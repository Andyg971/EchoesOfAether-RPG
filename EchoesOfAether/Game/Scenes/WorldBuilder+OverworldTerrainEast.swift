import SpriteKit

// Carte du monde — les SOLS de l'est (Cendreval, Ruines, Seuil, Cœur du
// Vide) et le réseau de ROUTES qui relie tous les lieux.
@MainActor
extension WorldBuilder {
    /// Les tabliers de terre de l'est : ce sont eux que les routes ne doivent
    /// pas border d'herbe (cf. `addOverworldRoads`).
    struct OverworldEastAprons {
        let mountApron: VillageTileMap
        let ruinsApron: VillageTileMap
        let blight: VillageTileMap
    }

    // MARK: - L'est du continent

    /// L'EST DU CONTINENT : trois sols, trois natures.
    ///
    /// Cendreval, les Ruines et le Seuil étaient posés À MÊME LA PRAIRIE :
    /// des blocs orange sur une pelouse, une statue sur du gazon, un portail
    /// du Vide sur de l'herbe vive. Chacun reçoit ses strates, même recette
    /// que le désert — un tablier de terre qui raccorde au vert, puis la
    /// matière propre au lieu.
    func addOverworldEastTerrain(_ geo: OverworldGeometry,
                                 in scene: SKScene) -> OverworldEastAprons {
        let tile = geo.tile

        // MASSIF DE CENDREVAL : dalle rocheuse sous les blocs.
        let mountC = geo.mountCenter
        let mountRX = geo.mountRX, mountRY = geo.mountRY
        var mountApron = geo.emptyMap()
        OverworldGeometry.stampBlob(&mountApron, at: mountC, rx: mountRX, ry: mountRY, grow: 1.08)
        renderTileMap(mountApron, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.78)
        // Éboulis de gravier, PAS de dalle grise : `a2_stone` est une pierre de
        // carrière bleu-gris, et en nappe sur un massif elle donnait une plaque
        // de bitume au milieu des prairies — les blocs orange posés dessus
        // n'avaient plus rien à voir avec leur propre sol. `ds_gravel` sort du
        // MÊME pack que ces blocs : la montagne et ses éboulis redeviennent la
        // même roche.
        var mountRock = geo.emptyMap()
        OverworldGeometry.stampBlob(&mountRock, at: mountC, rx: mountRX, ry: mountRY, grow: 0.86,
                                    feather: tile * 2 / mountRX)
        renderTileMap(mountRock, fullTile: "ds_gravel", edgePrefix: nil,
                      in: scene, z: -29.76)

        // RUINES DE LA SOURCE : un parvis effondré, pas une statue sur l'herbe.
        let pRuins = geo.ruins
        let ruinsRX = geo.ruinsRX, ruinsRY = geo.ruinsRY
        var ruinsApron = geo.emptyMap()
        OverworldGeometry.stampBlob(&ruinsApron, at: pRuins, rx: ruinsRX, ry: ruinsRY, grow: 1.0)
        renderTileMap(ruinsApron, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.74)
        var ruinsFloor = geo.emptyMap()
        OverworldGeometry.stampBlob(&ruinsFloor, at: pRuins, rx: ruinsRX, ry: ruinsRY, grow: 0.74,
                                    feather: tile * 2 / ruinsRX)
        renderTileMap(ruinsFloor, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -29.72,
                      tint: SKColor(red: 0.78, green: 0.76, blue: 0.74, alpha: 1),
                      tintBlend: 0.40)

        // LE SEUIL : la corruption ronge le sol avant le portail. Le violet du
        // Vide n'attend pas qu'on franchisse la porte — c'est ce qui manquait
        // le plus, l'approche disait « prairie » jusqu'au dernier pas.
        let voidShade = geo.voidShade
        let pThreshold = geo.threshold
        let thrRX = geo.thresholdRX, thrRY = geo.thresholdRY
        var blight = geo.emptyMap()
        OverworldGeometry.stampBlob(&blight, at: pThreshold, rx: thrRX, ry: thrRY, grow: 1.06)
        renderTileMap(blight, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.70, tint: voidShade, tintBlend: 0.52)
        var voidFloor = geo.emptyMap()
        OverworldGeometry.stampBlob(&voidFloor, at: pThreshold, rx: thrRX, ry: thrRY, grow: 0.72,
                                    feather: tile * 2 / thrRX)
        renderTileMap(voidFloor, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -29.68, tint: voidShade, tintBlend: 0.70)

        // LE CŒUR DU VIDE : au-delà du Seuil, hors d'atteinte. Il n'a pas de
        // lieu marchable — mais la faille se VOIT depuis le portail, et c'est
        // ce qui donne au Seuil quelque chose à garder.
        let pVoid = geo.voidheart
        var rift = geo.emptyMap()
        OverworldGeometry.stampBlob(&rift, at: pVoid, rx: 168, ry: 118, grow: 1.0)
        renderTileMap(rift, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.66, tint: voidShade, tintBlend: 0.62)
        var riftCore = geo.emptyMap()
        OverworldGeometry.stampBlob(&riftCore, at: pVoid, rx: 168, ry: 118, grow: 0.60,
                                    feather: tile * 2 / 168)
        renderTileMap(riftCore, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -29.64,
                      tint: SKColor(red: 0.36, green: 0.16, blue: 0.50, alpha: 1),
                      tintBlend: 0.82)

        return OverworldEastAprons(mountApron: mountApron, ruinsApron: ruinsApron,
                                   blight: blight)
    }

