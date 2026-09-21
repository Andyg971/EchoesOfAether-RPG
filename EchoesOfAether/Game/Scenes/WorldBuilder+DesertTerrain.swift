import SpriteKit

// Désert d'Ossara — les SOLS : terre craquelée, parois du canyon, arènes de combat.
@MainActor
extension WorldBuilder {
    /// Terrains : terre craquelée au sud, roche vers le canyon nord.
    ///
    /// Par l'autotiler, comme les chemins du village et de la forêt. Ils
    /// étaient posés en plaques rectangulaires de tuiles pleines : sans
    /// transition, la terre craquelée s'arrêtait net sur le sable et se
    /// lisait comme un bloc en escalier. Les tuiles `ds_edge_*` sont
    /// générées (sable + bordure dentelée) faute d'en trouver dans le pack.
    func addDesertTerrain(in scene: SKScene, w: CGFloat, h: CGFloat, cell: CGFloat) {
        var cracked = VillageTileMap(width: w, height: h, tile: cell)
        cracked.stampEllipse(center: CGPoint(x: w * 0.22, y: h * 0.30),
                             radiusX: w * 0.26, radiusY: h * 0.075)
        cracked.stampEllipse(center: CGPoint(x: w * 0.74, y: h * 0.33),
                             radiusX: w * 0.22, radiusY: h * 0.065)
        cracked.stampEllipse(center: CGPoint(x: w * 0.14, y: h * 0.88),
                             radiusX: w * 0.20, radiusY: h * 0.06)
        // La place de la cité : de la terre battue sous le souk et le puits.
        // Trois ellipses qui se chevauchent, pas un rectangle mou — le sol
        // suit la vie (camp à l'ouest, place au centre, cour des maisons).
        cracked.stampEllipse(center: CGPoint(x: w * 0.35, y: h * 0.455),
                             radiusX: w * 0.20, radiusY: h * 0.042)
        cracked.stampEllipse(center: CGPoint(x: w * 0.55, y: h * 0.485),
                             radiusX: w * 0.24, radiusY: h * 0.048)
        cracked.stampEllipse(center: CGPoint(x: w * 0.68, y: h * 0.545),
                             radiusX: w * 0.16, radiusY: h * 0.038)
        // L'allée : de la porte sud à la porte nord, à travers la place.
        cracked.stamp(rect: CGRect(x: w * 0.46, y: h * 0.372, width: w * 0.08,
                                   height: h * 0.265))
        renderTileMap(cracked, fullTile: "ds_cracked", edgePrefix: "ds_edge_",
                      in: scene, z: -9.6)

        var rock = VillageTileMap(width: w, height: h, tile: cell)
        // Îlots, pas une dalle : les deux plaques du canyon couvraient un
        // demi-écran chacune — en masse, la tuile rocheuse se lit comme un
        // mur. Réduites pour laisser le sable respirer entre les affleure-
        // ments.
        rock.stampEllipse(center: CGPoint(x: w * 0.78, y: h * 0.73),
                          radiusX: w * 0.14, radiusY: h * 0.050)
        rock.stampEllipse(center: CGPoint(x: w * 0.26, y: h * 0.70),
                          radiusX: w * 0.12, radiusY: h * 0.042)
        // Parois du canyon : des BANDES de plateau continues sur les deux
        // flancs, le fond et les épaules de l'entrée — pas des mesas
        // flottantes posées sur le sable (Andy : « la roche, tu l'as mal
        // faite »). Le bord déchiré vient de l'autotiler ; des bosses
        // seedées le font onduler vers l'intérieur.
        var rockSeed: UInt64 = 0x0C11_FF5E
        func rockNext() -> CGFloat {
            rockSeed = rockSeed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(rockSeed >> 40) / CGFloat(1 << 24)
        }
        rock.stamp(rect: CGRect(x: 0, y: 0, width: w * 0.062, height: h))
        rock.stamp(rect: CGRect(x: w * 0.938, y: 0, width: w * 0.062, height: h))
        rock.stamp(rect: CGRect(x: 0, y: h * 0.955, width: w, height: h * 0.045))
        rock.stamp(rect: CGRect(x: 0, y: 0, width: w * 0.32, height: h * 0.014))
        rock.stamp(rect: CGRect(x: w * 0.68, y: 0, width: w * 0.32, height: h * 0.014))
        for _ in 0..<8 {
            rock.stampEllipse(center: CGPoint(x: w * 0.062, y: h * (0.06 + rockNext() * 0.85)),
                              radiusX: w * (0.018 + rockNext() * 0.030),
                              radiusY: h * (0.015 + rockNext() * 0.028))
            rock.stampEllipse(center: CGPoint(x: w * 0.938, y: h * (0.06 + rockNext() * 0.85)),
                              radiusX: w * (0.018 + rockNext() * 0.030),
                              radiusY: h * (0.015 + rockNext() * 0.028))
        }
        for _ in 0..<4 {
            rock.stampEllipse(center: CGPoint(x: w * (0.10 + rockNext() * 0.80), y: h * 0.955),
                              radiusX: w * (0.03 + rockNext() * 0.04),
                              radiusY: h * (0.012 + rockNext() * 0.016))
        }
        // Dessus de paroi : la terre craquelée SOMBRE du pack (celle des
        // murs du canyon dans la carte de référence), pas le gravier
        // ds_rock — en nappe, il se lisait comme une moquette grise.
        renderTileMap(rock, fullTile: "ds_cracked_dark", edgePrefix: "ds_rockedge_",
                      in: scene, z: -9.5)
        // La HAUTEUR : chaque bord sud de paroi reçoit sa face de pierres
        // empilées — c'est elle qui fait lire la roche comme un relief.
        addCliffFaces(for: rock, cell: cell, in: scene)
    }

