import SwiftUI

struct DatapathPanel: View {
    var body: some View {
        Panel(
            title: "Datapath",
            meta: "8-bit · single internal bus",
            accessory: AnyView(legend)
        ) {
            DatapathView()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }

    private var legend: some View {
        HStack(spacing: 9) {
            dot(Theme.cyan, "data")
            dot(Theme.amber, "address")
            dot(Theme.violet, "control")
        }
    }

    private func dot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 3, height: 3)
            Text(text)
                .font(.mono(6.5, .medium))
                .foregroundStyle(Theme.faint)
        }
    }
}

struct DatapathView: View {
    @Environment(SimulatorModel.self) private var model

    @State private var progress: CGFloat = 0
    @State private var packetVisible = false
    @State private var packetRoute: Route?
    @State private var packetValue = ""
    @State private var packetColor = Theme.cyan
    @State private var generation = 0

    var body: some View {
        GeometryReader { geo in
            let scale = min(
                geo.size.width / DatapathGeometry.size.width,
                geo.size.height / DatapathGeometry.size.height,
                1.06
            )

            ZStack {
                diagram
                    .frame(width: DatapathGeometry.size.width, height: DatapathGeometry.size.height)
                    .scaleEffect(scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: model.animationToken) { _, _ in
            animatePacket()
        }
    }

    private var diagram: some View {
        ZStack(alignment: .topLeading) {
            WiresLayer(
                route: activeRoute,
                touched: model.lastOutcome?.op.touchedHardware ?? [],
                stage: model.lastOutcome?.op.stage,
                isALU: model.lastOutcome?.op.touchedHardware.contains(.alu) ?? false
            )

            RegisterBankCard()
                .position(x: DatapathGeometry.regPanel.midX, y: DatapathGeometry.regPanel.midY)

            ControlCard()
                .position(x: DatapathGeometry.controlPanel.midX, y: DatapathGeometry.controlPanel.midY)

            ALUCard()
                .position(x: DatapathGeometry.aluPanel.midX, y: DatapathGeometry.aluPanel.midY)

            SignalsCard()
                .position(x: DatapathGeometry.signalsPanel.midX, y: DatapathGeometry.signalsPanel.midY)

            MemoryCard()
                .position(x: DatapathGeometry.memoryPanel.midX, y: DatapathGeometry.memoryPanel.midY)

            decodeLink
            busLabel
            busPill
            packetLayer
        }
        .frame(width: DatapathGeometry.size.width, height: DatapathGeometry.size.height)
    }

    // MARK: Overlays

    private var decodeLink: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: 652, y: 96))
            path.addLine(to: CGPoint(x: 684, y: 96))
            context.stroke(
                path,
                with: .color(Theme.violet.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
        .allowsHitTesting(false)

        // A tiny label sits above the link.
        .overlay(alignment: .topLeading) {
            Text("decode")
                .font(.mono(5.5, .medium))
                .foregroundStyle(Theme.violet.opacity(0.55))
                .offset(x: 656, y: 84)
        }
    }

    private var busLabel: some View {
        HStack(spacing: 5) {
            Text("INTERNAL BUS")
                .font(.mono(6.5, .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.faint)
            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 34, height: 1)
        }
        .offset(x: 30, y: 197)
    }

    private var busPill: some View {
        let color = model.lastOutcome.map { Theme.stage($0.op.stage) } ?? Theme.faint
        let value = busText

        return HStack(spacing: 4) {
            Text("BUS")
                .font(.mono(5.5, .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.faint)
            Text(value)
                .font(.mono(7.5, .semibold))
                .foregroundStyle(value == "idle" ? Theme.ghost : color)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Theme.panelBottom)
                .overlay(Capsule().strokeBorder(value == "idle" ? Theme.stroke : color.opacity(0.3), lineWidth: 1))
        )
        .position(x: 400, y: DatapathGeometry.busY)
    }

    @ViewBuilder
    private var packetLayer: some View {
        if packetVisible, let route = packetRoute {
            let point = route.point(at: progress)

            Circle()
                .fill(packetColor.opacity(0.35))
                .frame(width: 22, height: 22)
                .blur(radius: 7)
                .position(point)

            Text(packetValue)
                .font(.mono(7.5, .bold))
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(packetColor)
                        .overlay(Capsule().strokeBorder(Theme.strokeStrong, lineWidth: 0.7))
                )
                .shadow(color: packetColor.opacity(0.65), radius: 8)
                .position(point)
        }
    }

    // MARK: Derived

    private var activeRoute: Route? {
        guard let op = model.lastOutcome?.op else { return nil }
        return DatapathRoutes.route(for: op)
    }

    private var busText: String {
        guard let outcome = model.lastOutcome,
              DatapathRoutes.route(for: outcome.op) != nil else {
            return "idle"
        }
        return DatapathRoutes.packetValue(for: outcome)
    }

