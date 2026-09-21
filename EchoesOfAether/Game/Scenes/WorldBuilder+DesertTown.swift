import SpriteKit

// Désert d'Ossara — la cité des caravanes.
@MainActor
extension WorldBuilder {
    func addDesertTown(in scene: SKScene, w: CGFloat, h: CGFloat) {
        // ── L'enceinte : la cité est FERMÉE — courtines d'adobe sur les
        // quatre côtés, porte au sud (l'arrivée) et porte au nord (vers le
        // canyon et l'oasis). Avant, une arche flottait seule dans le sable
        // avec quatre bouts de palissade — ça ne protégeait de rien.
        addDesertRamparts(in: scene, w: w, h: h)

        // ── LA GRAND-RUE, PAVÉE : de la porte sud à la porte nord, élargie en
        // place devant le puits. C'est elle qui fait la CITÉ.
        //
        // Les maisons dessinaient jusqu'ici un croissant lâche autour d'un
        // grand vide de terre craquelée : cinq bâtisses posées sur un arc,
        // aucune rue, aucun alignement, et le joueur traversait un terrain
        // vague meublé. Une ville se lit à ses axes — on pave l'axe, on range
        // les façades dessus, et le vide devient une place.
        let street = 0.50, southY = 0.375, northY = 0.635
        let cell: CGFloat = 96 * WorldBuilder.desertScale
        var paving = VillageTileMap(width: w, height: h, tile: cell)
        paving.stamp(rect: CGRect(x: w * (street - 0.052), y: h * (southY + 0.004),
                                  width: w * 0.104, height: h * (northY - southY - 0.008)))
        // La place : un renflement de la rue, pas une pièce à part.
        paving.stampEllipse(center: CGPoint(x: w * street, y: h * 0.468),
                            radiusX: w * 0.155, radiusY: h * 0.038)
        // Rue transversale, devant la seconde rangée.
        paving.stamp(rect: CGRect(x: w * 0.20, y: h * 0.552,
                                  width: w * 0.60, height: h * 0.018))
        renderTileMap(paving, fullTile: "ds_rock", edgePrefix: nil,
                      in: scene, z: -9.52)

        // ── Les façades, en RANGÉES le long des axes. Toutes tournées au sud
        // (le pack les dessine ainsi) : les rangées se lisent donc depuis la
        // rue qu'elles bordent, et la grande bâtisse ferme la perspective au
        // fond de la grand-rue.
        for (asset, x, y) in [("ds_house_large", 0.50, 0.618),   // fond de rue
                              // Rangée du fond, de part et d'autre.
                              ("ds_house_sand", 0.265, 0.590),
                              ("ds_house_red",  0.375, 0.590),
                              ("ds_house_red",  0.625, 0.590),
                              ("ds_house_sand", 0.735, 0.590),
                              // Rangée de la rue transversale.
                              ("ds_house_red",  0.185, 0.505),
                              ("ds_house_sand", 0.305, 0.505),
                              ("ds_house_sand", 0.695, 0.505),
                              ("ds_house_red",  0.815, 0.505)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── Le caravansérail, à l'ouest de la place : c'est là qu'on dételle
        // en arrivant par la porte sud. Tentes serrées, enclos, bêtes.
        for (asset, x, y) in [("ds_tent_canvas", 0.235, 0.432),
                              ("ds_tent_round", 0.155, 0.408),
                              ("ds_tent_small", 0.305, 0.412)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }
        addDesertProp("ds_fence", in: scene, at: CGPoint(x: w * 0.185, y: h * 0.452))
        addDesertProp("ds_fence", in: scene, at: CGPoint(x: w * 0.245, y: h * 0.452))
        addDesertProp("ds_camel_1", in: scene, at: CGPoint(x: w * 0.215, y: h * 0.462))
        addDesertProp("ds_camel_2", in: scene, at: CGPoint(x: w * 0.285, y: h * 0.455),
                      flipped: true)

        // ── Le souk, à l'est de la place : l'étal, les tapis, les sacs.
        for (asset, x, y) in [("ds_tent_big", 0.755, 0.428),
                              ("ds_tent_small", 0.845, 0.412),
                              ("ds_carpet_rolls", 0.665, 0.440),
                              ("ds_sacks", 0.700, 0.425),
                              ("ds_rug", 0.630, 0.428),
                              ("ds_scroll", 0.598, 0.443)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── La place : puits au centre, étal et feu de part et d'autre.
        addDesertProp("ds_market", in: scene, at: CGPoint(x: w * 0.395, y: h * 0.470))
        addDesertProp("ds_well", in: scene, at: DesertPOI.town.scaled(w: w, h: h))
        addDesertProp("ds_campfire", in: scene, at: CGPoint(x: w * 0.605, y: h * 0.472))

        // ── Palmiers intra-muros : la cité vit sur sa nappe d'eau. Alignés
        // aux angles des blocs, comme des arbres de rue.
        for (x, y) in [(0.125, 0.500), (0.875, 0.500),
                       (0.125, 0.585), (0.875, 0.585)] {
            addDesertProp("ds_palm_tall1", in: scene, at: CGPoint(x: w * x, y: h * y))
        }
        addDesertProp("ds_palm_small", in: scene, at: CGPoint(x: w * 0.435, y: h * 0.612))
        addDesertProp("ds_palm_small", in: scene, at: CGPoint(x: w * 0.565, y: h * 0.612))

        // ── Le petit bazar du quotidien : jarres aux portes, échelle contre
        // un mur, verdure au pied des façades. Ce qui fait qu'on y habite.
        for (asset, x, y) in [("ds_pot", 0.335, 0.578), ("ds_pot2", 0.665, 0.578),
                              ("ds_pot", 0.345, 0.494), ("ds_pot2", 0.655, 0.494),
                              ("ds_ladder", 0.225, 0.578),
                              ("ds_cactus_barrel2", 0.865, 0.545),
                              ("ds_grass_dry", 0.155, 0.545),
                              ("ds_grass_dry", 0.845, 0.545),
                              ("ds_oasis_flower", 0.415, 0.578),
                              ("ds_oasis_flower", 0.585, 0.578),
                              ("ds_flowers", 0.455, 0.500),
                              ("ds_agave", 0.545, 0.500),
                              ("ds_skull_cow2", 0.355, 0.408)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── Les habitants : trois silhouettes terrées derrière les remparts.
        // Ils ne vagabondent pas comme au village — on ne flâne pas quand
        // des goules rôdent aux portes. Le dialogue est dans
        // `GameManager.tryDesertInteraction`, aux mêmes repères.
        addDesertVillager("npc_villager", in: scene,
                          at: DesertPOI.npcCaravanier.scaled(w: w, h: h))
        addDesertVillager("npc_extra", in: scene,
                          at: DesertPOI.npcMerchant.scaled(w: w, h: h))
        addDesertVillager("npc_child", in: scene,
                          at: DesertPOI.npcChild.scaled(w: w, h: h))
    }

}
