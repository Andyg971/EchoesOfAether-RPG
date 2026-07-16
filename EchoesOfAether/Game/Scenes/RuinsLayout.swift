import CoreGraphics

/// Plan des Ruines de la Source (Acte II) — source unique de ses positions.
/// Même principe que `ThresholdLayout` et `VoidHeartLayout`.
///
/// Les Ruines ne sont pas un couloir mais une **enfilade de salles** : on
/// traverse le hall effondré, on force le passage gardé, on atteint la salle
/// des archives. Les inscriptions sont en retrait, jamais sur le trajet — on
/// ne les lit qu'en fouillant.
struct RuinsLayout {

    static let worldScale: CGFloat = 2.0

    let width: CGFloat
    let height: CGFloat

    init(sceneSize: CGSize) {
        width = sceneSize.width
        height = sceneSize.height * Self.worldScale
    }

    private func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: width * fx, y: height * fy)
    }

    // MARK: - Progression

    var entrance: CGPoint { p(0.50, 0.05) }
    var saveCrystal: CGPoint { p(0.78, 0.10) }
    /// Les Gardiens tiennent la porte entre le hall et la salle centrale.
    var guardiansAmbush: CGPoint { p(0.50, 0.34) }
    /// L'Archiviste garde les archives elles-mêmes.
    var archivistAmbush: CGPoint { p(0.58, 0.66) }
    /// Inscription d'Eran, à l'écart dès l'entrée.
    var eranInscription: CGPoint { p(0.13, 0.26) }
    /// Mur d'inscriptions : la découverte, au fond des archives.
    var discoveryWall: CGPoint { p(0.50, 0.90) }

    // MARK: - Salles

    /// Trois salles enfilées, séparées par des goulots. Bandes contiguës.
    var corridorBands: [(y0: CGFloat, y1: CGFloat, left: CGFloat, right: CGFloat)] {
        [
            (0.00, 0.20, 0.16, 0.86),   // hall d'entrée, effondré
            (0.20, 0.30, 0.06, 0.86),   // RENFONCEMENT GAUCHE — inscription d'Eran
            (0.30, 0.38, 0.42, 0.58),   // GOULOT — les Gardiens le tiennent
            (0.38, 0.58, 0.12, 0.88),   // salle centrale, large
            (0.58, 0.62, 0.40, 0.60),   // seconde porte
            (0.62, 0.78, 0.14, 0.86),   // salle des archives — l'Archiviste
            (0.78, 1.00, 0.26, 0.74)    // fond : le mur d'inscriptions
        ]
    }
}
