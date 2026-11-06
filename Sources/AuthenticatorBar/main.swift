import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AccountStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient
        popover.animates = false

        // Control + Option + O toggles the popover from anywhere.
        hotKey = HotKey(keyCode: kVK_ANSI_O, modifiers: controlKey | optionKey) { [weak self] in
            DispatchQueue.main.async { self?.togglePopover() }
        }
    }

    /// Full-height coloured shield (like Teams or GlobalProtect) instead of a thin monochrome glyph.
    private static func menuBarIcon() -> NSImage? {
        let blue = NSColor(red: 0.18, green: 0.50, blue: 1.0, alpha: 1)
        let config = NSImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white, blue]))
        guard let symbol = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Authenticator")?
            .withSymbolConfiguration(config) else { return nil }

        let height: CGFloat = 22
        let size = NSSize(width: height * symbol.size.width / symbol.size.height, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Authenticator"
        return image
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        store.load()

        // A fresh controller each time so the popover always opens on the code list.
        let host = NSHostingController(rootView: PopoverView(store: store, close: { [weak self] in
            self?.popover.performClose(nil)
        }))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
