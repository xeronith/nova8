import AppKit
import SwiftUI

struct AssemblyEditor: NSViewRepresentable {
    @Binding var text: String
    var highlightedLine: Int?
    var breakpoints: Set<Int>
    var diagnostics: [Diagnostic]
    var lineAddresses: [Int: UInt8]
    var focusLine: Int
    var focusToken: Int
    var autoScroll: Bool
    var onToggleBreakpoint: (Int) -> Void
    var onCursorLineChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .novaGutter
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true

        let textView = CodeTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .novaText
        textView.insertionPointColor = .novaCyan
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.novaSelection,
            .foregroundColor: NSColor.novaText
        ]
        textView.font = NSFont.monospacedSystemFont(ofSize: AssemblyHighlighter.fontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: CodeTextView.gutterWidth + 10, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        context.coordinator.textView = textView
        textView.onToggleBreakpoint = { [weak coordinator = context.coordinator] line in
            coordinator?.parent.onToggleBreakpoint(line)
        }
        textView.onFocusLine = { [weak coordinator = context.coordinator] line in
            coordinator?.focusFromGutter(line)
        }

        textView.currentLine = highlightedLine
        textView.breakpoints = breakpoints
        textView.lineAddresses = lineAddresses

        AssemblyHighlighter.apply(to: textView, diagnostics: diagnostics)
        context.coordinator.lastDiagnosticKey = diagnosticKey(diagnostics)
        context.coordinator.lastText = textView.string
        context.coordinator.lastBreakpoints = breakpoints
        context.coordinator.lastAddresses = lineAddresses
        context.coordinator.lastHighlightedLine = highlightedLine

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if textView.string != text {
            context.coordinator.isProgrammatic = true
            textView.string = text
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            context.coordinator.isProgrammatic = false
            context.coordinator.lastText = text
            AssemblyHighlighter.apply(to: textView, diagnostics: diagnostics)
            context.coordinator.lastDiagnosticKey = diagnosticKey(diagnostics)
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        } else {
            let key = diagnosticKey(diagnostics)
            if key != context.coordinator.lastDiagnosticKey {
                context.coordinator.lastDiagnosticKey = key
                AssemblyHighlighter.apply(to: textView, diagnostics: diagnostics)
            }
        }

        if context.coordinator.lastHighlightedLine != highlightedLine {
            context.coordinator.lastHighlightedLine = highlightedLine
            textView.currentLine = highlightedLine
            if autoScroll, let line = highlightedLine {
                let start = textView.characterIndex(forLine: line)
                textView.scrollRangeToVisible(NSRange(location: start, length: 0))
            }
        }

        if context.coordinator.lastBreakpoints != breakpoints {
            context.coordinator.lastBreakpoints = breakpoints
            textView.breakpoints = breakpoints
        }

        if context.coordinator.lastAddresses != lineAddresses {
            context.coordinator.lastAddresses = lineAddresses
            textView.lineAddresses = lineAddresses
        }

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            context.coordinator.focusFromGutter(focusLine)
        }
    }

    private func diagnosticKey(_ diagnostics: [Diagnostic]) -> String {
        diagnostics
            .filter { $0.severity == .error }
            .map { "\($0.line):\($0.message)" }
            .joined(separator: "|")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AssemblyEditor
        weak var textView: CodeTextView?
        var isProgrammatic = false
        var lastFocusToken = 0
        var lastText = ""
        var lastDiagnosticKey = ""
        var lastBreakpoints: Set<Int> = []
        var lastAddresses: [Int: UInt8] = [:]
        var lastHighlightedLine: Int?
        var lastReportedLine = 0

        init(_ parent: AssemblyEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammatic, let textView else { return }
            parent.text = textView.string
            lastText = textView.string
            AssemblyHighlighter.apply(to: textView, diagnostics: parent.diagnostics)
            reportCursorLine()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            reportCursorLine()
        }

        func reportCursorLine() {
            guard let textView else { return }
            let line = textView.lineNumber(forCharacter: textView.selectedRange().location)
            if line != lastReportedLine {
                lastReportedLine = line
                parent.onCursorLineChange(line)
            }
        }

        func focusFromGutter(_ line: Int) {
            guard let textView else { return }
            textView.focus(line: line)
            parent.onCursorLineChange(line)
            lastReportedLine = line
        }
    }
}

#if DEBUG
#Preview("Assembly Editor") {
    @Previewable @State var text = """
    ; NOVA-8
    .text
    start: LDI A, 0x2A
           OUT A
           HLT
    """
    AssemblyEditor(
        text: $text,
        highlightedLine: 3,
        breakpoints: [4],
        diagnostics: [],
        lineAddresses: [2: 0x00, 3: 0x02, 4: 0x04],
        focusLine: 1,
        focusToken: 0,
        autoScroll: false,
        onToggleBreakpoint: { _ in },
        onCursorLineChange: { _ in }
    )
    .preferredColorScheme(.dark)
    .padding()
    .frame(width: 360, height: 480)
    .background(Theme.background)
}
#endif
