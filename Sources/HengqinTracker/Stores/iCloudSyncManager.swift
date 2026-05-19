import Combine
import Foundation
import HengqinCore

/// Wraps `NSUbiquitousKeyValueStore` to ship the entire DayRecord dictionary
/// as a single JSON blob (≤ ~30 KB for a full year of marks, well under the
/// 1 MB / 1024-key limits). Last-write-wins is provided by KVS itself.
@MainActor
final class iCloudSyncManager: ObservableObject {
    enum Status: Equatable {
        case disabled                 // user toggle is off
        case unavailable(String)      // iCloud account / entitlement missing
        case idle                     // up to date
        case syncing
        case error(String)

        var summary: String {
            switch self {
            case .disabled: "未开启"
            case .unavailable(let reason): "不可用 · \(reason)"
            case .idle: "已同步"
            case .syncing: "同步中…"
            case .error(let message): "失败 · \(message)"
            }
        }
    }

    enum ExternalChange {
        /// Remote contained newer/different records; caller should adopt them.
        case adopt([DateKey: DayRecord])
    }

    @Published private(set) var status: Status = .disabled
    @Published private(set) var lastSyncedAt: Date?

    /// Suffix appended to the KVS key so each profile syncs in its own
    /// namespace. Set via `switchProfile(suffix:)` whenever the active profile
    /// changes.
    private(set) var keySuffix: String

    /// Persisted user preference for whether sync is on.
    var isEnabledByUser: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set {
            defaults.set(newValue, forKey: Self.enabledKey)
            if newValue {
                start()
            } else {
                stop()
            }
        }
    }

    var onExternalChange: ((ExternalChange) -> Void)?

    private let store: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private var observers: [NSObjectProtocol] = []
    private var lastPushedDigest: Data?
    private var pushTimer: Timer?

    private static let enabledKey = "hengqin.icloudSync.enabled"
    private static let lastSyncedAtKey = "hengqin.icloudSync.lastSyncedAt"
    private static let recordsKeyPrefix = "hengqin.records.v1"

    private var recordsKey: String {
        keySuffix.isEmpty ? Self.recordsKeyPrefix : "\(Self.recordsKeyPrefix).\(keySuffix)"
    }

    init(
        keySuffix: String = "",
        store: NSUbiquitousKeyValueStore = .default,
        defaults: UserDefaults = .standard
    ) {
        self.keySuffix = keySuffix
        self.store = store
        self.defaults = defaults
        if let saved = defaults.object(forKey: Self.lastSyncedAtKey) as? Date {
            self.lastSyncedAt = saved
        }
    }

    /// Re-subscribe to a different profile's KVS namespace. Stops any existing
    /// observer, swaps the key suffix, and lets the caller bootstrap fresh.
    func switchProfile(suffix newSuffix: String) {
        guard newSuffix != keySuffix else { return }
        stop()
        keySuffix = newSuffix
        lastPushedDigest = nil
    }

    /// Call once after the store has fully initialized.
    func bootstrap(currentRecords: [DateKey: DayRecord]) {
        if isEnabledByUser {
            start()
            if !currentRecords.isEmpty {
                push(records: currentRecords, force: true)
            }
            pull(force: true)
        }
    }

    func start() {
        guard observers.isEmpty else { return }
        guard ensureAvailability() else { return }

        status = .idle

        let recordsKey = recordsKey
        let token = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            let changedKeys = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? []
            let shouldPull = changedKeys.contains(recordsKey)
            Task { @MainActor in
                guard let self, shouldPull else { return }
                self.pull(force: false)
            }
        }
        observers.append(token)
        store.synchronize()
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver(_:))
        observers.removeAll()
        pushTimer?.invalidate()
        pushTimer = nil
        if status != .unavailable("") {
            status = .disabled
        } else {
            status = .disabled
        }
    }

    func push(records: [DateKey: DayRecord], force: Bool = false) {
        guard isEnabledByUser else { return }
        guard ensureAvailability() else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let payload = Dictionary(uniqueKeysWithValues: records.map { ($0.key.rawValue, $0.value) })
            let data = try encoder.encode(payload)

            if !force, data == lastPushedDigest { return }

            status = .syncing
            store.set(data, forKey: recordsKey)
            store.set(Date().timeIntervalSince1970, forKey: recordsKey + ".ts")
            store.synchronize()

            lastPushedDigest = data
            markSynced()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    /// Force-pull from KVS. Triggers `onExternalChange` if the remote dataset
    /// differs from the digest we last pushed.
    func pull(force: Bool = false) {
        guard isEnabledByUser else { return }
        guard ensureAvailability() else { return }

        guard let raw = store.data(forKey: recordsKey) else {
            markSynced()
            return
        }

        if !force, raw == lastPushedDigest { return }

        do {
            let decoded = try JSONDecoder().decode([String: DayRecord].self, from: raw)
            let records = Dictionary(uniqueKeysWithValues: decoded.map { (DateKey($0.key), $0.value) })
            lastPushedDigest = raw
            markSynced()
            onExternalChange?(.adopt(records))
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Private

    @discardableResult
    private func ensureAvailability() -> Bool {
        if !isEnabledByUser {
            status = .disabled
            return false
        }
        if FileManager.default.ubiquityIdentityToken == nil {
            status = .unavailable("未登录 iCloud，或当前为未签名构建")
            return false
        }
        return true
    }

    private func markSynced() {
        let now = Date()
        lastSyncedAt = now
        defaults.set(now, forKey: Self.lastSyncedAtKey)
        status = .idle
    }
}
