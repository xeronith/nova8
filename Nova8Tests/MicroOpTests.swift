import XCTest
@testable import Nova8

final class MicroOpTests: XCTestCase {

    private func program(_ source: String) -> AssembledProgram {
        let result = Assembler.assemble(source)
        XCTAssertFalse(result.hasErrors, result.diagnostics.map(\.message).joined(separator: " | "))
        return result
    }

    func testImmediateTrace() {
        let assembled = program("LDI A, 5")
        var machine = Machine(memory: assembled.memory)
        var trace: [MicroOp] = []

        while machine.state.instructionCount == 0 {
            guard let outcome = machine.step() else { break }
            trace.append(outcome.op)
        }

        XCTAssertEqual(trace.map(\.slot), ["F1", "F2", "F3", "D1", "O1", "O2", "O3", "E1"])
        XCTAssertEqual(trace.map(\.stage), [.fetch, .fetch, .fetch, .decode, .operand, .operand, .operand, .execute])
        XCTAssertEqual(machine.state.a, 5)
        XCTAssertEqual(machine.state.pc, 2)
    }

    func testALUExecutesInOneCycle() {
        let assembled = program("ADD B\nHLT")
        var machine = Machine(memory: assembled.memory)
        var snapshot = machine.snapshot
        snapshot.state.a = 2
        snapshot.state.b = 3
        machine.restore(snapshot)

        var trace: [MicroOp] = []
        machine.step()
        machine.step()
        machine.step()
        machine.step()
        let outcome = machine.step()
        if let outcome { trace.append(outcome.op) }

        XCTAssertEqual(trace.map(\.slot), ["E1"])
        XCTAssertEqual(machine.state.a, 5)
        XCTAssertEqual(machine.state.instructionCount, 1)
    }

    func testLoadAbsoluteTraceReadsMemory() {
        let assembled = program("LD A, 0x80\nHLT")
        var machine = Machine(memory: assembled.memory)
        machine.setMemory(0x2A, at: 0x80)

        var trace: [MicroOp] = []
        while machine.state.instructionCount == 0 {
            guard let outcome = machine.step() else { break }
            trace.append(outcome.op)
        }

        XCTAssertEqual(trace.map(\.slot), ["F1", "F2", "F3", "D1", "O1", "O2", "O3", "E1", "E2", "E3"])
        XCTAssertEqual(machine.state.a, 0x2A)
        XCTAssertEqual(machine.state.pc, 2)
    }

    func testConditionalBranchNotTaken() {
        let assembled = program("JZ 0x10\nHLT")
        var machine = Machine(memory: assembled.memory)
        // Zero is false by reset, so the branch falls through.
        var trace: [MicroOp] = []
        while machine.state.instructionCount == 0 {
            guard let outcome = machine.step() else { break }
            trace.append(outcome.op)
        }
        XCTAssertEqual(machine.state.pc, 2)
        XCTAssertEqual(trace.last?.title, "Branch skipped")
    }

    func testConditionalBranchTaken() {
        let assembled = program("JZ 0x10\nHLT")
        var machine = Machine(memory: assembled.memory)
        var snapshot = machine.snapshot
        snapshot.state.flags.zero = true
        machine.restore(snapshot)

        while machine.state.instructionCount == 0 {
            machine.step()
        }
        XCTAssertEqual(machine.state.pc, 0x10)
    }

    func testStepPhaseGroupsCycles() {
        let assembled = program("LDI A, 5")
        var machine = Machine(memory: assembled.memory)

        let first = machine.stepPhase()
        XCTAssertEqual(first?.op.stage, .fetch)
        XCTAssertEqual(machine.state.pc, 1)

        let second = machine.stepPhase()
        XCTAssertEqual(second?.op.stage, .decode)
        XCTAssertEqual(machine.state.pc, 1)

        let third = machine.stepPhase()
        XCTAssertEqual(third?.op.stage, .operand)
        XCTAssertEqual(machine.state.pc, 2)

        let fourth = machine.stepPhase()
        XCTAssertEqual(fourth?.op.stage, .execute)
        XCTAssertEqual(machine.state.a, 5)
    }

    func testHistoryRestoreAndFork() {
        let assembled = program("LDI A, 5\nLDI B, 7\nHLT")
        var machine = Machine(memory: assembled.memory)
        var history = History(initial: machine.snapshot)

        for _ in 0..<12 {
            guard let outcome = machine.step() else { break }
            history.append(snapshot: machine.snapshot, op: outcome.op, instruction: outcome.instruction)
        }

        let fullCount = history.entries.count
        XCTAssertGreaterThan(fullCount, 5)

        history.jump(to: 4)
        machine.restore(history.current.snapshot)

        guard let outcome = machine.step() else {
            return XCTFail("Expected to be able to step after restoring")
        }
        history.append(snapshot: machine.snapshot, op: outcome.op, instruction: outcome.instruction)

        XCTAssertEqual(history.entries.count, 6)
        XCTAssertEqual(machine.state.mar, 1)
    }

    func testCallPushesReturnAddress() {
        let assembled = program("""
        CALL sub
        HLT
        sub: RET
        """)
        var machine = Machine(memory: assembled.memory)

        // CALL has F1-F3, D1, O1-O3, E1-E5 = 12 cycles.
        for _ in 0..<12 { machine.step() }
        XCTAssertEqual(machine.state.pc, 0x03)
        XCTAssertEqual(machine.state.ram[Int(MemoryMap.stackPointerInitial)], 0x02)
        XCTAssertEqual(machine.state.sp, MemoryMap.stackPointerInitial &- 1)
    }
}
