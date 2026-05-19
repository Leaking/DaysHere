import AppKit
import CoreLocation
import SwiftUI

/// Thin wrapper around `CLLocationManager` for the in-app map picker.
///
/// macOS authorization flow:
///   1. `request()` triggers the system prompt (one-shot per app install — the
///      OS only re-shows it after the user toggles in System Settings)
///   2. After authorization changes, `status` republishes the new value
///   3. `fetchCurrent` requests a one-shot location; results land on
///      `lastLocation` or the supplied completion
@MainActor
final class LocationPermissionManager: NSObject, ObservableObject {
    @Published private(set) var status: CLAuthorizationStatus
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastError: String?

    private let manager = CLLocationManager()
    private var pendingCompletion: ((Result<CLLocation, Error>) -> Void)?
    private var pendingRequestAfterAuth: Bool = false

    var isAuthorized: Bool {
        // macOS does not expose a separate `.authorizedWhenInUse`; success is
        // represented as `.authorizedAlways` (and the legacy `.authorized`).
        status == .authorizedAlways
    }

    var isDenied: Bool {
        status == .denied || status == .restricted
    }

    override init() {
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Trigger the OS authorization prompt. No-op if already decided.
    func request() {
        guard status == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Fetch one location reading. If the user hasn't decided yet, this
    /// triggers the prompt first and (on Allow) automatically follows up
    /// with the read. On denial the completion fires with `.failure`.
    func fetchCurrent(_ completion: @escaping (Result<CLLocation, Error>) -> Void) {
        pendingCompletion = completion
        switch status {
        case .notDetermined:
            pendingRequestAfterAuth = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            completeWith(.failure(LocationError.notAuthorized))
        @unknown default:
            completeWith(.failure(LocationError.notAuthorized))
        }
    }

    /// Open System Settings to the Location panel so the user can flip
    /// the permission if they previously denied.
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    private func completeWith(_ result: Result<CLLocation, Error>) {
        if case .failure(let err) = result {
            lastError = err.localizedDescription
        } else if case .success(let loc) = result {
            lastLocation = loc
            lastError = nil
        }
        pendingCompletion?(result)
        pendingCompletion = nil
    }

    enum LocationError: LocalizedError {
        case notAuthorized
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "未获得定位权限，请在系统设置 → 隐私与安全性 → 定位服务中允许。"
            }
        }
    }
}

extension LocationPermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            if self.pendingRequestAfterAuth {
                self.pendingRequestAfterAuth = false
                if self.isAuthorized {
                    self.manager.requestLocation()
                } else {
                    self.completeWith(.failure(LocationError.notAuthorized))
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.completeWith(.success(loc))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.completeWith(.failure(error))
        }
    }
}
