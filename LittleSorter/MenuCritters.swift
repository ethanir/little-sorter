import SwiftUI

/// Single-image critters kept to the screen edges, each on its own path:
///  • bird  — gentle wave across the sky at the very top
///  • bunny — hops in the bottom-left corner
///  • cat   — prowls in the bottom-right corner
///
/// Deliberately sparse: kept OFF the title and the tappable cards so the menu
/// reads as one calm ambient layer, not a busy dashboard. Drawn as a frontmost
/// overlay (never blocks taps), Reduce-Motion aware, on-screen clamped.
struct MenuCritters: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Gait { case walk, hop, fly }

    private enum Path {
        case pingPong(lane: Double, xLo: Double, xHi: Double)
    }

    private struct Critter: Identifiable {
        let id: Int; let name: String; let size: CGFloat
        let speed: Double; let phase: Double; let gait: Gait; let path: Path
    }

    private let critters: [Critter] = [
        // top sky — drifts above the title
        Critter(id: 0, name: "bird", size: 46, speed: 0.030, phase: 0.10, gait: .fly,
                path: .pingPong(lane: 0.05, xLo: 0.06, xHi: 0.94)),
        Critter(id: 1, name: "bunny", size: 50, speed: 0.026, phase: 0.20, gait: .hop,
                path: .pingPong(lane: 0.88, xLo: 0.06, xHi: 0.40)),
        Critter(id: 2, name: "cat", size: 48, speed: 0.022, phase: 0.60, gait: .walk,
                path: .pingPong(lane: 0.88, xLo: 0.60, xHi: 0.94))
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if reduceMotion {
                    ForEach(critters) { c in critterView(c, t: 0, frozen: true, in: geo.size) }
                } else {
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        ForEach(critters) { c in critterView(c, t: t, frozen: false, in: geo.size) }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func critterView(_ c: Critter, t: Double, frozen: Bool, in size: CGSize) -> some View {
        let u = frozen ? frac(c.phase) : frac(t * c.speed + c.phase)
        let base = basePosition(c.path, u: u)
        let m = motion(for: c, t: t, frozen: frozen, size: size)
        let halfW = c.size / 2, halfH = c.size / 2, pad: CGFloat = 6
        let rawX = CGFloat(base.x) * size.width
        let rawY = CGFloat(base.y) * size.height + m.yOff
        let x = min(max(rawX, halfW + pad), size.width - halfW - pad)
        let y = min(max(rawY, halfH + pad), size.height - halfH - pad)
        return Image(c.name).resizable().scaledToFit()
            .frame(width: c.size, height: c.size)
            .scaleEffect(x: base.facing * m.sx, y: m.sy, anchor: m.anchor)
            .rotationEffect(.degrees(Double(m.rot)), anchor: m.anchor)
            .position(x: x, y: y)
    }

    private func basePosition(_ path: Path, u: Double) -> (x: Double, y: Double, facing: CGFloat) {
        switch path {
        case let .pingPong(lane, xLo, xHi):
            let lp = lanePhase(u)
            let x = xLo + lp.amount * (xHi - xLo)
            return (x, lane, lp.facing)
        }
    }

    private func lanePhase(_ u: Double) -> (amount: Double, facing: CGFloat) {
        let pause = 0.08, travel = 0.5 - 2 * 0.08
        if u < pause { return (0, 1) }
        else if u < 0.5 - pause { return (smoothStep((u - pause) / travel), 1) }
        else if u < 0.5 + pause { return (1, -1) }
        else if u < 1 - pause { return (1 - smoothStep((u - (0.5 + pause)) / travel), -1) }
        else { return (0, 1) }
    }

    private struct Motion {
        var yOff: CGFloat = 0; var rot: Double = 0
        var sx: CGFloat = 1; var sy: CGFloat = 1; var anchor: UnitPoint = .bottom
    }

    private func motion(for c: Critter, t: Double, frozen: Bool, size: CGSize) -> Motion {
        var m = Motion()
        m.anchor = (c.gait == .fly) ? .center : .bottom
        guard !frozen else { return m }
        switch c.gait {
        case .fly:
            let flap = sin(2 * .pi * frac(t / 0.24 + c.phase))
            m.sy = 1 + 0.10 * CGFloat(flap); m.sx = 1 - 0.05 * CGFloat(flap)
            m.rot = sin(t * 0.8 + c.phase * 6) * 5; m.yOff = CGFloat(sin(t * 0.7 + c.phase)) * 2
        case .hop:
            let u = frac(t / 1.7 + c.phase), airFrac = 0.62
            if u < airFrac {
                let a = u / airFrac, arc = 4 * (u / airFrac) * (1 - u / airFrac)
                m.yOff = -CGFloat(arc) * size.height * 0.04
                m.sy = 1 + 0.10 * CGFloat(arc); m.sx = 1 - 0.06 * CGFloat(arc); m.rot = (a - 0.5) * 9
            } else {
                let land = (u - airFrac) / (1 - airFrac), squash = CGFloat(max(0, 1 - land * 3))
                m.sy = 1 - 0.13 * squash; m.sx = 1 + 0.11 * squash
            }
        case .walk:
            let s = sin(2 * .pi * frac(t / 0.62 + c.phase))
            m.yOff = -CGFloat(abs(s)) * 3.5; m.rot = s * 4.5
            m.sx = 1 + 0.025 * CGFloat(abs(s)); m.sy = 1 - 0.020 * CGFloat(abs(s))
        }
        return m
    }

    private func smoothStep(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }
    private func frac(_ x: Double) -> Double { let r = x.truncatingRemainder(dividingBy: 1); return r < 0 ? r + 1 : r }
}
