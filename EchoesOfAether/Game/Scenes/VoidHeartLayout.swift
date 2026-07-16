import CoreGraphics

/// Plan du Cœur du Vide (Acte IV) — source unique de ses positions.
/// Même principe que `ThresholdLayout` : décor, hit-tests, bulles et spawns
/// lisent tous ce plan, sinon ils désynchronisent au premier déplacement.
///
/// Là où le Seuil est un couloir qui monte, le Cœur est une **descente en
/// spirale** vers la source : la sortie se referme derrière Kael (il a
/// franchi, il ne revient pas), et le chemin serpente — gauche, droite,
/// gauche — avant de déboucher sur la chambre du Cœur.
struct VoidHeartLayout {

    static let worldScale: CGFloat = 2.2

    let width: CGFloat
    let height: CGFloat

    init(sceneSize: CGSize) {
        width = sceneSize.width
        height = sceneSize.height * Self.worldScale
    }

    private func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: width * fx, y: height * fy)
    }

    // MARK: - Progression sud → nord

    /// Kael arrive du Seuil : la porte est derrière lui, close.
    var entrance: CGPoint { p(0.50, 0.04) }
    var saveCrystal: CGPoint { p(0.24, 0.09) }
    /// Les Dévoreurs d'échos gardent le premier virage.
    var devourerAmbush: CGPoint { p(0.68, 0.30) }
    /// La Voix se manifeste avant la chambre : le choix final se prend ici.
    var voiceConfront: CGPoint { p(0.50, 0.60) }
    /// Le Cœur : boss puis fin.
    var heart: CGPoint { p(0.50, 0.88) }
    var stairsBase: CGPoint { p(0.50, 0.78) }

    // MARK: - Détours

    /// Fragments de mémoire de Kael, dans les recoins du serpentin.
    var memories: [(id: String, pos: CGPoint)] {
        [("1", p(0.13, 0.20)),
         ("2", p(0.86, 0.44)),
         ("3", p(0.14, 0.68))]
    }

    /// Reflets absorbés (visages du Vide) : ancrages de déambulation.
    var reflections: [(id: String, asset: String, pos: CGPoint)] {
        [("elder", "npc_sage",     p(0.42, 0.235)),
         ("smith", "npc_garen",    p(0.58, 0.475)),
         ("lost",  "npc_villager", p(0.44, 0.700))]
    }

    // MARK: - Couloir

    /// Serpentin : le marchable se décale d'un côté puis de l'autre. Bandes
    /// contiguës — un trou entre deux, et le joueur s'échappe par la faille.
    var corridorBands: [(y0: CGFloat, y1: CGFloat, left: CGFloat, right: CGFloat)] {
        [
            (0.00, 0.14, 0.18, 0.82),   // vestibule : la porte s'est refermée
            (0.14, 0.18, 0.24, 0.92),   // le chemin part à droite
            (0.18, 0.25, 0.06, 0.92),   // RECOIN GAUCHE — mémoire 1
            (0.25, 0.34, 0.46, 0.92),   // virage droit — embuscade des Dévoreurs
            (0.34, 0.40, 0.10, 0.76),   // retour vers la gauche
            (0.40, 0.48, 0.10, 0.94),   // RECOIN DROIT — mémoire 2
            (0.48, 0.56, 0.32, 0.68),   // resserrement avant la Voix
            (0.56, 0.64, 0.24, 0.76),   // chambre de la Voix
            (0.64, 0.72, 0.06, 0.72),   // RECOIN GAUCHE — mémoire 3
            (0.72, 1.00, 0.28, 0.72)    // descente finale vers le Cœur
        ]
    }
}
