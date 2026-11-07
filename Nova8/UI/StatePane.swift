import SwiftUI

struct StatePane: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                RegistersPanel()
                InstructionPanel()
                MemoryPanel()
                StackPanel()
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
    }
}

#if DEBUG
#Preview("State Pane") {
    StatePane()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 12))
        .preferredColorScheme(.dark)
        .frame(width: 380, height: 700)
        .background(Theme.background)
}
#endif
