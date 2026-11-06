import Foundation

struct InstructionPlan: Equatable, Sendable {
    let instruction: DecodedInstruction
    let serial: Int
    let ops: [MicroOp]
}

/// Turns one instruction into the sequence of clock cycles that execute it.
/// The plan is built from the current state, so branch decisions and memory
/// addresses are already resolved when the animation starts.
enum InstructionPlanner {

    static func plan(address: UInt8, state: CPUState, serial: Int) -> InstructionPlan {
        let instruction = DecodedInstruction.decode(at: address, memory: state.ram)
        let opcode = instruction.opcode
        let firstByte = state.ram[Int(address)]
        let instructionText = instruction.assembly
        let pc = state[.pc]
        var ops: [MicroOp] = []

        func make(
            _ stage: MicroStage,
            _ slot: String,
            _ title: String,
            _ detail: String,
            _ kind: MicroOp.Kind,
            _ signals: [ControlSignal] = [],
            memory: UInt8? = nil,
            incPC: Bool = false
        ) -> MicroOp {
            MicroOp(
                stage: stage,
                slot: slot,
                title: title,
                detail: detail,
                kind: kind,
                signals: signals,
                memoryAddress: memory,
                incrementsPC: incPC,
                instructionSerial: serial,
                instructionAddress: address,
                instructionText: instructionText
            )
        }

        func flagsText(_ flags: Flags) -> String {
            "Z=\(flags.zero ? 1 : 0), C=\(flags.carry ? 1 : 0), N=\(flags.negative ? 1 : 0)"
        }

        // MARK: Fetch

        ops.append(make(
            .fetch, "F1", "MAR ← PC",
            "PC holds \(Fmt.hex(pc)), the address of the next instruction. Copy it into the memory address register so memory knows where to look.",
            .transfer(from: .pc, to: .mar),
            [.pcOut, .marIn]
        ))

        ops.append(make(
            .fetch, "F2", "MDR ← MEM[MAR]",
            "Memory places the byte at \(Fmt.hex(address)) on the data bus. It is \(Fmt.hex(firstByte)); latch it into MDR.",
            .memoryRead,
            [.memRead, .mdrIn],
            memory: address
        ))

        ops.append(make(
            .fetch, "F3", "IR ← MDR · PC++",
            "The instruction byte moves into the instruction register. PC increments to \(Fmt.hex(pc &+ 1)).",
            .transfer(from: .mdr, to: .ir),
            [.mdrOut, .irIn, .pcInc],
            incPC: true
        ))

        // MARK: Decode

        let opcodeBits = Fmt.bits(firstByte >> 3, width: 5)
        let registerBits = Fmt.bits(firstByte & 0x07, width: 3)
        let registerName = instruction.register?.name ?? "—"

        let registerExplanation: String
        if opcode.hasRegisterField {
            registerExplanation = "register \(registerBits) selects \(registerName)"
        } else {
            registerExplanation = "the register field (\(registerBits)) is unused"
        }

        let operandExplanation: String
        switch opcode.operandKind {
        case .none:
            operandExplanation = "This is a one-byte instruction, so there is no operand fetch."
        case .register:
            operandExplanation = "A second byte follows; it selects the source or pointer register."
        case .value:
            operandExplanation = "A second byte follows; it is an immediate value."
        case .address:
            operandExplanation = "A second byte follows; it is an absolute address."
        }

        let decodeDetail = instruction.isValid
            ? "IR = \(Fmt.byteBits(firstByte)). Bits 7–3 give opcode \(opcodeBits) = \(opcode.mnemonic); \(registerExplanation). \(operandExplanation)"
            : "IR = \(Fmt.byteBits(firstByte)). Opcode \(opcodeBits) is not defined on NOVA-8. The control unit will treat it as NOP."

        ops.append(make(
            .decode, "D1", "Decode \(Fmt.hex(firstByte))",
            decodeDetail,
            .decode,
            [.decode]
        ))

        guard instruction.isValid else {
            ops.append(make(
                .execute, "E1", "Invalid instruction",
                "No control signals are asserted. The machine skips this byte and continues with the next instruction.",
                .nop
            ))
            return InstructionPlan(instruction: instruction, serial: serial, ops: ops)
        }

        // MARK: Operand fetch

        let operandByte = state.ram[Int(address &+ 1)]
        if instruction.size == 2 {
            ops.append(make(
                .operand, "O1", "MAR ← PC",
                "PC points at \(Fmt.hex(pc &+ 1)), the second byte of the instruction. Put that address on the address bus.",
                .transfer(from: .pc, to: .mar),
                [.pcOut, .marIn]
            ))

            ops.append(make(
                .operand, "O2", "MDR ← MEM[MAR]",
                "Memory returns \(Fmt.hex(operandByte)) from \(Fmt.hex(pc &+ 1)).",
                .memoryRead,
                [.memRead, .mdrIn],
                memory: pc &+ 1
            ))

            let operandDetail: String
            switch opcode.operandKind {
            case .register:
                operandDetail = "The second byte encodes register \(operandByte & 0x07) → \(instruction.source?.name ?? "?"). It is latched into T while the decoder selects it."
            case .value:
                operandDetail = "Immediate \(Fmt.hex(operandByte)) is latched into T. PC advances to \(Fmt.hex(pc &+ 2))."
            case .address:
                operandDetail = "Address \(Fmt.hex(operandByte)) is latched into T. PC advances to \(Fmt.hex(pc &+ 2))."
            case .none:
                operandDetail = "PC advances to \(Fmt.hex(pc &+ 2))."
            }

            ops.append(make(
                .operand, "O3", "T ← MDR · PC++",
                operandDetail,
                .transfer(from: .mdr, to: .t),
                [.mdrOut, .tIn, .pcInc],
                incPC: true
            ))
        }

        // MARK: Execute

        switch opcode {
        case .nop:
            ops.append(make(
                .execute, "E1", "No operation",
                "NOP burns one instruction without changing any register or flag.",
                .nop
            ))

        case .hlt:
            ops.append(make(
                .execute, "E1", "Halt",
                "The clock stops here. The machine will not fetch another instruction until it is reset.",
                .halt,
                [.halt]
            ))

        case .ldi:
            guard let register = instruction.register else { break }
            let value = instruction.value ?? 0
            ops.append(make(
                .execute, "E1", "\(register.name) ← T",
                "T holds the immediate \(Fmt.hex(value)). Load it into \(register.name); flags are unchanged by a load.",
                .transfer(from: .t, to: register.hardware),
                [.tOut, .regIn]
            ))

        case .ld:
            guard let register = instruction.register, let target = instruction.value else { break }
            let value = state.ram[Int(target)]
            ops.append(make(
                .execute, "E1", "MAR ← T",
                "T holds \(Fmt.hex(target)). Copy that address into MAR.",
                .transfer(from: .t, to: .mar),
                [.tOut, .marIn]
            ))
            ops.append(make(
                .execute, "E2", "MDR ← MEM[MAR]",
                "Memory returns \(Fmt.hex(value)) from \(Fmt.hex(target)) and latches it into MDR.",
                .memoryRead,
                [.memRead, .mdrIn],
                memory: target
            ))
            ops.append(make(
                .execute, "E3", "\(register.name) ← MDR",
                "Copy \(Fmt.hex(value)) into \(register.name). Loads do not affect the flags.",
                .transfer(from: .mdr, to: register.hardware),
                [.mdrOut, .regIn]
            ))

        case .st:
            guard let register = instruction.register, let target = instruction.value else { break }
            let value = state.read(register.hardware)
            ops.append(make(
                .execute, "E1", "MAR ← T",
                "T holds the destination address \(Fmt.hex(target)). Copy it into MAR.",
                .transfer(from: .t, to: .mar),
                [.tOut, .marIn]
            ))
            ops.append(make(
                .execute, "E2", "MDR ← \(register.name)",
                "Read \(register.name) (\(Fmt.hex(value))) onto the bus and latch it into MDR.",
                .transfer(from: register.hardware, to: .mdr),
                [.regOut, .mdrIn]
            ))
            ops.append(make(
                .execute, "E3", "MEM[MAR] ← MDR",
                "Assert write enable. \(Fmt.hex(value)) is stored at \(Fmt.hex(target)).",
                .memoryWrite,
                [.mdrOut, .memWrite],
                memory: target
            ))

        case .ldr:
            guard let register = instruction.register, let pointer = instruction.source else { break }
            let target = state.read(pointer.hardware)
            let value = state.ram[Int(target)]
            ops.append(make(
                .execute, "E1", "MAR ← \(pointer.name)",
                "\(pointer.name) is being used as a pointer. Its value \(Fmt.hex(target)) becomes the memory address.",
                .transfer(from: pointer.hardware, to: .mar),
                [.regOut, .marIn]
            ))
            ops.append(make(
                .execute, "E2", "MDR ← MEM[MAR]",
                "Memory returns \(Fmt.hex(value)) from \(Fmt.hex(target)).",
                .memoryRead,
                [.memRead, .mdrIn],
                memory: target
            ))
            ops.append(make(
                .execute, "E3", "\(register.name) ← MDR",
                "Load \(Fmt.hex(value)) into \(register.name).",
                .transfer(from: .mdr, to: register.hardware),
                [.mdrOut, .regIn]
            ))

        case .str:
            guard let register = instruction.register, let pointer = instruction.source else { break }
            let target = state.read(pointer.hardware)
            let value = state.read(register.hardware)
            ops.append(make(
                .execute, "E1", "MAR ← \(pointer.name)",
                "\(pointer.name) points at \(Fmt.hex(target)). Put it on the address bus.",
                .transfer(from: pointer.hardware, to: .mar),
                [.regOut, .marIn]
            ))
            ops.append(make(
                .execute, "E2", "MDR ← \(register.name)",
                "Latch \(Fmt.hex(value)) from \(register.name) into MDR.",
                .transfer(from: register.hardware, to: .mdr),
                [.regOut, .mdrIn]
            ))
            ops.append(make(
                .execute, "E3", "MEM[MAR] ← MDR",
                "Store \(Fmt.hex(value)) at \(Fmt.hex(target)).",
                .memoryWrite,
                [.mdrOut, .memWrite],
                memory: target
            ))

        case .mov:
            guard let destination = instruction.register, let source = instruction.source else { break }
            let value = state.read(source.hardware)
            ops.append(make(
                .execute, "E1", "\(destination.name) ← \(source.name)",
                "Copy \(Fmt.hex(value)) from \(source.name) to \(destination.name). No flags change.",
                .transfer(from: source.hardware, to: destination.hardware),
                [.regOut, .regIn]
            ))

        case .add, .sub, .and, .or, .xor, .cmp:
            guard let register = instruction.register else { break }
            let rhs = state.read(register.hardware)
            let operation: ALUOperation
            switch opcode {
            case .add: operation = .add
            case .sub: operation = .sub
            case .and: operation = .and
            case .or: operation = .or
            case .xor: operation = .xor
            default: operation = .cmp
            }

            let result = ALU.evaluate(operation, state.a, rhs, carryIn: state.flags.carry)
            let flags = flagsText(result.flags)

            if opcode == .cmp {
                ops.append(make(
                    .execute, "E1", "Flags ← A − \(register.name)",
                    "The ALU subtracts \(Fmt.hex(rhs)) from \(Fmt.hex(state.a)) = \(Fmt.hex(result.value)). \(flags). A is not written back.",
                    .alu(operation, source: register.hardware, destination: nil, writesFlags: true),
                    [.regOut, .aluOut, .flagsIn]
                ))
            } else {
                let title = "A ← A \(operation.symbol) \(register.name)"
                ops.append(make(
                    .execute, "E1", title,
                    "The ALU computes \(Fmt.hex(state.a)) \(operation.symbol) \(Fmt.hex(rhs)) = \(Fmt.hex(result.value)). \(flags). The result is written back to A.",
                    .alu(operation, source: register.hardware, destination: .a, writesFlags: true),
                    [.regOut, .aluOut, .regIn, .flagsIn]
                ))
            }

        case .inc, .dec, .not:
            guard let register = instruction.register else { break }
            let current = state.read(register.hardware)
            let operation: ALUOperation
            let title: String
            let description: String
            switch opcode {
            case .inc:
                operation = .inc
                title = "\(register.name) ← \(register.name) + 1"
                description = "Increment \(Fmt.hex(current)) to \(Fmt.hex(current &+ 1)). Carry is preserved."
            case .dec:
                operation = .dec
                title = "\(register.name) ← \(register.name) − 1"
                description = "Decrement \(Fmt.hex(current)) to \(Fmt.hex(current &- 1)). Carry is preserved."
            default:
                operation = .not
                title = "\(register.name) ← ~\(register.name)"
                description = "Bitwise complement: \(Fmt.binary(current)) becomes \(Fmt.binary(~current))."
            }
            let result = ALU.evaluate(operation, current, 1, carryIn: state.flags.carry)
            ops.append(make(
                .execute, "E1", title,
                "\(description) \(flagsText(result.flags)).",
                .alu(operation, source: nil, destination: register.hardware, writesFlags: true),
                [.regOut, .aluOut, .regIn, .flagsIn]
            ))

        case .shl, .shr:
            let operation: ALUOperation = opcode == .shl ? .shl : .shr
            let result = ALU.evaluate(operation, state.a, 0, carryIn: state.flags.carry)
            let title = opcode == .shl ? "A ← A << 1" : "A ← A >> 1"
            let description = opcode == .shl
                ? "Shift \(Fmt.binary(state.a)) left. The old bit 7 falls into carry."
                : "Shift \(Fmt.binary(state.a)) right. The old bit 0 falls into carry."
            ops.append(make(
                .execute, "E1", title,
                "\(description) Result \(Fmt.hex(result.value)); \(flagsText(result.flags)).",
                .alu(operation, source: nil, destination: .a, writesFlags: true),
                [.aluOut, .regIn, .flagsIn]
            ))

        case .addi:
            let immediate = instruction.value ?? 0
            let result = ALU.evaluate(.add, state.a, immediate, carryIn: state.flags.carry)
            ops.append(make(
                .execute, "E1", "A ← A + T",
                "T holds the immediate \(Fmt.hex(immediate)). \(Fmt.hex(state.a)) + \(Fmt.hex(immediate)) = \(Fmt.hex(result.value)). \(flagsText(result.flags)).",
                .alu(.add, source: .t, destination: .a, writesFlags: true),
                [.tOut, .aluOut, .regIn, .flagsIn]
            ))

        case .push:
            guard let register = instruction.register else { break }
            let sp = state.sp
            let value = state.read(register.hardware)
            ops.append(make(
                .execute, "E1", "MAR ← SP",
                "The stack pointer \(Fmt.hex(sp)) points at the next free slot. Copy it into MAR.",
                .transfer(from: .sp, to: .mar),
                [.spOut, .marIn]
            ))
            ops.append(make(
                .execute, "E2", "MDR ← \(register.name)",
                "Latch \(Fmt.hex(value)) from \(register.name) into MDR.",
                .transfer(from: register.hardware, to: .mdr),
                [.regOut, .mdrIn]
            ))
            ops.append(make(
                .execute, "E3", "MEM[MAR] ← MDR",
                "Push \(Fmt.hex(value)) onto the stack at \(Fmt.hex(sp)).",
                .memoryWrite,
                [.mdrOut, .memWrite],
                memory: sp
            ))
            ops.append(make(
                .execute, "E4", "SP ← SP − 1",
                "Move the stack pointer down to \(Fmt.hex(sp &- 1)). The stack grows toward lower addresses.",
                .alu(.dec, source: nil, destination: .sp, writesFlags: false),
                [.spDec]
            ))

        case .pop:
            guard let register = instruction.register else { break }
            let sp = state.sp
            let newSP = sp &+ 1
            let value = state.ram[Int(newSP)]
            ops.append(make(
                .execute, "E1", "SP ← SP + 1",
                "Move the stack pointer up from \(Fmt.hex(sp)) to \(Fmt.hex(newSP)).",
                .alu(.inc, source: nil, destination: .sp, writesFlags: false),
                [.spInc]
            ))
            ops.append(make(
                .execute, "E2", "MAR ← SP",
                "SP now points at the top item, \(Fmt.hex(newSP)).",
                .transfer(from: .sp, to: .mar),
                [.spOut, .marIn]
            ))
            ops.append(make(
                .execute, "E3", "MDR ← MEM[MAR]",
                "Read \(Fmt.hex(value)) from the stack.",
                .memoryRead,
                [.memRead, .mdrIn],
                memory: newSP
            ))
            ops.append(make(
                .execute, "E4", "\(register.name) ← MDR",
                "Pop \(Fmt.hex(value)) into \(register.name).",
                .transfer(from: .mdr, to: register.hardware),
                [.mdrOut, .regIn]
            ))

        case .jmp:
            let target = instruction.value ?? 0
            ops.append(make(
                .execute, "E1", "PC ← T",
                "T holds the jump target \(Fmt.hex(target)). Load it into the program counter.",
                .transfer(from: .t, to: .pc),
                [.tOut, .pcIn],
                memory: target
            ))

        case .jz, .jnz, .jc, .jnc:
            let target = instruction.value ?? 0
            let taken: Bool
            let condition: String
            switch opcode {
            case .jz:
                taken = state.flags.zero
                condition = "Z=\(state.flags.zero ? 1 : 0) (jump if zero)"
            case .jnz:
                taken = !state.flags.zero
                condition = "Z=\(state.flags.zero ? 1 : 0) (jump if not zero)"
            case .jc:
                taken = state.flags.carry
                condition = "C=\(state.flags.carry ? 1 : 0) (jump if carry)"
            default:
                taken = !state.flags.carry
                condition = "C=\(state.flags.carry ? 1 : 0) (jump if no carry)"
            }
            let detail = taken
                ? "\(condition) is true, so PC ← \(Fmt.hex(target)). The fetch resumes there."
                : "\(condition) is false, so the branch is skipped and PC stays at \(Fmt.hex(pc &+ 2))."
            ops.append(make(
                .execute, "E1", taken ? "PC ← T" : "Branch skipped",
                detail,
                .branch(taken: taken, target: target),
                taken ? [.tOut, .pcIn] : [],
                memory: taken ? target : nil
            ))

        case .call:
            let target = instruction.value ?? 0
            let returnAddress = address &+ 2
            let sp = state.sp
            ops.append(make(
                .execute, "E1", "MAR ← SP",
                "A call must remember where to return. SP = \(Fmt.hex(sp)); copy it into MAR.",
                .transfer(from: .sp, to: .mar),
                [.spOut, .marIn]
            ))
            ops.append(make(
                .execute, "E2", "MDR ← PC",
                "The return address \(Fmt.hex(returnAddress)) (the instruction after CALL) goes into MDR.",
                .transfer(from: .pc, to: .mdr),
                [.pcOut, .mdrIn]
            ))
            ops.append(make(
                .execute, "E3", "MEM[MAR] ← MDR",
                "Push the return address onto the stack at \(Fmt.hex(sp)).",
                .memoryWrite,
                [.mdrOut, .memWrite],
                memory: sp
            ))
            ops.append(make(
                .execute, "E4", "SP ← SP − 1",
                "Point SP at the next free slot, \(Fmt.hex(sp &- 1)).",
                .alu(.dec, source: nil, destination: .sp, writesFlags: false),
                [.spDec]
            ))
            ops.append(make(
                .execute, "E5", "PC ← T",
                "Jump to the subroutine at \(Fmt.hex(target)).",
                .transfer(from: .t, to: .pc),
                [.tOut, .pcIn],
                memory: target
            ))

        case .ret:
            let sp = state.sp
            let newSP = sp &+ 1
            let returnAddress = state.ram[Int(newSP)]
            ops.append(make(
                .execute, "E1", "SP ← SP + 1",
                "Discard the top stack slot; SP moves to \(Fmt.hex(newSP)).",
                .alu(.inc, source: nil, destination: .sp, writesFlags: false),
                [.spInc]
            ))
            ops.append(make(
                .execute, "E2", "MAR ← SP",
                "The saved return address lives at \(Fmt.hex(newSP)).",
                .transfer(from: .sp, to: .mar),
                [.spOut, .marIn]
            ))
            ops.append(make(
                .execute, "E3", "MDR ← MEM[MAR]",
                "Read the return address \(Fmt.hex(returnAddress)).",
                .memoryRead,
                [.memRead, .mdrIn],
                memory: newSP
            ))
            ops.append(make(
                .execute, "E4", "PC ← MDR",
                "Return to \(Fmt.hex(returnAddress)).",
                .transfer(from: .mdr, to: .pc),
                [.mdrOut, .pcIn],
                memory: returnAddress
            ))
        }

        return InstructionPlan(instruction: instruction, serial: serial, ops: ops)
    }
}
