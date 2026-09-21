import SpriteKit

// Désert d'Ossara — seconde moitié : campement, oasis, points d'intérêt.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    /// Figurant de la cité : animation d'idle, pas d'errance (ils ont peur).
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
