import SpriteKit

// Géométrie du continent : les positions, rayons et teintes partagés par
// toutes les phases de `buildOverworld`. Calculée une fois pour une carte
// `w` × `h`, puis lue par le sol, les routes, la flore et les monuments —
// c'est la seule chose qui circule entre les fichiers `WorldBuilder+Overworld*`.
struct OverworldGeometry {
    let w: CGFloat
    let h: CGFloat
    /// Pas de la grille d'autotiling (points).
    let tile: CGFloat = 24

    // MARK: - Lieux (issus de `WorldBuilder.overworldLayout`)
    let village: CGPoint
    let forest: CGPoint
    let shrine: CGPoint
    let ruins: CGPoint
    let mines: CGPoint
    let desert: CGPoint
    let threshold: CGPoint
    let voidheart: CGPoint

    // MARK: - Désert d'Ossara (sud-est)
    let desertRect: CGRect
    var desertCenter: CGPoint { CGPoint(x: desertRect.midX, y: desertRect.midY) }

    // MARK: - Lac de Solis (sud-ouest)
    let lakeCenter: CGPoint
    let lakeRX: CGFloat
    let lakeRY: CGFloat

    // MARK: - Sanctuaire
    let shrineRX: CGFloat = 150
    let shrineRY: CGFloat = 98
    /// La pierre du sanctuaire : celle de l'ange, beige tiède. Le pavage
    /// et les bornes sont ramenés dessus — `a2_stone` et les colonnes sont
    /// d'un gris bleu froid qui jurait avec la statue qu'ils encadrent.
    let shrineStone = SKColor(red: 0.88, green: 0.84, blue: 0.76, alpha: 1)

    // MARK: - Forêt d'Ébène
    /// Massif resserré (0,20 → 0,17 de large, 0,24 → 0,185 de haut) : il
    /// mordait sur le Sanctuaire au nord et sur la route du désert à l'est.
    /// Il reste le plus grand ensemble de la carte, mais il laisse
    /// respirer ses voisins.
    let forestCenter: CGPoint
    let forestRX: CGFloat
    let forestRY: CGFloat
    let ebonyShade = SKColor(red: 0.16, green: 0.30, blue: 0.20, alpha: 1)

    // MARK: - Massif de Cendreval
    let mountCenter: CGPoint
    let mountRX: CGFloat
    let mountRY: CGFloat

    // MARK: - Ruines de la Source
    let ruinsRX: CGFloat = 190
    let ruinsRY: CGFloat = 132

    // MARK: - Le Seuil
    let thresholdRX: CGFloat = 210
    let thresholdRY: CGFloat = 140
    let voidShade = SKColor(red: 0.30, green: 0.20, blue: 0.42, alpha: 1)

    init(w: CGFloat, h: CGFloat) {
        self.w = w
        self.h = h
        // Positions issues de la disposition canonique (cf. overworldLayout) :
        // la carte de voyage rapide montre EXACTEMENT la même géographie.
        village   = WorldBuilder.overworldPoint("village",   w: w, h: h)
        forest    = WorldBuilder.overworldPoint("forest",    w: w, h: h)
        shrine    = WorldBuilder.overworldPoint("shrine",    w: w, h: h)
        ruins     = WorldBuilder.overworldPoint("ruins",     w: w, h: h)
        mines     = WorldBuilder.overworldPoint("mines",     w: w, h: h)
        desert    = WorldBuilder.overworldPoint("desert",    w: w, h: h)
        threshold = WorldBuilder.overworldPoint("threshold", w: w, h: h)
        voidheart = WorldBuilder.overworldPoint("voidheart", w: w, h: h)

        desertRect = CGRect(x: w * 0.66, y: 0, width: w * 0.34, height: h * 0.42)

        lakeCenter = CGPoint(x: w * 0.07, y: h * 0.10)
        lakeRX = w * 0.075
        lakeRY = h * 0.075

        forestCenter = CGPoint(x: forest.x, y: forest.y + h * 0.02)
        forestRX = w * 0.17
        forestRY = h * 0.185

        mountCenter = CGPoint(x: w * 0.80, y: h * 0.78)
        mountRX = w * 0.17
        mountRY = h * 0.17
    }

    /// Point du massif en coordonnées relatives à son centre.
    func inForest(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: forestCenter.x + forestRX * fx, y: forestCenter.y + forestRY * fy)
    }

    /// Point du désert en fractions de son rectangle — les bosquets se
    /// lisent alors sur le plan, pas en coordonnées absolues.
    func inDesert(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: desertRect.minX + desertRect.width * fx,
                y: desertRect.minY + desertRect.height * fy)
    }

    /// Une grille d'autotiling vide aux dimensions de la carte.
    func emptyMap() -> VillageTileMap {
        VillageTileMap(width: w, height: h, tile: tile)
    }

    /// Silhouette à trois lobes autour d'un centre — jamais un ovale nu.
    /// `feather` dilue le bord : sans lui, des strates empilées donnent des
    /// terrasses en escalier au lieu d'une ombre qui se referme.
    static func stampBlob(_ map: inout VillageTileMap, at c: CGPoint,
                          rx: CGFloat, ry: CGFloat, grow: CGFloat,
                          feather: CGFloat = 0) {
        map.stampEllipse(center: c, radiusX: rx * grow, radiusY: ry * grow,
                         feather: feather)
        map.stampEllipse(center: CGPoint(x: c.x - rx * 0.44, y: c.y - ry * 0.30),
                         radiusX: rx * 0.50 * grow, radiusY: ry * 0.48 * grow,
                         feather: feather)
        map.stampEllipse(center: CGPoint(x: c.x + rx * 0.40, y: c.y + ry * 0.34),
                         radiusX: rx * 0.46 * grow, radiusY: ry * 0.44 * grow,
                         feather: feather)
    }
}
