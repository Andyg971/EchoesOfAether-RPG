import SpriteKit

// CombatSprites — créatures dessinées en code (formes SpriteKit), fallback sans pixel-art.
extension CombatSprites {
    // MARK: - Beast (créature à quatre pattes, sombre, yeux jaunes)

    static func buildBeast(into root: SKNode) {
        let body = SKShapeNode(ellipseOf: CGSize(width: 78, height: 46))
        body.fillColor = SKColor(red: 0.16, green: 0.10, blue: 0.10, alpha: 1)
        body.strokeColor = SKColor(red: 0.35, green: 0.18, blue: 0.18, alpha: 0.6)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 2)
        root.addChild(body)

        let head = SKShapeNode(ellipseOf: CGSize(width: 42, height: 36))
        head.fillColor = body.fillColor
        head.strokeColor = body.strokeColor
        head.position = CGPoint(x: -32, y: 14)
        root.addChild(head)

        // Yeux jaunes glow
        for dx: CGFloat in [-8, 4] {
            let eye = SKShapeNode(circleOfRadius: 3.5)
            eye.fillColor = SKColor(red: 1, green: 0.85, blue: 0.20, alpha: 1)
            eye.strokeColor = .clear
            eye.glowWidth = 4
            eye.position = CGPoint(x: -32 + dx, y: 18)
            root.addChild(eye)
        }

