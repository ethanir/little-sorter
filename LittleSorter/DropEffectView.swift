import SwiftUI

/// A short, self-contained particle burst that plays when an item is dropped in
/// the correct zone. One reusable view, themed per `DropEffect`. Pure SwiftUI
/// Canvas — no images, no UIKit. Mount it with a fresh `.id(...)` each time so it
/// replays from the start; it fades itself out over `duration`.
struct DropEffectView: View {
    let effect: DropEffect
    var duration: Double = 1.0

    @State private var start = Date()
    // Durable: generated exactly once. If this were a plain `let` set in init, a
    // parent re-render (e.g. the Timed-mode clock ticking 10×/sec) would re-run
    // init and reshuffle the random layout mid-burst, making the effect jitter.
    @State private var particles: [Particle]

    init(effect: DropEffect, duration: Double = 1.0) {
        self.effect = effect
        self.duration = duration
        _particles = State(initialValue: DropEffectView.make(effect))
    }

    private enum ParticleShape { case circle, oval, star }

    private struct Particle {
        var angle: Double       // radians; -.pi/2 is straight up (screen y is down)
        var speed: Double       // outward travel in points
        var gravity: Double     // downward pull (×140·t²)
        var sway: Double        // horizontal flutter amplitude
        var swayFreq: Double
        var size: CGFloat
        var spin: Double        // rotations over the lifetime
        var color: Color
        var shape: ParticleShape
        var delay: Double       // small stagger
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let elapsed = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                for p in particles {
                    let span = max(0.0001, duration - p.delay)
                    let lt = (elapsed - p.delay) / span
                    guard lt >= 0 else { continue }
                    let t = min(1, lt)
                    let e = 1 - pow(1 - t, 3)                 // easeOutCubic outward
                    let x = cx + CGFloat(cos(p.angle) * p.speed * e
                            + p.sway * sin(t * 2 * Double.pi * p.swayFreq))
                    let y = cy + CGFloat(sin(p.angle) * p.speed * e
                            + p.gravity * (t * t) * 140)
                    let op = t < 0.12 ? t / 0.12 : 1 - (t - 0.12) / 0.88
                    let o = max(0, min(1, op))
                    guard o > 0.01 else { continue }

                    let s = p.size
                    var path: Path
                    switch p.shape {
                    case .circle:
                        path = Path(ellipseIn: CGRect(x: x - s/2, y: y - s/2, width: s, height: s))
                    case .oval:
                        path = Path(ellipseIn: CGRect(x: x - s*0.32, y: y - s*0.6,
                                                      width: s*0.64, height: s*1.2))
                    case .star:
                        path = DropEffectView.starPath(center: CGPoint(x: x, y: y), r: s*0.6)
                    }
                    if p.shape != .circle {
                        let rot = p.spin * 2 * .pi * t
                        var tf = CGAffineTransform(translationX: x, y: y)
                        tf = tf.rotated(by: rot).translatedBy(x: -x, y: -y)
                        path = path.applying(tf)
                    }
                    ctx.fill(path, with: .color(p.color.opacity(o)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Particle recipes

    private static func make(_ e: DropEffect) -> [Particle] {
        func r(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b) }
        func rs(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b) }
        var ps: [Particle] = []

        switch e {
        case .splash:
            let blues: [Color] = [.blue, .cyan, Color(red: 0.4, green: 0.7, blue: 1.0)]
            for _ in 0..<16 {
                ps.append(Particle(angle: r(-2.6, -0.55), speed: r(45, 95), gravity: r(0.9, 1.4),
                                   sway: 0, swayFreq: 0, size: rs(8, 16), spin: 0,
                                   color: blues.randomElement()!, shape: .circle, delay: r(0, 0.05)))
            }
        case .feathers:
            let creams: [Color] = [.white, Color(white: 0.96), Color(red: 1, green: 0.95, blue: 0.8)]
            for _ in 0..<12 {
                ps.append(Particle(angle: r(-2.4, -0.7), speed: r(20, 55), gravity: r(0.45, 0.9),
                                   sway: r(8, 18), swayFreq: r(1, 2), size: rs(12, 20), spin: r(-0.5, 0.5),
                                   color: creams.randomElement()!, shape: .oval, delay: r(0, 0.15)))
            }
        case .leaves:
            let greens: [Color] = [.green, Color(red: 0.3, green: 0.7, blue: 0.2),
                                   Color(red: 0.5, green: 0.8, blue: 0.3)]
            for _ in 0..<12 {
                ps.append(Particle(angle: r(-2.4, -0.7), speed: r(25, 60), gravity: r(0.45, 0.9),
                                   sway: r(10, 20), swayFreq: r(1, 2), size: rs(12, 20), spin: r(-0.7, 0.7),
                                   color: greens.randomElement()!, shape: .oval, delay: r(0, 0.12)))
            }
        case .dust:
            for _ in 0..<14 {
                let c = Color(red: r(0.45, 0.6), green: r(0.33, 0.45), blue: r(0.2, 0.3))
                ps.append(Particle(angle: r(-2.8, -0.35), speed: r(30, 72), gravity: r(0.0, 0.25),
                                   sway: 0, swayFreq: 0, size: rs(12, 24), spin: 0,
                                   color: c.opacity(0.85), shape: .circle, delay: r(0, 0.05)))
            }
        case .petals:
            let cols: [Color] = [.pink, .yellow, .orange, .purple, .red]
            for _ in 0..<16 {
                ps.append(Particle(angle: r(0, 2 * .pi), speed: r(40, 85), gravity: r(0.3, 0.7),
                                   sway: r(4, 10), swayFreq: r(1, 2), size: rs(10, 18), spin: r(-0.6, 0.6),
                                   color: cols.randomElement()!, shape: .oval, delay: r(0, 0.05)))
            }
        case .clouds:
            for _ in 0..<10 {
                ps.append(Particle(angle: r(-2.5, -0.6), speed: r(20, 50), gravity: r(-0.2, 0.05),
                                   sway: r(4, 10), swayFreq: 1, size: rs(18, 34), spin: 0,
                                   color: .white.opacity(0.9), shape: .circle, delay: r(0, 0.1)))
            }
        case .sand:
            let tans: [Color] = [Color(red: 0.95, green: 0.85, blue: 0.55),
                                 Color(red: 0.9, green: 0.78, blue: 0.5)]
            for _ in 0..<18 {
                ps.append(Particle(angle: r(-2.9, -0.25), speed: r(35, 80), gravity: r(0.8, 1.3),
                                   sway: 0, swayFreq: 0, size: rs(5, 11), spin: 0,
                                   color: tans.randomElement()!, shape: .circle, delay: r(0, 0.05)))
            }
        case .sparkle:
            let golds: [Color] = [.yellow, Color(red: 1, green: 0.85, blue: 0.2), .white]
            for _ in 0..<14 {
                ps.append(Particle(angle: r(0, 2 * .pi), speed: r(30, 75), gravity: r(-0.1, 0.15),
                                   sway: 0, swayFreq: 0, size: rs(10, 20), spin: r(0.2, 0.8),
                                   color: golds.randomElement()!, shape: .star, delay: r(0, 0.12)))
            }
        }
        return ps
    }

    private static func starPath(center c: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        let points = 4
        for i in 0..<(points * 2) {
            let rr: CGFloat = (i % 2 == 0) ? r : r * 0.4
            let a: Double = Double(i) / Double(points * 2) * 2 * Double.pi - Double.pi / 2
            let pt = CGPoint(x: c.x + rr * CGFloat(cos(a)),
                             y: c.y + rr * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
