import AppKit

final class CodeTextView: NSTextView {

    static let gutterWidth: CGFloat = 56

    var currentLine: Int? {
        didSet {
            if oldValue != currentLine {
                needsDisplay = true
            }
        }
    }

    var lineAddresses: [Int: UInt8] = [:] {
        didSet { needsDisplay = true }
    }

    var breakpoints: Set<Int> = [] {
        didSet { needsDisplay = true }
    }

    var highlightColor: NSColor = .novaCyan
    var onToggleBreakpoint: ((Int) -> Void)?
    var onFocusLine: ((Int) -> Void)?

    private let numberFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
    private let currentFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
    private let addressFont = NSFont.monospacedSystemFont(ofSize: 7.5, weight: .regular)

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let layoutManager else { return }

        drawGutter(in: rect, layout: layoutManager)

        guard (string as NSString).length > 0,
              let line = currentLine, line > 0 else { return }
        let ns = string as NSString
        let start = characterIndex(forLine: line)
        let clamped = min(max(0, start), ns.length - 1)
        guard clamped >= 0 else { return }

        let glyph = layoutManager.glyphIndexForCharacter(at: clamped)
        var fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        fragment.origin.y += textContainerInset.height
        fragment.origin.x = Self.gutterWidth
        fragment.size.width = max(0, bounds.width - Self.gutterWidth)

        highlightColor.withAlphaComponent(0.06).setFill()
        fragment.fill()

        highlightColor.withAlphaComponent(0.65).setFill()
        NSRect(x: Self.gutterWidth, y: fragment.minY + 1, width: 2, height: max(0, fragment.height - 2)).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Gutter fills and the attributed text use dynamic colors, so a
        // light/dark switch just needs a redraw to pick up the new appearance.
        needsDisplay = true
    }

    private func drawGutter(in rect: NSRect, layout: NSLayoutManager) {
        let ns = string as NSString
        let starts = lineStarts()

        NSColor.novaGutter.setFill()
        NSRect(x: 0, y: rect.minY, width: Self.gutterWidth, height: rect.height).fill()

        NSColor.novaGutterEdge.setFill()
        NSRect(x: Self.gutterWidth - 1, y: rect.minY, width: 1, height: rect.height).fill()

        guard ns.length > 0 else { return }

        for (index, start) in starts.enumerated() {
            let line = index + 1
            let glyph = layout.glyphIndexForCharacter(at: min(start, ns.length - 1))
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let y = fragment.minY + textContainerInset.height
            let height = fragment.height

            if y + height < rect.minY - 24 || y > rect.maxY + 24 { continue }

            drawGutterLine(
                number: line,
                y: y,
                height: height,
                address: lineAddresses[line],
                isCurrent: line == currentLine,
                hasBreakpoint: breakpoints.contains(line)
            )
        }
    }

    private func drawGutterLine(
        number: Int,
        y: CGFloat,
        height: CGFloat,
        address: UInt8?,
        isCurrent: Bool,
        hasBreakpoint: Bool
    ) {
        if isCurrent {
            NSColor.novaCyan.withAlphaComponent(0.07).setFill()
            NSRect(x: 0, y: y, width: Self.gutterWidth, height: height).fill()

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

    // MARK: - Lines

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

    private func lineNumber(at point: NSPoint) -> Int? {
        guard let layoutManager, (string as NSString).length > 0 else { return nil }
        let ns = string as NSString
        let starts = lineStarts()
        let inset = textContainerInset.height

        for (index, start) in starts.enumerated() {
            let glyph = layoutManager.glyphIndexForCharacter(at: min(start, ns.length - 1))
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let y = fragment.minY + inset
            if point.y >= y && point.y < y + max(fragment.height, 12) {
                return index + 1
            }
        }
        return nil
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

    // MARK: - Mouse

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(
            NSRect(x: 0, y: 0, width: Self.gutterWidth, height: bounds.height),
            cursor: .crosshair
        )
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard point.x < Self.gutterWidth else {
            super.mouseDown(with: event)
            return
        }

        guard let line = lineNumber(at: point) else { return }
        if point.x < 18 {
            onToggleBreakpoint?(line)
        } else {
            onFocusLine?(line)
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
