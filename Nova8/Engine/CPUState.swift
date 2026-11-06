import Foundation

// MARK: - Flags

struct Flags: Equatable, Codable, Sendable {
    var zero: Bool = false
    var carry: Bool = false
    var negative: Bool = false

    var summary: String {
        "Z\(zero ? 1 : 0) C\(carry ? 1 : 0) N\(negative ? 1 : 0)"
    }
}

// MARK: - CPU state

/// The complete architectural state of NOVA-8. Everything the machine knows is
/// in here, which makes snapshots (and time travel) trivial.
struct CPUState: Equatable, Sendable {
    var ram: [UInt8]
    var regs: [Hardware: UInt8]
    var flags: Flags
    var halted: Bool
    var microOpCount: Int
    var instructionCount: Int

    init(memory: [UInt8] = Array(repeating: 0, count: 256), input: UInt8 = 0) {
        var image = memory
        if image.count < 256 {
            image.append(contentsOf: Array(repeating: 0, count: 256 - image.count))
        } else if image.count > 256 {
            image = Array(image.prefix(256))
        }
        image[Int(MemoryMap.inputPort)] = input

        self.ram = image
        self.regs = [
            .a: 0, .b: 0, .c: 0, .d: 0,
            .sp: MemoryMap.stackPointerInitial,
            .pc: MemoryMap.programStart,
            .ir: 0, .mar: 0, .mdr: 0, .t: 0
        ]
        self.flags = Flags()
        self.halted = false
        self.microOpCount = 0
        self.instructionCount = 0
    }

    subscript(hardware: Hardware) -> UInt8 {
        get {
            guard hardware.isRegister else { return 0 }
            return regs[hardware] ?? 0
        }
        set {
            guard hardware.isRegister else { return }
            regs[hardware] = newValue
        }
    }

    mutating func write(_ value: UInt8, to hardware: Hardware) {
        guard hardware.isRegister else { return }
        regs[hardware] = value
    }

    var a: UInt8 { get { self[.a] } set { self[.a] = newValue } }
    var b: UInt8 { get { self[.b] } set { self[.b] = newValue } }
    var c: UInt8 { get { self[.c] } set { self[.c] = newValue } }
    var d: UInt8 { get { self[.d] } set { self[.d] = newValue } }
    var sp: UInt8 { get { self[.sp] } set { self[.sp] = newValue } }
    var pc: UInt8 { get { self[.pc] } set { self[.pc] = newValue } }
    var ir: UInt8 { get { self[.ir] } set { self[.ir] = newValue } }
    var mar: UInt8 { get { self[.mar] } set { self[.mar] = newValue } }
    var mdr: UInt8 { get { self[.mdr] } set { self[.mdr] = newValue } }
    var t: UInt8 { get { self[.t] } set { self[.t] = newValue } }

    func read(_ hardware: Hardware) -> UInt8 {
        guard hardware.isRegister else { return 0 }
        return regs[hardware] ?? 0
    }

    /// The byte that the current instruction is about to execute.
    var currentByte: UInt8 {
        ram[Int(pc)]
    }

    var displayValue: UInt8 {
        ram[Int(MemoryMap.displayPort)]
    }

    var inputValue: UInt8 {
        ram[Int(MemoryMap.inputPort)]
    }

    var stackDepth: Int {
        Int(MemoryMap.stackPointerInitial) - Int(sp)
    }

    var pcLineAddress: UInt8 {
        pc
    }
}

// MARK: - ALU

enum ALUOperation: String, Equatable, Sendable {
    case add, sub, and, or, xor, cmp, inc, dec, not, shl, shr

    var displayName: String {
        rawValue.uppercased()
    }

    /// The operation symbol shown in the datapath, e.g. "A + B".
    var symbol: String {
        switch self {
        case .add: return "+"
        case .sub: return "−"
        case .and: return "&"
        case .or: return "|"
        case .xor: return "^"
        case .cmp: return "−"
        case .inc: return "+1"
        case .dec: return "−1"
        case .not: return "~"
        case .shl: return "<<"
        case .shr: return ">>"
        }
    }

    /// These read A and the selected source register.
    var readsAccumulator: Bool {
        switch self {
        case .add, .sub, .and, .or, .xor, .cmp, .shl, .shr:
            return true
        case .inc, .dec, .not:
            return false
        }
    }

    var writesFlags: Bool { true }
}

enum ALU {
    static func evaluate(
        _ operation: ALUOperation,
        _ lhs: UInt8,
        _ rhs: UInt8,
        carryIn: Bool
    ) -> (value: UInt8, flags: Flags) {
        switch operation {
        case .add:
            let wide = Int(lhs) + Int(rhs)
            let value = UInt8(wide & 0xFF)
            return (value, Flags(zero: value == 0, carry: wide > 0xFF, negative: value & 0x80 != 0))

        case .sub, .cmp:
            let wide = Int(lhs) - Int(rhs)
            let value = UInt8(truncatingIfNeeded: wide)
            return (value, Flags(zero: value == 0, carry: wide < 0, negative: value & 0x80 != 0))

        case .and:
            let value = lhs & rhs
            return (value, Flags(zero: value == 0, carry: false, negative: value & 0x80 != 0))

        case .or:
            let value = lhs | rhs
            return (value, Flags(zero: value == 0, carry: false, negative: value & 0x80 != 0))

        case .xor:
            let value = lhs ^ rhs
            return (value, Flags(zero: value == 0, carry: false, negative: value & 0x80 != 0))

        case .inc:
            let value = lhs &+ 1
            return (value, Flags(zero: value == 0, carry: carryIn, negative: value & 0x80 != 0))

        case .dec:
            let value = lhs &- 1
            return (value, Flags(zero: value == 0, carry: carryIn, negative: value & 0x80 != 0))

        case .not:
            let value = ~lhs
            return (value, Flags(zero: value == 0, carry: carryIn, negative: value & 0x80 != 0))

        case .shl:
            let value = lhs << 1
            return (value, Flags(zero: value == 0, carry: lhs & 0x80 != 0, negative: value & 0x80 != 0))

        case .shr:
            let value = lhs >> 1
            return (value, Flags(zero: value == 0, carry: lhs & 0x01 != 0, negative: false))
        }
    }
}
