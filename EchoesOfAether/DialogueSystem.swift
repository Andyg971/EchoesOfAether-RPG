import SpriteKit

struct DialogueChoice {
    let title: String
    let responseSpeaker: String
    let response: String
}

enum DialogueStep {
    case line(speaker: String, text: String)
    case choice(prompt: String, options: [DialogueChoice])
}

@MainActor
final class DialogueSystem {
    private let root = SKNode()
    private let panel = SKShapeNode()
    private let separator = SKShapeNode()          // trait fin sous le nom
    private let portraitFrame = SKShapeNode()      // cadre pixel du portrait
    private let portraitSprite = SKSpriteNode()    // visage du locuteur
    private var hasPortrait = false
    private let speakerLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let bodyLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let continueIndicator = SKLabelNode(fontNamed: PixelUI.uiFont)
    private var choiceNodes: [SKShapeNode] = []
    private var choiceSelection = 0   // curseur sur les choix (A valide)
    private var steps: [DialogueStep] = []
    private var index = 0
    private var pendingNPC: (speaker: String, text: String)?
    private var completion: (() -> Void)?
    private var hasAnimatedEntrance = false

    /// Index du dernier choix sélectionné dans une étape `.choice` (nil tant
    /// qu'aucun choix n'a été fait). Permet de rendre un choix déterminant.
    private(set) var lastChoiceIndex: Int?
    /// Callback déclenché quand le joueur sélectionne un choix (index 0-based).
    var onChoiceSelected: ((Int) -> Void)?

    private let panelHeightLine: CGFloat = 72
    private var safeBottom: CGFloat = 0

    /// Hauteur ajustée au contenu : en-tête (prompt) + N boutons de choix
    /// + marge basse — plus de grand vide noir sous les choix.
    private var panelHeightChoices: CGFloat {
        68 + CGFloat(max(0, choiceNodes.count - 1)) * 32
    }

    /// Largeur compacte : le panneau ne barre plus tout l'écran.
    private func panelWidth(for size: CGSize) -> CGFloat {
        min(size.width - 48, 640)
    }

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_000
        root.isHidden = true
        scene.addChild(root)

        panel.fillColor = PixelUI.panelFill
        panel.strokeColor = PixelUI.gold
        panel.lineWidth = 2
        root.addChild(panel)

        // Portrait pixel du locuteur : cadre carré à gauche du panneau
        portraitFrame.zPosition = 2
        root.addChild(portraitFrame)
        portraitSprite.texture?.filteringMode = .nearest
        portraitSprite.zPosition = 3
        root.addChild(portraitSprite)

        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.fontSize = 11
        speakerLabel.fontColor = .white
        root.addChild(speakerLabel)

        separator.strokeColor = PixelUI.goldDim
        separator.lineWidth = 1
        root.addChild(separator)

        bodyLabel.horizontalAlignmentMode = .left
        bodyLabel.verticalAlignmentMode = .top
        bodyLabel.fontSize = 10
        bodyLabel.fontColor = SKColor(white: 0.94, alpha: 1)
        bodyLabel.numberOfLines = 0
        root.addChild(bodyLabel)

        continueIndicator.text = "A ▼"
        continueIndicator.fontSize = 9
        continueIndicator.fontColor = PixelUI.gold
        continueIndicator.horizontalAlignmentMode = .right
        continueIndicator.isHidden = true
        root.addChild(continueIndicator)
        JuiceEngine.pulse(continueIndicator, scale: 1.15)

        layout(in: scene.size)
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        self.safeBottom = safeBottom
        // Accessibilité « gros texte » : agrandit les polices du dialogue.
        // VT323 est étroite : tailles relevées pour garder la lisibilité.
        let ts = AccessibilitySettings.textScale
        speakerLabel.fontSize = 15 * ts
        bodyLabel.fontSize = 14 * ts
        continueIndicator.fontSize = 12 * ts
        let hasChoices = !choiceNodes.isEmpty
        let panelHeight = hasChoices ? panelHeightChoices : panelHeightLine
        let panelWidth = panelWidth(for: size)

