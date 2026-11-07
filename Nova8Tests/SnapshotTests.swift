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
    func testMainLightSnapshot() throws {
        let model = SimulatorModel()
        model.loadSample(id: "countdown")
        for _ in 0..<23 { model.step() }
        try render(
            ContentView().environment(model),
            size: CGSize(width: 1500, height: 960),
            name: "snapshot-main-light.png",
            appearance: .aqua
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
    func testThemeResolvesForAppearance() throws {
        let root = Rectangle()
            .fill(Theme.background)
            .frame(width: 24, height: 24)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 24, height: 24)

        // Sample the same hosting view twice so this also proves the dynamic
        // tokens re-resolve when the appearance changes at runtime.
        func sample(_ name: NSAppearance.Name) -> NSColor? {
            hosting.appearance = NSAppearance(named: name)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            hosting.displayIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                return nil
            }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            return rep.colorAt(x: 12, y: 12)?.usingColorSpace(.sRGB)
        }

        guard let light = sample(.aqua), let dark = sample(.darkAqua) else {
            return XCTFail("Could not sample theme colors")
        }

        XCTAssertGreaterThan(light.brightnessComponent, 0.75)
        XCTAssertLessThan(dark.brightnessComponent, 0.35)
    }

    @MainActor
    private func render<V: View>(
        _ view: V,
        size: CGSize,
        name: String,
        appearance: NSAppearance.Name = .darkAqua
    ) throws {
        let scheme: ColorScheme = appearance == .darkAqua ? .dark : .light
        let root = view
            .environment(\.colorScheme, scheme)
            .frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: root)
        hosting.appearance = NSAppearance(named: appearance)
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
