import SwiftUI

// MARK: - Card shell

struct DatapathCard<Content: View>: View {
    let title: String
    var meta: String?
    var accent: Color
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    init(
        title: String,
        meta: String? = nil,
        accent: Color = Theme.faint,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.meta = meta
        self.accent = accent
        self.width = width
        self.height = height
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.panelTop.opacity(0.92), Theme.panelBottom.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.mono(7.5, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(accent)
                if let meta {
                    Text(meta)
                        .font(.mono(6.3))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }
            }
            .offset(x: 12, y: 9)

            content
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Register bank

struct DatapathRegisterTile: View {
    let hardware: Hardware
    let value: UInt8
    let isTouched: Bool
    let isDestination: Bool
    let stage: MicroStage?
    var stackDepth: Int = 0

    private var accent: Color {
        isDestination ? Theme.stage(stage) : (isTouched ? Theme.dim : Theme.ghost)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(hardware.displayName)
                    .font(.mono(7.5, .semibold))
                    .foregroundStyle(isTouched ? accent : Theme.faint)
                Spacer(minLength: 0)
                if hardware == .pc {
                    Circle()
                        .fill(Theme.cyan)
                        .frame(width: 3, height: 3)
                        .shadow(color: Theme.cyan, radius: 3)
                }
            }

            Text(String(format: "0x%02X", value))
                .font(.mono(14, .semibold))
                .foregroundStyle(isTouched ? Theme.text : Theme.text.opacity(0.86))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(value)")
                .font(.mono(6.5))
                .foregroundStyle(Theme.faint)

            Spacer(minLength: 0)

            BitBars(value: value, color: isTouched ? accent : Theme.ghost, height: 3.5)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isTouched ? accent.opacity(0.08) : Theme.inset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isTouched ? accent.opacity(0.45) : Theme.stroke, lineWidth: 1)
        )
        .shadow(color: isDestination ? accent.opacity(0.2) : .clear, radius: 8)
    }
}

struct RegisterBankCard: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        DatapathCard(
            title: "Register file",
            meta: "A–D · SP · PC · T · IR",
            accent: Theme.dim,
            width: DatapathGeometry.regPanel.width,
            height: DatapathGeometry.regPanel.height
        ) {
            ForEach(Array(DatapathGeometry.registers.enumerated()), id: \.element) { index, hardware in
                let outcome = model.lastOutcome
                let touched = outcome?.op.touchedHardware.contains(hardware) ?? false
                let destination = outcome?.op.destinationHardware == hardware

                DatapathRegisterTile(
                    hardware: hardware,
                    value: model.state.read(hardware),
                    isTouched: touched,
                    isDestination: destination,
                    stage: outcome?.op.stage,
                    stackDepth: model.stackDepth
                )
                .frame(width: DatapathGeometry.tileWidth, height: DatapathGeometry.tileHeight)
                .offset(
                    x: 12 + CGFloat(index) * DatapathGeometry.tileStep,
                    y: 32
                )
            }
        }
    }
}

// MARK: - Control

