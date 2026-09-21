import SpriteKit

@MainActor
enum ParticleFactory {

    /// Étincelles d'impact 100% pixel : carrés nets, zéro glow.
    static func impactSparks(at position: CGPoint, color: SKColor = .white, count: Int = 10) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 800

        for _ in 0..<count {
            let side = CGFloat.random(in: 3...6).rounded()
            let spark = SKSpriteNode(color: color, size: CGSize(width: side, height: side))

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...220)
            let lifetime = TimeInterval.random(in: 0.2...0.5)
            // Légère gravité : les éclats retombent au lieu de filer tout droit.
            let dx = cos(angle) * speed * lifetime
            let dy = sin(angle) * speed * lifetime - 0.5 * 260 * lifetime * lifetime

            spark.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: lifetime),
                    .sequence([.wait(forDuration: lifetime * 0.5),
                               .fadeOut(withDuration: lifetime * 0.5)]),
                    .scale(to: 0.3, duration: lifetime)
                ]),
                .removeFromParent()
            ]))

            container.addChild(spark)
        }

        container.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
        return container
    }

    /// Explosion d'Éther noir 100% pixel : éclats carrés violets/noirs
    /// + noyau en carrés concentriques qui gonfle, zéro glow.
    static func blackAetherBurst(at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 810

        let palette: [SKColor] = [
            SKColor(red: 0.85, green: 0.55, blue: 1.00, alpha: 1),
            SKColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 1),
            SKColor(red: 0.35, green: 0.05, blue: 0.50, alpha: 1),
            SKColor(red: 0.10, green: 0.02, blue: 0.14, alpha: 1)
        ]

        for _ in 0..<22 {
            let side = CGFloat.random(in: 3...7).rounded()
            let spark = SKSpriteNode(color: palette.randomElement() ?? .purple,
                                     size: CGSize(width: side, height: side))

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...300)
            let lifetime = TimeInterval.random(in: 0.3...0.7)
            let dx = cos(angle) * speed * lifetime
            let dy = sin(angle) * speed * lifetime - 0.5 * 200 * lifetime * lifetime

            spark.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: lifetime),
                    .sequence([.wait(forDuration: lifetime * 0.5),
                               .fadeOut(withDuration: lifetime * 0.5)]),
                    .scale(to: 0.3, duration: lifetime)
                ]),
                .removeFromParent()
            ]))

            container.addChild(spark)
        }

        // Noyau : carrés concentriques qui gonflent et tournent.
        let core = SKNode()
        for (sz, ci) in [(34, 3), (22, 2), (12, 1)] {
            let sq = SKSpriteNode(color: palette[ci],
                                  size: CGSize(width: sz, height: sz))
            core.addChild(sq)
        }
        core.alpha = 0.9
        core.run(.sequence([
            .group([
                .scale(to: 2.6, duration: 0.25),
                .rotate(byAngle: .pi / 2, duration: 0.25),
                .fadeOut(withDuration: 0.3)
            ]),
            .removeFromParent()
        ]))
        container.addChild(core)

        container.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
        return container
    }

    // MARK: - Tap

    /// Marqueur de tap pixel : couronne de carrés qui s'écarte, zéro cercle lissé.
    static func tapMarker(at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 50

        let color = SKColor(red: 0.58, green: 0.52, blue: 0.94, alpha: 0.8)
        let count = 8
        for i in 0..<count {
            let ang = CGFloat(i) / CGFloat(count) * .pi * 2
            let px = SKSpriteNode(color: color, size: CGSize(width: 4, height: 4))
            px.position = CGPoint(x: cos(ang) * 10, y: sin(ang) * 10)
            container.addChild(px)
            let move = SKAction.move(to: CGPoint(x: cos(ang) * 24, y: sin(ang) * 24),
                                     duration: 0.35)
            move.timingMode = .easeOut
            px.run(.group([move, .fadeOut(withDuration: 0.35)]))
        }
        container.run(.sequence([.wait(forDuration: 0.4), .removeFromParent()]))
        return container
    }
}
