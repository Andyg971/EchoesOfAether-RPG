import SpriteKit

@MainActor
final class OptionsOverlay {

    /// Taille du panneau, en points de scène.
    ///
    /// Panneau PAYSAGE, en deux colonnes. Il empilait auparavant ses quatorze
    /// sections dans une bande de 304 × 672 : 20 % de la largeur, 95 % de la
    /// hauteur — un panneau portrait dans un jeu qui ne se joue qu'en paysage.
    /// `fittingFactor` le faisait tenir en le réduisant à ×0,55, ce qui marche
    /// géométriquement mais pas typographiquement : les libellés tombaient à
    /// 8,5 pt à l'écran, là où Apple recommande 11 pt au minimum.
    ///
    /// Deux colonnes ramènent la hauteur de 672 à 356 pt : le panneau tient
    /// désormais SANS AUCUNE réduction, et les libellés retrouvent leurs 15 pt
    /// pleins. Rien n'a été retiré, ni défilement ni pagination ajoutés — la
    /// place était sur le côté, pas en bas.
    ///
    /// Exposé pour que `OverlayLegibilityTests` garde l'invariant : ajouter
    /// une ligne sans revoir la mise en page fera échouer le test au lieu de
    /// rogner le texte en silence.
    static let panelSize = CGSize(width: 640, height: 356)

    private let root = SKNode()
    private var sfxLabel: SKLabelNode?
    private var musicLabel: SKLabelNode?
    private var confirmDelete = false

    var onClose: (() -> Void)?
    var onDeleteSave: (() -> Void)?
    var onVolumeChange: ((Float) -> Void)?
    var onMusicVolumeChange: ((Float) -> Void)?
    /// Appelé quand un réglage d'accessibilité « gros texte » change — permet
    /// au jeu de re-disposer le HUD et le dialogue.
    var onLargeTextChange: (() -> Void)?
    /// Appelé pour relancer le tutoriel.
    var onShowTutorial: (() -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    // Volumes 0.0–1.0 — câblés sur AudioEngine (SFX = masterVolume, musique = musicVolume).
    private(set) var sfxVolume: Float = 1.0
    private(set) var musicVolume: Float = 0.55

    func attach(to scene: SKScene) {
        root.zPosition = 1_600
        root.isHidden = true
        scene.addChild(root)
    }

    func show(in scene: SKScene) {
        root.removeAllChildren()
        root.isHidden = false
        confirmDelete = false

        let w = scene.size.width, h = scene.size.height

        // Fond
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.80)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: w / 2, y: h / 2)
        root.addChild(scrim)