struct ControlCard: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        let ir = model.state.ir
        let bits = Fmt.bits(ir, width: 8)
        let activeStage = model.currentStage

        DatapathCard(
            title: "Control",
            meta: "cycle \(model.state.microOpCount)",
            accent: Theme.violet,
            width: DatapathGeometry.controlPanel.width,
            height: DatapathGeometry.controlPanel.height
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Text("IR")
                        .font(.mono(6.5, .semibold))
                        .foregroundStyle(Theme.faint)
                    Text(String(format: "0x%02X", ir))
                        .font(.mono(11, .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(bits)
                        .font(.mono(6.8))
                        .foregroundStyle(Theme.faint)
                }

                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { index in
                        let bit = (ir >> (7 - index)) & 1
                        let color = index < 5 ? Theme.violet : Theme.amber
                        Text("\(bit)")
                            .font(.mono(7, .semibold))
                            .foregroundStyle(color.opacity(bit == 1 ? 1 : 0.35))
                            .frame(width: 14, height: 15)
                            .background(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(color.opacity(bit == 1 ? 0.18 : 0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(color.opacity(0.16), lineWidth: 0.7)
                            )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 5)

                HStack(spacing: 3) {
                    Text("OPCODE")
                        .frame(width: 78, alignment: .leading)
                    Text("REG")
                        .frame(width: 48, alignment: .leading)
                    Spacer()
                }
                .font(.mono(5.8, .medium))
                .foregroundStyle(Theme.faint)
                .padding(.top, 2)

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)
                    .padding(.vertical, 5)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(MicroStage.allCases, id: \.self) { stage in
                        let active = activeStage == stage
                        HStack(spacing: 5) {
                            Circle()
                                .fill(active ? Theme.stage(stage) : Theme.ghost)
                                .frame(width: 4, height: 4)
                                .shadow(color: active ? Theme.stage(stage).opacity(0.8) : .clear, radius: 3)
                            Text(stage.title)
                                .font(.mono(7, .medium))
                                .foregroundStyle(active ? Theme.text : Theme.faint)
                            Spacer()
                            if active {
                                Text(model.currentOp?.slot ?? "")
                                    .font(.mono(6.5, .semibold))
                                    .foregroundStyle(Theme.stage(stage))
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(width: 176)
            .offset(x: 12, y: 31)
        }
    }
}

// MARK: - ALU

struct ALUCard: View {
    @Environment(SimulatorModel.self) private var model

    private var aluResult: (operation: ALUOperation, lhs: UInt8, rhs: UInt8, result: UInt8, destination: Hardware?, sourceName: String)? {
        guard let outcome = model.lastOutcome,
              case .alu(let operation, let source, let destination, _) = outcome.op.kind else {
            return nil
        }

        let before = outcome.before
        let lhs: UInt8
        let rhs: UInt8

        switch operation {
        case .inc, .dec, .not:
            lhs = destination.map { before.read($0) } ?? before.a
            rhs = 1
        case .shl, .shr:
            lhs = before.a
            rhs = 0
        default:
            lhs = before.a
            rhs = source.map { before.read($0) } ?? 0
        }

        return (
            operation,
            lhs,
            rhs,
            operation == .cmp
                ? ALU.evaluate(.sub, before.a, rhs, carryIn: before.flags.carry).value
                : outcome.after.read(destination ?? .a),
            destination,
            source?.displayName ?? (destination?.displayName ?? "A")
        )
    }

    var body: some View {
        let stage = model.currentStage
        let color = Theme.stage(stage)

        DatapathCard(
            title: "ALU",
            meta: "arithmetic · logic unit",
            accent: Theme.green,
            width: DatapathGeometry.aluPanel.width,
            height: DatapathGeometry.aluPanel.height
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.inset)
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            aluResult == nil ? Theme.stroke : color.opacity(0.35),
                            lineWidth: 1
                        )

                    if let result = aluResult {
                        VStack(spacing: 5) {
                            HStack(spacing: 8) {
                                if result.operation == .inc || result.operation == .dec || result.operation == .not {
                                    operandChip(result.sourceName, value: result.lhs, color: Theme.amber)
                                    Text(result.operation.symbol)
                                        .font(.mono(19, .semibold))
                                        .foregroundStyle(color)
                                } else {
                                    operandChip("A", value: result.lhs, color: Theme.cyan)
                                    Text(result.operation.symbol)
                                        .font(.mono(19, .semibold))
                                        .foregroundStyle(color)
                                    if result.operation != .shl && result.operation != .shr {
                                        operandChip(result.sourceName, value: result.rhs, color: Theme.amber)
                                    }
                                }
                            }
                            HStack(spacing: 6) {
                                Text("=")
                                    .font(.mono(9))
                                    .foregroundStyle(Theme.faint)
                                Text(String(format: "0x%02X", result.result))
                                    .font(.mono(17, .semibold))
                                    .foregroundStyle(color)
                                    .contentTransition(.numericText())
                                if result.operation == .cmp {
                                    Text("flags")
                                        .font(.mono(7))
                                        .foregroundStyle(Theme.faint)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 3) {
                            Text("idle")
                                .font(.mono(15, .semibold))
                                .foregroundStyle(Theme.ghost)
                            Text("A is the accumulator")
                                .font(.ui(7.5))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                }
                .frame(width: 236, height: 94)
                .shadow(color: aluResult == nil ? .clear : color.opacity(0.18), radius: 12)

                HStack(spacing: 5) {
                    Text("FLAGS")
                        .font(.mono(6.5, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.faint)
                    Lamp(label: "Z", on: model.state.flags.zero, color: Theme.amber)
                    Lamp(label: "C", on: model.state.flags.carry, color: Theme.amber)
                    Lamp(label: "N", on: model.state.flags.negative, color: Theme.amber)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                Text(aluResult.map { $0.destination == nil ? "Comparison only — A is unchanged." : "Result is written back to \($0.destination?.displayName ?? "A")." } ?? "All arithmetic and logic results land in A.")
                    .font(.ui(7.5))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 6)
                    .lineLimit(2)

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 2) {
                    flagRule("Z", "the result is zero")
                    flagRule("C", "carry out, or a borrow")
                    flagRule("N", "bit 7 of the result")
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .frame(width: 236)
            .offset(x: 12, y: 34)
        }
    }

    private func flagRule(_ name: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(name)
                .font(.mono(6.5, .semibold))
                .foregroundStyle(Theme.amber)
                .frame(width: 8)
            Text(text)
                .font(.ui(7.2))
                .foregroundStyle(Theme.faint)
        }
    }

    private func operandChip(_ name: String, value: UInt8, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.mono(6.5, .semibold))
                .foregroundStyle(color.opacity(0.8))
            Text(String(format: "%02X", value))
                .font(.mono(11, .semibold))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 0.8)
        )
    }
}

// MARK: - Signals

struct SignalsCard: View {
    @Environment(SimulatorModel.self) private var model

    private var activeIndex: Int? {
        guard let last = model.lastOutcome?.op else { return nil }
        return model.machine.currentOps.firstIndex {
            $0.slot == last.slot && $0.instructionSerial == last.instructionSerial
        }
    }

    var body: some View {
        let op = model.currentOp
        let stage = op?.stage

        DatapathCard(
            title: "Control signals",
            meta: op.map { "\($0.slot) · \($0.stage.title)" } ?? "idle",
            accent: Theme.violet,
            width: DatapathGeometry.signalsPanel.width,
            height: DatapathGeometry.signalsPanel.height
        ) {
            VStack(alignment: .leading, spacing: 7) {
                if let op, !op.signals.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4)
                        ],
                        spacing: 4
                    ) {
                        ForEach(op.signals, id: \.self) { signal in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Theme.violet)
                                    .frame(width: 3, height: 3)
                                    .shadow(color: Theme.violet, radius: 3)
                                Text(signal.rawValue)
                                    .font(.mono(6.7, .medium))
                                    .foregroundStyle(Theme.text.opacity(0.82))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Theme.violet.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Theme.violet.opacity(0.12), lineWidth: 0.7)
                            )
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No control lines")
                            .font(.mono(9, .semibold))
                            .foregroundStyle(Theme.ghost)
                        Text("asserted this cycle")
                            .font(.ui(8))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.vertical, 4)
                }

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                if !model.machine.currentOps.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("SEQUENCE")
                                .font(.mono(5.8, .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.faint)
                            Spacer()
                            Text("\(model.machine.currentOps.count) cycles")
                                .font(.mono(5.8))
                                .foregroundStyle(Theme.ghost)
                        }

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 6),
                            spacing: 2
                        ) {
                            ForEach(Array(model.machine.currentOps.enumerated()), id: \.offset) { index, op in
                                let active = activeIndex == index
                                let done = activeIndex.map { index < $0 } ?? false
                                Text(op.slot)
                                    .font(.mono(5.8, .semibold))
                                    .foregroundStyle(active ? Theme.background : (done ? Theme.dim : Theme.faint))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 13)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(active ? Theme.stage(op.stage) : Theme.inset)
                                    )
                            }
                        }
                    }
                }

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(op?.title ?? "Clock idle")
                        .font(.mono(7.5, .semibold))
                        .foregroundStyle(op == nil ? Theme.faint : Theme.stage(stage))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(op?.detail ?? "Step the machine to assert control lines.")
                        .font(.ui(7))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Text("CLOCK")
                        .font(.mono(6, .semibold))
                        .foregroundStyle(Theme.ghost)
                    Text("\(model.state.microOpCount)")
                        .font(.mono(8, .semibold))
                        .foregroundStyle(Theme.dim)
                    Spacer()
                    if let op {
                        Text(op.slot)
                            .font(.mono(7, .bold))
                            .foregroundStyle(Theme.stage(op.stage))
                    }
                }
            }
            .frame(width: 180)
            .offset(x: 12, y: 32)
        }
    }
}

