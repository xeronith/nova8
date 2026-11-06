import SwiftUI

struct MemoryPanel: View {
    @Environment(SimulatorModel.self) private var model

    private let cellWidth: CGFloat = 15.5
    private let cellHeight: CGFloat = 13
    private let gap: CGFloat = 1
    private let labelWidth: CGFloat = 20

    var body: some View {
        Panel(
            title: "Memory",
            meta: String(format: "PC %02X · MAR %02X · MDR %02X", model.state.pc, model.state.mar, model.state.mdr)
        ) {
            VStack(alignment: .leading, spacing: 7) {
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        Color.clear.frame(width: labelWidth, height: 9)
                        ForEach(0..<16, id: \.self) { column in
                            Text(String(format: "%X", column))
                                .font(.mono(6.5, .medium))
                                .foregroundStyle(Theme.ghost)
                                .frame(width: cellWidth, height: 9)
                        }
                    }

                    ForEach(0..<16, id: \.self) { row in
                        HStack(spacing: gap) {
                            Text(String(format: "%X0", row))
                                .font(.mono(6.4, .medium))
                                .foregroundStyle(Theme.faint)
                                .frame(width: labelWidth, height: cellHeight, alignment: .trailing)

                            ForEach(0..<16, id: \.self) { column in
                                cell(at: row * 16 + column)
                            }
                        }
                    }
                }

                HStack(spacing: 7) {
                    legend(Theme.program, "CODE")
                    legend(Theme.data, "DATA")
                    legend(Theme.stack, "STACK")
                    legend(Theme.io, "I/O")
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
        }
    }

    private func cell(at index: Int) -> some View {
        let address = UInt8(index)
        let value = model.state.ram[index]
        let region = MemoryMap.region(for: address)
        let color = Theme.region(region)

        let isPC = model.state.pc == address
        let isMAR = model.state.mar == address
        let isSP = model.state.sp == address
        let active = model.lastOutcome?.op.memoryAddress == address
        let activeColor = Theme.stage(model.lastOutcome?.op.stage)

        let fill: Color
        if active {
            fill = activeColor.opacity(0.24)
        } else if isPC {
            fill = Theme.cyan.opacity(0.18)
        } else {
            fill = color.opacity(value == 0 ? 0.045 : 0.1)
        }

        let border: Color
        if isPC {
            border = Theme.cyan.opacity(0.85)
        } else if isMAR {
            border = Theme.amber.opacity(0.45)
        } else if active {
            border = activeColor.opacity(0.7)
        } else {
            border = .clear
        }

        let shown: String
        if value == 0 && address != MemoryMap.displayPort && address != MemoryMap.inputPort {
            shown = "·"
        } else {
            shown = String(format: "%02X", value)
        }

        let textColor: Color
        if isPC || active {
            textColor = Theme.text
        } else if value == 0 {
            textColor = Theme.faint.opacity(0.55)
        } else {
            textColor = Theme.text.opacity(0.78)
        }

        return Text(shown)
            .font(.mono(7.4, .medium))
            .foregroundStyle(textColor)
            .frame(width: cellWidth, height: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSP {
                    Circle()
                        .fill(Theme.violet)
                        .frame(width: 3, height: 3)
                        .padding(1.5)
                        .shadow(color: Theme.violet, radius: 2)
                }
            }
            .help(String(format: "0x%02X · %@ · 0x%02X", index, region.title, value))
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 4, height: 4)
            Text(text)
                .font(.mono(6.5, .medium))
                .foregroundStyle(Theme.faint)
        }
    }
}
