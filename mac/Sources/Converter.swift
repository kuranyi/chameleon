import Foundation
import Combine

/// Runs the conversion queue by driving the ffmpeg binary directly.
final class Converter: ObservableObject {

    @Published var jobs: [Job] = []
    @Published var destination: URL?
    @Published var format: OutputFormat = allFormats[0]
    @Published var isRunning = false
    @Published var overall: Double = 0
    @Published var summary = "Add files to get started."

    /// nil when ffmpeg isn't installed — the UI shows a banner in that case.
    let ffmpegPath  = Converter.locate("ffmpeg")
    let ffprobePath = Converter.locate("ffprobe")
    var toolsFound: Bool { ffmpegPath != nil && ffprobePath != nil }

    private var currentProcess: Process?
    private var cancelled = false
    private let worker = DispatchQueue(label: "studio.convert", qos: .userInitiated)

    // MARK: - Tool discovery
    // A bundled app doesn't inherit the shell's PATH, so look in the usual
    // Homebrew locations before falling back to a login shell.
    private static func locate(_ tool: String) -> String? {
        let fm = FileManager.default
        for dir in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"] {
            let path = dir + "/" + tool
            if fm.isExecutableFile(atPath: path) { return path }
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", "which \(tool)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fm.isExecutableFile(atPath: path) ? path : nil
    }

    // MARK: - Queue management

    func add(_ urls: [URL]) {
        var added = 0
        for url in urls where !jobs.contains(where: { $0.url == url }) {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  !isDir.boolValue else { continue }
            jobs.append(Job(url: url))
            added += 1
        }
        if added > 0 {
            summary = "\(added) file\(added == 1 ? "" : "s") added."
        }
    }

    func remove(_ job: Job) {
        guard !isRunning else { return }
        jobs.removeAll { $0.id == job.id }
        if jobs.isEmpty { reset() }
    }

    func clear() {
        guard !isRunning else { return }
        jobs.removeAll()
        reset()
    }

    private func reset() {
        overall = 0
        summary = "Add files to get started."
    }

    func cancel() {
        cancelled = true
        currentProcess?.terminate()
        summary = "Stopping…"
    }

    // MARK: - Running

    func start() {
        guard !isRunning, !jobs.isEmpty, let dest = destination else { return }
        guard let ffmpeg = ffmpegPath else { return }

        cancelled = false
        isRunning = true
        overall = 0
        for i in jobs.indices {
            jobs[i].status = .queued
            jobs[i].percent = 0
            jobs[i].message = ""
            jobs[i].output = nil
        }
        let snapshot = jobs
        let fmt = format

        worker.async { [weak self] in
            guard let self else { return }
            for (index, job) in snapshot.enumerated() {
                if self.cancelled {
                    self.update(index) { $0.status = .skipped; $0.message = "Cancelled" }
                    continue
                }
                self.onMain {
                    self.summary = "Converting \(index + 1) of \(snapshot.count) — \(job.name)"
                }
                self.convert(job, at: index, to: fmt, in: dest, ffmpeg: ffmpeg)
            }
            self.onMain {
                self.isRunning = false
                self.overall = 100
                let ok = self.jobs.filter { $0.status == .done }.count
                let bad = self.jobs.filter { $0.status == .failed }.count
                let skip = self.jobs.filter { $0.status == .skipped }.count
                var parts = ["\(ok) converted"]
                if bad > 0 { parts.append("\(bad) failed") }
                if skip > 0 { parts.append("\(skip) skipped") }
                self.summary = parts.joined(separator: ", ") + " → " + dest.lastPathComponent
            }
        }
    }

    // MARK: - One file