// MARK: - Memory

struct MemoryRegisterTile: View {
    let name: String
    let value: UInt8
    let isTouched: Bool
    let isDestination: Bool
    let stage: MicroStage?

    private var accent: Color {
        isDestination ? Theme.stage(stage) : (isTouched ? Theme.dim : Theme.ghost)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                Text(name)
                    .font(.mono(6.5, .semibold))
                    .foregroundStyle(isTouched ? accent : Theme.faint)
                Spacer(minLength: 0)
            }
            Text(String(format: "0x%02X", value))
                .font(.mono(11, .semibold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .lineLimit(1)
            BitBars(value: value, color: isTouched ? accent : Theme.ghost, height: 3)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(width: 80, height: 46, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isTouched ? accent.opacity(0.08) : Theme.inset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isTouched ? accent.opacity(0.45) : Theme.stroke, lineWidth: 1)
        )
    }
}

struct MiniRAMView: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        Canvas { context, size in
            let columns = 16
            let rows = 16
            let cellWidth = size.width / CGFloat(columns)
            let cellHeight = size.height / CGFloat(rows)
            let inset: CGFloat = 0.7

            for row in 0..<rows {
                for column in 0..<columns {
                    let address = row * columns + column
                    let byte = model.state.ram[address]
                    let region = Theme.region(MemoryMap.region(for: UInt8(address)))
                    let isPC = Int(model.state.pc) == address
                    let isMAR = Int(model.state.mar) == address
                    let active = model.lastOutcome?.op.memoryAddress == UInt8(address)
                    let activeColor = Theme.stage(model.lastOutcome?.op.stage)

                    let rect = CGRect(
                        x: CGFloat(column) * cellWidth + inset,
                        y: CGFloat(row) * cellHeight + inset,
                        width: cellWidth - inset * 2,
                        height: cellHeight - inset * 2
                    )
                    let path = Path(roundedRect: rect, cornerRadius: 1.2)

                    let fill: Color
                    if active {
                        fill = activeColor.opacity(0.55)
                    } else if isPC {
                        fill = Theme.cyan.opacity(0.42)
                    } else if byte != 0 {
                        fill = region.opacity(0.32)
                    } else {
                        fill = region.opacity(0.09)
                    }
                    context.fill(path, with: .color(fill))

                    if isPC || isMAR || active {
                        let stroke = active ? activeColor.opacity(0.9) : (isPC ? Theme.cyan.opacity(0.8) : Theme.amber.opacity(0.6))
                        context.stroke(path, with: .color(stroke), lineWidth: 0.8)
                    }
                }
            }

