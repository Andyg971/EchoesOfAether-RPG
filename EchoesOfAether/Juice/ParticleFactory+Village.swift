import SpriteKit

// ParticleFactory — le village vivant : fumée de cheminée, motes d'Aether, papillons.
extension ParticleFactory {
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
}