    private func convert(_ job: Job, at index: Int, to fmt: OutputFormat,
                         in dest: URL, ffmpeg: String) {
        let stem = job.url.deletingPathExtension().lastPathComponent
        let out = uniqueURL(in: dest, stem: stem, ext: fmt.ext)

        if out.standardizedFileURL == job.url.standardizedFileURL {
            update(index) {
                $0.status = .skipped
                $0.message = "Source and destination are the same file"
            }
            return
        }

        // Extracting audio from a file that has none fails deep inside ffmpeg
        // with "Invalid argument"; catch it here and say something useful.
        if fmt.group == "Audio", hasAudioStream(job.url) == false {
            update(index) {
                $0.status = .failed
                $0.message = "No audio track in this file"
            }
            return
        }

        let duration = probeDuration(job.url)
        update(index) { $0.status = .working; $0.percent = 0; $0.message = "Converting…" }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffmpeg)
        proc.arguments = ["-nostdin", "-hide_banner", "-loglevel", "error",
                          "-progress", "pipe:1", "-y", "-i", job.url.path]
                         + fmt.args + [out.path]

        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        let lock = NSLock()
        var buffer = Data()
        var errText = ""

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty, let self else { return }
            lock.lock()
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[buffer.startIndex..<nl], as: UTF8.self)
                buffer.removeSubrange(buffer.startIndex...nl)
                guard let dur = duration, dur > 0,
                      let eq = line.firstIndex(of: "=") else { continue }
                let key = String(line[line.startIndex..<eq])
                guard key == "out_time_us" || key == "out_time_ms" else { continue }
                // Both keys report microseconds, a long-standing ffmpeg quirk.
                let raw = line[line.index(after: eq)...]
                    .trimmingCharacters(in: .whitespaces)
                guard let micros = Double(raw) else { continue }
                let pct = min(99, max(0, micros / 1_000_000 / dur * 100))
                self.update(index) { $0.percent = pct }
            }
            lock.unlock()
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock()
            errText += String(decoding: chunk, as: UTF8.self)
            lock.unlock()
        }

        do {
            try proc.run()
        } catch {
            update(index) { $0.status = .failed; $0.message = error.localizedDescription }
            return
        }
        currentProcess = proc
        proc.waitUntilExit()
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        currentProcess = nil

        if cancelled {
            try? FileManager.default.removeItem(at: out)
            update(index) { $0.status = .skipped; $0.percent = 0; $0.message = "Cancelled" }
        } else if proc.terminationStatus == 0 {
            let size = (try? FileManager.default
                .attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
            update(index) {
                $0.status = .done
                $0.percent = 100
                $0.output = out
                $0.message = humanSize(size)
            }
        } else {
            try? FileManager.default.removeItem(at: out)
            lock.lock()
            let detail = errText.split(separator: "\n").last.map(String.init)
                ?? "ffmpeg exited \(proc.terminationStatus)"
            lock.unlock()
            update(index) { $0.status = .failed; $0.percent = 0; $0.message = detail }
        }
    }

    private func probeDuration(_ url: URL) -> Double? {
        guard let ffprobe = ffprobePath else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffprobe)
        proc.arguments = ["-v", "error", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", url.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(text), value > 0 else { return nil }
        return value
    }

    /// true/false when ffprobe can read the file, nil when it can't —
    /// an unreadable file should surface ffmpeg's own error instead.
    private func hasAudioStream(_ url: URL) -> Bool? {
        guard let ffprobe = ffprobePath else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffprobe)
        proc.arguments = ["-v", "error", "-select_streams", "a",
                          "-show_entries", "stream=index",
                          "-of", "csv=p=0", url.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        return !String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Never overwrite: `clip.mp4` becomes `clip (1).mp4` if taken.
    private func uniqueURL(in dir: URL, stem: String, ext: String) -> URL {
        var candidate = dir.appendingPathComponent("\(stem).\(ext)")
        var n = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(stem) (\(n)).\(ext)")
            n += 1
        }
        return candidate
    }

    // MARK: - Publishing helpers

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }

    private func update(_ index: Int, _ mutate: @escaping (inout Job) -> Void) {
        onMain { [weak self] in
            guard let self, self.jobs.indices.contains(index) else { return }
            mutate(&self.jobs[index])
            let finished = self.jobs.filter {
                $0.status == .done || $0.status == .failed || $0.status == .skipped
            }.count
            let active = self.jobs[index].status == .working
                ? self.jobs[index].percent / 100 : 0
            self.overall = min(100, Double(finished) + active)
                / Double(max(self.jobs.count, 1)) * 100
        }
    }
}
