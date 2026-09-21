import AVFoundation
import os

// AudioEngine — lecture : voix SFX, crossfades musique/ambiance, graphe AVAudio.
extension AudioEngine {
    // MARK: - Playback

    func play(_ sound: Sound) {
        guard engine.isRunning, let buffer = buffers[sound], !sfxPlayers.isEmpty else { return }
        // Pool round-robin : .interrupts donne une polyphonie = sfxVoiceCount.
        let player = sfxPlayers[sfxIndex]
        sfxIndex = (sfxIndex + 1) % sfxPlayers.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func startMusic() {
        guard engine.isRunning, let loop = musicBuffers[currentMood] else { return }
        let player = musicUsingA ? musicPlayerA : musicPlayerB
        if player.isPlaying { return }
        player.volume = 1
        player.scheduleBuffer(loop, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    /// Démarre la couche foley courante (appelé après le moteur). Sans
    /// buffer (fichier absent), ne fait rien : ambiance silencieuse.
    func startAmbience() {
        guard engine.isRunning, let loop = ambienceBuffers[currentAmbience] else { return }
        let player = ambienceUsingA ? ambiencePlayerA : ambiencePlayerB
        if player.isPlaying { return }
        player.volume = 1
        player.scheduleBuffer(loop, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    /// Cross-fade de la couche foley. Si l'entrant n'a pas de buffer
    /// (ex. `.none` ou fichier manquant), on se contente d'éteindre le
    /// sortant en fondu.
    func crossfadeAmbience(to ambience: Ambience, duration: Double = 1.6) {
        let incomingUsesA = !ambienceUsingA
        ambienceUsingA = incomingUsesA
        ambienceFadeTask?.cancel()
        ambienceFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let incoming = incomingUsesA ? self.ambiencePlayerA : self.ambiencePlayerB
            let outgoing = incomingUsesA ? self.ambiencePlayerB : self.ambiencePlayerA
            let buffer = self.ambienceBuffers[ambience]
            if let buffer { self.startLoop(incoming, buffer: buffer) }

            let steps = 32
            let stepDur = duration / Double(steps)
            for i in 1...steps {
                if Task.isCancelled { return }
                let p = Float(i) / Float(steps)
                if buffer != nil { incoming.volume = p }
                outgoing.volume = 1 - p
                try? await Task.sleep(nanoseconds: UInt64(stepDur * 1_000_000_000))
            }
            outgoing.stop()
            outgoing.volume = 1
        }
    }

    /// Cross-fade vers une nouvelle ambiance : l'entrant démarre à 0 et monte
    /// pendant que le sortant descend, sur ~1.4 s. On ne capture que des
    /// valeurs `Sendable` (mood, bool) dans la Task @MainActor — les nodes
    /// non-Sendable sont relus via `self`, qui reste isolé au main actor.
    func crossfade(to mood: MusicMood, duration: Double = 1.4) {
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
    func startLoop(_ player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer) {
        player.stop()
        player.volume = 0
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    // MARK: - Setup

    func configureSession() {
        #if !targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        // .ambient : respecte le bouton silence, mixe avec les autres apps.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    func buildGraph() {
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

        engine.attach(ambienceMixer)
        engine.attach(ambiencePlayerA)
        engine.attach(ambiencePlayerB)
        engine.connect(ambiencePlayerA, to: ambienceMixer, format: format)
        engine.connect(ambiencePlayerB, to: ambienceMixer, format: format)
        engine.connect(ambienceMixer, to: engine.mainMixerNode, format: format)

        sfxMixer.outputVolume = clamp(masterVolume)
        musicMixer.outputVolume = clamp(musicVolume)
        ambienceMixer.outputVolume = clamp(musicVolume * 0.6)
    }
}
