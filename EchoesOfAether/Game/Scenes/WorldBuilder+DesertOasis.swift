import SpriteKit

// Désert d'Ossara — l'oasis : bassin organique, source, palmeraie, campement.
extension WorldBuilder {
    /// Bassin d'oasis : la VRAIE eau du pack — tuiles 48 px assemblées
    /// cellule par cellule sur une ellipse (eau pleine au centre, berges
    /// nommées par leur(s) côté(s) sable), et la source qui jaillit posée
    /// dessus. Le rectangle SKShapeNode dessiné en code était le dernier
    /// élément de la zone à ne pas venir du pack.
    func addOasis(in scene: SKScene, at pos: CGPoint, w: CGFloat, h: CGFloat) {
        // Bassin ORGANIQUE. Il était tracé au rectangle — six tuiles sur
        // quatre — faute de savoir border une ellipse : une cellule en pointe
        // manque de berge sur trois côtés et le pack n'a pas la tuile. La
        // forme est donc ÉRODÉE avant d'être bordée (cf. `erodeUnborderable`),
        // et une mare d'oasis a enfin la silhouette d'une mare.
        let cell: CGFloat = 24
        var pond = VillageTileMap(width: w, height: h, tile: cell)
        pond.stampEllipse(center: pos, radiusX: 126, radiusY: 70)
        pond.stampEllipse(center: CGPoint(x: pos.x + 58, y: pos.y - 30),
                          radiusX: 62, radiusY: 42)
        pond.stampEllipse(center: CGPoint(x: pos.x - 66, y: pos.y + 24),
                          radiusX: 54, radiusY: 36)
        pond.erodeUnborderable()

        for r in 0..<pond.rows {
            for c in 0..<pond.cols where pond.matter(c, r) {
                let n = pond.matter(c, r + 1), s = pond.matter(c, r - 1)
                let e = pond.matter(c + 1, r), o = pond.matter(c - 1, r)
                let name: String
                switch (n, s, e, o) {
                case (false, _, _, false): name = "ds_water_nw"
                case (false, _, false, _): name = "ds_water_ne"
                case (_, false, _, false): name = "ds_water_sw"
                case (_, false, false, _): name = "ds_water_se"
                case (false, _, _, _):     name = "ds_water_n"
                case (_, false, _, _):     name = "ds_water_s"
                case (_, _, false, _):     name = "ds_water_e"
                case (_, _, _, false):     name = "ds_water_w"
                default:                   name = "ds_water"
                }
                guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                    anchor: .zero) else { continue }
                t.position = CGPoint(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
                t.zPosition = -9.3
                add(t, to: scene)
                // L'obstacle suit la forme, cellule par cellule : un seul
                // rectangle laissait marcher sur l'eau des lobes et barrait
                // du sable aux quatre coins.
                registerObstacle(CGRect(x: CGFloat(c) * cell + 3,
                                        y: CGFloat(r) * cell + 3,
                                        width: cell - 6, height: cell - 6))
            }
        }

        // La source, posée sur l'eau (même texture : le raccord se fond).
        if let spring = PixelArtSprites.still(name: "ds_water_spring", scale: 0.5,
                                              anchor: CGPoint(x: 0.5, y: 0.5)) {
            spring.position = CGPoint(x: pos.x - 8, y: pos.y + 4)
            spring.zPosition = -9.25
            add(spring, to: scene)
            JuiceEngine.pulse(spring, scale: 1.04)
        }

        // ── LA PALMERAIE : une oasis, c'est d'abord de l'ombre. Trois palmiers
        // épars ne faisaient pas une halte ; ici la couronne est fermée, dense
        // au nord (dos au vent) et ouverte au sud, là où la piste arrive.
        for (dx, dy) in [(-150.0, 34.0), (-104.0, 82.0), (-30.0, 104.0),
                         (46.0, 100.0), (118.0, 72.0), (158.0, 16.0),
                         (150.0, -44.0), (-142.0, -34.0), (-96.0, -76.0),
                         (92.0, -82.0)] {
            // Les hauts au nord (l'ombre porte vers la halte), les petits sur
            // les flancs : la couronne a un dessus et un dessous.
            let asset = abs(dx) > 120 ? "ds_palm_small"
                      : (dy > 0 ? "ds_palm_tall1" : "ds_palm_tall2")
            addDesertProp(asset, in: scene,
                          at: CGPoint(x: pos.x + CGFloat(dx), y: pos.y + CGFloat(dy)))
        }

        // ── LA HALTE : ce que des caravaniers laissent au bord de l'eau.
        // Sans elle, l'oasis n'était qu'un décor à contourner ; avec, c'est
        // une étape, et le joueur comprend pourquoi la piste passe par là.
        for (asset, dx, dy) in [("ds_tent_round", -122.0, -12.0),
                                ("ds_tent_small", -76.0, -58.0),
                                ("ds_campfire", -34.0, -74.0),
                                ("ds_rug", 12.0, -80.0),
                                ("ds_sacks", 58.0, -66.0),
                                ("ds_pot", -8.0, -52.0),
                                ("ds_camel_1", 118.0, -30.0)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: pos.x + dx, y: pos.y + dy))
        }

        // ── LA RIVE : roseaux, fleurs et herbes grasses collés à l'eau. C'est
        // ce liseré de vert qui dit « ici ça pousse », pas les palmiers seuls.
        let bank = ["ds_grass_dry", "ds_oasis_flower", "ds_flowers",
                    "ds_flowers_red", "ds_flower_orange", "ds_grass_dry"]
        var seed: UInt64 = 0x0A51_5A11
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        for i in 0..<26 {
            let a = CGFloat(i) / 26 * .pi * 2
            let ray = 1.06 + next() * 0.22
            let p = CGPoint(x: pos.x + cos(a) * 126 * ray,
                            y: pos.y + sin(a) * 70 * ray)
            addDesertProp(bank[Int(next() * 6) % 6], in: scene, at: p)
        }

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.desert.oasis")
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.30, green: 0.50, blue: 0.55, alpha: 0.9)
        label.position = CGPoint(x: pos.x, y: pos.y + 126)
        label.zPosition = -1
        add(label, to: scene)
    }
}