        // Cadre RPG pixel art (coins carrés, liseré sombre + bordure or)
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight))

        let baseY = panelHeight / 2 + 20 + safeBottom
        root.position = CGPoint(x: size.width / 2, y: baseY)

        // Portrait (44px natif) dans un cadre pixel à gauche ; le texte
        // se décale quand un visage est affiché.
        let portraitSide: CGFloat = 52
        let portraitX = -panelWidth / 2 + portraitSide / 2 + 10
        PixelUI.stylePanel(portraitFrame,
                           size: CGSize(width: portraitSide, height: portraitSide),
                           fill: SKColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1),
                           accent: PixelUI.goldDim)
        portraitFrame.position = CGPoint(x: portraitX, y: 0)
        portraitSprite.position = portraitFrame.position
        portraitSprite.size = CGSize(width: portraitSide - 8, height: portraitSide - 8)
        // En mode choix, le portrait recouvrait les boutons : on le masque.
        let showPortrait = hasPortrait && !hasChoices
        portraitFrame.isHidden = !showPortrait
        portraitSprite.isHidden = !showPortrait

        let textX = showPortrait
            ? portraitX + portraitSide / 2 + 12
            : -panelWidth / 2 + 14
        speakerLabel.position = CGPoint(x: textX, y: panelHeight / 2 - 16)

        let sepY = panelHeight / 2 - 26
        let sepPath = CGMutablePath()
        sepPath.move(to: CGPoint(x: textX, y: sepY))
        sepPath.addLine(to: CGPoint(x: panelWidth / 2 - 22, y: sepY))
        separator.path = sepPath

        bodyLabel.position = CGPoint(x: textX, y: sepY - 6)
        bodyLabel.preferredMaxLayoutWidth = panelWidth - (textX + panelWidth / 2) - 18

        continueIndicator.position = CGPoint(x: panelWidth / 2 - 18, y: -panelHeight / 2 + 16)

        layoutChoices(panelWidth: panelWidth, panelHeight: panelHeight)
    }

    func start(_ steps: [DialogueStep], completion: (() -> Void)? = nil) {
        // Audit visuel : --skip-dialogue court-circuite tout dialogue
        // (utile avec --boss-test/--fx-demo pour filmer les effets).
        if CommandLine.arguments.contains("--skip-dialogue") {
            completion?()
            return
        }
        self.steps = steps
        self.index = 0
        self.pendingNPC = nil
        self.lastChoiceIndex = nil
        self.completion = completion
        root.isHidden = false
        playEntranceAnimation()
        showCurrentStep()
    }

    private func playEntranceAnimation() {
        guard let sceneRef = root.scene else { return }
        let restY = root.position.y
        root.position = CGPoint(x: root.position.x, y: restY - 40)
        root.alpha = 0
        root.run(.group([
            .fadeIn(withDuration: 0.22),
            .move(to: CGPoint(x: sceneRef.size.width / 2, y: restY), duration: 0.28)
        ]))
        hasAnimatedEntrance = true
    }

    /// Couleur d'accent dérivée du nom du speaker — stable pour un même speaker.
    private func portraitColor(for speaker: String) -> SKColor {
        // Couleurs fixes pour les speakers principaux ; fallback via hash sinon.
        let key = speaker.lowercased()
        if key.contains("kael") {
            return SKColor(red: 0.55, green: 0.20, blue: 0.85, alpha: 1)
        }
        if key.contains("lyra") {
            return SKColor(red: 0.25, green: 0.70, blue: 0.45, alpha: 1)
        }
        if key.contains("dorin") {
            return SKColor(red: 0.85, green: 0.62, blue: 0.25, alpha: 1)
        }
        if key.contains("bram") {
            return SKColor(red: 0.70, green: 0.45, blue: 0.25, alpha: 1)
        }
        if key.contains("mara") {
            return SKColor(red: 0.30, green: 0.75, blue: 0.40, alpha: 1)
        }
        if key.contains("garen") {
            return SKColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 1)
        }
        if key.contains("sage") || key.contains("archi") {
            return SKColor(red: 0.45, green: 0.30, blue: 0.85, alpha: 1)
        }
        if key.contains("voix") || key.contains("voice") {
            return SKColor(red: 0.20, green: 0.20, blue: 0.30, alpha: 1)
        }
        // Fallback hash → teinte stable
        let hash = abs(speaker.hashValue)
        let hue = CGFloat(hash % 360) / 360
        return SKColor(hue: hue, saturation: 0.55, brightness: 0.75, alpha: 1)
    }

    /// Asset de portrait pixel par locuteur (nil = pas de visage :
    /// voix, cristal, plaque… le panneau retombe en mode texte seul).
    private func portraitAsset(for speaker: String) -> String? {
        let key = speaker.lowercased()
        let table: [(String, String)] = [
            ("kael", "portrait_kael_icon"),
            ("lyra", "portrait_lyra"),
            ("dorin", "portrait_dorin"),
            ("bram", "portrait_bram"),
            ("mara", "portrait_mara"),
            ("garen", "portrait_garen"),
            ("sage", "portrait_sage"),
            ("eran", "portrait_eran"),
            ("archiv", "portrait_archivist"),
            ("gardien", "portrait_guardian"),
            ("guardian", "portrait_guardian"),
            ("enfant", "portrait_child"),
            ("child", "portrait_child"),
            ("villageois", "portrait_villager"),
            ("villager", "portrait_villager")
        ]
        for (needle, asset) in table where key.contains(needle) { return asset }
        return nil
    }

    /// Nom teinté à la couleur du locuteur + portrait pixel si disponible.
    private func applyPortrait(for speaker: String) {
        let color = portraitColor(for: speaker)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        speakerLabel.fontColor = b < 0.6
            ? SKColor(hue: h, saturation: min(s, 0.6), brightness: 0.80, alpha: 1)
            : color

        if let asset = portraitAsset(for: speaker), UIImage(named: asset) != nil {
            let changed = portraitSprite.userData?["asset"] as? String != asset
            let texture = SKTexture(imageNamed: asset)
            texture.filteringMode = .nearest
            portraitSprite.texture = texture
            hasPortrait = true
            if changed {
                portraitSprite.userData = ["asset": asset]
                // Pop du portrait quand le locuteur change
                portraitSprite.setScale(0.82)
                portraitSprite.run(.sequence([
                    .scale(to: 1.06, duration: 0.10),
                    .scale(to: 1.0, duration: 0.10)
                ]))
            }
        } else {
            hasPortrait = false
            portraitSprite.userData = nil
        }
    }

    /// Contrôles classiques : le panneau absorbe tout tap. Les choix se
    /// naviguent au joystick (`moveChoiceSelection`) et se valident au
    /// bouton A (`advance`/`confirmChoice`), B passe (`skipToEnd`).
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        isActive && !root.isHidden
    }

    /// Joystick haut/bas : déplace le curseur sur les choix.
    func moveChoiceSelection(_ dy: Int) {
        guard isActive, !choiceNodes.isEmpty else { return }
        let count = choiceNodes.count
        choiceSelection = (choiceSelection - dy + count) % count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshChoiceHighlight()
    }

    /// Le choix sélectionné est encadré d'or, les autres estompés.
    private func refreshChoiceHighlight() {
        for (i, node) in choiceNodes.enumerated() {
            let selected = i == choiceSelection
            node.strokeColor = selected
                ? PixelUI.gold
                : SKColor(red: 0.62, green: 0.48, blue: 0.90, alpha: 0.5)
            node.alpha = selected ? 1.0 : 0.72
            node.setScale(selected ? 1.02 : 1.0)
        }
    }

    /// Bouton A pendant un choix : valide le choix sélectionné.
    func confirmChoice() {
        guard isActive, choiceNodes.indices.contains(choiceSelection) else { return }
        let node = choiceNodes[choiceSelection]
        guard let title = node.userData?["title"] as? String,
              let npcSpeaker = node.userData?["responseSpeaker"] as? String,
              let npcText = node.userData?["response"] as? String else { return }
        if let chosenIndex = node.userData?["index"] as? Int {
            lastChoiceIndex = chosenIndex
            onChoiceSelected?(chosenIndex)
        }
        pendingNPC = (speaker: npcSpeaker, text: npcText)
        clearChoices()
        let kaelName = String(localized: "dialogue.kael")
        speakerLabel.text = kaelName
        applyPortrait(for: kaelName)
        bodyLabel.text = title
        continueIndicator.isHidden = false
        AudioEngine.shared.playSelect()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    var hasChoicesOnScreen: Bool { !choiceNodes.isEmpty }

    /// Bouton A : valide le choix sélectionné s'il y en a, sinon avance
    /// d'une réplique (ou affiche la réaction du PNJ après un choix).
    func advance() {
        guard isActive else { return }
        guard choiceNodes.isEmpty else { confirmChoice(); return }

        if let npc = pendingNPC {
            pendingNPC = nil
            speakerLabel.text = npc.speaker
            applyPortrait(for: npc.speaker)
            bodyLabel.text = npc.text
            continueIndicator.isHidden = false
            AudioEngine.shared.playTap()
            if let sceneRef = root.scene {
                layout(in: sceneRef.size, safeBottom: safeBottom)
            }
            index += 1
            return
        }

        AudioEngine.shared.playTap()
        index += 1
        showCurrentStep()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    /// Bouton B : passe les répliques jusqu'au prochain CHOIX (qui exige
    /// une décision du joueur) ou jusqu'à la fin de la conversation.
    func skipToEnd() {
        guard isActive, choiceNodes.isEmpty else { return }
        AudioEngine.shared.playTap()
        pendingNPC = nil
        while index < steps.count {
            if case .choice = steps[index] { break }
            index += 1
        }
        showCurrentStep()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    private func showCurrentStep() {
        clearChoices()

        guard index < steps.count else {
            root.isHidden = true
            completion?()
            completion = nil
            return
        }

        switch steps[index] {
        case let .line(speaker, text):
            speakerLabel.text = speaker
            applyPortrait(for: speaker)
            bodyLabel.text = text
            continueIndicator.isHidden = false

        case let .choice(prompt, options):
            // Le prompt sert de titre ; pas de body label pour éviter
            // la collision avec les boutons de choix.
            speakerLabel.text = prompt
            applyPortrait(for: prompt)
            bodyLabel.text = ""
            continueIndicator.isHidden = true
            createChoices(options)
        }

        // Le portrait peut apparaître/disparaître selon le locuteur.
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    private func createChoices(_ options: [DialogueChoice]) {
        guard let sceneRef = root.scene else { return }
        let panelWidth = panelWidth(for: sceneRef.size)
        let buttonWidth = panelWidth - 28
        let buttonHeight: CGFloat = 28

        for (offset, option) in options.enumerated() {
            let button = SKShapeNode()
            PixelUI.stylePanel(button,
                               size: CGSize(width: buttonWidth, height: buttonHeight),
                               fill: SKColor(red: 0.11, green: 0.09, blue: 0.14, alpha: 1),
                               accent: SKColor(red: 0.62, green: 0.48, blue: 0.90, alpha: 1))
            button.userData = [
                "title": option.title,
                "responseSpeaker": option.responseSpeaker,
                "response": option.response,
                "index": offset
            ]

            let bullet = SKShapeNode(circleOfRadius: 3)
            bullet.fillColor = SKColor(red: 0.65, green: 0.45, blue: 1, alpha: 1)
            bullet.strokeColor = .clear
            bullet.glowWidth = 2
            bullet.position = CGPoint(x: -buttonWidth / 2 + 12, y: 0)
            button.addChild(bullet)

            let label = SKLabelNode(fontNamed: PixelUI.uiFont)
            label.text = option.title
            label.fontSize = 12 * AccessibilitySettings.textScale
            label.fontColor = .white
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = buttonWidth - 32
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -buttonWidth / 2 + 22, y: 0)
            button.addChild(label)

            let chevron = SKLabelNode(fontNamed: PixelUI.uiFont)
            chevron.text = "›"
            chevron.fontSize = 13
            chevron.fontColor = SKColor(red: 0.65, green: 0.55, blue: 0.95, alpha: 0.8)
            chevron.verticalAlignmentMode = .center
            chevron.horizontalAlignmentMode = .right
            chevron.position = CGPoint(x: buttonWidth / 2 - 10, y: 0)
            button.addChild(chevron)

            // Position provisoire — layoutChoices() replace précisément
            // dès que la hauteur dynamique du panneau est connue.
            let yOffset = -CGFloat(offset) * (buttonHeight + 4)
            button.position = CGPoint(x: 0, y: yOffset - 10)

            root.addChild(button)
            choiceNodes.append(button)

            JuiceEngine.popIn(button, delay: Double(offset) * 0.06)
        }
        choiceSelection = 0
        refreshChoiceHighlight()
    }

    private func layoutChoices(panelWidth: CGFloat, panelHeight: CGFloat) {
        guard !choiceNodes.isEmpty else { return }
        let buttonHeight: CGFloat = 28
        // Premier bouton juste sous le séparateur ; le panneau colle au
        // dernier bouton (hauteur dynamique, voir panelHeightChoices).
        let startY = panelHeight / 2 - 44

        for (offset, node) in choiceNodes.enumerated() {
            node.position = CGPoint(x: 0, y: startY - CGFloat(offset) * (buttonHeight + 4))
        }
    }

    private func clearChoices() {
        choiceNodes.forEach { $0.removeFromParent() }
        choiceNodes.removeAll()
    }
}
