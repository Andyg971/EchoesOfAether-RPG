import CoreGraphics

/// Plan du Seuil (Acte III) — source unique de ses positions.
///
/// Le décor, les hit-tests, les bulles d'interaction et les spawns de monstres
/// portaient chacun leur propre copie des mêmes fractions magiques : déplacer
/// un POI en désynchronisait trois autres. Tout passe désormais par ce plan.
///
/// Le Seuil n'est plus une esplanade lue d'un coup d'œil : c'est un **couloir
/// vertical** de 2,4 écrans. Kael entre au sud et remonte vers le portail au
/// nord. Le chemin se resserre en un goulot (l'embuscade des Ombres) et
/// s'ouvre sur des alcôves latérales — les stèles n'y sont qu'en récompense
/// d'un détour, jamais sur le trajet direct.
struct ThresholdLayout {

    /// Hauteur du monde en écrans. Au-delà de 1, la caméra scrolle seule
    /// (cf. WorldBuilder.updateCamera).
    static let worldScale: CGFloat = 2.4

    let width: CGFloat
    /// Hauteur MONDE (≠ hauteur écran).
    let height: CGFloat

    init(sceneSize: CGSize) {
        width = sceneSize.width
        height = sceneSize.height * Self.worldScale
    }

    private func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: width * fx, y: height * fy)
    }

    // MARK: - Progression sud → nord

    /// Entrée du Seuil : Kael arrive ici, dos au monde des vivants.
    var entrance: CGPoint { p(0.50, 0.035) }
    var saveCrystal: CGPoint { p(0.82, 0.075) }
    /// L'Écho de Lyra attend juste après l'entrée.
    var echoMeet: CGPoint { p(0.34, 0.115) }
    /// Goulot : deux colonnes se resserrent, les Ombres y tendent l'embuscade.
    var shadeAmbush: CGPoint { p(0.50, 0.335) }
    /// Eran attend sur le palier, avant la dernière montée.
    var eran: CGPoint { p(0.50, 0.615) }
    /// Pied de l'escalier du Seuil.
    var stairsBase: CGPoint { p(0.50, 0.80) }
    /// Le Seuil lui-même : combat du Gardien, puis franchissement.
    var portal: CGPoint { p(0.50, 0.90) }

    // MARK: - Détours

    /// Stèles du Vide, chacune au fond d'une alcôve (gauche, droite, gauche).
    var steles: [(id: String, pos: CGPoint)] {
        [("1", p(0.12, 0.225)),
         ("2", p(0.88, 0.475)),
         ("3", p(0.12, 0.715))]
    }

    /// Ancrages des esprits errants (ils déambulent autour).
    /// Ancrages des esprits errants (ils déambulent autour). Chacun est bien
    /// à l'intérieur de sa bande marchable, jamais collé à une paroi.
    var spirits: [(id: String, asset: String, pos: CGPoint)] {
        [("miner",  "npc_villager", p(0.42, 0.285)),
         ("mother", "npc_mara",     p(0.60, 0.545)),
         ("guard",  "npc_garen",    p(0.40, 0.720))]
    }

    // MARK: - Couloir

    /// Profil du couloir, tronçon par tronçon : `left`/`right` sont les bords
    /// de la zone **marchable**. Tout ce qui est en dehors est de la roche
    /// pleine — le chemin est creusé dedans, comme une grotte. C'est ce profil
    /// qui donne le rythme : hall, goulot, salle, palier, montée.
    ///
    /// Les tronçons sont contigus : aucun trou, sinon le joueur s'échappe par
    /// l'interstice. Une alcôve n'est pas une paroi absente — c'est la zone
    /// marchable qui s'élargit localement d'un côté.
    var corridorBands: [(y0: CGFloat, y1: CGFloat, left: CGFloat, right: CGFloat)] {
        [
            (0.00, 0.16, 0.14, 0.86),   // hall d'entrée, large
            (0.16, 0.19, 0.22, 0.72),   // on se resserre
            (0.19, 0.27, 0.06, 0.68),   // ALCÔVE GAUCHE — stèle 1
            (0.27, 0.31, 0.28, 0.68),
            (0.31, 0.38, 0.43, 0.57),   // GOULOT — embuscade des Ombres
            (0.38, 0.43, 0.20, 0.80),   // salle centrale
            (0.43, 0.52, 0.32, 0.94),   // ALCÔVE DROITE — stèle 2
            (0.52, 0.58, 0.30, 0.72),
            (0.58, 0.67, 0.22, 0.78),   // palier d'Eran
            (0.67, 0.76, 0.06, 0.70),   // ALCÔVE GAUCHE — stèle 3
            (0.76, 1.00, 0.30, 0.70)    // dernière montée vers le portail
        ]
    }
}
