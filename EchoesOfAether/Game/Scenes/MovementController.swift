import SpriteKit

@MainActor
final class MovementController {
    private let speed: CGFloat = 280

    private(set) var isMoving = false

    func move(_ node: SKNode, to point: CGPoint, in sceneSize: CGSize) {
        let clamped = CGPoint(
            x: min(max(point.x, 34), sceneSize.width - 34),
            y: min(max(point.y, 86), sceneSize.height - 44)
        )
        let dist = node.position.distance(to: clamped)
        let duration = max(0.12, TimeInterval(dist / speed))

        isMoving = true
        AudioEngine.shared.playStep()
        startWalkAnimation(on: node, towards: clamped)
        node.removeAction(forKey: "move")
        let moveAction = SKAction.sequence([
            .move(to: clamped, duration: duration),
            .run { [weak self] in
                self?.isMoving = false
                Self.stopWalkAnimation(on: node)
            }
        ])
        node.run(moveAction, withKey: "move")
    }

    func cancel(_ node: SKNode) {
        node.removeAction(forKey: "move")
        Self.stopWalkAnimation(on: node)
        isMoving = false
    }

    /// Marche manuelle (joystick) : démarre/arrête l'animation de pas.
    /// Idempotent — appelable chaque frame pendant le drag.
    func setManualWalk(_ node: SKNode, dx: CGFloat, active: Bool) {
        guard active else { Self.stopWalkAnimation(on: node); return }
        node.removeAction(forKey: "move")   // le pad prime sur tap-to-move
        // Sprite du pack : on pilote le cycle directement. `dy: 1` marque le
        // déplacement — même en montant tout droit (dx nul), Kael marche ; il
        // garde alors la dernière orientation acquise, faute de vue de dos.
        if node.childNode(withName: "body") != nil {
            BattleSprites.updateWalk(.kael, on: node,
                                     velocity: CGVector(dx: dx, dy: 1))
            if node.action(forKey: "walkDust") == nil { startDust(on: node) }
            return
        }
        startWalkAnimation(on: node,
                           towards: CGPoint(x: node.position.x + dx * 100,
                                            y: node.position.y))
    }

    // MARK: - Animation de marche

    /// Kael dispose enfin d'un vrai cycle de marche (`move_1..6` du pack) :
    /// on le joue au lieu de simuler des pas en secouant le sprite.
    /// Le rebond/balancement d'antan est retiré — le pack porte sa gestuelle,
    /// la faire trembler par-dessus la contredit. La poussière, elle, reste.
    private func startWalkAnimation(on node: SKNode, towards target: CGPoint) {
        let dx = target.x - node.position.x
        if node.childNode(withName: "body") != nil {
            BattleSprites.updateWalk(.kael, on: node,
                                     velocity: CGVector(dx: abs(dx) > 6 ? dx : 0, dy: 1))
        } else if let sprite = node.childNode(withName: "kaelSprite") {
            // Repli sur l'ancien sprite (pack absent) : rebond d'origine.
            if abs(dx) > 6 {
                sprite.xScale = (dx < 0 ? -1 : 1) * abs(sprite.xScale)
            }
            if sprite.action(forKey: "walkBob") == nil {
                sprite.run(.repeatForever(.sequence([
                    .group([.moveBy(x: 0, y: 2.5, duration: 0.10),
                            .rotate(toAngle: 0.05, duration: 0.10, shortestUnitArc: true)]),
                    .group([.moveBy(x: 0, y: -2.5, duration: 0.10),
                            .rotate(toAngle: -0.05, duration: 0.10, shortestUnitArc: true)])
                ])), withKey: "walkBob")
            }
        }

        startDust(on: node)
    }

    /// Petits nuages de poussière sous les pas. Partagé par les deux chemins
    /// d'animation (pack et repli).
    private func startDust(on node: SKNode) {
        guard node.action(forKey: "walkDust") == nil else { return }
        let dust = SKAction.repeatForever(.sequence([
            .run { [weak node] in
                guard let node, let parent = node.parent else { return }
                let puff = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...4))
                puff.fillColor = SKColor(red: 0.62, green: 0.54, blue: 0.42, alpha: 0.35)
                puff.strokeColor = .clear
                puff.position = CGPoint(x: node.position.x + .random(in: -6...6),
                                        y: node.position.y + .random(in: -2...2))
                puff.zPosition = node.zPosition - 0.1
                parent.addChild(puff)
                puff.run(.sequence([
                    .group([.scale(to: 1.8, duration: 0.35),
                            .fadeOut(withDuration: 0.35),
                            .moveBy(x: 0, y: 4, duration: 0.35)]),
                    .removeFromParent()
                ]))
            },
            .wait(forDuration: 0.18)
        ]))
        node.run(dust, withKey: "walkDust")
    }

    private static func stopWalkAnimation(on node: SKNode) {
        node.removeAction(forKey: "walkDust")
        // Sprite du pack : retour à l'idle, l'orientation acquise est gardée.
        if node.childNode(withName: "body") != nil {
            BattleSprites.updateWalk(.kael, on: node, velocity: .zero)
            return
        }
        guard let sprite = node.childNode(withName: "kaelSprite") else { return }
        sprite.removeAction(forKey: "walkBob")
        // Repose le sprite à sa position/rotation d'origine (cf. WorldNode.kael)
        sprite.run(.group([
            .rotate(toAngle: 0, duration: 0.08, shortestUnitArc: true),
            .move(to: CGPoint(x: 0, y: -16), duration: 0.08)
        ]))
    }
}
