import SwiftUI

struct InstructionPanel: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        let instruction = model.currentInstruction
        let byte = instruction.bytes.first ?? 0
        let opcodeBits = Fmt.bits(byte >> 3, width: 5)
        let registerBits = Fmt.bits(byte & 0x07, width: 3)
        let atBoundary = model.machine.isAtInstructionBoundary && !model.machine.isHalted
        let activeStage: MicroStage? = atBoundary ? nil : model.currentStage

        Panel(
            title: "Instruction",
            meta: String(format: "0x%02X · %d byte%@", instruction.address, instruction.size, instruction.size == 1 ? "" : "s")
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(instruction.assembly)
                        .font(.mono(13.5, .semibold))
                        .foregroundStyle(instruction.isValid ? Theme.text : Theme.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    Text(statusLabel)
                        .font(.mono(7.5, .semibold))
                        .tracking(0.7)
                        .foregroundStyle(statusColor)
                }

                HStack(spacing: 3) {
                    ForEach(0..<8, id: \.self) { index in
                        let bit = (byte >> (7 - index)) & 1
                        let color = index < 5 ? Theme.violet : Theme.amber
                        Text("\(bit)")
                            .font(.mono(8, .semibold))
                            .foregroundStyle(color.opacity(bit == 1 ? 1 : 0.45))
                            .frame(width: 17, height: 16)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(color.opacity(bit == 1 ? 0.16 : 0.035))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(color.opacity(0.22), lineWidth: 0.8)
                            )
                    }

                    Spacer(minLength: 6)

                    if instruction.bytes.count > 1 {
                        Text("BYTE 2  \(String(format: "0x%02X", instruction.bytes[1]))")
                            .font(.mono(7.3, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.inset))
                            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                }

                HStack(spacing: 3) {
                    Text("OPCODE \(opcodeBits)")
                        .frame(width: 5 * 17 + 4 * 3, alignment: .leading)
                    Text("REG \(registerBits)")
                        .frame(width: 3 * 17 + 2 * 3, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .font(.mono(7.2, .medium))
                .foregroundStyle(Theme.faint)

                HStack(spacing: 4) {
                    ForEach(MicroStage.allCases, id: \.self) { stage in
                        let active = activeStage == stage
                        Text(stage.letter)
                            .font(.mono(8, .bold))
                            .foregroundStyle(active ? Theme.background : Theme.faint)
                            .frame(width: 17, height: 15)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(active ? Theme.stage(stage) : Theme.inset)
                            )
                    }

                    Text(instruction.opcode.mnemonic.lowercased())
                        .font(.mono(7.5))
                        .foregroundStyle(Theme.faint)
                        .padding(.leading, 2)

                    Spacer(minLength: 0)

                    if let register = instruction.register, instruction.opcode.hasRegisterField {
                        Text("reg \(register.name)")
                            .font(.mono(7.2))
                            .foregroundStyle(Theme.faint)
                    }
                }
            }
            .padding(9)
        }
    }

    private var statusLabel: String {
        if model.needsReload { return "MODIFIED" }
        if model.machine.isHalted { return "HALTED" }
        if model.machine.isAtInstructionBoundary { return "NEXT" }
        return "EXECUTING"
    }

    private var statusColor: Color {
        if model.needsReload { return Theme.amber }
        if model.machine.isHalted { return Theme.amber }
        if model.machine.isAtInstructionBoundary { return Theme.dim }
        return Theme.green
    }
}

#if DEBUG
#Preview("Instruction") {
    InstructionPanel()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 380)
        .background(Theme.background)
}
#endif
