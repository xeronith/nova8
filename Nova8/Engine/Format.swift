import Foundation

enum Fmt {
    static func hex(_ value: UInt8) -> String {
        String(format: "0x%02X", value)
    }

    static func hex(_ value: Int) -> String {
        String(format: "0x%02X", value & 0xFF)
    }

    static func hexWord(_ value: Int) -> String {
        String(format: "0x%02X", value & 0xFF)
    }

    static func bits(_ value: UInt8, width: Int) -> String {
        let raw = String(value, radix: 2)
        return String(repeating: "0", count: max(0, width - raw.count)) + raw
    }

    static func binary(_ value: UInt8) -> String {
        bits(value, width: 8)
    }

    static func byteBits(_ value: UInt8) -> String {
        let bits = binary(value)
        let first = bits.prefix(4)
        let second = bits.suffix(4)
        return "\(first) \(second)"
    }
}
