import SwiftUI

struct MainInterface: View {
    @EnvironmentObject private var inspector: InspectorStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    sidebar
                        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
                } detail: {
                    selectedScreen
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                VStack(spacing: 0) {
                    selectedScreen
                    bottomNavigation
                }
            }
        }
        .background(InspectorTheme.background.ignoresSafeArea())
        .overlay {
            FloatingOverlayController()
                .environmentObject(inspector)
        }
        .alert("Inspector", isPresented: Binding(
            get: { inspector.lastError != nil },
            set: { if !$0 { inspector.lastError = nil } }
        )) {
            Button("Dismiss", role: .cancel) { inspector.lastError = nil }
        } message: {
            Text(inspector.lastError ?? "")
        }
        .tint(InspectorTheme.green)
    }

    private var sidebar: some View {
        List {
            Section {
                ForEach(MainSection.allCases) { section in
                    Button {
                        inspector.section = section
                    } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .foregroundStyle(inspector.section == section ? InspectorTheme.green : InspectorTheme.primary)
                    }
                }
            } header: {
                Text("MEMORY INSPECTOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
            }
            Section {
                Label("App-owned test regions", systemImage: "checkmark.shield")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(InspectorTheme.green)
            } header: {
                Text("SCOPE")
            }
        }
        .scrollContentBackground(.hidden)
        .background(InspectorTheme.background)
        .listStyle(.sidebar)
        .tint(InspectorTheme.green)
    }

    @ViewBuilder
    private var selectedScreen: some View {
        switch inspector.section {
        case .scanner: ScannerView()
        case .results: ResultsView()
        case .monitor: MonitorView()
        case .viewer: HexViewerView()
        case .more: MoreView()
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            ForEach(MainSection.allCases) { section in
                Button {
                    inspector.section = section
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 16, weight: .medium))
                        Text(section == .viewer ? "VIEW" : section.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(inspector.section == section ? InspectorTheme.green : InspectorTheme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .background(InspectorTheme.secondary)
        .overlay(alignment: .top) {
            Rectangle().fill(InspectorTheme.border).frame(height: 1)
        }
    }
}
