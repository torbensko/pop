import AppKit
import Combine

@MainActor
final class LauncherModel: ObservableObject {
    @Published var roots: [FolderRoot] = []
    @Published var query = "" { didSet { filter() } }
    @Published var results: [Item] = []
    @Published var selection = 0
    @Published var indexing = false
    @Published var message: String?
    @Published var focusToken = UUID()
    private var items: [Item] = []
    private var generation = 0
    private let configURL = URL.applicationSupportDirectory.appending(path: "Pop/config.json")
    private struct Config: Codable { var folders: [FolderRoot] }

    private var usage = UsageStore(url: URL.applicationSupportDirectory.appending(path: "Pop/usage.json"))
    @Published private var usageWarning: String?
    var isShowingSuggestions: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var statusMessage: String? { [message, usageWarning].compactMap { $0 }.joined(separator: "\n").nilIfEmpty }

    init() {
        do { try usage.load() }
        catch { usageWarning = "Could not load launch history: \(error.localizedDescription)" }
        reload()
    }

    func reload() {
        do {
            if FileManager.default.fileExists(atPath: configURL.path) {
                roots = try JSONDecoder().decode(Config.self, from: Data(contentsOf: configURL)).folders
                guard roots.allSatisfy({ (0...20).contains($0.depth) && ($0.path.hasPrefix("/") || $0.path.hasPrefix("~/")) }), Set(roots.map(\.path)).count == roots.count else {
                    fatalError("Invalid folders in \(configURL.path): use unique absolute paths and depths 0–20")
                }
            } else { try save() }
        } catch { fatalError("Cannot load \(configURL.path): \(error)") }
        reindex()
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Config(folders: roots)).write(to: configURL, options: .atomic)
    }

    func updateRoots(_ value: [FolderRoot]) {
        let previous = roots
        roots = value
        do { try save(); reindex() }
        catch { roots = previous; message = "Could not save folders: \(error.localizedDescription)" }
    }

    func chooseFolders() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = true
        picker.prompt = "Add folders"
        guard picker.runModal() == .OK else { return }
        var updated = roots
        for url in picker.urls {
            let path = url.standardizedFileURL.path
            if !updated.contains(where: { ($0.path as NSString).expandingTildeInPath == path }) { updated.append(FolderRoot(path: path, depth: 1)) }
        }
        updateRoots(updated)
    }

    func reindex() {
        generation += 1
        let current = generation
        // Include these folders themselves, without scanning their contents unless configured.
        let roots = roots + SearchIndex.commonFolderPaths.filter {
            FileManager.default.fileExists(atPath: $0)
        }.map { FolderRoot(path: $0, depth: 0) }
        indexing = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { SearchIndex.build(roots: roots) }.value
            guard current == generation else { return }
            items = result.items
            message = result.warnings.isEmpty ? nil : result.warnings.joined(separator: "\n")
            indexing = false
            filter()
        }
    }

    private func filter() { results = SearchIndex.search(query, items: items, usage: usage.entries); selection = 0 }
    func move(_ delta: Int) { selection = max(0, min(results.count - 1, selection + delta)) }
    func openSelection() -> Bool {
        guard results.indices.contains(selection) else { return false }
        let item = results[selection]
        guard NSWorkspace.shared.open(item.url) else { message = "Could not open \(item.name). Try reindexing."; return false }
        do { try usage.record(item.id); usageWarning = nil }
        catch { usageWarning = "Could not save launch history: \(error.localizedDescription)" }
        return true
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
