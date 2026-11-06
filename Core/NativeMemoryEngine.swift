import Foundation

struct NativeCandidate: Identifiable, Hashable, Sendable {
    let id: UInt64
    let offset: UInt64
    let bytes: [UInt8]
}

enum EngineFailure: LocalizedError, Sendable {
    case unavailable
    case operation(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The native memory engine could not be initialized."
        case .operation(let message):
            return message
        }
    }
}

final class NativeMemoryEngine: @unchecked Sendable {
    private let handle: OpaquePointer

    init() throws {
        guard let handle = mi_engine_create() else {
            throw EngineFailure.unavailable
        }
        self.handle = handle
    }

    deinit {
        mi_engine_destroy(handle)
    }

    func createRegion(name: String, bytes: [UInt8]) throws -> UInt64 {
        var identifier: UInt64 = 0
        let status = name.withCString { namePointer in
            bytes.withUnsafeBufferPointer { buffer in
                mi_region_create(handle, namePointer, buffer.baseAddress, buffer.count, &identifier)
            }
        }
        try check(status)
        return identifier
    }

    func write(region: UInt64, offset: UInt64, bytes: [UInt8]) throws {
        let status = bytes.withUnsafeBufferPointer { buffer in
            mi_region_write(handle, region, offset, buffer.baseAddress, buffer.count)
        }
        try check(status)
    }

    func read(region: UInt64, offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBufferPointer { buffer in
            mi_region_read(handle, region, offset, buffer.baseAddress, buffer.count)
        }
        try check(status)
        return bytes
    }

    func scan(region: UInt64,
              type: ValueKind,
              condition: ScanCondition,
              alignment: Int,
              byteOrder: MemoryByteOrder,
              value: [UInt8],
              upper: [UInt8]) throws {
        var count: UInt64 = 0
        let status = value.withUnsafeBufferPointer { valueBuffer in
            upper.withUnsafeBufferPointer { upperBuffer in
                mi_scan(handle,
                        region,
                        type.nativeValue,
                        condition.nativeValue,
                        byteOrder.nativeValue,
                        UInt32(alignment),
                        valueBuffer.baseAddress,
                        valueBuffer.count,
                        upperBuffer.baseAddress,
                        upperBuffer.count,
                        0.0001,
                        nil,
                        nil,
                        &count)
            }
        }
        try check(status)
    }

    func filter(condition: ScanCondition, value: [UInt8], upper: [UInt8]) throws {
        var count: UInt64 = 0
        let status = value.withUnsafeBufferPointer { valueBuffer in
            upper.withUnsafeBufferPointer { upperBuffer in
                mi_filter(handle,
                          condition.nativeValue,
                          valueBuffer.baseAddress,
                          valueBuffer.count,
                          upperBuffer.baseAddress,
                          upperBuffer.count,
                          0.0001,
                          nil,
                          nil,
                          &count)
            }
        }
        try check(status)
    }

    func page(_ page: UInt64) throws -> (candidates: [NativeCandidate], total: UInt64) {
        var identifiers = [UInt64](repeating: 0, count: 250)
        var offsets = [UInt64](repeating: 0, count: 250)
        var values = [UInt8](repeating: 0, count: 250 * 8)
        var sizes = [UInt8](repeating: 0, count: 250)
        var written = 0
        var total: UInt64 = 0
        let status = identifiers.withUnsafeMutableBufferPointer { idBuffer in
            offsets.withUnsafeMutableBufferPointer { offsetBuffer in
                values.withUnsafeMutableBufferPointer { valueBuffer in
                    sizes.withUnsafeMutableBufferPointer { sizeBuffer in
                        mi_candidates_page_flat(handle,
                                                page,
                                                idBuffer.baseAddress,
                                                offsetBuffer.baseAddress,
                                                valueBuffer.baseAddress,
                                                sizeBuffer.baseAddress,
                                                idBuffer.count,
                                                &written,
                                                &total)
                    }
                }
            }
        }
        try check(status)
        let candidates = (0..<written).map { index in
            NativeCandidate(id: identifiers[index],
                            offset: offsets[index],
                            bytes: Array(values[(index * 8)..<(index * 8 + Int(sizes[index]))]))
        }
        return (candidates, total)
    }

    func cancel() {
        _ = mi_cancel(handle)
    }

    private func check(_ status: mi_status) throws {
        guard status == MI_STATUS_OK else {
            throw EngineFailure.operation(String(cString: mi_status_message(status)))
        }
    }
}
