import XCTest
import SwiftUI
import AppKit
@testable import Nova8

final class SnapshotTests: XCTestCase {

    private var directory: String {
        let path = NSTemporaryDirectory() + "Nova8Snapshots"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    @MainActor
    func testMainSnapshot() throws {
        let model = SimulatorModel()
        model.loadSample(id: "countdown")
        for _ in 0..<23 { model.step() }
        try render(
            ContentView().environment(model),
            size: CGSize(width: 1500, height: 960),
            name: "snapshot-main.png"
        )
    }

    @MainActor
    func testHaltedSnapshot() throws {
        let model = SimulatorModel()
        model.loadSample(id: "blank")
        var guardCount = 0
        while !model.machine.isHalted && guardCount < 400 {
            model.step()
            guardCount += 1
        }
        try render(
            ContentView().environment(model),
            size: CGSize(width: 1500, height: 960),
            name: "snapshot-halted.png"
        )
    }

    @MainActor
    func testErrorSnapshot() throws {
        let model = SimulatorModel()
        model.updateSource("""
        ; broken program
        .text
        start: FROB A
               LDI A, 999
               JMP nowhere
        """)
        model.assembleAndLoad()
        model.showDiagnostics = true
        try render(
            ContentView().environment(model),
            size: CGSize(width: 1500, height: 960),
            name: "snapshot-errors.png"
        )
    }

    @MainActor
    func testStackSnapshot() throws {
        let model = SimulatorModel()
        model.loadSample(id: "subroutine")
        var guardCount = 0
        while model.stackDepth < 2 && guardCount < 2000 {
            model.step()
            guardCount += 1
        }
        try render(
            ContentView().environment(model),
            size: CGSize(width: 1500, height: 960),
            name: "snapshot-stack.png"
        )
    }

    @MainActor
    func testSamplesSheetSnapshot() throws {
        let model = SimulatorModel()
        try render(
            SamplesSheet().environment(model),
            size: CGSize(width: 780, height: 590),
            name: "snapshot-samples.png"
        )
    }

    @MainActor
    private func render<V: View>(_ view: V, size: CGSize, name: String) throws {
        let root = view.frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return XCTFail("Could not allocate bitmap")
        }
        hosting.displayIfNeeded()
        hosting.layer?.displayIfNeeded()
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            return XCTFail("Could not encode PNG")
        }

        let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
        try data.write(to: url)
        print("SNAPSHOT_WRITTEN \(url.path)")
    }
}
