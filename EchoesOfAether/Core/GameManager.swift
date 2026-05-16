import SpriteKit

@MainActor
final class GameManager {
    private(set) var state: GameState = .exploration
    private(set) var phase: GamePhase = .wake

    let world = WorldBuilder()
    let hud = HUDOverlay()
    let dialogue = DialogueSystem()
    let combat = CombatSystem()
    let movement = MovementController()

    private weak var scene: SKScene?
    private var resonanceTotal = 0

    func setup(scene: SKScene) {
        self.scene = scene
        world.build(in: scene)
        hud.attach(to: scene)
        dialogue.attach(to: scene)
        startWakeSequence()
    }

    func layout(size: CGSize, safeTop: CGFloat) {
        world.layout(in: size)
        hud.layout(in: size, safeTop: safeTop)
        dialogue.layout(in: size)
    }

    func update(deltaTime: TimeInterval) {
        combat.update(deltaTime: deltaTime)
    }

    func handleTap(at point: CGPoint, in scene: SKScene) {
        if state == .dialogue, dialogue.handleTap(at: point, in: scene) { return }
        if state == .combat, combat.handleTap(at: point, in: scene) { return }

        guard state == .exploration else { return }
        handleExplorationTap(point)
    }

    // MARK: - Story Flow

    private func startWakeSequence() {
        transition(to: .dialogue)
        phase = .wake
        hud.objectiveText = "Objectif: Lyra"
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            guard let self else { return }
            phase = .village
            hud.objectiveText = "Objectif: Dorin"
            transition(to: .exploration)
        }
    }

    private func handleExplorationTap(_ point: CGPoint) {
        guard let scene else { return }

        switch phase {
        case .wake:
            return

        case .village:
            if point.distance(to: world.dorin.position) < 90 {
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.dorinDialogue) { [weak self] in
                    guard let self, let scene = self.scene else { return }
                    transition(to: .transition)
                    TransitionManager.fade(in: scene) { [weak self] in
                        guard let self else { return }
                        phase = .forest
                        hud.objectiveText = "Objectif: lisière sombre"
                        scene.backgroundColor = SKColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1)
                    } completion: { [weak self] in
                        guard let self else { return }
                        transition(to: .exploration)
                        movement.move(world.kael, to: CGPoint(
                            x: scene.size.width * 0.5,
                            y: scene.size.height * 0.45
                        ), in: scene.size)
                    }
                }
            } else {
                tapAndMove(point, in: scene)
            }

        case .forest:
            if point.x > scene.size.width * 0.68 {
                startForestCombat()
            } else {
                tapAndMove(point, in: scene)
            }

        case .shrine:
            if point.x > scene.size.width * 0.62 {
                startShrineCombat()
            } else {
                tapAndMove(point, in: scene)
            }

        case .complete:
            tapAndMove(point, in: scene)
        }
    }

    private func tapAndMove(_ point: CGPoint, in scene: SKScene) {
        movement.move(world.kael, to: point, in: scene.size)
        scene.addChild(ParticleFactory.tapMarker(at: point))
    }

    private func startForestCombat() {
        guard let scene else { return }
        transition(to: .combat)
        hud.objectiveText = "Combat: charge l'ATB"
        combat.attach(to: scene, enemyName: "Bête corrompue", enemyHP: 150) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            hud.resonanceValue = resonanceTotal
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.blackAetherDialogue) { [weak self] in
                guard let self, let scene = self.scene else { return }
                transition(to: .transition)
                TransitionManager.fade(in: scene) { [weak self] in
                    guard let self else { return }
                    phase = .shrine
                    hud.objectiveText = "Objectif: sanctuaire"
                    scene.backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
                } completion: { [weak self] in
                    self?.transition(to: .exploration)
                }
            }
        }
    }

    private func startShrineCombat() {
        guard let scene else { return }
        transition(to: .combat)
        hud.objectiveText = "Mini-boss: pouvoir interdit"
        combat.attach(to: scene, enemyName: "Gardien fêlé", enemyHP: 260) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            hud.resonanceValue = resonanceTotal
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                guard let self, let scene = self.scene else { return }
                phase = .complete
                hud.objectiveText = "Fin V1: trahison amorcée"
                transition(to: .exploration)
                TransitionManager.showEndScreen(in: scene, resonance: resonanceTotal)
            }
        }
    }

    private func transition(to newState: GameState) {
        state = newState
    }
}
