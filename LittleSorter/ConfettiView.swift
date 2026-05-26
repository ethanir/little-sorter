import SwiftUI

/// Lightweight, asset-free confetti for the celebratory state.
/// Pieces are generated once into `@State` (a durable storage boundary), so
/// they are NOT regenerated when the parent re-renders mid-animation.
struct ConfettiView: View {

    private struct Piece: Identifiable {
        let id = UUID()
        let xRatio: CGFloat      // 0...1, multiplied by width at layout time
        let color: Color
        let size: CGFloat
        let duration: Double
        let delay: Double
        let spin: Double
    }

    @State private var pieces: [Piece] = ConfettiView.makePieces()
    @State private var animate = false

    private static func makePieces(count: Int = 70) -> [Piece] {
        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint]
        return (0..<count).map { i in
            Piece(
                xRatio: CGFloat.random(in: 0...1),
                color: palette[i % palette.count],
                size: CGFloat.random(in: 8...16),
                duration: Double.random(in: 1.4...2.6),
                delay: Double.random(in: 0...0.4),
                spin: Double.random(in: -360...360)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.4)
                        .rotationEffect(.degrees(animate ? piece.spin : 0))
                        .position(
                            x: piece.xRatio * geo.size.width,
                            y: animate ? geo.size.height + 60 : -60
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
    }
}
