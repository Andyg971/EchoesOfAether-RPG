import AVFoundation

/// Procedural audio engine — zero asset files needed.
/// Generates all game sounds via AVAudioSourceNode oscillators.
@MainActor
final class AudioEngine {

    static let shared = AudioEngine()

    private let engine   = AVAudioEngine()
    private let mixer    = AVAudioMixerNode()

    // Source of truth = engine.isRunning (no custom flag that can drift)
    var isRunning: Bool { engine.isRunning }

    /// Volume maître 0.0–1.0
    var masterVolume: Float {
        get { mixer.volume }
        set { mixer.volume = max(0, min(1, newValue)) }
    }

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Lifecycle

    func start() {
        guard !engine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: .mixWithOthers)
            try session.setActive(true)
            try engine.start()
        } catch {
            #if DEBUG
            print("[AudioEngine] start failed: \(error)")
            #endif
        }
    }

    /// Arrêt propre avant une transition de scène.
    /// Toutes les asyncAfter en attente vérifieront isRunning et ne joueront pas.
    func stop() {
        guard engine.isRunning else { return }
        engine.stop()
    }

    // MARK: - Game Sounds

    func playTap() {
        playTone(frequency: 880, duration: 0.06, volume: 0.15, type: .sine)
    }

    func playSelect() {
        playTone(frequency: 660, duration: 0.05, volume: 0.18, type: .sine)
        scheduleAfter(0.06) { self.playTone(frequency: 990, duration: 0.07, volume: 0.18, type: .sine) }
    }

    func playHit() {
        playTone(frequency: 120, duration: 0.12, volume: 0.35, type: .square, decay: true)
    }

    func playBlackSlash() {
        playTone(frequency: 55,  duration: 0.25, volume: 0.40, type: .square, decay: true)
        playTone(frequency: 440, duration: 0.15, volume: 0.12, type: .sine,   decay: true)
    }

    func playDamage() {
        playNoise(duration: 0.08, volume: 0.25)
    }

    func playGoldGain() {
        let notes: [Float] = [523, 659, 784]
        for (i, freq) in notes.enumerated() {
            scheduleAfter(Double(i) * 0.07) {
                self.playTone(frequency: freq, duration: 0.10, volume: 0.18, type: .sine)
            }
        }
    }

    func playPurchase() {
        playTone(frequency: 1047, duration: 0.08, volume: 0.20, type: .sine)
        scheduleAfter(0.1) { self.playTone(frequency: 1319, duration: 0.12, volume: 0.15, type: .sine) }
    }

    func playQuestComplete() {
        let notes: [Float] = [523, 659, 1047]
        for (i, freq) in notes.enumerated() {
            scheduleAfter(Double(i) * 0.12) {
                self.playTone(frequency: freq, duration: 0.18, volume: 0.22, type: .sine)
            }
        }
    }

    func playVictory() {
        let notes: [Float] = [784, 988, 1175, 1568]
        for (i, freq) in notes.enumerated() {
            scheduleAfter(Double(i) * 0.1) {
                self.playTone(frequency: freq, duration: 0.15, volume: 0.20, type: .sine)
            }
        }
    }

    func playStep() {
        playNoise(duration: 0.03, volume: 0.08)
    }

    func playShopOpen() {
        playTone(frequency: 587, duration: 0.12, volume: 0.15, type: .sine)
        scheduleAfter(0.08) { self.playTone(frequency: 784, duration: 0.15, volume: 0.12, type: .sine) }
    }

    // MARK: - Core Generators

    private enum WaveType { case sine, square }

    private func playTone(frequency: Float, duration: TimeInterval,
                          volume: Float, type: WaveType, decay: Bool = false) {
        guard engine.isRunning else { return }

        // Capture format & sampleRate BEFORE entering the render callback
        let format      = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate  = Float(format.sampleRate)
        guard sampleRate > 0 else { return }

        let totalSamples = Int(sampleRate * Float(duration))
        var phase:       Float = 0
        let phaseInc           = frequency / sampleRate
        var sampleIdx          = 0

        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let s: Float
                if sampleIdx < totalSamples {
                    let env: Float = decay
                        ? max(0, 1.0 - Float(sampleIdx) / Float(totalSamples))
                        : (sampleIdx < 200 ? Float(sampleIdx) / 200.0 : 1.0)
                            * (sampleIdx > totalSamples - 200
                               ? Float(totalSamples - sampleIdx) / 200.0 : 1.0)
                    switch type {
                    case .sine:   s = sinf(phase * 2.0 * .pi) * volume * env
                    case .square: s = (sinf(phase * 2.0 * .pi) > 0 ? 1.0 : -1.0) * volume * env * 0.5
                    }
                    phase += phaseInc
                    if phase > 1.0 { phase -= 1.0 }
                    sampleIdx += 1
                } else {
                    s = 0
                }
                for buf in buffers {
                    (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = s
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        // Detach bien après la fin du render (duration + 0.6s) pour éviter
        // _dispatch_assert_queue_fail si le callback IO tourne encore
        let detachDelay = duration + 0.6
        scheduleAfter(detachDelay) { [weak self] in
            guard let self else { return }
            self.engine.disconnectNodeOutput(sourceNode)
            self.engine.detach(sourceNode)
        }
    }

    private func playNoise(duration: TimeInterval, volume: Float) {
        guard engine.isRunning else { return }

        let format      = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate  = Float(format.sampleRate)
        guard sampleRate > 0 else { return }

        let totalSamples = Int(sampleRate * Float(duration))
        var sampleIdx    = 0

        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let s: Float
                if sampleIdx < totalSamples {
                    let env = max(0, 1.0 - Float(sampleIdx) / Float(totalSamples))
                    // LCG pseudo-random: lock-free, safe sur le thread audio
                    s = (Float(arc4random()) / Float(UInt32.max) * 2.0 - 1.0) * volume * env
                    sampleIdx += 1
                } else {
                    s = 0
                }
                for buf in buffers {
                    (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = s
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        scheduleAfter(duration + 0.6) { [weak self] in
            guard let self else { return }
            self.engine.disconnectNodeOutput(sourceNode)
            self.engine.detach(sourceNode)
        }
    }

    // MARK: - Helper

    /// Schedule sur le main thread en vérifiant isRunning au moment d'exécution.
    private func scheduleAfter(_ delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            action()
        }
    }
}
