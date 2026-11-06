import Foundation

// MARK: - Stages

enum MicroStage: String, CaseIterable, Sendable {
    case fetch
    case decode
    case operand
    case execute

    var title: String {
        switch self {
        case .fetch: return "Fetch"
        case .decode: return "Decode"
        case .operand: return "Operand"
        case .execute: return "Execute"
        }
    }

    var letter: String {
        switch self {
        case .fetch: return "F"
        case .decode: return "D"
        case .operand: return "O"
        case .execute: return "E"
        }
    }
}

// MARK: - Control signals

enum ControlSignal: String, CaseIterable, Sendable {
    case pcOut = "PC out"
    case pcIn = "PC in"
    case pcInc = "PC + 1"
    case spOut = "SP out"
    case spIn = "SP in"
    case spInc = "SP + 1"
    case spDec = "SP − 1"
    case marIn = "MAR in"
    case memRead = "MEM read"
    case memWrite = "MEM write"
    case mdrIn = "MDR in"
    case mdrOut = "MDR out"
    case irIn = "IR in"
    case tIn = "T in"
    case tOut = "T out"
    case aluOut = "ALU out"
    case flagsIn = "FLAGS in"
    case regOut = "REG out"
    case regIn = "REG in"
    case decode = "decode"
    case halt = "halt"
}

// MARK: - Micro-op

/// One clock's worth of work. These are generated from the decoded instruction
/// before it executes, then applied one at a time.
struct MicroOp: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case transfer(from: Hardware, to: Hardware)
        case memoryRead
        case memoryWrite
        case alu(ALUOperation, source: Hardware?, destination: Hardware?, writesFlags: Bool)
        case decode
        case branch(taken: Bool, target: UInt8)
        case halt
        case nop
    }

    let stage: MicroStage
    /// "F1", "D1", "E2"… shown on the timeline.
    let slot: String
    let title: String
    let detail: String
    let kind: Kind
    let signals: [ControlSignal]
    let memoryAddress: UInt8?
    let incrementsPC: Bool
    let instructionSerial: Int
    let instructionAddress: UInt8
    let instructionText: String

    func apply(to state: inout CPUState) {
        switch kind {
        case .transfer(let from, let to):
            state.write(state.read(from), to: to)

        case .memoryRead:
            state.write(state.ram[Int(state.mar)], to: .mdr)

        case .memoryWrite:
            state.ram[Int(state.mar)] = state.mdr

        case .alu(let operation, let source, let destination, let writesFlags):
            let lhs: UInt8
            let rhs: UInt8

            switch operation {
            case .inc, .dec, .not:
                lhs = destination.map { state.read($0) } ?? state.a
                rhs = 1
            case .shl, .shr:
                lhs = state.a
                rhs = 0
            default:
                lhs = state.a
                rhs = source.map { state.read($0) } ?? 0
            }

            let result = ALU.evaluate(operation, lhs, rhs, carryIn: state.flags.carry)
            if writesFlags {
                state.flags = result.flags
            }
            if let destination {
                state.write(result.value, to: destination)
            }

        case .decode:
            break

        case .branch(let taken, let target):
            if taken {
                state.write(target, to: .pc)
            }

        case .halt:
            state.halted = true

        case .nop:
            break
        }

        if incrementsPC {
            state.write(state.pc &+ 1, to: .pc)
        }
        state.microOpCount += 1
    }

    /// The component data leaves from, for the packet animation.
    var sourceHardware: Hardware? {
        switch kind {
        case .transfer(let from, _): return from
        case .memoryRead: return .ram
        case .memoryWrite: return .mdr
        case .alu: return .alu
        case .decode: return .ir
        case .branch(_, _): return .t
        case .halt, .nop: return nil
        }
    }

    /// The component data arrives at, for the packet animation.
    var destinationHardware: Hardware? {
        switch kind {
        case .transfer(_, let to): return to
        case .memoryRead: return .mdr
        case .memoryWrite: return .ram
        case .alu(_, _, let destination, let writesFlags):
            return destination ?? (writesFlags ? .flags : nil)
        case .decode: return .ir
        case .branch(let taken, _): return taken ? .pc : nil
        case .halt, .nop: return nil
        }
    }

    var isMemoryAccess: Bool {
        memoryAddress != nil
    }

    /// Every value-bearing part this cycle reads or writes.
    var touchedHardware: Set<Hardware> {
        switch kind {
        case .transfer(let from, let to):
            return [from, to]
        case .memoryRead:
            return [.ram, .mdr]
        case .memoryWrite:
            return [.mdr, .ram]
        case .alu(_, let source, let destination, _):
            var result: Set<Hardware> = [.alu]
            if let source { result.insert(source) }
            if let destination { result.insert(destination) }
            return result
        case .decode:
            return [.ir]
        case .branch(_, _):
            return [.t, .pc]
        case .halt, .nop:
            return []
        }
    }

    /// A one-line description suitable for a timeline tooltip.
    var timelineTitle: String {
        "\(slot) · \(title)"
    }
}
