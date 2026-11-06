import CoreGraphics
import Foundation
import SwiftUI

enum DatapathGeometry {
    static let size = CGSize(width: 900, height: 520)

    static let busY: CGFloat = 216
    static let busStartX: CGFloat = 24
    static let busEndX: CGFloat = 870

    static let registers: [Hardware] = [.a, .b, .c, .d, .sp, .pc, .t, .ir]

    static let regPanel = CGRect(x: 14, y: 12, width: 660, height: 148)
    static let controlPanel = CGRect(x: 686, y: 12, width: 200, height: 148)

    static let aluPanel = CGRect(x: 24, y: 248, width: 260, height: 252)
    static let signalsPanel = CGRect(x: 296, y: 248, width: 204, height: 252)
    static let memoryPanel = CGRect(x: 548, y: 240, width: 338, height: 260)

    static let tileWidth: CGFloat = 73
    static let tileHeight: CGFloat = 104
    static let tileStep: CGFloat = 79
    static let tileStartX: CGFloat = 26
    static let tileY: CGFloat = 44

    static let aluTapX: CGFloat = 154
    static let marTapX: CGFloat = 630
    static let mdrTapX: CGFloat = 552

    static let marRect = CGRect(x: 560, y: 286, width: 80, height: 46)
    static let mdrRect = CGRect(x: 560, y: 428, width: 80, height: 46)
    static let ramRect = CGRect(x: 668, y: 278, width: 204, height: 210)

    static func index(of hardware: Hardware) -> Int? {
        registers.firstIndex(of: hardware)
    }

    static func tileRect(_ hardware: Hardware) -> CGRect? {
        guard let index = index(of: hardware) else { return nil }
        return CGRect(
            x: tileStartX + CGFloat(index) * tileStep,
            y: tileY,
            width: tileWidth,
            height: tileHeight
        )
    }

    static func tileCenterX(_ hardware: Hardware) -> CGFloat? {
        tileRect(hardware).map { $0.midX }
    }

    static func registerBottom(_ hardware: Hardware) -> CGPoint? {
        tileRect(hardware).map { CGPoint(x: $0.midX, y: $0.maxY) }
    }

    static func busPoint(_ x: CGFloat) -> CGPoint {
        CGPoint(x: x, y: busY)
    }
}

// MARK: - Routes

struct Route {
    let points: [CGPoint]
    private let lengths: [CGFloat]
    private let total: CGFloat

    init(_ points: [CGPoint]) {
        self.points = points
        var lengths: [CGFloat] = []
        var total: CGFloat = 0
        for index in 0..<max(0, points.count - 1) {
            let a = points[index]
            let b = points[index + 1]
            let length = hypot(b.x - a.x, b.y - a.y)
            lengths.append(length)
            total += length
        }
        self.lengths = lengths
        self.total = max(total, 0.0001)
    }

    func point(at progress: CGFloat) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        var remaining = min(max(progress, 0), 1) * total
        for (index, length) in lengths.enumerated() {
            if remaining <= length {
                let a = points[index]
                let b = points[index + 1]
                let t = length <= 0.0001 ? 0 : remaining / length
                return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            remaining -= length
        }
        return points.last ?? .zero
    }

    var path: Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

enum DatapathRoutes {
    static func route(for op: MicroOp) -> Route? {
        switch op.kind {
        case .transfer(let from, let to):
            return route(from: from, to: to)
        case .memoryRead:
            return memoryDataRoute(reversed: false)
        case .memoryWrite:
            return memoryDataRoute(reversed: true)
        case .alu(_, _, let destination, _):
            return destination.flatMap { route(from: .alu, to: $0) }
        case .branch(let taken, _):
            return taken ? route(from: .t, to: .pc) : nil
        case .decode, .halt, .nop:
            return nil
        }
    }

    static func route(from: Hardware, to: Hardware) -> Route? {
        if from == to { return nil }

        // Memory data bus: RAM <-> MDR
        if from == .ram && to == .mdr { return memoryDataRoute(reversed: false) }
        if from == .mdr && to == .ram { return memoryDataRoute(reversed: true) }

        // ALU output
        if from == .alu, let toX = busTapX(to) {
            var points: [CGPoint] = [CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.aluPanel.minY)]
            points.append(CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.busY))
            points.append(contentsOf: busPath(fromX: DatapathGeometry.aluTapX, toX: toX, target: to))
            return Route(points)
        }

