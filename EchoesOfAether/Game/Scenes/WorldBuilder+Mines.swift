import SpriteKit

// Mines de Cendreval (excursion optionnelle).
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Mines de Cendreval (excursion optionnelle, forêt)

    func switchToMines(in scene: SKScene, progress: Int = 0, goldTaken: Bool = false) {
        clearBackdrop()
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        buildMines(in: scene, progress: progress, goldTaken: goldTaken)
        // worldHeight est défini par buildMines (descente scrollable).
    }

    /// Galeries mortes de Cendreval : le patron des treks (scroll +
    /// autotiler + props à l'échelle + collisions), appliqué sous terre.
    ///
    /// Les mines tenaient sur un écran — le seul intérieur du jeu sans
    /// profondeur, pour un lieu qui ne parle que de ça. Deux écrans et
    /// demi de descente : l'entrée éclairée par le jour, le corridor aux
    /// rails, la salle effondrée (plaque des mineurs), et la galerie
    /// est qui remonte vers la veine d'or. Le fond, au nord, appartient
    /// aux morts.
    func buildMines(in scene: SKScene, progress: Int, goldTaken: Bool) {
        let w = scene.size.width
        let h = scene.size.height * 2.5
        worldHeight = h

        // Sol : pierre gris cendre, sur toute la descente
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // ── Galeries creusées : terre d'excavation par l'autotiler ──
        //
        // Même outil que les chemins du village : les zones travaillées
        // par les mineurs se lisent au sol, et le joueur suit la terre
        // remuée comme un fil d'Ariane — corridor central, salle
        // effondrée à l'ouest, branche est vers la veine, fond au nord.
        // Tuiles me_* : 48 px source → 24 pt affichés (0,5 pt/pixel).
        var dug = VillageTileMap(width: w, height: h, tile: 24)
        dug.stamp(rect: CGRect(x: w * 0.42, y: 0, width: w * 0.16, height: h * 0.62))
        dug.stampEllipse(center: CGPoint(x: w * 0.33, y: h * 0.55),
                         radiusX: w * 0.26, radiusY: h * 0.065)
        dug.stamp(rect: CGRect(x: w * 0.42, y: h * 0.575, width: w * 0.48, height: h * 0.05))
        dug.stamp(rect: CGRect(x: w * 0.78, y: h * 0.575, width: w * 0.16, height: h * 0.22))
        dug.stampEllipse(center: CGPoint(x: w * 0.50, y: h * 0.90),
                         radiusX: w * 0.30, radiusY: h * 0.058)
        dug.stamp(rect: CGRect(x: w * 0.42, y: h * 0.60, width: w * 0.16, height: h * 0.28))
        renderTileMap(dug, fullTile: "me_dirt_full", edgePrefix: nil,
                      in: scene, z: -9.6,
                      tint: SKColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1))

        // ── Voûte au fond (nord) : pierre taillée + obstacle plein ──
        // Elle fermait le haut de l'écran unique ; elle ferme maintenant
        // le fond du monde, et Kael ne peut plus marcher dedans.
        let wallTile: CGFloat = 24
        let wallCols = Int(ceil(w / wallTile)) + 1
        for c in 0..<wallCols {
            for r in 0..<2 {
                guard let t = PixelArtSprites.still(
                    name: ["me_wall_1", "me_wall_2", "me_wall_3", "me_wall_5"][(c + r) % 4],
                    scale: 0.5, anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: CGFloat(c) * wallTile + wallTile / 2,
                                     y: h - CGFloat(r) * wallTile - wallTile / 2)
                t.zPosition = -6
                t.forEachDescendantSprite { s in
                    s.color = SKColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1)
                    s.colorBlendFactor = 0.55
                }
                add(t, to: scene)
            }
        }
        registerObstacle(CGRect(x: 0, y: h - 2 * wallTile - 8, width: w,
                                height: 2 * wallTile + 8))

        // Titre de zone, à l'entrée (là où le joueur le lit)
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.mines.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.60, green: 0.58, blue: 0.52, alpha: 0.7)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.045)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // ── Rails : le fil de la descente ──
        // Sud → salle, puis la branche est, puis la remontée vers la veine.
        addMineRails(in: scene, from: CGPoint(x: w * 0.50, y: h * 0.06),
                     to: CGPoint(x: w * 0.50, y: h * 0.60))
        addMineRails(in: scene, from: CGPoint(x: w * 0.50, y: h * 0.60),
                     to: CGPoint(x: w * 0.86, y: h * 0.60), horizontal: true)
        addMineRails(in: scene, from: CGPoint(x: w * 0.86, y: h * 0.60),
                     to: CGPoint(x: w * 0.86, y: h * 0.76))

        // Chariots abandonnés sur les rails
        addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.28), scale: 0.55)
        addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.68, y: h * 0.585), scale: 0.55)
        addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.86, y: h * 0.70), scale: 0.55)

        // ── Piliers et colonnes : la voûte fatiguée, sur toute la descente ──
        addPixelProp("pillar_grey_1", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.34), scale: 1.8)
        addPixelProp("pillar_grey_2", in: scene, at: CGPoint(x: w * 0.90, y: h * 0.42), scale: 1.8)
        addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.26, y: h * 0.64), scale: 2.0)
        addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.70, y: h * 0.66), scale: 1.8)
        addPixelProp("pillar_grey_1", in: scene, at: CGPoint(x: w * 0.22, y: h * 0.86), scale: 1.8)
        addPixelProp("pillar_grey_2", in: scene, at: CGPoint(x: w * 0.78, y: h * 0.88), scale: 1.8)

        // Étais de bois : ils encadrent le corridor aux rails, comme une
        // vraie galerie boisée (plus les coins perdus de l'écran unique).
        for y in [0.16, 0.30, 0.44] {
            addMineStrut(in: scene, at: CGPoint(x: w * 0.38, y: h * CGFloat(y)))
            addMineStrut(in: scene, at: CGPoint(x: w * 0.62, y: h * CGFloat(y)))
        }
        addMineStrut(in: scene, at: CGPoint(x: w * 0.10, y: h * 0.55))
        addMineStrut(in: scene, at: CGPoint(x: w * 0.90, y: h * 0.80))

        // Éboulis et rochers, répartis sur les trois tronçons
        let rocks: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("rock_5", 0.14, 0.12, 0.50), ("rock_3", 0.72, 0.18, 0.55),
            ("rock_7", 0.20, 0.26, 0.60), ("ext_pebbles", 0.66, 0.32, 0.8),
            ("gy_stone_3", 0.82, 0.38, 0.50), ("rock_9", 0.30, 0.44, 0.60),
            ("ext_pebbles", 0.46, 0.50, 0.8), ("gy_stone_1", 0.54, 0.63, 0.50),
            ("rock_1", 0.14, 0.70, 0.50), ("rock_7", 0.90, 0.64, 0.55),
            ("rock_3", 0.34, 0.78, 0.55), ("ext_pebbles", 0.62, 0.82, 0.8),
            ("rock_9", 0.42, 0.92, 0.60), ("gy_stone_3", 0.66, 0.94, 0.50)
        ]
        for (asset, x, y, s) in rocks {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // ── PAROIS ROCHEUSES : ce qui fait lire une GROTTE, pas un couloir ──
        // La galerie n'avait que des cailloux au sol : aucun relief, aucune
        // masse. Une frange de blocs et d'aiguilles borde maintenant les deux
        // flancs sur toute la descente, et se resserre vers le fond où la
        // roche n'a jamais été taillée. Hauteurs NORMALISÉES (cf. scaleFor) :
        // les planches vont de 64 à 192 px, elles étaient posées à la même
        // échelle et se retrouvaient hors gabarit les unes à côté des autres.
        let caveWalls: [(String, CGFloat, CGFloat, CGFloat)] = [
            // Flanc ouest, du haut vers le fond
            ("ds_boulder",    0.045, 0.10, 40), ("ds_rock_spire", 0.035, 0.21, 62),
            ("ds_rock_big",   0.055, 0.33, 46), ("ds_boulder2",   0.030, 0.45, 38),
            ("ds_rock_spire", 0.050, 0.57, 66), ("ds_rock_big",   0.035, 0.69, 48),
            ("ds_boulder",    0.060, 0.81, 42), ("ds_rock_spire", 0.040, 0.93, 70),
            // Flanc est
            ("ds_rock_spire", 0.960, 0.13, 64), ("ds_boulder2",   0.945, 0.25, 38),
            ("ds_rock_big",   0.968, 0.37, 46), ("ds_rock_spire", 0.950, 0.49, 60),
            ("ds_boulder",    0.972, 0.61, 42), ("ds_rock_big",   0.940, 0.73, 50),
            ("ds_rock_spire", 0.965, 0.85, 68), ("ds_boulder2",   0.945, 0.96, 40),
            // Le fond : la roche brute se referme sur la galerie
            ("ds_rock_spire", 0.20, 0.965, 58), ("ds_rock_big",   0.80, 0.955, 52),
            ("ds_boulder",    0.32, 0.985, 44), ("ds_boulder2",   0.68, 0.985, 40)
        ]
        for (asset, x, y, targetH) in caveWalls {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y),
                         scale: scaleFor(asset, height: targetH))
        }

        // Ossements des équipes disparues — de plus en plus denses au fond
        for p in [(0.38, 0.22), (0.62, 0.35), (0.26, 0.52), (0.82, 0.66),
                  (0.44, 0.84), (0.58, 0.92)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.85
            add(bones, to: scene)
        }

        // Lanternes des mineurs : le chemin de lumière de la descente
        for (x, y) in [(0.44, 0.075), (0.56, 0.075), (0.42, 0.24),
                       (0.58, 0.38), (0.14, 0.58), (0.70, 0.615),
                       (0.86, 0.73), (0.48, 0.87)] {
            addMineLantern(in: scene, at: CGPoint(x: w * CGFloat(x), y: h * CGFloat(y)))
        }
        // Bougies fondues près de la plaque
        addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.13, y: h * 0.525), scale: 0.5)
        addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.20, y: h * 0.535), scale: 0.45)

        // Champignons luisants : la seule vie qui reste ici
        for (x, y, s) in [(0.34, 0.14, 0.9), (0.66, 0.26, 0.8), (0.18, 0.40, 0.85),
                          (0.50, 0.55, 0.75), (0.78, 0.70, 0.9), (0.30, 0.72, 0.8),
                          (0.62, 0.88, 0.85), (0.36, 0.95, 0.75)] {
            guard let shroom = PixelArtSprites.still(
                name: Bool.random() ? "mushroom_1" : "mushroom_3",
                scale: CGFloat(s), anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            shroom.position = CGPoint(x: w * CGFloat(x), y: h * CGFloat(y))
            shroom.zPosition = -3
            shroom.forEachDescendantSprite { sp in
                sp.color = SKColor(red: 0.35, green: 0.85, blue: 0.75, alpha: 1)
                sp.colorBlendFactor = 0.35
            }
            add(shroom, to: scene)
            JuiceEngine.pulse(shroom, scale: 1.05)
        }

        // Les monstres ne sont plus des props statiques : le GameManager
        // fait patrouiller des RoamingMonster (spawnMineRoamers) qui chargent
        // Kael. Fini les halos de danger + crânes + bouton « A · Combattre ».

        // Plaque des mineurs, dans la salle effondrée : le lore de Cendreval
        let plaque = makeMinersPlaque(at: MinesPOI.plaque.scaled(w: w, h: h))
        add(plaque, to: scene)

        // Veine d'or : au fond de la galerie est (déjà ramassée = absente)
        if !goldTaken {
            let vein = makeGoldVein(at: MinesPOI.goldVein.scaled(w: w, h: h))
            vein.name = "minesGoldVein"
            add(vein, to: scene)
        }

        // Sortie au sud : halo de lumière du jour
        let exitGlow = SKShapeNode(circleOfRadius: 34)
        exitGlow.fillColor = SKColor(red: 0.55, green: 0.65, blue: 0.75, alpha: 0.10)
        exitGlow.strokeColor = SKColor(red: 0.70, green: 0.80, blue: 0.90, alpha: 0.25)
        exitGlow.lineWidth = 1.5
        exitGlow.position = CGPoint(x: w * 0.50, y: h * MinesPOI.exitY)
        add(exitGlow, to: scene)
        JuiceEngine.pulse(exitGlow, scale: 1.15)
        let exitLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        exitLabel.text = String(localized: "world.mines.exit")
        exitLabel.fontSize = 12
        exitLabel.fontColor = SKColor(white: 0.70, alpha: 0.7)
        exitLabel.position = CGPoint(x: w * 0.50, y: h * MinesPOI.exitY + 42)
        add(exitLabel, to: scene)

        // Cristal de sauvegarde près de la sortie : les mines sont mortelles,
        // on doit pouvoir souffler avant de replonger.
        addSaveCrystal(at: CGPoint(x: w * 0.68, y: h * 0.06), in: scene)

        // Cendre en suspension : même atmosphère que les ruines
        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.68)   // mines : galeries noires
        LightingEngine.applyGrade(.mines, in: scene)
        LightingEngine.attachHeroLight(to: kael)  // seul point chaud mobile
        AudioEngine.shared.setAmbience(.mines)
        debugDrawObstacles(in: scene)   // --show-obstacles : audit (mines)
    }
}
