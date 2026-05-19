import AppKit
import HengqinCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: ResidencyStore
    @ObservedObject var sync: iCloudSyncManager
    @ObservedObject var profileStore: ProfileStore

    @State private var pendingImport: PendingImport?
    @State private var lastError: String?
    @State private var inlineMessage: String?
    @State private var profileSheet: ProfileSheet?
    @State private var profileToDelete: LocationProfile?

    private struct PendingImport: Identifiable {
        let id = UUID()
        let url: URL
        let profile: LocationProfile
    }

    private enum ProfileSheet: Identifiable {
        case create
        case edit(LocationProfile)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let p): return "edit-\(p.id.uuidString)"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                profilesSection
                syncSection
                Spacer(minLength: 0)
                footer
            }
            .padding(22)
        }
        .frame(width: 520, height: 540)
        .background(.background)
        .sheet(item: $profileSheet) { sheet in
            switch sheet {
            case .create:
                ProfileEditorView(mode: .create) { profile in
                    profileStore.add(profile, activate: true)
                }
            case .edit(let profile):
                ProfileEditorView(mode: .edit(profile)) { updated in
                    profileStore.update(updated)
                }
            }
        }
        .confirmationDialog(
            "确认覆盖「\(pendingImport?.profile.name ?? "")」？",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingImport
        ) { pending in
            Button("覆盖导入到「\(pending.profile.name)」", role: .destructive) {
                confirmImport(pending: pending)
            }
            Button("取消", role: .cancel) { pendingImport = nil }
        } message: { pending in
            Text("将用选中的 JSON 替换「\(pending.profile.name)」的全部日记录，原档案中不在导入文件里的日期会被清除。其他坐标档案不受影响。")
        }
        .confirmationDialog(
            "删除档案？",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: profileToDelete
        ) { p in
            Button("删除「\(p.name)」", role: .destructive) {
                _ = profileStore.remove(p.id)
                profileToDelete = nil
            }
            Button("取消", role: .cancel) { profileToDelete = nil }
        } message: { p in
            Text("会同时删除该档案下的所有日记录与 iCloud 数据，无法恢复。\n（坐标 \(String(format: "%.4f", p.latitude)), \(String(format: "%.4f", p.longitude)) · 半径 \(Int(p.radiusKilometers))km）")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("设置")
                .font(.system(size: 17, weight: .semibold))
            Text("每个坐标档案独立存储日记录、独立 iCloud 同步、独立导入导出")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var profilesSection: some View {
        section(title: "坐标档案") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("当前档案")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { profileStore.activeProfile.id },
                        set: { profileStore.setActive($0) }
                    )) {
                        ForEach(profileStore.collection.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(maxWidth: 200)
                    Spacer()
                    Button {
                        profileSheet = .create
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                    .controlSize(.small)
                }

                VStack(spacing: 6) {
                    ForEach(profileStore.collection.profiles) { profile in
                        profileRow(profile)
                    }
                }

                if let inlineMessage {
                    Text(inlineMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                }
                if let lastError {
                    Text(lastError)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func profileRow(_ profile: LocationProfile) -> some View {
        let isActive = profile.id == profileStore.activeProfile.id
        let canDelete = profileStore.collection.profiles.count > 1
        return HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color(red: 0.184, green: 0.561, blue: 0.247) : Color.secondary.opacity(0.4))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if isActive {
                        Text("当前")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(Color(red: 0.184, green: 0.561, blue: 0.247).opacity(0.18))
                            )
                            .foregroundStyle(Color(red: 0.184, green: 0.561, blue: 0.247))
                    }
                }
                Text(String(format: "%.4f°N, %.4f°E · %dkm", profile.latitude, profile.longitude, Int(profile.radiusKilometers)))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                rowIconButton(icon: "square.and.arrow.down", help: "从 JSON 导入到「\(profile.name)」") {
                    triggerImport(into: profile)
                }
                rowIconButton(icon: "square.and.arrow.up", help: "导出「\(profile.name)」为 JSON") {
                    triggerExport(of: profile)
                }
                rowIconButton(icon: "pencil", help: "编辑档案") {
                    profileSheet = .edit(profile)
                }
                rowIconButton(
                    icon: "trash",
                    help: canDelete ? "删除档案" : "至少保留一个档案",
                    tint: canDelete ? .red : Color.secondary.opacity(0.5),
                    disabled: !canDelete
                ) {
                    profileToDelete = profile
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(isActive ? 0.05 : 0.02))
        )
    }

    private func rowIconButton(
        icon: String,
        help: String,
        tint: Color = .secondary,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    private var syncSection: some View {
        section(title: "同步") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { sync.isEnabledByUser },
                    set: { newValue in
                        sync.isEnabledByUser = newValue
                        if newValue { sync.push(records: store.records, force: true) }
                    }
                )) {
                    Text("通过 iCloud 跨设备同步")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    StatusDot(status: sync.status)
                    Text(sync.status.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let last = sync.lastSyncedAt {
                        Text("· 上次同步 \(Self.relativeFormatter.localizedString(for: last, relativeTo: Date()))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        sync.pull(force: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .help("立即拉取 iCloud 数据")
                }

                Text("不同坐标档案的数据各自独立同步（KVS key 加 profile UUID 后缀）。需以**签名 .app + Developer ID provisioning profile** 形式分发，详见 README。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("HengqinTracker · 2026 年度版")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
    }

    // MARK: - Actions

    private func triggerExport(of profile: LocationProfile) {
        lastError = nil
        inlineMessage = nil

        let panel = NSSavePanel()
        panel.title = "导出「\(profile.name)」数据"
        panel.allowedContentTypes = [.json]
        let safeName = profile.name.replacingOccurrences(of: "/", with: "_")
        panel.nameFieldStringValue = "hq-backup-\(safeName)-\(store.today.rawValue).json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try store.exportBackupData(for: profile.id)
            try data.write(to: url, options: .atomic)
            let backup = try DataBackup.decode(data)
            inlineMessage = "已导出「\(profile.name)」\(backup.records.count) 天 → \(url.lastPathComponent)"
        } catch {
            lastError = "导出失败：\(error.localizedDescription)"
        }
    }

    private func triggerImport(into profile: LocationProfile) {
        lastError = nil
        inlineMessage = nil

        let panel = NSOpenPanel()
        panel.title = "选择导入到「\(profile.name)」的 JSON"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImport = PendingImport(url: url, profile: profile)
    }

    private func confirmImport(pending: PendingImport) {
        defer { pendingImport = nil }
        do {
            let data = try Data(contentsOf: pending.url)
            let summary = try store.importBackupReplacingAll(from: data, into: pending.profile.id)
            inlineMessage = summary.shortDescription
        } catch {
            lastError = "导入失败：\(error.localizedDescription)"
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

private struct StatusDot: View {
    let status: iCloudSyncManager.Status

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 3).blur(radius: 0.4))
    }

    private var color: Color {
        switch status {
        case .idle: return Color(red: 0.184, green: 0.561, blue: 0.247)
        case .syncing: return Color(red: 0.95, green: 0.74, blue: 0.24)
        case .error: return Color(red: 0.85, green: 0.33, blue: 0.29)
        case .disabled, .unavailable: return Color.secondary
        }
    }
}
