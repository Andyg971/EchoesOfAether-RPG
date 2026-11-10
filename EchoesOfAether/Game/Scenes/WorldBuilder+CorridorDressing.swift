import SpriteKit

// Habillage commun des zones-couloirs (Ruines, Seuil, Cœur du Vide) :
// faces de paroi et mobilier funéraire le long des murs.
extension WorldBuilder {
    typealias CorridorBand = (y0: CGFloat, y1: CGFloat, left: CGFloat, right: CGFloat)

    /// FACES DE PAROI — la pierre vue de face, là où un mur surplombe le sol.
    ///
    /// Les parois n'étaient que des aplats sombres bordés d'un trait : vues
    /// du dessus, sans face, elles se lisaient comme une ombre portée sur le
    /// dallage, pas comme de la roche qui monte. Même leçon qu'au désert —
    /// une paroi top-down n'existe que par sa face sud.
    ///
    /// Une face apparaît chaque fois que le couloir se RESSERRE en montant :
    /// le bloc de la bande du dessus déborde alors au-dessus du sol de la
    /// bande du dessous. On y pose la moitié basse de `me_wall_2` (appareil
    /// de pierre), teintée à la couleur de la zone. Purement visuel : la
    /// collision reste celle du bloc (`addWall`).
    func addWallFaces(bands: [CorridorBand], w: CGFloat, h: CGFloat,
                      tint: SKColor, in scene: SKScene) {
        guard PixelArtSprites.exists("me_wall_2") else { return }
        let base = SKTexture(imageNamed: "me_wall_2")
        let face = SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: 0.5), in: base)
        face.filteringMode = .nearest
        let tile = CGSize(width: 48, height: 24)

        func run(from x0: CGFloat, to x1: CGFloat, y: CGFloat) {
            guard x1 - x0 > 6 else { return }
            var x = x0
            while x < x1 - 0.5 {
                let sprite = SKSpriteNode(texture: face, size: tile)
                sprite.anchorPoint = .zero
                // Dernière tuile recalée sur le bord : pas de débord dans le vide.
                sprite.position = CGPoint(x: min(x, max(x0, x1 - tile.width)), y: y)
                sprite.color = tint
                sprite.colorBlendFactor = 0.62
                sprite.zPosition = -7.5
                add(sprite, to: scene)
                x += tile.width
            }
            // Arête haute : un liseré clair détache la face du dessus du mur.
            let lip = SKSpriteNode(color: tint.withAlphaComponent(0.9),
                                   size: CGSize(width: x1 - x0, height: 2))
            lip.anchorPoint = .zero
            lip.position = CGPoint(x: x0, y: y + tile.height)
            lip.zPosition = -7.4
            add(lip, to: scene)
        }

        for (below, above) in zip(bands, bands.dropFirst()) {
            let y = h * above.y0
            if above.left > below.left {
                run(from: w * below.left, to: w * above.left, y: y)
            }
            if above.right < below.right {
                run(from: w * above.right, to: w * below.right, y: y)
            }
        }
    }

    /// MOBILIER FUNÉRAIRE — cercueils, sarcophages, arbres morts et gravats
    /// rangés le long des parois.
    ///
    /// Les trois zones tenaient en une dizaine de props chacune sur quatre
    /// écrans de haut : entre deux points d'intérêt, le joueur traversait du
    /// dallage nu. Le placement est déterministe (hash de la bande), collé
    /// aux murs, et s'efface autour des points d'intérêt (`avoid`) : le
    /// milieu du couloir et l'accès aux stèles restent libres.
    func dressCorridor(bands: [CorridorBand], w: CGFloat, h: CGFloat,
                       avoid: [CGPoint], in scene: SKScene) {
        let solids = ["gy_coffin_open", "gy_sarcophagus", "gy_tree_bare_1",
                      "gy_coffin_skeleton", "gy_cross_large", "gy_coffin_closed",
                      "gy_tree_bare_2", "gy_coffin_bones", "gy_skeleton"]
        let rubble = ["gy_pebbles_1", "gy_ribcage", "gy_pebbles_2", "gy_pebbles_1"]

        func isFree(_ p: CGPoint, radius: CGFloat) -> Bool {
            !avoid.contains { hypot($0.x - p.x, $0.y - p.y) < radius }
        }

        for (index, band) in bands.enumerated() {
            let x0 = w * band.left, x1 = w * band.right
            let y0 = h * band.y0, y1 = h * band.y1
            let width = x1 - x0, height = y1 - y0

            // Gravats : plats, franchissables, sur les bas-côtés.
            var y = y0 + 22
            var row = 0
            while y < y1 - 14 {
                let n = Self.tileHash(index * 31 + 5, row)
                let onLeft = n % 2 == 0
                let inset = width * (0.06 + CGFloat((n >> 3) % 20) / 100)   // 6–26 %
                let p = CGPoint(x: onLeft ? x0 + inset : x1 - inset, y: y)
                let name = rubble[(n >> 9) % rubble.count]
                if width > 120, isFree(p, radius: 60),
                   let node = PixelArtSprites.still(name: name, scale: 0.5,
                                                    anchor: CGPoint(x: 0.5, y: 0.0)) {
                    node.position = p
                    node.zPosition = -3   // au sol, sous les acteurs
                    if (n >> 14) % 2 == 0 { node.xScale = -1 }
                    add(node, to: scene)
                }
                y += 58 + CGFloat((n >> 6) % 34)
                row += 1
            }

            // Mobilier solide : seulement dans les salles (assez larges pour
            // qu'un cercueil contre le mur ne ferme pas le passage).
            guard width >= 300, height >= 110 else { continue }
            var sy = y0 + 48
            var slot = 0
            while sy < y1 - 40 {
                for onLeft in [true, false] {
                    let n = Self.tileHash(index * 17 + (onLeft ? 3 : 8), slot)
                    guard n % 5 != 0 else { continue }   // des trous : pas une haie
                    let inset = 30 + CGFloat((n >> 4) % 22)
                    let p = CGPoint(x: onLeft ? x0 + inset : x1 - inset,
                                    y: sy + CGFloat((n >> 8) % 26))
                    guard p.y < y1 - 30, isFree(p, radius: 100) else { continue }
                    addPixelProp(solids[(n >> 12) % solids.count], in: scene,
                                 at: p, scale: 0.5, flipped: !onLeft)
                }
                sy += 150
                slot += 1
            }
        }
    }
}
