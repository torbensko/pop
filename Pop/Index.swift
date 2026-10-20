import Foundation

struct FolderRoot: Codable, Identifiable, Equatable, Sendable {
    var path: String
    var depth: Int
    var id: String { path }
}

struct Item: Identifiable, Sendable {
    let url: URL
    let isApp: Bool
    var id: String { url.path }
    var name: String { isApp ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent }
}

enum SearchIndex {
    struct Result: Sendable {
        var items: [Item]
        var warnings: [String]
    }

    static func build(roots: [FolderRoot], appPaths: [String] = ["/Applications", "/System/Applications", "/System/Library/CoreServices/Applications", "~/Applications"]) -> Result {
        let fm = FileManager.default
        var items: [String: Item] = [:]
        var warnings: [String] = []
        func visit(_ url: URL, depth: Int, folders: Bool) {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]), values.isDirectory == true else { return }
            // Never follow directory links or descend into bundles.
            guard values.isSymbolicLink != true else { return }
            let app = url.pathExtension.lowercased() == "app"
            if app || (folders && values.isPackage != true) {
                items[url.standardizedFileURL.path] = Item(url: url.standardizedFileURL, isApp: app)
            }
            guard !app, values.isPackage != true, depth > 0 else { return }
            do {
                for child in try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey], options: [.skipsHiddenFiles]) {
                    visit(child, depth: depth - 1, folders: folders)
                }
            } catch { warnings.append("Cannot read \(url.path): \(error.localizedDescription)") }
        }
        for path in appPaths {
            visit(URL(fileURLWithPath: (path as NSString).expandingTildeInPath), depth: 4, folders: false)
        }
        for root in roots {
            let url = URL(fileURLWithPath: (root.path as NSString).expandingTildeInPath)
            if !fm.fileExists(atPath: url.path) { warnings.append("Folder unavailable: \(root.path)") }
            visit(url, depth: root.depth, folders: true)
        }
        return Result(items: Array(items.values), warnings: warnings)
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func score(_ query: String, name: String) -> Int? {
        let query = normalized(query).filter { !$0.isWhitespace }
        let name = normalized(name)
        let compact = name.filter { !$0.isWhitespace }
        if query.isEmpty { return 0 }
        guard query.count <= 128 else { return nil }
        if query == compact { return 10000 }
        if compact.hasPrefix(query) { return 8000 - min(compact.count, 500) }
        // Intentional abbreviations are subsequences, not spelling mistakes.
        // Score all possible alignments so repeated letters don't hide word boundaries.
        let chars = Array(name)
        var previous = Array(repeating: Int.min / 2, count: chars.count)
        for (queryIndex, char) in query.enumerated() {
            var current = previous.map { _ in Int.min / 2 }
            var bestEarlier = Int.min / 2
            for index in chars.indices {
                if index > 0 { bestEarlier = max(bestEarlier, previous[index - 1] + index - 1) }
                guard chars[index] == char else { continue }
                let boundary = index == 0 || !chars[index - 1].isLetter && !chars[index - 1].isNumber
                let bonus = boundary ? 100 : 0
                if queryIndex == 0 { current[index] = bonus - index }
                else {
                    current[index] = bestEarlier - index + bonus
                    if index > 0 { current[index] = max(current[index], previous[index - 1] + 50 + bonus) }
                }
            }
            previous = current
        }
        if let best = previous.max(), best > Int.min / 4 {
            return 5000 + min(best, 1500)
        }
        // Short queries must match literally; otherwise one typo would match almost anything.
        guard query.count >= 3, query.count <= 128 else { return nil }
        let limit = query.count >= 6 ? 2 : 1
        let candidates = [compact] + name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let distance = candidates.map { prefixDistance(Array(query), Array($0)) }.min() ?? Int.max
        return distance <= limit ? 3000 - distance * 300 : nil
    }

    // Damerau-Levenshtein distance to a name/word prefix: missing, extra,
    // substituted, and adjacent transposed letters are accepted.
    private static func prefixDistance(_ query: [Character], _ name: [Character]) -> Int {
        let name = Array(name.prefix(query.count + 2))
        var rows = Array(repeating: Array(repeating: 0, count: name.count + 1), count: query.count + 1)
        for i in 0...query.count { rows[i][0] = i }
        for j in 0...name.count { rows[0][j] = j }
        guard !name.isEmpty else { return query.count }
        for i in 1...query.count {
            for j in 1...name.count {
                rows[i][j] = min(rows[i - 1][j] + 1, rows[i][j - 1] + 1,
                                 rows[i - 1][j - 1] + (query[i - 1] == name[j - 1] ? 0 : 1))
                if i > 1, j > 1, query[i - 1] == name[j - 2], query[i - 2] == name[j - 1] {
                    rows[i][j] = min(rows[i][j], rows[i - 2][j - 2] + 1)
                }
            }
        }
        return rows[query.count].dropFirst().min() ?? query.count
    }

    static func search(_ query: String, items: [Item], usage: [String: LaunchUsage] = [:]) -> [Item] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return suggestions(items: items, usage: usage)
        }
        return items.compactMap { item in
            score(query, name: item.name).map { (item, $0 + (item.isApp ? 250 : 0) + usageBonus(usage[item.id])) }
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return alphabetical($0.0, $1.0)
        }.map(\.0)
    }

    private static func usageBonus(_ usage: LaunchUsage?) -> Int {
        guard let usage else { return 0 }
        return min(1200, Int(log2(Double(max(0, usage.count)) + 1) * 200))
    }

    private static func alphabetical(_ lhs: Item, _ rhs: Item) -> Bool {
        let order = lhs.name.localizedStandardCompare(rhs.name)
        return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
    }

    static var commonFolderPaths: [String] {
        ["Documents", "Downloads"].map { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent($0).path }
    }

    static func suggestions(items: [Item], usage: [String: LaunchUsage]) -> [Item] {
        let sorted = items.sorted {
            let left = usage[$0.id], right = usage[$1.id]
            if (left?.count ?? 0) != (right?.count ?? 0) { return (left?.count ?? 0) > (right?.count ?? 0) }
            if left?.lastOpened != right?.lastOpened { return (left?.lastOpened ?? .distantPast) > (right?.lastOpened ?? .distantPast) }
            let leftSeed = commonFolderPaths.contains($0.id), rightSeed = commonFolderPaths.contains($1.id)
            if leftSeed != rightSeed { return leftSeed }
            return alphabetical($0, $1)
        }
        return Array(sorted.filter { !$0.isApp }.prefix(3)) + Array(sorted.filter(\.isApp).prefix(5))
    }
}
