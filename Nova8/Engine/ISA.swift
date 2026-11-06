import Foundation

// MARK: - Hardware

/// Every value-bearing part of the machine, plus the pseudo-locations used by
/// the visual datapath (ALU result, flags, memory).
enum Hardware: String, CaseIterable, Codable, Hashable, Sendable {
    case a, b, c, d
    case sp, pc, ir, mar, mdr, t
    case alu, flags, ram

    var displayName: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .sp: return "SP"
        case .pc: return "PC"
        case .ir: return "IR"
        case .mar: return "MAR"
        case .mdr: return "MDR"
        case .t: return "T"
        case .alu: return "ALU"
        case .flags: return "FLAGS"
        case .ram: return "RAM"
        }
    }

    var isRegister: Bool {
        switch self {
        case .a, .b, .c, .d, .sp, .pc, .ir, .mar, .mdr, .t:
            return true
        default:
            return false
        }
    }

    var isGeneralPurpose: Bool {
        switch self {
        case .a, .b, .c, .d:
            return true
        default:
            return false
        }
    }
}

// MARK: - Registers

/// Registers addressable by an instruction. The 3-bit register field of an
/// instruction byte maps onto this enum.
enum Register: Int, CaseIterable, Codable, Sendable {
    case a = 0
    case b = 1
    case c = 2
    case d = 3
    case sp = 4

    var name: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .sp: return "SP"
        }
    }

    var hardware: Hardware {
        switch self {
        case .a: return .a
        case .b: return .b
        case .c: return .c
        case .d: return .d
        case .sp: return .sp
        }
    }

    static func named(_ text: String) -> Register? {
        switch text.trimmingCharacters(in: .whitespaces).uppercased() {
        case "A": return .a
        case "B": return .b
        case "C": return .c
        case "D": return .d
        case "SP": return .sp
        default: return nil
        }
    }
}

// MARK: - Opcodes

enum Opcode: UInt8, CaseIterable, Codable, Sendable {
    case nop = 0
    case hlt = 1
    case ret = 2
    case ldi = 3
    case ld = 4
    case st = 5
    case ldr = 6
    case str = 7
    case mov = 8
    case add = 9
    case sub = 10
    case and = 11
    case or = 12
    case xor = 13
    case cmp = 14
    case inc = 15
    case dec = 16
    case not = 17
    case shl = 18
    case shr = 19
    case push = 20
    case pop = 21
    case jmp = 22
    case jz = 23
    case jnz = 24
    case jc = 25
    case jnc = 26
    case call = 27
    case addi = 28

    var mnemonic: String {
        switch self {
        case .nop: return "NOP"
        case .hlt: return "HLT"
        case .ret: return "RET"
        case .ldi: return "LDI"
        case .ld: return "LD"
        case .st: return "ST"
        case .ldr: return "LDR"
        case .str: return "STR"
        case .mov: return "MOV"
        case .add: return "ADD"
        case .sub: return "SUB"
        case .and: return "AND"
        case .or: return "OR"
        case .xor: return "XOR"
        case .cmp: return "CMP"
        case .inc: return "INC"
        case .dec: return "DEC"
        case .not: return "NOT"
        case .shl: return "SHL"
        case .shr: return "SHR"
        case .push: return "PUSH"
        case .pop: return "POP"
        case .jmp: return "JMP"
        case .jz: return "JZ"
        case .jnz: return "JNZ"
        case .jc: return "JC"
        case .jnc: return "JNC"
        case .call: return "CALL"
        case .addi: return "ADDI"
        }
    }

    /// What the second instruction byte means, if there is one.
    enum OperandKind: Sendable {
        case none
        case register
        case value
        case address
    }

    var operandKind: OperandKind {
        switch self {
        case .nop, .hlt, .ret, .shl, .shr,
             .add, .sub, .and, .or, .xor, .cmp,
             .inc, .dec, .not, .push, .pop:
            return .none
        case .ldi, .addi:
            return .value
        case .ld, .st, .jmp, .jz, .jnz, .jc, .jnc, .call:
            return .address
        case .ldr, .str, .mov:
            return .register
        }
    }

    /// Whether the low three bits of the first byte name a register.
    var hasRegisterField: Bool {
        switch self {
        case .ldi, .ld, .st, .ldr, .str, .mov,
             .add, .sub, .and, .or, .xor, .cmp,
             .inc, .dec, .not, .push, .pop:
            return true
        default:
            return false
        }
    }

    var isBranch: Bool {
        switch self {
        case .jmp, .jz, .jnz, .jc, .jnc:
            return true
        default:
            return false
        }
    }

    var isConditionalBranch: Bool {
        switch self {
        case .jz, .jnz, .jc, .jnc:
            return true
        default:
            return false
        }
    }

