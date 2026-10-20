import Foundation

@main
struct SelectionTests {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = LauncherModel(configURL: directory.appendingPathComponent("config.json"),
                                  usageURL: directory.appendingPathComponent("usage.json"))
        let downloads = Item(url: URL(fileURLWithPath: "/Users/example/Downloads"), isApp: false)
        let photos = Item(url: URL(fileURLWithPath: "/System/Applications/Photos.app"), isApp: true)
        let blender = Item(url: URL(fileURLWithPath: "/Applications/Blender.app"), isApp: true)

        for query in ["", "ph"] {
            model.query = query
            model.results = [downloads, photos, blender]
            model.move(1)
            precondition(model.selection == 1)
            // A TextField submission can write its existing value before onSubmit.
            model.query = query
            precondition(model.selection == 1, "Unchanged text must preserve the highlighted card")
            var opened: [URL] = []
            precondition(model.openSelection { opened.append($0); return true })
            precondition(opened == [photos.url], "Return must open Photos, not Downloads or the final item")
        }
        model.query = "different"
        precondition(model.selection == 0, "Changed text starts a fresh selection")
        model.results = []
        precondition(!model.openSelection { _ in fatalError("Empty results must not launch") })
        print("Selection commit and activation regression checks passed.")
    }
}
