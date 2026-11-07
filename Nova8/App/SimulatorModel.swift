import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum StepMode: String, CaseIterable, Identifiable {
    case micro = "μop"
    case phase = "Phase"
    case instruction = "Instr"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .micro: return "One micro-operation"
        case .phase: return "One whole stage"
        case .instruction: return "One full instruction"
        }
    }
}

struct OutputEvent: Identifiable, Equatable {
    let id: Int
    let value: UInt8
    let instructionText: String
}

@MainActor
@Observable
final class SimulatorModel {

    // MARK: Program

    var source: String
    var selectedSampleID: String
    var program: AssembledProgram?
    var diagnostics: [Diagnostic]
    var needsReload: Bool = false
    var cursorLine: Int = 1
    var showSamples: Bool = false
    var showDiagnostics: Bool = false
    var showEditor: Bool = true
    var focusLine: Int = 1
    var focusToken: Int = 0

    // MARK: Machine

    var machine: Machine
    var history: History
    var lastOutcome: StepOutcome?
    var animationToken: Int = 0
    var isRunning: Bool = false
    var scrubbing: Bool = false
    var speed: Double = 1.0
    var stepMode: StepMode = .micro
    var inputByte: UInt8 = 0x2A
    var outputLog: [OutputEvent] = []
    var breakpointLines: Set<Int> = []
    var runToAddress: UInt8?
    var lastBreakpointHit: UInt8?
    var statusMessage: String?

    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var ignoreBreakpointAddress: UInt8?
    @ObservationIgnored private var nextOutputID: Int = 0
    @ObservationIgnored private let autosaveEnabled: Bool

    // MARK: Init

    init(autosaveEnabled: Bool = true) {
        self.autosaveEnabled = autosaveEnabled
        let saved = autosaveEnabled ? Self.readAutosave() : nil
        let initialSource: String
        let initialSample: String

        if let saved, !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialSource = saved
            initialSample = SampleCatalog.all.first(where: { $0.source == saved })?.id ?? ""
        } else if let first = SampleCatalog.all.first {
            initialSource = first.source
            initialSample = first.id
        } else {
            initialSource = "; NOVA-8\nHLT\n"
            initialSample = "blank"
        }

        let program = Assembler.assemble(initialSource)
        let machine = Machine(memory: program.memory, input: 0x2A)

