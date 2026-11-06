import CryptoKit
import Foundation
import SwiftUI

enum MainSection: String, CaseIterable, Identifiable, Sendable {
    case scanner = "Scanner"
    case results = "Results"
    case monitor = "Monitor"
    case viewer = "Memory Viewer"
    case more = "More"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .scanner: "waveform.path.ecg"
        case .results: "list.number"
        case .monitor: "eye"
        case .viewer: "memorychip"
        case .more: "ellipsis"
        }
    }
}

enum ValueKind: Int, CaseIterable, Identifiable, Sendable {
    case int8, uint8, int16, uint16, int32, uint32, int64, uint64, float32, float64

    var id: Int { rawValue }
    var title: String {
        ["Int8", "UInt8", "Int16", "UInt16", "Int32", "UInt32", "Int64", "UInt64", "Float32", "Float64"][rawValue]
    }
    var width: Int {
        switch self {
        case .int8, .uint8: 1
        case .int16, .uint16: 2
        case .int32, .uint32, .float32: 4
        case .int64, .uint64, .float64: 8
        }
    }
    var nativeValue: mi_data_type {
        switch self {
        case .int8: MI_TYPE_INT8
        case .uint8: MI_TYPE_UINT8
        case .int16: MI_TYPE_INT16
        case .uint16: MI_TYPE_UINT16
        case .int32: MI_TYPE_INT32
        case .uint32: MI_TYPE_UINT32
        case .int64: MI_TYPE_INT64
        case .uint64: MI_TYPE_UINT64
        case .float32: MI_TYPE_FLOAT32
        case .float64: MI_TYPE_FLOAT64
        }
    }

    func encode(_ input: String, byteOrder: MemoryByteOrder = .littleEndian) -> [UInt8]? {
        let encoded: [UInt8]?
        switch self {
        case .int8: encoded = Int8(input).map { [UInt8(bitPattern: $0)] }
        case .uint8: encoded = UInt8(input).map { [$0] }
        case .int16: encoded = Int16(input).map { littleEndianBytes($0) }
        case .uint16: encoded = UInt16(input).map { littleEndianBytes($0) }
        case .int32: encoded = Int32(input).map { littleEndianBytes($0) }
        case .uint32: encoded = UInt32(input).map { littleEndianBytes($0) }
        case .int64: encoded = Int64(input).map { littleEndianBytes($0) }
        case .uint64: encoded = UInt64(input).map { littleEndianBytes($0) }
        case .float32:
            encoded = Float(input).map { littleEndianBytes($0.bitPattern) }
        case .float64:
            encoded = Double(input).map { littleEndianBytes($0.bitPattern) }
        }
        guard let encoded else { return nil }
        return byteOrder == .littleEndian ? encoded : Array(encoded.reversed())
    }

    func decode(_ bytes: [UInt8], byteOrder: MemoryByteOrder = .littleEndian) -> String {
        guard bytes.count >= width else { return "—" }
        let ordered = byteOrder == .littleEndian ? Array(bytes.prefix(width)) : Array(bytes.prefix(width).reversed())
        return switch self {
        case .int8: String(Int8(bitPattern: ordered[0]))
        case .uint8: String(ordered[0])
        case .int16: String(Int16(bitPattern: readUnsigned(ordered, as: UInt16.self)))
        case .uint16: String(readUnsigned(ordered, as: UInt16.self))
        case .int32: String(Int32(bitPattern: readUnsigned(ordered, as: UInt32.self)))
        case .uint32: String(readUnsigned(ordered, as: UInt32.self))
        case .int64: String(Int64(bitPattern: readUnsigned(ordered, as: UInt64.self)))
        case .uint64: String(readUnsigned(ordered, as: UInt64.self))
        case .float32: String(Float(bitPattern: readUnsigned(ordered, as: UInt32.self)))
        case .float64: String(Double(bitPattern: readUnsigned(ordered, as: UInt64.self)))
        }
    }
}

enum MemoryByteOrder: Int, CaseIterable, Codable, Identifiable, Sendable {
    case littleEndian
    case bigEndian