    var isALU: Bool {
        switch self {
        case .add, .sub, .and, .or, .xor, .cmp, .inc, .dec, .not, .shl, .shr:
            return true
        default:
            return false
        }
    }
}

// MARK: - Decoded instruction

struct DecodedInstruction: Equatable, Sendable {
    let address: UInt8
    let opcode: Opcode
    /// Primary register: destination for LDI/LD/LDR, source for ST/STR, target
    /// for the single-register ALU ops.
    let register: Register?
    /// Secondary register for MOV (source) and LDR/STR (pointer).
    let source: Register?
    /// Immediate byte or absolute address, for instructions that take one.
    let value: UInt8?
    let bytes: [UInt8]
    let isValid: Bool

    var size: Int { bytes.count }

    var mnemonic: String {
        opcode.mnemonic
    }

    var assembly: String {
        guard isValid else {
            return String(format: "??? 0x%02X", bytes.first ?? 0)
        }
        return disassembly
    }

    private var disassembly: String {
        func hex(_ v: UInt8?) -> String {
            guard let v else { return "??" }
            return String(format: "0x%02X", v)
        }

        switch opcode {
        case .nop, .hlt, .ret, .shl, .shr:
            return opcode.mnemonic
        case .ldi, .addi:
            return opcode == .ldi
                ? "LDI \(register?.name ?? "?"), \(hex(value))"
                : "ADDI \(hex(value))"
        case .ld, .st:
            return "\(opcode.mnemonic) \(register?.name ?? "?"), \(hex(value))"
        case .ldr, .str:
            return "\(opcode.mnemonic) \(register?.name ?? "?"), \(source?.name ?? "?")"
        case .mov:
            return "MOV \(register?.name ?? "?"), \(source?.name ?? "?")"
        case .add, .sub, .and, .or, .xor, .cmp:
            return "\(opcode.mnemonic) \(register?.name ?? "?")"
        case .inc, .dec, .not, .push, .pop:
            return "\(opcode.mnemonic) \(register?.name ?? "?")"
        case .jmp, .jz, .jnz, .jc, .jnc, .call:
            return "\(opcode.mnemonic) \(hex(value))"
        }
    }

    static func decode(at address: UInt8, memory: [UInt8]) -> DecodedInstruction {
        let index = Int(address)
        let first = memory.indices.contains(index) ? memory[index] : 0
        let rawOpcode = first >> 3
        let rawRegister = first & 0x07
        let opcode = Opcode(rawValue: rawOpcode)
        let register = Register(rawValue: Int(rawRegister))
        let kind = opcode?.operandKind ?? .none

        var bytes: [UInt8] = [first]
        var second: UInt8?

        if kind != .none {
            let next = memory.indices.contains((index + 1) & 0xFF) ? memory[(index + 1) & 0xFF] : 0
            bytes.append(next)
            second = next
        }

        guard let opcode else {
            return DecodedInstruction(
                address: address,
                opcode: .nop,
                register: nil,
                source: nil,
                value: nil,
                bytes: bytes,
                isValid: false
            )
        }

        var source: Register?
        var value: UInt8?
        var valid = true

        if opcode.hasRegisterField && register == nil {
            valid = false
        }

        switch kind {
        case .register:
            source = second.flatMap { Register(rawValue: Int($0 & 0x07)) }
            if source == nil { valid = false }
        case .value, .address:
            value = second
        case .none:
            break
        }

        return DecodedInstruction(
            address: address,
            opcode: opcode,
            register: register,
            source: source,
            value: value,
            bytes: bytes,
            isValid: valid
        )
    }
}

// MARK: - Memory map

enum MemoryMap {
    static let programStart: UInt8 = 0x00
    static let programEnd: UInt8 = 0x7F
    static let dataStart: UInt8 = 0x80
    static let dataEnd: UInt8 = 0xBF
    static let stackStart: UInt8 = 0xC0
    static let stackEnd: UInt8 = 0xEF
    static let displayPort: UInt8 = 0xF0
    static let inputPort: UInt8 = 0xF1
    static let ioStart: UInt8 = 0xF0
    static let ioEnd: UInt8 = 0xFF

    static let stackPointerInitial = stackEnd

    enum Region: String, CaseIterable, Sendable {
        case program, data, stack, io, reserved

        var title: String {
            switch self {
            case .program: return "Program"
            case .data: return "Data"
            case .stack: return "Stack"
            case .io: return "I/O"
            case .reserved: return "Reserved"
            }
        }
    }

    static func region(for address: UInt8) -> Region {
        if address >= programStart && address <= programEnd { return .program }
        if address >= dataStart && address <= dataEnd { return .data }
        if address >= stackStart && address <= stackEnd { return .stack }
        if address <= inputPort { return .io }
        return .reserved
    }
}
