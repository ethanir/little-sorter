import SwiftUI

enum PaymentFlow: Int, Identifiable {
    case gate
    case grownUps
    var id: Int { rawValue }
}

struct LevelPickerView: View {
    @EnvironmentObject var store: Store
    var onPlay: (Level) -> Void
    var completed: Set<Int>
    var stars: [Int: Int]
    var times: [Int: Double]
    @Binding var timedMode: Bool

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isPad: Bool { hSizeClass == .regular }

    @State private var paymentFlow: PaymentFlow?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    /// On iPad, size the cards so the three rows fill the height (no big dead gap,
    /// bigger tap targets). On iPhone we keep the exact current 130pt card.
    private func cardHeight(_ geo: GeometryProxy) -> CGFloat {
        guard isPad else { return 130 }
        let rows: CGFloat = 3
        let reserved: CGFloat = 240        // title + subtitle + Grown-Ups + paddings
        let labelAndSpacing: CGFloat = 64  // per-row label height + grid spacing
        let avail = geo.size.height - reserved
        return max(160, avail / rows - labelAndSpacing)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.95, blue: 0.86),
                        Color(red: 0.86, green: 0.93, blue: 0.99)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: isPad ? 16 : 12) {
                    Text("Little Sorter")
                        .font(.system(size: isPad ? 56 : 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.45))
                        .padding(.top, isPad ? 36 : 28)

                    Text("Pick a place to play!")
                        .font(.system(size: isPad ? 24 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.42, green: 0.47, blue: 0.60))

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: isPad ? 24 : 16) {
                            ForEach(Level.all) { level in
                                card(level, cardHeight: cardHeight(geo))
                            }
                        }
                        .padding(.horizontal, isPad ? 40 : 16)
                        .padding(.vertical, isPad ? 8 : 16)
                    }

                    // Small, calm, adult-facing entry point. The ONLY route to purchase
                    // and external links — kept out of the child's tappable play area.
                    Button { paymentFlow = .gate } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "person.2.fill")
                            Text("Grown-Ups")
                        }
                        .font(.system(size: isPad ? 18 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.5, green: 0.55, blue: 0.65))
                    }
                    .padding(.bottom, isPad ? 20 : 14)
                    .accessibilityLabel("For grown-ups")
                }
            }
            .statusBarHidden(true)
            .sheet(item: $paymentFlow) { flow in
                switch flow {
                case .gate:
                    ParentalGate(onPass: {
                        paymentFlow = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            paymentFlow = .grownUps
                        }
                    })
                case .grownUps:
                    GrownUpsView(challengeMode: $timedMode)
                        .environmentObject(store)
                }
            }
        }
    }

    private func isLocked(_ level: Level) -> Bool { !level.isFree && !store.isUnlocked }

    private func tap(_ level: Level) {
        if isLocked(level) {
            SpeechManager.shared.speak("Ask a grown-up")
        } else {
            onPlay(level)
        }
    }

    private func card(_ level: Level, cardHeight: CGFloat) -> some View {
        let done = completed.contains(level.id)
        let earned = stars[level.id] ?? 0
        let best = times[level.id]
        let corner: CGFloat = isPad ? 34 : 28
        return Button { tap(level) } label: {
            VStack(spacing: isPad ? 12 : 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: corner).fill(level.background)
                    if let thumb = level.thumbnailImage {
                        Image(thumb).resizable().scaledToFill()
                    } else {
                        Image(systemName: level.symbol).font(.system(size: isPad ? 76 : 56)).foregroundStyle(.white)
                    }
                }
                .frame(height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(done ? Color.yellow : .white.opacity(0.7),
                                      lineWidth: done ? 4 : 3)
                )
                .overlay(alignment: .topLeading) {
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: isPad ? 34 : 26, weight: .bold))
                            .foregroundStyle(.white, .green)
                            .padding(isPad ? 12 : 8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isLocked(level) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: isPad ? 28 : 20, weight: .bold)).foregroundStyle(.white)
                            .padding(isPad ? 12 : 9).background(Circle().fill(.black.opacity(0.45))).padding(isPad ? 12 : 8)
                    }
                }

                Text(level.title)
                    .font(.system(size: isPad ? 30 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.45))

                if earned > 0 {
                    starsRow(earned: earned, best: best)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(level, done: done, earned: earned))
    }

    private func starsRow(earned: Int, best: Double?) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: isPad ? 7 : 5) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: isPad ? 22 : 15))
                        .foregroundStyle(i < earned ? Color.yellow : Color.gray.opacity(0.3))
                        .shadow(color: i < earned ? .orange.opacity(0.45) : .clear, radius: 1.5)
                }
            }
            if let best {
                HStack(spacing: 3) {
                    Image(systemName: "stopwatch").font(.system(size: isPad ? 15 : 11))
                    Text(String(format: "%.1fs", best))
                        .font(.system(size: isPad ? 16 : 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.42, green: 0.47, blue: 0.60))
            }
        }
    }

    private func accessibilityText(_ level: Level, done: Bool, earned: Int) -> String {
        if isLocked(level) { return "\(level.title), locked, ask a grown-up" }
        if earned > 0 { return "\(level.title), \(earned) of 3 stars" }
        if done { return "\(level.title), completed" }
        return level.title
    }
}
