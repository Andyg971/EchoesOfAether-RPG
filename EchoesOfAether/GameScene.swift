import SpriteKit

final class GameScene: SKScene {
    private enum Phase {
        case wake
        case village
        case forest
        case shrine
        case complete
    }

    private let world = WorldBuilder()
    private let hud = HUDOverlay()
    private let dialogue = DialogueSystem()
    private let combat = CombatSystem()

    private var phase: Phase = .wake
    private var lastUpdate: TimeInterval = 0
    private var resonanceTotal = 0
    var safeAreaTop: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
        world.build(in: self)
        hud.attach(to: self)
        dialogue.attach(to: self)
        startWakeSequence()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        world.layout(in: size)
        hud.layout(in: size, safeTop: safeAreaTop)
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

    private func startWakeSequence() {
        phase = .wake
        hud.objectiveText = "Objectif: Lyra"
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            self?.phase = .village
            self?.hud.objectiveText = "Objectif: Dorin"
        }
    }

    private func handleExplorationTap(_ point: CGPoint) {
        switch phase {
        case .wake:
            return

        case .village:
            if point.distance(to: world.dorin.position) < 90 {
                dialogue.start(PrototypeContent.dorinDialogue) { [weak self] in
                    guard let self else { return }
                    phase = .forest
                    hud.objectiveText = "Objectif: lisière sombre"
                    moveKael(to: CGPoint(x: size.width * 0.5, y: size.height * 0.45))
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
        hud.objectiveText = "Combat: charge l'ATB"
        combat.attach(to: self, enemyName: "Bête corrompue", enemyHP: 150) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            hud.resonanceValue = resonanceTotal
            dialogue.start(PrototypeContent.blackAetherDialogue) { [weak self] in
                self?.phase = .shrine
                self?.hud.objectiveText = "Objectif: sanctuaire"
            }
        }
    }

    private func startShrineCombat() {
        hud.objectiveText = "Mini-boss: pouvoir interdit"
        combat.attach(to: self, enemyName: "Gardien fêlé", enemyHP: 260) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            hud.resonanceValue = resonanceTotal
            dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                self?.phase = .complete
                self?.hud.objectiveText = "Fin V1: trahison amorcée"
            }
        }
    }

    private func moveKael(to point: CGPoint) {
        let clamped = CGPoint(
            x: min(max(point.x, 34), size.width - 34),
            y: min(max(point.y, 86), size.height - 44)
        )
        world.kael.removeAction(forKey: "move")
        let distance = world.kael.position.distance(to: clamped)
        let duration = max(0.15, TimeInterval(distance / 280))
        world.kael.run(.move(to: clamped, duration: duration), withKey: "move")
        addChild(ParticleFactory.tapMarker(at: point))
    }
}
