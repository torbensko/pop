import Foundation

struct LaunchUsage: Codable, Sendable {
    var count: Int
    var lastOpened: Date
}

struct UsageStore {
    let url: URL
    private(set) var entries: [String: LaunchUsage] = [:]

    mutating func load() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        entries = try JSONDecoder().decode([String: LaunchUsage].self, from: Data(contentsOf: url))
    }

    mutating func record(_ id: String, at date: Date = Date()) throws {
        let count = max(0, entries[id]?.count ?? 0)
        entries[id] = LaunchUsage(count: count < Int.max ? count + 1 : count, lastOpened: date)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }
}
