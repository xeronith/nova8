import XCTest
@testable import Nova8

final class AssemblerTests: XCTestCase {

    private func assemble(_ source: String) -> AssembledProgram {
        Assembler.assemble(source)
    }

    func testImmediateEncoding() {
        let result = assemble("LDI A, 5")
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(2)), [0x18, 0x05])
    }

    func testRegisterAndAddressEncoding() {
        let result = assemble("LD B, 0x80\nST A, DISPLAY")
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(4)), [0x21, 0x80, 0x28, 0xF0])
    }

    func testALUAndBranches() {
        let result = assemble("""
        start: LDI A, 1
               ADD B
               JNZ start
               HLT
        """)
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(6)), [
            0x18, 0x01, // LDI A, 1
            0x49,       // ADD B
            0xC0, 0x00, // JNZ start
            0x08        // HLT
        ])
    }

    func testIndirectAndMoveEncoding() {
        let result = assemble("LDR D, A\nSTR D, B\nMOV C, A")
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(6)), [
            0x33, 0x00,
            0x3B, 0x01,
            0x42, 0x00
        ])
    }

    func testStackAndCallEncoding() {
        let result = assemble("PUSH B\nPOP C\nCALL 0x10\nRET\nADDI 10\nSHL")
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(8)), [
            0xA1,       // PUSH B
            0xAA,       // POP C
            0xD8, 0x10, // CALL 0x10
            0x10,       // RET
            0xE0, 0x0A, // ADDI 10
            0x90        // SHL
        ])
    }

    func testLabelsAndDataSection() {
        let result = assemble("""
        .data
        src: DB 1, 2, 3
        .text
        start: LDI A, src
               JMP start
        """)
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(result.symbols["src"], 0x80)
        XCTAssertEqual(result.symbols["start"], 0x00)
        XCTAssertEqual(Array(result.memory[0x80..<0x83]), [1, 2, 3])
        XCTAssertEqual(Array(result.memory.prefix(4)), [0x18, 0x80, 0xB0, 0x00])
    }

    func testStringsAndConstants() {
        let result = assemble("""
        COUNT = 3
        .data
        msg: DB "HI", 0
        .text
        LDI A, COUNT
        """)
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(result.symbols["COUNT"], 3)
        XCTAssertEqual(Array(result.memory[0x80..<0x83]), [72, 73, 0])
        XCTAssertEqual(Array(result.memory.prefix(2)), [0x18, 0x03])
    }

    func testOutAliasBecomesStoreToDisplay() {
        let result = assemble("OUT B")
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(2)), [0x29, 0xF0])
    }

    func testUnknownMnemonicProducesDiagnostic() {
        let result = assemble("FROB A")
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.diagnostics.contains { $0.message.contains("Unknown instruction") })
    }

    func testForwardReferenceResolves() {
        let result = assemble("""
        JMP done
        done: HLT
        """)
        XCTAssertFalse(result.hasErrors, "\(result.diagnostics)")
        XCTAssertEqual(Array(result.memory.prefix(3)), [0xB0, 0x02, 0x08])
    }

    func testOutOfRangeImmediateFails() {
        let result = assemble("LDI A, 300")
        XCTAssertTrue(result.hasErrors)
    }
}
