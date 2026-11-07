import SwiftUI

enum Theme {

    // Surfaces
    static let background = Color(hex: 0x06090E)
    static let backgroundTop = Color(hex: 0x0A0F16)
    static let panelTop = Color(hex: 0x111823)
    static let panelBottom = Color(hex: 0x0B1119)
    static let panel = Color(hex: 0x0E141C)
    static let inset = Color(hex: 0x080C12)
    static let raised = Color(hex: 0x151E2A)

    // Lines
    static let stroke = Color.white.opacity(0.065)
    static let strokeStrong = Color.white.opacity(0.13)
    static let grid = Color.white.opacity(0.017)

    // Text
    static let text = Color(hex: 0xE9F0F8)
    static let dim = Color(hex: 0x8392A6)
    static let faint = Color(hex: 0x4F5D6E)
    static let ghost = Color(hex: 0x35414F)

    // Accents
    static let cyan = Color(hex: 0x5BD8E8)
    static let blue = Color(hex: 0x6FA8FF)
    static let amber = Color(hex: 0xF4B860)
    static let violet = Color(hex: 0xB69CFF)
    static let green = Color(hex: 0x72E3A6)
    static let rose = Color(hex: 0xFF90A4)
    static let red = Color(hex: 0xFF6B6B)

    // Memory regions
    static let program = Color(hex: 0x5BD8E8)
    static let data = Color(hex: 0x72E3A6)
    static let stack = Color(hex: 0xF4B860)
    static let io = Color(hex: 0xB69CFF)

    static func region(_ region: MemoryMap.Region) -> Color {
        switch region {
        case .program: return program
        case .data: return data
        case .stack: return stack
        case .io: return io
        case .reserved: return faint
        }
    }

    static func stage(_ stage: MicroStage?) -> Color {
        switch stage {
        case .fetch: return cyan
        case .decode: return violet
        case .operand: return amber
        case .execute: return green
        case nil: return dim
        }
    }

    static func accent(_ accent: SampleAccent) -> Color {
        switch accent {
        case .cyan: return cyan
        case .amber: return amber
        case .violet: return violet
        case .green: return green
        case .rose: return rose
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    static let novaText = NSColor(hex: 0xE9F0F8)
    static let novaDim = NSColor(hex: 0x8392A6)
    static let novaFaint = NSColor(hex: 0x4F5D6E)
    static let novaCyan = NSColor(hex: 0x5BD8E8)
    static let novaAmber = NSColor(hex: 0xF4B860)
    static let novaViolet = NSColor(hex: 0xB69CFF)
    static let novaGreen = NSColor(hex: 0x72E3A6)
    static let novaRose = NSColor(hex: 0xFF90A4)
    static let novaRed = NSColor(hex: 0xFF6B6B)
    static let novaBg = NSColor(hex: 0x080D13)
    static let novaSelection = NSColor(hex: 0x1A3444)
}

extension Font {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Background

struct GridBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.backgroundTop, Theme.background, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                var path = Path()
                let step: CGFloat = 32
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(Theme.grid), lineWidth: 1)
            }

            RadialGradient(
                colors: [Theme.cyan.opacity(0.055), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 760
            )
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Panel

struct Panel<Content: View>: View {
    let title: String
    var meta: String?
    var accessory: AnyView?
    var fillHeight: Bool
    @ViewBuilder var content: Content

    init(
        title: String,
        meta: String? = nil,
        accessory: AnyView? = nil,
        fillHeight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.meta = meta
        self.accessory = accessory
        self.fillHeight = fillHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.mono(9.5, .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.dim)

                if let meta {
                    Text(meta)
                        .font(.mono(9))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let accessory {
                    accessory
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 9)

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)

            content
        }
        .frame(
            maxWidth: fillHeight ? .infinity : nil,
            maxHeight: fillHeight ? .infinity : nil,
            alignment: .topLeading
        )
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
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.028), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: - Small pieces

struct BitBars: View {
    let value: UInt8
    var color: Color
    var height: CGFloat = 4

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { bit in
                let on = (value >> (7 - bit)) & 1 == 1
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(on ? color : Color.white.opacity(0.09))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .shadow(color: on ? color.opacity(0.45) : .clear, radius: 3)
            }
        }
    }
}

