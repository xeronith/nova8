import AppKit

enum AssemblyHighlighter {

    static let fontSize: CGFloat = 11.5

    private static let mnemonics: Set<String> = Set(Opcode.allCases.map { $0.mnemonic })
    private static let directives: Set<String> = [".TEXT", ".DATA", ".BYTE", "DB"]

    private static let registerRegex = try! NSRegularExpression(
        pattern: "(?<![A-Za-z0-9_])(A|B|C|D|SP)(?![A-Za-z0-9_])"
    )
    private static let numberRegex = try! NSRegularExpression(
        pattern: "\\b(0x[0-9A-Fa-f]+|0b[01]+|\\d+|\\$[0-9A-Fa-f]+)\\b"
    )
    private static let stringRegex = try! NSRegularExpression(
        pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'"
    )
    private static let labelRegex = try! NSRegularExpression(
        pattern: "^\\s*([A-Za-z_][A-Za-z0-9_]*):"
    )
    private static let constantRegex = try! NSRegularExpression(
        pattern: "^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*="
    )

    static func apply(to textView: NSTextView, diagnostics: [Diagnostic]) {
        guard let storage = textView.textStorage else { return }

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 0
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 24)]

        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.novaText,
            .paragraphStyle: paragraph
        ]

        let ns = storage.string as NSString
        let selection = textView.selectedRanges
        let scrollOrigin = textView.enclosingScrollView?.contentView.bounds.origin

        storage.beginEditing()
        storage.setAttributes(base, range: NSRange(location: 0, length: ns.length))

        var lineRanges: [Int: NSRange] = [:]
        var index = 0
        var lineNumber = 1

        while index < ns.length {
            let range = ns.lineRange(for: NSRange(location: index, length: 0))
            lineRanges[lineNumber] = range
            colorLine(ns.substring(with: range), offset: range.location, storage: storage)
            index = NSMaxRange(range)
            lineNumber += 1
        }

        if ns.length == 0 {
            lineRanges[1] = NSRange(location: 0, length: 0)
        }

        for diagnostic in diagnostics where diagnostic.severity == .error {
            guard let range = lineRanges[diagnostic.line], range.length > 0 else { continue }
            var length = range.length
            if ns.hasSuffix("\n", in: range) { length -= 1 }
            guard length > 0 else { continue }
            let target = NSRange(location: range.location, length: length)
            storage.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor.novaRed.withAlphaComponent(0.85),
                .backgroundColor: NSColor.novaRed.withAlphaComponent(0.055)
            ], range: target)
        }

        storage.endEditing()
        textView.typingAttributes = base
        textView.selectedRanges = selection

        if let scrollOrigin {
            textView.enclosingScrollView?.contentView.scroll(to: scrollOrigin)
        }
    }

    private static func colorLine(_ line: String, offset: Int, storage: NSTextStorage) {
        let ns = line as NSString
        guard ns.length > 0 else { return }

        let commentStart = findCommentStart(ns)
        let codeLength = commentStart ?? ns.length
        let code = NSRange(location: 0, length: codeLength)

        var masked: [NSRange] = []

        // Strings and character literals
        for match in stringRegex.matches(in: line, range: code) {
            let range = NSRange(location: offset + match.range.location, length: match.range.length)
            storage.addAttribute(.foregroundColor, value: NSColor(hex: 0x9FE8B8), range: range)
            masked.append(match.range)
        }

        // Comment
        if let commentStart {
            let range = NSRange(location: offset + commentStart, length: ns.length - commentStart)
            storage.addAttribute(.foregroundColor, value: NSColor.novaFaint, range: range)
            masked.append(NSRange(location: commentStart, length: ns.length - commentStart))
        }

        // Label definition
        for match in labelRegex.matches(in: line, range: code) {
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound else { continue }
            storage.addAttribute(
                .foregroundColor,
                value: NSColor.novaViolet,
                range: NSRange(location: offset + nameRange.location, length: nameRange.length)
            )
        }

        // Constant definition
        for match in constantRegex.matches(in: line, range: code) {
            if let nameRange = Range(match.range(at: 1), in: line) {
                let location = line.utf16.distance(from: line.utf16.startIndex, to: nameRange.lowerBound)
                let length = line.utf16.distance(from: nameRange.lowerBound, to: nameRange.upperBound)
                storage.addAttribute(
                    .foregroundColor,
                    value: NSColor.novaViolet,
                    range: NSRange(location: offset + location, length: length)
                )
            }
        }

        // First identifier after an optional label is the mnemonic.
        let head = headToken(in: ns, upTo: codeLength)
        if let head {
            let name = ns.substring(with: head).uppercased()
            let color: NSColor?
            if mnemonics.contains(name) || ["OUT", "IN"].contains(name) {
                color = NSColor.novaCyan
            } else if directives.contains(name) {
                color = NSColor.novaViolet
            } else {
                color = nil
            }
            if let color {
                storage.addAttribute(
                    .foregroundColor,
                    value: color,
                    range: NSRange(location: offset + head.location, length: head.length)
                )
            }
        }

        // Numbers
        for match in numberRegex.matches(in: line, range: code) {
            guard !intersects(match.range, masked) else { continue }
            storage.addAttribute(
                .foregroundColor,
                value: NSColor(hex: 0x8FD8C2),
                range: NSRange(location: offset + match.range.location, length: match.range.length)
            )
        }

        // Registers
        for match in registerRegex.matches(in: line, range: code) {
            guard !intersects(match.range, masked) else { continue }
            storage.addAttribute(
                .foregroundColor,
                value: NSColor.novaAmber,
                range: NSRange(location: offset + match.range.location, length: match.range.length)
            )
        }

        // DB directive at the head may be preceded by a label — handled above.
    }

    private static func findCommentStart(_ ns: NSString) -> Int? {
        var inString = false
        var inChar = false
        var escaped = false

        for index in 0..<ns.length {
            let character = ns.character(at: index)
            if escaped {
                escaped = false
                continue
            }
            if (inString || inChar), character == 92 {
                escaped = true
                continue
            }
            if character == 34, !inChar {
                inString.toggle()
                continue
            }
            if character == 39, !inString {
                inChar.toggle()
                continue
            }
            if character == 59, !inString, !inChar {
                return index
            }
        }
        return nil
    }

    private static func headToken(in ns: NSString, upTo limit: Int) -> NSRange? {
        var index = 0
        while index < limit, isWhitespace(ns.character(at: index)) { index += 1 }
        guard index < limit else { return nil }

        // Skip a label prefix.
        var cursor = index
        while cursor < limit, isIdentifier(ns.character(at: cursor)) { cursor += 1 }
        if cursor < limit, ns.character(at: cursor) == 58 {
            cursor += 1
            while cursor < limit, isWhitespace(ns.character(at: cursor)) { cursor += 1 }
        }

        // A constant assignment is not a mnemonic.
        var probe = cursor
        while probe < limit, isIdentifier(ns.character(at: probe)) { probe += 1 }
        var after = probe
        while after < limit, isWhitespace(ns.character(at: after)) { after += 1 }
        if after < limit, ns.character(at: after) == 61 { return nil }

        let start = cursor
        while cursor < limit, isIdentifier(ns.character(at: cursor)) || ns.character(at: cursor) == 46 {
            cursor += 1
        }
        guard cursor > start else { return nil }
        return NSRange(location: start, length: cursor - start)
    }

    private static func intersects(_ range: NSRange, _ masks: [NSRange]) -> Bool {
        masks.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        character == 32 || character == 9
    }

    private static func isIdentifier(_ character: unichar) -> Bool {
        (character >= 65 && character <= 90) ||
        (character >= 97 && character <= 122) ||
        (character >= 48 && character <= 57) ||
        character == 95
    }
}

private extension NSString {
    func hasSuffix(_ suffix: String, in range: NSRange) -> Bool {
        guard range.length >= suffix.utf16.count else { return false }
        let tail = NSRange(location: NSMaxRange(range) - suffix.utf16.count, length: suffix.utf16.count)
        return substring(with: tail) == suffix
    }
}
