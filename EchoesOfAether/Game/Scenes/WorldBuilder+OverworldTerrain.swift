import SpriteKit

// Carte du monde — les SOLS de l'ouest : désert d'Ossara, lac de Solis,
// pourtour du Sanctuaire, sous-bois d'Ébène. Chaque phase rend ses tuiles et
// renvoie la grille qui servira ensuite aux routes (`addOverworldRoads`).
@MainActor
extension WorldBuilder {
    /// Plaines herbeuses lumineuses (variétés mêlées) sous tout le continent.
    func addOverworldPlainsFloor(_ geo: OverworldGeometry, in scene: SKScene) {
        addTiledFloor(in: scene,
                      tileNames: ["me_grassvar_1", "me_grassvar_1", "me_grassvar_1",
                                  "me_grassvar_5", "me_grassvar_5",
                                  "me_grassvar_2", "me_grassvar_3", "me_grassvar_4"],
                      fallbackColor: SKColor(red: 0.36, green: 0.58, blue: 0.30, alpha: 1),
                      tileScale: 0.5, z: -30,
                      overrideSize: CGSize(width: geo.w + 96, height: geo.h + 96))
    }

    // MARK: - Désert d'Ossara

    /// DÉSERT D'OSSARA (sud-est) : TROIS STRATES, comme un vrai désert.
    ///
    /// Un désert ne commence pas sur un trait : la prairie s'assèche en
    /// steppe, la steppe durcit en croûte craquelée, et le sable prend le
    /// dessus au centre. Le tileset porte exactement cette lecture — les
    /// `ds_edge_*` sont des transitions SABLE↔CROÛTE, pas sable↔herbe.
    /// Posées sur l'herbe (l'ancien code), elles dessinaient un anneau de
    /// boue en escalier qui tranchait sur le vert : d'où le rendu sale.
    ///
    /// Les trois strates partagent la MÊME silhouette à des échelles
    /// décroissantes : c'est ce qui les fait lire comme un dégradé
    /// concentrique et non comme trois taches empilées.
    /// Renvoie la LISIÈRE ARIDE, dont les routes ont besoin.
    func addOverworldDesertStrata(_ geo: OverworldGeometry,
                                  in scene: SKScene) -> VillageTileMap {
        let desert = geo.desertRect
        let desertC = geo.desertCenter
        /// Silhouette du désert : le grand ovale + deux langues débordantes
        /// (bord organique, jamais un ovale nu), à l'échelle `grow`.
        func stampDesert(_ map: inout VillageTileMap, grow: CGFloat) {
            map.stampEllipse(center: desertC,
                             radiusX: desert.width * 0.66 * grow,
                             radiusY: desert.height * 0.74 * grow)
            map.stampEllipse(center: CGPoint(x: desertC.x + geo.w * 0.08,
                                             y: desertC.y + geo.h * 0.09),
                             radiusX: desert.width * 0.38 * grow,
                             radiusY: desert.height * 0.36 * grow)
            map.stampEllipse(center: CGPoint(x: desertC.x - geo.w * 0.07,
                                             y: desertC.y - geo.h * 0.08),
                             radiusX: desert.width * 0.32 * grow,
                             radiusY: desert.height * 0.30 * grow)
        }

        // Strate 1 — LISIÈRE ARIDE : terre battue autotilée sur l'herbe. Ce
        // sont les transitions des routes, déjà justes sur le vert.
        var arid = geo.emptyMap()
        stampDesert(&arid, grow: 1.12)
        renderTileMap(arid, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -29.8)

        // Strate 2 — CROÛTE CRAQUELÉE : le hardpan. Quatre variantes mêlées,
        // bord franc sur la terre battue — deux bruns voisins, la coupure ne
        // se voit pas, alors qu'elle hurlait contre l'herbe.
        var hardpan = geo.emptyMap()
        stampDesert(&hardpan, grow: 1.0)
        renderTileMap(hardpan, fullTile: "ds_cracked", edgePrefix: nil,
                      in: scene, z: -29.7,
                      variants: ["ds_cracked", "ds_cracked2",
                                 "ds_cracked3", "ds_cracked_dark"])

        // Strate 3 — LE SABLE : autotilé sur la croûte avec ses VRAIES
        // transitions. Trois variantes pour casser la trame diagonale de
        // `ds_sand`, qui se lisait en damier sur toute la largeur du désert.
        var sand = geo.emptyMap()
        stampDesert(&sand, grow: 0.84)
        renderTileMap(sand, fullTile: "ds_sand", edgePrefix: "ds_edge_",
                      in: scene, z: -29.6,
                      variants: ["ds_sand", "ds_sand2", "ds_sand3"])

        // Strate 4 — CHAMPS DE DUNES : nappes de sable ondulé là où le vent
        // travaille, au cœur. `ds_dune` est une TUILE, pas un objet : semée
        // en sprites elle posait des carrés de vagues sur le sable — c'était
        // l'artefact le plus voyant de la carte.
        var dunes = geo.emptyMap()
        for (fx, fy, fr) in [(0.38, 0.60, 0.30), (0.66, 0.34, 0.26),
                             (0.22, 0.26, 0.22), (0.80, 0.68, 0.20)] {
            dunes.stampEllipse(center: geo.inDesert(fx, fy),
                               radiusX: desert.width * fr,
                               radiusY: desert.height * fr * 0.9)
        }
        renderTileMap(dunes, fullTile: "ds_dune", edgePrefix: nil,
                      in: scene, z: -29.55, variants: ["ds_dune", "ds_dune2"])

        // Strate 5 — GRAVIER : deux reg pierreux, le contrepoint minéral du
        // sable. Ils accueillent les blocs rocheux plus bas.
        var reg = geo.emptyMap()
        for (fx, fy, fr) in [(0.14, 0.72, 0.15), (0.72, 0.14, 0.13)] {
            reg.stampEllipse(center: geo.inDesert(fx, fy),
                             radiusX: desert.width * fr,
                             radiusY: desert.height * fr * 0.9)
        }
        renderTileMap(reg, fullTile: "ds_gravel", edgePrefix: nil,
                      in: scene, z: -29.54)
        return arid
    }

