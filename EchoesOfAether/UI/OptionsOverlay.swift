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

    let root = SKNode()
    var sfxLabel: SKLabelNode?
    var musicLabel: SKLabelNode?
    var confirmDelete = false

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
    var sfxVolume: Float = 1.0
    var musicVolume: Float = 0.55

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

        let tutorialBtn = PixelUI.makeButton(String(localized: "options.replayTutorial"),
            size: CGSize(width: largeurBouton, height: 46),
            fill: SKColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1),
            accent: SKColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 0.85),
            fontSize: 18, name: "optionsTutorial")
        tutorialBtn.position = CGPoint(x: cx - pas, y: y)
        root.addChild(tutorialBtn)

        let resetBtn = PixelUI.makeButton(String(localized: "options.resetSave"),
            size: CGSize(width: largeurBouton, height: 46),
            fill: SKColor(red: 0.16, green: 0.05, blue: 0.05, alpha: 1),
            accent: SKColor(red: 0.65, green: 0.18, blue: 0.18, alpha: 0.9),
            fontSize: 18, name: "optionsReset")
        resetBtn.position = CGPoint(x: cx, y: y)
        root.addChild(resetBtn)

        let closeBtn = PixelUI.makeButton(String(localized: "options.close"),
            size: CGSize(width: largeurBouton, height: 46),
            fill: SKColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1),
            accent: Palette.panelBorder,
            fontSize: 18, name: "optionsClose")
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

}
