import AppKit
import Combine
import ServiceManagement

/// Wraps `SMAppService.mainApp` to register/unregister DaysHere as a
/// macOS Login Item. Works on signed `.app` bundles (which we always
/// distribute as); a raw `swift run` binary won't be discoverable by
/// ServiceManagement and `register()` will throw.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String?

    private let service: SMAppService = .mainApp

    init() {
        self.status = service.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var requiresUserApproval: Bool {
        status == .requiresApproval
    }

    /// Re-read status from the system. Call after presenting the settings
    /// window in case the user toggled Login Items externally.
    func refresh() {
        status = service.status
    }

    /// Attempt to register or unregister the main app for launch at login.
    /// Updates `status` (and `lastError` on failure). When macOS wants the
    /// user to confirm in System Settings, status becomes
    /// `.requiresApproval` — the UI then surfaces an "Open Settings" link.
    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    /// Open the macOS "Login Items" panel of System Settings.
    func openLoginItemsSettings() {
        // macOS 13+ → Login Items pane URL scheme
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.users"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    var statusSummary: String {
        switch status {
        case .notRegistered: return "未注册"
        case .enabled: return "已启用"
        case .requiresApproval: return "需要在系统设置中批准"
        case .notFound: return "未找到（请用签名 .app 运行）"
        @unknown default: return "未知状态"
        }
    }
}
