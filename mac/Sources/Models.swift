import Foundation

/// An output container + the ffmpeg flags that produce it.
struct OutputFormat: Identifiable, Hashable {
    let ext: String
    let group: String
    let label: String
    let args: [String]
    var id: String { ext }
}

let allFormats: [OutputFormat] = [
    OutputFormat(ext: "mp4", group: "Video", label: "MP4 · H.264 + AAC",
                 args: ["-c:v", "libx264", "-crf", "23", "-preset", "medium",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                        "-movflags", "+faststart"]),
    OutputFormat(ext: "mkv", group: "Video", label: "MKV · H.264 + AAC",
                 args: ["-c:v", "libx264", "-crf", "23", "-preset", "medium",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k"]),
    OutputFormat(ext: "mov", group: "Video", label: "MOV · H.264 + AAC",
                 args: ["-c:v", "libx264", "-crf", "23", "-preset", "medium",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k"]),
    OutputFormat(ext: "webm", group: "Video", label: "WebM · VP9 + Opus",
                 args: ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0",
                        "-row-mt", "1", "-c:a", "libopus", "-b:a", "128k"]),
    OutputFormat(ext: "gif", group: "Video", label: "GIF · 12 fps, 640px",
                 args: ["-filter_complex",
                        "fps=12,scale=640:-1:flags=lanczos,split[s0][s1]"
                        + ";[s0]palettegen[p];[s1][p]paletteuse",
                        "-loop", "0"]),
    OutputFormat(ext: "mp3", group: "Audio", label: "MP3 · V0 VBR",
                 args: ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]),
    OutputFormat(ext: "m4a", group: "Audio", label: "M4A · AAC 192k",
                 args: ["-vn", "-c:a", "aac", "-b:a", "192k"]),
    OutputFormat(ext: "wav", group: "Audio", label: "WAV · 16-bit PCM",
                 args: ["-vn", "-c:a", "pcm_s16le"]),
    OutputFormat(ext: "flac", group: "Audio", label: "FLAC · lossless",
                 args: ["-vn", "-c:a", "flac"]),
    OutputFormat(ext: "opus", group: "Audio", label: "Opus · 128k",
                 args: ["-vn", "-c:a", "libopus", "-b:a", "128k"]),
]

enum JobStatus: String {
    case queued, working, done, failed, skipped

    var label: String {
        switch self {
        case .queued:  return "Queued"
        case .working: return "Converting"
        case .done:    return "Done"
        case .failed:  return "Failed"
        case .skipped: return "Skipped"
        }
    }
}

struct Job: Identifiable {
    let id = UUID()
    let url: URL
    var status: JobStatus = .queued
    var percent: Double = 0
    var message: String = ""
    var output: URL?

    var name: String { url.lastPathComponent }
}

func humanSize(_ bytes: Int) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    return f.string(fromByteCount: Int64(bytes))
}
