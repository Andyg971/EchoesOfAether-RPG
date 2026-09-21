import SpriteKit

// Mines de Cendreval — rails, étais, lanternes, monstres errants, plaque, filon d'or.
extension WorldBuilder {

    /// Rails de mine : deux longerons métalliques + traverses de bois.
    /// 100 % SKSpriteNode — carrés nets, zéro shape lissée.
    func addMineRails(in scene: SKScene, from: CGPoint, to: CGPoint,
                              horizontal: Bool = false) {
        let rails = SKNode()
        rails.zPosition = -7
        let railColor = SKColor(red: 0.28, green: 0.28, blue: 0.33, alpha: 1)
        let tieColor = SKColor(red: 0.24, green: 0.16, blue: 0.09, alpha: 1)
        let length = horizontal ? abs(to.x - from.x) : abs(to.y - from.y)
        let gauge: CGFloat = 14

        for offset in [-gauge / 2, gauge / 2] {
            let rail = SKSpriteNode(color: railColor,
                                    size: horizontal
                                        ? CGSize(width: length, height: 3)
                                        : CGSize(width: 3, height: length))
            rail.position = horizontal
                ? CGPoint(x: (from.x + to.x) / 2, y: from.y + offset)
                : CGPoint(x: from.x + offset, y: (from.y + to.y) / 2)
            rails.addChild(rail)
        }
        let tieCount = Int(length / 26)
        for i in 0...tieCount {
            let d = CGFloat(i) * 26
            let tie = SKSpriteNode(color: tieColor,
                                   size: horizontal
                                       ? CGSize(width: 5, height: gauge + 8)
                                       : CGSize(width: gauge + 8, height: 5))
            tie.position = horizontal
                ? CGPoint(x: min(from.x, to.x) + d, y: from.y)
                : CGPoint(x: from.x, y: min(from.y, to.y) + d)
            tie.zPosition = -0.1
            rails.addChild(tie)
        }
        add(rails, to: scene)
    }

    /// Étai de mine : deux montants + traverse, brun sombre, pixel net.
    func addMineStrut(in scene: SKScene, at pos: CGPoint) {
        let strut = SKNode()
        strut.zPosition = -2
        let wood = SKColor(red: 0.30, green: 0.21, blue: 0.11, alpha: 1)
        let dark = SKColor(red: 0.16, green: 0.11, blue: 0.06, alpha: 1)
        for dx: CGFloat in [-14, 14] {
            let post = SKSpriteNode(color: wood, size: CGSize(width: 7, height: 54))
            post.position = CGPoint(x: dx, y: 0)
            strut.addChild(post)
            let edge = SKSpriteNode(color: dark, size: CGSize(width: 2, height: 54))
            edge.position = CGPoint(x: dx + 3, y: 0)
            strut.addChild(edge)
        }
        let beam = SKSpriteNode(color: wood, size: CGSize(width: 42, height: 7))
        beam.position = CGPoint(x: 0, y: 28)
        strut.addChild(beam)
        let beamEdge = SKSpriteNode(color: dark, size: CGSize(width: 42, height: 2))
        beamEdge.position = CGPoint(x: 0, y: 25)
        strut.addChild(beamEdge)
        strut.position = pos
        add(strut, to: scene)
    }