        let panelW = Self.panelSize.width, panelH = Self.panelSize.height
        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: CGSize(width: panelW, height: panelH),
                           fill: SKColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 0.97),
                           accent: SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 0.8))
        panel.position = CGPoint(x: w/2, y: h/2)
        root.addChild(panel)

        let cx = w / 2
        let top = h / 2 + panelH / 2   // bord haut du panneau en coords écran

        // Titre
        let title = label(String(localized: "options.title"), size: 28,
                          color: Palette.aether)
        title.position = CGPoint(x: cx, y: top - 34)
        root.addChild(title)

        // Deux colonnes, chacune avec son propre curseur vertical.
        // Gauche : ce qu'on règle en jouant (son, difficulté).
        // Droite : ce qu'on règle une fois (accessibilité, langue).
        let colonneGauche = cx - panelW / 4
        let colonneDroite = cx + panelW / 4
        let largeurLigne = panelW / 2 - 40
        let hautColonnes = top - 76

        // ── Colonne gauche ───────────────────────────────────────────────
        var yG = hautColonnes

        let musicTitle = label(String(localized: "options.music"), size: 18,
                               color: SKColor(white: 0.65, alpha: 1))
        musicTitle.position = CGPoint(x: colonneGauche, y: yG)
        root.addChild(musicTitle); yG -= 26
        root.addChild(makeVolumeRow(value: musicVolume,
                                    at: CGPoint(x: colonneGauche, y: yG),
                                    kind: .music)); yG -= 38

        let sfxTitle = label(String(localized: "options.sfx"), size: 18,
                             color: SKColor(white: 0.65, alpha: 1))
        sfxTitle.position = CGPoint(x: colonneGauche, y: yG)
        root.addChild(sfxTitle); yG -= 26
        root.addChild(makeVolumeRow(value: sfxVolume,
                                    at: CGPoint(x: colonneGauche, y: yG),
                                    kind: .sfx)); yG -= 42

        // Difficulté — se tape pour cycler Histoire → Normal → Vétéran, comme
        // les bascules voisines. Trois valeurs ne méritent pas un sous-menu.
        root.addChild(makeCycleRow(String(localized: "options.difficulty"),
                                   value: Difficulty.current.localizedName,
                                   name: "cycleDifficulty",
                                   at: CGPoint(x: colonneGauche, y: yG),
                                   width: largeurLigne)); yG -= 36

        // ── Colonne droite ───────────────────────────────────────────────
        var yD = hautColonnes

        root.addChild(makeToggleRow(String(localized: "options.reduceMotion"),
                                    isOn: AccessibilitySettings.reduceMotion,
                                    name: "toggleReduceMotion",
                                    at: CGPoint(x: colonneDroite, y: yD),
                                    width: largeurLigne)); yD -= 34
        root.addChild(makeToggleRow(String(localized: "options.largeText"),
                                    isOn: AccessibilitySettings.largeText,
                                    name: "toggleLargeText",
                                    at: CGPoint(x: colonneDroite, y: yD),
                                    width: largeurLigne)); yD -= 34
        root.addChild(makeToggleRow(String(localized: "options.haptics"),
                                    isOn: HapticsEngine.enabled,
                                    name: "toggleHaptics",
                                    at: CGPoint(x: colonneDroite, y: yD),
                                    width: largeurLigne)); yD -= 38

        let langTitle = label(String(localized: "options.language"), size: 18,
                              color: SKColor(white: 0.65, alpha: 1))
        langTitle.position = CGPoint(x: colonneDroite, y: yD)
        root.addChild(langTitle); yD -= 32

        let current = currentLanguageCode()
        let frBtn = makeLangButton("Français", code: "fr",
                                   selected: current == "fr", name: "langFR")
        frBtn.position = CGPoint(x: colonneDroite - 60, y: yD)
        root.addChild(frBtn)

        let enBtn = makeLangButton("English", code: "en",
                                   selected: current == "en", name: "langEN")
        enBtn.position = CGPoint(x: colonneDroite + 60, y: yD)
        root.addChild(enBtn); yD -= 26

        // Note redémarrage — cachée jusqu'au changement
        let restart = label(String(localized: "options.language.restart"), size: 14,
                            color: SKColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 1))
        restart.position = CGPoint(x: colonneDroite, y: yD)
        restart.name = "langRestart"
        restart.isHidden = true
        root.addChild(restart); yD -= 22

        // ── Pied de panneau, sur toute la largeur ────────────────────────
        // Aligné sous la plus basse des deux colonnes.
        var y = min(yG, yD) - 8
        addSeparator(width: panelW - 48, at: CGPoint(x: cx, y: y)); y -= 34

        let largeurBouton: CGFloat = 196
        let pas = largeurBouton + 12

        let tutorialBtn = makeButton(String(localized: "options.replayTutorial"),
            fill: SKColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1),
            stroke: SKColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 0.85),
            name: "optionsTutorial", width: largeurBouton)
        tutorialBtn.position = CGPoint(x: cx - pas, y: y)
        root.addChild(tutorialBtn)

        let resetBtn = makeButton(String(localized: "options.resetSave"),
            fill: SKColor(red: 0.16, green: 0.05, blue: 0.05, alpha: 1),
            stroke: SKColor(red: 0.65, green: 0.18, blue: 0.18, alpha: 0.9),
            name: "optionsReset", width: largeurBouton)
        resetBtn.position = CGPoint(x: cx, y: y)
        root.addChild(resetBtn)

        let closeBtn = makeButton(String(localized: "options.close"),
            fill: SKColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1),
            stroke: Palette.panelBorder,
            name: "optionsClose", width: largeurBouton)
        closeBtn.position = CGPoint(x: cx + pas, y: y)
        root.addChild(closeBtn)

        // Animate
        panel.alpha = 0; panel.run(.fadeIn(withDuration: 0.2))
        for (i, child) in root.children.enumerated() where child !== scrim {
            JuiceEngine.popIn(child, delay: Double(i) * 0.03)
        }

        // Filet de sécurité : `fittingFactor` réduirait le panneau s'il ne
        // tenait pas en hauteur. Depuis le passage en deux colonnes (356 pt),
        // il tient sur tous les écrans visés et ce facteur vaut 1 — on le
        // garde pour les écrans plus courts que le gabarit. Le scrim est
        // contre-scalé pour couvrir tout l'écran quoi qu'il arrive.
        let s = UIScale.fittingFactor(for: scene.size, contentHeight: panelH + 16)
        root.setScale(s)
        root.position = CGPoint(x: w / 2 * (1 - s), y: h / 2 * (1 - s))
        scrim.setScale(1 / s)
        AccessibilitySettings.announce(String(localized: "options.title"))
    }

    private func addSeparator(width: CGFloat, at pos: CGPoint) {
        let sep = SKShapeNode(rectOf: CGSize(width: width, height: 1))
        sep.fillColor = SKColor(white: 0.20, alpha: 0.5)
        sep.strokeColor = .clear
        sep.position = pos
        root.addChild(sep)
    }

    func hide() {
        root.isHidden = true
        root.removeAllChildren()
        confirmDelete = false
    }

    /// Bouton B : retour (équivalent du bouton Fermer).
    func dismiss() {
        AudioEngine.shared.playTap()
        onClose?()
    }

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
    private func currentLanguageCode() -> String {
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

    private func makeLangButton(_ text: String, code: String,
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

    private enum VolumeKind { case sfx, music }

    private func refreshVolumeDisplay(_ kind: VolumeKind) {
        switch kind {
        case .sfx:   sfxLabel?.text = volumeString(sfxVolume)
        case .music: musicLabel?.text = volumeString(musicVolume)
        }
    }

    private func volumeString(_ v: Float) -> String {
        let filled = Int((v * 4).rounded())
        let blocks = String(repeating: "█", count: filled) + String(repeating: "░", count: 4 - filled)
        return blocks
    }

    private func makeVolumeRow(value: Float, at pos: CGPoint, kind: VolumeKind) -> SKNode {
        let container = SKNode()
        container.position = pos
        let downName = kind == .sfx ? "sfxDown" : "musicDown"
        let upName   = kind == .sfx ? "sfxUp" : "musicUp"

        let downBtn = makeSmallButton("<", name: downName)
        downBtn.position = CGPoint(x: -70, y: 0)
        container.addChild(downBtn)

        let upBtn = makeSmallButton(">", name: upName)
        upBtn.position = CGPoint(x: 70, y: 0)
        container.addChild(upBtn)

        let volLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        volLabel.text = volumeString(value)
        volLabel.fontSize = 23
        volLabel.fontColor = SKColor(red: 0.55, green: 0.80, blue: 0.55, alpha: 1)
        volLabel.horizontalAlignmentMode = .center
        volLabel.verticalAlignmentMode = .center
        container.addChild(volLabel)
        switch kind {
        case .sfx:   sfxLabel = volLabel
        case .music: musicLabel = volLabel
        }

        return container
    }

    private func makeSmallButton(_ text: String, name: String) -> SKShapeNode {
        // Carré pixel (pas de cercle : le rond casse le style rétro).
        let btn = SKShapeNode(rectOf: CGSize(width: 36, height: 36))
        btn.fillColor = Palette.panelNight
        btn.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.70, alpha: 0.8)
        btn.lineWidth = 2
        btn.glowWidth = 0
        btn.name = name
        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 20
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }

    /// Bascule un réglage booléen (UserDefaults) et rafraîchit l'overlay.
    private func toggle(key: String, scene: SKScene) {
        let newValue = !UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(newValue, forKey: key)
        HapticsEngine.light()
        show(in: scene)   // rebuild pour refléter l'état ON/OFF
    }

    /// Ligne « libellé … [ON/OFF] » tappable (toute la ligne est la zone).
    private func makeToggleRow(_ text: String, isOn: Bool, name: String,
                               at pos: CGPoint, width: CGFloat) -> SKShapeNode {
        let row = SKShapeNode(rectOf: CGSize(width: width, height: 30))
        row.fillColor = SKColor(red: 0.09, green: 0.08, blue: 0.15, alpha: 1)
        row.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.60, alpha: 0.5)
        row.lineWidth = 1
        row.glowWidth = 0
        row.name = name
        row.position = pos

        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 15
        lbl.fontColor = SKColor(white: 0.85, alpha: 1)
        lbl.horizontalAlignmentMode = .left
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: -width / 2 + 12, y: 0)
        lbl.isUserInteractionEnabled = false
        row.addChild(lbl)

        // Badge ON/OFF carré (pas de pilule arrondie en pixel art).
        let pill = SKShapeNode(rectOf: CGSize(width: 46, height: 20))
        pill.glowWidth = 0
        pill.fillColor = isOn
            ? SKColor(red: 0.20, green: 0.55, blue: 0.32, alpha: 1)
            : SKColor(red: 0.20, green: 0.18, blue: 0.26, alpha: 1)
        pill.strokeColor = isOn
            ? SKColor(red: 0.40, green: 0.85, blue: 0.55, alpha: 1)
            : SKColor(red: 0.45, green: 0.40, blue: 0.55, alpha: 0.8)
        pill.lineWidth = 1.2
        pill.position = CGPoint(x: width / 2 - 33, y: 0)
        pill.isUserInteractionEnabled = false
        row.addChild(pill)

        let pillLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        pillLbl.text = isOn ? String(localized: "options.toggle.on")
                            : String(localized: "options.toggle.off")
        pillLbl.fontSize = 13
        pillLbl.fontColor = .white
        pillLbl.verticalAlignmentMode = .center
        pillLbl.horizontalAlignmentMode = .center
        pillLbl.position = pill.position
        pillLbl.isUserInteractionEnabled = false
        row.addChild(pillLbl)

        return row
    }

    /// Ligne « libellé … [valeur] » tappable, qui cycle entre plusieurs états.
    ///
    /// Même géométrie que `makeToggleRow` — c'est le même objet pour le joueur,
    /// avec trois positions au lieu de deux. Le badge est plus large : « Vétéran »
    /// ne tient pas dans les 46 pt d'un ON/OFF.
    private func makeCycleRow(_ text: String, value: String, name: String,
                              at pos: CGPoint, width: CGFloat) -> SKShapeNode {
        let row = SKShapeNode(rectOf: CGSize(width: width, height: 30))
        row.fillColor = SKColor(red: 0.09, green: 0.08, blue: 0.15, alpha: 1)
        row.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.60, alpha: 0.5)
        row.lineWidth = 1
        row.glowWidth = 0
        row.name = name
        row.position = pos

        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 15
        lbl.fontColor = SKColor(white: 0.85, alpha: 1)
        lbl.horizontalAlignmentMode = .left
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: -width / 2 + 12, y: 0)
        lbl.isUserInteractionEnabled = false
        row.addChild(lbl)

        // Badge carré (pas de pilule arrondie en pixel art), accent violet
        // comme le reste de l'écran d'options.
        let badge = SKShapeNode(rectOf: CGSize(width: 88, height: 20))
        badge.glowWidth = 0
        badge.fillColor = SKColor(red: 0.20, green: 0.16, blue: 0.34, alpha: 1)
        badge.strokeColor = SKColor(red: 0.62, green: 0.52, blue: 0.95, alpha: 1)
        badge.lineWidth = 1.2
        badge.position = CGPoint(x: width / 2 - 54, y: 0)
        badge.isUserInteractionEnabled = false
        row.addChild(badge)

        let badgeLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        badgeLbl.text = value
        badgeLbl.fontSize = 13
        badgeLbl.fontColor = .white
        badgeLbl.verticalAlignmentMode = .center
        badgeLbl.horizontalAlignmentMode = .center
        badgeLbl.position = badge.position
        badgeLbl.isUserInteractionEnabled = false
        row.addChild(badgeLbl)

        return row
    }

    /// `width` : 220 par défaut (pile de boutons), 196 pour les trois boutons
    /// alignés en pied de panneau paysage.
    private func makeButton(_ text: String, fill: SKColor, stroke: SKColor,
                            name: String, width: CGFloat = 220) -> SKShapeNode {
        // Bouton pixel : rectangle net, zéro coin arrondi, zéro glow.
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: 46))
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 2
        btn.glowWidth = 0
        btn.name = name
        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 18
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: PixelUI.uiFont)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        return l
    }
}
