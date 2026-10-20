import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController {
    private let model: LauncherModel
    private let panel: LauncherPanel

    init(model: LauncherModel) {
        self.model = model
        panel = LauncherPanel(contentRect: NSRect(x: 0, y: 0, width: 660, height: 460), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: SearchView(model: model) { [weak self] in self?.hide() })
    }
    func toggle() { if panel.isVisible { hide() } else { show() } }
    func hide() { panel.orderOut(nil) }
    func show() {
        model.query = ""
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2 + 80))
        }
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { self.model.focusToken = UUID() }
    }
}
