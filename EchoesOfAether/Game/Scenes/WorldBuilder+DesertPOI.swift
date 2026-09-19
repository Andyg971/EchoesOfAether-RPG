import SpriteKit

// Désert d'Ossara — seconde moitié : campement, oasis, points d'intérêt.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    func addDesertVillager(_ asset: String, in scene: SKScene, at pos: CGPoint) {
        guard let npc = PixelArtSprites.animated(
            name: asset, frames: 6,
            scale: PixelArtSprites.scale(name: "\(asset)_idle_1",
                                         height: PixelArtSprites.npcHeight),
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        npc.position = pos
        npc.zPosition = depthLayer(for: pos.y, sceneHeight: scene.size.height)
        addGroundShadow(under: npc, width: 13, height: 4)
        add(npc, to: scene)
    }

    /// L'enceinte de la cité : courtines d'adobe (kit ds_wall_*) fermées
    /// sur les quatre côtés, percées de deux portes (sud et nord).
    ///
    /// Andy voulait la cité « bien fermée avec les remparts tout autour »
    /// (référence : TDRPG Desert de Raou, dont ces murs sont extraits).
    func addDesertRamparts(in scene: SKScene, w: CGFloat, h: CGFloat) {
        let southY = h * 0.375
        let northY = h * 0.635
        let leftX  = w * 0.10
        let rightX = w * 0.90
        // ds_gate2 : 197 px × 0,65 = 128 pt de façade.
        let gateHalf: CGFloat = 64

        for y in [southY, northY] {
            addWallGate(in: scene, at: CGPoint(x: w * 0.50, y: y))
            addWallRun(in: scene, fromX: leftX, toX: w * 0.50 - gateHalf, y: y)
            addWallRun(in: scene, fromX: w * 0.50 + gateHalf, toX: rightX, y: y)
        }
        addWallColumn(in: scene, x: leftX, fromY: southY, toY: northY)
        addWallColumn(in: scene, x: rightX, fromY: southY, toY: northY)

        // Tours d'angle : un embout de mur coiffe chaque coin — sans elles,
        // les jointures des courtines se lisaient comme un bug de tuiles.
        for (cx, cy) in [(leftX, southY), (rightX, southY),
                         (leftX, northY), (rightX, northY)] {
            addDesertProp("ds_wall_end", in: scene, at: CGPoint(x: cx, y: cy - 4))
        }
        // Porte de service à l'est : une palissade fermée dans la courtine
        // (purement visuelle — l'obstacle du flanc reste continu).
        addDesertProp("ds_palisade_gate", in: scene,
                      at: CGPoint(x: rightX, y: h * 0.520))
    }

    /// Courtine horizontale : tuiles ds_wall_h enchaînées + obstacle continu.
    func addWallRun(in scene: SKScene, fromX x0: CGFloat, toX x1: CGFloat, y: CGFloat) {
        guard x1 > x0 else { return }
        let scale = WorldBuilder.desertDisplayScale(for: "ds_wall_h")
        let tileW = 48 * scale
        var x = x0 + tileW / 2
        while x < x1 + 1 {
            guard let t = PixelArtSprites.still(name: "ds_wall_h", scale: scale,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { break }
            t.position = CGPoint(x: min(x, x1 - tileW / 2), y: y)
            t.zPosition = depthLayer(for: y, sceneHeight: scene.size.height)
            add(t, to: scene)
            x += tileW
        }
        registerObstacle(CGRect(x: x0, y: y - 2, width: x1 - x0, height: 16))
    }

    /// Flanc vertical : tuiles ds_wall_v empilées + obstacle continu.
    func addWallColumn(in scene: SKScene, x: CGFloat, fromY y0: CGFloat, toY y1: CGFloat) {
        guard y1 > y0 else { return }
        let scale = WorldBuilder.desertDisplayScale(for: "ds_wall_v")
        let tileH = 48 * scale
        var y = y0
        while y < y1 {
            guard let t = PixelArtSprites.still(name: "ds_wall_v", scale: scale,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { break }
            t.position = CGPoint(x: x, y: min(y, y1 - tileH))
            t.zPosition = depthLayer(for: t.position.y, sceneHeight: scene.size.height)
            add(t, to: scene)
            y += tileH
        }
        registerObstacle(CGRect(x: x - 10, y: y0, width: 20, height: y1 - y0))
    }

    /// Porte de l'enceinte : arche beige, deux emprises (une par pilier),
    /// le passage central reste ouvert. Mesuré sur l'asset (197 px) : l'arche
    /// occupe ~36 % à 64 % de la largeur.
    func addWallGate(in scene: SKScene, at pos: CGPoint) {
        guard let gate = PixelArtSprites.still(name: "ds_gate2",
                                               scale: WorldBuilder.desertDisplayScale(for: "ds_gate2"),
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        gate.position = pos
        gate.zPosition = depthLayer(for: pos.y, sceneHeight: scene.size.height)
        add(gate, to: scene)

        let f = gate.calculateAccumulatedFrame()
        let depth: CGFloat = 16
        registerObstacle(CGRect(x: f.minX, y: pos.y - 2,
                                width: f.width * 0.36, height: depth))
        registerObstacle(CGRect(x: f.minX + f.width * 0.64, y: pos.y - 2,
                                width: f.width * 0.36, height: depth))
    }

    /// Ceinture de falaises : le désert est un canyon, ses bords ont du
    /// volume (mesas ds_cliff_* du pack, plus un simple sable plat qui
    /// s'arrête au bord de l'écran). Chaînées avec chevauchement pour
    /// former une crête continue ; la marche est bloquée par des bandes
    /// d'obstacles, pas par les sprites.
    func addDesertCliffs(in scene: SKScene, w: CGFloat, h: CGFloat) {
        // La crête ne se répète pas : chaque mesa tire son décalage, son
        // échelle et ses accents d'un LCG seedé — même recette que les
        // fleurs du village. Une grande mesa porte la ligne ; devant elle,
        // parfois, une petite en contrebas et un éboulis au pied.
        var seed: UInt64 = 0x055A_44A7
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        let rubble = ["ds_boulder", "ds_rock_pile", "ds_boulder2", "ds_rock_big"]

        // Les flancs sont portés par les BANDES de plateau (autotiler, dans
        // buildDesert) : ici on ne pose que des surplombs — quelques mesas
        // ASSISES SUR la bande, jamais sur le sable — et des éboulis à la
        // frontière sable/roche. Empilées sur le sable, elles se lisaient
        // comme des dalles flottantes.
        var y = h * 0.05
        while y < h * 0.92 {
            if next() > 0.35 {
                addDesertProp("ds_cliff_big", in: scene,
                              at: CGPoint(x: w * (0.012 + next() * 0.022), y: y),
                              scale: 0.42 + next() * 0.10)
            }
            if next() > 0.35 {
                addDesertProp("ds_cliff_big", in: scene,
                              at: CGPoint(x: w * (0.966 + next() * 0.022), y: y + next() * 20),
                              scale: 0.42 + next() * 0.10, flipped: true)
            }
            if next() > 0.40 {
                addDesertProp(rubble[Int(next() * 4) % 4], in: scene,
                              at: CGPoint(x: w * (0.076 + next() * 0.014), y: y + next() * 30))
            }
            if next() > 0.40 {
                addDesertProp(rubble[Int(next() * 4) % 4], in: scene,
                              at: CGPoint(x: w * (0.910 + next() * 0.014), y: y + next() * 30))
            }
            y += h * (0.075 + next() * 0.045)
        }

        // Fond nord : la crête ferme le monde derrière l'oasis.
        var x = w * 0.04
        while x < w * 0.98 {
            addDesertProp("ds_cliff_big", in: scene,
                          at: CGPoint(x: x, y: h * (0.962 + next() * 0.016)),
                          scale: 0.46 + next() * 0.12, flipped: next() > 0.5)
            x += w * (0.085 + next() * 0.040)
        }

        // Épaules de l'entrée sud : le canyon s'ouvre sur le centre,
        // épaissi de blocs pour ne pas laisser des tours isolées.
        for (fx, flip) in [(0.09, false), (0.20, true), (0.30, false),
                           (0.70, true), (0.80, false), (0.91, true)] {
            addDesertProp("ds_cliff_left", in: scene,
                          at: CGPoint(x: w * fx, y: h * 0.004), flipped: flip)
            if next() > 0.4 {
                addDesertProp(rubble[Int(next() * 4) % 4], in: scene,
                              at: CGPoint(x: w * fx + (next() - 0.5) * 40, y: h * 0.020))
            }
        }

        // La marche : bandes continues, indépendantes des sprites.
        registerObstacle(CGRect(x: 0, y: 0, width: w * 0.072, height: h))
        registerObstacle(CGRect(x: w * 0.928, y: 0, width: w * 0.072, height: h))
        registerObstacle(CGRect(x: 0, y: h * 0.952, width: w, height: h * 0.048))
        registerObstacle(CGRect(x: 0, y: 0, width: w * 0.34, height: h * 0.018))
        registerObstacle(CGRect(x: w * 0.66, y: 0, width: w * 0.34, height: h * 0.018))
    }

    /// Faces de falaise : sous chaque cellule de paroi dont le sud est
    /// vide, la pierre empilée du pack (48 px → 24 pt, deux par cellule
    /// de 48 pt). C'est l'indice de hauteur qui manquait : sans face, une
    /// paroi vue de dessus n'est qu'une texture posée sur le sable.
    func addCliffFaces(for map: VillageTileMap, cell: CGFloat, in scene: SKScene) {
        let half = cell / 2
        for r in 1..<map.rows {
            for c in 0..<map.cols where map.matter(c, r) && !map.matter(c, r - 1) {
                for i in 0..<2 {
                    let name: String
                    if i == 0, !map.matter(c - 1, r) {
                        name = "ds_cliff_face_l"
                    } else if i == 1, !map.matter(c + 1, r) {
                        name = "ds_cliff_face_r"
                    } else {
                        name = "ds_cliff_face"
                    }
                    guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                        anchor: CGPoint(x: 0, y: 1)) else { continue }
                    t.position = CGPoint(x: CGFloat(c) * cell + CGFloat(i) * half,
                                         y: CGFloat(r) * cell)
                    t.zPosition = -9.4
                    add(t, to: scene)
                }
            }
        }
    }

    /// Détails semés sur le sable libre (LCG seedé, hors cité/oasis/bords) —
    /// la technique des fleurs du village, portée au désert : c'est ce qui
    /// sépare une zone habillée d'un fond vide.
    func scatterDesertDetails(in scene: SKScene, w: CGFloat, h: CGFloat) {
        // L'oasis et les trois terrains de combat sont désormais COMPOSÉS
        // (palmeraie, halte, couronne de blocs, ossements). Y semer par-dessus
        // du décor au hasard brouillait la composition — d'où leur réserve.
        let reserved: [CGRect] = [
            CGRect(x: 0, y: h * 0.355, width: w, height: h * 0.30),        // cité
            CGRect(x: w * 0.06, y: h * 0.115, width: w * 0.38, height: h * 0.21), // oasis
            CGRect(x: w * 0.40, y: 0, width: w * 0.14, height: h * 0.38),  // allée pavée
            CGRect(x: w * 0.28, y: h * 0.21, width: w * 0.16, height: h * 0.07), // branche oasis
            CGRect(x: w * 0.45, y: h * 0.19, width: w * 0.36, height: h * 0.12), // arène sud
            CGRect(x: w * 0.42, y: h * 0.60, width: w * 0.38, height: h * 0.13), // arène canyon
            CGRect(x: w * 0.18, y: h * 0.79, width: w * 0.46, height: h * 0.15), // arène du boss
            CGRect(x: 0, y: 0, width: w, height: h * 0.065),               // entrée
            CGRect(x: 0, y: 0, width: w * 0.10, height: h),                // falaises O
            CGRect(x: w * 0.90, y: 0, width: w * 0.10, height: h),         // falaises E
            CGRect(x: 0, y: h * 0.93, width: w, height: h * 0.07)          // crête N
        ]
        let details = ["ds_grass_dry", "ds_bush_dead3", "ds_tumbleweed", "ds_skull",
                       "ds_bone", "ds_flower_orange", "ds_cactus_small", "ds_rock_pile"]
        var seed: UInt64 = 0x0D45_E27B
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        var placed = 0
        var attempts = 0
        while placed < 34 && attempts < 300 {
            attempts += 1
            let p = CGPoint(x: w * 0.08 + next() * w * 0.84,
                            y: h * 0.07 + next() * h * 0.86)
            if reserved.contains(where: { $0.contains(p) }) { continue }
            addDesertProp(details[Int(next() * 8) % 8], in: scene, at: p)
            placed += 1
        }
    }

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

    /// Un TERRAIN DE COMBAT : l'endroit où l'on se bat doit se lire avant que
    /// le monstre ne charge. Les rôdeurs d'Ossara apparaissaient sur du sable
    /// nu, aussi anonyme que le reste de la traversée — rien ne disait « ça
    /// va se jouer ici », et rien ne restait après.
    ///
    /// La recette : un sol assombri qui délimite l'aire, une couronne de blocs
    /// qui la ferme (on tourne autour, on ne fuit pas en ligne droite), et au
    /// centre les restes de ceux qui ont perdu.
    func addDesertBattleground(in scene: SKScene, at pos: CGPoint,
                                       radiusX: CGFloat, radiusY: CGFloat,
                                       ring: [String], litter: [String],
                                       cell: CGFloat) {
        // L'aire est une COUR, pas une flaque. Premier essai en ellipse : à
        // 48 pt la tuile pour 140 pt de hauteur utile, la courbe se quantifiait
        // en rectangle ébréché — un rond raté. Une cour de caravansérail est
        // rectangulaire de plein droit ; on assume la forme et on l'assume
        // franchement, coins rabattus pour qu'elle ne soit pas une boîte.
        var ground = VillageTileMap(width: pos.x * 2 + radiusX * 3,
                                    height: pos.y * 2 + radiusY * 3, tile: cell)
        ground.stamp(rect: CGRect(x: pos.x - radiusX, y: pos.y - radiusY,
                                  width: radiusX * 2, height: radiusY * 2))
        for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            ground.clear(rect: CGRect(x: pos.x + CGFloat(sx) * radiusX
                                          - (sx < 0 ? 0 : cell),
                                      y: pos.y + CGFloat(sy) * radiusY
                                          - (sy < 0 ? 0 : cell),
                                      width: cell, height: cell))
        }
        // Gravier, pas terre craquelée : au nord la zone EST déjà craquelée,
        // une aire de la même matière n'y ressortait pas. Le reg est la seule
        // texture minérale du pack — au sol, on voit qu'on a changé d'endroit.
        renderTileMap(ground, fullTile: "ds_gravel", edgePrefix: nil,
                      in: scene, z: -9.45,
                      tint: SKColor(red: 0.32, green: 0.18, blue: 0.12, alpha: 1),
                      tintBlend: 0.26)

        var seed: UInt64 = 0xB47_71E
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        // La bordure : colonnes et blocs le long des quatre côtés, plus serrés
        // aux angles. Trouées au nord et au sud — le joueur arrive par la
        // piste, on ne le mure pas dehors. Posés PLUS GROS que le décor
        // courant : à l'échelle du sable ils se perdaient dans les cailloux.
        var k = 0
        func edgeProp(_ p: CGPoint) {
            let asset = ring[k % ring.count]; k += 1
            addDesertProp(asset, in: scene, at: p,
                          scale: Self.desertDisplayScale(for: asset) * 1.55)
        }
        let steps = max(4, Int(radiusX * 2 / 84))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = pos.x - radiusX + radiusX * 2 * t
            let jitter = (next() - 0.5) * 14
            if abs(t - 0.5) > 0.12 {          // trouée centrale, au sud et au nord
                edgeProp(CGPoint(x: x, y: pos.y - radiusY - 10 + jitter))
                edgeProp(CGPoint(x: x, y: pos.y + radiusY + 6 + jitter))
            }
        }
        for i in 0...2 {
            let t = CGFloat(i) / 2
            let y = pos.y - radiusY * 0.7 + radiusY * 1.4 * t
            edgeProp(CGPoint(x: pos.x - radiusX - 12 + (next() - 0.5) * 10, y: y))
            edgeProp(CGPoint(x: pos.x + radiusX + 12 + (next() - 0.5) * 10, y: y))
        }
        // Les restes, au centre : ossements, colonnes brisées, feu éteint.
        for (i, asset) in litter.enumerated() {
            let a = CGFloat(i) / CGFloat(max(1, litter.count)) * .pi * 2 + 0.9
            addDesertProp(asset, in: scene,
                          at: CGPoint(x: pos.x + cos(a) * radiusX * (0.22 + next() * 0.34),
                                      y: pos.y + sin(a) * radiusY * (0.22 + next() * 0.34)))
        }
    }

    /// Chemin pavé du pack (ds_path_v/h) : l'allée qui guide de l'entrée
    /// à la porte sud, avec un crochet et une branche vers l'oasis. Les
    /// jonctions se recouvrent — le pavé organique le pardonne.
    func addDesertPathTiles(in scene: SKScene, w: CGFloat, h: CGFloat) {
        let t: CGFloat = 24
        func vSeg(_ x: CGFloat, _ yFrom: CGFloat, _ yTo: CGFloat) {
            var y = yFrom
            while y < yTo {
                guard let tile = PixelArtSprites.still(name: "ds_path_v", scale: 0.5,
                                                       anchor: .zero) else { return }
                tile.position = CGPoint(x: x - t / 2, y: y)
                tile.zPosition = -9.55
                add(tile, to: scene)
                y += t
            }
        }
        func hSeg(_ y: CGFloat, _ xFrom: CGFloat, _ xTo: CGFloat) {
            var x = xFrom
            while x < xTo {
                guard let tile = PixelArtSprites.still(name: "ds_path_h", scale: 0.5,
                                                       anchor: .zero) else { return }
                tile.position = CGPoint(x: x, y: y - t / 2)
                tile.zPosition = -9.55
                add(tile, to: scene)
                x += t
            }
        }
        vSeg(w * 0.50, h * 0.050, h * 0.195)
        hSeg(h * 0.195, w * 0.435, w * 0.505)
        vSeg(w * 0.44, h * 0.195, h * 0.300)
        hSeg(h * 0.300, w * 0.435, w * 0.505)
        vSeg(w * 0.50, h * 0.300, h * 0.373)
        // Branche vers l'oasis, depuis le crochet.
        hSeg(h * 0.242, w * 0.315, w * 0.44)
    }

    /// Monstre visible dans les dunes : sprite ennemi idle, teinté sable.
    /// Coffre à demi enfoui dans le sable, cerclé de fer.
    func makeBuriedChest(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = depthLayer(for: pos.y)

        // Monticule de sable
        let mound = SKShapeNode(rectOf: CGSize(width: 52, height: 12))
        mound.fillColor = SKColor(red: 0.88, green: 0.74, blue: 0.44, alpha: 1)
        mound.strokeColor = .clear
        mound.position = CGPoint(x: 0, y: -8)
        node.addChild(mound)

        // Couvercle visible du coffre
        let lid = SKShapeNode(rectOf: CGSize(width: 34, height: 16))
        lid.fillColor = SKColor(red: 0.36, green: 0.22, blue: 0.10, alpha: 1)
        lid.strokeColor = SKColor(red: 0.20, green: 0.12, blue: 0.05, alpha: 1)
        lid.lineWidth = 1.5
        lid.position = CGPoint(x: 0, y: 2)
        node.addChild(lid)

        for dx: CGFloat in [-10, 10] {
            let band = SKSpriteNode(color: SKColor(red: 0.62, green: 0.58, blue: 0.50, alpha: 1),
                                    size: CGSize(width: 3, height: 16))
            band.position = CGPoint(x: dx, y: 2)
            node.addChild(band)
        }

        let glow = SKShapeNode(circleOfRadius: 26)
        glow.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.06)
        glow.strokeColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.18)
        glow.lineWidth = 1
        node.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)
        return node
    }

    /// Retire le coffre enfoui (après ramassage).
    func removeBuriedChest() {
        guard let chest = worldNode.childNode(withName: "desertChest") else { return }
        chest.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
}
