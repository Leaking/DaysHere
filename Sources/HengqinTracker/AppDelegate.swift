import AppKit
import HengqinCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = ResidencyStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        installPopover()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showTopRightPopover()
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 74)
        guard let button = item.button else {
            statusItem = item
            return
        }

        let title = "横 \(store.stats.naturalDays)"
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        button.toolTip = "横琴驻留追踪"
        button.target = self
        button.action = #selector(togglePopover(_:))

        statusItem = item
    }

    private func installPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = Self.popoverSize
        popover.delegate = self
        let controller = NSHostingController(
            rootView: MenuBarPanelView(store: store)
                .frame(width: Self.panelWidth, height: Self.panelHeight)
        )
        if #available(macOS 13.0, *) {
            controller.sizingOptions = []
        }
        controller.preferredContentSize = Self.popoverSize
        popover.contentViewController = controller
        self.popover = popover
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover?.isShown == true {
            closePopover()
        } else {
            showTopRightPopover()
        }
    }

    private func showTopRightPopover() {
        guard let button = statusItem?.button, let popover else { return }
        NSApp.activate(ignoringOtherApps: true)
        button.highlight(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover?.performClose(nil)
        statusItem?.button?.highlight(false)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
    }

    private static let panelWidth: CGFloat = 640
    private static let panelHeight: CGFloat = 386
    private static let popoverSize = NSSize(width: panelWidth, height: panelHeight)
}
