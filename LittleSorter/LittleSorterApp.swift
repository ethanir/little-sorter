import SwiftUI

@main
struct LittleSorterApp: App {
    @StateObject private var store = Store()

    init() {
        #if DEBUG
        Level.validateContent()   // crash early in dev if level content is malformed
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .statusBarHidden(true)
        }
    }
}

/// Screen state machine: level picker <-> gameplay. Tracks completion, best star
/// rating, best time, and the Timed-mode toggle — all persisted via @AppStorage.
struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var current: Level? = nil

    @AppStorage("completedLevels") private var completedRaw = ""
    @AppStorage("timedMode") private var timedMode = false
    @AppStorage("bestStars") private var starsRaw = ""   // "id:stars,..."
    @AppStorage("bestTimes") private var timesRaw = ""   // "id:seconds,..."

    private var completedIDs: Set<Int> {
        Set(completedRaw.split(separator: ",").compactMap { Int($0) })
    }

    private var starsByLevel: [Int: Int] {
        var d: [Int: Int] = [:]
        for pair in starsRaw.split(separator: ",") {
            let kv = pair.split(separator: ":")
            if kv.count == 2, let k = Int(kv[0]), let v = Int(kv[1]) { d[k] = v }
        }
        return d
    }

    private var timesByLevel: [Int: Double] {
        var d: [Int: Double] = [:]
        for pair in timesRaw.split(separator: ",") {
            let kv = pair.split(separator: ":")
            if kv.count == 2, let k = Int(kv[0]), let v = Double(kv[1]) { d[k] = v }
        }
        return d
    }

    var body: some View {
        ZStack {
            if let level = current {
                GameView(
                    level: level,
                    timed: timedMode,
                    onExit: { current = nil },
                    onNext: { advance(from: level) },
                    onComplete: { stars, time in record(level.id, stars: stars, time: time) }
                )
                .id(level.id)
                .transition(reduceMotion ? .opacity
                            : .move(edge: .trailing).combined(with: .opacity))
            } else {
                LevelPickerView(
                    onPlay: { current = $0 },
                    completed: completedIDs,
                    stars: starsByLevel,
                    times: timesByLevel,
                    timedMode: $timedMode
                )
                .transition(reduceMotion ? .opacity
                            : .move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35),
                   value: current)
        .onAppear {
            MusicManager.shared.play("menu_music")
            ToneManager.shared.warmUp()
            SpeechManager.shared.warmUp()
        }
        .onChange(of: current) { _, newValue in
            if let level = newValue {
                MusicManager.shared.play("\(level.title.lowercased())_music")
            } else {
                MusicManager.shared.play("menu_music")
            }
        }
    }

    /// Marks a level complete and keeps the BEST (max) stars and BEST (min) time.
    /// Untimed completions pass stars 0 / time nil, so they never downgrade a record.
    private func record(_ id: Int, stars: Int, time: Double?) {
        var set = completedIDs
        set.insert(id)
        completedRaw = set.sorted().map(String.init).joined(separator: ",")

        if stars > 0 {
            var s = starsByLevel
            s[id] = max(s[id] ?? 0, stars)
            starsRaw = s.sorted { $0.key < $1.key }
                .map { "\($0.key):\($0.value)" }.joined(separator: ",")
        }
        if let t = time {
            var tm = timesByLevel
            tm[id] = min(tm[id] ?? .greatestFiniteMagnitude, t)
            timesRaw = tm.sorted { $0.key < $1.key }
                .map { "\($0.key):\(String(format: "%.2f", $0.value))" }.joined(separator: ",")
        }
    }

    private func advance(from level: Level) {
        // Go to the next playable level, or back to the menu. We deliberately do NOT
        // auto-open the purchase flow here — unlocking is reached only by an adult
        // via the Grown-Ups button + parental gate.
        if let next = Self.nextPlayable(after: level, unlocked: store.isUnlocked) {
            current = next
        } else {
            current = nil
        }
    }

    private static func nextPlayable(after level: Level, unlocked: Bool) -> Level? {
        guard let idx = Level.all.firstIndex(of: level), idx + 1 < Level.all.count else {
            return nil
        }
        for next in Level.all[(idx + 1)...] where next.isFree || unlocked {
            return next
        }
        return nil
    }
}