        // Crocs
        let fang = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -48, y: 8))
        p.addLine(to: CGPoint(x: -46, y: 0))
        p.addLine(to: CGPoint(x: -44, y: 8))
        p.closeSubpath()
        fang.path = p
        fang.fillColor = SKColor(white: 0.92, alpha: 1)
        fang.strokeColor = .clear
        root.addChild(fang)

        // Pattes
        for dx: CGFloat in [-24, -6, 14, 30] {
            let leg = SKShapeNode(rectOf: CGSize(width: 6, height: 22), cornerRadius: 2)
            leg.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.06, alpha: 1)
            leg.strokeColor = .clear
            leg.position = CGPoint(x: dx, y: -18)
            root.addChild(leg)
        }
    }

    // MARK: - Wolf (élancé, gris foncé, crinière)

    static func buildWolf(into root: SKNode) {
        let body = SKShapeNode(ellipseOf: CGSize(width: 86, height: 38))
        body.fillColor = SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)
        body.strokeColor = SKColor(red: 0.35, green: 0.35, blue: 0.42, alpha: 0.6)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 0)
        root.addChild(body)

        let head = SKShapeNode()
        let hp = CGMutablePath()
        hp.move(to: CGPoint(x: -40, y: 22))
        hp.addLine(to: CGPoint(x: -56, y: 8))
        hp.addLine(to: CGPoint(x: -42, y: -6))
        hp.addLine(to: CGPoint(x: -26, y: 8))
        hp.closeSubpath()
        head.path = hp
        head.fillColor = body.fillColor
        head.strokeColor = body.strokeColor
        head.lineWidth = 1.5
        root.addChild(head)

        // Oreilles
        for (dx, dy): (CGFloat, CGFloat) in [(-46, 26), (-32, 26)] {
            let ear = SKShapeNode()
            let ep = CGMutablePath()
            ep.move(to: CGPoint(x: dx, y: dy))
            ep.addLine(to: CGPoint(x: dx + 4, y: dy + 10))
            ep.addLine(to: CGPoint(x: dx + 8, y: dy))
            ep.closeSubpath()
            ear.path = ep
            ear.fillColor = body.fillColor
            ear.strokeColor = .clear
            root.addChild(ear)
        }

        // Œil rouge
        let eye = SKShapeNode(circleOfRadius: 3)
        eye.fillColor = SKColor(red: 0.95, green: 0.20, blue: 0.18, alpha: 1)
        eye.strokeColor = .clear
        eye.glowWidth = 4
        eye.position = CGPoint(x: -42, y: 10)
        root.addChild(eye)

        // Pattes
        for dx: CGFloat in [-22, -2, 18, 34] {
            let leg = SKShapeNode(rectOf: CGSize(width: 5, height: 24), cornerRadius: 2)
            leg.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
            leg.strokeColor = .clear
            leg.position = CGPoint(x: dx, y: -18)
            root.addChild(leg)
        }

        // Queue
        let tail = SKShapeNode(rectOf: CGSize(width: 28, height: 5), cornerRadius: 2)
        tail.fillColor = body.fillColor
        tail.strokeColor = .clear
        tail.zRotation = .pi / 6
        tail.position = CGPoint(x: 40, y: 8)
        root.addChild(tail)
    }

    // MARK: - Guardian Aether (boss, géant minéral pourpre)

    /// Gardien de l'Aether : la statue d'ange du sanctuaire, animée par
    /// l'Aether noir — pixel art teinté + cœur violet + yeux corrompus.
    static func buildGuardian(into root: SKNode) {
        guard let statue = PixelArtSprites.still(name: "me_statue_angel",
                                                 scale: 0.50,
                                                 anchor: CGPoint(x: 0.5, y: 0.0)) else {
            buildGuardianFallback(into: root)
            return
        }
        statue.position = CGPoint(x: 0, y: -34)
        statue.forEachDescendantSprite { sprite in
            sprite.color = SKColor(red: 0.30, green: 0.16, blue: 0.46, alpha: 1)
            sprite.colorBlendFactor = 0.35
        }
        root.addChild(statue)
        JuiceEngine.float(statue, distance: 4)

        // Cœur d'Aether retiré à la demande : un aplat violet de 14×14 posé
        // sur la statue ne lisait pas comme un cœur qui bat, mais comme une
        // texture manquante. Les yeux corrompus suffisent à dire la
        // corruption, et le sprite de pierre reste pur.

        // Yeux corrompus retirés : posés à y = 78 ils ne tombaient pas sur le
        // visage de la statue mais sur ses MAINS jointes, où ils se lisaient
        // comme deux carrés magenta collés au sprite. Sans repère fiable sur
        // l'asset pour viser les yeux, mieux vaut la pierre nue.
        // Halo/aura retiré à la demande : le sprite pixel reste pur.
    }

    /// Fallback shape si l'asset statue manque.
    static private func buildGuardianFallback(into root: SKNode) {
        let body = SKShapeNode(rectOf: CGSize(width: 70, height: 90), cornerRadius: 14)
        body.fillColor = SKColor(red: 0.18, green: 0.10, blue: 0.28, alpha: 1)
        body.strokeColor = SKColor(red: 0.55, green: 0.22, blue: 0.85, alpha: 0.8)
        body.lineWidth = 2.5
        body.position = CGPoint(x: 0, y: 14)
        root.addChild(body)

        let core = SKShapeNode(circleOfRadius: 11)
        core.fillColor = SKColor(red: 0.65, green: 0.25, blue: 0.95, alpha: 1)
        core.strokeColor = .clear
        core.glowWidth = 8
        core.position = CGPoint(x: 0, y: 18)
        root.addChild(core)
        JuiceEngine.pulse(core, scale: 1.3)
    }

    // MARK: - Ruins Guardian (sentinelle de pierre Acte II)

    static func buildRuinsGuardian(into root: SKNode) {
        let body = SKShapeNode(rectOf: CGSize(width: 56, height: 70), cornerRadius: 8)
        body.fillColor = SKColor(red: 0.25, green: 0.20, blue: 0.18, alpha: 1)
        body.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.32, alpha: 0.7)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 6)
        root.addChild(body)

        // Fissures rougeoyantes
        for (start, end) in [(CGPoint(x: -16, y: 20), CGPoint(x: 4, y: -8)),
                             (CGPoint(x: 14, y: 18), CGPoint(x: -2, y: -16))] {
            let crack = SKShapeNode()
            let cp = CGMutablePath()
            cp.move(to: start)
            cp.addLine(to: end)
            crack.path = cp
            crack.strokeColor = SKColor(red: 0.95, green: 0.30, blue: 0.10, alpha: 0.9)
            crack.lineWidth = 2
            crack.glowWidth = 3
            root.addChild(crack)
        }

        let head = SKShapeNode(rectOf: CGSize(width: 38, height: 30), cornerRadius: 6)
        head.fillColor = body.fillColor
        head.strokeColor = body.strokeColor
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 54)
        root.addChild(head)

        let visor = SKShapeNode(rectOf: CGSize(width: 22, height: 4), cornerRadius: 1)
        visor.fillColor = SKColor(red: 0.95, green: 0.30, blue: 0.15, alpha: 1)
        visor.strokeColor = .clear
        visor.glowWidth = 5
        visor.position = CGPoint(x: 0, y: 54)
        root.addChild(visor)

        // Bras massifs
        for dx: CGFloat in [-34, 34] {
            let arm = SKShapeNode(rectOf: CGSize(width: 14, height: 44), cornerRadius: 5)
            arm.fillColor = body.fillColor
            arm.strokeColor = body.strokeColor
            arm.position = CGPoint(x: dx, y: 6)
            root.addChild(arm)
        }
    }

    // MARK: - Archivist (boss voilé, livres flottants)

    static func buildArchivist(into root: SKNode) {
        // Robe voilée
        let robe = SKShapeNode()
        let rp = CGMutablePath()
        rp.move(to: CGPoint(x: -32, y: -34))
        rp.addLine(to: CGPoint(x: -22, y: 40))
        rp.addLine(to: CGPoint(x: 22, y: 40))
        rp.addLine(to: CGPoint(x: 32, y: -34))
        rp.closeSubpath()
        robe.path = rp
        robe.fillColor = SKColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1)
        robe.strokeColor = SKColor(red: 0.45, green: 0.20, blue: 0.70, alpha: 0.6)
        robe.lineWidth = 2
        root.addChild(robe)

        // Capuche
        let hood = SKShapeNode(circleOfRadius: 18)
        hood.fillColor = SKColor(red: 0.04, green: 0.02, blue: 0.08, alpha: 1)
        hood.strokeColor = SKColor(red: 0.45, green: 0.20, blue: 0.70, alpha: 0.5)
        hood.lineWidth = 2
        hood.position = CGPoint(x: 0, y: 48)
        root.addChild(hood)

        // Vide à la place du visage : 2 points pourpres
        for dx: CGFloat in [-5, 5] {
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = SKColor(red: 0.85, green: 0.45, blue: 1, alpha: 1)
            dot.strokeColor = .clear
            dot.glowWidth = 5
            dot.position = CGPoint(x: dx, y: 48)
            root.addChild(dot)
        }

        // Livres flottants
        for (dx, dy, rot): (CGFloat, CGFloat, CGFloat) in [(-46, 18, -0.3), (46, 26, 0.4), (-38, 64, 0.2)] {
            let book = SKShapeNode(rectOf: CGSize(width: 14, height: 10), cornerRadius: 1)
            book.fillColor = SKColor(red: 0.30, green: 0.15, blue: 0.45, alpha: 1)
            book.strokeColor = SKColor(red: 0.75, green: 0.45, blue: 1, alpha: 0.7)
            book.lineWidth = 1
            book.position = CGPoint(x: dx, y: dy)
            book.zRotation = rot
            root.addChild(book)
            JuiceEngine.float(book, distance: 4)
        }
    }
}
