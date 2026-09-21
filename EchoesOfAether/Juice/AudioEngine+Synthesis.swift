import AVFoundation
import os

// AudioEngine — synthèse procédurale des buffers (SFX, boucles musicales) + helpers.
extension AudioEngine {
    // MARK: - Synthèse

    func renderAllBuffers() {
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
        for ambience in Ambience.allCases {
            // Foley : fichier CC0 uniquement, aucune synthèse de repli.
            if let name = ambience.fileName {
                ambienceBuffers[ambience] = loadAudioBuffer(named: name, ext: "m4a")
            }
        }
    }

    /// Charge une piste embarquée dans un buffer PCM au format du moteur
    /// (conversion AVAudioConverter si le fichier diffère).
    func loadMusicFile(for mood: MusicMood) -> AVAudioPCMBuffer? {
        guard let name = mood.fileName else { return nil }
        if let buffer = loadAudioBuffer(named: name, ext: "m4a") { return buffer }
        // Piste dédiée pas encore livrée : on retombe sur une piste existante
        // plutôt que de laisser le combat silencieux.
        guard let alt = mood.fallbackFileName else { return nil }
        return loadAudioBuffer(named: alt, ext: "m4a")
    }

    /// Fichier audio du bundle → buffer PCM au format du moteur.
    func loadAudioBuffer(named name: String, ext: String) -> AVAudioPCMBuffer? {
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
    func makeBuffer(duration: Double, sample: (Double) -> Float) -> AVAudioPCMBuffer {
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

    func renderSFX(_ sound: Sound) -> AVAudioPCMBuffer {
        switch sound {
        case .uiMove:
            // Curseur de menu : sinus pur, niveau très bas, attaque adoucie.
            // Pensé pour être entendu vingt fois d'affilée sans fatiguer.
            return makeBuffer(duration: 0.08) { t in
                let e: Float = env(t, 0.08, attack: 0.010, release: 0.068)
                return e * 0.085 * sine(t, 620)
            }
        case .uiConfirm:
            // Validation : quinte montante en cloche douce — fondamentale
            // plus une octave discrète qui s'éteint vite. Aucun front raide,
            // aucun bruit : c'est ce qui sépare « doux » de « claquant ».
            return makeBuffer(duration: 0.26) { t in
                let f: Double = t < 0.075 ? 587 : 880
                let body: Float = sine(t, f)
                let shimmer: Float = sine(t, f * 2) * 0.18 * expF(-t * 14)
                let e: Float = env(t, 0.26, attack: 0.012, release: 0.20)
                return e * 0.13 * (body + shimmer)
            }
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
    struct MusicConfig {
        let duration: Double
        let root: Double      // fondamentale (drone grave)
        let fifth: Double     // quinte / intervalle de soutien
        let high: Double      // voix aiguë ondulante
        let shimmer: Double   // brillance (contre-temps du LFO)
        let amp: Float        // amplitude globale (fond sonore discret)
        let beat: Double      // fréquence du trémolo (0 = aucun)
    }

    func config(for mood: MusicMood) -> MusicConfig {
        switch mood {
        case .mines, .inn, .title, .finale,
             .combat, .combat2, .combat3, .boss:
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
    func renderMusicLoop(_ mood: MusicMood) -> AVAudioPCMBuffer {
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

    func clamp(_ v: Float) -> Float { max(0, min(1, v)) }

    func sine(_ t: Double, _ freq: Double) -> Float {
        Float(sin(2 * .pi * freq * t))
    }

    func square(_ t: Double, _ freq: Double) -> Float {
        sin(2 * .pi * freq * t) >= 0 ? 1 : -1
    }

    func noise() -> Float { Float.random(in: -1...1) }

    func expF(_ x: Double) -> Float { Float(exp(x)) }

    /// Enveloppe attack/release linéaire (anti-clic), 1 au sustain.
    func env(_ t: Double, _ dur: Double, attack: Double, release: Double) -> Float {
        if t < attack { return Float(t / attack) }
        if t > dur - release { return Float(max(0, (dur - t) / release)) }
        return 1
    }

    /// Renvoie la fréquence de l'étape courante d'une séquence (arpège/accord
    /// égrené) : change toutes les `step` secondes.
    func chordStep(_ t: Double, _ freqs: [Double], step: Double) -> Double {
        let idx = min(freqs.count - 1, Int(t / step))
        return freqs[idx]
    }
}
