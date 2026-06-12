import SpriteKit

/// Types de sprites utilisés dans l'arène de combat.
enum CombatSpriteKind {
    case beast          // Bête corrompue (forêt 1)
    case wolf           // Loup d'ombre (forêt 2)
    case guardian       // Gardien de l'Aether — boss Acte I
    case ruinsGuardian  // Gardien des Ruines (Acte II)
    case archivist      // Archiviste — boss Acte II
}

/// Factory de sprites pour l'arène de combat. Plus grands et plus expressifs
/// que les nodes monde, optimisés pour la lisibilité en plein écran.
@MainActor
enum CombatSprites {

    // MARK: - Kael

    static func kael() -> SKNode {
        let root = SKNode()
        root.name = "combatKael"
        addShadow(to: root, width: 64)

        let textures: [SKTexture] = (1...6).map { i in
            let t = SKTexture(imageNamed: "kael_idle_\(i)")
            t.filteringMode = .nearest
            return t
        }
        let sprite = SKSpriteNode(texture: textures[0])
        sprite.setScale(1.8)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        sprite.position = CGPoint(x: 0, y: -32)
        sprite.run(.repeatForever(.animate(with: textures, timePerFrame: 0.11,
                                            resize: false, restore: true)))
        root.addChild(sprite)

        // Aura Aether plus prononcée en combat
        let aura = SKShapeNode(circleOfRadius: 46)
        aura.fillColor = SKColor(red: 0.20, green: 0.05, blue: 0.35, alpha: 0.18)
        aura.strokeColor = SKColor(red: 0.55, green: 0.22, blue: 0.85, alpha: 0.22)
        aura.lineWidth = 1.5
        aura.position = CGPoint(x: 0, y: 22)
        aura.zPosition = -1
        root.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.18)

        return root
    }

    // MARK: - Enemy factory

    static func enemy(kind: CombatSpriteKind) -> SKNode {
        let root = SKNode()
        root.name = "combatEnemy"
        addShadow(to: root, width: enemyShadowWidth(kind))

        // Sprites pixel art animés (frames 48×96 extraites des sheets
        // Modern Exteriors). Les boss (guardian, archivist) gardent leurs
        // silhouettes programmatiques uniques. Fallback shape si asset
        // manquant.
        if let config = pixelSprite(for: kind),
           let sprite = PixelArtSprites.animated(name: config.name, frames: 6,
                                                 scale: 1.7,
                                                 timePerFrame: 0.16,
                                                 anchor: CGPoint(x: 0.5, y: 0.0)) {
            sprite.position = CGPoint(x: 0, y: -34)
            if let tint = config.tint {
                sprite.enumerateChildNodes(withName: "//*") { node, _ in
                    if let s = node as? SKSpriteNode {
                        s.color = tint
                        s.colorBlendFactor = 0.38
                    }
                }
            }
            root.addChild(sprite)
            return root
        }

        switch kind {
        case .beast:         buildBeast(into: root)
        case .wolf:          buildWolf(into: root)
        case .guardian:      buildGuardian(into: root)
        case .ruinsGuardian: buildRuinsGuardian(into: root)
        case .archivist:     buildArchivist(into: root)
        }
        return root
    }

    /// Asset pixel art + teinte optionnelle par type d'ennemi.
    private static func pixelSprite(for kind: CombatSpriteKind)
        -> (name: String, tint: SKColor?)? {
        switch kind {
        case .beast:
            return ("enemy_beast", nil)
        case .wolf:
            // "Loup d'ombre" : même créature, noyée d'ombre violette.
            return ("enemy_shadewolf",
                    SKColor(red: 0.22, green: 0.10, blue: 0.38, alpha: 1))
        case .ruinsGuardian:
            return ("enemy_bone", nil)
        case .guardian, .archivist:
            return nil   // boss uniques → silhouettes dédiées
        }
    }

    // MARK: - Shadow / ground anchor

    private static func enemyShadowWidth(_ kind: CombatSpriteKind) -> CGFloat {
        switch kind {
        case .beast:         return 78
        case .wolf:          return 86
        case .guardian:      return 110
        case .ruinsGuardian: return 84
        case .archivist:     return 90
        }
    }

    private static func addShadow(to root: SKNode, width: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: 12))
        shadow.fillColor = SKColor(white: 0, alpha: 0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -34)
        shadow.zPosition = -2
        root.addChild(shadow)
    }

    // MARK: - Beast (créature à quatre pattes, sombre, yeux jaunes)

    private static func buildBeast(into root: SKNode) {
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

    private static func buildWolf(into root: SKNode) {
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

    private static func buildGuardian(into root: SKNode) {
        let body = SKShapeNode(rectOf: CGSize(width: 70, height: 90), cornerRadius: 14)
        body.fillColor = SKColor(red: 0.18, green: 0.10, blue: 0.28, alpha: 1)
        body.strokeColor = SKColor(red: 0.55, green: 0.22, blue: 0.85, alpha: 0.8)
        body.lineWidth = 2.5
        body.position = CGPoint(x: 0, y: 14)
        root.addChild(body)

        // Cœur d'Aether (joyau central)
        let core = SKShapeNode(circleOfRadius: 11)
        core.fillColor = SKColor(red: 0.65, green: 0.25, blue: 0.95, alpha: 1)
        core.strokeColor = .clear
        core.glowWidth = 8
        core.position = CGPoint(x: 0, y: 18)
        root.addChild(core)
        JuiceEngine.pulse(core, scale: 1.3)

        // Tête flottante
        let head = SKShapeNode(circleOfRadius: 18)
        head.fillColor = SKColor(red: 0.22, green: 0.12, blue: 0.34, alpha: 1)
        head.strokeColor = SKColor(red: 0.55, green: 0.22, blue: 0.85, alpha: 0.7)
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 68)
        root.addChild(head)
        JuiceEngine.float(head, distance: 4)

        // Yeux pourpres
        for dx: CGFloat in [-6, 6] {
            let eye = SKShapeNode(circleOfRadius: 2.5)
            eye.fillColor = SKColor(red: 0.95, green: 0.55, blue: 1, alpha: 1)
            eye.strokeColor = .clear
            eye.glowWidth = 4
            eye.position = CGPoint(x: dx, y: 70)
            root.addChild(eye)
        }

        // Bras minéral (gauche, vers Kael)
        let armL = SKShapeNode(rectOf: CGSize(width: 16, height: 56), cornerRadius: 6)
        armL.fillColor = body.fillColor
        armL.strokeColor = body.strokeColor
        armL.lineWidth = 1.5
        armL.position = CGPoint(x: -34, y: 14)
        armL.zRotation = -.pi / 12
        root.addChild(armL)

        let armR = SKShapeNode(rectOf: CGSize(width: 16, height: 56), cornerRadius: 6)
        armR.fillColor = body.fillColor
        armR.strokeColor = body.strokeColor
        armR.lineWidth = 1.5
        armR.position = CGPoint(x: 34, y: 14)
        armR.zRotation = .pi / 12
        root.addChild(armR)
    }

    // MARK: - Ruins Guardian (sentinelle de pierre Acte II)

    private static func buildRuinsGuardian(into root: SKNode) {
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

    private static func buildArchivist(into root: SKNode) {
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
