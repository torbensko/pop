import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePop = Self("togglePop", initial: .init(.space, modifiers: [.control, .option]))
}

struct SettingsView: View {
    @ObservedObject var model: LauncherModel
    @State private var shortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .togglePop)
    @State private var shortcutMessage: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pop Settings").font(.title2.bold())
                    Text(AppVersion.description).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                KeyboardShortcuts.Recorder("Open launcher:", name: .togglePop) { value in
                    shortcut = value
                    shortcutMessage = nil
                }
                HStack {
                    Text(shortcut.map { "Assigned: \($0)" } ?? "No launch shortcut assigned")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Use ⌘Space") { useCommandSpace() }
                }
                if let shortcutMessage {
                    Text(shortcutMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            Text("Folder locations").font(.headline)
            Text("Depth 0 includes only the selected folder. Depth 1 adds its immediate subfolders. Documents and Downloads are included automatically. Applications receive a search ranking boost.")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach(model.roots) { root in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(URL(fileURLWithPath: root.path).lastPathComponent).fontWeight(.medium)
                            Text(root.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(root.path)
                        }
                        Spacer()
                        Stepper("Depth: \(root.depth)", value: Binding(get: { root.depth }, set: { depth in
                            model.updateRoots(model.roots.map { $0.id == root.id ? FolderRoot(path: root.path, depth: depth) : $0 })
                        }), in: 0...20).fixedSize()
                        Button { model.updateRoots(model.roots.filter { $0.id != root.id }) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Remove \(root.path)")
                    }.padding(.vertical, 4)
                }
            }.overlay { if model.roots.isEmpty { Text("Add a folder to start searching its subfolders.").foregroundStyle(.secondary) } }
            HStack {
                Button("Add folders…") { model.chooseFolders() }
                Spacer()
                if model.indexing { ProgressView().controlSize(.small) }
                Button("Reindex") { model.reload() }
            }
            if let message = model.message { Text(message).font(.caption).foregroundStyle(.orange).lineLimit(3).help(message) }
        }.padding(24).frame(width: 620, height: 440)
    }

    private func useCommandSpace() {
        let requested = KeyboardShortcuts.Shortcut(.space, modifiers: [.command])
        guard !requested.isTakenBySystem else {
            shortcutMessage = "Command–Space is assigned to a macOS shortcut. Disable that shortcut in System Settings → Keyboard → Keyboard Shortcuts first."
            return
        }
        // End recording before assigning, so the global shortcut resumes immediately.
        NSApp.keyWindow?.makeFirstResponder(nil)
        KeyboardShortcuts.setShortcut(requested, for: .togglePop)
        shortcut = KeyboardShortcuts.getShortcut(for: .togglePop)
        shortcutMessage = shortcut == requested ? "Command–Space saved." : "Could not save Command–Space."
    }
}
