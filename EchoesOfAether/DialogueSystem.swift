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
    private let speakerLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let bodyLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let continueIndicator = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var choiceNodes: [SKShapeNode] = []
    private var steps: [DialogueStep] = []
    private var index = 0
    private var pendingNPC: (speaker: String, text: String)?
    private var completion: (() -> Void)?

    private let panelHeightLine: CGFloat = 170
    private let panelHeightChoices: CGFloat = 310
    private var safeBottom: CGFloat = 0

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_000
        root.isHidden = true
        scene.addChild(root)

        panel.fillColor = SKColor(white: 0.06, alpha: 0.94)
        panel.strokeColor = SKColor(red: 0.52, green: 0.48, blue: 0.86, alpha: 1)
        panel.lineWidth = 2
        root.addChild(panel)

        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.fontSize = 18
        speakerLabel.fontColor = .white
        root.addChild(speakerLabel)

        bodyLabel.horizontalAlignmentMode = .left
        bodyLabel.verticalAlignmentMode = .top
        bodyLabel.fontSize = 15
        bodyLabel.fontColor = SKColor(white: 0.92, alpha: 1)
        bodyLabel.numberOfLines = 0
        root.addChild(bodyLabel)

        continueIndicator.text = "▼"
        continueIndicator.fontSize = 14
        continueIndicator.fontColor = SKColor(white: 0.5, alpha: 1)
        continueIndicator.horizontalAlignmentMode = .right
        continueIndicator.isHidden = true
        root.addChild(continueIndicator)
        JuiceEngine.pulse(continueIndicator, scale: 1.3)

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

        let baseY = panelHeight / 2 + 20 + safeBottom
        root.position = CGPoint(x: size.width / 2, y: baseY)
        speakerLabel.position = CGPoint(x: -panelWidth / 2 + 22, y: panelHeight / 2 - 30)
        bodyLabel.position = CGPoint(x: -panelWidth / 2 + 22, y: panelHeight / 2 - 52)
        bodyLabel.preferredMaxLayoutWidth = panelWidth - 44

        continueIndicator.position = CGPoint(x: panelWidth / 2 - 18, y: -panelHeight / 2 + 14)

        layoutChoices(panelWidth: panelWidth, panelHeight: panelHeight)
    }

    func start(_ steps: [DialogueStep], completion: (() -> Void)? = nil) {
        self.steps = steps
        self.index = 0
        self.pendingNPC = nil
        self.completion = completion
        root.isHidden = false
        showCurrentStep()
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
            speakerLabel.text = String(localized: "dialogue.kael")
            bodyLabel.text = title
            continueIndicator.isHidden = false
            layout(in: scene.size, safeBottom: safeBottom)
            return true
        }

        // Phase 2 : Kael a parlé → NPC réagit
        if let npc = pendingNPC {
            pendingNPC = nil
            speakerLabel.text = npc.speaker
            bodyLabel.text = npc.text
            continueIndicator.isHidden = false
            layout(in: scene.size, safeBottom: safeBottom)
            index += 1
            return true
        }

        // Phase normale : avancer
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
            bodyLabel.text = text
            continueIndicator.isHidden = false

        case let .choice(prompt, options):
            speakerLabel.text = prompt
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
            button.fillColor = SKColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 1)
            button.strokeColor = SKColor(red: 0.42, green: 0.38, blue: 0.68, alpha: 1)
            button.lineWidth = 1.5
            button.userData = [
                "title": option.title,
                "responseSpeaker": option.responseSpeaker,
                "response": option.response
            ]

            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = option.title
            label.fontSize = 14
            label.fontColor = .white
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = buttonWidth - 28
            label.verticalAlignmentMode = .center
            button.addChild(label)

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
