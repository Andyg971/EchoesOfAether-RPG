import AVFoundation

/// Procedural audio engine — zero asset files needed.
/// Generates all game sounds via AVAudioSourceNode oscillators.
@MainActor
final class AudioEngine {

    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var isRunning = false

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }

    /// Volume maître 0.0–1.0, contrôle le nœud mixer principal.
    var masterVolume: Float {
        get { mixer.volume }
        set { mixer.volume = max(0, min(1, newValue)) }
    }

    func start() {
        guard !isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isRunning = true
        } catch {
            #if DEBUG
            print("[AudioEngine] start failed: \(error)")
            #endif
        }
    }

    // MARK: - Game Sounds

    /// Short rising beep — dialogue advance, menu tap
    func playTap() {
        playTone(frequency: 880, duration: 0.06, volume: 0.15, type: .sine)
    }

    /// Two-note rising — dialogue choice selected
    func playSelect() {
        playTone(frequency: 660, duration: 0.05, volume: 0.18, type: .sine)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.playTone(frequency: 990, duration: 0.07, volume: 0.18, type: .sine)
        }
    }

    /// Thud — attack hit
    func playHit() {
        playTone(frequency: 120, duration: 0.12, volume: 0.35, type: .square, decay: true)
    }

    /// Dark rumble + high whine — black slash
    func playBlackSlash() {
        playTone(frequency: 55, duration: 0.25, volume: 0.40, type: .square, decay: true)
        playTone(frequency: 440, duration: 0.15, volume: 0.12, type: .sine, decay: true)
    }

    /// Damage taken — short noise burst
    func playDamage() {
        playNoise(duration: 0.08, volume: 0.25)
    }

    /// Ascending arpeggio — gold/loot gained
    func playGoldGain() {
        let notes: [Float] = [523, 659, 784] // C5 E5 G5
        for (i, freq) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) { [weak self] in
                self?.playTone(frequency: freq, duration: 0.10, volume: 0.18, type: .sine)
            }
        }
    }

    /// Purchase confirmation — satisfying ding
    func playPurchase() {
        playTone(frequency: 1047, duration: 0.08, volume: 0.20, type: .sine)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.playTone(frequency: 1319, duration: 0.12, volume: 0.15, type: .sine)
        }
    }

    /// Quest complete — triumphant three-note
    func playQuestComplete() {
        let notes: [Float] = [523, 659, 1047] // C5 E5 C6
        for (i, freq) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                self?.playTone(frequency: freq, duration: 0.18, volume: 0.22, type: .sine)
            }
        }
    }

    /// Enemy defeated — descending resolve
    func playVictory() {
        let notes: [Float] = [784, 988, 1175, 1568] // G5 B5 D6 G6
        for (i, freq) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                self?.playTone(frequency: freq, duration: 0.15, volume: 0.20, type: .sine)
            }
        }
    }

    /// Soft footstep tick
    func playStep() {
        playNoise(duration: 0.03, volume: 0.08)
    }

    /// Shop open — warm chime
    func playShopOpen() {
        playTone(frequency: 587, duration: 0.12, volume: 0.15, type: .sine)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.playTone(frequency: 784, duration: 0.15, volume: 0.12, type: .sine)
        }
    }

    // MARK: - Core Generators

    private enum WaveType { case sine, square }

    private func playTone(frequency: Float, duration: TimeInterval,
                          volume: Float, type: WaveType, decay: Bool = false) {
        guard isRunning else { return }

        let sampleRate = Float(engine.mainMixerNode.outputFormat(forBus: 0).sampleRate)
        let totalSamples = Int(sampleRate * Float(duration))
        var phase: Float = 0
        let phaseIncrement = frequency / sampleRate
        var sampleIndex = 0

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                guard sampleIndex < totalSamples else {
                    for buf in buffers {
                        (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = 0
                    }
                    continue
                }

                let envelope: Float = decay
                    ? max(0, 1.0 - Float(sampleIndex) / Float(totalSamples))
                    : (sampleIndex < 200 ? Float(sampleIndex) / 200.0 : 1.0)
                        * (sampleIndex > totalSamples - 200 ? Float(totalSamples - sampleIndex) / 200.0 : 1.0)

                let sample: Float
                switch type {
                case .sine:
                    sample = sinf(phase * 2.0 * .pi) * volume * envelope
                case .square:
                    sample = (sinf(phase * 2.0 * .pi) > 0 ? 1.0 : -1.0) * volume * envelope * 0.5
                }

                for buf in buffers {
                    (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = sample
                }

                phase += phaseIncrement
                if phase > 1.0 { phase -= 1.0 }
                sampleIndex += 1
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        let detachDelay = duration + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + detachDelay) { [weak self] in
            self?.engine.disconnectNodeOutput(sourceNode)
            self?.engine.detach(sourceNode)
        }
    }

    private func playNoise(duration: TimeInterval, volume: Float) {
        guard isRunning else { return }

        let sampleRate = Float(engine.mainMixerNode.outputFormat(forBus: 0).sampleRate)
        let totalSamples = Int(sampleRate * Float(duration))
        var sampleIndex = 0

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                guard sampleIndex < totalSamples else {
                    for buf in buffers {
                        (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = 0
                    }
                    continue
                }
                let envelope = max(0, 1.0 - Float(sampleIndex) / Float(totalSamples))
                let noise = Float.random(in: -1...1) * volume * envelope
                for buf in buffers {
                    (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = noise
                }
                sampleIndex += 1
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
            self?.engine.disconnectNodeOutput(sourceNode)
            self?.engine.detach(sourceNode)
        }
    }
}
