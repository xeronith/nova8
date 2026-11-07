import SwiftUI

struct ProgramPane: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        Panel(
            title: "Program",
            meta: "0x00–0x7F",
            accessory: AnyView(headerActions),
            fillHeight: true
        ) {
            VStack(spacing: 0) {
                AssemblyEditor(
                    text: Binding(
                        get: { model.source },
                        set: { model.updateSource($0) }
                    ),
                    highlightedLine: model.currentLine,
                    breakpoints: model.breakpointLines,
                    diagnostics: model.diagnostics,
                    lineAddresses: model.program?.lineToAddress ?? [:],
                    focusLine: model.focusLine,
                    focusToken: model.focusToken,
                    autoScroll: model.isRunning,
                    onToggleBreakpoint: { line in
                        model.toggleBreakpoint(line: line)
                    },
                    onCursorLineChange: { line in
                        model.cursorLine = line
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.showDiagnostics {
                    diagnosticsView
                    Rectangle().fill(Theme.stroke).frame(height: 1)
                }

                footer
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 3) {
            IconButton(
                systemName: "square.grid.2x2",
                size: 22,
                tint: Theme.dim,
                background: .clear,
                help: "Guided demos"
            ) {
                model.showSamples = true
            }
            IconButton(
                systemName: "hammer.fill",
                size: 22,
                tint: Theme.dim,
                background: .clear,
                help: "Assemble & reload (⌘B)"
            ) {
                model.assembleAndLoad()
            }
            IconButton(
                systemName: "sidebar.left",
                size: 22,
                tint: Theme.dim,
                background: .clear,
                help: "Hide the editor"
            ) {
                model.showEditor = false
            }
        }
    }

    private var diagnosticsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("DIAGNOSTICS")
                    .font(.mono(8, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.faint)
                Text("\(model.diagnostics.count)")
                    .font(.mono(8))
                    .foregroundStyle(Theme.faint)
                Spacer()
                Button {
                    model.showDiagnostics = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.diagnostics) { diagnostic in
                        Button {
                            model.focus(line: diagnostic.line)
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: diagnostic.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(diagnostic.severity == .error ? Theme.red : Theme.amber)
                                    .padding(.top, 2)
                                Text("Ln \(diagnostic.line)")
                                    .font(.mono(8.5, .medium))
                                    .foregroundStyle(Theme.dim)
                                    .frame(width: 34, alignment: .leading)
                                Text(diagnostic.message)
                                    .font(.ui(9.5))
                                    .foregroundStyle(Theme.text.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 112)
        }
        .background(Theme.inset.opacity(0.55))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
                .shadow(color: statusColor.opacity(0.7), radius: 4)

            Text(statusText)
                .font(.ui(9.5, .medium))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("Ln \(model.cursorLine)")
                .font(.mono(8.5))
                .foregroundStyle(Theme.faint)

            Text("·")
                .font(.mono(8))
                .foregroundStyle(Theme.ghost)

            Text("\(model.program?.textBytes ?? 0) B")
                .font(.mono(8.5))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Theme.inset.opacity(0.35))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    private var statusColor: Color {
        if model.hasErrors { return Theme.red }
        if model.needsReload { return Theme.amber }
        return Theme.green
    }

    private var statusText: String {
        if model.hasErrors {
            return "\(model.errorCount) error\(model.errorCount == 1 ? "" : "s") — fix before running"
        }
        if model.needsReload {
            return "Modified — run or step to assemble"
        }
        let count = model.program?.listing.count ?? 0
        return "Assembled \(count) instruction\(count == 1 ? "" : "s")"
    }
}

#if DEBUG
#Preview("Program Pane") {
    ProgramPane()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 360, height: 640)
        .background(Theme.background)
}

#Preview("Program Pane — Diagnostics") {
    let model = SimulatorModel.preview()
    model.updateSource("""
    ; broken program
    start: FROB A
           LDI A, 999
           JMP nowhere
    """)
    model.assembleAndLoad()
    model.showDiagnostics = true
    return ProgramPane()
        .environment(model)
        .preferredColorScheme(.dark)
        .padding()
        .frame(width: 360, height: 640)
        .background(Theme.background)
}
#endif
