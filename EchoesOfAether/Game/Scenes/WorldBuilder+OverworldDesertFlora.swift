import SpriteKit

// Carte du monde — DÉSERT D'OSSARA : la flore, en BOSQUETS.
//
// Le relief (croûte, dunes, gravier) est posé en tuiles par
// `addOverworldDesertStrata`. Ne restent ici que de vrais objets : ni
// `ds_cracked*` ni `ds_dune*`, qui sont des tuiles de sol de 96×96 — semées
// en sprites, elles parsemaient le sable de carrés de terre craquelée aux
// bords nets.
//
// Un désert ne sème pas sa flore uniformément : le vide domine, et la
// vie se groupe là où il reste de l'eau. D'où une trame de fond très
// clairsemée, puis des BOSQUETS denses posés à la main.
@MainActor
extension WorldBuilder {
    func plantOverworldDesert(_ geo: OverworldGeometry, in scene: SKScene) {
        let desert = geo.desertRect
        let desertRX = desert.width * 0.60, desertRY = desert.height * 0.66
        let desertPOIClearing = CGRect(x: geo.desert.x - 56, y: geo.desert.y - 40,
                                       width: 112, height: 80)

        // Trame de fond : le désert nu. Cailloux, broussailles mortes,
        // touffes sèches — assez pour que le sol vive, jamais assez pour
        // remplir. C'est l'immensité vide qui FAIT le désert.
        plantMass([Flora(asset: "ds_bush_dead",   height: 18, weight: 4),
                   Flora(asset: "ds_bush_dead2",  height: 18, weight: 3),
                   Flora(asset: "ds_bush_dead3",  height: 16, weight: 3),
                   Flora(asset: "ds_grass_dry",   height: 14, weight: 4),
                   Flora(asset: "rock_1",         height: 12, weight: 3),
                   Flora(asset: "rock_3",         height: 12, weight: 3),
                   Flora(asset: "ds_rock_pile",   height: 18, weight: 2),
                   Flora(asset: "ds_tumbleweed",  height: 16, weight: 2),
                   Flora(asset: "ds_tumbleweed2", height: 16, weight: 1)],
                  center: geo.desertCenter, radiusX: desertRX, radiusY: desertRY,
                  step: 62, coreDensity: 0.30, edgeDensity: 0.16,
                  avoiding: [desertPOIClearing], in: scene)

        // Bosquets de cactus : les saguaros poussent en peuplements, jamais
        // isolés. Quatre stations, chacune serrée sur son point d'eau.
        for (fx, fy, r) in [(0.30, 0.66, 0.16), (0.58, 0.30, 0.14),
                            (0.80, 0.56, 0.12), (0.16, 0.34, 0.11)] {
            plantMass([Flora(asset: "ds_cactus_tall",    height: 48, weight: 3),
                       Flora(asset: "ds_cactus_tall2",   height: 46, weight: 2),
                       Flora(asset: "ds_cactus_tall3",   height: 44, weight: 2),
                       Flora(asset: "ds_cactus_med",     height: 32, weight: 3),
                       Flora(asset: "ds_cactus_med2",    height: 30, weight: 3),
                       Flora(asset: "ds_cactus_barrel",  height: 22, weight: 3),
                       Flora(asset: "ds_cactus_barrel2", height: 20, weight: 2),
                       Flora(asset: "ds_cactus_small",   height: 16, weight: 3),
                       Flora(asset: "ds_cactus_flower",  height: 24, weight: 2),
                       Flora(asset: "ds_agave",          height: 22, weight: 3)],
                      center: geo.inDesert(fx, fy),
                      radiusX: desert.width * r, radiusY: desert.height * r * 1.1,
                      step: 34, coreDensity: 0.62, edgeDensity: 0.10,
                      avoiding: [desertPOIClearing], in: scene)
        }

        // Chaos rocheux : les deux reg de gravier portent leurs blocs, avec
        // une aiguille qui casse la ligne d'horizon.
        for (fx, fy, r) in [(0.14, 0.72, 0.15), (0.72, 0.14, 0.13)] {
            plantMass([Flora(asset: "ds_boulder",    height: 30, weight: 3),
                       Flora(asset: "ds_boulder2",   height: 26, weight: 3),
                       Flora(asset: "ds_rock_big",   height: 34, weight: 2),
                       Flora(asset: "ds_rock_pile",  height: 20, weight: 3),
                       Flora(asset: "ds_rock_spire", height: 52, weight: 1)],
                      center: geo.inDesert(fx, fy),
                      radiusX: desert.width * r, radiusY: desert.height * r * 0.9,
                      step: 40, coreDensity: 0.56, edgeDensity: 0.12,
                      avoiding: [desertPOIClearing], in: scene)
        }

        // Charnier de caravane : les ossements se groupent là où la soif a
        // eu raison d'un convoi. Éparpillés partout, ils perdaient tout sens.
        plantMass([Flora(asset: "ds_skull_cow",  height: 18, weight: 3),
                   Flora(asset: "ds_skull_cow2", height: 18, weight: 2),
                   Flora(asset: "ds_skull",      height: 14, weight: 2),
                   Flora(asset: "ds_bones",      height: 14, weight: 3),
                   Flora(asset: "ds_bone",       height: 10, weight: 3)],
                  center: geo.inDesert(0.46, 0.16),
                  radiusX: desert.width * 0.10, radiusY: desert.height * 0.10,
                  step: 34, coreDensity: 0.44, edgeDensity: 0.08,
                  avoiding: [desertPOIClearing], in: scene)

        // Palmeraie du campement : le POI est une tente de caravane, elle
        // s'installe à l'ombre. C'est aussi le repère visuel qui dit « on
        // entre ici » avant même de lire le panneau.
        plantMass([Flora(asset: "ds_palm_tall1", height: 58, weight: 3),
                   Flora(asset: "ds_palm_tall2", height: 54, weight: 3),
                   Flora(asset: "ds_palm_small", height: 32, weight: 2),
                   Flora(asset: "ds_oasis_flower", height: 14, weight: 2),
                   Flora(asset: "ds_flower_orange", height: 12, weight: 1)],
                  center: geo.desert,
                  radiusX: 132, radiusY: 96,
                  step: 40, coreDensity: 0.34, edgeDensity: 0.42,
                  avoiding: [desertPOIClearing], in: scene)
    }
}
