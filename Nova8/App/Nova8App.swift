import SwiftUI

@main
struct Nova8App: App {
    @State private var model = SimulatorModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 1240, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1500, height: 960)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Program") { model.newProgram() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { model.openDocument() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Save As…") { model.saveDocument() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Export Hex Image…") { model.exportHex() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandMenu("Machine") {
                Button(model.isRunning ? "Pause" : "Run") { model.toggleRun() }
                    .keyboardShortcut(.return, modifiers: [.command])
                Button("Step One Micro-operation") { model.step() }
                    .keyboardShortcut("]", modifiers: .command)
                Button("Step Back") { model.stepBack() }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Assemble & Reload") { model.assembleAndLoad() }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Run to Cursor") { model.runToCursor() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Divider()
                Button("Reset Machine") { model.reset() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
