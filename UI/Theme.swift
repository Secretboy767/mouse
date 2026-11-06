import SwiftUI

enum InspectorTheme {
    static let background = Color(hex: 0x111418)
    static let secondary = Color(hex: 0x191E24)
    static let panel = Color(hex: 0x20262E)
    static let border = Color(hex: 0x303842)
    static let primary = Color(hex: 0xE7EAEE)
    static let muted = Color(hex: 0x929BA6)
    static let green = Color(hex: 0x42C77A)
    static let red = Color(hex: 0xF06464)
    static let blue = Color(hex: 0x55A5EF)
    static let yellow = Color(hex: 0xE9BD57)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String
    var status: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(InspectorTheme.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(InspectorTheme.muted)
            }
            Spacer(minLength: 8)
            if let status {
                HStack(spacing: 6) {
                    Circle().fill(InspectorTheme.green).frame(width: 6, height: 6)
                    Text(status.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(InspectorTheme.green)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(InspectorTheme.green.opacity(0.09), in: Capsule())
            }
        }
        .padding(.bottom, 8)
    }
}

struct SectionPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(InspectorTheme.muted)
                Spacer()
            }
            content
        }
        .padding(15)
        .background(InspectorTheme.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(InspectorTheme.border, lineWidth: 1)
        }
    }
}

struct MonospacedField: View {
    let title: String
    @Binding var text: String
    var prompt = "Value"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(InspectorTheme.muted)
            TextField(prompt, text: $text)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 11)
                .frame(minHeight: 42)
                .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6).stroke(InspectorTheme.border, lineWidth: 1)
                }
                .foregroundStyle(InspectorTheme.primary)
        }
    }
}

struct StatusBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(InspectorTheme.yellow)
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(InspectorTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(InspectorTheme.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7).stroke(InspectorTheme.yellow.opacity(0.35), lineWidth: 1)
        }
    }
}
