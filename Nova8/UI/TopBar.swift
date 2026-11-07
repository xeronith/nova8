import SwiftUI

struct TopBar: View {
    @Environment(SimulatorModel.self) private var model

    /// Fixed lanes either side of the transport cluster. Reserving a constant
    /// width keeps the controls from sliding when the program name gets longer
    /// or the counters gain digits; both lanes add the same headroom, so the
    /// cluster stays on exactly the same x for the default program.
    private let leadingLane: CGFloat = 358
    private let trailingLane: CGFloat = 175

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 14) {
            HStack(spacing: 14) {
                brand

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(width: 1, height: 22)

                programMenu

                IconButton(
                    systemName: "sidebar.left",
                    size: 26,
                    tint: model.showEditor ? Theme.cyan.opacity(0.8) : Theme.faint,
                    background: .clear,
                    help: model.showEditor ? "Hide the program pane" : "Show the program pane"
                ) {
                    model.showEditor.toggle()
                }
            }
            .frame(width: leadingLane, alignment: .leading)

            Spacer(minLength: 10)

            transport

            speedControl

            SegmentedPill(values: StepMode.allCases, selection: $model.stepMode) { mode in
                Text(mode.rawValue)
            }

            Spacer(minLength: 10)

            counters
                .frame(width: trailingLane, alignment: .trailing)

            stateBadge
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(
            ZStack {
                Rectangle().fill(Theme.backgroundTop.opacity(0.92))
                Rectangle().fill(.ultraThinMaterial).opacity(0.35)
            }
            // Carry the bar's surface up behind the titlebar strip so the
            // traffic lights sit on it instead of on the grid background.
            .ignoresSafeArea(edges: .top)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    // MARK: Brand

    private var brand: some View {
        HStack(spacing: 9) {
            Image("BrandMark")
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .shadow(color: Theme.cyan.opacity(0.18), radius: 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("NOVA-8")
                    .font(.mono(12.5, .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.text)
                Text("visual 8-bit computer")
                    .font(.ui(8.5, .medium))
                    .foregroundStyle(Theme.faint)
            }
        }
    }

    // MARK: Program menu

    private var displayTitle: String {
        if let sample = model.currentSample {
            return sample.source == model.source ? sample.title : "\(sample.title) — edited"
        }
        return model.needsReload ? "Untitled — modified" : "Untitled"
    }

    private var programMenu: some View {
        Menu {
            ForEach(SampleCatalog.all) { sample in
                Button {
                    model.loadSample(sample)
                } label: {
                    Text("\(model.selectedSampleID == sample.id ? "✓ " : "")\(sample.title)")
                }
            }
            Divider()
            Button("Guided Demos…") { model.showSamples = true }
            Divider()
            Button("New Program") { model.newProgram() }
            Button("Open…") { model.openDocument() }
            Button("Save As…") { model.saveDocument() }
            Button("Export Hex Image…") { model.exportHex() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                Text(displayTitle)
                    .font(.ui(11, .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if model.needsReload {
                    Circle().fill(Theme.amber).frame(width: 4.5, height: 4.5)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.035))
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(displayTitle)
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 6) {
            IconButton(
                systemName: "backward.end.fill",
                tint: Theme.dim,
                disabled: !model.history.canRewind || model.isRunning,
                help: "Step back one micro-operation (⌘[)"
            ) {
                model.stepBack()
            }

            IconButton(
                systemName: "forward.end.fill",
                tint: Theme.text,
                background: Theme.raised,
                disabled: !model.canStep,
                help: "Step \(model.stepMode.title) (⌘])"
            ) {
                model.step()
            }

            IconButton(
                systemName: model.isRunning ? "pause.fill" : "play.fill",
                size: 36,
                tint: model.isRunning ? Theme.amber : Theme.cyan,
                prominent: true,
                disabled: model.isRunning ? false : !model.canRun,
                help: model.isRunning ? "Pause (⌘↩)" : "Run (⌘↩)"
            ) {
                model.toggleRun()
            }

            IconButton(
                systemName: "arrow.counterclockwise",
                tint: Theme.dim,
                help: "Reset the machine (⌘R)"
            ) {
                model.reset()
            }
        }
    }

    private var speedControl: some View {
        @Bindable var model = model
        return HStack(spacing: 6) {
            Image(systemName: "speedometer")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.faint)
            Slider(value: $model.speed, in: 0.25...4.0)
                .controlSize(.mini)
                .tint(Theme.cyan)
                .frame(width: 68)
            Text(String(format: "%.1f×", model.speed))
                .font(.mono(9, .medium))
                .foregroundStyle(Theme.dim)
                .frame(width: 28, alignment: .leading)
        }
        .help("Playback speed")
    }

    // MARK: Counters

    private var counters: some View {
        HStack(spacing: 12) {
            counter("PC", String(format: "0x%02X", model.state.pc))
            counter("μOPS", "\(model.state.microOpCount)")
            counter("INSTR", "\(model.state.instructionCount)")
        }
    }

    private func counter(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.mono(7.5, .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.faint)
            Text(value)
                .font(.mono(10.5, .medium))
                .foregroundStyle(Theme.dim)
                .monospacedDigit()
        }
    }

    private var stateBadge: some View {
        Group {
            if model.hasErrors {
                Button {
                    model.showDiagnostics = true
                } label: {
                    TinyChip(text: "\(model.errorCount) ERROR\(model.errorCount == 1 ? "" : "S")", color: Theme.red, filled: true)
                }
                .buttonStyle(.plain)
            } else if model.isRunning {
                TinyChip(text: "RUNNING", color: Theme.green, filled: true)
            } else if model.machine.isHalted {
                TinyChip(text: "HALTED", color: Theme.amber)
            } else {
                TinyChip(text: "READY", color: Theme.cyan)
            }
        }
        .frame(width: 70, alignment: .trailing)
    }
}

#if DEBUG
#Preview("Top Bar") {
    TopBar()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .frame(width: 1500)
        .background(Theme.background)
}
#endif
