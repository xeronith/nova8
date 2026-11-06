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
