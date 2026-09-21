import SpriteKit

// Carte du monde (overworld façon FF7) — disposition canonique, coffres,
// entrée dans la zone et ORCHESTRATION de la construction. Chaque phase vit
// dans son fichier : `+OverworldTerrain` (sols de l'ouest),
// `+OverworldTerrainEast` (sols de l'est, routes), `+OverworldForestFlora`,
// `+OverworldLandmarks`, `+OverworldDesertFlora`, `+OverworldPOI` (helpers).
// La géométrie partagée est dans `OverworldGeometry`.
@MainActor
extension WorldBuilder {
    // MARK: - Carte du monde (overworld façon FF7)

    /// DISPOSITION CANONIQUE du continent, en fractions (0…1) de la carte,
    /// axe Y vers le haut. Source de vérité UNIQUE : le monde marchable
    /// (`buildOverworld`) ET la carte de voyage rapide (`buildMapPlaces`)
    /// s'en servent, donc les deux montrent la même géographie. Avant, les
    /// Mines étaient à l'est dans le monde et à l'ouest sur la carte…
    nonisolated static let overworldLayout: [String: CGPoint] = [
        "village":   CGPoint(x: 0.14, y: 0.34),
        "forest":    CGPoint(x: 0.40, y: 0.52),
        // Le Sanctuaire tombait DANS l'ellipse de la Forêt d'Ébène : son
        // parvis poussait sous la canopée, et le sous-bois venait lécher les
        // dalles. Un lieu consacré se gagne — il est remonté au nord du
        // massif, dans le couloir entre les Ruines et les Montagnes, à
        // découvert. La carte de voyage suit la même disposition.
        "shrine":    CGPoint(x: 0.54, y: 0.87),
        "ruins":     CGPoint(x: 0.30, y: 0.82),
        "mines":     CGPoint(x: 0.76, y: 0.80),
        "desert":    CGPoint(x: 0.83, y: 0.22),
        "threshold": CGPoint(x: 0.92, y: 0.90),
        // Au-delà du Seuil : pas de lieu marchable, mais la carte le situe.
        "voidheart": CGPoint(x: 0.96, y: 0.62)
    ]

    /// Position MONDE d'un lieu canonique, pour une carte `w` × `h`.
    nonisolated static func overworldPoint(_ id: String, w: CGFloat, h: CGFloat) -> CGPoint {
        let f = overworldLayout[id] ?? CGPoint(x: 0.5, y: 0.5)
        return CGPoint(x: w * f.x, y: h * f.y)
    }

    /// TRÉSORS de la carte, volontairement À L'ÉCART des chemins : le joueur
    /// qui sort des sentiers est récompensé. `gold`/`shards` par coffre.
    static let overworldChests: [(id: String, at: CGPoint, gold: Int, shards: Int)] = [
        // Derrière la forêt d'Ébène, au fond du bosquet.
        ("grove",  CGPoint(x: 0.24, y: 0.63), 90,  1),
        // Rive nord du lac, coincé entre les rochers.
        ("shore",  CGPoint(x: 0.06, y: 0.30), 120, 0),
        // Haut des montagnes de Cendreval, derrière les aiguilles.
        ("summit", CGPoint(x: 0.66, y: 0.94), 150, 2)
    ]

    /// Rive est du lac de Solis : le seul endroit où l'on pêche.
    /// Le lac est en (0.07, 0.10) de rayon (0.075, 0.075) — le spot est posé
    /// juste au bord, du côté que Kael longe en venant du village.
    static func overworldFishingSpot(w: CGFloat, h: CGFloat) -> CGPoint {
        CGPoint(x: w * 0.155, y: h * 0.115)
    }

    /// Position MONDE d'un coffre de la carte.
    static func overworldChestPoint(_ id: String, w: CGFloat, h: CGFloat) -> CGPoint {
        let f = overworldChests.first { $0.id == id }?.at ?? CGPoint(x: 0.5, y: 0.5)
        return CGPoint(x: w * f.x, y: h * f.y)
    }

    /// Pose les coffres non encore ouverts sur la carte du monde.
    func addOverworldChests(taken: Set<String>, in scene: SKScene) {
        let w = worldWidth > 0 ? worldWidth : scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height
        for chest in Self.overworldChests where !taken.contains(chest.id) {
            addTreasureChest(named: "owChest_\(chest.id)",
                             at: CGPoint(x: w * chest.at.x, y: h * chest.at.y),
                             in: scene)
        }
    }

    /// Retire un coffre de la carte après ramassage.
    func removeOverworldChest(_ id: String) {
        guard let chest = worldNode.childNode(withName: "owChest_\(id)") else { return }
        chest.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
    }

