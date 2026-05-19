import CoreLocation
import HengqinCore
import SwiftUI

struct ProfileEditorView: View {
    enum Mode {
        case create
        case edit(LocationProfile)
    }

    let mode: Mode
    var onCommit: (LocationProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var radiusText: String
    @State private var validationError: String?
    @State private var showingMapPicker: Bool = false

    init(mode: Mode, onCommit: @escaping (LocationProfile) -> Void) {
        self.mode = mode
        self.onCommit = onCommit
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _latitudeText = State(initialValue: "22.125")
            _longitudeText = State(initialValue: "113.535")
            _radiusText = State(initialValue: "8")
        case .edit(let profile):
            _name = State(initialValue: profile.name)
            _latitudeText = State(initialValue: String(profile.latitude))
            _longitudeText = State(initialValue: String(profile.longitude))
            _radiusText = State(initialValue: String(profile.radiusKilometers))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(isCreate ? "新增坐标档案" : "编辑坐标档案")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Form {
                LabeledField(label: "名称", placeholder: "例如：横琴 / 深圳 / 老家") {
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledField(label: "坐标", placeholder: "") {
                    Button {
                        showingMapPicker = true
                    } label: {
                        Label("在地图上选择…", systemImage: "map")
                            .font(.system(size: 11))
                    }
                    .controlSize(.small)
                }

                LabeledField(label: "纬度 (°N)", placeholder: "22.125") {
                    TextField("", text: $latitudeText)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                }

                LabeledField(label: "经度 (°E)", placeholder: "113.535") {
                    TextField("", text: $longitudeText)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                }

                LabeledField(label: "判定半径 (km)", placeholder: "8") {
                    TextField("", text: $radiusText)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                }
            }
            .formStyle(.columns)

            if let validationError {
                Text(validationError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            Text("纬度范围 -90 ~ 90，经度 -180 ~ 180。判定半径用于 Chrome 扩展或未来的 macOS GPS 采样；macOS 菜单栏版本目前仅做手动标记，不依赖该值。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(isCreate ? "创建" : "保存") {
                    commit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380, height: 400)
        .sheet(isPresented: $showingMapPicker) {
            LocationPickerSheet(
                initialCoordinate: currentCoordinate,
                initialName: name.isEmpty ? nil : name
            ) { picked in
                latitudeText = formatCoord(picked.latitude)
                longitudeText = formatCoord(picked.longitude)
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let label = picked.addressLabel, !label.isEmpty {
                    name = label
                }
            }
        }
    }

    private var currentCoordinate: CLLocationCoordinate2D {
        let lat = Double(latitudeText) ?? 22.125
        let lng = Double(longitudeText) ?? 113.535
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func formatCoord(_ value: Double) -> String {
        // Keep 6 decimal places (~10 cm precision), trim trailing zeros.
        let formatted = String(format: "%.6f", value)
        var trimmed = formatted
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = "请输入名称"
            return
        }
        guard let lat = Double(latitudeText), (-90...90).contains(lat) else {
            validationError = "纬度需为 -90 ~ 90 之间的数字"
            return
        }
        guard let lng = Double(longitudeText), (-180...180).contains(lng) else {
            validationError = "经度需为 -180 ~ 180 之间的数字"
            return
        }
        guard let radius = Double(radiusText), radius > 0, radius < 5000 else {
            validationError = "半径需为 0 ~ 5000 的正数（公里）"
            return
        }

        let profile: LocationProfile
        switch mode {
        case .create:
            profile = LocationProfile(
                name: trimmedName,
                latitude: lat,
                longitude: lng,
                radiusKilometers: radius
            )
        case .edit(let existing):
            profile = LocationProfile(
                id: existing.id,
                name: trimmedName,
                latitude: lat,
                longitude: lng,
                radiusKilometers: radius,
                createdAt: existing.createdAt
            )
        }

        onCommit(profile)
        dismiss()
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    let placeholder: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            content
                .frame(maxWidth: .infinity)
        }
    }
}
