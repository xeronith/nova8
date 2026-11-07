import AppKit
import SwiftUI

/// Lets the borderless-looking window behave like a normal one: the custom
/// top bar can drag it, and the traffic lights sit over our background.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .novaBg
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
