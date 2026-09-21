import SpriteKit

// ParticleFactory — ambiances de zone : poussière, pluie, brume, aura, cendres.
extension ParticleFactory {
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

    /// Pluie pixel en espace ÉCRAN (le monde scrolle, pas la pluie) :
    /// traits verticaux 2×8 rendus en .nearest, légère gîte de vent.
    /// `advanceSimulationTime` pré-remplit l'écran à l'arrivée en zone.
    static func rain(in size: CGSize, heavy: Bool = false) -> SKNode {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 2, height: 8), format: format
        ).image { ctx in
            ctx.cgContext.setFillColor(SKColor(red: 0.78, green: 0.86, blue: 1.0,
                                               alpha: 0.9).cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 2, height: 8))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest

        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.particleBirthRate = heavy ? 240 : 130
        emitter.particleLifetime = 1.6
        emitter.particleLifetimeRange = 0.3
        emitter.particlePositionRange = CGVector(dx: size.width + 240, dy: 0)
        emitter.position = CGPoint(x: size.width / 2, y: size.height + 24)
        emitter.particleSpeed = 620
        emitter.particleSpeedRange = 130
        emitter.emissionAngle = -.pi / 2 - 0.10   // vent léger vers la gauche
        emitter.particleAlpha = 0.5
        emitter.particleAlphaRange = 0.25
        emitter.particleScale = 1.2
        emitter.particleScaleRange = 0.4
        emitter.advanceSimulationTime(2)
        emitter.zPosition = 95   // au-dessus du grade (90), sous le HUD (100)
        return emitter
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
}
