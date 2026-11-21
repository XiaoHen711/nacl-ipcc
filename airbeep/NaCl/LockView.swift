import SwiftUI

struct LockView: View {
    @EnvironmentObject private var store: LockStore
    @State private var showLockConfirm = false
    @State private var showRestoreConfirm = false
    @State private var showingSetup = false

    var body: some View {
        ZStack {
            Theme.screen.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showingSetup = true
                    } label: {
                        ChannelBanner(state: store.channel)
                    }
                    .buttonStyle(.plain)

                    hero
                    StatusCard(phase: store.phase)
                    formCard

                    Button(action: confirmLock) {
                        lockButtonLabel
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isBusy)

                    Button {
                        showingSetup = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("配对与通道设置")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button {
                        showRestoreConfirm = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text("恢复")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())

                    Text("写入 /var/mobile/Library/Carrier Bundles/iPhone · 完成后设备自动注销")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 26)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .sheet(isPresented: $showingSetup, onDismiss: { store.refreshChannel() }) {
            AirBeepAirliftSetupView()
        }
        .alert("确认写入运营商配置？", isPresented: $showLockConfirm) {
            Button("继续写入") { store.lock() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把 \(store.bundle.id) 写入本机 Carrier Bundles 目录，并注销重载。过程中请勿退出应用。")
        }
        .alert("恢复到系统默认配置？", isPresented: $showRestoreConfirm) {
            Button("恢复", role: .destructive) { store.restore() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会把写入的 bundle 版本号归零，让 CommCenter 回落到系统自带配置，然后注销。卡贴场景下可能再次出现跳激活。")
        }
    }

    // MARK: - 片段

    private var hero: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.26), Theme.accent.opacity(0.03)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 48
                        )
                    )
                    .frame(width: 74, height: 74)
                    .overlay {
                        Circle().strokeBorder(Theme.accent.opacity(0.34), lineWidth: 1)
                    }

                VStack(spacing: 0) {
                    Text("NaCl")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Text("IPCC")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.accent.opacity(0.55))
                }
            }
            .padding(.bottom, 2)

            Text("锁定 IPCC")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)

            Text("固定 SIM 对应的运营商配置，减少夜间或重启后的重新激活。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 292)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("运营商配置")

            Menu {
                bundleMenu
            } label: {
                bundleRow
            }

            Text("Bundle 名称必须对应 /System/Library/Carrier Bundles/iPhone 下的文件夹。")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.horizontal, 2)

            Divider()
                .overlay(Theme.line)
                .padding(.vertical, 12)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent.opacity(0.8))
                    .padding(.top, 2)
                Text("Apple 签名外壳 · 只替换 carrier.plist，signatures 与 *.der.pri 原样保留。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    @ViewBuilder
    private var lockButtonLabel: some View {
        HStack(spacing: 8) {
            if store.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.onAccent)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
            }
            Text(store.isBusy ? "写入中…" : store.lockButtonTitle)
        }
    }

    @ViewBuilder
    private var bundleMenu: some View {
        ForEach(CarrierBundle.presets) { preset in
            Button {
                store.bundleID = preset.id
                store.append(.info, "已选择运营商配置 \(preset.id)")
            } label: {
                if preset.id == store.bundleID {
                    Label("\(preset.id) · \(preset.displayName)", systemImage: "checkmark")
                } else {
                    Text("\(preset.id) · \(preset.displayName)")
                }
            }
        }
    }

    private var bundleRow: some View {
        HStack(spacing: 6) {
            Text(store.bundleID)
                .font(.system(size: 14.5, design: .monospaced))
                .foregroundStyle(Theme.text)
            Text("· \(store.bundle.displayName)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        }
    }

    // MARK: - 辅助

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
            .padding(.bottom, 6)
    }

    private func confirmLock() {
        showLockConfirm = true
    }
}

// MARK: - 状态卡

struct StatusCard: View {
    let phase: LockPhase

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(iconBackground)
                icon
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 12.5, design: subtitleMono ? .monospaced : .default))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !chips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(chips.indices, id: \.self) { index in
                            Chip(text: chips[index].text, mono: chips[index].mono)
                        }
                    }
                    .padding(.top, 5)
                }

                if let progressValue = progress {
                    ProgressBar(value: progressValue)
                }
            }

            Spacer(minLength: 0)
        }
        .card(border: borderColor)
    }

    @ViewBuilder
    private var icon: some View {
        switch phase {
        case .idle:
            Image(systemName: "hourglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
        case .locking, .restoring:
            ProgressView()
                .controlSize(.small)
                .tint(Theme.accent)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.danger)
        }
    }

    private var title: String {
        switch phase {
        case .idle: return "尚未锁定"
        case .locking: return "锁定中…"
        case .locked(let receipt): return "已锁定 · \(receipt.bundleID)"
        case .restoring: return "正在恢复…"
        case .failed: return "写入失败"
        }
    }

    private var subtitle: String {
        switch phase {
        case .idle:
            return "选择运营商配置后写入 Carrier Bundles 目录。"
        case .locking(let step):
            return LockFlow.steps[min(max(step, 0), LockFlow.steps.count - 1)]
        case .locked(let receipt):
            return "\(receipt.imsi.isEmpty ? "配置已写入设备" : receipt.imsi) · 该配置已写入用户域"
        case .restoring(let step):
            return LockFlow.restoreSteps[min(max(step, 0), LockFlow.restoreSteps.count - 1)]
        case .failed(let message):
            return message
        }
    }

    private var subtitleMono: Bool {
        if case .locked = phase { return true }
        return false
    }

    private var chips: [(text: String, mono: Bool)] {
        switch phase {
        case .locked(let receipt):
            return [
                ("airtrafficd", true),
                (Clock.string(receipt.date), true),
                (receipt.verified ? "已验证" : "未校验", false),
            ]
        case .failed:
            return [("可重试", false)]
        default:
            return []
        }
    }

    private var progress: Double? {
        switch phase {
        case .locking(let step):
            return Double(step + 1) / Double(LockFlow.steps.count)
        case .restoring(let step):
            return Double(step + 1) / Double(LockFlow.restoreSteps.count)
        default:
            return nil
        }
    }

    private var borderColor: Color {
        switch phase {
        case .locked: return Theme.accent.opacity(0.3)
        case .failed: return Theme.danger.opacity(0.3)
        default: return Theme.line
        }
    }

    private var iconBackground: Color {
        switch phase {
        case .locked: return Theme.accent.opacity(0.16)
        case .failed: return Theme.danger.opacity(0.14)
        default: return Color.white.opacity(0.05)
        }
    }
}