    /// Le grand continent explorable : Kael marche d'un lieu à l'autre, la
    /// caméra le suit en 2D (`worldWidth`/`worldHeight` > écran).
    func switchToOverworld(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.07, green: 0.13, blue: 0.09, alpha: 1)
        let w = scene.size.width * 2.7
        let h = scene.size.height * 2.4
        worldWidth = w
        worldHeight = h
        buildOverworld(in: scene, w: w, h: h)
    }

    /// Assemble le continent, phase par phase. L'ordre est celui des couches :
    /// sols (z négatifs, du plus profond au plus proche), puis routes, puis
    /// tout ce qui se dresse (flore, monuments, entrées de lieu).
    func buildOverworld(in scene: SKScene, w: CGFloat, h: CGFloat) {
        overworldPlaces.removeAll()
        let geo = OverworldGeometry(w: w, h: h)

        // ── SOLS ──
        addOverworldPlainsFloor(geo, in: scene)
        let arid = addOverworldDesertStrata(geo, in: scene)
        addOverworldLake(geo, in: scene)
        let shrineGround = addOverworldShrineGround(geo, in: scene)
        let forestFloor = addOverworldForestFloor(geo, in: scene)
        let east = addOverworldEastTerrain(geo, in: scene)
        addOverworldRoads(geo, arid: arid, forestFloor: forestFloor,
                          noGrassEdges: [arid, forestFloor, shrineGround,
                                         east.mountApron, east.ruinsApron, east.blight],
                          in: scene)

        // ── CE QUI SE DRESSE ──
        plantOverworldForest(geo, in: scene)
        dressOverworldShrine(geo, in: scene)
        dressOverworldMountains(geo, in: scene)
        dressOverworldRuins(geo, in: scene)
        dressOverworldThreshold(geo, in: scene)
        plantOverworldDesert(geo, in: scene)
        scatterOverworldPlains(geo, in: scene)
        addOverworldPlaces(geo, in: scene)
    }

    /// Détail des plaines : fleurs & cailloux, sobre (jamais sur l'eau).
    /// La zone interdite couvre la LISIÈRE ARIDE, pas seulement le sable :
    /// des fleurs vives sur la terre desséchée annulaient tout le dégradé
    /// prairie → steppe → désert. Idem sous le couvert et sur le parvis :
    /// ces deux lieux ont leur propre flore (fougères d'ombre, offrandes
    /// blanches). Les fleurs de prairie qui s'y invitaient brouillaient les
    /// deux ambiances.
    func scatterOverworldPlains(_ geo: OverworldGeometry, in scene: SKScene) {
        let everywhere = CGRect(x: 0, y: 0, width: geo.w, height: geo.h)
        let lake = lakeRect(geo.lakeCenter, geo.lakeRX, geo.lakeRY)
        let desertKeepOut = geo.desertRect.insetBy(dx: -geo.desertRect.width * 0.10,
                                                   dy: -geo.desertRect.height * 0.10)
        let forestKeepOut = CGRect(x: geo.forestCenter.x - geo.forestRX,
                                   y: geo.forestCenter.y - geo.forestRY,
                                   width: geo.forestRX * 2, height: geo.forestRY * 2)
        let shrineKeepOut = CGRect(x: geo.shrine.x - geo.shrineRX,
                                   y: geo.shrine.y - geo.shrineRY,
                                   width: geo.shrineRX * 2, height: geo.shrineRY * 2)
        scatterOverworld(["village_flower_yellow", "village_flower_pink",
                          "village_flower_red", "me_flower_blue", "ext_flower_sun"],
                         count: 46, in: everywhere, scale: 0.45,
                         avoiding: [lake, desertKeepOut, forestKeepOut, shrineKeepOut],
                         in: scene)
        // `ds_rock` a quitté cette liste : c'est un PAVAGE de 96×96 tileable,
        // pas un caillou. Semé en sprite, il posait dix-huit dalles beiges au
        // hasard sur la carte — en pleine prairie, sur les routes, dans les
        // bois. Il sert maintenant à ce pour quoi il est dessiné : le parvis.
        scatterOverworld(["rock_5", "rock_9", "rock_1", "rock_3"],
                         count: 18, in: everywhere, scale: 0.34,
                         avoiding: [lake], in: scene)
    }

    /// Lieux (POI d'entrée) — chacun sur sa clairière de terre.
    func addOverworldPlaces(_ geo: OverworldGeometry, in scene: SKScene) {
        addOverworldPlace("village",   asset: "village_house_country", scale: 0.24,
                          at: geo.village,
                          title: String(localized: "map.place.village"), in: scene)
        addOverworldPlace("forest",    asset: "tree_big", scale: 0.42,
                          at: geo.forest,
                          title: String(localized: "map.place.forest"), in: scene)
        addOverworldPlace("shrine",    asset: "me_statue_angel", scale: 0.4,
                          at: geo.shrine,
                          title: String(localized: "map.place.shrine"), in: scene)
        addOverworldPlace("ruins",     asset: "me_statue_angel", scale: 0.34,
                          at: geo.ruins,
                          title: String(localized: "map.place.ruins"), in: scene)
        addOverworldPlace("mines",     asset: "ds_cliff_big", scale: 0.4,
                          at: geo.mines,
                          title: String(localized: "map.place.mines"), in: scene)
        addOverworldPlace("desert",    asset: "ds_tent_big", scale: 0.34,
                          at: geo.desert,
                          title: String(localized: "map.place.desert"), in: scene)
        addOverworldPlace("threshold", asset: "gy_gate_big", scale: 0.4,
                          at: geo.threshold,
                          title: String(localized: "map.place.threshold"), in: scene)
    }
}
