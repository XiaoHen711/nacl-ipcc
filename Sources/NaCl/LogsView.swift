import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: LockStore

    var body: some View {
        ZStack {
            Theme.screen.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("运行日志")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Chip(text: "\(store.logs.count) 条")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    if store.logs.isEmpty {
                        Text("还没有日志，先做一次锁定试试。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.logs.reversed())) { entry in
                                LogRow(entry: entry)
                                Rectangle()
                                    .fill(Color.white.opacity(0.035))
                                    .frame(height: 1)
                            }
                        }
                        .padding(.vertical, 4)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.line, lineWidth: 1)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                    }
                }

                HStack(spacing: 10) {
                    ShareLink(item: store.exportText) {
                        Text("导出日志")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Theme.text.opacity(0.85))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.035))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Theme.line, lineWidth: 1)
                            }
                    }

                    Button {
                        store.clearLogs()
                    } label: {
                        Text("清除")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Theme.text.opacity(0.85))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.035))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Theme.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                Text("真实版本会把同一份日志镜像到 /var/mobile/Library/Logs/NaCl/。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Clock.string(entry.time))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.faint)

            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .padding(.top, 5)

            Text(entry.text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.text.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var dotColor: Color {
        switch entry.level {
        case .info: return Color(hex: 0x62C9F5)
        case .ok: return Theme.accent
        case .warn: return Theme.warn
        case .error: return Theme.danger
        }
    }
}