        // Into the ALU
        if to == .alu, let fromX = busTapX(from) {
            var points: [CGPoint] = [CGPoint(x: fromX, y: DatapathGeometry.busY)]
            points.append(CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.busY))
            points.append(CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.aluPanel.minY))
            return Route(points)
        }

        guard let fromX = busTapX(from),
              let toX = busTapX(to) else { return nil }

        var points: [CGPoint] = [sourceAnchor(from)]
        if from == .mdr {
            points = [CGPoint(x: DatapathGeometry.mdrTapX, y: 451), CGPoint(x: DatapathGeometry.mdrTapX, y: DatapathGeometry.busY)]
        } else if from == .mar {
            points = [CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.marRect.midY), CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.busY)]
        } else if from == .alu {
            points = [CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.aluPanel.minY), CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.busY)]
        } else {
            points = [sourceAnchor(from)]
        }

        points.append(CGPoint(x: fromX, y: DatapathGeometry.busY))

        if to != .mdr && to != .mar && to != .alu {
            points.append(CGPoint(x: toX, y: DatapathGeometry.busY))
            if let bottom = DatapathGeometry.registerBottom(to) {
                points.append(bottom)
            }
        } else if to == .mar {
            points.append(CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.busY))
            points.append(CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.marRect.minY))
        } else if to == .mdr {
            points.append(CGPoint(x: DatapathGeometry.mdrTapX, y: DatapathGeometry.busY))
            points.append(CGPoint(x: DatapathGeometry.mdrTapX, y: 451))
            points.append(CGPoint(x: DatapathGeometry.mdrRect.minX, y: 451))
        } else if to == .alu {
            points.append(CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.busY))
            points.append(CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.aluPanel.minY))
        }

        return Route(points)
    }

    private static func busTapX(_ hardware: Hardware) -> CGFloat? {
        switch hardware {
        case .a, .b, .c, .d, .sp, .pc, .t, .ir:
            return DatapathGeometry.tileCenterX(hardware)
        case .mar:
            return DatapathGeometry.marTapX
        case .mdr:
            return DatapathGeometry.mdrTapX
        case .alu:
            return DatapathGeometry.aluTapX
        default:
            return nil
        }
    }

    private static func sourceAnchor(_ hardware: Hardware) -> CGPoint {
        switch hardware {
        case .mar:
            return CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.marRect.minY)
        case .mdr:
            return CGPoint(x: DatapathGeometry.mdrRect.minX, y: 451)
        case .alu:
            return CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.aluPanel.minY)
        default:
            if let bottom = DatapathGeometry.registerBottom(hardware) {
                return bottom
            }
            return CGPoint(x: DatapathGeometry.aluTapX, y: DatapathGeometry.busY)
        }
    }

    private static func busPath(fromX: CGFloat, toX: CGFloat, target: Hardware) -> [CGPoint] {
        var points: [CGPoint] = [CGPoint(x: toX, y: DatapathGeometry.busY)]
        if target == .mar {
            points.append(CGPoint(x: DatapathGeometry.marTapX, y: DatapathGeometry.marRect.minY))
        } else if target == .mdr {
            points.append(CGPoint(x: DatapathGeometry.mdrTapX, y: 451))
            points.append(CGPoint(x: DatapathGeometry.mdrRect.minX, y: 451))
        } else if let bottom = DatapathGeometry.registerBottom(target) {
            points.append(bottom)
        }
        return points
    }

    private static func memoryDataRoute(reversed: Bool) -> Route {
        let ram = CGPoint(x: DatapathGeometry.ramRect.minX, y: 451)
        let mdr = CGPoint(x: DatapathGeometry.mdrRect.maxX, y: 451)
        return reversed ? Route([mdr, ram]) : Route([ram, mdr])
    }

    static func packetValue(for outcome: StepOutcome) -> String {
        let op = outcome.op
        switch op.kind {
        case .transfer(_, let to):
            return String(format: "0x%02X", outcome.after.read(to))
        case .memoryRead:
            return String(format: "0x%02X", outcome.after.mdr)
        case .memoryWrite:
            guard let address = op.memoryAddress else { return "0x??" }
            return String(format: "0x%02X", outcome.after.ram[Int(address)])
        case .alu(_, _, let destination, _):
            if let destination {
                return String(format: "0x%02X", outcome.after.read(destination))
            }
            return "flags"
        case .branch(_, let target):
            return String(format: "0x%02X", target)
        case .decode:
            return "decode"
        case .halt:
            return "halt"
        case .nop:
            return "nop"
        }
    }
}
