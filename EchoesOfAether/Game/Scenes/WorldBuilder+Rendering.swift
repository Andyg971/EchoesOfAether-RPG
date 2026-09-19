import SpriteKit

// Rendu : vignette de zone, sol plat, clôtures, autotile.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Vignette de zone (écran, ne scrolle pas)

    /// Assombrit les bords de l'écran — ambiance grotte/forêt profonde.
    /// Texture radiale rendue en basse résolution puis upscalée en
    /// .nearest : le dégradé reste en gros pixels, cohérent pixel art.
    /// alpha 0 = retire la vignette (village, zones claires).
    func setZoneVignette(in scene: SKScene, alpha: CGFloat) {
        scene.childNode(withName: "zoneVignette")?.removeFromParent()
        guard alpha > 0.01 else { return }

        let cols = 44, rows = 20
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            let c = ctx.cgContext
            for y in 0..<rows {
                for x in 0..<cols {
                    let nx = (CGFloat(x) + 0.5) / CGFloat(cols) * 2 - 1
                    let ny = (CGFloat(y) + 0.5) / CGFloat(rows) * 2 - 1
                    let d = min(1, sqrt(nx * nx + ny * ny * 0.85))
                    let a = pow(max(0, d - 0.45) / 0.55, 2) * alpha
                    guard a > 0.01 else { continue }
                    c.setFillColor(SKColor(red: 0.01, green: 0.01, blue: 0.02,
                                           alpha: a).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let vignette = SKSpriteNode(texture: texture)
        vignette.name = "zoneVignette"
        vignette.size = CGSize(width: scene.size.width + 4, height: scene.size.height + 4)
        vignette.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        vignette.zPosition = 480   // au-dessus du monde, sous HUD/overlays
        scene.addChild(vignette)
    }

    // MARK: - Sol plat (fond uni, sans tiles répétitives)

    func addFlatGroundVillage(in scene: SKScene, size: CGSize) {
        let base = SKShapeNode(rectOf: size)
        base.fillColor = SKColor(red: 0.32, green: 0.55, blue: 0.28, alpha: 1)
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2 - 48, y: size.height / 2 - 48)
        base.zPosition = -10
        add(base, to: scene)
    }

    func addFlatGroundForest(in scene: SKScene, size: CGSize) {
        let base = SKShapeNode(rectOf: size)
        base.fillColor = SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2 - 48, y: size.height / 2 - 48)
        base.zPosition = -10
        add(base, to: scene)
    }

    // MARK: - Clôture (rectangle d'assets fence ME)
    func addFenceRect(in scene: SKScene, at center: CGPoint, size: CGSize) {
        let tile: CGFloat = 16  // 48px × 0.33
        let scale: CGFloat = 0.33
        let halfW = size.width / 2
        let halfH = size.height / 2

        // Périmètre infranchissable (4 bandes fines sur les côtés)
        registerObstacle(CGRect(x: center.x - halfW - 5, y: center.y + halfH - 5,
                                width: size.width + 10, height: 10))
        registerObstacle(CGRect(x: center.x - halfW - 5, y: center.y - halfH - 5,
                                width: size.width + 10, height: 10))
        registerObstacle(CGRect(x: center.x - halfW - 5, y: center.y - halfH,
                                width: 10, height: size.height))
        registerObstacle(CGRect(x: center.x + halfW - 5, y: center.y - halfH,
                                width: 10, height: size.height))
        let cols = max(2, Int(size.width / tile))
        let rows = max(2, Int(size.height / tile))

        // Top + bottom
        for c in 0..<cols {
            let x = center.x - halfW + (CGFloat(c) + 0.5) * tile
            let name = c == 0 ? "me_fence_top_left" : (c == cols - 1 ? "me_fence_top_right" : "me_fence_top_mid")
            if let t = PixelArtSprites.still(name: name, scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: x, y: center.y + halfH)
                t.zPosition = -3
                add(t, to: scene)
            }
            let nb = c == 0 ? "me_fence_bot_left" : (c == cols - 1 ? "me_fence_bot_right" : "me_fence_bot_mid")
            if let t = PixelArtSprites.still(name: nb, scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: x, y: center.y - halfH)
                t.zPosition = -3
                add(t, to: scene)
            }
        }
        // Sides (middle row only — skip corners already placed)
        for r in 1..<(rows - 1) {
            let y = center.y - halfH + (CGFloat(r) + 0.5) * tile
            if let t = PixelArtSprites.still(name: "me_fence_mid_left", scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: center.x - halfW, y: y)
                t.zPosition = -3
                add(t, to: scene)
            }
            if let t = PixelArtSprites.still(name: "me_fence_mid_right", scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: center.x + halfW, y: y)
                t.zPosition = -3
                add(t, to: scene)
            }
        }
    }

    // MARK: - Rendu autotile (chemins de terre, étang du village)

    /// Pose les tuiles d'une `VillageTileMap` : tuiles pleines sur les
    /// cellules marquées, transitions nommées sur l'herbe adjacente
    /// (ex. `me_edge_n` = matière au nord de la cellule d'herbe).
    /// `tint` assombrit/teinte les tuiles (forêt sombre, etc.) pour
    /// rester assorti au sol teinté.
    /// `edgePrefix` nil = pas de tuiles de transition (les mines : la terre
    /// d'excavation s'arrête net sur la pierre, et les bords `me_edge_*`
    /// portent de l'herbe qui n'a rien à faire sous terre).
    /// `variants` : tuiles pleines interchangeables, tirées cellule par
    /// cellule. Une seule texture répétée sur une grande surface (le sable du
    /// désert) affiche sa trame en damier — le motif diagonal de `ds_sand`
    /// se lisait d'un bout à l'autre de la carte. Le tirage est DÉTERMINISTE
    /// (haché sur col/row) : le sol reste identique d'une entrée à l'autre.
    /// `skipping` : cellules à ne PAS peindre, sans toucher à la grille. Une
    /// route qui entre dans le désert y est rendue autrement (piste de
    /// gravier) ; la découper de `map` lui referait un bord — donc de
    /// l'herbe — en pleine dune. On masque au rendu, la topologie survit.
    func renderTileMap(_ map: VillageTileMap, fullTile: String,
                               edgePrefix: String?, in scene: SKScene, z: CGFloat,
                               tint: SKColor? = nil, tintBlend: CGFloat = 0.45,
                               tintJitter: CGFloat = 0, variants: [String] = [],
                               skipping: VillageTileMap? = nil) {
        for piece in map.pieces() {
            if piece.suffix != nil, edgePrefix == nil { continue }
            if skipping?.matter(piece.col, piece.row) == true { continue }
            let full = variants.isEmpty
                ? fullTile
                : variants[Self.tileHash(piece.col, piece.row) % variants.count]
            let name = piece.suffix.map { (edgePrefix ?? "") + $0 } ?? full
            guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                 anchor: .zero) else { continue }
            t.position = CGPoint(x: CGFloat(piece.col) * map.tile,
                                  y: CGFloat(piece.row) * map.tile)
            t.zPosition = piece.suffix == nil ? z : z + 0.05
            if let tint {
                // Jitter par cellule : une teinte STRICTEMENT uniforme sur des
                // centaines de tuiles fait une nappe plate et morte. Quelques
                // pour cent de variation, et le sol prend le grain de la
                // lumière filtrée. Haché sur la cellule, donc stable.
                let jitter = tintJitter <= 0 ? 0 : {
                    let unit = CGFloat(Self.tileHash(piece.col + 7, piece.row + 13) % 1000)
                    return (unit / 1000 - 0.5) * 2 * tintJitter
                }()
                let blend = max(0, min(1, tintBlend + jitter))
                t.forEachDescendantSprite { sprite in
                    sprite.color = tint
                    sprite.colorBlendFactor = blend
                }
            }
            add(t, to: scene)
        }
    }

    /// Hachage stable d'une cellule → choix de variante de tuile. Un simple
    /// `randomElement` redessinerait le sol différemment à chaque entrée dans
    /// la zone ; ici deux visites donnent exactement le même désert.
    /// Mélange complet (façon splitmix) : un simple `h * K` laisse ses bits de
    /// poids faible corrélés aux coordonnées, et `% n` derrière en fait un
    /// motif régulier — l'ombre du sous-bois se voyait en damier propre.
    static func tileHash(_ col: Int, _ row: Int) -> Int {
        var h = UInt64(bitPattern: Int64(col &* 73_856_093 ^ row &* 19_349_663))
        h ^= h >> 30; h = h &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 27; h = h &* 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        return Int(h % UInt64(Int.max))
    }
}
