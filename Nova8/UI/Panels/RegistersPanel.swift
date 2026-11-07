import SwiftUI

struct RegistersPanel: View {
    @Environment(SimulatorModel.self) private var model

    private let registers: [Hardware] = [.a, .b, .c, .d, .sp, .pc, .ir, .mar, .mdr, .t]

    var body: some View {
        Panel(
            title: "Registers",
            meta: String(format: "SP 0x%02X · %d/48 stack", model.state.sp, model.stackDepth)
        ) {
            VStack(spacing: 6) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5),
                    spacing: 4
                ) {
                    ForEach(registers, id: \.self) { hardware in
                        tile(hardware)
                    }
                }

                HStack(spacing: 6) {
                    Text("FLAGS")
                        .font(.mono(7.5, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.faint)

                    Lamp(label: "Z", on: model.state.flags.zero, color: Theme.amber)
                    Lamp(label: "C", on: model.state.flags.carry, color: Theme.amber)
                    Lamp(label: "N", on: model.state.flags.negative, color: Theme.amber)

                    Spacer(minLength: 4)

                    Text("μ\(model.state.microOpCount) · i\(model.state.instructionCount)")
                        .font(.mono(7.5))
                        .foregroundStyle(Theme.faint)
                }
            }
            .padding(8)
        }
    }

    private func tile(_ hardware: Hardware) -> some View {
        let value = model.state.read(hardware)
        let outcome = model.lastOutcome
        let touched = outcome?.op.touchedHardware.contains(hardware) ?? false
        let isDestination = outcome?.op.destinationHardware == hardware
        let color: Color? = touched
            ? (isDestination ? Theme.stage(outcome?.op.stage) : Theme.dim)
            : nil

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(hardware.displayName)
                    .font(.mono(7.5, .semibold))
                    .foregroundStyle(color ?? Theme.faint)
                Spacer(minLength: 0)
                if hardware == .pc {
                    Circle()
                        .fill(Theme.cyan)
                        .frame(width: 3, height: 3)
                }
            }

            Text(String(format: "0x%02X", value))
                .font(.mono(11.5, .semibold))
                .foregroundStyle(color == nil ? Theme.text.opacity(0.9) : Theme.text)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            BitBars(value: value, color: color ?? Theme.ghost, height: 3)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(height: 42)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.map { $0.opacity(0.085) } ?? Theme.inset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(color.map { $0.opacity(0.45) } ?? Theme.stroke, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.18), value: value)
    }
}

#if DEBUG
#Preview("Registers") {
    RegistersPanel()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 380)
        .background(Theme.background)
}
#endif