    var id: Int { rawValue }
    var title: String { self == .littleEndian ? "Little Endian" : "Big Endian" }
    var nativeValue: mi_byte_order {
        self == .littleEndian ? MI_BYTE_ORDER_LITTLE_ENDIAN : MI_BYTE_ORDER_BIG_ENDIAN
    }
}

enum ScanCondition: Int, CaseIterable, Identifiable, Sendable {
    case exact, notEqual, greater, less, between, unknown, increased, decreased, changed, unchanged, increasedBy, decreasedBy, equalToPrevious

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .exact: "Exact"
        case .notEqual: "Not Equal"
        case .greater: "Greater"
        case .less: "Less"
        case .between: "Between"
        case .unknown: "Unknown"
        case .increased: "Increased"
        case .decreased: "Decreased"
        case .changed: "Changed"
        case .unchanged: "Unchanged"
        case .increasedBy: "Increased By"
        case .decreasedBy: "Decreased By"
        case .equalToPrevious: "Equal to Previous"
        }
    }
    var nativeValue: mi_condition {
        switch self {
        case .exact: MI_CONDITION_EXACT
        case .notEqual: MI_CONDITION_NOT_EQUAL
        case .greater: MI_CONDITION_GREATER
        case .less: MI_CONDITION_LESS
        case .between: MI_CONDITION_BETWEEN
        case .unknown: MI_CONDITION_UNKNOWN
        case .increased: MI_CONDITION_INCREASED
        case .decreased: MI_CONDITION_DECREASED
        case .changed: MI_CONDITION_CHANGED
        case .unchanged: MI_CONDITION_UNCHANGED
        case .increasedBy: MI_CONDITION_INCREASED_BY
        case .decreasedBy: MI_CONDITION_DECREASED_BY
        case .equalToPrevious: MI_CONDITION_EQUAL_TO_PREVIOUS
        }
    }
    var isInitialOnly: Bool { self == .unknown || self == .exact || self == .notEqual || self == .greater || self == .less || self == .between }
    var needsValue: Bool { ![.unknown, .increased, .decreased, .changed, .unchanged, .equalToPrevious].contains(self) }
}

struct MemorySource: Identifiable, Hashable, Sendable {
    let id: UInt64
    let name: String
    let detail: String
    let size: Int
}

struct ScanStep: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let condition: String
    let value: String
    let candidates: Int
    let duration: Double
}

struct WatchedValue: Identifiable, Codable, Sendable {
    let id: UInt64
    let offset: UInt64
    let sourceID: UInt64
    let sourceName: String
    let kind: ValueKindCodable
    let byteOrder: MemoryByteOrder
    var previous: String
    var current: String
    var history: [ValuePoint]
}

struct ValueKindCodable: Codable, Sendable {
    let rawValue: Int
    var value: ValueKind { ValueKind(rawValue: rawValue) ?? .int32 }
}

struct ValuePoint: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let value: Double
}

struct StoredSnapshot: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let date: Date
    let sourceName: String
    let byteCount: Int
    let sha256: String
    let bytes: Data
}

@MainActor
final class InspectorStore: ObservableObject {
    @Published var section: MainSection = .scanner
    @Published var moreDestination = "Snapshots"
    @Published var sources: [MemorySource] = []
    @Published var selectedSourceID: UInt64 = 0
    @Published var valueKind: ValueKind = .int32
    @Published var byteOrder: MemoryByteOrder = .littleEndian
    @Published var alignment = 0
    @Published var condition: ScanCondition = .exact
    @Published var searchValue = "100"
    @Published var upperValue = "200"
    @Published var candidates: [NativeCandidate] = []
    @Published var candidateCount: UInt64 = 0
    @Published var pageIndex: UInt64 = 0
    @Published var isScanning = false
    @Published var progress = 0.0
    @Published var scanDuration: Double = 0
    @Published var lastError: String?
    @Published var scanHistory: [ScanStep] = []
    @Published var watchlist: [WatchedValue] = []
    @Published var snapshots: [StoredSnapshot] = []
    @Published var selectedByte = 0
    @Published var viewerOffset = "0"
    @Published var viewerBytes: [UInt8] = []
    @Published var viewerMode = "Hex"
    @Published var refreshSeconds = 1.0
    @Published var monitoringPaused = false

