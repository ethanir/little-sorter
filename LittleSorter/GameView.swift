import SwiftUI
import Combine

// MARK: - Preference key for capturing drop-zone frames at runtime

struct ZoneFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - A fired drop-effect burst (positioned at the zone's center)

private struct ZoneBurst: Identifiable {
    let id: Int
    let effect: DropEffect
    let center: CGPoint
}

// MARK: - Gameplay

struct GameView: View {
    let level: Level
    let timed: Bool
    var onExit: () -> Void
    var onNext: () -> Void
    var onComplete: (Int, Double?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var chosenItems: [SortItem]
    @State private var placed: Set<UUID> = []
    @State private var offsets: [UUID: CGSize] = [:]
    @State private var draggingID: UUID? = nil
    @State private var zoneFrames: [String: CGRect] = [:]
    @State private var celebrating = false
    @State private var starPop = false

    // Haptic triggers. `.sensoryFeedback` fires on CHANGE only, so starting at 0
    // means no buzz on first appearance — only on real drops.
    @State private var successPulse: Int = 0
    @State private var bonkPulse: Int = 0

    // Correct-drop celebration
    @State private var burst: ZoneBurst? = nil
    @State private var burstCounter: Int = 0
    @State private var bouncingZone: String? = nil
    @State private var warmingEffects = true

    // Timed mode
    @State private var elapsed: Double = 0
    @State private var startDate: Date? = nil
    @State private var timerActive = false
    @State private var failed = false
    @State private var earnedStars = 0
    @State private var finishTime: Double? = nil
    private let timeLimit: Double = 30
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// Real elapsed time, derived from a start `Date` rather than an accumulator.
    /// A `+= 0.1` accumulator silently undercounts whenever the run loop is busy
    /// (animation, coalescing, backgrounding), which would drift the star
    /// thresholds; reading the wall clock keeps scores honest.
    private func currentElapsed() -> Double {
        guard let startDate else { return 0 }
        return min(timeLimit, Date().timeIntervalSince(startDate))
    }

    private func startTimer() {
        startDate = Date()
        elapsed = 0
        timerActive = true
    }

    /// Faster finish = more stars. ≤10s → 3, ≤20s → 2, otherwise (within 30s) → 1.
    private static func stars(for elapsed: Double) -> Int {
        if elapsed <= 10 { return 3 }
        if elapsed <= 20 { return 2 }
        return 1
    }

    private let spaceName = "littleSorterGameSpace"

    init(level: Level,
         timed: Bool,
         onExit: @escaping () -> Void,
         onNext: @escaping () -> Void,
         onComplete: @escaping (Int, Double?) -> Void) {
        self.level = level
        self.timed = timed
        self.onExit = onExit
        self.onNext = onNext
        self.onComplete = onComplete
        _chosenItems = State(initialValue: GameView.pick(from: level.items,
                                                         zones: level.zones,
                                                         max: 6))
    }

    /// Random subset that still guarantees at least one item per zone when possible.
    private static func pick(from pool: [SortItem], zones: [DropZone], max: Int) -> [SortItem] {
        var remaining = pool.shuffled()
        var chosen: [SortItem] = []
        for zone in zones {
            if let idx = remaining.firstIndex(where: { $0.targetZoneID == zone.id }) {
                chosen.append(remaining.remove(at: idx))
            }
        }
        for item in remaining where chosen.count < max {
            chosen.append(item)
        }
        return Array(chosen.prefix(max)).shuffled()
    }

    private var unplacedItems: [SortItem] {
        chosenItems.filter { !placed.contains($0.id) }
    }

    // Renders custom art when `imageName` is set, else the SF Symbol.
    @ViewBuilder
    private func itemArt(_ item: SortItem, size: CGFloat) -> some View {
        if let name = item.imageName, !name.isEmpty {
            Image(name).resizable().scaledToFit().frame(width: size * 0.62, height: size * 0.62)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: size * 0.52))
                .foregroundStyle(item.color)
        }
    }

    @ViewBuilder
    private func trayArt(_ item: SortItem) -> some View {
        if let name = item.imageName, !name.isEmpty {
            Image(name).resizable().scaledToFit().frame(width: 24, height: 24)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: 22))
                .foregroundStyle(item.color)
        }
    }

    // Illustrated zone art when `imageName` is set, else the SF Symbol.
    @ViewBuilder
    private func zoneArt(_ zone: DropZone, size: CGFloat) -> some View {
        if let name = zone.imageName, !name.isEmpty {
            Image(name).resizable().scaledToFit().frame(height: size)
        } else {
            Image(systemName: zone.symbol)
                .font(.system(size: size * 0.6))
                .foregroundStyle(.white)
        }
    }

    var body: some View {
        ZStack {
            if let bg = level.backgroundImage {
                Image(bg).resizable().scaledToFill().ignoresSafeArea()
            } else {
                level.background.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                header

                if placed.isEmpty && !celebrating {
                    instructionHint
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                if timed && !celebrating && !failed {
                    timerPill
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                Spacer(minLength: 8)
                zonesRow
                Spacer(minLength: 8)
                itemsRow
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.3), value: placed.isEmpty)

            if celebrating {
                celebrationOverlay
                    .transition(.opacity)
            }

            if failed {
                failOverlay
                    .transition(.opacity)
            }

            if let b = burst {
                if reduceMotion {
                    // Calm, non-flying acknowledgement instead of a particle burst.
                    Circle()
                        .fill(.white.opacity(0.35))
                        .frame(width: 90, height: 90)
                        .position(b.center)
                        .id(b.id)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                } else {
                    DropEffectView(effect: b.effect)
                        .frame(width: 300, height: 300)
                        .position(b.center)
                        .id(b.id)
                        .allowsHitTesting(false)
                }
            }

            if warmingEffects && !reduceMotion {
                // Pre-warm the Canvas/TimelineView GPU pipeline so the FIRST correct
                // drop's burst doesn't hitch. Rendered invisibly for a moment on entry.
                DropEffectView(effect: .sparkle)
                    .frame(width: 40, height: 40)
                    .opacity(0.001)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(.named(spaceName))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { warmingEffects = false }
            if timed { startTimer() }
        }
        .onReceive(tick) { _ in
            guard timed, timerActive, !celebrating, !failed else { return }
            elapsed = currentElapsed()
            if elapsed >= timeLimit {
                timerActive = false
                timeUp()
            }
        }
        .onPreferenceChange(ZoneFramePreferenceKey.self) { frames in
            zoneFrames = frames
        }
        .statusBarHidden(true)
        // SwiftUI-native haptics (iOS 17) — no UIKit. No-ops on devices without
        // a Taptic Engine and in the simulator.
        .sensoryFeedback(.success, trigger: successPulse)
        .sensoryFeedback(.impact(weight: .light), trigger: bonkPulse)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.white, .black.opacity(0.25))
            }
            .accessibilityLabel("Back")

            Spacer()
        }
        .padding(.top, 8)
    }

    private var instructionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
            Text("Drag each one where it belongs")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(.black.opacity(0.22)))
    }

    private var timerPill: some View {
        let left = max(0, timeLimit - elapsed)
        let low = left <= 10
        return HStack(spacing: 7) {
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 18, weight: .bold))
            Text("\(Int(ceil(left)))")
                .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
            Text("s")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule().fill(low ? Color.red.opacity(0.9) : Color.black.opacity(0.3)))
        .scaleEffect(low ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: low)
        .accessibilityLabel("\(Int(ceil(left))) seconds left")
    }

    // MARK: Drop zones

    private var zonesRow: some View {
        HStack(spacing: 12) {
            ForEach(level.zones) { zone in
                zoneView(zone)
            }
        }
    }

    private func zoneView(_ zone: DropZone) -> some View {
        let itemsHere = chosenItems.filter { placed.contains($0.id) && $0.targetZoneID == zone.id }

        return VStack(spacing: 6) {
            zoneArt(zone, size: 74)

            Text(zone.label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 4) {
                ForEach(itemsHere) { item in
                    trayArt(item)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(minHeight: 30)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 175)
        .scaleEffect(bouncingZone == zone.id && !reduceMotion ? 1.06 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.45), value: bouncingZone)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(zone.color.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.white.opacity(0.6), lineWidth: 3)
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ZoneFramePreferenceKey.self,
                    value: [zone.id: geo.frame(in: .named(spaceName))]
                )
            }
        )
        .accessibilityLabel(zone.label)
    }

    // MARK: Items area (up to 3 per row, wraps to a second row, gently staggered)

    private var itemsRow: some View {
        GeometryReader { geo in
            let perRow = 3
            let spacing: CGFloat = 16
            let available = geo.size.width - spacing * CGFloat(perRow - 1)
            let size = min(104, max(70, available / CGFloat(perRow)))
            let rows = chunk(unplacedItems, into: perRow)

            VStack(spacing: 16) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: spacing) {
                        ForEach(Array(row.enumerated()), id: \.element.id) { idx, item in
                            itemView(item, size: size)
                                .offset(y: idx % 2 == 0 ? -7 : 7)  // playful, not a straight line
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unplacedItems)
        }
        .frame(height: 230)
    }

    private func chunk(_ items: [SortItem], into n: Int) -> [[SortItem]] {
        stride(from: 0, to: items.count, by: n).map {
            Array(items[$0..<min($0 + n, items.count)])
        }
    }

    private func itemView(_ item: SortItem, size: CGFloat) -> some View {
        let isDragging = (draggingID == item.id)

        return itemArt(item, size: size)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.28), radius: isDragging ? 9 : 3, y: 2)
            .scaleEffect(isDragging ? 1.18 : 1.0)
            .overlay(alignment: .top) {
                if isDragging {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(0.75)))
                        .fixedSize()
                        .offset(y: -size * 0.75)
                        .transition(.opacity)
                }
            }
            .offset(offsets[item.id] ?? .zero)
            .zIndex(isDragging ? 1 : 0)
            .transition(.scale.combined(with: .opacity))
            .gesture(dragGesture(for: item))
            .accessibilityLabel(item.name)
    }

    // MARK: Drag handling

    private func dragGesture(for item: SortItem) -> some Gesture {
        DragGesture(coordinateSpace: .named(spaceName))
            .onChanged { value in
                // Speak the name once, the moment this item becomes the dragged one.
                if draggingID != item.id {
                    SpeechManager.shared.speak(item.name)
                }
                draggingID = item.id
                offsets[item.id] = value.translation
            }
            .onEnded { value in
                handleDrop(item, at: value.location)
            }
    }

    private func handleDrop(_ item: SortItem, at point: CGPoint) {
        draggingID = nil

        if let zoneID = zone(at: point), zoneID == item.targetZoneID {
            placeCorrect(item)
        } else {
            ToneManager.shared.play(frequency: 196.0)
            bonkPulse += 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                offsets[item.id] = .zero
            }
        }
    }

    /// Toddlers are imprecise, so each zone's hit area is inflated. Because inflated
    /// rects can overlap (and `zoneFrames` has no stable iteration order), we collect
    /// every zone whose padded rect contains the point and break ties by the nearest
    /// center — so a near-boundary drop resolves deterministically, not at random.
    private func zone(at point: CGPoint) -> String? {
        let candidates = level.zones.compactMap { z -> (id: String, dist: CGFloat)? in
            guard let rect = zoneFrames[z.id],
                  rect.insetBy(dx: -24, dy: -24).contains(point) else { return nil }
            let dx = point.x - rect.midX, dy = point.y - rect.midY
            return (z.id, dx * dx + dy * dy)
        }
        return candidates.min { $0.dist < $1.dist }?.id
    }

    private func placeCorrect(_ item: SortItem) {
        // Happy ascending chime — now one buffer, so both notes play fully.
        ToneManager.shared.playSequence([523.25, 783.99])
        successPulse += 1

        // Themed celebration at the zone: a particle burst + a little zone bounce.
        if let rect = zoneFrames[item.targetZoneID],
           let zone = level.zones.first(where: { $0.id == item.targetZoneID }) {
            burstCounter += 1
            let thisID = burstCounter
            burst = ZoneBurst(id: thisID, effect: zone.effect,
                              center: CGPoint(x: rect.midX, y: rect.midY))
            bouncingZone = zone.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if bouncingZone == zone.id { bouncingZone = nil }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if burst?.id == thisID { burst = nil }
            }
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            _ = placed.insert(item.id)
        }

        if placed.count == chosenItems.count {
            timerActive = false   // stop the clock the instant the last item lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                celebrate()
            }
        }
    }

    private func celebrate() {
        guard !failed else { return }
        timerActive = false
        // Full arpeggio in a single buffer — no clipping.
        ToneManager.shared.playSequence([523.25, 659.25, 783.99, 1046.50])
        let e = timed ? currentElapsed() : 0
        elapsed = e
        let s = timed ? GameView.stars(for: e) : 0
        let t: Double? = timed ? e : nil
        earnedStars = s
        finishTime = t
        onComplete(s, t)
        successPulse += 1
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            celebrating = true
        }
    }

    private func timeUp() {
        guard !celebrating else { return }
        // Gentle descending "aww" — never harsh for little ones.
        ToneManager.shared.playSequence([329.63, 261.63])
        bonkPulse += 1
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            failed = true
        }
    }

    private func restart() {
        burst = nil
        earnedStars = 0
        finishTime = nil
        elapsed = 0
        starPop = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            failed = false
            celebrating = false
            placed.removeAll()
            offsets.removeAll()
            draggingID = nil
            chosenItems = GameView.pick(from: level.items, zones: level.zones, max: 6)
        }
        if timed { startTimer() }
    }

    // MARK: Celebration

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()

            if !reduceMotion {
                ConfettiView()
            }

            VStack(spacing: 24) {
                Text("Yay! You did it! 🎉")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    .multilineTextAlignment(.center)

                if timed {
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(i < earnedStars ? .yellow : .white.opacity(0.35))
                                .shadow(color: i < earnedStars ? .orange.opacity(0.6) : .clear, radius: 10)
                                .scaleEffect(reduceMotion ? 1.0 : (starPop ? 1.0 : 0.2))
                                .animation(reduceMotion ? nil :
                                            .spring(response: 0.5, dampingFraction: 0.5)
                                            .delay(Double(i) * 0.12), value: starPop)
                        }
                    }
                    .onAppear { starPop = true }

                    if let t = finishTime {
                        Text(String(format: "Finished in %.1fs", t))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    }
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange.opacity(0.6), radius: 14)
                        .scaleEffect(reduceMotion ? 1.0 : (starPop ? 1.0 : 0.2))
                        .onAppear {
                            if reduceMotion {
                                starPop = true
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                                    starPop = true
                                }
                            }
                        }
                }

                Button(action: onNext) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 40))
                        Text("Next")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 38)
                    .padding(.vertical, 18)
                    .background(Capsule().fill(.green))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .accessibilityLabel("Next level")
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Out of time

    private var failOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Time's up! ⏰")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

                Image(systemName: "hourglass")
                    .font(.system(size: 78))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                Button(action: restart) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 38))
                        Text("Try Again")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.green))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .accessibilityLabel("Try again")

                Button(action: onExit) {
                    Text("Back to Menu")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white.opacity(0.22)))
                }
                .accessibilityLabel("Back to menu")
            }
            .padding(.horizontal, 24)
        }
    }
}
