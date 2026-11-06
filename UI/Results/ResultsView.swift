import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var inspector: InspectorStore
    @State private var query = ""
    @State private var selected = Set<UInt64>()
    @State private var selectedCandidates: [UInt64: NativeCandidate] = [:]
    @State private var sortByOffset = true
    @State private var inspected: NativeCandidate?
    @State private var jumpPage = ""

    private var rows: [NativeCandidate] {
        let filtered = inspector.visibleCandidates.filter {
            query.isEmpty ||
            String(format: "0x%llX", $0.offset).localizedCaseInsensitiveContains(query) ||
            inspector.valueKind.decode($0.bytes, byteOrder: inspector.byteOrder).localizedCaseInsensitiveContains(query)
        }
        return sortByOffset ? filtered.sorted { $0.offset < $1.offset } : filtered.sorted {
            inspector.valueKind.decode($0.bytes, byteOrder: inspector.byteOrder) <
                inspector.valueKind.decode($1.bytes, byteOrder: inspector.byteOrder)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Scan Results",
                         subtitle: inspector.selectedSource?.name ?? "No source selected",
                         status: "\(inspector.candidateCount) TOTAL")
                .padding(.horizontal, 16)
                .padding(.top, 18)
            searchAndActions
            columnHeaders
            if rows.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(InspectorTheme.muted)
                    Text("NO VISIBLE CANDIDATES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted)
                    Text(inspector.candidateCount == 0
                         ? "Run a scan to populate this result set."
                         : "No candidates on this page match the search.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { candidate in
                            HStack(spacing: 8) {
                                Button {
                                    toggle(candidate)
                                } label: {
                                    Image(systemName: selected.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(candidate.id) ? InspectorTheme.green : InspectorTheme.muted)
                                        .frame(width: 26, height: 38)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    inspected = candidate
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(String(format: "0x%08llX", candidate.offset))
                                            .frame(width: 98, alignment: .leading)
                                            .foregroundStyle(InspectorTheme.blue)
                                        Text(inspector.valueKind.title)
                                            .frame(width: 50, alignment: .leading)
                                            .foregroundStyle(InspectorTheme.muted)
                                        Text(inspector.valueKind.decode(candidate.bytes, byteOrder: inspector.byteOrder))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundStyle(InspectorTheme.primary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Circle().fill(InspectorTheme.green).frame(width: 6, height: 6)
                            }
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 13)
                            .frame(height: 43)
                            .background(selected.contains(candidate.id) ? InspectorTheme.green.opacity(0.06) : .clear)
                        Divider().overlay(InspectorTheme.border.opacity(0.65))
                            .padding(.leading, 42)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !selected.isEmpty {
                        Button {
                            for item in selectedCandidates.values {
                                inspector.addToWatchlist(item)
                            }
                            selected.removeAll()
                            selectedCandidates.removeAll()
                            inspector.section = .monitor
                        } label: {
                            Label("WATCH \(selected.count)", systemImage: "eye")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: 0x111418))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(InspectorTheme.green, in: Capsule())
                                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                        }
                        .padding(14)
                    }
                }
            }
            pagination
        }
        .background(InspectorTheme.background)
        .sheet(item: $inspected) { candidate in
            CandidateInspectorView(candidate: candidate)
                .environmentObject(inspector)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var searchAndActions: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(InspectorTheme.muted)
            TextField("Search current page", text: $query)
                .font(.system(size: 11, design: .monospaced))
                .autocorrectionDisabled()
            Menu {
                Button("Sort by offset") { sortByOffset = true }
                Button("Sort by value") { sortByOffset = false }
                Button("Select visible") {
                    for candidate in rows {
                        selected.insert(candidate.id)
                        selectedCandidates[candidate.id] = candidate
                    }
                }
                Button("Clear selection") {
                    selected.removeAll()
                    selectedCandidates.removeAll()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(InspectorTheme.blue)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(InspectorTheme.secondary, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7).stroke(InspectorTheme.border, lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Text("SEL").frame(width: 22)
            Text("OFFSET").frame(width: 98, alignment: .leading)
            Text("TYPE").frame(width: 50, alignment: .leading)
            Text("VALUE").frame(maxWidth: .infinity, alignment: .leading)
            Text("STATE").frame(width: 32, alignment: .trailing)
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .tracking(0.7)
        .foregroundStyle(InspectorTheme.muted)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Color(hex: 0x171B20))
    }

    private var pagination: some View {
        HStack(spacing: 12) {
            Button {
                inspector.loadPage(inspector.pageIndex - 1)
            } label: {
                Image(systemName: "chevron.left").frame(width: 35, height: 34)
            }
            .disabled(inspector.pageIndex == 0)
            Text("PAGE \(inspector.pageIndex + 1) / \(inspector.pageCount)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(InspectorTheme.primary)
            Button {
                inspector.loadPage(inspector.pageIndex + 1)
            } label: {
                Image(systemName: "chevron.right").frame(width: 35, height: 34)
            }
            .disabled(inspector.pageIndex + 1 >= inspector.pageCount)
            TextField("Page", text: $jumpPage)
                .keyboardType(.numberPad)
                .font(.system(size: 9, design: .monospaced))
                .frame(width: 38)
                .textFieldStyle(.roundedBorder)
            Button("GO") {
                guard let oneBased = UInt64(jumpPage), oneBased > 0 else { return }
                inspector.loadPage(min(inspector.pageCount - 1, oneBased - 1))
                jumpPage = ""
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .disabled(jumpPage.isEmpty)
            Spacer()
            Text("\(inspector.candidates.count) ROWS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(InspectorTheme.muted)
        }
        .buttonStyle(.plain)
        .foregroundStyle(InspectorTheme.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(InspectorTheme.secondary)
        .overlay(alignment: .top) { Rectangle().fill(InspectorTheme.border).frame(height: 1) }
    }

    private func toggle(_ candidate: NativeCandidate) {
        if selected.remove(candidate.id) != nil {
            selectedCandidates.removeValue(forKey: candidate.id)
        } else {
            selectedCandidates[candidate.id] = candidate
        }
    }
}

struct CandidateInspectorView: View {
    @EnvironmentObject private var inspector: InspectorStore
    let candidate: NativeCandidate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(title: "Candidate Inspector", subtitle: "Stable ID \(candidate.id)")
                    SectionPanel(title: "Current Inspection") {
                        detail("SOURCE", inspector.selectedSource?.name ?? "Unavailable")
                        detail("RELATIVE OFFSET", String(format: "0x%08llX", candidate.offset))
                        detail("DATA TYPE", inspector.valueKind.title)
                        detail("CURRENT VALUE", inspector.valueKind.decode(candidate.bytes, byteOrder: inspector.byteOrder))
                        detail("BYTES", candidate.bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
                        detail("ALIGNMENT", "\(inspector.valueKind.width)-byte")
                    }
                    Button {
                        inspector.addToWatchlist(candidate)
                        dismiss()
                    } label: {
                        Label("Add to Watchlist", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: 0x111418))
                            .background(InspectorTheme.green, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(16)
            }
            .background(InspectorTheme.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(InspectorTheme.green)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(InspectorTheme.muted)
            Spacer()
            Text(value).foregroundStyle(InspectorTheme.primary).multilineTextAlignment(.trailing)
        }
        .font(.system(size: 11, design: .monospaced))
    }
}
