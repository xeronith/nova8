import Foundation

struct HistoryEntry: Identifiable, Equatable, Sendable {
    let id: Int
    let snapshot: MachineSnapshot
    let op: MicroOp?
    let instruction: DecodedInstruction?

    var stage: MicroStage? { op?.stage }
    var title: String { op?.timelineTitle ?? "Reset" }
}

struct HistoryGroup: Identifiable, Equatable, Sendable {
    let id: Int
    let serial: Int
    let address: UInt8
    let instructionText: String
    let entries: [HistoryEntry]
}

/// A flight recorder for the machine. Every entry is a complete snapshot, so
/// scrubbing backwards is exact and stepping from the past forks the future.
struct History: Equatable, Sendable {
    private(set) var entries: [HistoryEntry]
    private(set) var cursor: Int
    private var nextID: Int
    let limit: Int

    init(initial: MachineSnapshot, limit: Int = 2500) {
        self.entries = [HistoryEntry(id: 0, snapshot: initial, op: nil, instruction: nil)]
        self.cursor = 0
        self.nextID = 1
        self.limit = limit
    }

    var current: HistoryEntry {
        entries[min(max(cursor, 0), entries.count - 1)]
    }

    var isLive: Bool {
        cursor == entries.count - 1
    }

    var canRewind: Bool {
        cursor > 0
    }

    var canFastForward: Bool {
        cursor < entries.count - 1
    }

    mutating func reset(initial: MachineSnapshot) {
        entries = [HistoryEntry(id: 0, snapshot: initial, op: nil, instruction: nil)]
        cursor = 0
        nextID = 1
    }

    mutating func append(
        snapshot: MachineSnapshot,
        op: MicroOp,
        instruction: DecodedInstruction?
    ) {
        if cursor < entries.count - 1 {
            entries.removeSubrange((cursor + 1)...)
        }

        entries.append(HistoryEntry(id: nextID, snapshot: snapshot, op: op, instruction: instruction))
        nextID += 1
        cursor = entries.count - 1
        trimIfNeeded()
    }

    mutating func jump(to index: Int) {
        guard !entries.isEmpty else { return }
        cursor = min(max(index, 0), entries.count - 1)
    }

    mutating func jump(by delta: Int) {
        jump(to: cursor + delta)
    }

    mutating func replaceCurrent(snapshot: MachineSnapshot) {
        guard entries.indices.contains(cursor) else { return }
        let current = entries[cursor]
        entries[cursor] = HistoryEntry(
            id: current.id,
            snapshot: snapshot,
            op: current.op,
            instruction: current.instruction
        )
    }

    /// The instruction groups that have been recorded, oldest first.
    func groups() -> [HistoryGroup] {
        var result: [HistoryGroup] = []
        var currentSerial: Int?
        var bucket: [HistoryEntry] = []
        var headerOp: MicroOp?

        func flush() {
            guard let serial = currentSerial, let header = headerOp else { return }
            result.append(HistoryGroup(
                id: serial,
                serial: serial,
                address: header.instructionAddress,
                instructionText: header.instructionText,
                entries: bucket
            ))
            bucket = []
        }

        for entry in entries {
            guard let op = entry.op else { continue }
            if op.instructionSerial != currentSerial {
                flush()
                currentSerial = op.instructionSerial
                headerOp = op
            }
            bucket.append(entry)
        }
        flush()
        return result
    }

    private mutating func trimIfNeeded() {
        guard entries.count > limit else { return }
        let overflow = entries.count - limit
        entries.removeFirst(overflow)
        cursor = max(0, cursor - overflow)
    }
}
