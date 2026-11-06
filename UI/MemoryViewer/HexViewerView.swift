import SwiftUI

struct HexViewerView: View {
    @EnvironmentObject private var inspector: InspectorStore
    @State private var pattern = ""
    @State private var searchMessage: String?

    private var lineCount: Int { (inspector.viewerBytes.count + 15) / 16 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ScreenHeader(title: "Memory Viewer",
                                 subtitle: "Synchronized byte, hex and text inspection",
                                 status: "\(inspector.viewerBytes.count) BYTES")
                    sourceSelector
                    navigationPanel
                    searchPanel
                    viewerPanel
                    if let searchMessage {
                        Text(searchMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(InspectorTheme.blue)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 18)
                .padding(.bottom, 30)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
        }
        .background(InspectorTheme.background)
        .onAppear { inspector.loadViewer() }
    }

    private var sourceSelector: some View {
        SectionPanel(title: "Registered Region") {
            Menu {
                ForEach(inspector.sources) { source in
                    Button(source.name) { inspector.selectSource(source.id) }
                }
            } label: {
                HStack {
                    Image(systemName: "memorychip").foregroundStyle(InspectorTheme.green)
                    Text(inspector.selectedSource?.name ?? "Select source")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(InspectorTheme.primary)
                    Spacer()
                    Text(inspector.selectedSource?.detail ?? "")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(InspectorTheme.muted)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(InspectorTheme.muted)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: inspector.selectedSourceID) { _ in inspector.loadViewer() }
        }
    }

    private var navigationPanel: some View {
        SectionPanel(title: "View Controls") {
            HStack(spacing: 9) {
                MonospacedField(title: "Offset (Hex)", text: $inspector.viewerOffset, prompt: "00000000")
                Menu {
                    ForEach(["Hex", "Binary", "Decimal", "ASCII", "UTF-8", "UTF-16"], id: \.self) { mode in
                        Button(mode) { inspector.viewerMode = mode }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DISPLAY MODE")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(InspectorTheme.muted)
                        Text(inspector.viewerMode)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(InspectorTheme.primary)
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                            .padding(.horizontal, 9)
                            .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .frame(width: 125)
                Button {
                    inspector.loadViewer()
                } label: {
                    Image(systemName: "arrow.right.to.line")
                        .frame(width: 38, height: 40)
                        .foregroundStyle(InspectorTheme.green)
                        .background(InspectorTheme.background, in: RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 17)
                }
                .accessibilityLabel("Navigate to offset")
            }
        }
    }

    private var searchPanel: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(InspectorTheme.muted)
            TextField("Hex bytes e.g. 4D 45 4D", text: $pattern)
                .font(.system(size: 10, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("FIND") { findPattern() }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(InspectorTheme.green)
        }
        .padding(.horizontal, 11)
        .frame(height: 42)
        .background(InspectorTheme.secondary, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7).stroke(InspectorTheme.border, lineWidth: 1)
        }
    }

    private var viewerPanel: some View {
        SectionPanel(title: "Synchronized Bytes") {
            HStack {
                Text("OFFSET").frame(width: 72, alignment: .leading)
                Text(inspector.viewerMode == "Hex" ? "HEX BYTES" : inspector.viewerMode.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("ASCII").frame(width: 72, alignment: .leading)
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(InspectorTheme.muted)
            .padding(.bottom, 2)

            if inspector.viewerBytes.isEmpty {
                Text("Navigate to a valid offset to inspect region bytes.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(InspectorTheme.muted)
                    .padding(.vertical, 18)
            } else {
                ForEach(0..<lineCount, id: \.self) { line in
                    let start = line * 16
                    let end = min(start + 16, inspector.viewerBytes.count)
                    let indices = Array(start..<end)
                    HStack(alignment: .top, spacing: 4) {
                        Text(String(format: "%08llX", (UInt64(inspector.viewerOffset, radix: 16) ?? 0) + UInt64(start)))
                            .frame(width: 72, alignment: .leading)
                            .foregroundStyle(InspectorTheme.muted)
                        HStack(spacing: 2) {
                            ForEach(indices, id: \.self) { index in
                                byteCell(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 0) {
                            ForEach(indices, id: \.self) { index in
                                Button {
                                    inspector.selectedByte = index
                                } label: {
                                    Text(ascii(inspector.viewerBytes[index]))
                                        .font(.system(size: 9, weight: index == inspector.selectedByte ? .bold : .regular, design: .monospaced))
                                        .foregroundStyle(index == inspector.selectedByte ? InspectorTheme.green : InspectorTheme.primary)
                                        .frame(width: 8, height: 22)
                                        .background(index == inspector.selectedByte ? InspectorTheme.green.opacity(0.15) : .clear)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: 72, alignment: .leading)
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }
        }
    }

    private func byteCell(_ index: Int) -> some View {
        Button {
            inspector.selectedByte = index
        } label: {
            Text(byteText(inspector.viewerBytes[index]))
                .font(.system(size: 9, weight: index == inspector.selectedByte ? .bold : .regular, design: .monospaced))
                .foregroundStyle(index == inspector.selectedByte ? InspectorTheme.green : InspectorTheme.blue)
                .frame(minWidth: inspector.viewerMode == "Binary" ? 22 : 19, minHeight: 22)
                .background(index == inspector.selectedByte ? InspectorTheme.green.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    private func byteText(_ byte: UInt8) -> String {
        switch inspector.viewerMode {
        case "Binary": String(byte, radix: 2).leftPadded(to: 8, with: "0")
        case "Decimal": String(byte)
        case "ASCII", "UTF-8", "UTF-16": ascii(byte)
        default: String(format: "%02X", byte)
        }
    }

    private func ascii(_ byte: UInt8) -> String {
        (32...126).contains(byte) ? String(UnicodeScalar(byte)) : "·"
    }

    private func findPattern() {
        let tokens = pattern.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else {
            searchMessage = "Enter a hexadecimal sequence."
            return
        }
        let bytes = tokens.compactMap { UInt8($0, radix: 16) }
        guard bytes.count == tokens.count else {
            searchMessage = "Invalid hexadecimal byte sequence."
            return
        }
        if let match = inspector.viewerBytes.indices.first(where: { index in
            index + bytes.count <= inspector.viewerBytes.count &&
                Array(inspector.viewerBytes[index..<(index + bytes.count)]) == bytes
        }) {
            inspector.selectedByte = match
            searchMessage = "Match at local offset 0x\(String(match, radix: 16).uppercased())."
        } else {
            searchMessage = "No match in the displayed region."
        }
    }
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        String(repeating: character, count: max(0, length - count)) + self
    }
}
