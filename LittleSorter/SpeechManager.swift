import AVFoundation

/// Speaks item names aloud for pre-readers — fully on-device, no network,
/// no assets, no third-party SDKs.
///
/// It configures its OWN ambient, mix-with-others audio session in `init`, so
/// spoken names behave correctly even on the very first drag — before
/// `ToneManager` has ever been touched. Setting the category from both managers
/// is idempotent and safe. With `.ambient`, speech mixes with other audio and
/// is silenced by the hardware mute switch, matching the game's calm intent.
final class SpeechManager {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Speak a short label (an item name). Any in-progress utterance is cut so
    /// rapid drags don't queue a backlog of words. (Trade-off: very fast
    /// repeated drags can chop words; add a debounce if that bothers in testing.)
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42            // a touch slower than default, easier for toddlers
        utterance.pitchMultiplier = 1.1  // gently bright / friendly
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    /// Primes the voice once at launch. The first-ever utterance loads the voice
    /// data and causes a one-time hitch; doing it silently up front means the
    /// child's first real drag is smooth.
    func warmUp() {
        let u = AVSpeechUtterance(string: " ")
        u.volume = 0           // inaudible
        synthesizer.speak(u)
    }
}
