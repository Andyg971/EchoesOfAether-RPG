import SpriteKit

// Marqueurs de quête : talisman, fer corrompu, herbe lunaire, insigne, cristal, « ! » sur les PNJ.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Talisman perdu (quête de la villageoise)

    /// La croix de bois du fils, à moitié enterrée sur le sentier ouest.
    func addMedallionMarker(in scene: SKScene) {
        guard medallionMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.28, y: h * 0.72)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD
        if let cross = PixelArtSprites.still(name: "gy_cross_wood", scale: 0.30,
                                             anchor: CGPoint(x: 0.5, y: 0.0)) {
            marker.addChild(cross)
        }
        let glow = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 0.30),
                                size: CGSize(width: 30, height: 30))
        glow.zRotation = .pi / 4
        glow.position = CGPoint(x: 0, y: 10)
        glow.zPosition = -0.5
        marker.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        medallionMarker = marker
    }

    func removeMedallionMarker() {
        medallionMarker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let m = medallionMarker, let idx = backdropNodes.firstIndex(where: { $0 === m }) {
            backdropNodes.remove(at: idx)
        }
        medallionMarker = nil
    }

    // MARK: - Fer corrompu (quête de Bram)

    /// Veine de fer noirci qui affleure à l'est du bosquet.
    func addOreMarker(in scene: SKScene) {
        guard oreMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        // ATTENTION : loin du campement+cristal (0.52, 0.52) — le tap du
        // cristal de save est prioritaire et volerait le ramassage.
        marker.position = CGPoint(x: w * 0.40, y: h * 0.63)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD

        // Bloc de fer corrompu — grille pixel, filons violets (zéro glow)
        let rock = PixelIcons.custom(map: [
            "....RRRR....",
            "..RRrrrrRR..",
            ".RrvRrrRvrR.",
            "RrrvvrrrvvrR",
            "RrrrvrrrrvrR",
            "RrvrrrRvrrrR",
            "RrvvrrrvvrrR",
            ".RrrrRrrrrR.",
            "..RRRRRRRR.."
        ], palette: [
            "R": SKColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1),
            "r": SKColor(red: 0.20, green: 0.18, blue: 0.26, alpha: 1),
            "v": SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1)
        ], pixel: 1.8)
        marker.addChild(rock)

        // Étincelle pixel violette (repère œil, cohérent charte)
        let sparkle = SKSpriteNode(color: SKColor(red: 0.65, green: 0.40, blue: 0.95, alpha: 1),
                                   size: CGSize(width: 7, height: 7))
        sparkle.zRotation = .pi / 4
        sparkle.position = CGPoint(x: 0, y: 18)
        marker.addChild(sparkle)
        JuiceEngine.float(sparkle, distance: 4)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        oreMarker = marker
    }

    func removeOreMarker() {
        removeCollectMarker(&oreMarker)
    }

    // MARK: - Herbe lunaire (quête de Sage)

    /// Herbe pâle qui luit entre les racines, à l'ouest du sentier.
    func addHerbMarker(in scene: SKScene) {
        guard herbMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.12, y: h * 0.40)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD

        // Brins luminescents. Carrés nets : un `cornerRadius: 1` sur un brin
        // de 2 pt de large le transformait en gélule.
        for (dx, height) in [(-4, 10), (0, 14), (4, 9)] {
            let blade = SKSpriteNode(color: SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 0.95),
                                     size: CGSize(width: 2, height: CGFloat(height)))
            blade.position = CGPoint(x: CGFloat(dx), y: CGFloat(height) / 2)
            marker.addChild(blade)
        }

        let halo = pixelHalo(color: SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 1),
                             radius: 13)
        halo.position = CGPoint(x: 0, y: 6)
        marker.addChild(halo)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        herbMarker = marker
    }

    func removeHerbMarker() {
        removeCollectMarker(&herbMarker)
    }

    // MARK: - Insigne de l'éclaireur (quête de Garen)

    /// L'insigne de Tomm, à moitié enfoui sur la sente est.
    func addBadgeMarker(in scene: SKScene) {
        guard badgeMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.68, y: h * 0.18)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD

        // Écusson métallique terni. Coins vifs : `cornerRadius: 4` sur 10×12
        // arrondissait l'écusson jusqu'à en faire une pastille.
        let shield = SKSpriteNode(color: SKColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1),
                                  size: CGSize(width: 9, height: 12))
        shield.zRotation = 0.5   // à moitié planté dans le sol
        marker.addChild(shield)
        // Éclat de métal poli, un pixel plus clair.
        let sheen = SKSpriteNode(color: SKColor(red: 0.80, green: 0.82, blue: 0.88, alpha: 1),
                                 size: CGSize(width: 3, height: 5))
        sheen.zRotation = 0.5
        sheen.position = CGPoint(x: -1, y: 2)
        marker.addChild(sheen)

        marker.addChild(pixelHalo(color: SKColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 1),
                                  radius: 12))

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        badgeMarker = marker
    }

    func removeBadgeMarker() {
        removeCollectMarker(&badgeMarker)
    }

    /// Le cristal-mère (quête de Lyra), planté au cœur mort de la forêt.
    ///
    /// Violet d'Aether, la couleur de la marque de Kael et de l'Entaille
    /// Noire : cette chose et lui sont de la même famille, et ça doit se voir
    /// avant même le dialogue.
    func addCrystalMarker(in scene: SKScene) {
        guard crystalMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.78, y: h * 0.70)
        marker.zPosition = 60

        // Éclat dressé : losange d'Aether, comme les pastilles du combat.
        let shard = SKSpriteNode(color: Palette.aetherDeep,
                                 size: CGSize(width: 11, height: 11))
        shard.zRotation = .pi / 4
        marker.addChild(shard)
        let core = SKSpriteNode(color: SKColor(red: 0.90, green: 0.80, blue: 1.00, alpha: 1),
                                size: CGSize(width: 4, height: 4))
        core.zRotation = .pi / 4
        marker.addChild(core)

        marker.addChild(pixelHalo(color: Palette.aetherDeep,
                                  radius: 13))

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        crystalMarker = marker
    }

    func removeCrystalMarker() {
        removeCollectMarker(&crystalMarker)
    }

    /// Halo de repérage, en pixel strict.
    ///
    /// Les marqueurs de collecte signalaient leur objet avec un
    /// `SKShapeNode(circleOfRadius:)` rempli d'un alpha faible et animé en
    /// échelle : un disque dégradé, à bords lissés, qui grossissait et
    /// rétrécissait. C'est exactement ce que la charte pixel exclut — et à
    /// l'écran ça se lisait comme une tache grise qui scintille, sans rapport
    /// avec le reste du jeu.
    ///
    /// Ici : quatre pastilles carrées posées en losange, qui clignotent
    /// ensemble. Les angles sont droits, donc les positions tombent sur des
    /// entiers et les carrés restent nets. Aucun dégradé, aucune échelle
    /// animée — seulement l'alpha, qui ne floute rien.
    func pixelHalo(color: SKColor, radius: CGFloat) -> SKNode {
        let halo = SKNode()
        for (dx, dy) in [(0.0, 1.0), (1.0, 0.0), (0.0, -1.0), (-1.0, 0.0)] {
            let pip = SKSpriteNode(color: color, size: CGSize(width: 3, height: 3))
            pip.position = CGPoint(x: CGFloat(dx) * radius, y: CGFloat(dy) * radius)
            halo.addChild(pip)
        }
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.30, duration: 0.55),
            .fadeAlpha(to: 1.00, duration: 0.55)
        ])))
        return halo
    }

    /// Fade + retrait d'un marqueur de collecte (factorisation commune).
    func removeCollectMarker(_ marker: inout SKNode?) {
        marker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let m = marker, let idx = backdropNodes.firstIndex(where: { $0 === m }) {
            backdropNodes.remove(at: idx)
        }
        marker = nil
    }

    // MARK: - Marqueurs de quête « ! » sur les PNJ

    /// Point d'exclamation doré pulsant au-dessus d'un PNJ qui a une
    /// quête à proposer. `visible: false` le retire.
    func setQuestMarker(on npc: SKNode, visible: Bool) {
        let markName = "questMark"
        if !visible {
            npc.childNode(withName: markName)?.removeFromParent()
            return
        }
        guard npc.childNode(withName: markName) == nil else { return }
        let mark = SKLabelNode(fontNamed: PixelUI.uiFont)
        mark.name = markName
        mark.text = "!"
        mark.fontSize = 20
        mark.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        mark.position = CGPoint(x: 0, y: 40)
        mark.zPosition = 5
        npc.addChild(mark)
        mark.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 5, duration: 0.4),
            .moveBy(x: 0, y: -5, duration: 0.4)
        ])))
    }
}
