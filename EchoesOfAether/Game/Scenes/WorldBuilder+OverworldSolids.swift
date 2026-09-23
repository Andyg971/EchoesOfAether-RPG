import SpriteKit

// Carte du monde — ce qui ARRÊTE Kael : arbres, rochers, cactus, fûts.
//
// Longtemps, seul le lac bloquait : Kael traversait la Forêt d'Ébène en
// ligne droite, à travers les troncs, et gravissait les aiguilles de
// Cendreval. Désormais tout décor assez haut pour barrer le passage pose une
// empreinte au pied (on passe derrière, jamais au travers), comme dans les
// zones. Les ROUTES, les clairières des lieux, les coffres et la rive de pêche
// restent libres : aucun décor solide n'y pousse, donc chaque lieu reste
// accessible à pied quel que soit le tirage de la flore.
@MainActor
extension WorldBuilder {
    /// Hauteur à l'écran (points) à partir de laquelle un décor bloque.
    /// Sous ce seuil (fleurs, touffes, souches, crânes, cailloux) on marche
    /// dessus ; au-dessus (arbres, blocs, cactus, fûts) on le contourne.
    static let overworldSolidHeight: CGFloat = 26

    /// Demi-largeur du couloir libre de part et d'autre d'une route. Plus
    /// large que le ruban de terre : le serpentement de `stampRoad` et le
    /// pied des arbres de lisière ne doivent pas refermer le passage.
    private static let passageHalfWidth: CGFloat = 22

    /// Trace les passages avant de semer quoi que ce soit de solide.
    func prepareOverworldPassages(_ geo: OverworldGeometry) {
        var map = geo.emptyMap()
        for (a, b) in geo.roadLinks {
            stampRoad(&map, from: a, to: b, half: Self.passageHalfWidth)
        }
        for p in geo.places {
            map.stampEllipse(center: p, radiusX: 64, radiusY: 44)
            // Kael réapparaît 90 pt au sud du lieu qu'il quitte.
            map.stampEllipse(center: CGPoint(x: p.x, y: p.y - 90),
                             radiusX: 30, radiusY: 30)
        }
        for chest in Self.overworldChests {
            map.stampEllipse(center: Self.overworldChestPoint(chest.id, w: geo.w, h: geo.h),
                             radiusX: 40, radiusY: 32)
        }
        map.stampEllipse(center: Self.overworldFishingSpot(w: geo.w, h: geo.h),
                         radiusX: 40, radiusY: 32)
        overworldPassages = map
    }

    /// Ce point est-il sur un passage à garder libre ?
    func isOverworldPassage(_ p: CGPoint) -> Bool {
        overworldPassages?.contains(p) ?? false
    }

    /// Un décor de la carte de cette hauteur doit-il bloquer ?
    func isOverworldSolid(height: CGFloat) -> Bool {
        height >= Self.overworldSolidHeight
    }

    /// Empreinte d'un décor solide de la carte : le PIED seulement, mince.
    /// À l'échelle de la carte, les couverts sont serrés (pas de 32 à 46 pt) :
    /// une empreinte au ratio des zones murerait la forêt entière. On bute
    /// sur les troncs et les blocs, on se faufile entre eux.
    func registerOverworldSolid(_ node: SKNode) {
        registerFootprint(of: node, widthRatio: 0.46, depthRatio: 0.2, maxDepth: 12)
    }
}
