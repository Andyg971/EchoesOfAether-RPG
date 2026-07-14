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

    // Deux nodes musique pour permettre un cross-fade propre entre ambiances
    // (l'entrant monte pendant que le sortant descend). Le mixeur musique
    // garde le volume utilisateur ; le fondu se fait sur `.volume` des nodes.
    private let musicPlayerA = AVAudioPlayerNode()
    private let musicPlayerB = AVAudioPlayerNode()
    private var musicUsingA = true
    private var musicFadeTask: Task<Void, Never>?

    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate, channels: 2)!

    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var musicBuffers: [MusicMood: AVAudioPCMBuffer] = [:]
    private(set) var currentMood: MusicMood = .calm

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

        /// SFX CC0 embarqué (Juhani Junkala) ; nil = synthèse.
        var fileName: String? {
            switch self {
            case .tap:        return "sfx_tap"
            case .select:     return "sfx_select"
            case .hit:        return "sfx_hit"
            case .blackSlash: return "sfx_blackslash"
            case .damage:     return "sfx_damage"
            case .gold:       return "sfx_gold"
            case .purchase:   return "sfx_purchase"
            case .quest:      return "sfx_quest"
            case .victory:    return "sfx_victory"
            case .step:       return "sfx_step"
            case .shopOpen:   return "sfx_shopopen"
            }
        }
    }

    /// Ambiance musicale par zone. Chaque cas a sa propre boucle pré-rendue
    /// (drone + harmoniques + battement). Aucune dépendance audio externe.
    enum MusicMood: CaseIterable {
        case calm        // village / éveil
        case tense       // forêt corrompue
        case sacred      // sanctuaire
        case ruins       // ruines / Acte II / Kael déchu
        case voidThreshold // Acte III, le Seuil
        case mines       // galeries de Cendreval
        case inn         // intérieurs (auberge, échoppes)
        case combat      // combat standard
        case boss        // combat de boss
        case title       // écran-titre
        case finale      // vraie fin / crédits — aube nouvelle

        /// Ambiance associée à une phase de jeu.
        static func forPhase(_ phase: GamePhase) -> MusicMood {
            switch phase {
            case .wake, .village, .complete: return .calm
            case .forest:                    return .tense
            case .shrine:                    return .sacred
            case .act2, .ruins, .fallen:     return .ruins
            case .act3, .act4:               return .voidThreshold
            }
        }

        /// Piste CC0 embarquée (OpenGameArt) ; nil = boucle synthétisée.
        var fileName: String? {
            switch self {
            case .calm:          return "music_village"
            case .tense:         return "music_forest"
            case .sacred:        return "music_title"
            case .ruins:         return "music_mines"
            case .voidThreshold: return "music_threshold"
            case .mines:         return "music_mines"
            case .inn:           return "music_inn"
            case .combat:        return "music_combat"
            case .boss:          return "music_boss"
            case .title:         return "music_title"
            case .finale:        return "music_finale"
            }
        }

        /// Mood de repli pour la synthèse des cas sans piste dédiée.
        var synthFallback: MusicMood {
            switch self {
            case .mines: return .ruins
            case .inn: return .calm
            case .combat: return .tense
            case .boss: return .voidThreshold
            case .title: return .sacred
            case .finale: return .sacred
            default: return self
            }
        }
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
        musicFadeTask?.cancel()
        musicPlayerA.stop()
        musicPlayerB.stop()
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
    func stopMusic()  {
        musicFadeTask?.cancel()
        musicPlayerA.stop()
        musicPlayerB.stop()
    }

    /// Bascule l'ambiance musicale (cross-fade si le moteur tourne déjà).
    /// Idempotent : aucun effet si l'ambiance est déjà active.
    func setMood(_ mood: MusicMood) {
        guard mood != currentMood else { return }
        currentMood = mood
        if engine.isRunning { crossfade(to: mood) }
    }

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
        guard engine.isRunning, let loop = musicBuffers[currentMood] else { return }
        let player = musicUsingA ? musicPlayerA : musicPlayerB
        if player.isPlaying { return }
        player.volume = 1
        player.scheduleBuffer(loop, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    /// Cross-fade vers une nouvelle ambiance : l'entrant démarre à 0 et monte
    /// pendant que le sortant descend, sur ~1.4 s. On ne capture que des
    /// valeurs `Sendable` (mood, bool) dans la Task @MainActor — les nodes
    /// non-Sendable sont relus via `self`, qui reste isolé au main actor.
    private func crossfade(to mood: MusicMood, duration: Double = 1.4) {
        let incomingUsesA = !musicUsingA
        musicUsingA = incomingUsesA
        musicFadeTask?.cancel()
        musicFadeTask = Task { @MainActor [weak self] in
            guard let self, let buffer = self.musicBuffers[mood] else { return }
            let incoming = incomingUsesA ? self.musicPlayerA : self.musicPlayerB
            let outgoing = incomingUsesA ? self.musicPlayerB : self.musicPlayerA
            // stop() vide la file du node : évite qu'un buffer périmé reste en
            // attente si les ambiances s'enchaînent vite.
            self.startLoop(incoming, buffer: buffer)

            let steps = 28
            let stepDur = duration / Double(steps)
            for i in 1...steps {
                if Task.isCancelled { return }
                let p = Float(i) / Float(steps)
                incoming.volume = p
                outgoing.volume = 1 - p
                try? await Task.sleep(nanoseconds: UInt64(stepDur * 1_000_000_000))
            }
            outgoing.stop()
            outgoing.volume = 1
        }
    }

    /// Démarre une boucle musicale via l'API à callback. Isolée dans une
    /// fonction synchrone : appelée depuis le `Task` async, elle évite le
    /// warning « consider using asynchronous alternative » (la variante
    /// async de `scheduleBuffer` ne rend jamais la main sur `.loops`).
    @MainActor
    private func startLoop(_ player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer) {
        player.stop()
        player.volume = 0
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
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

        engine.attach(musicPlayerA)
        engine.attach(musicPlayerB)
        engine.connect(musicPlayerA, to: musicMixer, format: format)
        engine.connect(musicPlayerB, to: musicMixer, format: format)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: format)

        sfxMixer.outputVolume = clamp(masterVolume)
        musicMixer.outputVolume = clamp(musicVolume)
    }

    // MARK: - Synthèse

    private func renderAllBuffers() {
        for sound in Sound.allCases {
            // Vrai SFX CC0 embarqué quand disponible, synthèse sinon.
            buffers[sound] = sound.fileName.flatMap { loadAudioBuffer(named: $0, ext: "wav") }
                ?? renderSFX(sound)
        }
        for mood in MusicMood.allCases {
            // Vraie musique CC0 embarquée quand disponible ; sinon la
            // boucle synthétisée historique.
            musicBuffers[mood] = loadMusicFile(for: mood)
                ?? renderMusicLoop(mood.synthFallback)
        }
    }

    /// Charge une piste embarquée dans un buffer PCM au format du moteur
    /// (conversion AVAudioConverter si le fichier diffère).
    private func loadMusicFile(for mood: MusicMood) -> AVAudioPCMBuffer? {
        guard let name = mood.fileName else { return nil }
        return loadAudioBuffer(named: name, ext: "m4a")
    }

    /// Fichier audio du bundle → buffer PCM au format du moteur.
    private func loadAudioBuffer(named name: String, ext: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let file = try? AVAudioFile(forReading: url) else { return nil }

        let inFormat = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0,
              let inBuffer = AVAudioPCMBuffer(pcmFormat: inFormat,
                                              frameCapacity: frames) else { return nil }
        do { try file.read(into: inBuffer) } catch { return nil }

        if inFormat == format { return inBuffer }

        guard let converter = AVAudioConverter(from: inFormat, to: format) else { return nil }
        let ratio = format.sampleRate / inFormat.sampleRate
        let outFrames = AVAudioFrameCount(Double(frames) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                               frameCapacity: outFrames) else { return nil }
        // convert() est synchrone : le closure ne s'échappe pas du call.
        // nonisolated(unsafe) fait taire les diagnostics Sendable d'AVFAudio.
        nonisolated(unsafe) var fed = false
        nonisolated(unsafe) let source = inBuffer
        var error: NSError?
        converter.convert(to: outBuffer, error: &error) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return source
        }
        return error == nil ? outBuffer : nil
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

    /// Paramètres d'un pad d'ambiance bouclable.
    /// `beat` (Hz) ajoute un trémolo lent qui crée une tension/inquiétude ;
    /// 0 = drone stable et apaisé.
    private struct MusicConfig {
        let duration: Double
        let root: Double      // fondamentale (drone grave)
        let fifth: Double     // quinte / intervalle de soutien
        let high: Double      // voix aiguë ondulante
        let shimmer: Double   // brillance (contre-temps du LFO)
        let amp: Float        // amplitude globale (fond sonore discret)
        let beat: Double      // fréquence du trémolo (0 = aucun)
    }

    private func config(for mood: MusicMood) -> MusicConfig {
        switch mood {
        case .mines, .inn, .combat, .boss, .title, .finale:
            // Moods à piste CC0 : synthèse de repli si le fichier manque.
            return config(for: mood.synthFallback)
        case .calm:
            // La mineur ouvert, doux — identique à l'ancienne ambiance village.
            return MusicConfig(duration: 8, root: 110, fifth: 164.81,
                               high: 220, shimmer: 329.63, amp: 0.16, beat: 0)
        case .tense:
            // Sol grave + seconde mineure dissonante : forêt corrompue.
            return MusicConfig(duration: 8, root: 98, fifth: 146.83,
                               high: 207.65, shimmer: 277.18, amp: 0.15, beat: 0.18)
        case .sacred:
            // Do majeur lumineux, quinte ouverte : sanctuaire.
            return MusicConfig(duration: 8, root: 130.81, fifth: 196,
                               high: 261.63, shimmer: 392, amp: 0.14, beat: 0)
        case .ruins:
            // Fa grave, lent et sombre : ruines / Kael déchu.
            return MusicConfig(duration: 8, root: 87.31, fifth: 130.81,
                               high: 174.61, shimmer: 233.08, amp: 0.15, beat: 0.10)
        case .voidThreshold:
            // Ré très grave + triton sourd : le Seuil, dread pulsé.
            return MusicConfig(duration: 8, root: 73.42, fifth: 110,
                               high: 103.83, shimmer: 146.83, amp: 0.17, beat: 0.25)
        }
    }

    /// Pad d'ambiance bouclable : drone + harmoniques + LFO lent, avec trémolo
    /// optionnel. Boucle de 8 s sans coupure perceptible (amplitude basse pour
    /// rester en fond).
    private func renderMusicLoop(_ mood: MusicMood) -> AVAudioPCMBuffer {
        let c = config(for: mood)
        return makeBuffer(duration: c.duration) { t in
            let lfo: Float = Float(0.5 + 0.5 * sin(2 * .pi * t / c.duration)) // 1 cycle / boucle
            let tremolo: Float = c.beat > 0
                ? Float(0.75 + 0.25 * sin(2 * .pi * c.beat * t))
                : 1
            let root: Float = sine(t, c.root) * 0.5
            let fifth: Float = sine(t, c.fifth) * 0.35
            let high: Float = sine(t, c.high) * 0.18 * lfo
            let shimmer: Float = sine(t, c.shimmer) * 0.10 * (1 - lfo)
            return c.amp * tremolo * (root + fifth + high + shimmer)
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
