import SwiftUI

struct ContentView: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        ZStack(alignment: .top) {
            GridBackground()

            VStack(spacing: 0) {
                TopBar()

                HStack(alignment: .top, spacing: 10) {
                    if model.showEditor {
                        GeometryReader { geo in
                            VStack(spacing: 10) {
                                ProgramPane()
                                    .frame(height: max(260, geo.size.height - 206))

                                OutputPanel()
                                    .frame(height: 196)
                            }
                        }
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    VStack(spacing: 10) {
                        DatapathPanel()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        NarrationBar()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    StatePane()
                        .frame(width: 360)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: model.showEditor)

                TimelineBar()
                    .frame(height: 106)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }

            StatusToast()
                .padding(.top, 68)
                .zIndex(20)
        }
        .background(Theme.background)
        .background(WindowConfigurator())
        .animation(.easeInOut(duration: 0.2), value: model.statusMessage)
        .sheet(isPresented: Binding(
            get: { model.showSamples },
            set: { model.showSamples = $0 }
        )) {
            SamplesSheet()
                .environment(model)
        }
    }
}

// MARK: - Toast

struct StatusToast: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        if let message = model.statusMessage {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(message)
                    .font(.ui(10, .medium))
                    .foregroundStyle(Theme.text.opacity(0.92))
                    .lineLimit(2)

                Button {
                    model.statusMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Theme.raised)
                    .overlay(Capsule().strokeBorder(Theme.strokeStrong, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: message) {
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                if model.statusMessage == message {
                    withAnimation(.easeOut(duration: 0.2)) {
                        model.statusMessage = nil
                    }
                }
            }
        }
    }

    private var icon: String {
        if model.hasErrors { return "exclamationmark.triangle.fill" }
        if model.machine.isHalted { return "stop.circle.fill" }
        return "info.circle.fill"
    }

    private var iconColor: Color {
        if model.hasErrors { return Theme.red }
        if model.machine.isHalted { return Theme.amber }
        return Theme.cyan
    }
}

#if DEBUG
#Preview("Full App") {
    ContentView()
        .environment(SimulatorModel.preview(sampleID: "countdown", steps: 23))
        .preferredColorScheme(.dark)
        .frame(width: 1500, height: 960)
}

#Preview("Status Toast") {
    ZStack(alignment: .top) {
        Theme.background
        StatusToast()
            .environment(SimulatorModel.preview(statusMessage: "Halted after 42 instructions."))
            .padding(.top, 68)
    }
    .preferredColorScheme(.dark)
    .frame(width: 700, height: 200)
}
#endif
