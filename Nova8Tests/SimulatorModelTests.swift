import XCTest
@testable import Nova8

@MainActor
final class SimulatorModelTests: XCTestCase {

    private func model() -> SimulatorModel {
        let model = SimulatorModel()
        model.loadSample(id: "countdown")
        model.speed = 4.0
        return model
    }

    func testMicroStepAdvancesOneCycle() {
        let model = self.model()
        let before = model.state.microOpCount
        model.stepMode = .micro
        model.step()
        XCTAssertEqual(model.state.microOpCount, before + 1)
        XCTAssertEqual(model.history.entries.count, 2)
        XCTAssertTrue(model.history.isLive)
    }

    func testInstructionStepRetiresInstruction() {
        let model = self.model()
        model.stepMode = .instruction
        model.step()
        XCTAssertEqual(model.state.instructionCount, 1)
        XCTAssertEqual(model.state.microOpCount, 8) // LDI B, 5
        XCTAssertEqual(model.history.entries.count, 9) // every cycle is recorded
    }

    func testPhaseStepRecordsEveryCycle() {
        let model = self.model()
        model.stepMode = .phase
        model.step() // fetch: F1 F2 F3
        XCTAssertEqual(model.state.microOpCount, 3)
        XCTAssertEqual(model.history.entries.count, 4)
        model.step() // decode: D1
        XCTAssertEqual(model.state.microOpCount, 4)
        XCTAssertEqual(model.history.entries.count, 5)
    }

    func testTimeTravelRestoresForkPoint() {
        let model = self.model()
        for _ in 0..<9 { model.step() }
        XCTAssertEqual(model.history.cursor, 9)

        model.jumpHistory(to: 4)
        XCTAssertEqual(model.history.cursor, 4)
        XCTAssertEqual(model.machine.state, model.history.entries[4].snapshot.state)
        XCTAssertFalse(model.history.isLive)
        XCTAssertTrue(model.scrubbing)

        model.step()
        XCTAssertEqual(model.history.entries.count, 6)
        XCTAssertTrue(model.history.isLive)
    }

    func testAssemblyErrorPreventsExecution() {
        let model = self.model()
        model.updateSource("FROB A")
        model.assembleAndLoad()
        XCTAssertTrue(model.hasErrors)
        let before = model.state.microOpCount
        model.step()
        XCTAssertEqual(model.state.microOpCount, before)
    }

    func testInputPortUpdates() {
        let model = self.model()
        model.setInput(0x7E)
        XCTAssertEqual(model.state.ram[Int(MemoryMap.inputPort)], 0x7E)
        XCTAssertEqual(model.inputValue, 0x7E)
    }

    func testBreakpointStopsRun() async throws {
        let model = self.model()
        // OUT B lives on line 7 of the countdown sample.
        model.toggleBreakpoint(line: 7)
        model.run()

        try await waitUntil(timeout: 4.0) { !model.isRunning }

        XCTAssertEqual(model.lastBreakpointHit, 0x02)
        XCTAssertFalse(model.machine.isHalted)
        XCTAssertTrue(model.statusMessage?.contains("Paused at") ?? false)
    }

    func testRunReachesHalt() async throws {
        let model = SimulatorModel()
        model.loadSample(id: "blank")
        model.speed = 100
        model.run()
        try await waitUntil(timeout: 5.0) { !model.isRunning }

        XCTAssertTrue(model.machine.isHalted)
        XCTAssertEqual(model.state.ram[Int(MemoryMap.displayPort)], 42)
        XCTAssertEqual(model.state.instructionCount, 3)
    }

    func testScrubbingOutputLog() {
        let model = self.model()
        for _ in 0..<18 { model.step() } // runs LDI and ST, which writes 5 to the display
        XCTAssertEqual(model.outputLog.last?.value, 5)

        model.jumpHistory(to: 0)
        XCTAssertTrue(model.outputLog.isEmpty)
        XCTAssertEqual(model.machine.state.ram[Int(MemoryMap.displayPort)], 0)
    }

    private func waitUntil(
        timeout: TimeInterval,
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}
