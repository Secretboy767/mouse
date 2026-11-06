import SwiftUI
import UIKit

struct MoreView: View {
    @EnvironmentObject private var inspector: InspectorStore
    @State private var exportURL: URL?
    @State private var showingExport = false

    private let destinations = ["Snapshots", "Dataset", "Scan History", "Settings", "About"]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "More Tools",
                         subtitle: "Snapshots · datasets · session history",
                         status: "LOCAL")
                .padding(.horizontal, 15)
                .padding(.top, 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(destinations, id: \.self) { destination in
                        Button {
                            inspector.moreDestination = destination
                        } label: {
                            Text(destination.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(inspector.moreDestination == destination ? Color(hex: 0x111418) : InspectorTheme.muted)
                                .padding(.horizontal, 11)
                                .frame(height: 32)
                                .background(inspector.moreDestination == destination ? InspectorTheme.green : InspectorTheme.secondary,
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
            }
            Group {
                switch inspector.moreDestination {
                case "Dataset": dataset
                case "Scan History": history
                case "Settings": settings
                case "About": about
                default: snapshots
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(InspectorTheme.background)
        .sheet(isPresented: $showingExport) {
            if let exportURL {
                ActivityShareView(items: [exportURL])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var snapshots: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("SNAPSHOT STORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(InspectorTheme.muted)
                    Spacer()
                    Button {
                        inspector.createSnapshot()
                    } label: {
                        Label("Capture", systemImage: "plus")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: 0x111418))
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(InspectorTheme.green, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                if let comparison = inspector.compareLatestSnapshots() {
                    SectionPanel(title: "Latest Snapshot Comparison") {
                        HStack {
                            snapshotMetric("CHANGED", comparison.changed, InspectorTheme.yellow)
                            Spacer()
                            snapshotMetric("SAME", comparison.unchanged, InspectorTheme.green)
                            Spacer()
                            snapshotMetric("ADDED", comparison.added, InspectorTheme.blue)
                            Spacer()
                            snapshotMetric("REMOVED", comparison.removed, InspectorTheme.red)
                        }
                    }
                }
                if inspector.snapshots.isEmpty {
                    SectionPanel(title: "No Snapshots") {
                        Text("Capture copies bytes from the selected registered region and stores a SHA-256 integrity digest.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(InspectorTheme.muted)
                    }
                } else {
                    ForEach(inspector.snapshots) { snapshot in
                        SectionPanel(title: snapshot.name) {
                            dataLine("SOURCE", snapshot.sourceName)
                            dataLine("CAPTURED", snapshot.date.formatted(date: .abbreviated, time: .standard))
                            dataLine("SIZE", "\(snapshot.byteCount) bytes")
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SHA-256").foregroundStyle(InspectorTheme.muted)
                                Text(snapshot.sha256)
                                    .font(.system(size: 8, design: .monospaced))
                                    .textSelection(.enabled)
                                    .foregroundStyle(InspectorTheme.green)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack {
                                Button {
                                    exportURL = inspector.exportSnapshot(snapshot)
                                    showingExport = exportURL != nil
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    inspector.deleteSnapshot(snapshot.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .foregroundStyle(InspectorTheme.red)
                                }
                            }
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: 1050)
            .frame(maxWidth: .infinity)
        }
    }

    private var dataset: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(inspector.sources) { source in
                    SectionPanel(title: source.name) {
                        dataLine("CLASSIFICATION", "Application-owned simulation")
                        dataLine("REGION SIZE", "\(source.size) bytes")
                        Text(source.detail)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(InspectorTheme.muted)
                        Button {
                            inspector.selectSource(source.id)
                            inspector.section = .scanner
                        } label: {
                            Label("Inspect this region", systemImage: "scope")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(InspectorTheme.green)
                        }
                    }
                }
                SectionPanel(title: "Numeric Lab Controls") {
                    Text("Mutations apply to the real library-owned test buffer. Scan results remain tied to buffer offsets.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted)
                    HStack {
                        actionButton("− 1", symbol: "minus") { inspector.changeTestValue(by: -1) }
                        actionButton("+ 1", symbol: "plus") { inspector.changeTestValue(by: 1) }
                        actionButton("Reset", symbol: "arrow.counterclockwise") { inspector.resetDataset() }
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: 1050)
            .frame(maxWidth: .infinity)
        }
    }

    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if inspector.scanHistory.isEmpty {
                    SectionPanel(title: "No Scan History") {
                        Text("Completed scan operations are recorded here.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(InspectorTheme.muted)
                    }
                } else {
                    ForEach(inspector.scanHistory) { step in
                        SectionPanel(title: step.condition) {
                            dataLine("VALUE", step.value)
                            dataLine("REMAINING CANDIDATES", "\(step.candidates)")
                            dataLine("DURATION", String(format: "%.4f s", step.duration))
                            dataLine("TIME", step.date.formatted(date: .abbreviated, time: .standard))
                        }
                    }
                }
            }
            .padding(15)
        }
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionPanel(title: "Runtime Policy") {
                    settingRow("Inspection scope", "Registered app-owned buffers only", "checkmark.shield", InspectorTheme.green)
                    settingRow("Background refresh", "Suspended by iOS lifecycle", "moon.zzz", InspectorTheme.yellow)
                    settingRow("Candidate page cap", "250 rows", "list.number", InspectorTheme.blue)
                }
                SectionPanel(title: "Floating Quick Access") {
                    settingRow("Overlay", "In-app floating navigation control", "scope", InspectorTheme.green)
                    Text("The draggable button position is stored locally. The control remains inside this app and is not a system-wide overlay.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted)
                }
                SectionPanel(title: "Refresh Interval") {
                    Text("Choose monitoring refresh from the Monitor section. iOS may suspend refresh while the app is backgrounded.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted)
                }
            }
            .padding(15)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(title: "Memory Inspector", subtitle: "Native runtime analysis suite")
            SectionPanel(title: "Platform Boundaries") {
                Text("This app reads only buffers explicitly copied into its own native engine. iOS does not grant ordinary apps unrestricted access to other apps' process memory.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(InspectorTheme.primary)
                Text("Monitoring is foreground-only. The floating control is in-app and does not inject into or conceal itself from other apps.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(InspectorTheme.muted)
            }
            Spacer()
        }
        .padding(15)
    }

    private func dataLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(InspectorTheme.muted)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(InspectorTheme.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 9, design: .monospaced))
    }

    private func snapshotMetric(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(InspectorTheme.muted)
            Text("\(value)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(tint)
        }
    }

    private func settingRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(InspectorTheme.primary)
                Text(subtitle).font(.system(size: 9, design: .monospaced)).foregroundStyle(InspectorTheme.muted)
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(InspectorTheme.green)
                .padding(.horizontal, 9)
                .frame(height: 34)
                .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                        y: controller.view.bounds.midY,
                                        width: 0,
                                        height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
