import AVFoundation

/// Procedural audio engine — zero asset files.
/// Génère sons via AVAudioSourceNode. Désactivé silencieusement
/// si l'environnement ne supporte pas (simulator iOS 26, audio session occupée).
@MainActor
final class AudioEngine {

    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let mixer  = AVAudioMixerNode()
    private var isEnabled = false   // false tant que start() n'a pas réussi
    private var startFailed = false // true si start() a échoué, ne pas retenter

    var isRunning: Bool { isEnabled && engine.isRunning }

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
        guard !startFailed, !engine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            try engine.start()
            isEnabled = true
            #if DEBUG
            print("[AudioEngine] started OK")
            #endif
        } catch {
            startFailed = true
            isEnabled = false
            #if DEBUG
            print("[AudioEngine] start failed (audio disabled): \(error)")
            #endif
        }
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.stop()
        isEnabled = false
    }

    // MARK: - Game Sounds (no-op si !isRunning)

    func playTap()          { playTone(880, 0.06, 0.15, .sine) }
    func playSelect()       {
        playTone(660, 0.05, 0.18, .sine)
        after(0.06) { self.playTone(990, 0.07, 0.18, .sine) }
    }
    func playHit()          { playTone(120, 0.12, 0.35, .square, decay: true) }
    func playBlackSlash()   {
        playTone(55,  0.25, 0.40, .square, decay: true)
        playTone(440, 0.15, 0.12, .sine,   decay: true)
    }
    func playDamage()       { playNoise(0.08, 0.25) }

    func playGoldGain() {
        let notes: [Float] = [523, 659, 784]
        for (i, f) in notes.enumerated() {
            after(Double(i) * 0.07) { self.playTone(f, 0.10, 0.18, .sine) }
        }
    }

    func playPurchase() {
        playTone(1047, 0.08, 0.20, .sine)
        after(0.1) { self.playTone(1319, 0.12, 0.15, .sine) }
    }

    func playQuestComplete() {
        let notes: [Float] = [523, 659, 1047]
        for (i, f) in notes.enumerated() {
            after(Double(i) * 0.12) { self.playTone(f, 0.18, 0.22, .sine) }
        }
    }

    func playVictory() {
        let notes: [Float] = [784, 988, 1175, 1568]
        for (i, f) in notes.enumerated() {
            after(Double(i) * 0.1) { self.playTone(f, 0.15, 0.20, .sine) }
        }
    }

    func playStep() { playNoise(0.03, 0.08) }

    func playShopOpen() {
        playTone(587, 0.12, 0.15, .sine)
        after(0.08) { self.playTone(784, 0.15, 0.12, .sine) }
    }

    // MARK: - Core Generators

    private enum WaveType { case sine, square }

    private func playTone(_ frequency: Float, _ duration: TimeInterval,
                          _ volume: Float, _ type: WaveType, decay: Bool = false) {
        guard isRunning else { return }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        guard sampleRate > 0 else { return }

        let totalSamples = Int(sampleRate * Float(duration))
        var phase: Float = 0
        let phaseInc = frequency / sampleRate
        var idx = 0

        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            for frame in 0..<Int(frameCount) {
                let s: Float
                if idx < totalSamples {
                    let env: Float = decay
                        ? max(0, 1.0 - Float(idx) / Float(totalSamples))
                        : (idx < 200 ? Float(idx) / 200.0 : 1.0)
                            * (idx > totalSamples - 200
                               ? Float(totalSamples - idx) / 200.0 : 1.0)
                    switch type {
                    case .sine:   s = sinf(phase * 2.0 * .pi) * volume * env
                    case .square: s = (sinf(phase * 2.0 * .pi) > 0 ? 1.0 : -1.0) * volume * env * 0.5
                    }
                    phase += phaseInc
                    if phase > 1.0 { phase -= 1.0 }
                    idx += 1
                } else {
                    s = 0
                }
                for buf in buffers {
                    (buf.mData?.assumingMemoryBound(to: Float.self))?.advanced(by: frame).pointee = s
                }
            }
            return noErr
        }

        // attach/connect peuvent throw — protéger
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        // Detach très longtemps après pour garantir IO thread terminé
        after(duration + 1.0) { [weak self] in
            guard let self else { return }
            // Vérifier engine toujours vivant
            if self.engine.attachedNodes.contains(sourceNode) {
                self.engine.disconnectNodeOutput(sourceNode)
                self.engine.detach(sourceNode)
            }
        }
    }

    private func playNoise(_ duration: TimeInterval, _ volume: Float) {
        guard isRunning else { return }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        guard sampleRate > 0 else { return }

        let totalSamples = Int(sampleRate * Float(duration))
        var idx = 0

        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            for frame in 0..<Int(frameCount) {
                let s: Float
                if idx < totalSamples {
                    let env = max(0, 1.0 - Float(idx) / Float(totalSamples))
                    s = (Float(arc4random()) / Float(UInt32.max) * 2.0 - 1.0) * volume * env
                    idx += 1
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

        after(duration + 1.0) { [weak self] in
            guard let self else { return }
            if self.engine.attachedNodes.contains(sourceNode) {
                self.engine.disconnectNodeOutput(sourceNode)
                self.engine.detach(sourceNode)
            }
        }
    }

    // MARK: - Helper

    private func after(_ delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            action()
        }
    }
}
