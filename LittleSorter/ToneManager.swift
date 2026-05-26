import AVFoundation

/// Generates short, soft sine tones at runtime — no audio files needed.
final class ToneManager {
    static let shared = ToneManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        engine.attach(player)
        // Connect with an explicit MONO format so it matches the mono buffers we
        // schedule (passing nil here adopts the stereo output and crashes on play).
        engine.connect(player, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        try? engine.start()
    }

    /// A single soft tone (used for the gentle "wrong drop" bonk).
    func play(frequency: Double) {
        playSequence([frequency])
    }

    /// Renders an ENTIRE sequence of notes into ONE buffer and plays it once.
    /// Because each note lives in the same buffer, chained chimes/arpeggios no
    /// longer interrupt each other — the success chime and celebration arpeggio
    /// play out fully instead of being chopped after ~0.12s.
    func playSequence(_ frequencies: [Double], noteDuration: Double = 0.22, gap: Double = 0.05) {
        guard !frequencies.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else { return }

        let perNote = noteDuration + gap
        let totalFrames = AVAudioFrameCount(sampleRate * perNote * Double(frequencies.count))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames),
              let channel = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = totalFrames

        // Silence the whole buffer first (gaps between notes stay quiet).
        for i in 0..<Int(totalFrames) { channel[i] = 0 }

        let noteFrames = Int(sampleRate * noteDuration)
        let stride = Int(sampleRate * perNote)

        for (n, freq) in frequencies.enumerated() {
            let start = n * stride
            for j in 0..<noteFrames {
                let idx = start + j
                if idx >= Int(totalFrames) { break }
                let t = Double(j) / sampleRate
                let envelope = exp(-4.0 * t)
                let fundamental = sin(2 * .pi * freq * t)
                let overtone = 0.3 * sin(2 * .pi * freq * 2 * t)
                channel[idx] = Float((fundamental + overtone) * envelope * 0.18)
            }
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// Schedules one tiny silent buffer at launch to spin up the render path,
    /// so the first real chime doesn't hitch.
    func warmUp() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else { return }
        buffer.frameLength = 1024
        if let ch = buffer.floatChannelData?[0] {
            for i in 0..<1024 { ch[i] = 0 }
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
