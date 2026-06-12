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
    }

    private static func stopWalkAnimation(on node: SKNode) {
        guard let sprite = node.childNode(withName: "kaelSprite") else { return }
        sprite.removeAction(forKey: "walkBob")
        // Repose le sprite à sa position/rotation d'origine (cf. WorldNode.kael)
        sprite.run(.group([
            .rotate(toAngle: 0, duration: 0.08, shortestUnitArc: true),
            .move(to: CGPoint(x: 0, y: -16), duration: 0.08)
        ]))
    }
}
