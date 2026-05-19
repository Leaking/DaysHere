import CoreLocation
@preconcurrency import MapKit
import SwiftUI

struct LocationPickerSheet: View {
    struct PickedLocation {
        let latitude: Double
        let longitude: Double
        let addressLabel: String?
    }

    let initialCoordinate: CLLocationCoordinate2D
    let initialName: String?
    var onPick: (PickedLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissions = LocationPermissionManager()
    @StateObject private var completer = LocalSearchCompleter()
    @State private var position: MapCameraPosition
    @State private var currentCoordinate: CLLocationCoordinate2D
    @State private var addressLabel: String?
    @State private var searchText: String = ""
    @State private var isSearchFocused: Bool = false
    @State private var permissionAlert: PermissionAlert?
    @State private var reverseGeocodeTask: Task<Void, Never>?

    private enum PermissionAlert: Identifiable {
        case denied
        var id: String { "denied" }
    }

    init(initialCoordinate: CLLocationCoordinate2D, initialName: String? = nil, onPick: @escaping (PickedLocation) -> Void) {
        self.initialCoordinate = initialCoordinate
        self.initialName = initialName
        self.onPick = onPick
        let region = MKCoordinateRegion(
            center: initialCoordinate,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )
        _position = State(initialValue: .region(region))
        _currentCoordinate = State(initialValue: initialCoordinate)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField

            if isSearchFocused, !completer.results.isEmpty {
                searchResultsList
                    .transition(.opacity)
            }

            mapBody

            bottomBar

            actionRow
        }
        .frame(width: 560, height: 600)
        .onAppear {
            reverseGeocode(currentCoordinate)
        }
        .onChange(of: searchText) { _, newValue in
            completer.queryFragment = newValue
            isSearchFocused = !newValue.isEmpty
        }
        .alert(item: $permissionAlert) { _ in
            Alert(
                title: Text("定位权限被拒绝"),
                message: Text("请在 系统设置 → 隐私与安全性 → 定位服务 中允许 HengqinTracker。"),
                primaryButton: .default(Text("打开系统设置")) { permissions.openSystemSettings() },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("在地图上选择坐标")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("搜索地点 (横琴口岸 / 长隆海洋王国 / 横琴湾酒店…)", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(completer.results, id: \.self) { result in
                    Button {
                        selectSearchResult(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.02))
                    Divider().opacity(0.4)
                }
            }
        }
        .frame(maxHeight: 160)
        .background(Color.primary.opacity(0.03))
        .overlay(
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1),
            alignment: .bottom
        )
    }

    private var mapBody: some View {
        ZStack {
            Map(position: $position)
                .onMapCameraChange(frequency: .continuous) { context in
                    currentCoordinate = context.region.center
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    debounceReverseGeocode(context.region.center)
                }

            // Center pin — always indicates the picked coordinate.
            VStack(spacing: 0) {
                Image(systemName: "mappin")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(red: 0.85, green: 0.20, blue: 0.20))
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .offset(y: -8) // anchor pin tip on geometric center
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 6, height: 3)
                    .blur(radius: 1)
                    .offset(y: -6)
            }
            .allowsHitTesting(false)
        }
        .clipped()
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.4f°N, %.4f°E", currentCoordinate.latitude, currentCoordinate.longitude))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                if let addressLabel, !addressLabel.isEmpty {
                    Text(addressLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                useCurrentLocation()
            } label: {
                Label("使用当前位置", systemImage: "location.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .controlSize(.small)
            .disabled(permissions.isDenied)
            .help(permissions.isDenied ? "已拒绝定位权限，点击下方提示打开设置" : "请求一次性定位")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle().fill(Color.primary.opacity(0.04))
                .overlay(Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1), alignment: .top)
        )
    }

    private var actionRow: some View {
        HStack {
            if permissions.isDenied {
                Button {
                    permissions.openSystemSettings()
                } label: {
                    Label("定位被拒，去开启", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button("取消") { dismiss() }
            Button("使用此处") {
                let picked = PickedLocation(
                    latitude: currentCoordinate.latitude,
                    longitude: currentCoordinate.longitude,
                    addressLabel: addressLabel
                )
                onPick(picked)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        searchText = completion.title
        isSearchFocused = false
        Task {
            let request = MKLocalSearch.Request(completion: completion)
            request.resultTypes = [.address, .pointOfInterest]
            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                guard let item = response.mapItems.first else { return }
                let coord = item.placemark.coordinate
                let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1500, longitudinalMeters: 1500)
                await MainActor.run {
                    position = .region(region)
                    currentCoordinate = coord
                    addressLabel = [item.name, item.placemark.title]
                        .compactMap { $0 }
                        .first { !$0.isEmpty }
                }
            } catch {
                // Search failures are non-fatal — keep current state.
            }
        }
    }

    private func useCurrentLocation() {
        if permissions.isDenied {
            permissionAlert = .denied
            return
        }
        permissions.fetchCurrent { result in
            switch result {
            case .success(let loc):
                let region = MKCoordinateRegion(
                    center: loc.coordinate,
                    latitudinalMeters: 4000,
                    longitudinalMeters: 4000
                )
                position = .region(region)
                currentCoordinate = loc.coordinate
                reverseGeocode(loc.coordinate)
            case .failure:
                if permissions.isDenied {
                    permissionAlert = .denied
                }
            }
        }
    }

    private func debounceReverseGeocode(_ coord: CLLocationCoordinate2D) {
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            reverseGeocode(coord)
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN"))
                guard let p = placemarks.first else { return }
                let parts = [p.subLocality, p.locality, p.administrativeArea].compactMap { $0 }
                let label = p.name ?? parts.joined(separator: " · ")
                await MainActor.run {
                    addressLabel = label
                }
            } catch {
                // Ignore — leave previous label.
            }
        }
    }
}

@MainActor
final class LocalSearchCompleter: NSObject, ObservableObject {
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    var queryFragment: String = "" {
        didSet {
            completer.queryFragment = queryFragment
            if queryFragment.isEmpty {
                results = []
            }
        }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
}

extension LocalSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let snapshot = completer.results
        Task { @MainActor in
            self.results = snapshot
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}
