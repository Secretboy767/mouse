import Charts
import SwiftUI

struct MonitorView: View {
    @EnvironmentObject private var inspector: InspectorStore

    private let intervals: [(String, Double)] = [
        ("Manual", 0), ("100 ms", 0.1), ("250 ms", 0.25), ("500 ms", 0.5),
        ("1 sec", 1), ("2 sec", 2), ("5 sec", 5)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ScreenHeader(title: "Live Monitor",
                                 subtitle: "Values read from registered owned buffers",
                                 status: inspector.monitoringPaused ? "PAUSED" : "ACTIVE")
                    controls
                    if inspector.watchlist.isEmpty {
                        SectionPanel(title: "Watchlist") {
                            VStack(spacing: 9) {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 22))
                                    .foregroundStyle(InspectorTheme.muted)
                                Text("WATCHLIST EMPTY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(0.8)
                                    .foregroundStyle(InspectorTheme.muted)
                                Text("Add candidates from Scanner or Results.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(InspectorTheme.muted.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    } else {
                        ForEach(inspector.watchlist) { item in
                            watchRow(item)
                        }
                    }
                    if let first = inspector.watchlist.first, !first.history.isEmpty {
                        historyPanel(first)
                    }
                    if let error = inspector.lastError {
                        StatusBanner(message: error)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 18)
                .padding(.bottom, 25)
                .frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
            }
        }
        .background(InspectorTheme.background)
        .task(id: inspector.refreshSeconds) {
            guard inspector.refreshSeconds > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(inspector.refreshSeconds * 1_000_000_000))
                if !Task.isCancelled {
                    inspector.refreshWatchlist()
                }
            }
        }
    }

    private var controls: some View {
        SectionPanel(title: "Refresh Scheduler") {
            HStack(spacing: 8) {
                Menu {
                    ForEach(0..<intervals.count, id: \.self) { index in
                        let item = intervals[index]
                        Button(item.0) { inspector.refreshSeconds = item.1 }
                    }
                } label: {
                    HStack {
                        Image(systemName: "timer")
                        Text(intervals.first(where: { $0.1 == inspector.refreshSeconds })?.0 ?? "Manual")
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(InspectorTheme.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 37)
                    .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                }
                Button {
                    inspector.monitoringPaused.toggle()
                } label: {
                    Label(inspector.monitoringPaused ? "Resume" : "Pause",
                          systemImage: inspector.monitoringPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(InspectorTheme.blue)
                        .padding(.horizontal, 10)
                        .frame(height: 37)
                        .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                }
                Button {
                    inspector.refreshWatchlist(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(InspectorTheme.green)
                        .frame(width: 38, height: 37)
                        .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                }
                .accessibilityLabel("Refresh all monitored values")
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    for value in inspector.watchlist {
                        inspector.removeFromWatchlist(value.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(InspectorTheme.red)
                        .frame(width: 34, height: 37)
                }
                .accessibilityLabel("Clear watchlist")
            }
        }
    }

    private func watchRow(_ item: WatchedValue) -> some View {
        let currentValue = Double(item.current) ?? 0
        let previousValue = Double(item.previous) ?? currentValue
        let tint = currentValue > previousValue
            ? InspectorTheme.green
            : currentValue < previousValue ? InspectorTheme.red : InspectorTheme.muted

        return SectionPanel(title: "\(item.sourceName) · \(item.kind.value.title)") {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "0x%08llX", item.offset))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(InspectorTheme.blue)
                    Text("ID \(item.id)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted)
                }
                Spacer(minLength: 0)
                valueColumn("PREVIOUS", item.previous, color: InspectorTheme.muted)
                valueColumn("CURRENT", item.current, color: tint)
                valueColumn("DELTA", String(format: "%+.4g", currentValue - previousValue), color: tint)
                Button {
                    inspector.removeFromWatchlist(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(InspectorTheme.muted)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Remove monitored candidate")
            }
        }
    }

    private func valueColumn(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(InspectorTheme.muted)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func historyPanel(_ item: WatchedValue) -> some View {
        SectionPanel(title: "Value History · \(item.sourceName)") {
            Chart(item.history) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(InspectorTheme.green)
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(InspectorTheme.green.opacity(0.1))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(InspectorTheme.border)
                    AxisValueLabel().foregroundStyle(InspectorTheme.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(InspectorTheme.border)
                    AxisValueLabel().foregroundStyle(InspectorTheme.muted)
                }
            }
            .frame(height: 160)

            let values = item.history.map(\.value)
            HStack {
                stat("MIN", values.min().map { String(format: "%.3g", $0) } ?? "—")
                Spacer()
                stat("MAX", values.max().map { String(format: "%.3g", $0) } ?? "—")
                Spacer()
                stat("AVG", values.isEmpty ? "—" : String(format: "%.3g", values.reduce(0, +) / Double(values.count)))
                Spacer()
                stat("SAMPLES", "\(values.count)")
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(InspectorTheme.muted)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(InspectorTheme.primary)
        }
    }
}