struct Lamp: View {
    let label: String
    let on: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(on ? color : Color.white.opacity(0.1))
                .frame(width: 5, height: 5)
                .shadow(color: on ? color.opacity(0.8) : .clear, radius: 4)
            Text("\(label)\(on ? "1" : "0")")
                .font(.mono(8.5, .semibold))
                .foregroundStyle(on ? color : Theme.faint)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(on ? color.opacity(0.1) : Color.white.opacity(0.03))
        )
    }
}

struct TinyChip: View {
    let text: String
    var color: Color = Theme.dim
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.mono(8.5, .semibold))
            .foregroundStyle(filled ? Theme.background : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(filled ? color : color.opacity(0.09))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(filled ? 0 : 0.2), lineWidth: 1)
            )
    }
}

struct IconButton: View {
    let systemName: String
    var size: CGFloat = 30
    var tint: Color = Theme.dim
    var prominent: Bool = false
    var background: Color = Theme.raised
    var disabled: Bool = false
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: prominent ? 13 : 11.5, weight: .semibold))
                .foregroundStyle(disabled ? Theme.ghost : (prominent ? Theme.background : tint))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: prominent ? 10 : 8, style: .continuous)
                        .fill(prominent ? tint : background)
                        .overlay(
                            RoundedRectangle(cornerRadius: prominent ? 10 : 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(hovering && !prominent ? 0.1 : 0), lineWidth: 1)
                        )
                )
                .shadow(color: prominent && !disabled ? tint.opacity(0.3) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct SegmentedPill<Value: Hashable & Identifiable, Label: View>: View {
    let values: [Value]
    @Binding var selection: Value
    @ViewBuilder let label: (Value) -> Label

    var body: some View {
        HStack(spacing: 2) {
            ForEach(values) { value in
                Button {
                    selection = value
                } label: {
                    label(value)
                        .font(.mono(9.5, .semibold))
                        .foregroundStyle(selection == value ? Theme.text : Theme.faint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == value ? Theme.raised : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.inset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview("Panel") {
    Panel(title: "Registers", meta: "SP 0x00 · 0/48 stack") {
        Text("Panel content")
            .font(.ui(11))
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
    .preferredColorScheme(.dark)
    .padding()
    .frame(width: 380)
    .background(Theme.background)
}

#Preview("Bits & Lamps") {
    VStack(alignment: .leading, spacing: 12) {
        BitBars(value: 0b1011_0100, color: Theme.cyan)
        BitBars(value: 0b0000_1111, color: Theme.amber)

        HStack(spacing: 8) {
            Lamp(label: "Z", on: true, color: Theme.amber)
            Lamp(label: "C", on: false, color: Theme.amber)
            Lamp(label: "N", on: true, color: Theme.amber)
        }

        HStack(spacing: 8) {
            TinyChip(text: "READY", color: Theme.cyan)
            TinyChip(text: "HALTED", color: Theme.amber)
            TinyChip(text: "3 ERRORS", color: Theme.red, filled: true)
        }

        HStack(spacing: 8) {
            IconButton(systemName: "play.fill", prominent: true, help: "Run") {}
            IconButton(systemName: "forward.end.fill", help: "Step") {}
            IconButton(systemName: "arrow.counterclockwise", disabled: true, help: "Reset") {}
        }

        SegmentedPill(values: StepMode.allCases, selection: .constant(.micro)) { mode in
            Text(mode.rawValue)
        }
    }
    .preferredColorScheme(.dark)
    .padding()
    .frame(width: 380)
    .background(Theme.background)
}

#Preview("Grid Background") {
    GridBackground()
        .preferredColorScheme(.dark)
        .frame(width: 500, height: 300)
}
#endif
