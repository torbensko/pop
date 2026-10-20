import SwiftUI
import AppKit

struct SearchView: View {
    @ObservedObject var model: LauncherModel
    var dismiss: () -> Void
    @FocusState private var focused: Bool
    private var calculating: Bool { model.query.trimmingCharacters(in: .whitespaces).hasPrefix("=") }
    private var answer: String? { Calculator.evaluate(String(model.query.trimmingCharacters(in: .whitespaces).dropFirst())) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: calculating ? "equal.circle" : "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps and folders, or type =", text: $model.query)
                    .textFieldStyle(.plain).font(.system(size: 24)).focused($focused)
                    .onSubmit { activate() }
                    .onKeyPress(.downArrow) { moveVertically(1); return .handled }
                    .onKeyPress(.upArrow) { moveVertically(-1); return .handled }
                    .onKeyPress(.leftArrow) {
                        guard model.isShowingSuggestions else { return .ignored }
                        model.move(-1); return .handled
                    }
                    .onKeyPress(.rightArrow) {
                        guard model.isShowingSuggestions else { return .ignored }
                        model.move(1); return .handled
                    }
                if model.indexing { ProgressView().controlSize(.small) }
            }.padding(22)
            Divider()
            if calculating {
                VStack(alignment: .leading, spacing: 12) {
                    Text(answer ?? "Enter an expression").font(.system(size: 36, weight: .medium, design: .rounded)).textSelection(.enabled)
                    Text(answer == nil ? "Try = (24 + 6) / 3 · Supports + − * / ^ and parentheses" : "Press Return to copy result")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(24)
            } else if model.results.isEmpty {
                ContentUnavailableView(model.indexing ? "Indexing…" : "No matches", systemImage: "magnifyingglass", description: Text("Search by name. Add folder locations in Settings."))
                    .frame(maxHeight: .infinity)
            } else if model.isShowingSuggestions {
                QuickSuggestionsView(items: model.results,
                                     selectedID: model.results.indices.contains(model.selection) ? model.results[model.selection].id : nil) { item in
                    guard let index = model.results.firstIndex(where: { $0.id == item.id }) else { return }
                    model.selection = index
                    activate()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(model.results) { item in
                                let index = model.results.firstIndex(where: { $0.id == item.id }) ?? 0
                                Button {
                                    model.selection = index
                                    activate()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 32, height: 32)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name).font(.system(size: 15, weight: .medium))
                                            Text(item.url.deletingLastPathComponent().path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                        }
                                        Spacer()
                                        Text(item.isApp ? "Application" : "Folder").font(.caption).foregroundStyle(.secondary)
                                    }.padding(10).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .background(index == model.selection ? Color.accentColor.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                    .id(item.id)
                            }
                        }.padding(10)
                    }.onChange(of: model.selection) { _, value in if model.results.indices.contains(value) { proxy.scrollTo(model.results[value].id) } }
                        .onChange(of: model.query) { _, _ in if let first = model.results.first { proxy.scrollTo(first.id) } }
                }
            }
            Divider()
            HStack {
                Text(calculating ? "Calculator" : model.isShowingSuggestions ? "Suggestions · Learns as you open items" : "\(model.results.count) matches")
                Spacer()
                Text("\(model.isShowingSuggestions ? "←→ ↑↓" : "↑↓") Select   ↵ \(calculating ? "Copy" : "Open")   esc Close")
            }.font(.caption).foregroundStyle(.secondary).padding(12)
            if let message = model.statusMessage {
                Text(message).font(.caption).foregroundStyle(.orange).lineLimit(2).help(message).padding(.horizontal, 12).padding(.bottom, 8)
            }
        }.frame(width: 660, height: 460).background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear { focused = true }
            .onChange(of: model.focusToken) { _, _ in focused = true }
            .onExitCommand(perform: dismiss)
    }

    private func moveVertically(_ direction: Int) {
        guard model.isShowingSuggestions else { model.move(direction); return }
        let folderCount = model.results.prefix { !$0.isApp }.count
        let appCount = model.results.count - folderCount
        guard folderCount > 0, appCount > 0 else { return }
        if direction > 0, model.selection < folderCount {
            model.selection = folderCount + min(model.selection, appCount - 1)
        } else if direction < 0, model.selection >= folderCount {
            model.selection = min(model.selection - folderCount, folderCount - 1)
        }
    }

    private func activate() {
        if calculating {
            guard let answer else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(answer, forType: .string)
            dismiss()
        } else if model.openSelection() { dismiss() }
    }
}