            // Region separators
            for boundary in [8, 12, 15] {
                let y = CGFloat(boundary) * cellHeight
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 0.8)
            }
        }
    }
}

struct MemoryInternalWires: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        let touched = model.lastOutcome?.op.touchedHardware ?? []

        Canvas { context, _ in
            let marActive = touched.contains(.mar)
            var mar = Path()
            mar.move(to: CGPoint(x: 82, y: 0))
            mar.addLine(to: CGPoint(x: 82, y: 46))
            context.stroke(
                mar,
                with: .color(marActive ? Theme.amber.opacity(0.85) : Theme.amber.opacity(0.16)),
                lineWidth: marActive ? 1.8 : 1
            )

            let mdrActive = touched.contains(.mdr)
            var mdr = Path()
            mdr.move(to: CGPoint(x: 4, y: 0))
            mdr.addLine(to: CGPoint(x: 4, y: 211))
            mdr.addLine(to: CGPoint(x: 12, y: 211))
            context.stroke(
                mdr,
                with: .color(mdrActive ? Theme.cyan.opacity(0.85) : Theme.cyan.opacity(0.16)),
                lineWidth: mdrActive ? 1.8 : 1
            )
        }
        .frame(width: DatapathGeometry.memoryPanel.width, height: DatapathGeometry.memoryPanel.height)
        .allowsHitTesting(false)
    }
}

