import Foundation

struct MachineSnapshot: Equatable, Sendable {
    var state: CPUState
    var pending: [MicroOp]
    var currentInstruction: DecodedInstruction?
    var currentOps: [MicroOp]
    var nextSerial: Int
}

struct StepOutcome: Equatable, Sendable {
    let before: CPUState
    let after: CPUState
    let op: MicroOp
    let instruction: DecodedInstruction?
}

/// The clock. A Machine owns the architectural state plus the remaining
/// micro-ops of the instruction currently in flight.
struct Machine: Equatable, Sendable {
    private(set) var state: CPUState
    private(set) var pending: [MicroOp] = []
    private(set) var currentInstruction: DecodedInstruction?
    private(set) var currentOps: [MicroOp] = []
    private var nextSerial: Int = 0

    init(memory: [UInt8] = Array(repeating: 0, count: 256), input: UInt8 = 0) {
        self.state = CPUState(memory: memory, input: input)
    }

    var snapshot: MachineSnapshot {
        MachineSnapshot(
            state: state,
            pending: pending,
            currentInstruction: currentInstruction,
            currentOps: currentOps,
            nextSerial: nextSerial
        )
    }

    mutating func restore(_ snapshot: MachineSnapshot) {
        state = snapshot.state
        pending = snapshot.pending
        currentInstruction = snapshot.currentInstruction
        currentOps = snapshot.currentOps
        nextSerial = snapshot.nextSerial
    }

    var isAtInstructionBoundary: Bool {
        pending.isEmpty
    }

    var isHalted: Bool {
        state.halted && pending.isEmpty
    }

    var upcomingOps: [MicroOp] {
        pending
    }

    mutating func setMemory(_ value: UInt8, at address: UInt8) {
        state.ram[Int(address)] = value
    }

    /// Execute exactly one clock cycle.
    @discardableResult
    mutating func step() -> StepOutcome? {
        if state.halted && pending.isEmpty {
            return nil
        }

        if pending.isEmpty {
            let plan = InstructionPlanner.plan(
                address: state[.pc],
                state: state,
                serial: nextSerial
            )
            nextSerial += 1
            currentInstruction = plan.instruction
            currentOps = plan.ops
            pending = plan.ops
        }

        let before = state
        let op = pending.removeFirst()
        op.apply(to: &state)

        if pending.isEmpty {
            state.instructionCount += 1
        }

        return StepOutcome(
            before: before,
            after: state,
            op: op,
            instruction: currentInstruction
        )
    }

    /// Execute until the current instruction retires.
    @discardableResult
    mutating func stepInstruction() -> StepOutcome? {
        guard !isHalted else { return nil }
        let startingCount = state.instructionCount
        var last: StepOutcome?

        repeat {
            guard let outcome = step() else { break }
            last = outcome
            if state.halted { break }
        } while state.instructionCount == startingCount

        return last
    }

    /// Execute every remaining micro-op belonging to the current stage.
    @discardableResult
    mutating func stepPhase() -> StepOutcome? {
        guard !isHalted else { return nil }
        guard var last = step() else { return nil }
        let stage = last.op.stage

        while let next = pending.first, next.stage == stage {
            guard let outcome = step() else { break }
            last = outcome
            if state.halted { break }
        }
        return last
    }
}
