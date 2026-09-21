import SpriteKit

// Effets de sort en pixels nets : feu, glace, foudre (particules SpriteKit, zéro glow).
extension CombatSystem {
    /// FEU : charge aspirée, boule de feu massive en cloche, traînée épaisse,
    /// explosion pixel + onde de choc + flammes résiduelles + fumée.
    func playEmberEffect(on foe: EnemyState, boosted: Bool) {
    let pal = Self.firePalette
    let start = CGPoint(x: actorHomePosition.x + 30, y: actorHomePosition.y + 40)

    // 1. Charge : pixels de braise aspirés vers la main de Kael.
    PixelFX.converge(in: root, to: start, palette: pal,
                     count: boosted ? 14 : 10, radius: 46, duration: 0.18)

    // 2. Noyau de la boule = carrés concentriques tournoyants.
    let ball = SKNode()
    let sizes: [(CGFloat, Int)] = boosted
        ? [(28, 3), (20, 1), (12, 0)] : [(22, 3), (15, 1), (9, 0)]
    for (sz, ci) in sizes {
        let sq = SKSpriteNode(color: pal[ci], size: CGSize(width: sz, height: sz))
        ball.addChild(sq)
    }
    ball.position = start
    ball.zPosition = 826
    ball.setScale(0.2)
    ball.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.25)))
    root.addChild(ball)

    // Traînée : braises carrées lâchées en continu.
    let trail = SKAction.repeatForever(.sequence([
        .run { [weak self, weak ball] in
            guard let self, let ball else { return }
            for _ in 0..<3 {
                let side = CGFloat.random(in: 4...8)
                let ember = SKSpriteNode(color: pal.randomElement() ?? .orange,
                                         size: CGSize(width: side, height: side))
                ember.position = CGPoint(x: ball.position.x + .random(in: -7...7),
                                         y: ball.position.y + .random(in: -7...7))
                ember.zPosition = 825
                self.root.addChild(ember)
                ember.run(.sequence([
                    .group([.fadeOut(withDuration: 0.3), .scale(to: 0.2, duration: 0.3)]),
                    .removeFromParent()
                ]))
            }
        },
        .wait(forDuration: 0.02)
    ]))

    // 3. Vol en cloche : la boule monte puis retombe sur la cible.
    let impact = CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 20)
    let arc = CGMutablePath()
    arc.move(to: start)
    let apex = CGPoint(x: (start.x + impact.x) / 2,
                       y: max(start.y, impact.y) + 70)
    arc.addQuadCurve(to: impact, control: apex)
    let fly = SKAction.follow(arc, asOffset: false, orientToPath: false, duration: 0.26)
    fly.timingMode = .easeIn

    ball.run(.sequence([
        .group([.scale(to: 1.0, duration: 0.16),
                .sequence([.wait(forDuration: 0.16),
                           .run { ball.run(trail, withKey: "trail") }])]),
        .wait(forDuration: 0.04),
        fly,
        .run { [weak self] in
            guard let self else { return }
            ball.removeAction(forKey: "trail")
            let ground = foe.homePosition
            // Explosion radiale massive + gerbe montante + fumée.
            PixelFX.burst(in: self.root, at: ground, palette: pal,
                          count: boosted ? 52 : 34, speed: 130...300,
                          gravity: 380, pixel: 5...11)
            PixelFX.burst(in: self.root, at: ground, palette: pal,
                          count: boosted ? 18 : 12, speed: 70...150,
                          gravity: -120, pixel: 4...8,
                          baseAngle: .pi / 2, spread: .pi * 0.6)
            // Onde de choc au sol, écrasée en perspective.
            PixelFX.shockRing(in: self.root, at: ground, palette: pal,
                              count: boosted ? 26 : 18,
                              fromRadius: 10, toRadius: boosted ? 88 : 66,
                              pixel: 6, flatten: 0.35, duration: 0.32)
            // Flammes qui vacillent au sol + panache de fumée.
            PixelFX.groundFlames(in: self.root, at: ground, palette: pal,
                                 count: boosted ? 10 : 7,
                                 width: boosted ? 80 : 58)
            PixelFX.smoke(in: self.root, at: ground, count: boosted ? 10 : 7)
            JuiceEngine.screenShake(self.root, intensity: boosted ? 10 : 7, duration: 0.24)
        },
        .removeFromParent()
    ]))
    }

    /// GLACE : brume givrée au sol, éventail de stalactites cristallines,
    /// scintillements sur les pointes, éclats à l'impact.
    func playFrostEffect(on foe: EnemyState, boosted: Bool) {
    let pal = Self.icePalette
    let count = boosted ? 6 : 4

    // Brume de givre qui rampe au sol avant le jaillissement.
    for _ in 0..<(boosted ? 12 : 8) {
        let side = CGFloat.random(in: 4...8)
        let mist = SKSpriteNode(color: pal[0].withAlphaComponent(0.55),
                                size: CGSize(width: side, height: side))
        mist.position = CGPoint(x: foe.homePosition.x + .random(in: -50...50),
                                y: foe.homePosition.y - 30 + .random(in: -4...6))
        mist.zPosition = 824
        mist.alpha = 0
        root.addChild(mist)
        mist.run(.sequence([
            .group([.fadeAlpha(to: 0.55, duration: 0.10),
                    .moveBy(x: .random(in: -20...20), y: 4, duration: 0.5)]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    for i in 0..<count {
        let h: CGFloat = CGFloat.random(in: 30...46) * (boosted ? 1.25 : 1.0)
        let spike = SKNode()
        let steps = 5
        for s in 0..<steps {
            let f = CGFloat(s)
            // Cristal : plus clair au sommet, arêtes latérales pixel
            let core = SKSpriteNode(
                color: s >= steps - 2 ? pal[0] : pal[1],
                size: CGSize(width: max(2, 14 - f * 2.5), height: h / CGFloat(steps) + 1))
            core.position = CGPoint(x: 0, y: (f + 0.5) * h / CGFloat(steps))
            spike.addChild(core)
            if s < steps - 1 {
                let edge = SKSpriteNode(color: pal[2],
                                        size: CGSize(width: 2, height: h / CGFloat(steps)))
                edge.position = CGPoint(x: -(14 - f * 2.5) / 2, y: core.position.y)
                spike.addChild(edge)
            }
        }
        spike.position = CGPoint(x: foe.homePosition.x + CGFloat(i - count / 2) * 15,
                                 y: foe.homePosition.y - 30)
        spike.zPosition = 826
        spike.yScale = 0
        root.addChild(spike)
        spike.run(.sequence([
            .wait(forDuration: Double(i) * 0.05),
            .scaleY(to: 1.0, duration: 0.08),   // jaillit sec
            .run { [weak self] in
                guard let self else { return }
                // Sparkle 16-bit sur la pointe fraîchement sortie.
                PixelFX.twinkle(in: self.root,
                                at: CGPoint(x: spike.position.x + .random(in: -4...4),
                                            y: spike.position.y + h - 2),
                                color: pal[1], size: 3,
                                delay: Double.random(in: 0...0.1))
            },
            .wait(forDuration: 0.28),
            .run { [weak self] in
                guard let self else { return }
                // Se brise en éclats pixel qui retombent
                PixelFX.burst(in: self.root,
                              at: CGPoint(x: spike.position.x, y: spike.position.y + h * 0.5),
                              palette: pal, count: boosted ? 12 : 8,
                              speed: 80...180, gravity: 420, pixel: 3...6)
            },
            .group([.fadeOut(withDuration: 0.18), .scaleY(to: 0.5, duration: 0.18)]),
            .removeFromParent()
        ]))
    }
    // Souffle givré : anneau écrasé qui s'étend au sol.
    PixelFX.shockRing(in: root, at: CGPoint(x: foe.homePosition.x,
                                            y: foe.homePosition.y - 26),
                      palette: pal, count: boosted ? 20 : 14,
                      fromRadius: 8, toRadius: boosted ? 70 : 52,
                      pixel: 4, flatten: 0.3, duration: 0.28)
    root.run(.sequence([.wait(forDuration: 0.12),
                        .run { [weak self] in
                            JuiceEngine.screenShake(self?.root ?? SKNode(),
                                                    intensity: boosted ? 6 : 4, duration: 0.14)
                        }]))
    }

    /// FOUDRE : éclairs pixel en escalier (zéro diagonale lissée), double flash,
    /// onde de choc rasante + crépitement résiduel sur la cible.
    func playThunderEffect(on foe: EnemyState, boosted: Bool) {
    guard let scene = parentScene else { return }
    let pal = Self.boltPalette
    let hit = CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 6)

    // 2-3 éclairs en marches d'escalier, carrés nets uniquement.
    let strands = boosted ? 3 : 2
    for strand in 0..<strands {
        let offsetX = CGFloat(strand - strands / 2) * 10
        let top = CGPoint(x: hit.x + offsetX + .random(in: -14...14),
                          y: scene.size.height + 10)
        let bolt = PixelFX.bolt(in: root, from: top,
                                to: CGPoint(x: hit.x + offsetX * 0.4, y: hit.y),
                                core: strand == 0 ? pal[0] : pal[1],
                                edge: pal[2],
                                width: strand == 0 ? (boosted ? 8 : 6) : 4,
                                jitter: 22)
        bolt.alpha = 0
        bolt.run(.sequence([
            .wait(forDuration: Double(strand) * 0.03),
            .fadeIn(withDuration: 0.02),
            .wait(forDuration: 0.07),
            .fadeAlpha(to: 0.25, duration: 0.04),
            .fadeAlpha(to: 1.0, duration: 0.03),
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ]))
    }
    // Double flash : blanc sec puis jaune, comme un vrai orage.
    JuiceEngine.flashOverlay(in: root, size: scene.size,
                             color: .white, duration: 0.05)
    root.run(.sequence([.wait(forDuration: 0.06), .run { [weak self] in
        guard let self, let scene = self.parentScene else { return }
        JuiceEngine.flashOverlay(in: self.root, size: scene.size,
                                 color: SKColor(red: 0.98, green: 0.94, blue: 0.60, alpha: 1),
                                 duration: 0.09)
    }]))
    JuiceEngine.screenShake(root, intensity: boosted ? 9 : 6, duration: 0.18)
    // Éclats projetés horizontalement au point d'impact (rasants).
    PixelFX.burst(in: root, at: hit, palette: pal, count: boosted ? 28 : 18,
                  speed: 140...320, gravity: 300, pixel: 3...6,
                  baseAngle: 0, spread: .pi * 0.5)
    PixelFX.burst(in: root, at: hit, palette: pal, count: boosted ? 28 : 18,
                  speed: 140...320, gravity: 300, pixel: 3...6,
                  baseAngle: .pi, spread: .pi * 0.5)
    // Onde de choc électrique rasante au sol.
    PixelFX.shockRing(in: root, at: hit, palette: pal,
                      count: boosted ? 24 : 16,
                      fromRadius: 6, toRadius: boosted ? 84 : 60,
                      pixel: 5, flatten: 0.3, duration: 0.26)
    // Crépitement résiduel : étincelles qui claquent sur l'ennemi.
    for i in 0..<(boosted ? 8 : 5) {
        PixelFX.twinkle(in: root,
                        at: CGPoint(x: foe.homePosition.x + .random(in: -26...26),
                                    y: foe.homePosition.y + .random(in: -20...36)),
                        color: pal[1], size: 3,
                        delay: 0.10 + Double(i) * 0.06)
    }
    }

    /// SOIN : anneau béni au sol, colonne de carrés translucides, spirale de
}
