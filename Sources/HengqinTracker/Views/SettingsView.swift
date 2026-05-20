import AppKit
import HengqinCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: ResidencyStore
    @ObservedObject var sync: iCloudSyncManager
    @ObservedObject var profileStore: ProfileStore

    @StateObject private var launchManager = LaunchAtLoginManager()
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
        ZStack {
            // Same translucent theme gradient as the dashboard panel so the
            // window feels like a continuation of the popover.
            store.theme.background
                .opacity(0.42)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroHeader
                    backupCard
                    profilesCard
                    syncCard
                    launchCard
                    aboutFooter
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 620, idealHeight: 720)
        .onAppear { launchManager.refresh() }
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

    // MARK: - Hero header

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.239, green: 0.753, blue: 0.478),
                            Color(red: 0.122, green: 0.478, blue: 0.298)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color(red: 0.122, green: 0.478, blue: 0.298).opacity(0.30), radius: 6, x: 0, y: 2)
                Text("横")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("一年几天 · 设置")
                    .font(.system(size: 17, weight: .semibold))
                Text("管理坐标档案、数据备份与 iCloud 同步")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Backup hero card (primary import/export entry)

    private var backupCard: some View {
        let activeProfile = profileStore.activeProfile
        let recordCount = store.records.count

        return CardSection(title: "数据备份", subtitle: "导入会完全覆盖目标档案，导出生成可跨设备分享的 JSON。") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("当前档案")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(activeProfile.name)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("· \(recordCount) 天")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                }

                HStack(spacing: 10) {
                    BackupActionButton(
                        title: "导入备份…",
                        systemImage: "square.and.arrow.down.on.square",
                        description: "从 JSON 替换当前档案",
                        prominent: true
                    ) {
                        triggerImport(into: activeProfile)
                    }

                    BackupActionButton(
                        title: "导出当前档案…",
                        systemImage: "square.and.arrow.up.on.square",
                        description: "保存为 .json 备份",
                        prominent: false
                    ) {
                        triggerExport(of: activeProfile)
                    }
                }

                if let inlineMessage {
                    statusBanner(
                        icon: "checkmark.circle.fill",
                        text: inlineMessage,
                        tint: Color(red: 0.184, green: 0.561, blue: 0.247)
                    )
                }
                if let lastError {
                    statusBanner(
                        icon: "exclamationmark.triangle.fill",
                        text: lastError,
                        tint: Color(red: 0.85, green: 0.33, blue: 0.29)
                    )
                }

                Text("有多个坐标档案？也可在下方「坐标档案」中对任意档案单独导入 / 导出。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusBanner(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.30), lineWidth: 0.6)
        )
    }

    // MARK: - Profiles

    private var profilesCard: some View {
        CardSection(
            title: "坐标档案",
            subtitle: "每个档案独立存储日记录、独立 iCloud 同步、独立导入导出。",
            trailing: AnyView(
                Button {
                    profileSheet = .create
                } label: {
                    Label("新增档案", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            )
        ) {
            VStack(spacing: 6) {
                ForEach(profileStore.collection.profiles) { profile in
                    profileRow(profile)
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold))
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
                Text(String(format: "%.4f°N, %.4f°E · %d km", profile.latitude, profile.longitude, Int(profile.radiusKilometers)))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if !isActive {
                Button("切换") {
                    profileStore.setActive(profile.id)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }

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
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isActive ? 0.07 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(isActive ? 0.10 : 0.05), lineWidth: 0.5)
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
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    // MARK: - Sync

    private var syncCard: some View {
        CardSection(
            title: "iCloud 同步",
            subtitle: "需以签名 .app + Developer ID provisioning profile 形式分发，详见 README。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { sync.isEnabledByUser },
                    set: { newValue in
                        sync.isEnabledByUser = newValue
                        if newValue { sync.push(records: store.records, force: true) }
                    }
                )) {
                    Text("通过 iCloud 跨设备同步")
                        .font(.system(size: 12.5))
                }
                .toggleStyle(.switch)
                .controlSize(.regular)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    StatusDot(status: sync.status)
                    Text(sync.status.summary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    if let last = sync.lastSyncedAt {
                        Text("· 上次同步 \(Self.relativeFormatter.localizedString(for: last, relativeTo: Date()))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        sync.pull(force: true)
                    } label: {
                        Label("立即拉取", systemImage: "arrow.clockwise")
                            .font(.system(size: 11.5))
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .help("立即拉取 iCloud 数据")
                }

                Text("不同坐标档案的数据各自独立同步（KVS key 加 profile UUID 后缀）。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Launch

    private var launchCard: some View {
        CardSection(
            title: "启动",
            subtitle: "通过 macOS ServiceManagement 注册为登录项，仅签名 .app 形式生效。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { launchManager.isEnabled },
                    set: { launchManager.setEnabled($0) }
                )) {
                    Text("登录时自动启动")
                        .font(.system(size: 12.5))
                }
                .toggleStyle(.switch)
                .controlSize(.regular)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(launchStatusColor)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(launchStatusColor.opacity(0.25), lineWidth: 3).blur(radius: 0.4))
                    Text(launchManager.statusSummary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if launchManager.requiresUserApproval {
                        Button {
                            launchManager.openLoginItemsSettings()
                        } label: {
                            Label("打开系统设置", systemImage: "gear")
                                .font(.system(size: 11.5))
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }

                if let err = launchManager.lastError {
                    statusBanner(
                        icon: "exclamationmark.triangle.fill",
                        text: err,
                        tint: Color(red: 0.85, green: 0.33, blue: 0.29)
                    )
                }
            }
        }
    }

    private var launchStatusColor: Color {
        switch launchManager.status {
        case .enabled: return Color(red: 0.184, green: 0.561, blue: 0.247)
        case .requiresApproval: return Color(red: 0.95, green: 0.74, blue: 0.24)
        case .notFound: return Color(red: 0.85, green: 0.33, blue: 0.29)
        case .notRegistered: return .secondary
        @unknown default: return .secondary
        }
    }

    // MARK: - Footer

    private var aboutFooter: some View {
        HStack {
            Text("一年几天 · DaysHere · 2026 年度版")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 4)
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

// MARK: - Reusable card

private struct CardSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if let trailing { trailing }
            }

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidPanel(cornerRadius: 12)
        }
    }
}

// MARK: - Backup action button

private struct BackupActionButton: View {
    let title: String
    let systemImage: String
    let description: String
    let prominent: Bool
    let action: () -> Void

    @State private var hovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(description)
                        .font(.system(size: 10.5))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(prominent ? Color.white.opacity(0.15) : Color.primary.opacity(0.10), lineWidth: 0.6)
            )
            .shadow(color: prominent ? Color.accentColor.opacity(0.28) : .clear, radius: 6, x: 0, y: 2)
            .scaleEffect(hovering ? 1.015 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
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
