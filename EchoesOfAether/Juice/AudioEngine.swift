import AVFoundation

/// AudioEngine — synthèse procédurale temps réel.
///
/// Aucun asset audio : chaque SFX et le pad d'ambiance sont synthétisés une
/// fois au démarrage dans des `AVAudioPCMBuffer`, puis joués via des
/// `AVAudioPlayerNode`. On évite délibérément `AVAudioSourceNode` (render
/// callback sur l'IOThread) qui crashait sur simulateur iOS 26
/// (`_dispatch_assert_queue_fail`). Ici tout est pré-rendu : pas de callback
/// audio, graphe stable.
@MainActor
final class AudioEngine {

    static let shared = AudioEngine()

    // MARK: - Graphe

    private let engine = AVAudioEngine()
    private let sfxMixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private var sfxPlayers: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private let musicPlayer = AVAudioPlayerNode()

    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate, channels: 2)!

    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?

    private var started = false
    private let sfxVoiceCount = 8

    // MARK: - Volumes

    /// Volume des effets (0...1). Câblé sur le sous-mixeur SFX.
    var masterVolume: Float = 1.0 {
        didSet { sfxMixer.outputVolume = clamp(masterVolume) }
    }

    /// Volume de la musique d'ambiance (0...1).
    var musicVolume: Float = 0.55 {
        didSet { musicMixer.outputVolume = clamp(musicVolume) }
    }

    var isRunning: Bool { engine.isRunning }

    private init() {}

    // MARK: - Sons

    enum Sound: CaseIterable {
        case tap, select, hit, blackSlash, damage
        case gold, purchase, quest, victory, step, shopOpen
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else {
            if !engine.isRunning { try? engine.start() }
            return
        }
        started = true

        configureSession()
        buildGraph()
        renderAllBuffers()

        engine.prepare()
        do {
            try engine.start()
        } catch {
            #if DEBUG
            print("[AudioEngine] start failed: \(error)")
            #endif
            return
        }
        startMusic()
    }

    func stop() {
        musicPlayer.stop()
        sfxPlayers.forEach { $0.stop() }
        engine.stop()
    }

    // MARK: - Game Sounds

    func playTap()          { play(.tap) }
    func playSelect()       { play(.select) }
    func playHit()          { play(.hit) }
    func playBlackSlash()   { play(.blackSlash) }
    func playDamage()       { play(.damage) }
    func playGoldGain()     { play(.gold) }
    func playPurchase()     { play(.purchase) }
    func playQuestComplete(){ play(.quest) }
    func playVictory()      { play(.victory) }
    func playStep()         { play(.step) }
    func playShopOpen()     { play(.shopOpen) }

    func playMusic()  { startMusic() }
    func stopMusic()  { musicPlayer.stop() }

    // MARK: - Playback

    private func play(_ sound: Sound) {
        guard engine.isRunning, let buffer = buffers[sound], !sfxPlayers.isEmpty else { return }
        // Pool round-robin : .interrupts donne une polyphonie = sfxVoiceCount.
        let player = sfxPlayers[sfxIndex]
        sfxIndex = (sfxIndex + 1) % sfxPlayers.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func startMusic() {
        guard engine.isRunning, let loop = musicBuffer else { return }
        if musicPlayer.isPlaying { return }
        musicPlayer.scheduleBuffer(loop, at: nil, options: .loops, completionHandler: nil)
        musicPlayer.play()
    }

    // MARK: - Setup

    private func configureSession() {
        #if !targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        // .ambient : respecte le bouton silence, mixe avec les autres apps.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    private func buildGraph() {
        engine.attach(sfxMixer)
        engine.attach(musicMixer)

        for _ in 0..<sfxVoiceCount {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: sfxMixer, format: format)
            sfxPlayers.append(p)
        }
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: format)

        engine.attach(musicPlayer)
        engine.connect(musicPlayer, to: musicMixer, format: format)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: format)

        sfxMixer.outputVolume = clamp(masterVolume)
        musicMixer.outputVolume = clamp(musicVolume)
    }

    // MARK: - Synthèse

    private func renderAllBuffers() {
        for sound in Sound.allCases {
            buffers[sound] = renderSFX(sound)
        }
        musicBuffer = renderMusicLoop()
    }

    /// Crée un buffer stéréo et le remplit via une fonction d'échantillon
    /// `sample(t)` (t en secondes), identique sur les 2 canaux.
    private func makeBuffer(duration: Double, sample: (Double) -> Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let chans = Int(format.channelCount)
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            let v = sample(t)
            for ch in 0..<chans {
                buffer.floatChannelData![ch][frame] = v
            }
        }
        return buffer
    }

    private func renderSFX(_ sound: Sound) -> AVAudioPCMBuffer {
        switch sound {
        case .tap:
            return makeBuffer(duration: 0.06) { t in
                let e: Float = env(t, 0.06, attack: 0.002, release: 0.05)
                return e * 0.22 * sine(t, 880)
            }
        case .select:
            return makeBuffer(duration: 0.12) { t in
                let f: Double = 640 + 520 * min(1, t / 0.1)   // glissando montant
                let e: Float = env(t, 0.12, attack: 0.004, release: 0.09)
                return e * 0.22 * sine(t, f)
            }
        case .hit:
            return makeBuffer(duration: 0.14) { t in
                let body: Float = sine(t, 180) * 0.5
                let crack: Float = noise() * expF(-t * 60)
                let e: Float = env(t, 0.14, attack: 0.001, release: 0.12)
                return e * 0.28 * (body + crack)
            }
        case .blackSlash:
            return makeBuffer(duration: 0.34) { t in
                let f: Double = 520 * exp(-t * 5) + 70          // sweep descendant
                let tone: Float = sine(t, f) * 0.6
                let air: Float = noise() * expF(-t * 9) * 0.5
                let e: Float = env(t, 0.34, attack: 0.002, release: 0.28)
                return e * 0.30 * (tone + air)
            }
        case .damage:
            return makeBuffer(duration: 0.16) { t in
                let e: Float = env(t, 0.16, attack: 0.001, release: 0.13)
                return e * 0.26 * square(t, 130)
            }
        case .gold:
            return makeBuffer(duration: 0.22) { t in
                let p1: Float = t < 0.09 ? sine(t, 1175) : 0          // ping aigu
                let p2: Float = t >= 0.08 ? sine(t - 0.08, 1568) : 0  // ping plus haut
                let e: Float = env(t, 0.22, attack: 0.002, release: 0.16)
                return e * 0.20 * (p1 + p2)
            }
        case .purchase:
            return makeBuffer(duration: 0.26) { t in
                let f: Double = chordStep(t, [523, 659, 784], step: 0.07)  // do-mi-sol
                let e: Float = env(t, 0.26, attack: 0.003, release: 0.18)
                return e * 0.20 * sine(t, f)
            }
        case .quest:
            return makeBuffer(duration: 0.5) { t in
                let f: Double = chordStep(t, [659, 784, 988, 1319], step: 0.1) // arpège
                let e: Float = env(t, 0.5, attack: 0.004, release: 0.3)
                return e * 0.20 * sine(t, f)
            }
        case .victory:
            return makeBuffer(duration: 0.7) { t in
                // accord majeur soutenu (do-mi-sol)
                let chord: Float = sine(t, 523) + sine(t, 659) + sine(t, 784)
                let e: Float = env(t, 0.7, attack: 0.01, release: 0.45)
                return e * 0.12 * chord
            }
        case .step:
            return makeBuffer(duration: 0.05) { t in
                let n: Float = noise() * expF(-t * 80)
                let e: Float = env(t, 0.05, attack: 0.001, release: 0.045)
                return e * 0.10 * n
            }
        case .shopOpen:
            return makeBuffer(duration: 0.3) { t in
                let f: Double = chordStep(t, [784, 1047], step: 0.1)
                let e: Float = env(t, 0.3, attack: 0.006, release: 0.22)
                return e * 0.18 * sine(t, f)
            }
        }
    }

    /// Pad d'ambiance bouclable : drone mineur + LFO lent. ~8s pour une boucle
    /// douce sans coupure perceptible (amplitude basse pour rester en fond).
    private func renderMusicLoop() -> AVAudioPCMBuffer {
        let duration = 8.0
        return makeBuffer(duration: duration) { t in
            let lfo: Float = Float(0.5 + 0.5 * sin(2 * .pi * t / duration))  // 1 cycle / boucle
            let root: Float = sine(t, 110) * 0.5                              // La2
            let fifth: Float = sine(t, 164.81) * 0.35                         // Mi3
            let high: Float = sine(t, 220) * 0.18 * lfo                       // La3 ondulant
            let shimmer: Float = sine(t, 329.63) * 0.10 * (1 - lfo)           // Mi4
            return 0.16 * (root + fifth + high + shimmer)
        }
    }

    // MARK: - Helpers de synthèse

    private func clamp(_ v: Float) -> Float { max(0, min(1, v)) }

    private func sine(_ t: Double, _ freq: Double) -> Float {
        Float(sin(2 * .pi * freq * t))
    }

    private func square(_ t: Double, _ freq: Double) -> Float {
        sin(2 * .pi * freq * t) >= 0 ? 1 : -1
    }

    private func noise() -> Float { Float.random(in: -1...1) }

    private func expF(_ x: Double) -> Float { Float(exp(x)) }

    /// Enveloppe attack/release linéaire (anti-clic), 1 au sustain.
    private func env(_ t: Double, _ dur: Double, attack: Double, release: Double) -> Float {
        if t < attack { return Float(t / attack) }
        if t > dur - release { return Float(max(0, (dur - t) / release)) }
        return 1
    }

    /// Renvoie la fréquence de l'étape courante d'une séquence (arpège/accord
    /// égrené) : change toutes les `step` secondes.
    private func chordStep(_ t: Double, _ freqs: [Double], step: Double) -> Double {
        let idx = min(freqs.count - 1, Int(t / step))
        return freqs[idx]
    }
}
