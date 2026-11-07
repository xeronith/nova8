import SwiftUI

/// Every token resolves to a light or dark value based on the effective
/// appearance, so the whole UI follows the system theme automatically.
enum Theme {

    // Surfaces
    static let background = Color(nsColor: .nova(light: 0xEEF2F7, dark: 0x06090E))
    static let backgroundTop = Color(nsColor: .nova(light: 0xF7F9FC, dark: 0x0A0F16))
    static let panelTop = Color(nsColor: .nova(light: 0xFFFFFF, dark: 0x111823))
    static let panelBottom = Color(nsColor: .nova(light: 0xF4F7FB, dark: 0x0B1119))
    static let panel = Color(nsColor: .nova(light: 0xFFFFFF, dark: 0x0E141C))
    static let inset = Color(nsColor: .nova(light: 0xE9EEF4, dark: 0x080C12))
    static let raised = Color(nsColor: .nova(light: 0xFFFFFF, dark: 0x151E2A))

    // Lines
    static let stroke = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.065))
    static let strokeStrong = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.18, darkAlpha: 0.13))
    static let grid = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.035, darkAlpha: 0.017))

    // Text
    static let text = Color(nsColor: .nova(light: 0x1A2330, dark: 0xE9F0F8))
    static let dim = Color(nsColor: .nova(light: 0x566579, dark: 0x8392A6))
    static let faint = Color(nsColor: .nova(light: 0x8794A6, dark: 0x4F5D6E))
    static let ghost = Color(nsColor: .nova(light: 0xB6C1CE, dark: 0x35414F))

    // Accents
    static let cyan = Color(nsColor: .nova(light: 0x0E8CA6, dark: 0x5BD8E8))
    static let blue = Color(nsColor: .nova(light: 0x2E6FE0, dark: 0x6FA8FF))
    static let amber = Color(nsColor: .nova(light: 0xB26A00, dark: 0xF4B860))
    static let violet = Color(nsColor: .nova(light: 0x6A4FD0, dark: 0xB69CFF))
    static let green = Color(nsColor: .nova(light: 0x17915A, dark: 0x72E3A6))
    static let rose = Color(nsColor: .nova(light: 0xD1496A, dark: 0xFF90A4))
    static let red = Color(nsColor: .nova(light: 0xD63B3B, dark: 0xFF6B6B))

    // Neutral fills, highlights and wires that used to be literal white/black.
    static let sheen = Color(nsColor: .nova(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.0, darkAlpha: 0.028))
    static let track = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.09))
    static let fillSubtle = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.035, darkAlpha: 0.03))
    static let hoverStroke = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.1))
    static let busLine = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.1, darkAlpha: 0.065))
    static let busLineStrong = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.18, darkAlpha: 0.14))
    static let busNode = Color(nsColor: .nova(light: 0x0A1622, dark: 0xFFFFFF, lightAlpha: 0.22, darkAlpha: 0.18))

    // Shadows
    static let shadow = Color(nsColor: .nova(light: 0x000000, dark: 0x000000, lightAlpha: 0.10, darkAlpha: 0.28))
    static let shadowStrong = Color(nsColor: .nova(light: 0x000000, dark: 0x000000, lightAlpha: 0.16, darkAlpha: 0.40))

    // Memory regions
    static let program = Theme.cyan
    static let data = Theme.green
    static let stack = Theme.amber
    static let io = Theme.violet

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

    /// A color that resolves to `light` or `dark` depending on the appearance
    /// it is drawn in. Both SwiftUI (`Color(nsColor:)`) and AppKit pick this up.
    static func nova(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    static let novaText = NSColor.nova(light: 0x1A2330, dark: 0xE9F0F8)
    static let novaDim = NSColor.nova(light: 0x566579, dark: 0x8392A6)
    static let novaFaint = NSColor.nova(light: 0x8794A6, dark: 0x4F5D6E)
    static let novaCyan = NSColor.nova(light: 0x0E8CA6, dark: 0x5BD8E8)
    static let novaAmber = NSColor.nova(light: 0xB26A00, dark: 0xF4B860)
    static let novaViolet = NSColor.nova(light: 0x6A4FD0, dark: 0xB69CFF)
    static let novaGreen = NSColor.nova(light: 0x17915A, dark: 0x72E3A6)
    static let novaRose = NSColor.nova(light: 0xD1496A, dark: 0xFF90A4)
    static let novaRed = NSColor.nova(light: 0xD63B3B, dark: 0xFF6B6B)
    static let novaString = NSColor.nova(light: 0x1E8A4C, dark: 0x9FE8B8)
    static let novaNumber = NSColor.nova(light: 0x0E7C86, dark: 0x8FD8C2)
    static let novaGutter = NSColor.nova(light: 0xEDF1F6, dark: 0x0A0F16)
    static let novaGutterEdge = NSColor.nova(light: 0xDCE3EC, dark: 0x111926)
    static let novaBg = NSColor.nova(light: 0xEEF2F7, dark: 0x080D13)
    static let novaSelection = NSColor.nova(light: 0xBFD6F0, dark: 0x1A3444)
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
                                colors: [Theme.sheen, .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
                .shadow(color: Theme.shadow, radius: 18, y: 8)
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
                    .fill(on ? color : Theme.track)
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
                .fill(on ? color : Theme.track)
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
                .fill(on ? color.opacity(0.1) : Theme.fillSubtle)
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
                                .strokeBorder(Theme.hoverStroke.opacity(hovering && !prominent ? 1 : 0), lineWidth: 1)
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
    .padding()
    .frame(width: 380)
    .background(Theme.background)
}

#Preview("Grid Background") {
    GridBackground()
        .frame(width: 500, height: 300)
}
#endif
