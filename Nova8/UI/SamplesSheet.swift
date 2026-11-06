import SwiftUI

struct SamplesSheet: View {
    @Environment(SimulatorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var hovered: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            GridBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SampleCatalog.all) { sample in
                            card(sample)
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)

                footer
            }
        }
        .frame(width: 780, height: 590)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("GUIDED DEMOS")
                    .font(.mono(11, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.text)
                Text("Load a program, then step through its cycles. Every program is editable.")
                    .font(.ui(10.5))
                    .foregroundStyle(Theme.dim)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.raised))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    private func card(_ sample: SampleProgram) -> some View {
        let accent = Theme.accent(sample.accent)
        let selected = model.selectedSampleID == sample.id
        let isHovered = hovered == sample.id

        return Button {
            model.loadSample(sample)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    TinyChip(text: sample.badge, color: accent)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(accent)
                    }
                }

                Text(sample.title)
                    .font(.mono(14, .semibold))
                    .foregroundStyle(Theme.text)

                Text(sample.subtitle)
                    .font(.ui(10))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 7.5))
                        .foregroundStyle(Theme.faint)
                    Text(sample.notes.isEmpty ? "sandbox" : "\(sample.notes.count) guided notes")
                        .font(.ui(8.5))
                        .foregroundStyle(Theme.faint)
                    Spacer()
                    Text("Load")
                        .font(.mono(8.5, .semibold))
                        .foregroundStyle(accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
            .frame(height: 144)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.panelTop, Theme.panelBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        LinearGradient(
                            colors: [accent.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        selected ? accent.opacity(0.55) : (isHovered ? Theme.strokeStrong : Theme.stroke),
                        lineWidth: 1
                    )
            )
            .shadow(color: isHovered ? accent.opacity(0.12) : .clear, radius: 14)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? sample.id : nil }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard")
                .font(.system(size: 9))
                .foregroundStyle(Theme.faint)
            Text("⌘B assemble · ⌘] step · ⌘↩ run · click the gutter to set a breakpoint")
                .font(.ui(8.5))
                .foregroundStyle(Theme.faint)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }
}
