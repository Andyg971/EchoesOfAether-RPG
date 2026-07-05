import SpriteKit

/// Moteur d'effets 100% pixel art : uniquement des carrés nets (`SKSpriteNode`),
/// zéro glow, zéro tracé vectoriel lissé. Chaque effet est composé de
/// particules carrées alignées sur une grille visuelle, comme un vrai
/// jeu 16-bit.
@MainActor
enum PixelFX {

    // MARK: - Burst radial

    /// Explosion de carrés pixel projetés radialement avec gravité et fondu.
    /// `spread` en radians autour de `baseAngle` (2π = tous azimuts).
    static func burst(in parent: SKNode, at center: CGPoint,
                      palette: [SKColor], count: Int,
                      speed: ClosedRange<CGFloat>, gravity: CGFloat,
                      pixel: ClosedRange<CGFloat> = 4...8,
                      baseAngle: CGFloat = 0, spread: CGFloat = .pi * 2,
                      z: CGFloat = 828) {
        for _ in 0..<count {
            let side = CGFloat.random(in: pixel).rounded()
            let px = SKSpriteNode(color: palette.randomElement() ?? .white,
                                  size: CGSize(width: side, height: side))
            px.position = center
            px.zPosition = z
            parent.addChild(px)

            let ang = baseAngle + CGFloat.random(in: -spread / 2...spread / 2)
            let spd = CGFloat.random(in: speed)
            let dur = TimeInterval(CGFloat.random(in: 0.35...0.6))
            let dx = cos(ang) * spd * CGFloat(dur)
            let dy = sin(ang) * spd * CGFloat(dur) - 0.5 * gravity * CGFloat(dur * dur)
            px.run(.sequence([
                .group([
                    .move(by: CGVector(dx: dx, dy: dy), duration: dur),
                    .sequence([.wait(forDuration: dur * 0.6),
                               .fadeOut(withDuration: dur * 0.4)]),
                    .scale(to: 0.4, duration: dur)
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Anneau de choc

    /// Onde de choc : carrés disposés en cercle qui s'écartent du centre.
    /// `flatten` < 1 écrase verticalement l'anneau (perspective au sol).
    static func shockRing(in parent: SKNode, at center: CGPoint,
                          palette: [SKColor], count: Int = 20,
                          fromRadius: CGFloat = 8, toRadius: CGFloat = 70,
                          pixel: CGFloat = 5, flatten: CGFloat = 1.0,
                          duration: TimeInterval = 0.30, z: CGFloat = 827) {
        for i in 0..<count {
            let ang = CGFloat(i) / CGFloat(count) * .pi * 2
            let px = SKSpriteNode(color: palette.randomElement() ?? .white,
                                  size: CGSize(width: pixel, height: pixel))
            px.position = CGPoint(x: center.x + cos(ang) * fromRadius,
                                  y: center.y + sin(ang) * fromRadius * flatten)
            px.zPosition = z
            parent.addChild(px)
            let dest = CGPoint(x: center.x + cos(ang) * toRadius,
                               y: center.y + sin(ang) * toRadius * flatten)
            let move = SKAction.move(to: dest, duration: duration)
            move.timingMode = .easeOut
            px.run(.sequence([
                .group([move,
                        .sequence([.wait(forDuration: duration * 0.4),
                                   .fadeOut(withDuration: duration * 0.6)]),
                        .scale(to: 0.5, duration: duration)]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Éclair pixel

    /// Éclair en escalier : segments carrés verticaux + connecteurs
    /// horizontaux, zéro diagonale lissée. Retourne le nœud (déjà ajouté).
    @discardableResult
    static func bolt(in parent: SKNode, from top: CGPoint, to hit: CGPoint,
                     core: SKColor, edge: SKColor,
                     width: CGFloat = 6, jitter: CGFloat = 20,
                     z: CGFloat = 827) -> SKNode {
        let node = SKNode()
        node.zPosition = z

        var x = top.x
        var y = top.y
        // Descente en marches : run vertical puis saut horizontal net.
        while y > hit.y + 14 {
            let seg = CGFloat.random(in: 22...42)
            let h = min(seg, y - hit.y)
            addBoltSegment(to: node, x: x, yTop: y, height: h,
                           width: width, core: core, edge: edge)
            y -= h
            let targetX = hit.x + CGFloat.random(in: -jitter...jitter)
            let dx = targetX - x
            if abs(dx) > 3 {
                let hBar = SKSpriteNode(color: core,
                                        size: CGSize(width: abs(dx) + width, height: width))
                hBar.position = CGPoint(x: x + dx / 2, y: y)
                node.addChild(hBar)
                x = targetX
            }
        }
        // Dernier tronçon jusqu'au point d'impact.
        addBoltSegment(to: node, x: hit.x, yTop: y, height: max(4, y - hit.y),
                       width: width, core: core, edge: edge)
        parent.addChild(node)
        return node
    }

    private static func addBoltSegment(to node: SKNode, x: CGFloat, yTop: CGFloat,
                                       height: CGFloat, width: CGFloat,
                                       core: SKColor, edge: SKColor) {
        let seg = SKSpriteNode(color: core, size: CGSize(width: width, height: height))
        seg.position = CGPoint(x: x, y: yTop - height / 2)
        node.addChild(seg)
        // Liseré sombre côté gauche : lisibilité pixel sans glow.
        let rim = SKSpriteNode(color: edge, size: CGSize(width: 2, height: height))
        rim.position = CGPoint(x: x - width / 2 - 1, y: seg.position.y)
        node.addChild(rim)
    }

    // MARK: - Scintillement

    /// Étoile pixel « + » qui grandit puis disparaît — le sparkle 16-bit
    /// classique.
    static func twinkle(in parent: SKNode, at p: CGPoint, color: SKColor,
                        size: CGFloat = 4, delay: TimeInterval = 0,
                        z: CGFloat = 831) {
        let star = SKNode()
        let c = SKSpriteNode(color: .white, size: CGSize(width: size, height: size))
        star.addChild(c)
        for (dx, dy) in [(0, 1), (0, -1), (1, 0), (-1, 0)] {
            let arm = SKSpriteNode(color: color, size: CGSize(width: size, height: size))
            arm.position = CGPoint(x: CGFloat(dx) * size, y: CGFloat(dy) * size)
            star.addChild(arm)
        }
        star.position = p
        star.zPosition = z
        star.setScale(0)
        parent.addChild(star)
        star.run(.sequence([
            .wait(forDuration: delay),
            .scale(to: 1.0, duration: 0.10),
            .scale(to: 0.0, duration: 0.14),
            .removeFromParent()
        ]))
    }

    // MARK: - Convergence (charge-up)

    /// Pixels aspirés depuis un cercle vers `center` — annonce un sort.
    static func converge(in parent: SKNode, to center: CGPoint,
                         palette: [SKColor], count: Int = 10,
                         radius: CGFloat = 42, duration: TimeInterval = 0.20,
                         z: CGFloat = 826) {
        for i in 0..<count {
            let ang = CGFloat(i) / CGFloat(count) * .pi * 2 + .random(in: -0.3...0.3)
            let side = CGFloat.random(in: 3...6)
            let px = SKSpriteNode(color: palette.randomElement() ?? .white,
                                  size: CGSize(width: side, height: side))
            px.position = CGPoint(x: center.x + cos(ang) * radius,
                                  y: center.y + sin(ang) * radius)
            px.zPosition = z
            px.alpha = 0
            parent.addChild(px)
            let move = SKAction.move(to: center, duration: duration)
            move.timingMode = .easeIn
            px.run(.sequence([
                .wait(forDuration: Double.random(in: 0...0.08)),
                .group([.fadeIn(withDuration: duration * 0.4), move]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Flammes résiduelles

    /// Petites langues de feu pixel qui vacillent au sol après une explosion.
    static func groundFlames(in parent: SKNode, at base: CGPoint,
                             palette: [SKColor], count: Int = 7,
                             width: CGFloat = 60, duration: TimeInterval = 0.9,
                             z: CGFloat = 825) {
        for _ in 0..<count {
            let w = CGFloat.random(in: 4...7)
            let h = CGFloat.random(in: 8...16)
            let flame = SKSpriteNode(color: palette[min(1, palette.count - 1)],
                                     size: CGSize(width: w, height: h))
            flame.anchorPoint = CGPoint(x: 0.5, y: 0)
            flame.position = CGPoint(x: base.x + .random(in: -width / 2...width / 2),
                                     y: base.y + .random(in: -4...4))
            flame.zPosition = z
            parent.addChild(flame)
            // Vacillement : hauteur qui pompe + couleur qui alterne.
            let flicker = SKAction.repeatForever(.sequence([
                .run { [weak flame] in
                    flame?.color = palette.randomElement() ?? .orange
                    flame?.yScale = .random(in: 0.6...1.3)
                },
                .wait(forDuration: 0.06)
            ]))
            flame.run(flicker, withKey: "flicker")
            flame.run(.sequence([
                .wait(forDuration: duration * .random(in: 0.6...1.0)),
                .group([.fadeOut(withDuration: 0.2), .scaleY(to: 0.1, duration: 0.2)]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Fumée

    /// Panaches de fumée pixel qui montent en se dissipant.
    static func smoke(in parent: SKNode, at base: CGPoint,
                      count: Int = 8, z: CGFloat = 824) {
        let greys: [SKColor] = [
            SKColor(white: 0.28, alpha: 1),
            SKColor(white: 0.38, alpha: 1),
            SKColor(red: 0.32, green: 0.26, blue: 0.24, alpha: 1)
        ]
        for i in 0..<count {
            let side = CGFloat.random(in: 5...10)
            let puff = SKSpriteNode(color: greys.randomElement() ?? .gray,
                                    size: CGSize(width: side, height: side))
            puff.position = CGPoint(x: base.x + .random(in: -18...18),
                                    y: base.y + .random(in: -4...10))
            puff.zPosition = z
            puff.alpha = 0.85
            parent.addChild(puff)
            let dur = TimeInterval.random(in: 0.5...0.9)
            puff.run(.sequence([
                .wait(forDuration: Double(i) * 0.03),
                .group([
                    .moveBy(x: .random(in: -14...14), y: .random(in: 40...80), duration: dur),
                    .fadeOut(withDuration: dur),
                    .scale(to: 1.6, duration: dur)
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Arc de slash pixel

    /// Croissant de coup d'épée bâti en carrés le long d'un arc — remplace
    /// l'ancien tracé vectoriel glowé.
    static func slashArc(in parent: SKNode, at point: CGPoint,
                         color: SKColor, strong: Bool, z: CGFloat = 830) {
        let radius: CGFloat = strong ? 46 : 36
        let thickness: CGFloat = strong ? 8 : 6
        let steps = strong ? 14 : 11
        let start: CGFloat = .pi * 0.75
        let end: CGFloat = -.pi * 0.25
        let node = SKNode()
        node.position = point
        node.zPosition = z
        parent.addChild(node)

        for s in 0..<steps {
            let t = CGFloat(s) / CGFloat(steps - 1)
            let ang = start + (end - start) * t
            // Croissant : plus épais au milieu, effilé aux pointes.
            let w = thickness * (0.4 + 0.6 * sin(t * .pi))
            let px = SKSpriteNode(color: color, size: CGSize(width: max(3, w), height: max(3, w)))
            px.position = CGPoint(x: cos(ang) * radius, y: sin(ang) * radius)
            px.alpha = 0
            node.addChild(px)
            px.run(.sequence([
                .wait(forDuration: Double(s) * 0.012),
                .fadeIn(withDuration: 0.02),
                .wait(forDuration: 0.10),
                .fadeOut(withDuration: 0.10),
                .removeFromParent()
            ]))
        }
        node.run(.sequence([
            .rotate(byAngle: -.pi * 0.35, duration: 0.22),
            .wait(forDuration: 0.15),
            .removeFromParent()
        ]))
    }
}
