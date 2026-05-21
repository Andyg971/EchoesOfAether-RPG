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

    // MARK: - Atmospheric

    static func ambientDust(in size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 5

        for _ in 0..<20 {
            let dust = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            dust.fillColor = SKColor(white: 0.35, alpha: CGFloat.random(in: 0.1...0.25))
            dust.strokeColor = .clear
            dust.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )

            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -40...40),
                y: CGFloat.random(in: 10...30),
                duration: TimeInterval.random(in: 4...8)
            )
            let fade = SKAction.sequence([
                .fadeAlpha(to: CGFloat.random(in: 0.05...0.15), duration: 3),
                .fadeAlpha(to: CGFloat.random(in: 0.1...0.25), duration: 3)
            ])
            dust.run(.repeatForever(.group([drift, fade, .sequence([drift.reversed(), fade.reversed()])])))
            container.addChild(dust)
        }

        return container
    }

    static func forestFog(in size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 5

        for _ in 0..<15 {
            let fog = SKShapeNode(circleOfRadius: CGFloat.random(in: 20...50))
            fog.fillColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: CGFloat.random(in: 0.03...0.08))
            fog.strokeColor = .clear
            fog.position = CGPoint(
                x: CGFloat.random(in: -50...size.width + 50),
                y: CGFloat.random(in: 0...size.height * 0.5)
            )

            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -60...60),
                y: CGFloat.random(in: -10...10),
                duration: TimeInterval.random(in: 6...12)
            )
            fog.run(.repeatForever(.sequence([drift, drift.reversed()])))
            container.addChild(fog)
        }

        for _ in 0..<8 {
            let wisp = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            wisp.fillColor = SKColor(red: 0.20, green: 0.55, blue: 0.30, alpha: 0.4)
            wisp.strokeColor = .clear
            wisp.glowWidth = 3
            wisp.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: size.height * 0.3...size.height * 0.7)
            )

            let float = SKAction.moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -20...20), duration: 3)
            let blink = SKAction.sequence([.fadeAlpha(to: 0.1, duration: 2), .fadeAlpha(to: 0.5, duration: 2)])
            wisp.run(.repeatForever(.group([.sequence([float, float.reversed()]), blink])))
            container.addChild(wisp)
        }

        return container
    }

    static func shrineAura(in size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 5

        for _ in 0..<12 {
            let rune = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            rune.fillColor = SKColor(red: 0.50, green: 0.20, blue: 0.85, alpha: CGFloat.random(in: 0.2...0.5))
            rune.strokeColor = .clear
            rune.glowWidth = 4
            rune.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )

            let rise = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 20...60), duration: TimeInterval.random(in: 4...8))
            let pulse = SKAction.sequence([
                .fadeAlpha(to: 0.05, duration: 2),
                .fadeAlpha(to: CGFloat.random(in: 0.3...0.6), duration: 2)
            ])
            rune.run(.repeatForever(.group([.sequence([rise, rise.reversed()]), pulse])))
            container.addChild(rune)
        }

        for i in 0..<3 {
            let vortex = SKShapeNode(circleOfRadius: CGFloat(8 + i * 12))
            vortex.fillColor = .clear
            vortex.strokeColor = SKColor(red: 0.40, green: 0.15, blue: 0.70, alpha: 0.08)
            vortex.lineWidth = 1
            vortex.position = CGPoint(x: size.width * 0.70, y: size.height * 0.55)
            vortex.zPosition = 4
            container.addChild(vortex)

            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: TimeInterval(8 + i * 4))
            let scale = SKAction.sequence([.scale(to: 1.3, duration: 3), .scale(to: 0.8, duration: 3)])
            vortex.run(.repeatForever(.group([rotate, scale])))
        }

        return container
    }

    static func ruinsAsh(in size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 5

        for _ in 0..<18 {
            let ash = SKShapeNode(rectOf: CGSize(
                width: CGFloat.random(in: 1.5...3.5),
                height: CGFloat.random(in: 1.5...3.5)
            ), cornerRadius: 0.5)
            ash.fillColor = SKColor(
                red: CGFloat.random(in: 0.25...0.45),
                green: 0.05,
                blue: CGFloat.random(in: 0.04...0.10),
                alpha: CGFloat.random(in: 0.15...0.40)
            )
            ash.strokeColor = .clear
            ash.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )

            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -25...25),
                y: CGFloat.random(in: -30...(-5)),
                duration: TimeInterval.random(in: 3...7)
            )
            let blink = SKAction.sequence([
                .fadeAlpha(to: CGFloat.random(in: 0.05...0.15), duration: 2),
                .fadeAlpha(to: CGFloat.random(in: 0.2...0.4),  duration: 2)
            ])
            ash.run(.repeatForever(.group([.sequence([drift, drift.reversed()]), blink])))
            container.addChild(ash)
        }

        for _ in 0..<6 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3))
            ember.fillColor = SKColor(red: 0.75, green: 0.20, blue: 0.10, alpha: 0.5)
            ember.strokeColor = .clear
            ember.glowWidth = 3
            ember.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height * 0.6)
            )
            let float = SKAction.moveBy(x: CGFloat.random(in: -15...15), y: CGFloat.random(in: 15...45), duration: TimeInterval.random(in: 3...6))
            let pulse = SKAction.sequence([.fadeAlpha(to: 0.1, duration: 1.5), .fadeAlpha(to: 0.6, duration: 1.5)])
            ember.run(.repeatForever(.group([.sequence([float, float.reversed()]), pulse])))
            container.addChild(ember)
        }

        return container
    }

    // MARK: - Tap

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
