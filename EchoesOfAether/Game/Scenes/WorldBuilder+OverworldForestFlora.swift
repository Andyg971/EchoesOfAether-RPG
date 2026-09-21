import SpriteKit

// Carte du monde — la FORÊT D'ÉBÈNE : des PEUPLEMENTS, pas un papier peint.
//
// Toutes les espèces étaient tirées d'un seul sac pondéré sur tout le
// massif : chaque mètre carré avait la même composition que le voisin,
// donc aucune lecture d'ensemble — du bruit vert d'un bout à l'autre.
// Une vraie forêt pousse par peuplements, et respire par clairières.
@MainActor
extension WorldBuilder {
    func plantOverworldForest(_ geo: OverworldGeometry, in scene: SKScene) {
        let forestC = geo.forestCenter
        let forestRX = geo.forestRX, forestRY = geo.forestRY
        let forestPOIClearing = CGRect(x: geo.forest.x - 56, y: geo.forest.y - 40,
                                       width: 112, height: 80)

        // Les clairières : deux trouées de lumière où rien de haut ne pousse.
        // Ce sont elles qui donnent une échelle au massif — sans respiration,
        // un mur d'arbres n'a ni profondeur ni parcours.
        let glades = [CGRect(x: geo.inForest(-0.30, 0.44).x - 62,
                             y: geo.inForest(-0.30, 0.44).y - 44, width: 124, height: 88),
                      CGRect(x: geo.inForest(0.44, -0.36).x - 54,
                             y: geo.inForest(0.44, -0.36).y - 38, width: 108, height: 76)]
        let noTrees = glades + [forestPOIClearing]

        // Trame de fond : jeunes pousses partout, assez claires pour ne jamais
        // laisser de calvitie entre deux peuplements.
        plantMass([Flora(asset: "ext_tree_3", height: 38, weight: 4),
                   Flora(asset: "tree_medium_1", height: 42, weight: 3),
                   Flora(asset: "tree_medium_2", height: 42, weight: 3),
                   Flora(asset: "tree_medium_3", height: 40, weight: 2)],
                  center: forestC, radiusX: forestRX, radiusY: forestRY,
                  step: 46, coreDensity: 0.44, edgeDensity: 0.14,
                  avoiding: noTrees, in: scene)

        // Futaie de conifères : le grain brun de la Forêt d'Ébène, en trois
        // stations serrées — c'est elle qu'on traverse en venant du village.
        for (fx, fy, r) in [(-0.44, -0.10, 0.42), (0.26, 0.40, 0.38),
                            (0.52, -0.06, 0.30)] {
            plantMass([Flora(asset: "ext_tree_1", height: 60, weight: 5),
                       Flora(asset: "ext_tree_2", height: 58, weight: 5),
                       Flora(asset: "ext_tree_3", height: 40, weight: 2)],
                      center: geo.inForest(fx, fy),
                      radiusX: forestRX * r, radiusY: forestRY * r,
                      step: 32, coreDensity: 0.88, edgeDensity: 0.22,
                      avoiding: noTrees, in: scene)
        }

        // Canopée feuillue : les grands verts, plus hauts, qui ferment le ciel
        // au cœur du massif.
        for (fx, fy, r) in [(-0.02, -0.02, 0.46), (-0.40, 0.34, 0.30),
                            (0.30, -0.42, 0.28)] {
            plantMass([Flora(asset: "me_tree_1", height: 56, weight: 4),
                       Flora(asset: "me_tree_2", height: 56, weight: 4),
                       Flora(asset: "me_tree_3", height: 54, weight: 3),
                       Flora(asset: "me_tree_4", height: 54, weight: 3),
                       Flora(asset: "me_tree_5", height: 68, weight: 3),
                       Flora(asset: "me_tree_6", height: 68, weight: 3),
                       Flora(asset: "tree_big",  height: 46, weight: 2)],
                      center: geo.inForest(fx, fy),
                      radiusX: forestRX * r, radiusY: forestRY * r,
                      step: 34, coreDensity: 0.86, edgeDensity: 0.20,
                      avoiding: noTrees, in: scene)
        }

        // Le bois mort : la signature d'Ébène. Groupé, il raconte une forêt
        // qui meurt par endroits ; éparpillé, ce n'était qu'un arbre sec de
        // plus dans le bruit.
        for (fx, fy, r) in [(0.06, 0.50, 0.24), (-0.56, 0.16, 0.20)] {
            plantMass([Flora(asset: "gy_tree",        height: 60, weight: 4),
                       Flora(asset: "forest_stump_1", height: 18, weight: 3),
                       Flora(asset: "forest_stump_2", height: 18, weight: 3),
                       Flora(asset: "stump_1",        height: 16, weight: 2),
                       Flora(asset: "stump_2",        height: 16, weight: 2),
                       Flora(asset: "ext_cut_wood",   height: 16, weight: 2)],
                      center: geo.inForest(fx, fy),
                      radiusX: forestRX * r, radiusY: forestRY * r,
                      step: 38, coreDensity: 0.64, edgeDensity: 0.14,
                      avoiding: noTrees, in: scene)
        }

        // Sous-bois : champignons et fougères sous la canopée — l'humidité de
        // l'ombre. Ils ont le droit d'entrer dans les clairières, eux.
        plantMass([Flora(asset: "forest_mushroom_1", height: 14, weight: 3),
                   Flora(asset: "forest_mushroom_2", height: 14, weight: 3),
                   Flora(asset: "me_mushrooms_1",    height: 12, weight: 2),
                   Flora(asset: "me_mushrooms_2",    height: 12, weight: 2),
                   Flora(asset: "me_big_sprout_2",   height: 18, weight: 3),
                   Flora(asset: "me_big_sprout_5",   height: 18, weight: 3),
                   Flora(asset: "me_big_sprout_1",   height: 16, weight: 2),
                   Flora(asset: "me_big_sprout_7",   height: 16, weight: 2)],
                  center: forestC, radiusX: forestRX * 0.94, radiusY: forestRY * 0.94,
                  step: 46, coreDensity: 0.46, edgeDensity: 0.14, in: scene)

        // Les clairières fleurissent : c'est là que la lumière passe.
        for glade in glades {
            plantMass([Flora(asset: "me_flower_white",  height: 12, weight: 3),
                       Flora(asset: "me_flower_yellow", height: 12, weight: 3),
                       Flora(asset: "me_flower_blue",   height: 12, weight: 2),
                       Flora(asset: "me_grass_1",       height: 12, weight: 3),
                       Flora(asset: "me_grass_3",       height: 12, weight: 3),
                       Flora(asset: "ext_grass_2",      height: 12, weight: 2)],
                      center: CGPoint(x: glade.midX, y: glade.midY),
                      radiusX: glade.width * 0.46, radiusY: glade.height * 0.46,
                      step: 26, coreDensity: 0.52, edgeDensity: 0.18, in: scene)
        }
    }
}
