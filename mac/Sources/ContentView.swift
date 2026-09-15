import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var conv: Converter
    @State private var dropTargeted = false
    @State private var emptyHovering = false

    var body: some View {
        VStack(spacing: 0) {
            if !conv.toolsFound { missingToolsBanner }
            fileList
            Divider()
            settings
            Divider()
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Banner

    private var missingToolsBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("ffmpeg wasn't found. Install it with ") + Text("brew install ffmpeg").bold()
            Spacer()
        }
        .font(.callout)
        .padding(10)
        .background(Color.orange.opacity(0.18))
    }

    // MARK: - File list

    private var fileList: some View {
        ZStack {
            if conv.jobs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Drop files here")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("or click to choose files")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(emptyHovering && !conv.isRunning ? Color.primary.opacity(0.04) : Color.clear)
                .contentShape(Rectangle())
                .onHover { emptyHovering = $0 }
                .onTapGesture { if !conv.isRunning { chooseFiles() } }
                .help("Click to choose files")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(conv.jobs) { job in
                            JobRow(job: job) { conv.remove(job) }
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dropTargeted ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(6)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers {
            group.enter()
            _ = provider.loadDataRepresentation(
                forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                lock.lock(); urls.append(url); lock.unlock()
            }
        }
        group.notify(queue: .main) { conv.add(urls) }
        return true
    }

    // MARK: - Settings

    private var settings: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Convert to").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                Picker("", selection: $conv.format) {
                    ForEach(["Video", "Audio"], id: \.self) { group in
                        Section(group) {
                            ForEach(allFormats.filter { $0.group == group }) { f in
                                Text(f.label).tag(f)
                            }
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                Spacer()
            }
            GridRow {
                Text("Save into").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                HStack(spacing: 8) {
                    Button("Choose…") { chooseDestination() }
                    Text(conv.destination?.path ?? "No folder chosen")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(conv.destination == nil ? .tertiary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(conv.destination?.path ?? "")
                    if let dest = conv.destination {
                        Button {
                            NSWorkspace.shared.open(dest)
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderless)
                        .help("Reveal in Finder")
                    }
                    Spacer()
                }
            }
        }
        .disabled(conv.isRunning)
        .padding(14)
        .fixedSize(horizontal: false, vertical: true)   // hug content, don't stretch
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            Button("Add Files…") { chooseFiles() }
                .disabled(conv.isRunning)
            Button("Clear") { conv.clear() }
                .disabled(conv.isRunning || conv.jobs.isEmpty)

            Divider().frame(height: 16)

            ProgressView(value: conv.overall, total: 100)
                .progressViewStyle(.linear)
                .frame(width: 120)
            Text("\(Int(conv.overall.rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            Text(conv.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if conv.isRunning {
                Button("Stop") { conv.cancel() }
            } else {
                Button("Convert") { conv.start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(conv.jobs.isEmpty || conv.destination == nil || !conv.toolsFound)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Panels

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select files to convert"
        panel.prompt = "Add"
        if panel.runModal() == .OK { conv.add(panel.urls) }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose where converted files are saved"
        panel.prompt = "Choose"
        if panel.runModal() == .OK { conv.destination = panel.url }
    }
}

// MARK: - Row

struct JobRow: View {
    let job: Job
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.name).lineLimit(1).truncationMode(.middle)
                if !job.message.isEmpty {
                    Text(job.message)
                        .font(.caption)
                        .foregroundStyle(job.status == .failed ? Color.red : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(job.message)
                }
            }
            Spacer(minLength: 8)

            if job.status == .working {
                ProgressView(value: job.percent, total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 70)
                Text("\(Int(job.percent.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            } else {
                Text(job.status.label)
                    .font(.caption)
                    .foregroundStyle(tint)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0)
            .help("Remove")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            if let out = job.output { NSWorkspace.shared.activateFileViewerSelecting([out]) }
        }
    }

    private var icon: String {
        switch job.status {
        case .queued:  return "circle.dashed"
        case .working: return "arrow.triangle.2.circlepath"
        case .done:    return "checkmark.circle.fill"
        case .failed:  return "exclamationmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    private var tint: Color {
        switch job.status {
        case .done:    return .green
        case .failed:  return .red
        case .working: return .accentColor
        default:       return .secondary
        }
    }
}