    /// Lanterne de mineur : sprite + nappe de lumière chaude au sol.
    func addMineLantern(in scene: SKScene, at pos: CGPoint) {
        let pool = SKShapeNode(ellipseOf: CGSize(width: 110, height: 54))
        pool.fillColor = SKColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 0.07)
        pool.strokeColor = .clear
        pool.position = CGPoint(x: pos.x, y: pos.y + 4)
        pool.zPosition = -5
        add(pool, to: scene)
        JuiceEngine.pulse(pool, scale: 1.08)
        addPixelProp("village_lantern_1", in: scene, at: pos, scale: 0.5)
    }

    /// Crée un sprite de monstre baladeur (ennemi idle animé, teinté cendre,
    /// ancré aux pieds + ombre) SANS le placer — le GameManager le pilote via
    /// `RoamingMonster`. Renvoie nil si l'asset manque.
    /// `tint`/`blend` : teinte du sprite. Défaut = cendre (mines, forêt) ; les
    /// zones du Vide passent leur propre teinte (violet, magenta).
    /// `frames`/`height` : tous les rôdeurs ne sortent pas des planches ME
    /// 48×96 à six frames. L'Archiviste vient d'un pack à huit frames sur un
    /// canevas 74×80 — à échelle commune il arrivait à mi-mollet d'un
    /// squelette. On vise donc une hauteur à l'écran.
    func makeRoamingMonster(asset: String,
                            frames: Int = 6,
                            height: CGFloat? = nil,
                            tint: SKColor = SKColor(red: 0.48, green: 0.44, blue: 0.42, alpha: 1),
                            blend: CGFloat = 0.22,
                            alpha: CGFloat = 1) -> SKNode? {
        guard let monster = PixelArtSprites.animated(
            name: asset, frames: frames,
            scale: height.map { scaleFor("\(asset)_idle_1", height: $0) } ?? 0.55,
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return nil }
        monster.forEachDescendantSprite { s in
            s.color = tint
            s.colorBlendFactor = blend
        }
        monster.alpha = alpha
        addGroundShadow(under: monster, width: 26, height: 7)
        return monster
    }

    /// Monstre visible dans la galerie : sprite ennemi idle, teinté cendre.
    /// Plaque de bois gravée par les équipes de mineurs.
    func makeMinersPlaque(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = depthLayer(for: pos.y)

        // Un VRAI panneau de bois planté dans la galerie. La plaque d'avant
        // était dessinée à la main — rectangle arrondi, trois traits pour
        // faire « gravure », halo doré qui pulse — et ça se voyait : c'était
        // le seul objet des mines à ne pas être du pixel art.
        let signHeight: CGFloat = 96
        if let sign = PixelArtSprites.still(name: "ext_sign",
                                            scale: scaleFor("ext_sign", height: signHeight),
                                            anchor: CGPoint(x: 0.5, y: 0.0)) {
            sign.position = CGPoint(x: 0, y: -signHeight * 0.5)
            // Teinte cendre : le bois du panneau prend la lumière des mines,
            // sinon il arrive en plein soleil dans une galerie noire.
            sign.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.42, green: 0.36, blue: 0.30, alpha: 1)
                sprite.colorBlendFactor = 0.35
            }
            node.addChild(sign)
        }

        // Lueur chaude posée derrière : elle dit « il y a quelque chose à
        // lire ici » sans dessiner de cadre par-dessus le panneau.
        let halo = pixelHalo(color: SKColor(red: 0.85, green: 0.65, blue: 0.30, alpha: 1),
                             radius: 26)
        halo.zPosition = -0.5
        node.addChild(halo)

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.mines.inscription")
        label.fontSize = 12
        label.fontColor = SKColor(white: 0.65, alpha: 0.8)
        label.position = CGPoint(x: 0, y: -signHeight * 0.5 - 16)
        node.addChild(label)
        return node
    }

    /// Veine d'or scintillante dans la paroi.
    func makeGoldVein(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = depthLayer(for: pos.y)

        let rock = SKShapeNode(rectOf: CGSize(width: 40, height: 26), cornerRadius: 6)
        rock.fillColor = SKColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1)
        rock.strokeColor = SKColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 0.8)
        rock.lineWidth = 1.5
        node.addChild(rock)

        for (dx, dy) in [(-11, 4), (-2, -5), (7, 3), (13, -2)] {
            let fleck = SKSpriteNode(color: Palette.gold,
                                     size: CGSize(width: 4, height: 4))
            fleck.position = CGPoint(x: CGFloat(dx), y: CGFloat(dy))
            fleck.zRotation = .pi / 4
            node.addChild(fleck)
        }

        let glow = SKShapeNode(circleOfRadius: 24)
        glow.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.06)
        glow.strokeColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.18)
        glow.lineWidth = 1
        node.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)
        return node
    }

    /// Retire la veine d'or (après ramassage).
    func removeGoldVein() {
        guard let vein = worldNode.childNode(withName: "minesGoldVein") else { return }
        vein.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
}