    // MARK: - Lac de Solis

    /// LAC DE SOLIS (sud-ouest) : eau + berges autotilées, comme l'étang
    /// du village. L'eau ne se marche pas (obstacle enregistré).
    func addOverworldLake(_ geo: OverworldGeometry, in scene: SKScene) {
        let lakeC = geo.lakeCenter
        let lakeRX = geo.lakeRX, lakeRY = geo.lakeRY
        var lake = geo.emptyMap()
        lake.stampEllipse(center: lakeC, radiusX: lakeRX, radiusY: lakeRY)
        renderTileMap(lake, fullTile: "me_water_full", edgePrefix: "me_shore_",
                      in: scene, z: -29.5)
        registerObstacle(CGRect(x: lakeC.x - lakeRX * 0.9, y: lakeC.y - lakeRY * 0.9,
                                width: lakeRX * 1.8, height: lakeRY * 1.8))
        add(LightingEngine.waterShimmer(center: lakeC, radiusX: lakeRX, radiusY: lakeRY),
            to: scene)
    }

    // MARK: - Sanctuaire

    /// SANCTUAIRE : une clairière consacrée, pas une statue sur l'herbe.
    ///
    /// Le lieu n'avait AUCUN sol propre : l'ange était posé sur la même
    /// prairie que le reste du continent, et les trois routes qui y
    /// convergent s'y étalaient en une flaque de terre informe. Même
    /// méthode que le désert — des strates concentriques, de la prairie
    /// sauvage vers le cœur pavé. Renvoie le pourtour de terre balayée.
    func addOverworldShrineGround(_ geo: OverworldGeometry,
                                  in scene: SKScene) -> VillageTileMap {
        let pShrine = geo.shrine
        let shrineRX = geo.shrineRX, shrineRY = geo.shrineRY
        var shrineGround = geo.emptyMap()
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
        var shrinePlaza = geo.emptyMap()
        shrinePlaza.stampEllipse(center: pShrine,
                                 radiusX: shrineRX * 0.62, radiusY: shrineRY * 0.62)
        renderTileMap(shrinePlaza, fullTile: "ds_rock", edgePrefix: nil,
                      in: scene, z: -29.46)
        return shrineGround
    }

    // MARK: - Forêt d'Ébène

    /// FORÊT D'ÉBÈNE : le SOL du massif, en strates d'ombre.
    ///
    /// Le sous-bois était tuilé en `tile_grass_dark`, une planche de 16 px
    /// là où la grille d'autotiling compte 24 pt : chaque tuile ne couvrait
    /// qu'un neuvième de sa cellule. Le « couvert sombre » était donc un
    /// semis de confettis invisibles, et la forêt poussait sur la prairie
    /// vive — d'où l'impression de papier peint d'arbres.
    ///
    /// Ici l'ombre est TEINTE sur la vraie tuile d'herbe (48 px, à
    /// l'échelle). Renvoie la silhouette NETTE du massif (pour les routes).
    func addOverworldForestFloor(_ geo: OverworldGeometry,
                                 in scene: SKScene) -> VillageTileMap {
        let forestC = geo.forestCenter
        let forestRX = geo.forestRX, forestRY = geo.forestRY
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
        var forestFloor = geo.emptyMap()
        stampForest(&forestFloor, grow: 1.0)
        // La frange se compte en CELLULES, pas en pourcentage : `feather` est
        // une fraction du rayon, et le massif fait ~450 pt de demi-largeur —
        // 0,26 diluait cinq cellules de large, soit un damier de gros carrés
        // clairs en pleine forêt. Deux cellules suffisent à casser l'ovale.
        var understory = geo.emptyMap()
        stampForest(&understory, grow: 1.0, feather: geo.tile * 2 / forestRX)
        // Teinte PLATE, sans variantes ni jitter : le sous-bois est une ombre,
        // pas une matière. Toute variation de tuile à tuile se lit en damier
        // à cette échelle de caméra — le relief, ce sont les arbres.
        renderTileMap(understory, fullTile: "me_grassvar_1", edgePrefix: nil,
                      in: scene, z: -29.44, tint: geo.ebonyShade, tintBlend: 0.38)
        return forestFloor
    }
}
