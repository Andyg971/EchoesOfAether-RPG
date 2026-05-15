import SpriteKit

@MainActor
enum JuiceEngine {

    static func screenShake(_ node: SKNode, intensity: CGFloat = 10, duration: TimeInterval = 0.3) {
        let shakes = Int(duration / 0.04)
        var actions: [SKAction] = []
        for i in 0..<shakes {
            let factor = CGFloat(shakes - i) / CGFloat(shakes)
            let dx = CGFloat.random(in: -intensity...intensity) * factor
            let dy = CGFloat.random(in: -intensity...intensity) * factor
            actions.append(.moveBy(x: dx, y: dy, duration: 0.02))
            actions.append(.moveBy(x: -dx, y: -dy, duration: 0.02))
        }
        node.run(.sequence(actions), withKey: "shake")
    }

    static func flash(_ node: SKNode, color: SKColor = .white, duration: TimeInterval = 0.12) {
        guard let shape = node as? SKShapeNode else { return }
        let original = shape.fillColor
        shape.run(.sequence([
            .run { shape.fillColor = color },
            .wait(forDuration: duration),
            .run { shape.fillColor = original }
        ]), withKey: "flash")
    }

    static func flashOverlay(in parent: SKNode, size: CGSize, color: SKColor, duration: TimeInterval = 0.15) {
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = color
        overlay.strokeColor = .clear
        overlay.alpha = 0.6
        overlay.zPosition = 950
        parent.addChild(overlay)
        overlay.run(.sequence([
            .fadeOut(withDuration: duration),
            .removeFromParent()
        ]))
    }

    static func slowMotion(scene: SKScene, duration: TimeInterval = 0.15, factor: CGFloat = 0.3) {
        scene.speed = factor
        scene.run(.sequence([
            .wait(forDuration: duration * factor),
            .run { scene.speed = 1.0 }
        ]), withKey: "slowmo")
    }

    static func popIn(_ node: SKNode, delay: TimeInterval = 0) {
        node.setScale(0)
        node.alpha = 0
        let appear = SKAction.group([
            .scale(to: 1.15, duration: 0.2),
            .fadeIn(withDuration: 0.15)
        ])
        appear.timingMode = .easeOut
        node.run(.sequence([
            .wait(forDuration: delay),
            appear,
            .scale(to: 1.0, duration: 0.1)
        ]))
    }

    static func popOut(_ node: SKNode, completion: (@Sendable () -> Void)? = nil) {
        let shrink = SKAction.group([
            .scale(to: 0, duration: 0.2),
            .fadeOut(withDuration: 0.2)
        ])
        if let completion {
            node.run(.sequence([shrink, .removeFromParent()]), completion: completion)
        } else {
            node.run(.sequence([shrink, .removeFromParent()]))
        }
    }

    static func pulse(_ node: SKNode, scale: CGFloat = 1.15) {
        let up = SKAction.scale(to: scale, duration: 0.5)
        let down = SKAction.scale(to: 1.0, duration: 0.5)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([up, down])), withKey: "pulse")
    }

    static func float(_ node: SKNode, distance: CGFloat = 6) {
        let up = SKAction.moveBy(x: 0, y: distance, duration: 1)
        let down = SKAction.moveBy(x: 0, y: -distance, duration: 1)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([up, down])), withKey: "float")
    }

    static func squashAndStretch(_ node: SKNode, duration: TimeInterval = 0.2) {
        let squash = SKAction.scaleX(to: 1.3, y: 0.7, duration: duration * 0.3)
        let stretch = SKAction.scaleX(to: 0.8, y: 1.3, duration: duration * 0.3)
        let reset = SKAction.scale(to: 1.0, duration: duration * 0.4)
        squash.timingMode = .easeOut
        reset.timingMode = .easeInEaseOut
        node.run(.sequence([squash, stretch, reset]))
    }
}
