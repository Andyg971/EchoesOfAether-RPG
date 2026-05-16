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
        node.removeAction(forKey: "move")
        let moveAction = SKAction.sequence([
            .move(to: clamped, duration: duration),
            .run { [weak self] in self?.isMoving = false }
        ])
        node.run(moveAction, withKey: "move")
    }

    func cancel(_ node: SKNode) {
        node.removeAction(forKey: "move")
        isMoving = false
    }
}
