import SwiftUI

struct NarrationBar: View {
    @Environment(SimulatorModel.self) private var model

    /// Reserves room for the optional tip row (and a two-line detail at the
    /// narrowest window) so the datapath above never resizes between cycles.
    static let minHeight: CGFloat = 90

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            stageBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(model.currentOp?.slot ?? "—")
                        .font(.mono(8.5, .bold))
                        .foregroundStyle(stageColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(stageColor.opacity(0.12))
                        )

                    Text(model.currentOp?.title ?? "Ready")
                        .font(.mono(12, .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 6)

                    if let next = model.nextOp {
                        Text("NEXT  \(next.slot) · \(next.title)")
                            .font(.mono(7.5, .medium))
                            .foregroundStyle(Theme.faint)
                            .lineLimit(1)
                    }
                }

                Text(detail)
                    .font(.ui(10))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = model.currentNote {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 7.5))
                            .foregroundStyle(Theme.amber)
                            .padding(.top, 2)
                        Text(note.text)
                            .font(.ui(9.5))
                            .foregroundStyle(Theme.amber.opacity(0.9))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.panelTop, Theme.panelBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
                .shadow(color: Theme.shadow, radius: 14, y: 6)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(stageColor.opacity(0.7))
                .frame(width: 2)
                .padding(.vertical, 12)
                .padding(.leading, 1)
        }
    }

    private var stageBadge: some View {
        VStack(spacing: 0) {
            Text(model.currentStage?.letter ?? "·")
                .font(.mono(17, .bold))
                .foregroundStyle(stageColor)
            Text(model.currentStage?.title.uppercased() ?? "IDLE")
                .font(.mono(5.8, .semibold))
                .tracking(0.6)
                .foregroundStyle(stageColor.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 46, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(stageColor.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(stageColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var stageColor: Color {
        Theme.stage(model.currentStage)
    }

    private var detail: String {
        if let op = model.currentOp {
            return op.detail
        }
        if model.hasErrors {
            return "Fix the assembly errors in the program pane, then press Assemble or Run."
        }
        return "Press Step to advance one micro-operation, or Run to watch the clock. Every transfer across the bus is a real cycle."
    }
}

#if DEBUG
#Preview("Narration") {
    NarrationBar()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 820)
        .background(Theme.background)
}
#endif
