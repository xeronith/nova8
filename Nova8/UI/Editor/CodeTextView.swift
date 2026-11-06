import AppKit

final class CodeTextView: NSTextView {

    var highlightedLine: Int? {
        didSet {
            if oldValue != highlightedLine {
                needsDisplay = true
            }
        }
    }

    var highlightColor: NSColor = .novaCyan

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let line = highlightedLine,
              line > 0,
              let layoutManager,
              (string as NSString).length > 0 else { return }

        let ns = string as NSString
        let start = characterIndex(forLine: line)
        let clamped = min(max(0, start), ns.length - 1)
        guard clamped >= 0 else { return }

        let glyph = layoutManager.glyphIndexForCharacter(at: clamped)
        var fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        fragment.origin.y += textContainerInset.height
        fragment.origin.x = 0
        fragment.size.width = bounds.width

        highlightColor.withAlphaComponent(0.06).setFill()
        fragment.fill()

        highlightColor.withAlphaComponent(0.65).setFill()
        NSRect(x: 0, y: fragment.minY + 1, width: 2, height: max(0, fragment.height - 2)).fill()
    }

    func characterIndex(forLine line: Int) -> Int {
        let ns = string as NSString
        var index = 0
        var current = 1
        while current < line && index < ns.length {
            index = NSMaxRange(ns.lineRange(for: NSRange(location: index, length: 0)))
            current += 1
        }
        return min(index, ns.length)
    }

    func lineNumber(forCharacter characterIndex: Int) -> Int {
        let ns = string as NSString
        let clamped = min(max(0, characterIndex), ns.length)
        guard clamped > 0 else { return 1 }
        var count = 1
        for index in 0..<clamped where ns.character(at: index) == 10 {
            count += 1
        }
        return count
    }

    func lineStarts() -> [Int] {
        let ns = string as NSString
        var starts = [0]
        guard ns.length > 0 else { return starts }
        for index in 0..<ns.length where ns.character(at: index) == 10 {
            starts.append(index + 1)
        }
        return starts
    }

    func focus(line: Int) {
        let ns = string as NSString
        let start = min(characterIndex(forLine: line), ns.length)
        let range = ns.lineRange(for: NSRange(location: start, length: 0))
        let location = range.location
        var length = 0
        if range.length > 0 {
            length = range.length
            if ns.hasSuffix("\n", in: range) { length -= 1 }
        }
        setSelectedRange(NSRange(location: location, length: length))
        scrollRangeToVisible(NSRange(location: location, length: length))
        window?.makeFirstResponder(self)
    }
}

// MARK: - Ruler

final class LineNumberRulerView: NSRulerView {

    weak var codeView: CodeTextView?

    var lineAddresses: [Int: UInt8] = [:] {
        didSet { needsDisplay = true }
    }

    var breakpoints: Set<Int> = [] {
        didSet { needsDisplay = true }
    }

    var currentLine: Int? {
        didSet { needsDisplay = true }
    }

    var onToggleBreakpoint: ((Int) -> Void)?
    var onFocusLine: ((Int) -> Void)?

    private let numberFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
    private let currentFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
    private let addressFont = NSFont.monospacedSystemFont(ofSize: 7.5, weight: .regular)

    override var isFlipped: Bool { true }

    init(codeView: CodeTextView, scrollView: NSScrollView) {
        self.codeView = codeView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = codeView
        self.ruleThickness = 56
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(NSRect(x: 0, y: 0, width: 18, height: bounds.height), cursor: .crosshair)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor(hex: 0x0A0F16).setFill()
        bounds.fill()

        NSColor(hex: 0x111926).setFill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()

        guard let codeView else { return }

        let ns = codeView.string as NSString
        let starts = codeView.lineStarts()
        let inset = codeView.textContainerInset.height
        let layout = codeView.layoutManager

        for (index, start) in starts.enumerated() {
            let line = index + 1
            var y = inset
            var height: CGFloat = 16

            if let layout, ns.length > 0 {
                let glyph = layout.glyphIndexForCharacter(at: min(start, ns.length - 1))
                let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let converted = convert(
                    NSRect(x: 0, y: fragment.minY + inset, width: 1, height: fragment.height),
                    from: codeView
                )
                y = converted.minY
                height = fragment.height
            } else {
                y = convert(NSPoint(x: 0, y: inset), from: codeView).y
            }

            if y < -24 || y > bounds.height + 24 { continue }

            drawLine(
                number: line,
                y: y,
                height: height,
                address: lineAddresses[line],
                isCurrent: line == currentLine,
                hasBreakpoint: breakpoints.contains(line)
            )
        }
    }

    private func drawLine(
        number: Int,
        y: CGFloat,
        height: CGFloat,
        address: UInt8?,
        isCurrent: Bool,
        hasBreakpoint: Bool
    ) {
        if isCurrent {
            NSColor.novaCyan.withAlphaComponent(0.07).setFill()
            NSRect(x: 0, y: y, width: bounds.width, height: height).fill()

            NSColor.novaCyan.withAlphaComponent(0.85).setFill()
            NSRect(x: 0, y: y + 1, width: 2, height: max(0, height - 2)).fill()
        }

        if hasBreakpoint {
            let center = NSPoint(x: 9, y: y + height / 2)
            NSColor.novaAmber.withAlphaComponent(0.2).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)).fill()

            NSColor.novaAmber.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)).fill()
        }

        let numberParagraph = NSMutableParagraphStyle()
        numberParagraph.alignment = .right
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: isCurrent ? currentFont : numberFont,
            .foregroundColor: isCurrent ? NSColor.novaText : NSColor.novaFaint,
            .paragraphStyle: numberParagraph
        ]
        ("\(number)" as NSString).draw(
            in: NSRect(x: 14, y: y + 1, width: 19, height: height),
            withAttributes: numberAttributes
        )

        if let address {
            let addressParagraph = NSMutableParagraphStyle()
            addressParagraph.alignment = .right
            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: addressFont,
                .foregroundColor: isCurrent ? NSColor.novaCyan : NSColor.novaCyan.withAlphaComponent(0.5),
                .paragraphStyle: addressParagraph
            ]
            (String(format: "%02X", address) as NSString).draw(
                in: NSRect(x: 35, y: y + 3, width: 18, height: height),
                withAttributes: addressAttributes
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let codeView else { return }
        let point = convert(event.locationInWindow, from: nil)
        let ns = codeView.string as NSString
        let starts = codeView.lineStarts()
        let inset = codeView.textContainerInset.height
        let layout = codeView.layoutManager

        for (index, start) in starts.enumerated() {
            let line = index + 1
            var y = inset
            var height: CGFloat = 16

            if let layout, ns.length > 0 {
                let glyph = layout.glyphIndexForCharacter(at: min(start, ns.length - 1))
                let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                y = convert(NSPoint(x: 0, y: fragment.minY + inset), from: codeView).y
                height = fragment.height
            } else {
                y = convert(NSPoint(x: 0, y: inset), from: codeView).y
            }

            let hitRect = NSRect(x: 0, y: y, width: bounds.width, height: max(height, 12))
            if hitRect.contains(point) {
                if point.x < 18 {
                    onToggleBreakpoint?(line)
                } else {
                    onFocusLine?(line)
                }
                return
            }
        }
    }
}

private extension NSString {
    func hasSuffix(_ suffix: String, in range: NSRange) -> Bool {
        guard range.length >= suffix.utf16.count else { return false }
        let tail = NSRange(location: NSMaxRange(range) - suffix.utf16.count, length: suffix.utf16.count)
        return substring(with: tail) == suffix
    }
}