    private func animatePacket() {
        guard !model.scrubbing,
              let outcome = model.lastOutcome,
              let route = DatapathRoutes.route(for: outcome.op) else {
            generation += 1
            packetVisible = false
            return
        }

        generation += 1
        let token = generation
        packetRoute = route
        packetValue = DatapathRoutes.packetValue(for: outcome)
        packetColor = Theme.stage(outcome.op.stage)
        progress = 0
        packetVisible = true

        let duration = max(0.12, model.animationDuration)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 18_000_000)
            guard token == generation else { return }
            withAnimation(.easeInOut(duration: duration)) {
                progress = 1
            }
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.12) * 1_000_000_000))
            guard token == generation else { return }
            packetVisible = false
        }
    }
}

// MARK: - Wires

struct WiresLayer: View {
    let route: Route?
    let touched: Set<Hardware>
    let stage: MicroStage?
    let isALU: Bool

    var body: some View {
        Canvas { context, size in
            let busY = DatapathGeometry.busY
            let activeColor = Theme.stage(stage)

            var bus = Path()
            bus.move(to: CGPoint(x: DatapathGeometry.busStartX, y: busY))
            bus.addLine(to: CGPoint(x: DatapathGeometry.busEndX, y: busY))

            context.stroke(bus, with: .color(Theme.cyan.opacity(0.055)), lineWidth: 12)
            context.stroke(bus, with: .color(Theme.busLine), lineWidth: 2.4)
            context.stroke(bus, with: .color(Theme.busLineStrong), lineWidth: 0.7)

            // Register taps
            for hardware in DatapathGeometry.registers {
                guard let rect = DatapathGeometry.tileRect(hardware) else { continue }
                let x = rect.midX
                let active = touched.contains(hardware)

                var tap = Path()
                tap.move(to: CGPoint(x: x, y: rect.maxY))
                tap.addLine(to: CGPoint(x: x, y: busY))
                context.stroke(
                    tap,
                    with: .color(active ? activeColor.opacity(0.7) : Theme.busLine),
                    lineWidth: active ? 1.8 : 1
                )

                let dotRect = CGRect(x: x - 2, y: busY - 2, width: 4, height: 4)
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(active ? activeColor : Theme.busNode)
                )
            }

            // ALU tap
            var alu = Path()
            alu.move(to: CGPoint(x: DatapathGeometry.aluTapX, y: busY))
            alu.addLine(to: CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.aluPanel.minY))
            context.stroke(
                alu,
                with: .color(isALU ? Theme.green.opacity(0.8) : Theme.busLine),
                lineWidth: isALU ? 2 : 1
            )

            // Memory taps: MAR (address) and MDR (data). The lines continue
            // inside the memory card, where MemoryInternalWires picks them up.
            let marActive = touched.contains(.mar)
            var mar = Path()
            mar.move(to: CGPoint(x: DatapathGeometry.marTapX, y: busY))
            mar.addLine(to: CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.memoryPanel.minY))
            context.stroke(
                mar,
                with: .color(marActive ? Theme.amber.opacity(0.8) : Theme.amber.opacity(0.16)),
                lineWidth: marActive ? 1.8 : 1
            )

            let mdrActive = touched.contains(.mdr)
            var mdr = Path()
            mdr.move(to: CGPoint(x: DatapathGeometry.mdrTapX, y: busY))
            mdr.addLine(to: CGPoint(x: DatapathGeometry.mdrTapX, y: DatapathGeometry.memoryPanel.minY))
            context.stroke(
                mdr,
                with: .color(mdrActive ? Theme.cyan.opacity(0.8) : Theme.cyan.opacity(0.16)),
                lineWidth: mdrActive ? 1.8 : 1
            )

            let mdrDot = CGRect(
                x: DatapathGeometry.mdrTapX - 2,
                y: busY - 2,
                width: 4,
                height: 4
            )
            context.fill(
                Path(ellipseIn: mdrDot),
                with: .color(mdrActive ? Theme.cyan : Theme.busNode)
            )

            // The route currently being traversed
            if let route {
                context.stroke(
                    route.path,
                    with: .color(activeColor.opacity(0.16)),
                    lineWidth: 9
                )
                context.stroke(
                    route.path,
                    with: .color(activeColor.opacity(0.72)),
                    lineWidth: 2
                )
            }
        }
        .frame(width: DatapathGeometry.size.width, height: DatapathGeometry.size.height)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Datapath Panel") {
    DatapathPanel()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 900, height: 520)
        .background(Theme.background)
}

#Preview("Datapath") {
    DatapathView()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .frame(width: DatapathGeometry.size.width, height: DatapathGeometry.size.height)
        .padding()
        .background(Theme.background)
}
#endif
