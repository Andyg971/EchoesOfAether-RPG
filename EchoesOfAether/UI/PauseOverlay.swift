import SpriteKit

@MainActor
final class PauseOverlay {
    private let root = SKNode()
    private var buttonsReady = false

    var onResume: (() -> Void)?
    var onSave: (() -> Void)?
    var onOptions: (() -> Void)?
    /// Ouvre l'Arbre de l'Aether (points de compétence).
    var onSkills: (() -> Void)?
    var onMainMenu: (() -> Void)?
    /// Points non dépensés — affichés en pastille sur le bouton pour que le
    /// joueur ne les oublie pas au fond d'un menu.
    var pendingSkillPoints = 0
    /// Rouvre le mur d'achat. Le bouton n'existe que si le jeu complet n'est
    /// pas encore débloqué — sinon rien ne rappelle l'achat au joueur payant.
    var onUnlock: (() -> Void)?
    var showsUnlockButton = false

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_500
        root.isHidden = true
        scene.addChild(root)
    }

    func show(in scene: SKScene) {
        root.removeAllChildren()
        root.isHidden = false
        buttonsReady = false

        // Fond flouté (semi-transparent)
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.72)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        // Panel central — cadre pixel SNES (coins carrés, double bordure)
        let panelW: CGFloat = 280
        let panelH: CGFloat = showsUnlockButton ? 480 : 420
        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: CGSize(width: panelW, height: panelH),
                           fill: SKColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 0.96),
                           accent: SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 0.8))
        panel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        panel.alpha = 0
        root.addChild(panel)

        // Titre
        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        title.text = String(localized: "pause.title")
        title.fontSize = 28
        title.fontColor = Palette.aether
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: scene.size.width / 2,
                                 y: scene.size.height / 2 + panelH / 2 - 40)
        title.alpha = 0
        root.addChild(title)

        // Boutons
        let centerX = scene.size.width / 2
        let centerY = scene.size.height / 2

        let resumeBtn = PixelUI.makeButton(String(localized: "pause.resume"),
            size: CGSize(width: 200, height: 48),
            fill: SKColor(red: 0.10, green: 0.20, blue: 0.12, alpha: 1),
            accent: SKColor(red: 0.30, green: 0.70, blue: 0.40, alpha: 1),
            fontSize: 20, name: "pauseResume")
        resumeBtn.position = CGPoint(x: centerX, y: centerY + 90)
        resumeBtn.alpha = 0
        root.addChild(resumeBtn)

        let saveBtn = PixelUI.makeButton(String(localized: "pause.save"),
            size: CGSize(width: 200, height: 48),
            fill: SKColor(red: 0.06, green: 0.06, blue: 0.18, alpha: 1),
            accent: SKColor(red: 0.30, green: 0.45, blue: 0.80, alpha: 1),
            fontSize: 20, name: "pauseSave")
        saveBtn.position = CGPoint(x: centerX, y: centerY + 32)
        saveBtn.alpha = 0
        root.addChild(saveBtn)

        let optionsBtn = PixelUI.makeButton(String(localized: "pause.options"),
            size: CGSize(width: 200, height: 48),
            fill: SKColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1),
            accent: Palette.panelBorder,
            fontSize: 20, name: "pauseOptions")
        optionsBtn.position = CGPoint(x: centerX, y: centerY - 84)
        optionsBtn.alpha = 0
        root.addChild(optionsBtn)

        // Arbre de l'Aether — pastille dorée quand des points dorment.
        let skillsBtn = PixelUI.makeButton(String(localized: "pause.skills"),
            size: CGSize(width: 200, height: 48),
            fill: SKColor(red: 0.10, green: 0.07, blue: 0.18, alpha: 1),
            accent: Palette.aether,
            fontSize: 20, name: "pauseSkills")
        skillsBtn.position = CGPoint(x: centerX, y: centerY - 26)
        skillsBtn.alpha = 0
        if pendingSkillPoints > 0 {
            let badge = SKShapeNode()
            PixelUI.stylePanel(badge, size: CGSize(width: 26, height: 20),
                               fill: SKColor(red: 0.20, green: 0.14, blue: 0.04, alpha: 1),
                               accent: PixelUI.gold)
            badge.position = CGPoint(x: 84, y: 0)
            let count = SKLabelNode(fontNamed: PixelUI.uiFont)
            count.text = "\(pendingSkillPoints)"
            count.fontSize = 15
            count.fontColor = PixelUI.gold
            count.verticalAlignmentMode = .center
            count.horizontalAlignmentMode = .center
            badge.addChild(count)
            skillsBtn.addChild(badge)
        }
        root.addChild(skillsBtn)

        let menuBtn = PixelUI.makeButton(String(localized: "pause.mainMenu"),
            size: CGSize(width: 200, height: 48),
            fill: SKColor(red: 0.12, green: 0.06, blue: 0.06, alpha: 1),
            accent: SKColor(red: 0.55, green: 0.20, blue: 0.20, alpha: 0.9),
            fontSize: 20, name: "pauseMenu")
        menuBtn.position = CGPoint(x: centerX, y: centerY - 142)
        menuBtn.alpha = 0
        root.addChild(menuBtn)

        // Débloquer le jeu complet — uniquement pour les joueurs de l'Acte I.
        var unlockBtn: SKNode?
        if showsUnlockButton {
            let btn = PixelUI.makeButton(String(localized: "pause.unlock"),
                size: CGSize(width: 200, height: 48),
                fill: SKColor(red: 0.16, green: 0.12, blue: 0.05, alpha: 1),
                accent: PixelUI.gold,
                fontSize: 20, name: "pauseUnlock")
            btn.position = CGPoint(x: centerX, y: centerY - 200)
            btn.alpha = 0
            root.addChild(btn)
            unlockBtn = btn
        }

        // Animate
        let fadeIn = SKAction.fadeIn(withDuration: 0.25)
        panel.run(fadeIn)
        title.run(fadeIn)
        resumeBtn.run(.sequence([.wait(forDuration: 0.08), fadeIn]))
        saveBtn.run(.sequence([.wait(forDuration: 0.14), fadeIn]))
        skillsBtn.run(.sequence([.wait(forDuration: 0.18), fadeIn]))
        optionsBtn.run(.sequence([.wait(forDuration: 0.20), fadeIn]))
        let ready = SKAction.run { [weak self] in self?.buttonsReady = true }
        if let unlockBtn {
            menuBtn.run(.sequence([.wait(forDuration: 0.22), fadeIn]))
            unlockBtn.run(.sequence([.wait(forDuration: 0.26), fadeIn, ready]))
        } else {
            menuBtn.run(.sequence([.wait(forDuration: 0.22), fadeIn, ready]))
        }

        // iPad : agrandit l'overlay (centre fixe). iPhone → facteur 1.
        UIScale.apply(to: root, sceneSize: scene.size)
        AccessibilitySettings.announce(String(localized: "pause.title"))
    }

    func hide() {
        root.isHidden = true
        root.removeAllChildren()
        buttonsReady = false
    }

    /// Bouton B : reprendre la partie (équivalent de « Reprendre »).
    func dismiss() { onResume?() }

    // Curseur (contrôles classiques) sur les boutons du menu pause.
    // « Débloquer » n'entre dans le cycle que s'il est affiché.
    private var selection = 0
    private var buttonNames: [String] {
        let base = ["pauseResume", "pauseSave", "pauseSkills", "pauseOptions", "pauseMenu"]
        return showsUnlockButton ? base + ["pauseUnlock"] : base
    }

    /// Joystick haut/bas : déplace le curseur.
    func moveSelection(_ dy: Int) {
        guard isActive, buttonsReady else { return }
        selection = (selection - dy + buttonNames.count) % buttonNames.count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshSelectionHighlight()
        announceSelection()
    }

    /// VoiceOver : annonce le bouton sous le curseur.
    private func announceSelection() {
        guard let btn = root.childNode(withName: buttonNames[selection]),
              let lbl = btn.children.compactMap({ $0 as? SKLabelNode }).first else { return }
        AccessibilitySettings.announce(lbl.text ?? "")
    }

    /// Bouton A : active le bouton sélectionné.
    func confirmSelection() {
        guard isActive, buttonsReady else { return }
        switch buttonNames[selection] {
        case "pauseResume": onResume?()
        case "pauseSave": onSave?()
        case "pauseSkills": onSkills?()
        case "pauseOptions": onOptions?()
        case "pauseMenu": onMainMenu?()
        case "pauseUnlock": onUnlock?()
        default: break
        }
    }

    func resetSelection() {
        selection = 0
        refreshSelectionHighlight()
    }

    private func refreshSelectionHighlight() {
        for (i, name) in buttonNames.enumerated() {
            guard let btn = root.childNode(withName: name) as? SKShapeNode else { continue }
            // Mémorise la bordure d'origine pour la restaurer à la désélection
            if btn.userData?["origStroke"] == nil {
                btn.userData = btn.userData ?? [:]
                btn.userData?["origStroke"] = btn.strokeColor
            }
            let selected = i == selection
            btn.lineWidth = selected ? 3 : 2
            btn.setScale(selected ? 1.04 : 1.0)
            if selected {
                btn.strokeColor = PixelUI.gold
            } else if let orig = btn.userData?["origStroke"] as? SKColor {
                btn.strokeColor = orig
            }
        }
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, buttonsReady else { return isActive }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "pauseResume") as? SKShapeNode,
           btn.contains(local) {
            onResume?()
            return true
        }
        if let btn = root.childNode(withName: "pauseSave") as? SKShapeNode,
           btn.contains(local) {
            onSave?()
            return true
        }
        if let btn = root.childNode(withName: "pauseSkills") as? SKShapeNode,
           btn.contains(local) {
            onSkills?()
            return true
        }
        if let btn = root.childNode(withName: "pauseOptions") as? SKShapeNode,
           btn.contains(local) {
            onOptions?()
            return true
        }
        if let btn = root.childNode(withName: "pauseUnlock") as? SKShapeNode,
           btn.contains(local) {
            onUnlock?()
            return true
        }
        if let btn = root.childNode(withName: "pauseMenu") as? SKShapeNode,
           btn.contains(local) {
            onMainMenu?()
            return true
        }
        return true
    }

}