    private var engine: NativeMemoryEngine?

    init() {
        do {
            let engine = try NativeMemoryEngine()
            self.engine = engine
            try createTestRegions(using: engine)
            loadPersistedData()
        } catch {
            lastError = error.localizedDescription
        }
    }

    var selectedSource: MemorySource? {
        sources.first { $0.id == selectedSourceID }
    }

    var pageCount: UInt64 {
        max(1, (candidateCount + 249) / 250)
    }

    var visibleCandidates: [NativeCandidate] { candidates }

    func runScan(initial: Bool) {
        guard !isScanning, let engine, let source = selectedSource else { return }
        let selectedCondition = condition
        let selectedKind = valueKind
        guard !initial || selectedCondition.isInitialOnly else {
            lastError = "InvalidComparisonValue: Select an initial-scan condition or run a next scan."
            return
        }
        guard initial || selectedCondition != .unknown else {
            lastError = "InvalidComparisonValue: Unknown is only valid for an initial scan."
            return
        }
        let selectedOrder = byteOrder
        let selectedAlignment = alignment
        let encoded = selectedCondition.needsValue ? selectedKind.encode(searchValue, byteOrder: selectedOrder) : []
        let upper = selectedCondition == .between ? selectedKind.encode(upperValue, byteOrder: selectedOrder) : []
        guard !selectedCondition.needsValue || encoded != nil,
              selectedCondition != .between || upper != nil else {
            lastError = "InvalidComparisonValue: Enter a valid \(selectedKind.title) value."
            return
        }
        let value = encoded ?? []
        let high = upper ?? []
        let began = Date()
        isScanning = true
        lastError = nil
        progress = 0

        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    if initial {
                        try engine.scan(region: source.id,
                                        type: selectedKind,
                                        condition: selectedCondition,
                                        alignment: selectedAlignment,
                                        byteOrder: selectedOrder,
                                        value: value,
                                        upper: high)
                    } else {
                        try engine.filter(condition: selectedCondition, value: value, upper: high)
                    }
                    return try engine.page(0)
                }
            }.value
            guard let self else { return }
            self.isScanning = false
            self.scanDuration = Date().timeIntervalSince(began)
            switch result {
            case .success(let page):
                self.candidates = page.candidates
                self.candidateCount = page.total
                self.pageIndex = 0
                self.scanHistory.insert(ScanStep(id: UUID(),
                                                 date: Date(),
                                                 condition: selectedCondition.title,
                                                 value: selectedCondition.needsValue ? self.searchValue : "—",
                                                 candidates: Int(page.total),
                                                 duration: self.scanDuration),
                                        at: 0)
                self.persistData()
            case .failure(let error):
                self.lastError = error.localizedDescription
            }
        }
    }

    func loadPage(_ page: UInt64) {
        guard let engine, page < pageCount else { return }
        do {
            let result = try engine.page(page)
            candidates = result.candidates
            candidateCount = result.total
            pageIndex = page
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancelScan() {
        engine?.cancel()
    }

    func selectSource(_ identifier: UInt64) {
        guard selectedSourceID != identifier else { return }
        selectedSourceID = identifier
        resetScan()
    }

    func selectValueKind(_ kind: ValueKind) {
        guard valueKind != kind else { return }
        valueKind = kind
        if alignment != 0 && alignment > kind.width {
            alignment = 0
        }
        resetScan()
    }

    func selectByteOrder(_ order: MemoryByteOrder) {
        guard byteOrder != order else { return }
        byteOrder = order
        resetScan()
    }

    func selectAlignment(_ value: Int) {
        guard alignment != value else { return }
        alignment = value
        resetScan()
    }

    func resetScan() {
        cancelScan()
        candidates = []
        candidateCount = 0
        pageIndex = 0
        scanHistory = []
        persistData()
    }

    func addToWatchlist(_ candidate: NativeCandidate) {
        guard let source = sources.first(where: { $0.id == selectedSourceID }),
              !watchlist.contains(where: { $0.id == candidate.id }) else { return }
        let currentBytes: [UInt8]
        do {
            currentBytes = try engine?.read(region: source.id,
                                            offset: candidate.offset,
                                            count: valueKind.width) ?? candidate.bytes
        } catch {
            lastError = "MemoryReadFailure: \(error.localizedDescription)"
            return
        }
        let text = valueKind.decode(currentBytes, byteOrder: byteOrder)
        watchlist.append(WatchedValue(id: candidate.id,
                                      offset: candidate.offset,
                                      sourceID: source.id,
                                      sourceName: source.name,
                                      kind: ValueKindCodable(rawValue: valueKind.rawValue),
                                      byteOrder: byteOrder,
                                      previous: text,
                                      current: text,
                                      history: []))
        persistData()
    }

    func removeFromWatchlist(_ id: UInt64) {
        watchlist.removeAll { $0.id == id }
        persistData()
    }

    func refreshWatchlist(force: Bool = false) {
        guard (force || !monitoringPaused), let engine else { return }
        do {
            for index in watchlist.indices {
                let item = watchlist[index]
                let bytes = try engine.read(region: item.sourceID,
                                            offset: item.offset,
                                            count: item.kind.value.width)
                let value = item.kind.value.decode(bytes, byteOrder: item.byteOrder)
                watchlist[index].previous = watchlist[index].current
                watchlist[index].current = value
                if let numeric = Double(value) {
                    watchlist[index].history.append(ValuePoint(id: UUID(), date: Date(), value: numeric))
                    if watchlist[index].history.count > 240 {
                        watchlist[index].history.removeFirst(watchlist[index].history.count - 240)
                    }
                }
            }
            persistData()
        } catch {
            lastError = "MemoryReadFailure: \(error.localizedDescription)"
        }
    }

    func loadViewer() {
        let value = viewerOffset.lowercased().hasPrefix("0x")
            ? String(viewerOffset.dropFirst(2))
            : viewerOffset
        guard let engine, let source = selectedSource, let offset = UInt64(value, radix: 16),
              offset <= UInt64(source.size) else {
            lastError = "InvalidMemoryRange: Enter a valid hexadecimal offset."
            return
        }
        do {
            let bounded = min(256, max(0, source.size - Int(offset)))
            viewerBytes = try engine.read(region: source.id, offset: offset, count: bounded)
            selectedByte = min(selectedByte, max(0, viewerBytes.count - 1))
        } catch {
            lastError = "MemoryReadFailure: \(error.localizedDescription)"
        }
    }

    func createSnapshot() {
        guard let engine, let source = selectedSource else { return }
        do {
            let bytes = try engine.read(region: source.id, offset: 0, count: source.size)
            let data = Data(bytes)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            snapshots.insert(StoredSnapshot(id: UUID(),
                                            name: "Snapshot \(snapshots.count + 1)",
                                            date: Date(),
                                            sourceName: source.name,
                                            byteCount: data.count,
                                            sha256: hash,
                                            bytes: data),
                             at: 0)
            snapshots = Array(snapshots.prefix(20))
            persistData()
        } catch {
            lastError = "SnapshotFailure: \(error.localizedDescription)"
        }
    }

    func deleteSnapshot(_ id: UUID) {
        snapshots.removeAll { $0.id == id }
        persistData()
    }

    func exportSnapshot(_ snapshot: StoredSnapshot) -> URL? {
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(snapshot.name.replacingOccurrences(of: " ", with: "-"))
                .appendingPathExtension("json")
            try JSONEncoder.inspectorEncoder.encode(snapshot).write(to: url, options: .atomic)
            return url
        } catch {
            lastError = "ExportFailure: \(error.localizedDescription)"
            return nil
        }
    }

    func compareLatestSnapshots() -> (changed: Int, unchanged: Int, added: Int, removed: Int)? {
        guard snapshots.count >= 2 else { return nil }
        let newer = snapshots[0].bytes
        let older = snapshots[1].bytes
        let sharedCount = min(newer.count, older.count)
        var changed = 0
        for index in 0..<sharedCount where newer[index] != older[index] {
            changed += 1
        }
        return (changed,
                sharedCount - changed,
                max(0, newer.count - older.count),
                max(0, older.count - newer.count))
    }

    func changeTestValue(by delta: Int32) {
        guard let engine, let source = sources.first(where: { $0.name == "Numeric Lab" }) else { return }
        do {
            let current = try engine.read(region: source.id, offset: 0, count: 4)
            let old = Int32(bitPattern: readUnsigned(current, as: UInt32.self))
            try engine.write(region: source.id, offset: 0, bytes: littleEndianBytes(old &+ delta))
            if source.id == selectedSourceID {
                loadViewer()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetDataset() {
        guard let engine,
              let source = sources.first(where: { $0.name == "Numeric Lab" }) else { return }
        do {
            var data = [UInt8]()
            data.reserveCapacity(4096 * 4)
            for number in 0..<4096 {
                data.append(contentsOf: littleEndianBytes(Int32(number % 256)))
            }
            try engine.write(region: source.id, offset: 0, bytes: data)
            resetScan()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func createTestRegions(using engine: NativeMemoryEngine) throws {
        var numeric = [UInt8]()
        for number in 0..<4096 {
            numeric.append(contentsOf: littleEndianBytes(Int32(number % 256)))
        }
        var floating = [UInt8]()
        for number in 0..<2048 {
            floating.append(contentsOf: littleEndianBytes((Float(number) / 4).bitPattern))
        }
        var binary = Array("MEMORY CORE / AUTHORIZED TEST REGION / UTF-8 / 0123456789".utf8)
        binary += [0, 0, 0, 0]
        binary += (0..<192).map { UInt8(($0 * 37) & 0xFF) }
        let player = [UInt8](repeating: 0, count: 512)
        let staticBytes = Array(repeating: littleEndianBytes(Int32(42)), count: 256).flatMap { $0 }
        sources = [
            MemorySource(id: try engine.createRegion(name: "Player Simulation", bytes: player),
                         name: "Player Simulation", detail: "Owned test buffer · 512 B", size: player.count),
            MemorySource(id: try engine.createRegion(name: "Numeric Lab", bytes: numeric),
                         name: "Numeric Lab", detail: "4,096 Int32 values · 16 KB", size: numeric.count),
            MemorySource(id: try engine.createRegion(name: "Float Lab", bytes: floating),
                         name: "Float Lab", detail: "2,048 Float32 values · 8 KB", size: floating.count),
            MemorySource(id: try engine.createRegion(name: "Binary Lab", bytes: binary),
                         name: "Binary Lab", detail: "Text and byte patterns · \(binary.count) B", size: binary.count),
            MemorySource(id: try engine.createRegion(name: "Static Values", bytes: staticBytes),
                         name: "Static Values", detail: "Constant test values · \(staticBytes.count / 1024) KB", size: staticBytes.count)
        ]
        selectedSourceID = sources.first(where: { $0.name == "Numeric Lab" })?.id ?? sources[0].id
    }

    private var persistenceURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("inspector-state.json")
    }

    private func loadPersistedData() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let state = try? JSONDecoder().decode(PersistedInspectorState.self, from: data) else { return }
        snapshots = state.snapshots
        watchlist = state.watchlist
        scanHistory = state.history
    }

    private func persistData() {
        let state = PersistedInspectorState(snapshots: snapshots,
                                            watchlist: watchlist,
                                            history: Array(scanHistory.prefix(100)))
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            lastError = "PersistenceFailure: \(error.localizedDescription)"
        }
    }
}

private struct PersistedInspectorState: Codable {
    let snapshots: [StoredSnapshot]
    let watchlist: [WatchedValue]
    let history: [ScanStep]
}

private extension JSONEncoder {
    static var inspectorEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
    var littleEndian = value.littleEndian
    return withUnsafeBytes(of: &littleEndian) { Array($0) }
}

private func readUnsigned<T: FixedWidthInteger>(_ bytes: [UInt8], as type: T.Type) -> T {
    var result: T = 0
    for (index, byte) in bytes.prefix(MemoryLayout<T>.size).enumerated() {
        result |= T(byte) << (index * 8)
    }
    return result
}
