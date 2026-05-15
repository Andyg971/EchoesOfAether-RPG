import SpriteKit

final class GameScene: SKScene {
    private enum Phase {
        case wake
        case village
        case forest
        case shrine
        case complete
    }

    private let kael = SKShapeNode(rectOf: CGSize(width: 34, height: 44), cornerRadius: 8)
    private let lyra = SKShapeNode(circleOfRadius: 20)
    private let dorin = SKShapeNode(circleOfRadius: 22)
    private let objectiveLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let dialogue = DialogueSystem()
    private let combat = CombatSystem()

    private var phase: Phase = .wake
    private var lastUpdate: TimeInterval = 0
    private var resonanceTotal = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
        buildWorld()
        dialogue.attach(to: self)
        startWakeSequence()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutWorld()
        dialogue.layout(in: size)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        combat.update(deltaTime: delta)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }

        if dialogue.handleTap(at: point, in: self) { return }
        if combat.handleTap(at: point, in: self) { return }

        handleExplorationTap(point)
    }

    private func buildWorld() {
        addBackdrop()

        kael.fillColor = SKColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1)
        kael.strokeColor = SKColor(red: 0.58, green: 0.52, blue: 0.94, alpha: 1)
        kael.lineWidth = 3
        addChild(kael)

        lyra.fillColor = SKColor(red: 0.14, green: 0.55, blue: 0.43, alpha: 1)
        lyra.strokeColor = .white.withAlphaComponent(0.5)
        addChild(lyra)

        dorin.fillColor = SKColor(red: 0.72, green: 0.58, blue: 0.32, alpha: 1)
        dorin.strokeColor = .white.withAlphaComponent(0.5)
        addChild(dorin)

        objectiveLabel.fontSize = 14
        objectiveLabel.fontColor = .white
        objectiveLabel.horizontalAlignmentMode = .left
        addChild(objectiveLabel)

        resonanceLabel.fontSize = 13
        resonanceLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        resonanceLabel.horizontalAlignmentMode = .right
        addChild(resonanceLabel)

        layoutWorld()
    }

    private func addBackdrop() {
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.13, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        addChild(ground)

        for index in 0..<18 {
            let radius = CGFloat(22 + (index % 4) * 8)
            let stone = SKShapeNode(circleOfRadius: radius)
            stone.fillColor = SKColor(white: 0.12 + CGFloat(index % 3) * 0.02, alpha: 1)
            stone.strokeColor = .clear
            stone.position = CGPoint(x: CGFloat(60 + index * 73), y: CGFloat(90 + (index * 97) % 360))
            stone.zPosition = -5
            addChild(stone)
        }
    }

    private func layoutWorld() {
        kael.position = CGPoint(x: size.width * 0.18, y: size.height * 0.44)
        lyra.position = CGPoint(x: size.width * 0.34, y: size.height * 0.52)
        dorin.position = CGPoint(x: size.width * 0.68, y: size.height * 0.52)
        objectiveLabel.position = CGPoint(x: 24, y: size.height - 88)
        resonanceLabel.position = CGPoint(x: size.width - 24, y: size.height - 88)
        updateHUD()
    }

    private func startWakeSequence() {
        phase = .wake
        objectiveLabel.text = "Objectif: Lyra"
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            self?.phase = .village
            self?.objectiveLabel.text = "Objectif: Dorin"
        }
    }

    private func handleExplorationTap(_ point: CGPoint) {
        switch phase {
        case .wake:
            return

        case .village:
            if point.distance(to: dorin.position) < 90 {
                dialogue.start(PrototypeContent.dorinDialogue) { [weak self] in
                    self?.phase = .forest
                    self?.objectiveLabel.text = "Objectif: lisière sombre"
                    guard let size = self?.size else { return }
                    self?.moveKael(to: CGPoint(x: size.width * 0.5, y: size.height * 0.45))
                }
            } else {
                moveKael(to: point)
            }

        case .forest:
            if point.x > size.width * 0.68 {
                startForestCombat()
            } else {
                moveKael(to: point)
            }

        case .shrine:
            if point.x > size.width * 0.62 {
                startShrineCombat()
            } else {
                moveKael(to: point)
            }

        case .complete:
            moveKael(to: point)
        }
    }

    private func startForestCombat() {
        objectiveLabel.text = "Combat: charge l'ATB"
        combat.attach(to: self, enemyName: "Bête corrompue", enemyHP: 150) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            updateHUD()
            dialogue.start(PrototypeContent.blackAetherDialogue) { [weak self] in
                self?.phase = .shrine
                self?.objectiveLabel.text = "Objectif: sanctuaire"
            }
        }
    }

    private func startShrineCombat() {
        objectiveLabel.text = "Mini-boss: pouvoir interdit"
        combat.attach(to: self, enemyName: "Gardien fêlé", enemyHP: 260) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            updateHUD()
            dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                self?.phase = .complete
                self?.objectiveLabel.text = "Fin V1: trahison amorcée"
            }
        }
    }

    private func moveKael(to point: CGPoint) {
        let clamped = CGPoint(
            x: min(max(point.x, 34), size.width - 34),
            y: min(max(point.y, 86), size.height - 44)
        )
        kael.removeAction(forKey: "move")
        kael.run(.move(to: clamped, duration: 0.35), withKey: "move")
    }

    private func updateHUD() {
        resonanceLabel.text = "Résonance noire: \(resonanceTotal)"
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
