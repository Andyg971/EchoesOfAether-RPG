import SpriteKit

// OptionsOverlay — taps : volumes, bascules, langue, reset avec confirmation.
extension OptionsOverlay {
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "sfxDown") as? SKShapeNode, btn.contains(local) {
            sfxVolume = max(0, sfxVolume - 0.25)
            refreshVolumeDisplay(.sfx)
            HapticsEngine.light()
            onVolumeChange?(sfxVolume)
            return true
        }
        if let btn = root.childNode(withName: "sfxUp") as? SKShapeNode, btn.contains(local) {
            sfxVolume = min(1, sfxVolume + 0.25)
            refreshVolumeDisplay(.sfx)
            HapticsEngine.light()
            onVolumeChange?(sfxVolume)
            return true
        }
        if let btn = root.childNode(withName: "musicDown") as? SKShapeNode, btn.contains(local) {
            musicVolume = max(0, musicVolume - 0.25)
            refreshVolumeDisplay(.music)
            HapticsEngine.light()
            onMusicVolumeChange?(musicVolume)
            return true
        }
        if let btn = root.childNode(withName: "musicUp") as? SKShapeNode, btn.contains(local) {
            musicVolume = min(1, musicVolume + 0.25)
            refreshVolumeDisplay(.music)
            HapticsEngine.light()
            onMusicVolumeChange?(musicVolume)
            return true
        }
        if let btn = root.childNode(withName: "cycleDifficulty") as? SKShapeNode, btn.contains(local) {
            Difficulty.current = Difficulty.current.next
            HapticsEngine.light()
            show(in: scene)   // rebuild pour afficher le nouveau palier
            return true
        }
        if let btn = root.childNode(withName: "toggleReduceMotion") as? SKShapeNode, btn.contains(local) {
            toggle(key: AccessibilitySettings.reduceMotionKey, scene: scene)
            return true
        }
        if let btn = root.childNode(withName: "toggleLargeText") as? SKShapeNode, btn.contains(local) {
            toggle(key: AccessibilitySettings.largeTextKey, scene: scene)
            onLargeTextChange?()
            return true
        }
        if let btn = root.childNode(withName: "toggleHaptics") as? SKShapeNode, btn.contains(local) {
            // Défaut activé : on bascule depuis la valeur effective, pas depuis
            // le brut UserDefaults.bool (qui vaut false tant qu'on n'a rien écrit).
            UserDefaults.standard.set(!HapticsEngine.enabled, forKey: HapticsEngine.enabledKey)
            HapticsEngine.light()   // buzz de confirmation si on vient d'activer
            show(in: scene)
            return true
        }
        if let btn = root.childNode(withName: "optionsTutorial") as? SKShapeNode, btn.contains(local) {
            HapticsEngine.light()
            onShowTutorial?()
            return true
        }
        if let btn = root.childNode(withName: "langFR") as? SKShapeNode, btn.contains(local) {
            selectLanguage("fr")
            return true
        }
        if let btn = root.childNode(withName: "langEN") as? SKShapeNode, btn.contains(local) {
            selectLanguage("en")
            return true
        }
        if let btn = root.childNode(withName: "optionsReset") as? SKShapeNode, btn.contains(local) {
            handleReset(btn: btn)
            return true
        }
        if let btn = root.childNode(withName: "optionsClose") as? SKShapeNode, btn.contains(local) {
            HapticsEngine.light()
            onClose?()
            return true
        }
        return true
    }

    // MARK: - Language

    /// Code langue actif (fr/en) — basé sur la localisation résolue du bundle.
    func currentLanguageCode() -> String {
        if let override = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first {
            return override.hasPrefix("en") ? "en" : "fr"
        }
        return (Bundle.main.preferredLocalizations.first ?? "fr").hasPrefix("en") ? "en" : "fr"
    }

    /// Persiste la langue choisie. iOS charge le bundle au lancement :
    /// effectif au prochain démarrage (on l'indique au joueur).
    private func selectLanguage(_ code: String) {
        HapticsEngine.light()
        guard code != currentLanguageCode() else { return }
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        // Met à jour la sélection visuelle + affiche la note de redémarrage
        refreshLangSelection(selected: code)
        if let restart = root.childNode(withName: "langRestart") {
            restart.isHidden = false
            JuiceEngine.popIn(restart, delay: 0)
        }
    }

    private func refreshLangSelection(selected: String) {
        for (name, code) in [("langFR", "fr"), ("langEN", "en")] {
            guard let btn = root.childNode(withName: name) as? SKShapeNode else { continue }
            styleLangButton(btn, selected: code == selected)
        }
    }

    func makeLangButton(_ text: String, code: String,
                                selected: Bool, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 112, height: 40))
        btn.glowWidth = 0
        btn.name = name
        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 18
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        lbl.name = "label"
        btn.addChild(lbl)
        styleLangButton(btn, selected: selected)
        return btn
    }

    private func styleLangButton(_ btn: SKShapeNode, selected: Bool) {
        if selected {
            btn.fillColor = SKColor(red: 0.30, green: 0.22, blue: 0.50, alpha: 1)
            btn.strokeColor = SKColor(red: 0.70, green: 0.58, blue: 1.0, alpha: 1)
            btn.lineWidth = 2
        } else {
            btn.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.16, alpha: 1)
            btn.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.60, alpha: 0.7)
            btn.lineWidth = 1.5
        }
        (btn.childNode(withName: "label") as? SKLabelNode)?.fontColor =
            selected ? .white : SKColor(white: 0.60, alpha: 1)
    }

    // MARK: - Private

    private func handleReset(btn: SKShapeNode) {
        if confirmDelete {
            HapticsEngine.error()
            onDeleteSave?()
        } else {
            confirmDelete = true
            HapticsEngine.heavy()
            // Change bouton en rouge confirmation
            btn.strokeColor = SKColor(red: 0.90, green: 0.15, blue: 0.10, alpha: 1)
            if let lbl = btn.children.first as? SKLabelNode {
                lbl.text = String(localized: "options.resetSave.confirm")
                lbl.fontColor = SKColor(red: 1, green: 0.3, blue: 0.2, alpha: 1)
            }
        }
    }


    /// Bascule un réglage booléen (UserDefaults) et rafraîchit l'overlay.
    func toggle(key: String, scene: SKScene) {
        let newValue = !UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(newValue, forKey: key)
        HapticsEngine.light()
        show(in: scene)   // rebuild pour refléter l'état ON/OFF
    }
}