struct MemoryCard: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        let outcome = model.lastOutcome
        let touched = outcome?.op.touchedHardware ?? []
        let stage = outcome?.op.stage

        DatapathCard(
            title: "Memory",
            meta: "256 × 8 · uniform",
            accent: Theme.amber,
            width: DatapathGeometry.memoryPanel.width,
            height: DatapathGeometry.memoryPanel.height
        ) {
            ZStack(alignment: .topLeading) {
                MemoryInternalWires()

                MemoryRegisterTile(
                    name: "MAR",
                    value: model.state.mar,
                    isTouched: touched.contains(.mar),
                    isDestination: outcome?.op.destinationHardware == .mar,
                    stage: stage
                )
                .offset(x: 12, y: 46)

                MemoryRegisterTile(
                    name: "MDR",
                    value: model.state.mdr,
                    isTouched: touched.contains(.mdr),
                    isDestination: outcome?.op.destinationHardware == .mdr,
                    stage: stage
                )
                .offset(x: 12, y: 188)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("RAM")
                            .font(.mono(6.5, .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.faint)
                        Spacer()
                        Text("0x00–0xFF")
                            .font(.mono(6))
                            .foregroundStyle(Theme.ghost)
                    }
                    .frame(width: 204)

                    MiniRAMView()
                        .frame(width: 204, height: 210)
                }
                .offset(x: 120, y: 16)

                MemoryArrows()
                    .frame(width: 338, height: 260)
            }
        }
    }
}

struct MemoryArrows: View {
    var body: some View {
        Canvas { context, size in
            let marY: CGFloat = 69
            let mdrY: CGFloat = 211
            let startX: CGFloat = 92
            let endX: CGFloat = 120

            var address = Path()
            address.move(to: CGPoint(x: startX, y: marY))
            address.addLine(to: CGPoint(x: endX, y: marY))
            context.stroke(address, with: .color(Theme.amber.opacity(0.55)), lineWidth: 1.2)
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: endX, y: marY))
                    path.addLine(to: CGPoint(x: endX - 5, y: marY - 3))
                    path.addLine(to: CGPoint(x: endX - 5, y: marY + 3))
                    path.closeSubpath()
                },
                with: .color(Theme.amber.opacity(0.7))
            )

            var data = Path()
            data.move(to: CGPoint(x: endX, y: mdrY))
            data.addLine(to: CGPoint(x: startX, y: mdrY))
            context.stroke(data, with: .color(Theme.cyan.opacity(0.55)), lineWidth: 1.2)
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: startX, y: mdrY))
                    path.addLine(to: CGPoint(x: startX + 5, y: mdrY - 3))
                    path.addLine(to: CGPoint(x: startX + 5, y: mdrY + 3))
                    path.closeSubpath()
                },
                with: .color(Theme.cyan.opacity(0.7))
            )
        }
    }
}

#if DEBUG
#Preview("Register Bank Card") {
    RegisterBankCard()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .background(Theme.background)
}

#Preview("Control Card") {
    ControlCard()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .background(Theme.background)
}

#Preview("ALU Card") {
    ALUCard()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .background(Theme.background)
}

#Preview("Signals Card") {
    SignalsCard()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .background(Theme.background)
}

#Preview("Memory Card") {
    MemoryCard()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .background(Theme.background)
}
#endif
