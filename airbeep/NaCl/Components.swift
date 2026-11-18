import SwiftUI

enum Clock {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func string(_ date: Date) -> String {
        formatter.string(from: date)
    }
}

struct CardStyle: ViewModifier {
    var border: Color = Theme.line

    func body(content: Content) -> some View {
        content
            .padding(15)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.035), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
    }
}

extension View {
    func card(border: Color = Theme.line) -> some View {
        modifier(CardStyle(border: border))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15.5, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x49EC9C), Theme.accentDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Theme.accent.opacity(0.35), radius: 16, x: 0, y: 8)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15.5, weight: .medium))
            .foregroundStyle(Theme.text.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.09 : 0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.line, lineWidth: 1)
                    }
            }
    }
}

struct Chip: View {
    let text: String
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: mono ? .monospaced : .default))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
    }
}

/// 顶部通道提示条：真实反映配对文件 / LocalDevVPN / 注入入口的状态。
struct ChannelBanner: View {
    let state: ChannelState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: dotColor.opacity(0.8), radius: 4)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(dotColor.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    dotColor.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
        }
    }

    private var text: String {
        switch state {
        case .unknown: return "正在检测通道…"
        case .ready(let detail): return detail
        case .problem(let detail): return detail
        }
    }

    private var dotColor: Color {
        switch state {
        case .unknown: return Theme.faint
        case .ready: return Theme.accent
        case .problem: return Theme.warn
        }
    }
}

struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentDeep, Theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 4)
        .padding(.top, 8)
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.accent.opacity(0.9))
    }
}
