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
        if active {
            node.removeAction(forKey: "move")   // le pad prime sur tap-to-move
            startWalkAnimation(on: node,
                               towards: CGPoint(x: node.position.x + dx * 100,
                                                y: node.position.y))
        } else {
            Self.stopWalkAnimation(on: node)
        }
    }

    // MARK: - Animation de marche

    /// Pas d'assets de frames de marche pour Kael : on anime le sprite
    /// (rebond + balancement rythmés) et on l'oriente vers la direction.
    private func startWalkAnimation(on node: SKNode, towards target: CGPoint) {
        guard let sprite = node.childNode(withName: "kaelSprite") else { return }
        // Oriente le sprite vers la direction de marche
        if abs(target.x - node.position.x) > 6 {
            let facing: CGFloat = target.x < node.position.x ? -1 : 1
            sprite.xScale = facing * abs(sprite.xScale)
        }
        guard sprite.action(forKey: "walkBob") == nil else { return }
        let bob = SKAction.repeatForever(.sequence([
            .group([.moveBy(x: 0, y: 2.5, duration: 0.10),
                    .rotate(toAngle: 0.05, duration: 0.10, shortestUnitArc: true)]),
            .group([.moveBy(x: 0, y: -2.5, duration: 0.10),
                    .rotate(toAngle: -0.05, duration: 0.10, shortestUnitArc: true)])
        ]))
        sprite.run(bob, withKey: "walkBob")

        // Petits nuages de poussière sous les pas
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
        guard let sprite = node.childNode(withName: "kaelSprite") else { return }
        sprite.removeAction(forKey: "walkBob")
        // Repose le sprite à sa position/rotation d'origine (cf. WorldNode.kael)
        sprite.run(.group([
            .rotate(toAngle: 0, duration: 0.08, shortestUnitArc: true),
            .move(to: CGPoint(x: 0, y: -16), duration: 0.08)
        ]))
    }
}
