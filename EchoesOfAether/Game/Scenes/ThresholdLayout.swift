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
    var spirits: [(id: String, asset: String, pos: CGPoint)] {
        [("miner",  "npc_villager", p(0.32, 0.275)),
         ("mother", "npc_mara",     p(0.68, 0.535)),
         ("guard",  "npc_garen",    p(0.38, 0.745))]
    }

    // MARK: - Couloir

    /// Bandes du couloir : pour chaque tronçon, les x des parois gauche/droite.
    /// C'est ce profil qui donne le rythme — hall, goulot, salle, palier.
    /// `nil` = paroi ouverte (alcôve) : on ne pose rien, le joueur peut entrer.
    var corridorBands: [(y0: CGFloat, y1: CGFloat, left: CGFloat?, right: CGFloat?)] {
        [
            // Hall d'entrée, large
            (0.02, 0.17, 0.08, 0.92),
            // Alcôve gauche (stèle 1) : paroi gauche ouverte
            (0.19, 0.26, nil, 0.78),
            // Resserrement vers le goulot
            (0.28, 0.31, 0.30, 0.70),
            // GOULOT — embuscade des Ombres
            (0.32, 0.36, 0.40, 0.60),
            // Salle centrale, large
            (0.38, 0.44, 0.10, 0.90),
            // Alcôve droite (stèle 2) : paroi droite ouverte
            (0.45, 0.51, 0.22, nil),
            // Couloir vers le palier
            (0.53, 0.59, 0.26, 0.74),
            // Palier d'Eran
            (0.60, 0.66, 0.24, 0.76),
            // Alcôve gauche (stèle 3)
            (0.68, 0.74, nil, 0.72),
            // Dernière montée vers le portail
            (0.76, 0.94, 0.30, 0.70)
        ]
    }
}
