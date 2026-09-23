import SpriteKit

// Carte du monde — seconde moitié : points d'intérêt, coffres, voyage.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    /// Marque une ROUTE entre deux lieux dans la grille d'autotiling : un ruban
    /// de cellules de terre qui serpente doucement. Les transitions herbe/terre
    /// sont posées ensuite par `renderTileMap` — d'où le rendu net des autres
    /// zones, au lieu de plaques carrées superposées.
    /// `half` : demi-largeur du ruban. Une route de plaine s'assume large ;
    /// sous les arbres, le même gabarit ouvrait une saignée de terre nue qui
    /// annulait le couvert — le sentier forestier passe donc en étroit.
    func stampRoad(_ map: inout VillageTileMap, from a: CGPoint, to b: CGPoint,
                           half: CGFloat = 15) {
        let dx = b.x - a.x, dy = b.y - a.y
        let dist = max(1, (dx * dx + dy * dy).squareRoot())
        let steps = max(4, Int(dist / 10))       // pas serré : ruban continu
        let px = -dy / dist, py = dx / dist      // perpendiculaire normalisée
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            // Serpentement qui s'annule aux extrémités : la route arrive droit
            // sur la clairière du lieu.
            let td = Double(t)
            let swing: Double = sin(td * .pi * 2)
            let taper: Double = sin(td * .pi)
            let wobble = CGFloat(swing * taper * 18.0)
            let cx: CGFloat = a.x + dx * t + px * wobble
            let cy: CGFloat = a.y + dy * t + py * wobble
            map.stamp(rect: CGRect(x: cx - half, y: cy - half,
                                   width: half * 2, height: half * 2))
        }
    }

    /// Empreinte rectangulaire d'un lac elliptique (pour en écarter le décor).
    func lakeRect(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
        CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)
    }

    func overworldPatch(_ tiles: [String], rect: CGRect,
                                tileScale: CGFloat, z: CGFloat, in scene: SKScene) {
        guard let node = PixelArtSprites.tiledFloor(tileNames: tiles, in: rect.size,
                                                    tileScale: tileScale) else { return }
        node.position = CGPoint(x: rect.minX, y: rect.minY)
        node.zPosition = z
        add(node, to: scene)
    }

    /// Région au bord IRRÉGULIER : plusieurs plaques carrées de tailles et
    /// positions variées qui se chevauchent autour d'un centre — l'union ne
    /// ressemble plus à un rectangle net.
    func blobPatch(_ tiles: [String], center: CGPoint, blobs: Int,
                           minSize: CGFloat, maxSize: CGFloat, spread: CGFloat,
                           tileScale: CGFloat, z: CGFloat, in scene: SKScene) {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<blobs {
            let sz = CGFloat.random(in: minSize...maxSize, using: &rng)
            let c = CGPoint(x: center.x + .random(in: -spread...spread, using: &rng),
                            y: center.y + .random(in: -spread...spread, using: &rng))
            overworldPatch(tiles,
                           rect: CGRect(x: c.x - sz / 2, y: c.y - sz / 2,
                                        width: sz, height: sz),
                           tileScale: tileScale, z: z, in: scene)
        }
    }

    /// Sème du décor dans une région. `avoiding` : zones interdites (lac,
    /// sable…) — sans quoi des fleurs poussent sur l'eau.
    /// Échelle à appliquer pour qu'un asset occupe `height` points à l'écran,
    /// quelle que soit la taille native de sa planche. Mélanger des packs
    /// d'origines différentes (64 px, 96 px, 192 px) à une échelle commune
    /// donnait des blocs deux fois plus hauts que leurs voisins.
    func scaleFor(_ asset: String, height: CGFloat) -> CGFloat {
        guard let native = PixelArtSprites.pixelHeight(of: asset), native > 0
        else { return 1 }
        return height / native
    }

    /// Une espèce de végétation : son asset et la HAUTEUR À L'ÉCRAN visée.
    /// Les planches vont de 64 à 192 px de haut ; les rendre toutes à la même
    /// échelle donnait des arbres géants à côté d'arbustes — d'où le fouillis.
    /// Ici chaque espèce est normalisée, donc la forêt a une échelle crédible.
    struct Flora {
        let asset: String
        let height: CGFloat    // hauteur visée à l'écran, en points
        let weight: Int        // fréquence relative dans le massif
    }

    /// Plante un MASSIF (forêt ou oasis d'un désert) dans une ellipse :
    /// densité DÉGRESSIVE du cœur vers la lisière, positions sur une grille
    /// jitterée (ni trous béants ni paquets), profondeur triée par Y.
    /// C'est ce qui fait lire « forêt » au lieu de « arbres éparpillés ».
    func plantMass(_ species: [Flora], center: CGPoint,
                           radiusX: CGFloat, radiusY: CGFloat,
                           step: CGFloat, coreDensity: Double, edgeDensity: Double,
                           avoiding: [CGRect] = [], in scene: SKScene) {
        guard !species.isEmpty else { return }
        var rng = SystemRandomNumberGenerator()
        // Tirage pondéré : la canopée domine, les accents restent des accents.
        var pool: [Flora] = []
        for s in species { pool.append(contentsOf: Array(repeating: s, count: max(1, s.weight))) }

        var y = center.y - radiusY
        while y <= center.y + radiusY {
            var x = center.x - radiusX
            while x <= center.x + radiusX {
                // Distance normalisée au centre de l'ellipse (0 = cœur, 1 = bord).
                let nx = (x - center.x) / max(1, radiusX)
                let ny = (y - center.y) / max(1, radiusY)
                let d = (nx * nx + ny * ny).squareRoot()
                defer { x += step }
                guard d <= 1 else { continue }
                // Le couvert s'éclaircit vers la lisière : bord naturel, pas net.
                let density = coreDensity + (edgeDensity - coreDensity) * Double(d)
                guard Double.random(in: 0...1, using: &rng) < density else { continue }

                let jx = CGFloat.random(in: -step * 0.42...step * 0.42, using: &rng)
                let jy = CGFloat.random(in: -step * 0.42...step * 0.42, using: &rng)
                let p = CGPoint(x: x + jx, y: y + jy)
                guard !avoiding.contains(where: { $0.contains(p) }) else { continue }

                let flora = pool.randomElement(using: &rng) ?? species[0]
                // Rien de solide ne pousse sur une route ni dans une clairière.
                let solid = isOverworldSolid(height: flora.height)
                if solid && isOverworldPassage(p) { continue }
                guard let texH = PixelArtSprites.pixelHeight(of: flora.asset),
                      texH > 0 else { continue }
                // Variation de gabarit ±12 % : aucun arbre n'est le clone du voisin.
                let variance = CGFloat.random(in: 0.88...1.12, using: &rng)
                let scale = flora.height * variance / texH
                guard let node = PixelArtSprites.still(name: flora.asset, scale: scale,
                                                       anchor: CGPoint(x: 0.5, y: 0.0))
                else { continue }
                node.position = p
                node.zPosition = actorLayer(for: p.y) - 0.2
                add(node, to: scene)
                if solid { registerOverworldSolid(node) }
            }
            y += step
        }
    }

    /// `solid` : le décor semé bloque Kael (rochers) — il évite alors aussi
    /// les passages (routes, clairières), cf. `WorldBuilder+OverworldSolids`.
    func scatterOverworld(_ assets: [String], count: Int, in rect: CGRect,
                                  scale: CGFloat, avoiding: [CGRect] = [],
                                  solid: Bool = false, in scene: SKScene) {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<count {
            let name = assets.randomElement(using: &rng) ?? assets[0]
            guard let s = PixelArtSprites.still(name: name, scale: scale,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            // Quelques essais pour tomber hors des zones interdites.
            var p = CGPoint.zero
            var placed = false
            for _ in 0..<6 {
                p = CGPoint(x: .random(in: rect.minX...rect.maxX, using: &rng),
                            y: .random(in: rect.minY...rect.maxY, using: &rng))
                if !avoiding.contains(where: { $0.contains(p) }),
                   !(solid && isOverworldPassage(p)) { placed = true; break }
            }
            guard placed else { continue }
            s.position = p
            s.zPosition = actorLayer(for: p.y) - 0.2
            add(s, to: scene)
            if solid { registerOverworldSolid(s) }
        }
    }

    /// Pose un lieu sur la carte : sprite + panonceau nom, et l'enregistre
    /// comme POI d'entrée (voyage à l'approche + bouton A).
    func addOverworldPlace(_ id: String, asset: String, scale: CGFloat,
                                   at p: CGPoint, title: String, in scene: SKScene) {
        // La clairière de terre sous le lieu est tracée avec les routes
        // (grille autotilée de `buildOverworld`) — rien à poser ici.
        var top = p.y + 26           // repli si le sprite manque
        if let s = PixelArtSprites.still(name: asset, scale: scale,
                                         anchor: CGPoint(x: 0.5, y: 0.0)) {
            s.position = p
            s.zPosition = actorLayer(for: p.y)
            add(s, to: scene)
            top = p.y + s.calculateAccumulatedFrame().height
        }
        // Panneau nom juste au-dessus du sprite (ombre portée dure).
        let labelY = top + 10
        for (dx, dy, c, z) in [(1.5 as CGFloat, -1.5 as CGFloat,
                                SKColor(white: 0, alpha: 0.85), 599 as CGFloat),
                               (0, 0, SKColor.white, 600)] {
            let l = SKLabelNode(fontNamed: PixelUI.uiFont)
            l.text = title; l.fontSize = 13
            l.fontColor = c
            l.horizontalAlignmentMode = .center
            l.verticalAlignmentMode = .center
            l.position = CGPoint(x: p.x + dx, y: labelY + dy)
            l.zPosition = z
            add(l, to: scene)
        }
        overworldPlaces.append((id: id, pos: p, title: title))
    }

    func switchToShrine(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1)
        buildShrine(in: scene)
    }

    func switchToVillage(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        scene.backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = false }
        buildVillage(in: scene)
        villagePlanActive = true
        layout(in: scene.size)
    }

    func switchToRuins(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        // worldHeight est défini par buildRuins (enfilade de salles scrollable).
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.04, green: 0.02, blue: 0.03, alpha: 1)
        buildRuins(in: scene)
    }

    /// Acte III — Le Seuil. Royaume du Vide où Kael franchit la frontière.
    /// Décor 100% assets existants (statues, piliers, escalier, arbres morts).
    func switchToThreshold(in scene: SKScene,
                           echoJoined: Bool = false,
                           spiritsCalmed: Set<String> = [],
                           shadesDefeated: Bool = false,
                           eranMet: Bool = false) {
        clearBackdrop()
        worldNode.position = .zero
        // worldHeight est défini par buildThreshold (couloir vertical scrollable).
        // Eran N'EST PAS dans cette liste : une fois compagnon (eran.isHidden
        // = false via showEranCompanion), une reconstruction du décor ne doit
        // pas le re-masquer — il continue de suivre le trio.
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.08, alpha: 1)
        buildThreshold(in: scene, echoJoined: echoJoined,
                       spiritsCalmed: spiritsCalmed,
                       shadesDefeated: shadesDefeated,
                       eranMet: eranMet)
        if echoJoined { showLyraEcho(in: scene) }
    }

    /// Acte IV — Le Cœur du Vide. Au-delà du Seuil : la source des échos.
    /// Décor 100% assets existants (mêmes règles que le Seuil).
    func switchToVoidHeart(in scene: SKScene,
                           echoJoined: Bool = false,
                           reflectionsFreed: Set<String> = [],
                           devourersDefeated: Bool = false,
                           bossDefeated: Bool = false) {
        clearBackdrop()
        worldNode.position = .zero
        // worldHeight est défini par buildVoidHeart (serpentin scrollable).
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.04, green: 0.01, blue: 0.07, alpha: 1)
        buildVoidHeart(in: scene, reflectionsFreed: reflectionsFreed,
                       devourersDefeated: devourersDefeated,
                       bossDefeated: bossDefeated)
        if echoJoined { showLyraEcho(in: scene) }
    }

    /// L'Écho de Lyra accompagne Kael au Seuil : le node Lyra existant,
    /// teinté cyan spectral et translucide (le follow est réutilisé).
    func showLyraEcho(in scene: SKScene) {
        lyra.isHidden = false
        lyra.position = CGPoint(x: kael.position.x - 44, y: kael.position.y)
        // C'EST le sprite de Lyra — mais spectral : désaturé vers un cyan
        // glacé et plus translucide qu'un vivant. Il « respire » (pulsation
        // d'opacité) pour dire d'un coup d'œil qu'elle est morte.
        lyra.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.50, green: 0.92, blue: 0.98, alpha: 1)
            s.colorBlendFactor = 0.6
        }
        lyra.removeAction(forKey: "echoSpectral")
        if AccessibilitySettings.reduceMotion {
            lyra.alpha = 0.6
        } else {
            lyra.alpha = 0.55
            let breathe = SKAction.sequence([
                .fadeAlpha(to: 0.74, duration: 1.1),
                .fadeAlpha(to: 0.45, duration: 1.1)
            ])
            breathe.timingMode = .easeInEaseOut
            lyra.run(.repeatForever(breathe), withKey: "echoSpectral")
        }
    }
}
