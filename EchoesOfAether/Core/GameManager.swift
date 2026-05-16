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
        hud.objectiveText = String(localized: "hud.objective.lyra")
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            guard let self else { return }
            phase = .village
            hud.objectiveText = String(localized: "hud.objective.dorin")
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
                        hud.objectiveText = String(localized: "hud.objective.forest")
                        world.switchToForest(in: scene)
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
        hud.objectiveText = String(localized: "hud.objective.combat")
        combat.attach(to: scene, enemyName: String(localized: "combat.enemy.beast"), enemyHP: 150) { [weak self] resonance in
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
                    hud.objectiveText = String(localized: "hud.objective.shrine")
                    world.switchToShrine(in: scene)
                } completion: { [weak self] in
                    self?.transition(to: .exploration)
                }
            }
        }
    }

    private func startShrineCombat() {
        guard let scene else { return }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.miniboss")
        combat.attach(to: scene, enemyName: String(localized: "combat.enemy.guardian"), enemyHP: 260) { [weak self] resonance in
            guard let self else { return }
            resonanceTotal += resonance
            hud.resonanceValue = resonanceTotal
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                guard let self, let scene = self.scene else { return }
                phase = .complete
                hud.objectiveText = String(localized: "hud.objective.complete")
                transition(to: .exploration)
                TransitionManager.showEndScreen(in: scene, resonance: resonanceTotal)
            }
        }
    }

    private func transition(to newState: GameState) {
        state = newState
    }
}
