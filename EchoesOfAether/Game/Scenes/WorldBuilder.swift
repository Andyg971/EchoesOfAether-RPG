import SpriteKit

/// Repères d'Ossara, en fractions de la hauteur du MONDE (pas de l'écran).
///
/// Source unique : `WorldBuilder` y pose les décors, `GameManager+Desert` y
/// teste les interactions. Les deux les écrivaient chacun de leur côté, en
/// fractions de `scene.size.height` — tant que le désert tenait sur un écran
/// les deux formules donnaient le même point, par coïncidence. Le jour où la
/// zone a scrollé, le coffre et l'oasis seraient restés joignables depuis le
/// vide, à un tiers de leur sprite.
enum DesertPOI {
    /// Sortie sud, vers la carte du monde.
    static let exitY: CGFloat = 0.04
    /// Coffre enfoui, à l'ombre du canyon (flanc ouest).
    static let chestY: CGFloat = 0.64
    /// Oasis, sur la route AVANT la cité (Andy : « beaucoup trop haut sur
    /// la map ») — une halte de caravane, pas une récompense de fond de
    /// carte.
    static let oasis = CGPoint(x: 0.24, y: 0.22)
    /// Cité des caravanes : centre de la place.
    static let town = CGPoint(x: 0.50, y: 0.46)
    /// Habitants de la cité, terrés depuis que les monstres rôdent.
    static let npcCaravanier = CGPoint(x: 0.30, y: 0.445)
    static let npcMerchant   = CGPoint(x: 0.435, y: 0.47)
    static let npcChild      = CGPoint(x: 0.545, y: 0.465)
    /// Rayon d'interaction commun aux POI de la zone.
    static let reach: CGFloat = 60
}

/// Repères des mines de Cendreval, en fractions de la hauteur du MONDE.
/// Même contrat que `DesertPOI` : `WorldBuilder` pose, `GameManager+Mines`
/// teste — une seule table pour les deux.
enum MinesPOI {
    /// Remontée vers la forêt, au sud.
    static let exitY: CGFloat = 0.04
    /// Plaque des mineurs, dans la salle effondrée.
    static let plaque = CGPoint(x: 0.16, y: 0.55)
    /// Veine d'or, au fond de la galerie est.
    static let goldVein = CGPoint(x: 0.82, y: 0.78)
    /// Rayon d'interaction commun.
    static let reach: CGFloat = 60
}

extension CGPoint {
    /// Fractions (x, y) → point monde. Évite d'écrire `w * p.x, h * p.y` des
    /// deux côtés et de se tromper de hauteur en chemin.
    func scaled(w: CGFloat, h: CGFloat) -> CGPoint {
        CGPoint(x: x * w, y: y * h)
    }
}

@MainActor
final class WorldBuilder {
    // Personnages principaux
    let kael: SKNode
    let lyra: SKNode
    /// Compagnon Eran (Actes III-IV) : marche en queue du trio, derrière
    /// l'Écho de Lyra. Masqué tant qu'Eran n'a pas rejoint le groupe.
    let eran: SKNode
    let dorin: SKNode
    // PNJ village
    let bram: SKNode
    let mara: SKNode
    let garen: SKNode
    let sage: SKNode
    let child: SKNode
    let villager: SKNode

    let worldNode = SKNode()
    // `private(set)` retiré sur ces trois-là : les zones (extensions dans
    // d'autres fichiers) les écrivent en construisant leur décor.
    var worldHeight: CGFloat = 0
    /// Largeur de la zone quand elle défile aussi horizontalement (carte du
    /// monde façon FF7). `0` = zone d'un seul écran de large (comportement
    /// par défaut de toutes les autres zones).
    var worldWidth: CGFloat = 0
    /// Empreintes au sol infranchissables (maisons, arbres, props solides).
    /// En coordonnées monde ; vidées à chaque changement de zone.
    var obstacles: [CGRect] = []

    /// Rectangles occupés VISUELLEMENT par le décor (tout le sprite, pas
    /// seulement son pied). Cf. `registerFootprint` et `isCluttered`.
    var propRects: [CGRect] = []
    var backdropNodes: [SKNode] = []
    var atmosphereNode: SKNode?
    var toyMarker: SKNode?
    var medallionMarker: SKNode?
    var oreMarker: SKNode?
    var herbMarker: SKNode?
    var badgeMarker: SKNode?
    var crystalMarker: SKNode?
    var activeInterior: HouseInteriorKind?
    /// Vrai pendant la veille du réveil : Lyra reste au chevet de Kael
    /// même si `layout()` est rejoué (rotation, resize, premier layout).
    var lyraKeepsVigil = false
    /// Vrai tant que le décor courant est le village : seul cas où
    /// `layout()` a le droit de replacer les acteurs sur son plan.
    /// Vrai tant que le décor courant est le village : `layout()` n'a le
    /// droit de replacer Kael (et les PNJ) que dans ce cas. `internal`
    /// plutôt que `private` pour que `WorldLayoutTests` puisse simuler un
    /// changement de zone (le flag est mis à false par `clearBackdrop()`).
    var villagePlanActive = false

    /// Figurants du village (`gv_*`, cf. `populateVillage`) — reconstruits à
    /// chaque entrée dans le village, et promenés comme les PNJ de quête.
    var villageFolk: [SKNode] = []

    /// Vrai jusqu'au premier `updateCamera` d'une zone : la caméra se cale
    /// d'un coup sur Kael (pas de glissement disgracieux au spawn).
    var snapCameraNextFrame = true

    /// Lieux de la carte du monde : id (pour le voyage) + position MONDE.
    var overworldPlaces: [(id: String, pos: CGPoint, title: String)] = []

    init() {
        kael    = WorldNode.kael()
        lyra    = WorldNode.lyra()
        eran    = BattleSprites.worldNode(.eran, name: "eranCompanion") ?? SKNode()
        dorin   = WorldNode.dorin()
        bram    = WorldNode.bram()
        mara    = WorldNode.mara()
        garen   = WorldNode.garen()
        sage    = WorldNode.sage()
        child   = WorldNode.child()
        villager = WorldNode.scaredVillager()
    }

    func build(in scene: SKScene) {
        worldNode.name = "worldNode"
        scene.addChild(worldNode)
        buildVillage(in: scene)
        villagePlanActive = true
        for node in [kael, lyra, eran, dorin, bram, mara, garen, sage, child, villager] {
            worldNode.addChild(node)
        }
        eran.isHidden = true   // n'apparaît qu'aux Actes III-IV (cf. showEranCompanion)
        layout(in: scene.size)
    }
}
