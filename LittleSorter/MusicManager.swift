import AVFoundation

/// Loops one background-music track at a time. Tracks live in the app bundle as
/// mp3 files named "<level>_music.mp3" (farm_music, ocean_music, ...).
///
/// Uses the shared ambient/mix-with-others session (set by ToneManager), so the
/// music mixes under the tap tones + spoken names and is silenced by the
/// hardware mute switch — calm by default, parent stays in control.
final class MusicManager {
    static let shared = MusicManager()

    private var player: AVAudioPlayer?
    private var current: String?

    private init() {}

    /// Start (or keep) looping the named track. No-op if it's already playing.
    func play(_ name: String) {
        if current == name, player?.isPlaying == true { return }

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            return // track not found in bundle — fail silently
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1      // loop forever
            newPlayer.volume = 0.4            // sit under the tones/speech
            newPlayer.prepareToPlay()
            player?.stop()
            newPlayer.play()
            player = newPlayer
            current = name
        } catch {
            // ignore — music is non-essential
        }
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
    }
}
