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

    @State private var paymentFlow: PaymentFlow?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.95, blue: 0.86),
                    Color(red: 0.86, green: 0.93, blue: 0.99)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Little Sorter")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.45))
                    .padding(.top, 28)

                Text("Pick a place to play!")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.42, green: 0.47, blue: 0.60))

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Level.all) { level in
                            card(level)
                        }
                    }
                    .padding(16)
                }

                // Small, calm, adult-facing entry point. The ONLY route to purchase
                // and external links — kept out of the child's tappable play area.
                Button { paymentFlow = .gate } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "person.2.fill")
                        Text("Grown-Ups")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.5, green: 0.55, blue: 0.65))
                }
                .padding(.bottom, 14)
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

    private func isLocked(_ level: Level) -> Bool { !level.isFree && !store.isUnlocked }

    private func tap(_ level: Level) {
        if isLocked(level) {
            // A child must never trigger the purchase flow. Just a gentle spoken
            // nudge; unlocking happens only via the Grown-Ups button + parental gate.
            SpeechManager.shared.speak("Ask a grown-up")
        } else {
            onPlay(level)
        }
    }

    private func card(_ level: Level) -> some View {
        let done = completed.contains(level.id)
        let earned = stars[level.id] ?? 0
        let best = times[level.id]
        return Button { tap(level) } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(level.background)
                    if let thumb = level.thumbnailImage {
                        Image(thumb).resizable().scaledToFill()
                    } else {
                        Image(systemName: level.symbol).font(.system(size: 56)).foregroundStyle(.white)
                    }
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(done ? Color.yellow : .white.opacity(0.7),
                                      lineWidth: done ? 4 : 3)
                )
                // Clear, conventional "done" signal — a checkmark, not just a glow.
                .overlay(alignment: .topLeading) {
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white, .green)
                            .padding(8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isLocked(level) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                            .padding(9).background(Circle().fill(.black.opacity(0.45))).padding(8)
                    }
                }

                Text(level.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.45))

                // Stars are a Challenge-Mode reward, so they only appear once earned.
                // Never-played levels show no stars (empty grey stars read as "zero").
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
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(i < earned ? Color.yellow : Color.gray.opacity(0.3))
                        .shadow(color: i < earned ? .orange.opacity(0.45) : .clear, radius: 1.5)
                }
            }
            if let best {
                HStack(spacing: 3) {
                    Image(systemName: "stopwatch").font(.system(size: 11))
                    Text(String(format: "%.1fs", best))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
