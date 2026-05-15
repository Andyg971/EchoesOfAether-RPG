import SpriteKit

@MainActor
enum ParticleFactory {

    static func impactSparks(at position: CGPoint, color: SKColor = .white, count: Int = 10) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 800

        for _ in 0..<count {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3.5))
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.glowWidth = 2

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...220)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            let lifetime = TimeInterval.random(in: 0.2...0.5)

            spark.run(.sequence([
                .group([
                    .moveBy(x: dx * lifetime, y: dy * lifetime, duration: lifetime),
                    .fadeOut(withDuration: lifetime),
                    .scale(to: 0.1, duration: lifetime)
                ]),
                .removeFromParent()
            ]))

            container.addChild(spark)
        }

        container.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
        return container
    }

    static func blackAetherBurst(at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 810

        let darkPurple = SKColor(red: 0.35, green: 0.05, blue: 0.50, alpha: 1)
        let voidBlack = SKColor(red: 0.10, green: 0.02, blue: 0.14, alpha: 1)

        for i in 0..<16 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            spark.fillColor = i % 2 == 0 ? darkPurple : voidBlack
            spark.strokeColor = .clear
            spark.glowWidth = i % 3 == 0 ? 4 : 1

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...300)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            let lifetime = TimeInterval.random(in: 0.3...0.7)

            spark.run(.sequence([
                .group([
                    .moveBy(x: dx * lifetime, y: dy * lifetime, duration: lifetime),
                    .fadeOut(withDuration: lifetime),
                    .scale(to: 0.2, duration: lifetime)
                ]),
                .removeFromParent()
            ]))

            container.addChild(spark)
        }

        let core = SKShapeNode(circleOfRadius: 18)
        core.fillColor = voidBlack
        core.strokeColor = darkPurple
        core.glowWidth = 8
        core.alpha = 0.9
        core.run(.sequence([
            .group([
                .scale(to: 3.0, duration: 0.25),
                .fadeOut(withDuration: 0.3)
            ]),
            .removeFromParent()
        ]))
        container.addChild(core)

        container.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
        return container
    }

    static func tapMarker(at position: CGPoint) -> SKNode {
        let ring = SKShapeNode(circleOfRadius: 14)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 0.58, green: 0.52, blue: 0.94, alpha: 0.7)
        ring.lineWidth = 2
        ring.zPosition = 50

        ring.run(.sequence([
            .group([
                .scale(to: 1.8, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ]),
            .removeFromParent()
        ]))

        return ring
    }
}
