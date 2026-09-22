import AVFoundation
import os

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
    static let log = Logger(subsystem: "com.appmakerstudio.echoesofaether",
                                    category: "AudioEngine")

    static let shared = AudioEngine()

    // MARK: - Graphe

    let engine = AVAudioEngine()
    let sfxMixer = AVAudioMixerNode()
    let musicMixer = AVAudioMixerNode()
    var sfxPlayers: [AVAudioPlayerNode] = []
    var sfxIndex = 0

    // Deux nodes musique pour permettre un cross-fade propre entre ambiances
    // (l'entrant monte pendant que le sortant descend). Le mixeur musique
    // garde le volume utilisateur ; le fondu se fait sur `.volume` des nodes.
    let musicPlayerA = AVAudioPlayerNode()
    let musicPlayerB = AVAudioPlayerNode()
    var musicUsingA = true
    var musicFadeTask: Task<Void, Never>?

    // Couche foley : boucle d'ambiance de zone (vent, grillons, gouttes)
    // sous la musique. Même schéma que la musique (2 nodes + cross-fade),
    // mixeur séparé à volume réduit. Aucune synthèse de repli : si le
    // fichier d'ambiance manque, on reste silencieux (un vent synthétique
    // jurerait). Fichiers CC0 embarqués dans Resources/Ambience.
    let ambienceMixer = AVAudioMixerNode()
    let ambiencePlayerA = AVAudioPlayerNode()
    let ambiencePlayerB = AVAudioPlayerNode()
    var ambienceUsingA = true
    var ambienceFadeTask: Task<Void, Never>?
    var ambienceBuffers: [Ambience: AVAudioPCMBuffer] = [:]
    private(set) var currentAmbience: Ambience = .none

    let sampleRate: Double = 44_100
    lazy var format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate, channels: 2)!

    var buffers: [Sound: AVAudioPCMBuffer] = [:]
    var musicBuffers: [MusicMood: AVAudioPCMBuffer] = [:]
    private(set) var currentMood: MusicMood = .calm

    private var started = false
    let sfxVoiceCount = 8

    // MARK: - Volumes

    /// Volume des effets (0...1). Câblé sur le sous-mixeur SFX.
    var masterVolume: Float = 1.0 {
        didSet { sfxMixer.outputVolume = clamp(masterVolume) }
    }

    /// Volume de la musique d'ambiance (0...1).
    var musicVolume: Float = 0.55 {
        didSet {
            musicMixer.outputVolume = clamp(musicVolume)
            // Le foley suit le réglage musique mais reste en retrait (×0.6).
            ambienceMixer.outputVolume = clamp(musicVolume * 0.6)
        }
    }

    var isRunning: Bool { engine.isRunning }

    private init() {}

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
            Self.log.error("start failed: \(error.localizedDescription, privacy: .public)")
            #endif
            return
        }
        startMusic()
        startAmbience()
    }

    func stop() {
        musicFadeTask?.cancel()
        ambienceFadeTask?.cancel()
        musicPlayerA.stop()
        musicPlayerB.stop()
        ambiencePlayerA.stop()
        ambiencePlayerB.stop()
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
    /// Déplacement de curseur dans un menu (doux, discret).
    func playUIMove()       { play(.uiMove) }
    /// Validation dans un menu (doux, sans claquement).
    func playUIConfirm()    { play(.uiConfirm) }

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

    /// Index de la prochaine piste de combat standard.
    private var combatRotation = 0

    /// Musique d'un combat ORDINAIRE : alterne entre trois variantes pour que
    /// les affrontements ne sonnent pas tous pareil. (Tant que
    /// `music_combat2/3.m4a` ne sont pas livrées, les trois retombent sur
    /// `music_combat` — cf. fallbackFileName.)
    func setCombatMood() {
        let pool: [MusicMood] = [.combat, .combat2, .combat3]
        let mood = pool[combatRotation % pool.count]
        combatRotation += 1
        setMood(mood)
    }

    /// Bascule la couche foley de zone (cross-fade). Idempotent. Silencieux
    /// si le fichier d'ambiance n'est pas embarqué (buffer absent).
    func setAmbience(_ ambience: Ambience) {
        guard ambience != currentAmbience else { return }
        currentAmbience = ambience
        if engine.isRunning { crossfadeAmbience(to: ambience) }
    }
}
