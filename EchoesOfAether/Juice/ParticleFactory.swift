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

    // MARK: - Village vivant

    /// Fumée de cheminée : bouffées de carrés gris qui montent en
    /// dérivant, en boucle. À poser sur le toit d'une maison.
    static func chimneySmoke() -> SKNode {
        let container = SKNode()
        container.zPosition = 30
        let spawn = SKAction.repeatForever(.sequence([
            .run { [weak container] in
                guard let container else { return }
                let side = CGFloat.random(in: 4...7)
                let puff = SKSpriteNode(
                    color: SKColor(white: 0.78, alpha: CGFloat.random(in: 0.16...0.28)),
                    size: CGSize(width: side, height: side))
                puff.position = CGPoint(x: .random(in: -3...3), y: 0)
                container.addChild(puff)
                let rise = SKAction.moveBy(x: .random(in: -14...4),
                                           y: .random(in: 34...52),
                                           duration: .random(in: 2.2...3.2))
                rise.timingMode = .easeOut
                puff.run(.sequence([
                    .group([rise,
                            .scale(to: 2.0, duration: 2.8),
                            .sequence([.wait(forDuration: 1.4),
                                       .fadeOut(withDuration: 1.4)])]),
                    .removeFromParent()
                ]))
            },
            .wait(forDuration: 0.55)
        ]))
        container.run(spawn)
        return container
    }

    /// Éclats d'Aether : petits carrés violets/sarcelle qui s'élèvent
    /// lentement en scintillant, comme le flux qui monte de la terre.
    /// Cinématique de l'écran-titre — pixels nets, zéro glow flou.
    static func aetherMotes(in size: CGSize, count: Int = 22) -> SKNode {
        let container = SKNode()
        container.zPosition = 26
        let palette: [SKColor] = [
            SKColor(red: 0.66, green: 0.42, blue: 0.98, alpha: 1),
            SKColor(red: 0.45, green: 0.80, blue: 0.92, alpha: 1),
            SKColor(red: 0.82, green: 0.66, blue: 1.00, alpha: 1)
        ]
        for _ in 0..<count {
            let side = CGFloat(Int.random(in: 2...4))
            let mote = SKSpriteNode(color: palette.randomElement()!,
                                    size: CGSize(width: side, height: side))
            let startX = CGFloat.random(in: 0...size.width)
            mote.position = CGPoint(x: startX, y: .random(in: 0...size.height))
            mote.alpha = 0
            container.addChild(mote)
            // Montée lente + léger balancement + scintillement, en boucle.
            func climb() -> SKAction {
                let dur = TimeInterval.random(in: 6...11)
                let rise = SKAction.moveBy(x: .random(in: -24...24),
                                           y: size.height * .random(in: 0.5...0.9),
                                           duration: dur)
                let twinkle = SKAction.sequence([
                    .fadeAlpha(to: .random(in: 0.4...0.85), duration: dur * 0.25),
                    .fadeAlpha(to: .random(in: 0.2...0.5), duration: dur * 0.5),
                    .fadeAlpha(to: 0, duration: dur * 0.25)
                ])
                return .group([rise, twinkle])
            }
            let loop = SKAction.repeatForever(.sequence([
                .run { [weak mote] in
                    mote?.position = CGPoint(x: startX + .random(in: -20...20), y: -6)
                },
                .run { [weak mote] in mote?.run(climb()) },
                .wait(forDuration: .random(in: 6...11))
            ]))
            mote.run(.sequence([.wait(forDuration: .random(in: 0...5)), loop]))
        }
        return container
    }

    /// Papillons : petits carrés colorés qui voletent en zigzag
    /// dans la zone donnée. Discret — 4 papillons.
    static func butterflies(in size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 24
        let palette: [SKColor] = [
            SKColor(red: 0.95, green: 0.75, blue: 0.30, alpha: 0.9),
            SKColor(red: 0.85, green: 0.55, blue: 0.90, alpha: 0.9),
            SKColor(red: 0.60, green: 0.85, blue: 0.95, alpha: 0.9),
            SKColor(red: 0.98, green: 0.98, blue: 0.85, alpha: 0.9)
        ]
        for i in 0..<4 {
            let fly = SKSpriteNode(color: palette[i % palette.count],
                                   size: CGSize(width: 3, height: 3))
            fly.position = CGPoint(x: .random(in: size.width * 0.1...size.width * 0.9),
                                   y: .random(in: size.height * 0.15...size.height * 0.7))
            container.addChild(fly)
            // Zigzag : petites courses aléatoires enchaînées + battement d'ailes
            let hop = SKAction.run { [weak fly] in
                guard let fly else { return }
                let dest = CGPoint(x: fly.position.x + .random(in: -60...60),
                                   y: fly.position.y + .random(in: -30...40))
                let clamped = CGPoint(
                    x: min(max(dest.x, 20), size.width - 20),
                    y: min(max(dest.y, size.height * 0.10), size.height * 0.8))
                let move = SKAction.move(to: clamped, duration: .random(in: 1.2...2.2))
                move.timingMode = .easeInEaseOut
                fly.run(move)
            }
            fly.run(.repeatForever(.sequence([hop, .wait(forDuration: 2.3)])))
            fly.run(.repeatForever(.sequence([
                .scaleY(to: 0.4, duration: 0.12),
                .scaleY(to: 1.0, duration: 0.12)
            ])))
        }
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