    /// LES TROIS TERRAINS DE COMBAT.
    /// Ils sont calés sur les points d'apparition des rôdeurs
    /// (`GameManager.spawnDesertRoamers`) : dunes du sud, gorge du canyon,
    /// et l'arène du boss tout au nord. Les monstres surgissaient jusqu'ici
    /// sur du sable nu, indiscernable du reste de la traversée.
    func addDesertBattlegrounds(in scene: SKScene, w: CGFloat, h: CGFloat, cell: CGFloat) {
        addDesertBattleground(in: scene, at: CGPoint(x: w * 0.62, y: h * 0.25),
                              radiusX: w * 0.15, radiusY: h * 0.048,
                              ring: ["ds_rock_pile", "ds_boulder2", "ds_bush_dead",
                                     "ds_boulder", "ds_cactus_barrel"],
                              litter: ["ds_skull_cow", "ds_bones", "ds_bone",
                                       "ds_tumbleweed"],
                              cell: cell)
        addDesertBattleground(in: scene, at: CGPoint(x: w * 0.60, y: h * 0.66),
                              radiusX: w * 0.16, radiusY: h * 0.050,
                              ring: ["ds_boulder", "ds_rock_big", "ds_boulder2",
                                     "ds_rock_spire", "ds_rock_pile"],
                              litter: ["ds_bones", "ds_skull", "ds_bone",
                                       "ds_skull_cow2", "ds_carpet_rolls"],
                              cell: cell)
        // L'arène du boss : la plus large, cerclée de colonnes en ruine — un
        // ancien caravansérail dont il ne reste que le cercle.
        addDesertBattleground(in: scene, at: CGPoint(x: w * 0.40, y: h * 0.86),
                              radiusX: w * 0.20, radiusY: h * 0.058,
                              ring: ["ds_ruin_column", "ds_rock_spire",
                                     "ds_ruin_stone", "ds_boulder", "ds_ruin_column"],
                              litter: ["ds_skull_cow", "ds_bones", "ds_campfire",
                                       "ds_bone", "ds_skull", "ds_sacks"],
                              cell: cell)
    }
}
