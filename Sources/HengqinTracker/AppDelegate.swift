import AppKit
import Combine
import HengqinCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let profileStore = ProfileStore()
    private lazy var store = ResidencyStore(profileStore: profileStore)
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var viewModeObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        installPopover()
        observeViewMode()

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

        let title = "\(store.stats.naturalDays) 天"
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        button.toolTip = "一年几天 · DaysHere"
        button.target = self
        button.action = #selector(togglePopover(_:))

        statusItem = item
    }

    private func installPopover() {
        let initialSize = MenuBarPanelView.popoverSize(for: store.viewMode)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = initialSize
        popover.delegate = self
        let controller = NSHostingController(
            rootView: MenuBarPanelView(store: store, openSettings: { [weak self] in
                self?.showSettings()
            })
        )
        if #available(macOS 13.0, *) {
            controller.sizingOptions = []
        }
        controller.preferredContentSize = initialSize
        popover.contentViewController = controller
        self.popover = popover
    }

    /// Watch the active view mode and resize the popover whenever it flips.
    /// NSPopover.animates = true makes the contentSize change animate
    /// automatically; pairing it with `.animation` on the SwiftUI side keeps
    /// the inner layout and the window frame moving together.
    private func observeViewMode() {
        viewModeObserver = store.$viewMode
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.animatePopoverResize(to: mode)
            }
    }

    private func animatePopoverResize(to mode: HeatmapViewMode) {
        guard let popover else { return }
        let newSize = MenuBarPanelView.popoverSize(for: mode)
        popover.contentSize = newSize
        popover.contentViewController?.preferredContentSize = newSize
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
        // Refresh size in case viewMode changed while the popover was closed.
        let currentSize = MenuBarPanelView.popoverSize(for: store.viewMode)
        popover.contentSize = currentSize
        popover.contentViewController?.preferredContentSize = currentSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover?.performClose(nil)
        statusItem?.button?.highlight(false)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
    }

    // MARK: - Settings window

    private func showSettings() {
        if let window = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(store: store, sync: store.sync, profileStore: profileStore)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "一年几天 · 设置"
        window.titlebarAppearsTransparent = false
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
