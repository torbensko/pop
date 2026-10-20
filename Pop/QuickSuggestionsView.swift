import SwiftUI
import AppKit

struct QuickSuggestionsView: View {
    let items: [Item]
    let selectedID: String?
    let open: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            suggestionRow("Folders", items: items.filter { !$0.isApp })
            suggestionRow("Applications", items: items.filter(\.isApp))
            Spacer(minLength: 0)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func suggestionRow(_ title: String, items: [Item]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 10) {
                    ForEach(items) { item in
                        Button { open(item) } label: {
                            VStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                    .resizable().frame(width: 36, height: 36)
                                Text(item.name).font(.system(size: 12, weight: .medium))
                                    .lineLimit(2).multilineTextAlignment(.center)
                                    .frame(height: 30, alignment: .top)
                            }
                            .frame(width: 110, height: 98)
                            .background(selectedID == item.id ? Color.accentColor.opacity(0.17) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selectedID == item.id ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                            .help(item.url.path)
                            .accessibilityLabel("\(item.name), \(item.isApp ? "application" : "folder")")
                            .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
                    }
                }
            }
        }
    }
}
