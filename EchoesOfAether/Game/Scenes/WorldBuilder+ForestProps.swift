import SpriteKit

// Forêt d'Ébène — sous-bois semé, échelle des arbres, marqueur du jouet perdu.
extension WorldBuilder {
    /// Sous-bois : champignons, rochers, souches, pousses et os dispersés
    /// de façon déterministe, hors sentier et clairières.
    func scatterForestProps(in scene: SKScene, w: CGFloat, h: CGFloat) {
        let reserved: [CGRect] = [
            CGRect(x: w * 0.44, y: 0, width: w * 0.12, height: h * 0.17),
            CGRect(x: w * 0.15, y: h * 0.25, width: w * 0.30, height: h * 0.13),  // bosquet
            CGRect(x: w * 0.39, y: h * 0.47, width: w * 0.26, height: h * 0.10),  // campement
            CGRect(x: w * 0.56, y: h * 0.60, width: w * 0.28, height: h * 0.12),  // clairière
            CGRect(x: w * 0.44, y: h * 0.85, width: w * 0.22, height: h * 0.10)   // seuil
        ]
        let props = ["me_mushrooms_1", "me_mushrooms_2", "forest_mushroom_1",
                     "forest_mushroom_2", "mushroom_1", "mushroom_3",
                     "rock_1", "rock_3", "rock_5", "village_rock_1",
                     "stump_1", "stump_2", "forest_stump_1",
                     "me_big_sprout_1", "me_big_sprout_2", "me_big_sprout_3",
                     "bones_1"]
        var seed: UInt64 = 0xF0E5_57_2026
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        var placed = 0
        var attempts = 0
        while placed < 52 && attempts < 420 {
            attempts += 1
            let p = CGPoint(x: w * 0.16 + next() * w * 0.68,
                            y: h * 0.02 + next() * h * 0.94)
            if reserved.contains(where: { $0.contains(p) }) { continue }
            let name = props[Int(next() * CGFloat(props.count)) % props.count]
            guard let node = PixelArtSprites.still(name: name, scale: 0.42,
                                                    anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            node.position = p
            node.zPosition = -8.8
            add(node, to: scene)
            // Rochers, souches et ossements bloquent ; le reste se marche.
            if !Self.walkablePropPrefixes.contains(where: name.hasPrefix) {
                registerFootprint(of: node, widthRatio: 0.6, maxDepth: 16)
            }
            placed += 1
        }
    }

    /// Scale dynamique des arbres pixel art de la forêt selon la largeur.
    /// Cible ~70 pt iPhone, ~110 pt iPad pour les arbres de bordure.
    func forestTreeScale(for sceneWidth: CGFloat) -> CGFloat {
        let s = sceneWidth / 2400
        return max(0.22, min(0.45, s))
    }

    /// Place le jouet visible en forêt (si quête active)
    func addToyMarker(in scene: SKScene) {
        guard toyMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let toy = SKNode()
        toy.position = CGPoint(x: w * 0.80, y: h * 0.45)
        // Objet posé au sol : trié comme le reste du monde, sinon Kael
        // passe derrière un jouet qui est devant lui.
        toy.zPosition = depthLayer(for: toy.position.y)

        // Petit ours en bois — grille pixel (charte : zéro coin arrondi/glow)
        let bear = PixelIcons.custom(map: [
            ".OO....OO.",
            ".Oo....oO.",
            "..OOOOOO..",
            ".OoooooooO",
            ".OoDooDooO",
            ".OooooooO.",
            "..OonnOO..",
            "..OOOOOO..",
            ".OOooooOO.",
            "OOooooooOO",
            "OoOooooOoO",
            ".OOooooOO.",
            ".Oo....oO.",
            ".OO....OO."
        ], palette: [
            "O": SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1),
            "o": SKColor(red: 0.68, green: 0.45, blue: 0.20, alpha: 1),
            "D": SKColor(red: 0.20, green: 0.12, blue: 0.06, alpha: 1),
            "n": SKColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1)
        ], pixel: 1.6)
        toy.addChild(bear)

        // Losange pixel doré flottant au-dessus du jouet
        let sparkle = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        sparkle.fillColor = Palette.goldWorld
        sparkle.strokeColor = SKColor(red: 1, green: 0.95, blue: 0.6, alpha: 0.9)
        sparkle.lineWidth = 1
        sparkle.zRotation = .pi / 4
        sparkle.position = CGPoint(x: 0, y: 24)
        toy.addChild(sparkle)
        JuiceEngine.float(sparkle, distance: 4)

        worldNode.addChild(toy)
        backdropNodes.append(toy)
        toyMarker = toy
    }

    func removeToyMarker() {
        toyMarker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let t = toyMarker, let idx = backdropNodes.firstIndex(where: { $0 === t }) {
            backdropNodes.remove(at: idx)
        }
        toyMarker = nil
    }
}
