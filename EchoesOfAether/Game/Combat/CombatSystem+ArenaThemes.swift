import SpriteKit

// Arène — décors propres aux zones sans planche de saison : désert, mines,
// caverne, Vide.
//
// Le décor d'arène se déduisait de l'ESPÈCE de l'ennemi. Or les mines, le
// désert et la caverne réutilisent les espèces de la forêt : un pillard des
// dunes se battait donc devant une pinède, un mineur cendreux aussi. Le lieu
// du combat prime désormais sur l'espèce quand il a son propre thème.
extension CombatSystem {
    enum ArenaTheme {
        case desert, mines, cave, void
    }

    func arenaPalette(for theme: ArenaTheme) -> ArenaPalette {
        switch theme {
        case .desert:
            // Crépuscule sur Ossara : assez sombre pour garder les plates
            // (texte blanc) lisibles, assez chaud pour dire « sable ».
            return ArenaPalette(
                skyColor: SKColor(red: 0.42, green: 0.22, blue: 0.16, alpha: 1),
                haloColor: SKColor(red: 0.85, green: 0.50, blue: 0.22, alpha: 0.30),
                horizonColor: SKColor(red: 0.95, green: 0.70, blue: 0.35, alpha: 0.55),
                stageColor: SKColor(red: 0.46, green: 0.31, blue: 0.19, alpha: 1),
                stageEdgeColor: SKColor(red: 0.24, green: 0.15, blue: 0.10, alpha: 1),
                stageStrokeColor: SKColor(red: 0.80, green: 0.58, blue: 0.32, alpha: 0.7),
                decorColor: SKColor(red: 0.30, green: 0.17, blue: 0.12, alpha: 1))
        case .mines:
            return ArenaPalette(
                skyColor: SKColor(red: 0.09, green: 0.08, blue: 0.11, alpha: 1),
                haloColor: SKColor(red: 0.95, green: 0.65, blue: 0.25, alpha: 0.18),
                horizonColor: SKColor(red: 0.60, green: 0.42, blue: 0.22, alpha: 0.5),
                stageColor: SKColor(red: 0.20, green: 0.15, blue: 0.12, alpha: 1),
                stageEdgeColor: SKColor(red: 0.07, green: 0.05, blue: 0.05, alpha: 1),
                stageStrokeColor: SKColor(red: 0.50, green: 0.36, blue: 0.20, alpha: 0.6),
                decorColor: SKColor(red: 0.15, green: 0.13, blue: 0.16, alpha: 1))
        case .cave:
            return ArenaPalette(
                skyColor: SKColor(red: 0.06, green: 0.09, blue: 0.14, alpha: 1),
                haloColor: SKColor(red: 0.35, green: 0.65, blue: 0.85, alpha: 0.20),
                horizonColor: SKColor(red: 0.40, green: 0.70, blue: 0.85, alpha: 0.45),
                stageColor: SKColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1),
                stageEdgeColor: SKColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1),
                stageStrokeColor: SKColor(red: 0.35, green: 0.60, blue: 0.75, alpha: 0.55),
                decorColor: SKColor(red: 0.10, green: 0.14, blue: 0.20, alpha: 1))
        case .void:
            return ArenaPalette(
                skyColor: SKColor(red: 0.10, green: 0.05, blue: 0.17, alpha: 1),
                haloColor: SKColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 0.28),
                horizonColor: SKColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.55),
                stageColor: SKColor(red: 0.15, green: 0.09, blue: 0.23, alpha: 1),
                stageEdgeColor: SKColor(red: 0.05, green: 0.03, blue: 0.09, alpha: 1),
                stageStrokeColor: SKColor(red: 0.60, green: 0.28, blue: 0.88, alpha: 0.6),
                decorColor: SKColor(red: 0.16, green: 0.08, blue: 0.26, alpha: 1))
        }
    }

    /// Fond d'un thème de zone : deux lignes de relief en blocs (dunes,
    /// strates de roche) puis les décors de la zone posés sur l'horizon.
    func addThemedBackdrop(to parent: SKNode, size: CGSize, theme: ArenaTheme,
                           palette: ArenaPalette, floorY: CGFloat) {
        let horizonY = floorY + 30
        // Relief lointain puis proche : le proche est plus sombre et plus bas.
        addSkyline(to: parent, size: size, baseY: horizonY, block: 16,
                   minHeight: 46, maxHeight: 96, seed: 3,
                   color: palette.decorColor.blended(with: palette.skyColor, 0.55), z: -15)
        addSkyline(to: parent, size: size, baseY: horizonY, block: 12,
                   minHeight: 14, maxHeight: 52, seed: 11,
                   color: palette.decorColor, z: -13)

        // (asset, x en fraction de largeur, hauteur à l'écran en points)
        let decor: [(name: String, x: CGFloat, height: CGFloat)]
        switch theme {
        case .desert:
            decor = [("ds_cliff_big", 0.10, 120), ("ds_palm_tall1", 0.27, 110),
                     ("ds_cactus_tall", 0.44, 62), ("ds_rock_spire", 0.58, 84),
                     ("ds_palm_tall2", 0.76, 104), ("ds_cliff_big", 0.93, 128)]
        case .mines:
            decor = [("rock_9", 0.08, 70), ("village_lantern_1", 0.22, 64),
                     ("me_wood_storage", 0.40, 58), ("rock_5", 0.56, 52),
                     ("me_cart_empty", 0.72, 50), ("village_lantern_1", 0.86, 64),
                     ("rock_7", 0.95, 66)]
        case .cave:
            decor = [("rock_9", 0.07, 82), ("pillar_grey_1", 0.24, 120),
                     ("rock_3", 0.42, 44), ("me_statue_angel", 0.56, 128),
                     ("pillar_grey_2", 0.78, 120), ("rock_7", 0.93, 76)]
        case .void:
            decor = [("gy_tomb_grey_1", 0.08, 78), ("gy_candle", 0.22, 84),
                     ("gy_tree", 0.36, 120), ("gy_gate_big", 0.55, 150),
                     ("gy_candle", 0.74, 84), ("gy_tomb_grey_2", 0.88, 78)]
        }
        for item in decor where PixelArtSprites.exists(item.name) {
            guard let node = PixelArtSprites.still(
                name: item.name,
                scale: PixelArtSprites.scale(name: item.name, height: item.height),
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            node.position = CGPoint(x: size.width * item.x, y: horizonY - 14)
            node.zPosition = -12
            // Fondu dans la teinte du lieu : le décor reste un arrière-plan.
            node.forEachDescendantSprite { sprite in
                sprite.color = palette.skyColor
                sprite.colorBlendFactor = 0.42
            }
            parent.addChild(node)
        }
    }

    /// Ligne de relief en colonnes de largeur fixe : un profil en escalier,
    /// déterministe (pas de hasard : deux combats au même lieu se ressemblent).
    private func addSkyline(to parent: SKNode, size: CGSize, baseY: CGFloat,
                            block: CGFloat, minHeight: CGFloat, maxHeight: CGFloat,
                            seed: Int, color: SKColor, z: CGFloat) {
        let columns = Int((size.width / block).rounded(.up)) + 1
        for c in 0..<columns {
            let wave = sin(Double(c + seed) * 0.37) + 0.6 * sin(Double(c * 2 + seed) * 0.23)
            let t = CGFloat((wave + 1.6) / 3.2)
            // Hauteur calée sur la grille : les marches tombent sur des blocs.
            let height = ((minHeight + (maxHeight - minHeight) * t) / block).rounded() * block
            let column = SKSpriteNode(color: color,
                                      size: CGSize(width: block, height: height + 40))
            column.anchorPoint = CGPoint(x: 0, y: 0)
            column.position = CGPoint(x: CGFloat(c) * block, y: baseY - 40)
            column.zPosition = z
            parent.addChild(column)
        }
    }
}

private extension SKColor {
    /// Mélange linéaire vers `other` (0 = soi, 1 = other).
    func blended(with other: SKColor, _ t: CGFloat) -> SKColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}
