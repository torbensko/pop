import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var model: LauncherModel!
    private var launcher: PanelController!
    private var settings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = LauncherModel()
        launcher = PanelController(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Pop")
        let menu = NSMenu()
        let versionItem = NSMenuItem(title: "Pop · \(AppVersion.description)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        add("Open Pop", action: #selector(toggle), to: menu)
        add("Settings…", action: #selector(showSettings), to: menu)
        add("Reindex", action: #selector(reindex), to: menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        KeyboardShortcuts.onKeyUp(for: .togglePop) { [weak self] in self?.launcher.toggle() }
    }
    private func add(_ title: String, action: Selector, to menu: NSMenu) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
    }
    @objc private func toggle() { launcher.toggle() }
    @objc private func reindex() { model.reload() }
    @objc private func showSettings() {
        launcher.hide()
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Pop Settings"
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }
}
