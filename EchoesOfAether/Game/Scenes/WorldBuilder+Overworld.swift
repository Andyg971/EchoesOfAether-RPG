import SpriteKit

// Carte du monde (overworld façon FF7) — première moitié : construction.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Carte du monde (overworld façon FF7)

    /// DISPOSITION CANONIQUE du continent, en fractions (0…1) de la carte,
    /// axe Y vers le haut. Source de vérité UNIQUE : le monde marchable
    /// (`buildOverworld`) ET la carte de voyage rapide (`buildMapPlaces`)
    /// s'en servent, donc les deux montrent la même géographie. Avant, les
    /// Mines étaient à l'est dans le monde et à l'ouest sur la carte…
    static let overworldLayout: [String: CGPoint] = [
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
    static func overworldPoint(_ id: String, w: CGFloat, h: CGFloat) -> CGPoint {
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

    func buildOverworld(in scene: SKScene, w: CGFloat, h: CGFloat) {
        overworldPlaces.removeAll()

        // ── SOL : plaines herbeuses lumineuses (variétés mêlées) ──
        addTiledFloor(in: scene,
                      tileNames: ["me_grassvar_1", "me_grassvar_1", "me_grassvar_1",
                                  "me_grassvar_5", "me_grassvar_5",
                                  "me_grassvar_2", "me_grassvar_3", "me_grassvar_4"],
                      fallbackColor: SKColor(red: 0.36, green: 0.58, blue: 0.30, alpha: 1),
                      tileScale: 0.5, z: -30,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Positions des lieux (partagées entre chemins, décors et POI).
        // Positions issues de la disposition canonique (cf. overworldLayout) :
        // la carte de voyage rapide montre EXACTEMENT la même géographie.
        let pVillage   = Self.overworldPoint("village",   w: w, h: h)
        let pForest    = Self.overworldPoint("forest",    w: w, h: h)
        let pShrine    = Self.overworldPoint("shrine",    w: w, h: h)
        let pRuins     = Self.overworldPoint("ruins",     w: w, h: h)
        let pMines     = Self.overworldPoint("mines",     w: w, h: h)
        let pDesert    = Self.overworldPoint("desert",    w: w, h: h)
        let pThreshold = Self.overworldPoint("threshold", w: w, h: h)
        let tile: CGFloat = 24

        // ── DÉSERT D'OSSARA (sud-est) : TROIS STRATES, comme un vrai désert.
        //
        // Un désert ne commence pas sur un trait : la prairie s'assèche en
        // steppe, la steppe durcit en croûte craquelée, et le sable prend le
        // dessus au centre. Le tileset porte exactement cette lecture — les
        // `ds_edge_*` sont des transitions SABLE↔CROÛTE, pas sable↔herbe.
        // Posées sur l'herbe (l'ancien code), elles dessinaient un anneau de
        // boue en escalier qui tranchait sur le vert : d'où le rendu sale.
        //
        // Les trois strates partagent la MÊME silhouette à des échelles
        // décroissantes : c'est ce qui les fait lire comme un dégradé
        // concentrique et non comme trois taches empilées.
        let desert = CGRect(x: w * 0.66, y: 0, width: w * 0.34, height: h * 0.42)
        let desertC = CGPoint(x: desert.midX, y: desert.midY)
        /// Silhouette du désert : le grand ovale + deux langues débordantes
        /// (bord organique, jamais un ovale nu), à l'échelle `grow`.
        func stampDesert(_ map: inout VillageTileMap, grow: CGFloat) {
            map.stampEllipse(center: desertC,
                             radiusX: desert.width * 0.66 * grow,
                             radiusY: desert.height * 0.74 * grow)
            map.stampEllipse(center: CGPoint(x: desertC.x + w * 0.08,
                                             y: desertC.y + h * 0.09),
                             radiusX: desert.width * 0.38 * grow,
                             radiusY: desert.height * 0.36 * grow)
            map.stampEllipse(center: CGPoint(x: desertC.x - w * 0.07,
                                             y: desertC.y - h * 0.08),
                             radiusX: desert.width * 0.32 * grow,
                             radiusY: desert.height * 0.30 * grow)
        }

        // Strate 1 — LISIÈRE ARIDE : terre battue autotilée sur l'herbe. Ce
        // sont les transitions des routes, déjà justes sur le vert.
        var arid = VillageTileMap(width: w, height: h, tile: tile)
        stampDesert(&arid, grow: 1.12)
        renderTileMap(arid, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.8)

        // Strate 2 — CROÛTE CRAQUELÉE : le hardpan. Quatre variantes mêlées,
        // bord franc sur la terre battue — deux bruns voisins, la coupure ne
        // se voit pas, alors qu'elle hurlait contre l'herbe.
        var hardpan = VillageTileMap(width: w, height: h, tile: tile)
        stampDesert(&hardpan, grow: 1.0)
        renderTileMap(hardpan, fullTile: "ds_cracked", edgePrefix: nil,
                      in: scene, z: -29.7,
                      variants: ["ds_cracked", "ds_cracked2",
                                 "ds_cracked3", "ds_cracked_dark"])

        // Strate 3 — LE SABLE : autotilé sur la croûte avec ses VRAIES
        // transitions. Trois variantes pour casser la trame diagonale de
        // `ds_sand`, qui se lisait en damier sur toute la largeur du désert.
        var sand = VillageTileMap(width: w, height: h, tile: tile)
        stampDesert(&sand, grow: 0.84)
        renderTileMap(sand, fullTile: "ds_sand", edgePrefix: "ds_edge_",
                      in: scene, z: -29.6,
                      variants: ["ds_sand", "ds_sand2", "ds_sand3"])

        // Strate 4 — CHAMPS DE DUNES : nappes de sable ondulé là où le vent
        // travaille, au cœur. `ds_dune` est une TUILE, pas un objet : semée
        // en sprites elle posait des carrés de vagues sur le sable — c'était
        // l'artefact le plus voyant de la carte.
        var dunes = VillageTileMap(width: w, height: h, tile: tile)
        for (fx, fy, fr) in [(0.38, 0.60, 0.30), (0.66, 0.34, 0.26),
                             (0.22, 0.26, 0.22), (0.80, 0.68, 0.20)] {
            dunes.stampEllipse(center: CGPoint(x: desert.minX + desert.width * fx,
                                               y: desert.minY + desert.height * fy),
                               radiusX: desert.width * fr,
                               radiusY: desert.height * fr * 0.9)
        }
        renderTileMap(dunes, fullTile: "ds_dune", edgePrefix: nil,
                      in: scene, z: -29.55, variants: ["ds_dune", "ds_dune2"])

        // Strate 5 — GRAVIER : deux reg pierreux, le contrepoint minéral du
        // sable. Ils accueillent les blocs rocheux plus bas.
        var reg = VillageTileMap(width: w, height: h, tile: tile)
        for (fx, fy, fr) in [(0.14, 0.72, 0.15), (0.72, 0.14, 0.13)] {
            reg.stampEllipse(center: CGPoint(x: desert.minX + desert.width * fx,
                                             y: desert.minY + desert.height * fy),
                             radiusX: desert.width * fr,
                             radiusY: desert.height * fr * 0.9)
        }
        renderTileMap(reg, fullTile: "ds_gravel", edgePrefix: nil,
                      in: scene, z: -29.54)

        // ── LAC DE SOLIS (sud-ouest) : eau + berges autotilées, comme l'étang
        // du village. L'eau ne se marche pas (obstacle enregistré).
        let lakeC = CGPoint(x: w * 0.07, y: h * 0.10)
        let lakeRX = w * 0.075, lakeRY = h * 0.075
        var lake = VillageTileMap(width: w, height: h, tile: tile)
        lake.stampEllipse(center: lakeC, radiusX: lakeRX, radiusY: lakeRY)
        renderTileMap(lake, fullTile: "me_water_full", edgePrefix: "me_shore_",
                      in: scene, z: -29.5)
        registerObstacle(CGRect(x: lakeC.x - lakeRX * 0.9, y: lakeC.y - lakeRY * 0.9,
                                width: lakeRX * 1.8, height: lakeRY * 1.8))
        add(LightingEngine.waterShimmer(center: lakeC, radiusX: lakeRX, radiusY: lakeRY),
            to: scene)

        // ── SANCTUAIRE : une clairière consacrée, pas une statue sur l'herbe.
        //
        // Le lieu n'avait AUCUN sol propre : l'ange était posé sur la même
        // prairie que le reste du continent, et les trois routes qui y
        // convergent s'y étalaient en une flaque de terre informe. Même
        // méthode que le désert — des strates concentriques, de la prairie
        // sauvage vers le cœur pavé.
        let shrineRX: CGFloat = 150, shrineRY: CGFloat = 98
        /// La pierre du sanctuaire : celle de l'ange, beige tiède. Le pavage
        /// et les bornes sont ramenés dessus — `a2_stone` et les colonnes sont
        /// d'un gris bleu froid qui jurait avec la statue qu'ils encadrent.
        let shrineStone = SKColor(red: 0.88, green: 0.84, blue: 0.76, alpha: 1)
        var shrineGround = VillageTileMap(width: w, height: h, tile: tile)
        shrineGround.stampEllipse(center: pShrine, radiusX: shrineRX, radiusY: shrineRY)
        // Deux lobes : le pourtour entretenu suit le terrain, pas un compas.
        shrineGround.stampEllipse(center: CGPoint(x: pShrine.x - 68, y: pShrine.y + 44),
                                  radiusX: shrineRX * 0.46, radiusY: shrineRY * 0.46)
        shrineGround.stampEllipse(center: CGPoint(x: pShrine.x + 64, y: pShrine.y - 38),
                                  radiusX: shrineRX * 0.42, radiusY: shrineRY * 0.42)
        // Terre BALAYÉE, éclaircie : sans ça le pourtour consacré se confondait
        // avec les trois routes qui y aboutissent — même tuile, même ton.
        renderTileMap(shrineGround, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.48,
                      tint: SKColor(white: 1, alpha: 1), tintBlend: 0.22)
        // Le parvis dallé, franc sur la terre battue : c'est une dalle posée
        // par des mains, elle a le droit d'avoir un bord net. `ds_rock` est un
        // vrai pavage beige, de la couleur de l'ange — `a2_stone` était un gris
        // bleu de carrière qui refroidissait tout le lieu.
        var shrinePlaza = VillageTileMap(width: w, height: h, tile: tile)
        shrinePlaza.stampEllipse(center: pShrine,
                                 radiusX: shrineRX * 0.62, radiusY: shrineRY * 0.62)
        renderTileMap(shrinePlaza, fullTile: "ds_rock", edgePrefix: nil,
                      in: scene, z: -29.46)

        // ── FORÊT D'ÉBÈNE : le SOL du massif, en strates d'ombre ──
        //
        // Le sous-bois était tuilé en `tile_grass_dark`, une planche de 16 px
        // là où la grille d'autotiling compte 24 pt : chaque tuile ne couvrait
        // qu'un neuvième de sa cellule. Le « couvert sombre » était donc un
        // semis de confettis invisibles, et la forêt poussait sur la prairie
        // vive — d'où l'impression de papier peint d'arbres.
        //
        // Ici l'ombre est TEINTE sur la vraie tuile d'herbe (48 px, à
        // l'échelle) et se referme en trois paliers : lisière, sous-bois,
        // cœur d'ébène. C'est le dégradé qui donne sa profondeur au massif.
        // Massif resserré (0,20 → 0,17 de large, 0,24 → 0,185 de haut) : il
        // mordait sur le Sanctuaire au nord et sur la route du désert à l'est.
        // Il reste le plus grand ensemble de la carte, mais il laisse
        // respirer ses voisins.
        let forestC = CGPoint(x: pForest.x, y: pForest.y + h * 0.02)
        let forestRX = w * 0.17, forestRY = h * 0.185
        let ebonyShade = SKColor(red: 0.16, green: 0.30, blue: 0.20, alpha: 1)
        /// Silhouette du massif à l'échelle `grow` — deux lobes, jamais un ovale.
        /// `feather` dilue le bord : sans lui, trois teintes empilées donnent
        /// trois terrasses en escalier au lieu d'une ombre qui se referme.
        func stampForest(_ map: inout VillageTileMap, grow: CGFloat,
                         feather: CGFloat = 0) {
            map.stampEllipse(center: forestC,
                             radiusX: forestRX * grow, radiusY: forestRY * grow,
                             feather: feather)
            map.stampEllipse(center: CGPoint(x: forestC.x - forestRX * 0.42,
                                             y: forestC.y - forestRY * 0.34),
                             radiusX: forestRX * 0.52 * grow,
                             radiusY: forestRY * 0.50 * grow, feather: feather)
            map.stampEllipse(center: CGPoint(x: forestC.x + forestRX * 0.38,
                                             y: forestC.y + forestRY * 0.30),
                             radiusX: forestRX * 0.48 * grow,
                             radiusY: forestRY * 0.46 * grow, feather: feather)
        }
        // UNE seule teinte, pas trois paliers : empiler des tuiles identiques
        // à des mélanges différents dessinait des terrasses de rizière, et les
        // diluer cellule par cellule remplaçait les terrasses par une mosaïque
        // de carrés clairs — dans les deux cas la grille se voyait. La
        // profondeur vient des arbres, le sol se contente d'être une ombre.
        var forestFloor = VillageTileMap(width: w, height: h, tile: tile)
        stampForest(&forestFloor, grow: 1.0)
        // La frange se compte en CELLULES, pas en pourcentage : `feather` est
        // une fraction du rayon, et le massif fait ~450 pt de demi-largeur —
        // 0,26 diluait cinq cellules de large, soit un damier de gros carrés
        // clairs en pleine forêt. Deux cellules suffisent à casser l'ovale.
        var understory = VillageTileMap(width: w, height: h, tile: tile)
        stampForest(&understory, grow: 1.0, feather: tile * 2 / forestRX)
        // Teinte PLATE, sans variantes ni jitter : le sous-bois est une ombre,
        // pas une matière. Toute variation de tuile à tuile se lit en damier
        // à cette échelle de caméra — le relief, ce sont les arbres.
        renderTileMap(understory, fullTile: "me_grassvar_1", edgePrefix: nil,
                      in: scene, z: -29.44, tint: ebonyShade, tintBlend: 0.38)

        // ── L'EST DU CONTINENT : trois sols, trois natures ──
        //
        // Cendreval, les Ruines et le Seuil étaient posés À MÊME LA PRAIRIE :
        // des blocs orange sur une pelouse, une statue sur du gazon, un portail
        // du Vide sur de l'herbe vive. Chacun reçoit ses strates, même recette
        // que le désert — un tablier de terre qui raccorde au vert, puis la
        // matière propre au lieu.
        /// Silhouette à trois lobes autour d'un centre — jamais un ovale nu.
        func stampBlob(_ map: inout VillageTileMap, at c: CGPoint,
                       rx: CGFloat, ry: CGFloat, grow: CGFloat, feather: CGFloat = 0) {
            map.stampEllipse(center: c, radiusX: rx * grow, radiusY: ry * grow,
                             feather: feather)
            map.stampEllipse(center: CGPoint(x: c.x - rx * 0.44, y: c.y - ry * 0.30),
                             radiusX: rx * 0.50 * grow, radiusY: ry * 0.48 * grow,
                             feather: feather)
            map.stampEllipse(center: CGPoint(x: c.x + rx * 0.40, y: c.y + ry * 0.34),
                             radiusX: rx * 0.46 * grow, radiusY: ry * 0.44 * grow,
                             feather: feather)
        }

        // MASSIF DE CENDREVAL : dalle rocheuse sous les blocs.
        let mountC = CGPoint(x: w * 0.80, y: h * 0.78)
        let mountRX = w * 0.17, mountRY = h * 0.17
        var mountApron = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&mountApron, at: mountC, rx: mountRX, ry: mountRY, grow: 1.08)
        renderTileMap(mountApron, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.78)
        // Éboulis de gravier, PAS de dalle grise : `a2_stone` est une pierre de
        // carrière bleu-gris, et en nappe sur un massif elle donnait une plaque
        // de bitume au milieu des prairies — les blocs orange posés dessus
        // n'avaient plus rien à voir avec leur propre sol. `ds_gravel` sort du
        // MÊME pack que ces blocs : la montagne et ses éboulis redeviennent la
        // même roche.
        var mountRock = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&mountRock, at: mountC, rx: mountRX, ry: mountRY, grow: 0.86,
                  feather: tile * 2 / mountRX)
        renderTileMap(mountRock, fullTile: "ds_gravel", edgePrefix: nil,
                      in: scene, z: -29.76)

        // RUINES DE LA SOURCE : un parvis effondré, pas une statue sur l'herbe.
        let ruinsRX: CGFloat = 190, ruinsRY: CGFloat = 132
        var ruinsApron = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&ruinsApron, at: pRuins, rx: ruinsRX, ry: ruinsRY, grow: 1.0)
        renderTileMap(ruinsApron, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.74)
        var ruinsFloor = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&ruinsFloor, at: pRuins, rx: ruinsRX, ry: ruinsRY, grow: 0.74,
                  feather: tile * 2 / ruinsRX)
        renderTileMap(ruinsFloor, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -29.72,
                      tint: SKColor(red: 0.78, green: 0.76, blue: 0.74, alpha: 1),
                      tintBlend: 0.40)

        // LE SEUIL : la corruption ronge le sol avant le portail. Le violet du
        // Vide n'attend pas qu'on franchisse la porte — c'est ce qui manquait
        // le plus, l'approche disait « prairie » jusqu'au dernier pas.
        let voidShade = SKColor(red: 0.30, green: 0.20, blue: 0.42, alpha: 1)
        let thrRX: CGFloat = 210, thrRY: CGFloat = 140
        var blight = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&blight, at: pThreshold, rx: thrRX, ry: thrRY, grow: 1.06)
        renderTileMap(blight, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.70, tint: voidShade, tintBlend: 0.52)
        var voidFloor = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&voidFloor, at: pThreshold, rx: thrRX, ry: thrRY, grow: 0.72,
                  feather: tile * 2 / thrRX)
        renderTileMap(voidFloor, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -29.68, tint: voidShade, tintBlend: 0.70)

        // LE CŒUR DU VIDE : au-delà du Seuil, hors d'atteinte. Il n'a pas de
        // lieu marchable — mais la faille se VOIT depuis le portail, et c'est
        // ce qui donne au Seuil quelque chose à garder.
        let pVoid = Self.overworldPoint("voidheart", w: w, h: h)
        var rift = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&rift, at: pVoid, rx: 168, ry: 118, grow: 1.0)
        renderTileMap(rift, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.66, tint: voidShade, tintBlend: 0.62)
        var riftCore = VillageTileMap(width: w, height: h, tile: tile)
        stampBlob(&riftCore, at: pVoid, rx: 168, ry: 118, grow: 0.60,
                  feather: tile * 2 / 168)
        renderTileMap(riftCore, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -29.64,
                      tint: SKColor(red: 0.36, green: 0.16, blue: 0.50, alpha: 1),
                      tintBlend: 0.82)

        // ── ROUTES : un seul réseau de terre battue AUTOTILÉ (transitions
        // me_edge_* sur l'herbe) — la lecture « vraie carte du monde ».
        var roads = VillageTileMap(width: w, height: h, tile: tile)
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
        // La route CHANGE DE MATIÈRE selon la zone qu'elle traverse. Ses bords
        // `me_edge_*` portent de l'HERBE : la piste d'Ossara traversait le
        // sable bordée de vert vif, la tente était cernée de gazon en plein
        // désert, et sous les arbres le même liseré vif annulait l'ombre du
        // couvert. Trois revêtements, donc :
        //   désert     → piste caravanière de gravier tassé
        //   forêt      → sentier de terre foulée, teinté comme le sous-bois
        //   ailleurs   → terre battue autotilée sur l'herbe
        //
        // La topologie de `roads` reste INTACTE : on masque au rendu au lieu
        // de découper la grille, sinon la route se refermerait sur chaque
        // lisière avec un liseré d'herbe tout neuf.
        var noGrassEdges = arid
        noGrassEdges.formUnion(forestFloor)
        noGrassEdges.formUnion(shrineGround)
        noGrassEdges.formUnion(mountApron)
        noGrassEdges.formUnion(ruinsApron)
        noGrassEdges.formUnion(blight)
        var caravanTrack = roads
        caravanTrack.intersect(arid)
        // Le sentier forestier est retracé ÉTROIT, pas découpé dans la route :
        // au gabarit de plaine il ouvrait sous les arbres une saignée de terre
        // nue plus large que la clairière du lieu, et le couvert n'existait plus.
        var woodTrail = VillageTileMap(width: w, height: h, tile: tile)
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
                      tint: ebonyShade, tintBlend: 0.34)
        // Cendreval ne reçoit AUCUN revêtement : la route s'arrête au pied du
        // massif et s'y perd. Une piste pavée par-dessus l'éboulis faisait une
        // matière de plus dans un écran qui en comptait déjà quatre — et un
        // sol trop bavard se remarque plus que le lieu qu'il porte. Deux
        // matières par endroit, pas davantage : le tablier qui raccorde au
        // vert, puis la matière du lieu.

        // ── FORÊT D'ÉBÈNE : des PEUPLEMENTS, pas un papier peint ──
        //
        // Toutes les espèces étaient tirées d'un seul sac pondéré sur tout le
        // massif : chaque mètre carré avait la même composition que le voisin,
        // donc aucune lecture d'ensemble — du bruit vert d'un bout à l'autre.
        // Une vraie forêt pousse par peuplements, et respire par clairières.
        let forestPOIClearing = CGRect(x: pForest.x - 56, y: pForest.y - 40,
                                       width: 112, height: 80)

        /// Point du massif en coordonnées relatives à son centre.
        func inForest(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: forestC.x + forestRX * fx, y: forestC.y + forestRY * fy)
        }

        // Les clairières : deux trouées de lumière où rien de haut ne pousse.
        // Ce sont elles qui donnent une échelle au massif — sans respiration,
        // un mur d'arbres n'a ni profondeur ni parcours.
        let glades = [CGRect(x: inForest(-0.30, 0.44).x - 62,
                             y: inForest(-0.30, 0.44).y - 44, width: 124, height: 88),
                      CGRect(x: inForest(0.44, -0.36).x - 54,
                             y: inForest(0.44, -0.36).y - 38, width: 108, height: 76)]
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
                      center: inForest(fx, fy),
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
                      center: inForest(fx, fy),
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
                      center: inForest(fx, fy),
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

        // ── SANCTUAIRE : ce qui fait un lieu consacré ──
        // Un cercle de bornes de pierre autour du parvis, posé à l'ANGLE —
        // sept pierres régulières, parce qu'une main les a dressées. Un semis
        // aléatoire aurait dit « cailloux », pas « sanctuaire ».
        /// Pose une pièce de mobilier sacré à sa hauteur d'écran, ramenée à la
        /// pierre de l'ange. Sans la teinte, chaque borne gardait le gris bleu
        /// de son pack d'origine : sept objets dépareillés autour d'une statue.
        func placeShrinePiece(_ asset: String, at p: CGPoint, height: CGFloat,
                              tinted: Bool = true) {
            guard let texH = PixelArtSprites.pixelHeight(of: asset), texH > 0,
                  let node = PixelArtSprites.still(name: asset, scale: height / texH,
                                                   anchor: CGPoint(x: 0.5, y: 0.0))
            else { return }
            if tinted {
                node.forEachDescendantSprite { sprite in
                    sprite.color = shrineStone
                    sprite.colorBlendFactor = 0.55
                }
            }
            node.position = p
            node.zPosition = actorLayer(for: p.y) - 0.2
            add(node, to: scene)
        }

        // Six petites statues d'orants, alternées, dans la même pierre pâle que
        // l'ange. Le premier essai dressait des `gy_stone_*` et des
        // `pillar_grey_*` : ce sont des PIERRES TOMBALES, elles transformaient
        // le sanctuaire en cimetière — un contresens à trois zones du Seuil.
        let shrineStones = ["me_statue_putto", "angel_statue_2", "me_statue_putto",
                            "angel_statue_2", "me_statue_putto", "angel_statue_2"]
        for (i, asset) in shrineStones.enumerated() {
            let a = CGFloat(i) / CGFloat(shrineStones.count) * .pi * 2 - .pi / 2
            placeShrinePiece(asset,
                             at: CGPoint(x: pShrine.x + cos(a) * shrineRX * 0.76,
                                         y: pShrine.y + sin(a) * shrineRY * 0.78),
                             height: 40, tinted: false)
        }
        // Cierges au pied du parvis, bancs de pèlerins face à l'ange, vasques
        // en fond : ce sont les traces d'un lieu FRÉQUENTÉ, pas un monument.
        placeShrinePiece("gy_candle", at: CGPoint(x: pShrine.x - 66, y: pShrine.y + 2),
                         height: 38)
        placeShrinePiece("gy_candle", at: CGPoint(x: pShrine.x + 66, y: pShrine.y + 2),
                         height: 38)
        placeShrinePiece("me_bench_1", at: CGPoint(x: pShrine.x - 52, y: pShrine.y - 60),
                         height: 22, tinted: false)
        placeShrinePiece("me_bench_1", at: CGPoint(x: pShrine.x + 52, y: pShrine.y - 60),
                         height: 22, tinted: false)
        placeShrinePiece("me_statue_grey",
                         at: CGPoint(x: pShrine.x - 122, y: pShrine.y - 46), height: 54)
        placeShrinePiece("me_fountain",
                         at: CGPoint(x: pShrine.x + 122, y: pShrine.y - 46), height: 50)
        // Fleurs blanches sur le pourtour entretenu : l'anneau d'offrandes qui
        // sépare le parvis de la prairie sauvage.
        plantMass([Flora(asset: "me_flower_white", height: 13, weight: 4),
                   Flora(asset: "me_flower_blue",  height: 13, weight: 3),
                   Flora(asset: "me_flower_pink",  height: 12, weight: 2),
                   Flora(asset: "me_grass_clean_2", height: 11, weight: 2)],
                  center: pShrine, radiusX: shrineRX * 0.94, radiusY: shrineRY * 0.94,
                  step: 30, coreDensity: 0.06, edgeDensity: 0.46,
                  avoiding: [CGRect(x: pShrine.x - 62, y: pShrine.y - 46,
                                    width: 124, height: 92)],
                  in: scene)

        // ── MONTAGNES DE CENDREVAL : les blocs, sur leur dalle ──
        let minesClearing = CGRect(x: pMines.x - 78, y: pMines.y - 52,
                                   width: 156, height: 104)
        let thresholdClearing = CGRect(x: pThreshold.x - thrRX * 0.80,
                                       y: pThreshold.y - thrRY * 0.80,
                                       width: thrRX * 1.60, height: thrRY * 1.60)
        plantMass([Flora(asset: "ds_rock_spire", height: 62, weight: 4),
                   Flora(asset: "ds_rock_big",   height: 44, weight: 3),
                   Flora(asset: "ds_boulder",    height: 34, weight: 3),
                   Flora(asset: "ds_boulder2",   height: 30, weight: 2),
                   Flora(asset: "rock_1",        height: 26, weight: 2),
                   Flora(asset: "rock_3",        height: 22, weight: 2)],
                  center: mountC, radiusX: mountRX, radiusY: mountRY,
                  step: 42, coreDensity: 0.80, edgeDensity: 0.20,
                  avoiding: [minesClearing, thresholdClearing],
                  in: scene)

        // ── LE CARREAU DE LA MINE : une entrée de mine, c'est un CHANTIER.
        // Le POI n'était qu'une falaise couchée sur la terre battue — rien ne
        // disait qu'on y descendait chercher du minerai.
        for (asset, dx, dy, hgt) in [("me_wood_cart", -86.0, -30.0, 30.0),
                                     ("me_cart_empty", 84.0, -34.0, 28.0),
                                     ("ext_cut_wood", -52.0, -50.0, 14.0),
                                     ("me_cut_wood", 56.0, -54.0, 16.0),
                                     ("village_lantern_1", -70.0, 20.0, 34.0),
                                     ("village_lantern_1", 70.0, 20.0, 34.0),
                                     ("ds_ladder", 104.0, 6.0, 26.0),
                                     ("me_barrel_1", -104.0, 4.0, 20.0),
                                     ("me_barrel_2", -92.0, -8.0, 20.0),
                                     ("ds_rock_pile", 40.0, -68.0, 20.0),
                                     ("ds_rock_pile", -34.0, -72.0, 18.0)] {
            guard let texH = PixelArtSprites.pixelHeight(of: asset), texH > 0,
                  let node = PixelArtSprites.still(name: asset,
                                                   scale: CGFloat(hgt) / texH,
                                                   anchor: CGPoint(x: 0.5, y: 0.0))
            else { continue }
            // Passés au brun de suie : sortis du pack village, la charrette
            // rouge vif et les tonneaux bleus donnaient au carreau de mine un
            // air de kermesse. Le charbon salit tout ce qu'on descend dedans.
            node.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.34, green: 0.26, blue: 0.20, alpha: 1)
                sprite.colorBlendFactor = 0.55
            }
            node.position = CGPoint(x: pMines.x + CGFloat(dx), y: pMines.y + CGFloat(dy))
            node.zPosition = actorLayer(for: node.position.y) - 0.2
            add(node, to: scene)
        }

        // ── RUINES DE LA SOURCE : ce qui reste d'un sanctuaire plus vieux que
        // le Sanctuaire. Colonnes couchées, fûts brisés, dalles descellées —
        // et pas une fleur : la Source est tarie.
        var ruinSeed: UInt64 = 0x5057_3E11
        func ruinNext() -> CGFloat {
            ruinSeed = ruinSeed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(ruinSeed >> 40) / CGFloat(1 << 24)
        }
        for i in 0..<14 {
            let a = CGFloat(i) / 14 * .pi * 2 + 0.35
            let ray = 0.62 + ruinNext() * 0.34
            // Uniquement des fûts et des blocs : `pillar_grey_*` sont des
            // stèles funéraires, elles peuplaient les ruines de tombes.
            let assets = ["ds_ruin_column", "column_broken_1", "ds_ruin_stone",
                          "ds_ruin_column", "column_broken_1", "ds_ruin_stone"]
            let asset = assets[i % assets.count]
            guard let texH = PixelArtSprites.pixelHeight(of: asset), texH > 0,
                  let node = PixelArtSprites.still(name: asset,
                                                   scale: (32 + ruinNext() * 22) / texH,
                                                   anchor: CGPoint(x: 0.5, y: 0.0))
            else { continue }
            node.position = CGPoint(x: pRuins.x + cos(a) * ruinsRX * ray,
                                    y: pRuins.y + sin(a) * ruinsRY * ray)
            node.zPosition = actorLayer(for: node.position.y) - 0.2
            add(node, to: scene)
        }
        plantMass([Flora(asset: "ds_grass_dry", height: 12, weight: 4),
                   Flora(asset: "rock_5", height: 10, weight: 3),
                   Flora(asset: "rock_9", height: 10, weight: 3),
                   Flora(asset: "gy_tree", height: 46, weight: 1)],
                  center: pRuins, radiusX: ruinsRX, radiusY: ruinsRY,
                  step: 44, coreDensity: 0.18, edgeDensity: 0.34,
                  avoiding: [CGRect(x: pRuins.x - 60, y: pRuins.y - 42,
                                    width: 120, height: 84)],
                  in: scene)

        // ── LE SEUIL : la garde du portail. Arbres morts en cercle, stèles et
        // cierges éteints — la frontière est TENUE, elle n'est pas qu'un décor.
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * .pi * 2 + 0.25
            if abs(sin(a)) > 0.86 { continue }        // on laisse passer au sud
            let assets = ["gy_tree", "gy_tomb_grey_1", "gy_tree",
                          "gy_cross_grey", "gy_tomb_black", "gy_candle_off"]
            let asset = assets[i % assets.count]
            let hgt: CGFloat = asset == "gy_tree" ? 52 : 30
            guard let texH = PixelArtSprites.pixelHeight(of: asset), texH > 0,
                  let node = PixelArtSprites.still(name: asset, scale: hgt / texH,
                                                   anchor: CGPoint(x: 0.5, y: 0.0))
            else { continue }
            // Teintés du violet du Vide : sortis de leur pack, ils gardaient le
            // gris d'un cimetière ordinaire au milieu d'un sol corrompu.
            node.forEachDescendantSprite { sprite in
                sprite.color = voidShade
                sprite.colorBlendFactor = 0.45
            }
            node.position = CGPoint(x: pThreshold.x + cos(a) * thrRX * 0.74,
                                    y: pThreshold.y + sin(a) * thrRY * 0.76)
            node.zPosition = actorLayer(for: node.position.y) - 0.2
            add(node, to: scene)
        }
        // ── LA FAILLE DU CŒUR DU VIDE : hors d'atteinte, mais visible depuis
        // le Seuil. Des troncs morts et rien d'autre — c'est le bout du monde.
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2 + 0.5
            // À 0,5 d'échelle ces troncs faisaient deux fois la hauteur du
            // portail et volaient la vedette au Seuil. Ils sont le FOND.
            guard let texH = PixelArtSprites.pixelHeight(of: "gy_tree"), texH > 0,
                  let node = PixelArtSprites.still(name: "gy_tree", scale: 44 / texH,
                                                   anchor: CGPoint(x: 0.5, y: 0.0))
            else { continue }
            node.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.30, green: 0.12, blue: 0.46, alpha: 1)
                sprite.colorBlendFactor = 0.80
            }
            node.position = CGPoint(x: pVoid.x + cos(a) * 150, y: pVoid.y + sin(a) * 104)
            node.zPosition = actorLayer(for: node.position.y) - 0.2
            add(node, to: scene)
        }

        // ── DÉSERT D'OSSARA : la flore, en BOSQUETS ──
        //
        // Le relief (croûte, dunes, gravier) est posé plus haut, en tuiles.
        // Ne restent ici que de vrais objets : ni `ds_cracked*` ni `ds_dune*`,
        // qui sont des tuiles de sol de 96×96 — semées en sprites, elles
        // parsemaient le sable de carrés de terre craquelée aux bords nets.
        //
        // Un désert ne sème pas sa flore uniformément : le vide domine, et la
        // vie se groupe là où il reste de l'eau. D'où une trame de fond très
        // clairsemée, puis des BOSQUETS denses posés à la main.
        let desertRX = desert.width * 0.60, desertRY = desert.height * 0.66
        let desertPOIClearing = CGRect(x: pDesert.x - 56, y: pDesert.y - 40,
                                       width: 112, height: 80)

        /// Point du désert en fractions de son rectangle — les bosquets se
        /// lisent alors sur le plan, pas en coordonnées absolues.
        func inDesert(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: desert.minX + desert.width * fx,
                    y: desert.minY + desert.height * fy)
        }

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
                  center: desertC, radiusX: desertRX, radiusY: desertRY,
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
                      center: inDesert(fx, fy),
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
                      center: inDesert(fx, fy),
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
                  center: inDesert(0.46, 0.16),
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
                  center: pDesert,
                  radiusX: 132, radiusY: 96,
                  step: 40, coreDensity: 0.34, edgeDensity: 0.42,
                  avoiding: [desertPOIClearing], in: scene)

        // ── Détail plaines : fleurs & cailloux, sobre (jamais sur l'eau) ──
        // La zone interdite couvre la LISIÈRE ARIDE, pas seulement le sable :
        // des fleurs vives sur la terre desséchée annulaient tout le dégradé
        // prairie → steppe → désert construit plus haut.
        // Idem sous le couvert et sur le parvis : ces deux lieux ont leur
        // propre flore (fougères d'ombre, offrandes blanches). Les fleurs de
        // prairie qui s'y invitaient brouillaient les deux ambiances.
        let desertKeepOut = desert.insetBy(dx: -desert.width * 0.10,
                                           dy: -desert.height * 0.10)
        let forestKeepOut = CGRect(x: forestC.x - forestRX, y: forestC.y - forestRY,
                                   width: forestRX * 2, height: forestRY * 2)
        let shrineKeepOut = CGRect(x: pShrine.x - shrineRX, y: pShrine.y - shrineRY,
                                   width: shrineRX * 2, height: shrineRY * 2)
        scatterOverworld(["village_flower_yellow", "village_flower_pink",
                          "village_flower_red", "me_flower_blue", "ext_flower_sun"],
                         count: 46, in: CGRect(x: 0, y: 0, width: w, height: h),
                         scale: 0.45,
                         avoiding: [lakeRect(lakeC, lakeRX, lakeRY), desertKeepOut,
                                    forestKeepOut, shrineKeepOut],
                         in: scene)
        // `ds_rock` a quitté cette liste : c'est un PAVAGE de 96×96 tileable,
        // pas un caillou. Semé en sprite, il posait dix-huit dalles beiges au
        // hasard sur la carte — en pleine prairie, sur les routes, dans les
        // bois. Il sert maintenant à ce pour quoi il est dessiné : le parvis.
        scatterOverworld(["rock_5", "rock_9", "rock_1", "rock_3"],
                         count: 18, in: CGRect(x: 0, y: 0, width: w, height: h),
                         scale: 0.34, avoiding: [lakeRect(lakeC, lakeRX, lakeRY)],
                         in: scene)

        // ── Lieux (POI d'entrée) — sur une clairière de terre ──
        addOverworldPlace("village",   asset: "village_house_country", scale: 0.24,
                          at: pVillage,
                          title: String(localized: "map.place.village"), in: scene)
        addOverworldPlace("forest",    asset: "tree_big", scale: 0.42,
                          at: pForest,
                          title: String(localized: "map.place.forest"), in: scene)
        addOverworldPlace("shrine",    asset: "me_statue_angel", scale: 0.4,
                          at: pShrine,
                          title: String(localized: "map.place.shrine"), in: scene)
        addOverworldPlace("ruins",     asset: "me_statue_angel", scale: 0.34,
                          at: pRuins,
                          title: String(localized: "map.place.ruins"), in: scene)
        addOverworldPlace("mines",     asset: "ds_cliff_big", scale: 0.4,
                          at: pMines,
                          title: String(localized: "map.place.mines"), in: scene)
        addOverworldPlace("desert",    asset: "ds_tent_big", scale: 0.34,
                          at: pDesert,
                          title: String(localized: "map.place.desert"), in: scene)
        addOverworldPlace("threshold", asset: "gy_gate_big", scale: 0.4,
                          at: pThreshold,
                          title: String(localized: "map.place.threshold"), in: scene)
    }

    /// Marque une ROUTE entre deux lieux dans la grille d'autotiling : un ruban
    /// de cellules de terre qui serpente doucement. Les transitions herbe/terre
    /// sont posées ensuite par `renderTileMap` — d'où le rendu net des autres
    /// zones, au lieu de plaques carrées superposées.
    /// `half` : demi-largeur du ruban. Une route de plaine s'assume large ;
    /// sous les arbres, le même gabarit ouvrait une saignée de terre nue qui
    /// annulait le couvert — le sentier forestier passe donc en étroit.
}
