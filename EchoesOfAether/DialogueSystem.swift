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
    private let panelAccent = SKShapeNode()        // bande accent à gauche
    private let separator = SKShapeNode()          // trait fin sous le nom
    private let portraitBack = SKShapeNode()       // cercle avatar
    private let portraitInitial = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let speakerLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let bodyLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let continueIndicator = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var choiceNodes: [SKShapeNode] = []
    private var steps: [DialogueStep] = []
    private var index = 0
    private var pendingNPC: (speaker: String, text: String)?
    private var completion: (() -> Void)?
    private var hasAnimatedEntrance = false

    private let panelHeightLine: CGFloat = 186
    private let panelHeightChoices: CGFloat = 326
    private var safeBottom: CGFloat = 0
    private let portraitRadius: CGFloat = 26

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_000
        root.isHidden = true
        scene.addChild(root)

        panel.fillColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.96)
        panel.strokeColor = SKColor(red: 0.52, green: 0.48, blue: 0.86, alpha: 1)
        panel.lineWidth = 2
        root.addChild(panel)

        panelAccent.fillColor = SKColor(red: 0.55, green: 0.30, blue: 0.92, alpha: 0.85)
        panelAccent.strokeColor = .clear
        root.addChild(panelAccent)

        portraitBack.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1)
        portraitBack.strokeColor = SKColor(red: 0.55, green: 0.30, blue: 0.92, alpha: 0.9)
        portraitBack.lineWidth = 2
        portraitBack.path = CGPath(ellipseIn: CGRect(x: -portraitRadius, y: -portraitRadius,
                                                       width: portraitRadius * 2,
                                                       height: portraitRadius * 2),
                                   transform: nil)
        root.addChild(portraitBack)

        portraitInitial.fontSize = 22
        portraitInitial.fontColor = .white
        portraitInitial.verticalAlignmentMode = .center
        portraitInitial.horizontalAlignmentMode = .center
        root.addChild(portraitInitial)

        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.fontSize = 19
        speakerLabel.fontColor = .white
        root.addChild(speakerLabel)

        separator.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.70, alpha: 0.5)
        separator.lineWidth = 1
        root.addChild(separator)

        bodyLabel.horizontalAlignmentMode = .left
        bodyLabel.verticalAlignmentMode = .top
        bodyLabel.fontSize = 16
        bodyLabel.fontColor = SKColor(white: 0.94, alpha: 1)
        bodyLabel.numberOfLines = 0
        root.addChild(bodyLabel)

        continueIndicator.text = "▼"
        continueIndicator.fontSize = 16
        continueIndicator.fontColor = SKColor(red: 0.65, green: 0.55, blue: 0.95, alpha: 0.9)
        continueIndicator.horizontalAlignmentMode = .right
        continueIndicator.isHidden = true
        root.addChild(continueIndicator)
        JuiceEngine.pulse(continueIndicator, scale: 1.15)

        layout(in: scene.size)
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        self.safeBottom = safeBottom
        let hasChoices = !choiceNodes.isEmpty
        let panelHeight = hasChoices ? panelHeightChoices : panelHeightLine
        let panelWidth = min(size.width - 32, 720)

        panel.path = CGPath(
            roundedRect: CGRect(x: -panelWidth / 2, y: -panelHeight / 2,
                                width: panelWidth, height: panelHeight),
            cornerWidth: 18, cornerHeight: 18, transform: nil
        )

        // Bande accent verticale (4pt) le long du bord gauche du panneau
        let accentRect = CGRect(x: -panelWidth / 2, y: -panelHeight / 2,
                                 width: 4, height: panelHeight)
        panelAccent.path = CGPath(roundedRect: accentRect, cornerWidth: 2,
                                   cornerHeight: 2, transform: nil)

        let baseY = panelHeight / 2 + 20 + safeBottom
        root.position = CGPoint(x: size.width / 2, y: baseY)

        // Portrait : coin haut-gauche, légèrement au-dessus du panneau
        let portraitX = -panelWidth / 2 + portraitRadius + 16
        let portraitY = panelHeight / 2 - portraitRadius - 8
        portraitBack.position = CGPoint(x: portraitX, y: portraitY)
        portraitInitial.position = CGPoint(x: portraitX, y: portraitY)

        let textX = portraitX + portraitRadius + 14
        speakerLabel.position = CGPoint(x: textX, y: panelHeight / 2 - 28)

        // Trait séparateur sous le nom (s'étend jusqu'au bord droit)
        let sepY = panelHeight / 2 - 48
        let sepPath = CGMutablePath()
        sepPath.move(to: CGPoint(x: textX, y: sepY))
        sepPath.addLine(to: CGPoint(x: panelWidth / 2 - 22, y: sepY))
        separator.path = sepPath

        bodyLabel.position = CGPoint(x: -panelWidth / 2 + 22, y: sepY - 14)
        bodyLabel.preferredMaxLayoutWidth = panelWidth - 44

        continueIndicator.position = CGPoint(x: panelWidth / 2 - 18, y: -panelHeight / 2 + 16)

        layoutChoices(panelWidth: panelWidth, panelHeight: panelHeight)
    }

    func start(_ steps: [DialogueStep], completion: (() -> Void)? = nil) {
        self.steps = steps
        self.index = 0
        self.pendingNPC = nil
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

    private func applyPortrait(for speaker: String) {
        let color = portraitColor(for: speaker)
        portraitBack.fillColor = color.withAlphaComponent(0.85)
        portraitBack.strokeColor = color
        portraitInitial.text = String(speaker.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
        // Petit "pop" quand le speaker change
        portraitBack.run(.sequence([
            .scale(to: 1.15, duration: 0.08),
            .scale(to: 1.0, duration: 0.14)
        ]))
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, !root.isHidden else { return false }

        let localPoint = root.convert(point, from: scene)

        // Phase 1 : joueur tape un choix → Kael parle
        for node in choiceNodes where node.contains(localPoint) {
            guard let title = node.userData?["title"] as? String,
                  let npcSpeaker = node.userData?["responseSpeaker"] as? String,
                  let npcText = node.userData?["response"] as? String else { continue }
            pendingNPC = (speaker: npcSpeaker, text: npcText)
            clearChoices()
            let kaelName = String(localized: "dialogue.kael")
            speakerLabel.text = kaelName
            applyPortrait(for: kaelName)
            bodyLabel.text = title
            continueIndicator.isHidden = false
            AudioEngine.shared.playSelect()
            layout(in: scene.size, safeBottom: safeBottom)
            return true
        }

        // Phase 2 : Kael a parlé → NPC réagit
        if let npc = pendingNPC {
            pendingNPC = nil
            speakerLabel.text = npc.speaker
            applyPortrait(for: npc.speaker)
            bodyLabel.text = npc.text
            continueIndicator.isHidden = false
            AudioEngine.shared.playTap()
            layout(in: scene.size, safeBottom: safeBottom)
            index += 1
            return true
        }

        // Phase normale : avancer
        AudioEngine.shared.playTap()
        index += 1
        showCurrentStep()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
        return true
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
            speakerLabel.text = prompt
            applyPortrait(for: prompt)
            bodyLabel.text = String(localized: "dialogue.chooseResponse")
            continueIndicator.isHidden = true
            createChoices(options)
        }
    }

    private func createChoices(_ options: [DialogueChoice]) {
        guard let sceneRef = root.scene else { return }
        let panelWidth = min(sceneRef.size.width - 32, 720)
        let buttonWidth = panelWidth - 44
        let buttonHeight: CGFloat = 52

        for (offset, option) in options.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 14)
            button.fillColor = SKColor(red: 0.12, green: 0.10, blue: 0.20, alpha: 1)
            button.strokeColor = SKColor(red: 0.55, green: 0.42, blue: 0.92, alpha: 1)
            button.lineWidth = 1.8
            button.userData = [
                "title": option.title,
                "responseSpeaker": option.responseSpeaker,
                "response": option.response
            ]

            // Marge intérieure : point de couleur à gauche
            let bullet = SKShapeNode(circleOfRadius: 4)
            bullet.fillColor = SKColor(red: 0.65, green: 0.45, blue: 1, alpha: 1)
            bullet.strokeColor = .clear
            bullet.glowWidth = 3
            bullet.position = CGPoint(x: -buttonWidth / 2 + 16, y: 0)
            button.addChild(bullet)

            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = option.title
            label.fontSize = 15
            label.fontColor = .white
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = buttonWidth - 56
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -buttonWidth / 2 + 28, y: 0)
            button.addChild(label)

            // Chevron à droite
            let chevron = SKLabelNode(fontNamed: "AvenirNext-Medium")
            chevron.text = "›"
            chevron.fontSize = 22
            chevron.fontColor = SKColor(red: 0.65, green: 0.55, blue: 0.95, alpha: 0.8)
            chevron.verticalAlignmentMode = .center
            chevron.horizontalAlignmentMode = .right
            chevron.position = CGPoint(x: buttonWidth / 2 - 14, y: 0)
            button.addChild(chevron)

            let yOffset = -CGFloat(offset) * (buttonHeight + 10)
            button.position = CGPoint(x: 0, y: yOffset - 60)

            root.addChild(button)
            choiceNodes.append(button)

            JuiceEngine.popIn(button, delay: Double(offset) * 0.06)
        }
    }

    private func layoutChoices(panelWidth: CGFloat, panelHeight: CGFloat) {
        guard !choiceNodes.isEmpty else { return }
        let buttonHeight: CGFloat = 52
        let startY = panelHeight / 2 - 90

        for (offset, node) in choiceNodes.enumerated() {
            node.position = CGPoint(x: 0, y: startY - CGFloat(offset) * (buttonHeight + 10))
        }
    }

    private func clearChoices() {
        choiceNodes.forEach { $0.removeFromParent() }
        choiceNodes.removeAll()
    }
}
