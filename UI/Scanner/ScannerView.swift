import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var inspector: InspectorStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Memory Scanner",
                             subtitle: "Registered buffers / controlled inspection",
                             status: "LOCAL")
                sourcePanel
                configurationPanel
                controls
                summary
                preview
                if let error = inspector.lastError {
                    StatusBanner(message: error)
                }
            }
            .padding(.horizontal, sizeClass == .regular ? 24 : 14)
            .padding(.top, 18)
            .padding(.bottom, 30)
            .frame(maxWidth: 1050)
            .frame(maxWidth: .infinity)
        }
        .background(InspectorTheme.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var sourcePanel: some View {
        SectionPanel(title: "Inspection Source") {
            Menu {
                ForEach(inspector.sources) { source in
                    Button {
                        inspector.selectSource(source.id)
                    } label: {
                        if source.id == inspector.selectedSourceID {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "memorychip")
                        .foregroundStyle(InspectorTheme.green)
                        .frame(width: 32, height: 32)
                        .background(InspectorTheme.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inspector.selectedSource?.name ?? "No registered region")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(InspectorTheme.primary)
                        Text(inspector.selectedSource?.detail ?? "Create or select a test dataset")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(InspectorTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(InspectorTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var configurationPanel: some View {
        SectionPanel(title: "Scan Configuration") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                pickerField(title: "Data Type") {
                    Picker("Data type",
                           selection: Binding(get: { inspector.valueKind },
                                              set: { inspector.selectValueKind($0) })) {
                        ForEach(ValueKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
                pickerField(title: "Condition") {
                    Picker("Condition", selection: $inspector.condition) {
                        ForEach(ScanCondition.allCases) { condition in
                            Text(condition.title).tag(condition)
                        }
                    }
                }
                MonospacedField(title: inspector.condition == .between ? "Lower Value" : "Value",
                                text: $inspector.searchValue,
                                prompt: inspector.condition.needsValue ? "Enter value" : "Not required")
                if inspector.condition == .between {
                    MonospacedField(title: "Upper Value",
                                    text: $inspector.upperValue,
                                    prompt: "Upper bound")
                }
                pickerField(title: "Alignment") {
                    Picker("Alignment",
                           selection: Binding(get: { inspector.alignment },
                                              set: { inspector.selectAlignment($0) })) {
                        ForEach([0, 1, 2, 4, 8].filter { $0 == 0 || $0 <= inspector.valueKind.width }, id: \.self) { value in
                            Text(value == 0 ? "Automatic" : "\(value) byte\(value == 1 ? "" : "s")").tag(value)
                        }
                    }
                }
                pickerField(title: "Byte Order") {
                    Picker("Byte order",
                           selection: Binding(get: { inspector.byteOrder },
                                              set: { inspector.selectByteOrder($0) })) {
                        ForEach(MemoryByteOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                }
            }
            if inspector.valueKind == .float32 || inspector.valueKind == .float64 {
                HStack(spacing: 7) {
                    Image(systemName: "function")
                    Text("FLOAT TOLERANCE")
                    Spacer()
                    Text("0.0001")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(InspectorTheme.muted)
                .padding(.top, 2)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                inspector.runScan(initial: inspector.candidateCount == 0)
            } label: {
                Label(inspector.candidateCount == 0 ? "First Scan" : "Next Scan",
                      systemImage: inspector.candidateCount == 0 ? "play.fill" : "line.3.horizontal.decrease")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: 0x111418))
                    .background(InspectorTheme.green, in: RoundedRectangle(cornerRadius: 7))
            }
            .disabled(inspector.isScanning || inspector.selectedSource == nil)
            .opacity(inspector.isScanning ? 0.6 : 1)

            if inspector.isScanning {
                Button {
                    inspector.cancelScan()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(InspectorTheme.red)
                        .background(InspectorTheme.panel, in: RoundedRectangle(cornerRadius: 7))
                }
                .accessibilityLabel("Cancel scan")
            }

            Button {
                inspector.resetScan()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(InspectorTheme.muted)
                    .background(InspectorTheme.panel, in: RoundedRectangle(cornerRadius: 7))
            }
            .accessibilityLabel("Reset scan")
        }
        .buttonStyle(.plain)
    }

    private var summary: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            metric("CANDIDATES", value: "\(inspector.candidateCount)", symbol: "scope", tint: InspectorTheme.green)
            metric("VISIBLE", value: "\(inspector.candidates.count) / 250", symbol: "list.bullet", tint: InspectorTheme.blue)
            metric("PAGE", value: "\(inspector.pageIndex + 1) / \(inspector.pageCount)", symbol: "rectangle.split.3x1", tint: InspectorTheme.primary)
            metric("LAST SCAN", value: String(format: "%.3f s", inspector.scanDuration), symbol: "timer", tint: InspectorTheme.yellow)
        }
    }

    private var preview: some View {
        SectionPanel(title: "Candidate Preview") {
            if inspector.candidates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 22))
                        .foregroundStyle(InspectorTheme.muted.opacity(0.7))
                    Text(inspector.isScanning ? "SCANNING REGISTERED REGION" : "NO CANDIDATES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(InspectorTheme.muted)
                    Text("Select a source and run an initial scan.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                ForEach(inspector.candidates.prefix(5)) { candidate in
                    CandidateLine(candidate: candidate,
                                  kind: inspector.valueKind,
                                  byteOrder: inspector.byteOrder) {
                        inspector.addToWatchlist(candidate)
                    }
                    if candidate.id != inspector.candidates.prefix(5).last?.id {
                        Divider().overlay(InspectorTheme.border)
                    }
                }
                Button {
                    inspector.section = .results
                } label: {
                    HStack {
                        Text("OPEN ALL RESULTS")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(InspectorTheme.green)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pickerField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(InspectorTheme.muted)
            content()
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tint(InspectorTheme.primary)
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, 9)
                .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6).stroke(InspectorTheme.border, lineWidth: 1)
                }
        }
    }

    private func metric(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(InspectorTheme.muted)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(InspectorTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(InspectorTheme.secondary, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(InspectorTheme.border, lineWidth: 1)
        }
    }
}

struct CandidateLine: View {
    let candidate: NativeCandidate
    let kind: ValueKind
    var byteOrder: MemoryByteOrder = .littleEndian
    var onWatch: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(String(format: "0x%08llX", candidate.offset))
                .frame(width: 100, alignment: .leading)
            Text(kind.title)
                .frame(width: 52, alignment: .leading)
                .foregroundStyle(InspectorTheme.muted)
            Text(kind.decode(candidate.bytes, byteOrder: byteOrder))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(InspectorTheme.primary)
            Button(action: onWatch) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(InspectorTheme.green)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add candidate to watchlist")
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(InspectorTheme.blue)
        .lineLimit(1)
    }
}
