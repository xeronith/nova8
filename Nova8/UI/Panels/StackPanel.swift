import SwiftUI

struct StackPanel: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        Panel(
            title: "Stack",
            meta: String(format: "SP 0x%02X · %d/48 used", model.state.sp, model.stackDepth)
        ) {
            VStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let address = Int(MemoryMap.stackEnd) - index
                    let value = model.state.ram[address]
                    let sp = Int(model.state.sp)
                    let filled = address > sp
                    let isTop = address == sp + 1 && model.stackDepth > 0
                    let isSP = address == sp

                    HStack(spacing: 6) {
                        Text(String(format: "%02X", address))
                            .font(.mono(7, .medium))
                            .foregroundStyle(isSP ? Theme.violet : Theme.faint)
                            .frame(width: 18, alignment: .leading)

                        Text(filled ? String(format: "0x%02X", value) : "··")
                            .font(.mono(8, .semibold))
                            .foregroundStyle(filled ? Theme.text : Theme.ghost)

                        Spacer(minLength: 0)

                        if isTop {
                            TinyChip(text: "TOS", color: Theme.amber)
                        } else if isSP {
                            TinyChip(text: "SP", color: Theme.violet)
                        }
                    }
                    .frame(height: 13)
                    .padding(.horizontal, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(filled ? Theme.amber.opacity(0.055) : Color.clear)
                    )
                    .overlay(alignment: .leading) {
                        if filled {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Theme.amber.opacity(0.4))
                                .frame(width: 2, height: 11)
                                .padding(.leading, 1)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 6.5))
                        .foregroundStyle(Theme.faint)
                    Text("PUSH writes at SP, then SP−1")
                        .font(.ui(7.5))
                        .foregroundStyle(Theme.faint)
                    Spacer()
                }
                .padding(.top, 3)
            }
            .padding(7)
        }
    }
}