    // MARK: - Routes

    /// ROUTES : un seul réseau de terre battue AUTOTILÉ (transitions
    /// me_edge_* sur l'herbe) — la lecture « vraie carte du monde ».
    ///
    /// La route CHANGE DE MATIÈRE selon la zone qu'elle traverse. Ses bords
    /// `me_edge_*` portent de l'HERBE : la piste d'Ossara traversait le
    /// sable bordée de vert vif, la tente était cernée de gazon en plein
    /// désert, et sous les arbres le même liseré vif annulait l'ombre du
    /// couvert. Trois revêtements, donc :
    ///   désert     → piste caravanière de gravier tassé
    ///   forêt      → sentier de terre foulée, teinté comme le sous-bois
    ///   ailleurs   → terre battue autotilée sur l'herbe
    ///
    /// La topologie de `roads` reste INTACTE : on masque au rendu au lieu
    /// de découper la grille, sinon la route se refermerait sur chaque
    /// lisière avec un liseré d'herbe tout neuf.
    /// `noGrassEdges` : tous les sols de terre (lisière aride, sous-bois,
    /// pourtour du sanctuaire, tabliers de l'est) où la route ne borde pas.
    func addOverworldRoads(_ geo: OverworldGeometry,
                           arid: VillageTileMap, forestFloor: VillageTileMap,
                           noGrassEdges grounds: [VillageTileMap],
                           in scene: SKScene) {
        let pVillage = geo.village, pForest = geo.forest, pShrine = geo.shrine
        let pRuins = geo.ruins, pMines = geo.mines, pDesert = geo.desert
        let pThreshold = geo.threshold
        var roads = geo.emptyMap()
        for (a, b) in [(pVillage, pForest), (pForest, pShrine),
                       (pForest, pDesert), (pShrine, pRuins),
                       (pShrine, pMines), (pMines, pThreshold),
                       (pVillage, pRuins)] {
            stampRoad(&roads, from: a, to: b)
        }
        // Clairière de terre sous chaque lieu : le POI est posé, pas flottant.
        for p in [pVillage, pForest, pShrine, pRuins, pMines, pDesert, pThreshold] {
            roads.stampEllipse(center: p, radiusX: 52, radiusY: 34)
        }
        var noGrassEdges = geo.emptyMap()
        for ground in grounds { noGrassEdges.formUnion(ground) }
        var caravanTrack = roads
        caravanTrack.intersect(arid)
        // Le sentier forestier est retracé ÉTROIT, pas découpé dans la route :
        // au gabarit de plaine il ouvrait sous les arbres une saignée de terre
        // nue plus large que la clairière du lieu, et le couvert n'existait plus.
        var woodTrail = geo.emptyMap()
        for (a, b) in [(pVillage, pForest), (pForest, pShrine), (pForest, pDesert)] {
            stampRoad(&woodTrail, from: a, to: b, half: 8)
        }
        woodTrail.stampEllipse(center: pForest, radiusX: 40, radiusY: 26)
        woodTrail.intersect(forestFloor)
        renderTileMap(roads, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.4, skipping: noGrassEdges)
        renderTileMap(caravanTrack, fullTile: "ds_gravel", edgePrefix: nil,
                      in: scene, z: -29.4)
        renderTileMap(woodTrail, fullTile: "me_dirt_full", edgePrefix: nil,
                      in: scene, z: -29.4,
                      tint: geo.ebonyShade, tintBlend: 0.34)
        // Cendreval ne reçoit AUCUN revêtement : la route s'arrête au pied du
        // massif et s'y perd. Une piste pavée par-dessus l'éboulis faisait une
        // matière de plus dans un écran qui en comptait déjà quatre — et un
        // sol trop bavard se remarque plus que le lieu qu'il porte. Deux
        // matières par endroit, pas davantage : le tablier qui raccorde au
        // vert, puis la matière du lieu.
    }
}
