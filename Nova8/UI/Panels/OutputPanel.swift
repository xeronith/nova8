import SwiftUI

struct SevenSegmentDigit: View {
    let digit: Int
    var color: Color = Theme.cyan

    private static let segments: [CGRect] = [
        CGRect(x: 9, y: 4, width: 22, height: 5),
        CGRect(x: 31, y: 8, width: 5, height: 23),
        CGRect(x: 31, y: 39, width: 5, height: 23),
        CGRect(x: 9, y: 62, width: 22, height: 5),
        CGRect(x: 4, y: 39, width: 5, height: 23),
        CGRect(x: 4, y: 8, width: 5, height: 23),
        CGRect(x: 9, y: 33, width: 22, height: 5)
    ]

    private static let masks: [Set<Int>] = [
        [0, 1, 2, 3, 4, 5],
        [1, 2],
        [0, 1, 6, 4, 3],
        [0, 1, 6, 2, 3],
        [5, 6, 1, 2],
        [0, 5, 6, 2, 3],
        [0, 5, 6, 4, 3, 2],
        [0, 1, 2],
        [0, 1, 2, 3, 4, 5, 6],
        [0, 1, 5, 6, 2, 3]
    ]

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 40
            let scaleY = size.height / 70
            let active = Self.masks[max(0, min(9, digit))]

            for (index, segment) in Self.segments.enumerated() {
                let rect = CGRect(
                    x: segment.minX * scaleX,
                    y: segment.minY * scaleY,
                    width: segment.width * scaleX,
                    height: segment.height * scaleY
                )
                let path = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
                let on = active.contains(index)
                context.fill(path, with: .color(on ? color : Color.white.opacity(0.055)))
            }
        }
        .shadow(color: color.opacity(0.35), radius: 7)
    }
}

struct OutputPanel: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        Panel(title: "Output", meta: "0xF0 display · 0xF1 input") {
            VStack(spacing: 7) {
                displayRow

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                inputRow

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                console
            }
            .padding(9)
        }
    }

    private var displayRow: some View {
        let value = Int(model.displayValue)
        let digits = [value / 100, (value / 10) % 10, value % 10]

        return HStack(spacing: 9) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    SevenSegmentDigit(digit: digits[index])
                        .frame(width: 21, height: 36)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("DISPLAY")
                    .font(.mono(7, .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.faint)
                Text(String(format: "0x%02X", model.displayValue))
                    .font(.mono(13.5, .semibold))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text("\(model.displayValue) decimal")
                    .font(.ui(8.5))
                    .foregroundStyle(Theme.dim)
            }

            Spacer(minLength: 0)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 7) {
            Text("IN 0xF1")
                .font(.mono(7.5, .semibold))
                .foregroundStyle(Theme.faint)

            Slider(
                value: Binding(
                    get: { Double(model.inputValue) },
                    set: { model.setInput(UInt8($0.rounded())) }
                ),
                in: 0...255
            )
            .controlSize(.mini)
            .tint(Theme.violet)

            Text(String(format: "0x%02X", model.inputValue))
                .font(.mono(9, .medium))
                .foregroundStyle(Theme.dim)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var console: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if model.outputLog.isEmpty {
                        Text("No writes to 0xF0 yet. Output shows up here.")
                            .font(.ui(8.5))
                            .foregroundStyle(Theme.faint)
                            .padding(.vertical, 2)
                    } else {
                        ForEach(model.outputLog) { event in
                            HStack(spacing: 5) {
                                Text(String(format: "%02X", event.value))
                                    .font(.mono(8, .semibold))
                                    .foregroundStyle(Theme.cyan)
                                Text("\(event.value)")
                                    .font(.mono(8))
                                    .foregroundStyle(Theme.dim)
                                    .frame(width: 22, alignment: .trailing)
                                Text(event.instructionText)
                                    .font(.ui(8))
                                    .foregroundStyle(Theme.faint)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .id(event.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 34)
            .onChange(of: model.outputLog.count) { _, _ in
                if let last = model.outputLog.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Output") {
    OutputPanel()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 23))
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 360)
        .background(Theme.background)
}

#Preview("Seven-Segment Digits") {
    HStack(spacing: 6) {
        ForEach(0..<10, id: \.self) { digit in
            SevenSegmentDigit(digit: digit)
                .frame(width: 21, height: 36)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(Theme.background)
}
#endif
