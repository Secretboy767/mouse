import SwiftUI

private enum QuickDestination: String, CaseIterable, Identifiable, Hashable {
    case scanner = "Scanner"
    case results = "Results"
    case monitor = "Monitor"
    case viewer = "Memory Viewer"
    case snapshots = "Snapshots"
    case settings = "Settings"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .scanner: "waveform.path.ecg"
        case .results: "list.number"
        case .monitor: "eye"
        case .viewer: "memorychip"
        case .snapshots: "square.stack.3d.up"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct FloatingOverlayController: View {
    @EnvironmentObject private var inspector: InspectorStore
    @AppStorage("inspector.overlay.x") private var savedX = -1.0
    @AppStorage("inspector.overlay.y") private var savedY = -1.0
    @State private var expanded = false
    @State private var dragTranslation = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let initialX = savedX < 0 ? width - 160 : CGFloat(savedX) * width
            let initialY = savedY < 0 ? height - 178 : CGFloat(savedY) * height
            let currentX = clamp(initialX + dragTranslation.width, low: 160, high: max(160, width - 160))
            let currentY = clamp(initialY + dragTranslation.height, low: 130, high: max(130, height - 130))

            ZStack(alignment: .topLeading) {
                if expanded {
                    radialMenu
                        .transition(.scale(scale: 0.72, anchor: .bottomTrailing).combined(with: .opacity))
                }
                floatingButton { translation in
                    savedX = Double(clamp(initialX + translation.width, low: 160, high: max(160, width - 160)) / width)
                    savedY = Double(clamp(initialY + translation.height, low: 130, high: max(130, height - 130)) / height)
                }
                .position(x: 277, y: 233)
            }
            .frame(width: 320, height: 260)
            .position(x: currentX, y: currentY)
            .animation(.spring(response: 0.34, dampingFraction: 0.8), value: expanded)
            .onChange(of: geometry.size) { _ in
                guard savedX >= 0, savedY >= 0 else { return }
                savedX = min(1, max(0, savedX))
                savedY = min(1, max(0, savedY))
            }
            .accessibilityElement(children: .contain)
        }
        .allowsHitTesting(true)
    }

    private func floatingButton(onDragEnded: @escaping (CGSize) -> Void) -> some View {
        Button {
            withAnimation { expanded.toggle() }
        } label: {
            Image(systemName: expanded ? "xmark" : "scope")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(InspectorTheme.green)
                .frame(width: 54, height: 54)
                .background(Color(hex: 0x151A20), in: Circle())
                .overlay(Circle().stroke(InspectorTheme.border, lineWidth: 1.2))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Close quick menu" : "Open quick menu")
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { gesture in
                    dragTranslation = gesture.translation
                }
                .onEnded { gesture in
                    onDragEnded(gesture.translation)
                    dragTranslation = .zero
                }
        )
        .onTapGesture(count: 2) {
            select(.scanner)
        }
        .onLongPressGesture(minimumDuration: 0.55) {
            withAnimation { expanded = true }
            inspector.moreDestination = "Settings"
            inspector.section = .more
        }
    }

    private var radialMenu: some View {
        ZStack {
            Circle()
                .fill(InspectorTheme.panel.opacity(0.56))
                .frame(width: 220, height: 220)
                .overlay(Circle().stroke(InspectorTheme.border.opacity(0.5), lineWidth: 1))
                .position(x: 225, y: 215)
                .allowsHitTesting(false)
            ForEach(QuickDestination.allCases) { destination in
                radialButton(destination)
                    .position(radialPoint(destination))
                    .transition(.scale(scale: 0.35, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .frame(width: 320, height: 260)
        .accessibilityElement(children: .contain)
    }

    private func radialButton(_ destination: QuickDestination) -> some View {
        Button {
            select(destination)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(InspectorTheme.green)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: 0x171C22), in: Circle())
                    .overlay(Circle().stroke(InspectorTheme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                Text(destination.rawValue == "Memory Viewer" ? "Viewer" : destination.rawValue)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(InspectorTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 72, height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.rawValue)
    }

    private func radialPoint(_ destination: QuickDestination) -> CGPoint {
        let angles: [CGFloat] = [190, 206, 222, 238, 254, 270]
        let index = QuickDestination.allCases.firstIndex(of: destination) ?? 0
        let angle = angles[index] * .pi / 180
        let radius: CGFloat = 100
        return CGPoint(x: 277 + cos(angle) * radius,
                       y: 233 + sin(angle) * radius)
    }

    private func select(_ destination: QuickDestination) {
        switch destination {
        case .scanner: inspector.section = .scanner
        case .results: inspector.section = .results
        case .monitor: inspector.section = .monitor
        case .viewer: inspector.section = .viewer
        case .snapshots:
            inspector.moreDestination = "Snapshots"
            inspector.section = .more
        case .settings:
            inspector.moreDestination = "Settings"
            inspector.section = .more
        }
        withAnimation { expanded = false }
    }

    private func clamp(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }
}
