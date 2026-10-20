import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
check(Calculator.evaluate("(24 + 6) / 3") == "10", "Parentheses")
check(Calculator.evaluate("2+3*4") == "14", "Precedence")
check(Calculator.evaluate("2^3^2") == "512", "Right-associative powers")
check(Calculator.evaluate("-2^2") == "-4", "Unary precedence")
check(Calculator.evaluate("2^-2") == "0.25", "Negative exponent")
for invalid in ["", "1/0", "1+", "(2+3", "2foo", "1..2", "()"] {
    check(Calculator.evaluate(invalid) == nil, "Reject \(invalid)")
}
check(SearchIndex.score("vsc", name: "Visual Studio Code") != nil, "Subsequence")
check(SearchIndex.score("cafe", name: "Café") == 10000, "Accent folding")
check(SearchIndex.score("xyz", name: "Safari") == nil, "Reject mismatch")
let app = Item(url: URL(fileURLWithPath: "/Apps/Visual Studio Code.app"), isApp: true)
let folder = Item(url: URL(fileURLWithPath: "/Projects/vsc"), isApp: false)
check(SearchIndex.search("vsc", items: [folder, app]).first?.id == folder.id, "Exact folder beats a weak application match")
let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try fm.createDirectory(at: root.appendingPathComponent("child/grandchild"), withIntermediateDirectories: true)
try fm.createDirectory(at: root.appendingPathComponent("Example.app/Contents"), withIntermediateDirectories: true)
try fm.createDirectory(at: root.appendingPathComponent(".hidden/nested"), withIntermediateDirectories: true)
try fm.createSymbolicLink(at: root.appendingPathComponent("cycle"), withDestinationURL: root)
defer { try? fm.removeItem(at: root) }
for depth in 0...2 {
    let result = SearchIndex.build(roots: [FolderRoot(path: root.path, depth: depth)], appPaths: [])
    check(result.items.filter { !$0.isApp }.count == depth + 1, "Depth \(depth), skip links/hidden/bundles")
    check(result.items.contains { $0.isApp } == (depth > 0), "Apps at depth boundary")
}
let overlaps = SearchIndex.build(roots: [FolderRoot(path: root.path, depth: 2), FolderRoot(path: root.appendingPathComponent("child").path, depth: 1)], appPaths: [])
check(overlaps.items.count == 4, "Deduplicate overlapping roots")
print("All calculator, ranking, and directory indexing checks passed.")

for query in ["vis co", "vsco", "vsc", "studio co"] {
    check(SearchIndex.score(query, name: "Visual Studio Code") != nil, "Intentional abbreviation: \(query)")
}
for query in ["blnder", "blendre", "blenxer", "blendder", "blen"] {
    check(SearchIndex.score(query, name: "Blender") != nil, "Missing, transposed, substituted, extra letters: \(query)")
}
check(SearchIndex.score("zz", name: "Blender") == nil, "Short queries must match")
check(SearchIndex.score("zzzzzz", name: "Blender") == nil, "Unrelated long query")
check(SearchIndex.score("blender", name: "Blender")! > SearchIndex.score("blendre", name: "Blender")!, "Exact beats typo")
let blender = Item(url: URL(fileURLWithPath: "/Apps/Blender.app"), isApp: true)
let blendFolder = Item(url: URL(fileURLWithPath: "/Projects/Blender"), isApp: false)
check(SearchIndex.search("blend", items: [blendFolder, blender]).first?.isApp == true, "App boost for equally good matches")
let history = [blendFolder.id: LaunchUsage(count: 20, lastOpened: Date())]
check(SearchIndex.search("blend", items: [blendFolder, blender], usage: history).first?.id == blendFolder.id, "Frequent folder is promoted")
check(SearchIndex.search("safari", items: [blendFolder, blender], usage: history).isEmpty, "Usage never creates an unrelated match")
let docs = Item(url: URL(fileURLWithPath: SearchIndex.commonFolderPaths[0]), isApp: false)
let downloads = Item(url: URL(fileURLWithPath: SearchIndex.commonFolderPaths[1]), isApp: false)
let starter = SearchIndex.search("", items: [folder, blender, docs, downloads, app])
check(Set(starter.prefix(2).map(\.id)) == Set([docs.id, downloads.id]), "Default common folders")
let used = SearchIndex.search("  ", items: [folder, blender, docs, downloads, app], usage: [blender.id: LaunchUsage(count: 5, lastOpened: Date())])
check(used.first(where: \.isApp)?.id == blender.id, "Frequent app at top of application section")
let historyURL = root.appendingPathComponent("history/usage.json")
var store = UsageStore(url: historyURL)
try store.load()
try store.record(blender.id, at: Date(timeIntervalSince1970: 100))
try store.record(blender.id, at: Date(timeIntervalSince1970: 200))
var restored = UsageStore(url: historyURL)
try restored.load()
check(restored.entries[blender.id]?.count == 2, "Usage persists across restarts")
check(restored.entries[blender.id]?.lastOpened == Date(timeIntervalSince1970: 200), "Last-open date persists")
print("All abbreviation, typo tolerance, usage ranking, suggestions, and persistence checks passed.")
