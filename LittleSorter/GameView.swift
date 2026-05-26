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
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isPad: Bool { hSizeClass == .regular }

    @State private var chosenItems: [SortItem]
    @State private var placed: Set<UUID> = []
    @State private var offsets: [UUID: CGSize] = [:]
    @State private var draggingID: UUID? = nil
    @State private var zoneFrames: [String: CGRect] = [:]
    @State private var celebrating = false
    @State private var starPop = false

    @State private var successPulse: Int = 0
    @State private var bonkPulse: Int = 0

    @State private var burst: ZoneBurst? = nil
    @State private var burstCounter: Int = 0
    @State private var bouncingZone: String? = nil
    @State private var warmingEffects = true

    @State private var elapsed: Double = 0
    @State private var startDate: Date? = nil
    @State private var timerActive = false
    @State private var failed = false
    @State private var earnedStars = 0
    @State private var finishTime: Double? = nil
    private let timeLimit: Double = 30
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private func currentElapsed() -> Double {
        guard let startDate else { return 0 }
        return min(timeLimit, Date().timeIntervalSince(startDate))
    }

    private func startTimer() {
        startDate = Date()
        elapsed = 0
        timerActive = true
    }

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
    private func trayArt(_ item: SortItem, size: CGFloat) -> some View {
        if let name = item.imageName, !name.isEmpty {
            Image(name).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: size * 0.9))
                .foregroundStyle(item.color)
        }
    }

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
        GeometryReader { geo in
            ZStack {
                if let bg = level.backgroundImage {
                    Image(bg).resizable().scaledToFill().ignoresSafeArea()
                } else {
                    level.background.ignoresSafeArea()
                }

                // iPhone keeps its original fixed layout; iPad uses a fill-based
                // layout where the item tray takes all remaining space (so items
                // can never overflow off the bottom).
                if isPad {
                    iPadContent(geo)
                } else {
                    iPhoneContent
                }

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
                        Circle()
                            .fill(.white.opacity(0.35))
                            .frame(width: 90, height: 90)
                            .position(b.center)
                            .id(b.id)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    } else {
                        DropEffectView(effect: b.effect)
                            .frame(width: isPad ? 380 : 300, height: isPad ? 380 : 300)
                            .position(b.center)
                            .id(b.id)
                            .allowsHitTesting(false)
                    }
                }

                if warmingEffects && !reduceMotion {
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
            .sensoryFeedback(.success, trigger: successPulse)
            .sensoryFeedback(.impact(weight: .light), trigger: bonkPulse)
        }
    }

    // MARK: Layouts

    private var iPhoneContent: some View {
        VStack(spacing: 0) {
            header
            if placed.isEmpty && !celebrating {
                instructionHint.padding(.top, 6).transition(.opacity)
            }
            if timed && !celebrating && !failed {
                timerPill.padding(.top, 6).transition(.opacity)
            }
            Spacer(minLength: 8)
            zonesRow(height: 175)
            Spacer(minLength: 8)
            itemsTray(fixedHeight: 230)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.3), value: placed.isEmpty)
    }

    private func iPadContent(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            header
            if placed.isEmpty && !celebrating {
                instructionHint.padding(.top, 8).transition(.opacity)
            }
            if timed && !celebrating && !failed {
                timerPill.padding(.top, 8).transition(.opacity)
            }
            Spacer().frame(height: geo.size.height * 0.05)
            zonesRow(height: geo.size.height * 0.26)
            Spacer().frame(height: geo.size.height * 0.03)
            // No fixed height — fills all remaining space, items sized to fit it.
            itemsTray(fixedHeight: nil)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 40)
        .animation(.easeInOut(duration: 0.3), value: placed.isEmpty)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: isPad ? 54 : 46))
                    .foregroundStyle(.white, .black.opacity(0.25))
            }
            .accessibilityLabel("Back to menu")

            Spacer()
        }
        .padding(.top, 8)
    }

    private var instructionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
            Text("Drag each one where it belongs")
                .font(.system(size: isPad ? 19 : 15, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isPad ? 20 : 16)
        .padding(.vertical, isPad ? 11 : 9)
        .background(Capsule().fill(.black.opacity(0.22)))
    }

    private var timerPill: some View {
        let left = max(0, timeLimit - elapsed)
        let low = left <= 10
        return HStack(spacing: 7) {
            Image(systemName: "stopwatch.fill")
                .font(.system(size: isPad ? 22 : 18, weight: .bold))
            Text("\(Int(ceil(left)))")
                .font(.system(size: isPad ? 26 : 22, weight: .heavy, design: .rounded).monospacedDigit())
            Text("s")
                .font(.system(size: isPad ? 17 : 15, weight: .bold, design: .rounded))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isPad ? 22 : 18)
        .padding(.vertical, isPad ? 10 : 8)
        .background(Capsule().fill(low ? Color.red.opacity(0.9) : Color.black.opacity(0.3)))
        .scaleEffect(low ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: low)
        .accessibilityLabel("\(Int(ceil(left))) seconds left")
    }

    // MARK: Drop zones

    private func zonesRow(height: CGFloat) -> some View {
        HStack(spacing: isPad ? 20 : 12) {
            ForEach(level.zones) { zone in
                zoneView(zone, height: height)
            }
        }
        .frame(height: height)
    }

    private func zoneView(_ zone: DropZone, height: CGFloat) -> some View {
        let itemsHere = chosenItems.filter { placed.contains($0.id) && $0.targetZoneID == zone.id }
        let artSize = height * 0.42
        let corner: CGFloat = isPad ? 32 : 26

        return VStack(spacing: isPad ? 10 : 6) {
            zoneArt(zone, size: artSize)

            Text(zone.label)
                .font(.system(size: isPad ? 22 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: isPad ? 6 : 4) {
                ForEach(itemsHere) { item in
                    trayArt(item, size: isPad ? 34 : 24)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(minHeight: isPad ? 42 : 30)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .scaleEffect(bouncingZone == zone.id && !reduceMotion ? 1.06 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.45), value: bouncingZone)
        .background(
            RoundedRectangle(cornerRadius: corner)
                .fill(zone.color.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner)
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

    // MARK: Items area
    //
    // Sizes items to fit BOTH the available width and the available height.
    // When `fixedHeight` is nil (iPad) the tray fills all the remaining space,
    // so the items can never overflow off the bottom — every item is visible.

    private func itemsTray(fixedHeight: CGFloat?) -> some View {
        GeometryReader { g in
            let perRow = 3
            let spacing: CGFloat = isPad ? 24 : 16
            let totalRows = max(1, Int(ceil(Double(chosenItems.count) / Double(perRow))))
            let maxByW = (g.size.width - spacing * CGFloat(perRow - 1)) / CGFloat(perRow)
            let maxByH = (g.size.height - spacing * CGFloat(totalRows - 1)) / CGFloat(totalRows)
            let cap: CGFloat = isPad ? 150 : 104
            let size = max(56, min(cap, min(maxByW, maxByH)))
            let rows = chunk(unplacedItems, into: perRow)

            return VStack(spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: spacing) {
                        ForEach(Array(row.enumerated()), id: \.element.id) { idx, item in
                            itemView(item, size: size)
                                .offset(y: idx % 2 == 0 ? -6 : 6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unplacedItems)
        }
        .frame(height: fixedHeight)
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
                        .font(.system(size: isPad ? 20 : 16, weight: .bold, design: .rounded))
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
        ToneManager.shared.playSequence([523.25, 783.99])
        successPulse += 1

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
            timerActive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                celebrate()
            }
        }
    }

    private func celebrate() {
        guard !failed else { return }
        timerActive = false
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

            VStack(spacing: isPad ? 28 : 24) {
                Text("Yay! You did it! 🎉")
                    .font(.system(size: isPad ? 42 : 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    .multilineTextAlignment(.center)

                if timed {
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: isPad ? 72 : 60))
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
                            .font(.system(size: isPad ? 24 : 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    }
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: isPad ? 116 : 96))
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
                            .font(.system(size: isPad ? 46 : 40))
                        Text("Next")
                            .font(.system(size: isPad ? 40 : 36, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, isPad ? 46 : 38)
                    .padding(.vertical, isPad ? 20 : 18)
                    .background(Capsule().fill(.green))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .accessibilityLabel("Next level")

                Button(action: onExit) {
                    Text("Back to Menu")
                        .font(.system(size: isPad ? 22 : 20, weight: .semibold, design: .rounded))
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

    // MARK: Out of time

    private var failOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Time's up! ⏰")
                    .font(.system(size: isPad ? 42 : 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

                Image(systemName: "hourglass")
                    .font(.system(size: isPad ? 96 : 78))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                Button(action: restart) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: isPad ? 44 : 38))
                        Text("Try Again")
                            .font(.system(size: isPad ? 36 : 32, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, isPad ? 40 : 34)
                    .padding(.vertical, isPad ? 18 : 16)
                    .background(Capsule().fill(.green))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .accessibilityLabel("Try again")

                Button(action: onExit) {
                    Text("Back to Menu")
                        .font(.system(size: isPad ? 22 : 20, weight: .semibold, design: .rounded))
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