        self.source = initialSource
        self.selectedSampleID = initialSample
        self.program = program
        self.diagnostics = program.diagnostics
        self.machine = machine
        self.history = History(initial: machine.snapshot)
        self.showDiagnostics = program.hasErrors
    }

    // MARK: Derived state

    var state: CPUState { machine.state }

    var currentSample: SampleProgram? {
        SampleCatalog.sample(id: selectedSampleID)
    }

    var hasErrors: Bool {
        program?.hasErrors ?? true
    }

    var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }

    var canStep: Bool {
        !hasErrors && !isRunning && !machine.isHalted
    }

    var canRun: Bool {
        !hasErrors && !isRunning && !machine.isHalted
    }

    var isLive: Bool {
        history.isLive
    }

    var currentStage: MicroStage? {
        if let lastOutcome {
            return lastOutcome.op.stage
        }
        if let next = machine.upcomingOps.first {
            return next.stage
        }
        return nil
    }

    var currentOp: MicroOp? {
        lastOutcome?.op
    }

    var nextOp: MicroOp? {
        machine.upcomingOps.first
    }

    var currentInstruction: DecodedInstruction {
        if let instruction = machine.currentInstruction,
           !machine.isAtInstructionBoundary || machine.isHalted {
            return instruction
        }
        return DecodedInstruction.decode(at: machine.state.pc, memory: machine.state.ram)
    }

    var currentLine: Int? {
        let address: UInt8
        if machine.isHalted {
            address = machine.currentInstruction?.address ?? machine.state.pc
        } else if machine.isAtInstructionBoundary {
            address = machine.state.pc
        } else {
            address = machine.currentInstruction?.address ?? machine.state.pc
        }
        return program?.line(forAddress: address)
    }

    var pcLine: Int? {
        program?.line(forAddress: machine.state.pc)
    }

    var displayValue: UInt8 {
        machine.state.displayValue
    }

    var inputValue: UInt8 {
        machine.state.inputValue
    }

    var stackDepth: Int {
        machine.state.stackDepth
    }

    var currentNote: SampleNote? {
        guard let sample = currentSample else { return nil }
        let stage = currentStage

        let noteLine: Int?
        if let last = lastOutcome, !machine.isHalted {
            noteLine = program?.line(forAddress: last.op.instructionAddress) ?? currentLine
        } else {
            noteLine = currentLine
        }

        let anchored = sample.notes.filter { note in
            guard let anchor = note.anchor else { return true }
            guard let noteLine else { return false }
            return sourceLine(noteLine).contains(anchor)
        }

        if let stage,
           let exact = anchored.first(where: { $0.stages?.contains(stage) ?? true }) {
            return exact
        }
        return anchored.first
    }

    var stepDelay: TimeInterval {
        max(0.035, min(1.4, 0.34 / max(0.25, speed)))
    }

    var animationDuration: TimeInterval {
        min(0.34, stepDelay * 0.92)
    }

    func sourceLine(_ line: Int) -> String {
        let lines = source.components(separatedBy: .newlines)
        guard line >= 1, line <= lines.count else { return "" }
        return lines[line - 1]
    }

    func focus(line: Int) {
        focusLine = max(1, line)
        cursorLine = focusLine
        focusToken += 1
    }

    // MARK: Editing

    func updateSource(_ text: String) {
        guard text != source else { return }
        source = text
        pause()
        needsReload = true
        statusMessage = nil

        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            self.previewAssemble()
        }
    }

    private func previewAssemble() {
        let result = Assembler.assemble(source)
        program = result
        diagnostics = result.diagnostics
        showDiagnostics = !result.diagnostics.isEmpty
        saveAutosave()
    }

    func assembleAndLoad() {
        pause()
        let result = Assembler.assemble(source)
        program = result
        diagnostics = result.diagnostics
        saveAutosave()

        guard !result.hasErrors else {
            needsReload = true
            statusMessage = result.diagnostics.first?.message ?? "Assembly failed."
            showDiagnostics = true
            return
        }

        needsReload = false
        showDiagnostics = false
        loadMachine(memory: result.memory)
        statusMessage = "Assembled \(result.listing.count) instructions."
    }

    private func prepareToExecute() -> Bool {
        if needsReload || program == nil {
            assembleAndLoad()
        }
        guard let program, !program.hasErrors else {
            statusMessage = "Fix the assembly errors before running."
            showDiagnostics = true
            return false
        }
        return true
    }

    private func loadMachine(memory: [UInt8]) {
        machine = Machine(memory: memory, input: inputByte)
        history = History(initial: machine.snapshot)
        lastOutcome = nil
        outputLog = []
        nextOutputID = 0
        scrubbing = false
        lastBreakpointHit = nil
        ignoreBreakpointAddress = nil
        animationToken += 1
    }

    func reset() {
        pause()
        guard prepareToExecute() else { return }
        loadMachine(memory: program?.memory ?? Array(repeating: 0, count: 256))
        runToAddress = nil
        statusMessage = nil
    }

    // MARK: Stepping

    func step() {
        pause()
        guard prepareToExecute() else { return }
        guard !machine.isHalted else {
            statusMessage = "The machine is halted. Reset to run again."
            return
        }

        switch stepMode {
        case .micro:
            if let outcome = machine.step() {
                record(outcome)
            }

        case .phase:
            guard let first = machine.step() else { return }
            record(first)
            let stage = first.op.stage
            while let next = machine.upcomingOps.first,
                  next.stage == stage,
                  let outcome = machine.step() {
                record(outcome)
            }

        case .instruction:
            let startCount = machine.state.instructionCount
            repeat {
                guard let outcome = machine.step() else { break }
                record(outcome)
                if machine.isHalted { break }
            } while machine.state.instructionCount == startCount
        }

        lastBreakpointHit = nil

        if machine.isHalted {
            statusMessage = "Halted after \(machine.state.instructionCount) instructions."
        }
    }

    func stepBack() {
        guard history.canRewind else { return }
        jumpHistory(to: history.cursor - 1)
    }

    func run() {
        guard !isRunning else { return }
        guard prepareToExecute() else { return }
        guard !machine.isHalted else {
            statusMessage = "The machine is halted. Reset to run again."
            return
        }

        isRunning = true
        statusMessage = nil
        lastBreakpointHit = nil
        scrubbing = false

        runTask?.cancel()
        runTask = Task { [weak self] in
            while true {
                guard let self, !Task.isCancelled, self.isRunning else { return }

                if self.shouldStopForBreakpoint() {
                    self.isRunning = false
                    return
                }

                if let outcome = self.machine.step() {
                    self.record(outcome)
                }

                if self.machine.isHalted {
                    self.isRunning = false
                    self.statusMessage = "Halted after \(self.machine.state.instructionCount) instructions."
                    return
                }

                let nanos = UInt64(max(0.02, self.stepDelay) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    func toggleRun() {
        if isRunning {
            pause()
        } else {
            run()
        }
    }

    func pause() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    private func shouldStopForBreakpoint() -> Bool {
        guard machine.isAtInstructionBoundary, !machine.isHalted else { return false }
        let pc = machine.state.pc

        if let ignored = ignoreBreakpointAddress, ignored != pc {
            ignoreBreakpointAddress = nil
        }
        if ignoreBreakpointAddress == pc {
            return false
        }

        let line = program?.line(forAddress: pc)
        let breakpointHit = line.map { breakpointLines.contains($0) } ?? false
        let runToHit = runToAddress == pc

        guard breakpointHit || runToHit else { return false }

        ignoreBreakpointAddress = pc
        lastBreakpointHit = pc
        runToAddress = nil
        let whereText = line.map { " (line \($0))" } ?? ""
        statusMessage = "Paused at 0x\(String(format: "%02X", pc))\(whereText)."
        return true
    }

    private func record(_ outcome: StepOutcome) {
        history.append(
            snapshot: machine.snapshot,
            op: outcome.op,
            instruction: outcome.instruction
        )
        lastOutcome = outcome
        scrubbing = false
        animationToken += 1

        if case .memoryWrite = outcome.op.kind,
           outcome.op.memoryAddress == MemoryMap.displayPort {
            let value = outcome.after.ram[Int(MemoryMap.displayPort)]
            outputLog.append(OutputEvent(
                id: nextOutputID,
                value: value,
                instructionText: outcome.op.instructionText
            ))
            nextOutputID += 1
            if outputLog.count > 40 {
                outputLog.removeFirst(outputLog.count - 40)
            }
        }
    }

    // MARK: Time travel

    func jumpHistory(to index: Int) {
        pause()
        history.jump(to: index)
        machine.restore(history.current.snapshot)
        rebuildOutcome()
        rebuildOutputLog()
        scrubbing = !history.isLive
        lastBreakpointHit = nil
        ignoreBreakpointAddress = nil
        animationToken += 1
    }

    func returnToLive() {
        jumpHistory(to: history.entries.count - 1)
    }

    private func rebuildOutcome() {
        let index = history.cursor
        guard index > 0,
              let op = history.entries[index].op else {
            lastOutcome = nil
            return
        }

        let before = history.entries[index - 1].snapshot.state
        let after = history.entries[index].snapshot.state
        lastOutcome = StepOutcome(
            before: before,
            after: after,
            op: op,
            instruction: history.entries[index].instruction
        )
    }

    private func rebuildOutputLog() {
        var events: [OutputEvent] = []
        var identifier = 0

        for entry in history.entries.prefix(history.cursor + 1) {
            guard let op = entry.op,
                  case .memoryWrite = op.kind,
                  op.memoryAddress == MemoryMap.displayPort else { continue }
            events.append(OutputEvent(
                id: identifier,
                value: entry.snapshot.state.ram[Int(MemoryMap.displayPort)],
                instructionText: op.instructionText
            ))
            identifier += 1
        }

        if events.count > 40 {
            events = Array(events.suffix(40))
        }
        outputLog = events
        nextOutputID = events.count
    }

    // MARK: Breakpoints

    func toggleBreakpoint(line: Int) {
        guard program?.address(forLine: line) != nil else { return }
        if breakpointLines.contains(line) {
            breakpointLines.remove(line)
        } else {
            breakpointLines.insert(line)
        }
    }

    func runToCursor() {
        guard let address = program?.address(forLine: cursorLine) else {
            statusMessage = "That line has no instruction."
            return
        }
        runToAddress = address
        run()
    }

    func clearBreakpoints() {
        breakpointLines.removeAll()
        runToAddress = nil
    }

    // MARK: Input

    func setInput(_ value: UInt8) {
        inputByte = value
        machine.setMemory(value, at: MemoryMap.inputPort)
        history.replaceCurrent(snapshot: machine.snapshot)
    }

    // MARK: Samples

    func loadSample(_ sample: SampleProgram) {
        pause()
        selectedSampleID = sample.id
        source = sample.source
        needsReload = false
        statusMessage = nil
        breakpointLines.removeAll()
        runToAddress = nil
        showSamples = false

        let result = Assembler.assemble(source)
        program = result
        diagnostics = result.diagnostics
        if result.hasErrors {
            statusMessage = result.diagnostics.first?.message
            showDiagnostics = true
            return
        }
        showDiagnostics = false
        loadMachine(memory: result.memory)
        saveAutosave()
    }

    func loadSample(id: String) {
        guard let sample = SampleCatalog.sample(id: id) else { return }
        loadSample(sample)
    }

    // MARK: Files

    func newProgram() {
        guard let blank = SampleCatalog.sample(id: "blank") else { return }
        loadSample(blank)
    }

    func openDocument() {
        pause()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "asm") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            source = text
            selectedSampleID = ""
            needsReload = false
            let result = Assembler.assemble(text)
            program = result
            diagnostics = result.diagnostics
            if result.hasErrors {
                needsReload = true
                showDiagnostics = true
                statusMessage = "Opened with \(result.diagnostics.filter { $0.severity == .error }.count) error(s)."
            } else {
                showDiagnostics = false
                loadMachine(memory: result.memory)
                statusMessage = "Opened \(url.lastPathComponent)."
            }
            saveAutosave()
        } catch {
            statusMessage = "Could not open file: \(error.localizedDescription)"
        }
    }

    func saveDocument() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "asm") ?? .plainText]
        panel.nameFieldStringValue = "program.asm"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try source.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Saved \(url.lastPathComponent)."
        } catch {
            statusMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    func exportHex() {
        guard let program else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "hex") ?? .plainText]
        panel.nameFieldStringValue = "program.hex"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var lines: [String] = [
            "; NOVA-8 memory image",
            "; 256 bytes · 16 per row",
            ""
        ]
        for row in 0..<16 {
            let base = row * 16
            let bytes = (0..<16).map { String(format: "%02X", program.memory[base + $0]) }
            lines.append(String(format: "%02X: ", base) + bytes.joined(separator: " "))
        }

        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Exported \(url.lastPathComponent)."
        } catch {
            statusMessage = "Could not export: \(error.localizedDescription)"
        }
    }

    // MARK: Autosave

    private static var supportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nova8", isDirectory: true)
    }

    private static var autosaveURL: URL {
        supportDirectory.appendingPathComponent("last.asm")
    }

    private static func readAutosave() -> String? {
        try? String(contentsOf: autosaveURL, encoding: .utf8)
    }

    private func saveAutosave() {
        guard autosaveEnabled else { return }
        let directory = Self.supportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? source.write(to: Self.autosaveURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Previews

#if DEBUG
extension SimulatorModel {
    /// Builds a model for SwiftUI previews: no autosave is read or written, the
    /// requested sample is loaded, and the machine is stepped a fixed number of
    /// times so the canvas is deterministic.
    static func preview(
        sampleID: String = "countdown",
        steps: Int = 0,
        statusMessage: String? = nil
    ) -> SimulatorModel {
        let model = SimulatorModel(autosaveEnabled: false)
        model.loadSample(id: sampleID)
        for _ in 0..<steps { model.step() }
        model.statusMessage = statusMessage
        return model
    }
}
#endif
