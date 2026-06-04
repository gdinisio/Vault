//
//  SparklineView.swift
//  Vault
//
//  Lightweight line + area sparkline for holdings rows and the hero chart.
//

import SwiftUI

struct SparklineView: View {
    let points: [Double]
    var color: Color = Theme.gain
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let path = linePath(in: geo.size)
            ZStack {
                // area fill
                areaPath(in: geo.size)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // stroke
                path
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalised(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        let minV = points.min() ?? 0
        let maxV = points.max() ?? 1
        let range = maxV - minV == 0 ? 1 : maxV - minV
        let step = size.width / CGFloat(points.count - 1)
        return points.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let y = size.height - CGFloat((value - minV) / range) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        let pts = normalised(in: size)
        guard let first = pts.first else { return path }
        path.move(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        let pts = normalised(in: size)
        guard let last = pts.last, let first = pts.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

/// Deterministic pseudo-random series from a seed, mirroring the design mock.
/// Used purely for cosmetic sparklines until real history is wired in.
enum Spark {
    static func series(seed: Double, count: Int = 22, trendingUp: Bool = true) -> [Double] {
        var out: [Double] = []
        var v = 50.0
        for i in 0..<count {
            let x = sin(seed * 12.9898 + Double(i) * 1.7) * 43758.5453
            let noise = (x - floor(x)) - 0.5
            v += noise * 7 + (trendingUp ? 0.9 : -0.7)
            out.append(v)
        }
        return out
    }
}

#Preview {
    VStack(spacing: 24) {
        SparklineView(points: Spark.series(seed: 7.3, count: 60, trendingUp: true), color: Theme.gain)
            .frame(width: 360, height: 96)
        SparklineView(points: Spark.series(seed: 2.5, count: 22, trendingUp: false), color: Theme.loss)
            .frame(width: 120, height: 38)
    }
    .padding(40)
    .background(Theme.bgDeep)
}
