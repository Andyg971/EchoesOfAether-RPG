import SpriteKit

struct DialogueChoice {
    let title: String
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
    private var choiceNodes: [SKShapeNode] = []
    private var steps: [DialogueStep] = []
    private var index = 0
    private var pendingResponse: String?
    private var completion: (() -> Void)?

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

        layout(in: scene.size)
    }

    func layout(in size: CGSize) {
        let panelWidth = min(size.width - 48, 720)
        let panelHeight: CGFloat = 170
        panel.path = CGPath(
            roundedRect: CGRect(x: -panelWidth / 2, y: -panelHeight / 2, width: panelWidth, height: panelHeight),
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )
        root.position = CGPoint(x: size.width / 2, y: 110)
        speakerLabel.position = CGPoint(x: -panelWidth / 2 + 22, y: 54)
        bodyLabel.position = CGPoint(x: -panelWidth / 2 + 22, y: 25)
        bodyLabel.preferredMaxLayoutWidth = panelWidth - 44
        layoutChoices(panelWidth: panelWidth)
    }

    func start(_ steps: [DialogueStep], completion: (() -> Void)? = nil) {
        self.steps = steps
        self.index = 0
        self.pendingResponse = nil
        self.completion = completion
        root.isHidden = false
        showCurrentStep()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, !root.isHidden else { return false }

        let localPoint = root.convert(point, from: scene)
        for node in choiceNodes where node.contains(localPoint) {
            guard let response = node.userData?["response"] as? String else { continue }
            pendingResponse = response
            clearChoices()
            speakerLabel.text = "Réponse"
            bodyLabel.text = response
            index += 1
            return true
        }

        if pendingResponse != nil {
            pendingResponse = nil
            showCurrentStep()
            return true
        }

        index += 1
        showCurrentStep()
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

        case let .choice(prompt, options):
            speakerLabel.text = prompt
            bodyLabel.text = "Choisis comment Kael répond."
            createChoices(options)
        }
    }

    private func createChoices(_ options: [DialogueChoice]) {
        for (offset, option) in options.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: 205, height: 42), cornerRadius: 12)
            button.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
            button.strokeColor = SKColor(red: 0.36, green: 0.34, blue: 0.62, alpha: 1)
            button.position = CGPoint(x: CGFloat(offset - 1) * 220, y: -48)
            button.userData = ["response": option.response]

            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = option.title
            label.fontSize = 11
            label.fontColor = .white
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = 185
            label.verticalAlignmentMode = .center
            button.addChild(label)

            root.addChild(button)
            choiceNodes.append(button)
        }
    }

    private func layoutChoices(panelWidth: CGFloat) {
        guard !choiceNodes.isEmpty else { return }
        for (offset, node) in choiceNodes.enumerated() {
            node.position = CGPoint(x: CGFloat(offset - 1) * min(220, panelWidth / 3.3), y: -48)
        }
    }

    private func clearChoices() {
        choiceNodes.forEach { $0.removeFromParent() }
        choiceNodes.removeAll()
    }
}
