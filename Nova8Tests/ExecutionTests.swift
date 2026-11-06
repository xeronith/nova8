import XCTest
@testable import Nova8

final class ExecutionTests: XCTestCase {

    private func execute(_ source: String, maxCycles: Int = 40_000) -> (machine: Machine, program: AssembledProgram) {
        let program = Assembler.assemble(source)
        XCTAssertFalse(program.hasErrors, program.diagnostics.map(\.message).joined(separator: " | "))

        var machine = Machine(memory: program.memory)
        var cycles = 0
        while !machine.isHalted && cycles < maxCycles {
            machine.step()
            cycles += 1
        }
        XCTAssertTrue(machine.isHalted, "Program did not halt within \(maxCycles) cycles")
        return (machine, program)
    }

    func testSumOneToTen() {
        let (machine, _) = execute("""
        start: LDI A, 0
               LDI B, 10
        loop:  ADD B
               DEC B
               JNZ loop
               OUT A
               HLT
        """)
        XCTAssertEqual(machine.state.a, 55)
        XCTAssertEqual(machine.state.ram[Int(MemoryMap.displayPort)], 55)
    }

    func testMultiply() {
        let (machine, _) = execute("""
        start: LDI A, 0
               LDI B, 6
               LDI C, 7
        loop:  ADD B
               DEC C
               JNZ loop
               OUT A
               HLT
        """)
        XCTAssertEqual(machine.state.a, 42)
    }

    func testCountdown() {
        let (machine, _) = execute("""
        start: LDI B, 5
        loop:  OUT B
               DEC B
               JNZ loop
               HLT
        """)
        XCTAssertEqual(machine.state.b, 0)
        XCTAssertEqual(machine.state.ram[Int(MemoryMap.displayPort)], 1)
    }

    func testFibonacci() {
        let (machine, _) = execute("""
        start: LDI A, 0
               LDI B, 1
               LDI D, 10
        loop:  OUT A
               MOV C, A
               ADD B
               MOV B, C
               DEC D
               JNZ loop
               HLT
        """)
        XCTAssertEqual(machine.state.d, 0)
        XCTAssertEqual(machine.state.ram[Int(MemoryMap.displayPort)], 34)
    }

    func testSubroutineAndStack() {
        let (machine, _) = execute("""
        start: LDI A, 5
               LDI B, 99
               CALL addten
               OUT A
               OUT B
               HLT
        addten: PUSH B
                LDI B, 10
                ADD B
                POP B
                RET
        """)
        XCTAssertEqual(machine.state.a, 15)
        XCTAssertEqual(machine.state.b, 99)
        XCTAssertEqual(machine.state.sp, MemoryMap.stackPointerInitial)
        XCTAssertEqual(machine.state.ram[Int(MemoryMap.displayPort)], 99)
    }

    func testBlockCopy() {
        let (machine, _) = execute("""
        start: LDI A, src
               LDI B, dst
               LDI C, 8
        loop:  LDR D, A
               STR D, B
               INC A
               INC B
               DEC C
               JNZ loop
               LDI A, 0xAA
               OUT A
               HLT
        .data
        src: DB 1, 2, 3, 4, 5, 6, 7, 8
        dst: DB 0, 0, 0, 0, 0, 0, 0, 0
        """)
        XCTAssertEqual(Array(machine.state.ram[0x88..<0x90]), [1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(machine.state.a, 0xAA)
    }

    func testZeroFlagAndConditionalBranch() {
        let (machine, _) = execute("""
        start: LDI A, 1
               SUB A
               JZ done
               LDI A, 99
        done:  HLT
        """)
        XCTAssertEqual(machine.state.a, 0)
        XCTAssertTrue(machine.state.flags.zero)
    }

    func testBorrowSetsCarryAndNegative() {
        let (machine, _) = execute("""
        start: LDI A, 0
               LDI B, 1
               SUB B
               HLT
        """)
        XCTAssertEqual(machine.state.a, 255)
        XCTAssertTrue(machine.state.flags.carry)
        XCTAssertTrue(machine.state.flags.negative)
        XCTAssertFalse(machine.state.flags.zero)
    }

    func testIncrementDoesNotClearCarry() {
        let program = Assembler.assemble("INC B\nHLT")
        var machine = Machine(memory: program.memory)
        var snapshot = machine.snapshot
        snapshot.state.flags.carry = true
        machine.restore(snapshot)
        machine.step() // fetch
        machine.step()
        machine.step()
        machine.step() // decode
        machine.step() // execute
        XCTAssertEqual(machine.state.b, 1)
        XCTAssertTrue(machine.state.flags.carry)
    }

    func testInputPortIsReadable() {
        let program = Assembler.assemble("IN A\nHLT")
        var machine = Machine(memory: program.memory, input: 0x5A)
        for _ in 0..<10 where !machine.isHalted {
            machine.step()
        }
        XCTAssertEqual(machine.state.a, 0x5A)
    }
}
