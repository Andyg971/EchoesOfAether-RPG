import SpriteKit

// Corruption de Kael (Acte II) : teinte progressive du sprite.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Kael Corruption (Acte II)

    /// Applique visuellement la corruption de Kael (niveau 1-3).
    /// Supprime les noeuds précédents avant d'ajouter le nouveau niveau.
    func applyKaelCorruption(level: Int) {
        // Supprimer l'ancienne corruption
        kael.children
            .filter { $0.name == "kaelCorruption" }
            .forEach { $0.removeFromParent() }

        guard level > 0 else { return }

        // Niveau 1 : aura sombre violette élargie
        let aura = PixelShape.disc(
            radius: CGFloat(34 + level * 8),
            fill: SKColor(red: 0.20, green: 0.04, blue: 0.32, alpha: CGFloat(level) * 0.05),
            stroke: SKColor(red: 0.45, green: 0.10, blue: 0.70, alpha: CGFloat(level) * 0.16),
            pixel: 4)
        aura.name = "kaelCorruption"
        aura.zPosition = -1
        kael.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.0 + CGFloat(level) * 0.08)

        // Niveau 2+ : vrilles sombres (4 tentacules)
        if level >= 2 {
            for i in 0..<4 {
                let angle = CGFloat(i) * (.pi / 2)
                let tendril = PixelShape.polyline(
                    [.zero,
                     CGPoint(x: cos(angle + 0.5) * 16, y: sin(angle + 0.5) * 16),
                     CGPoint(x: cos(angle) * 28, y: sin(angle) * 28)],
                    color: SKColor(red: 0.25, green: 0.04, blue: 0.40, alpha: 0.55),
                    pixel: 2)
                tendril.name = "kaelCorruption"
                tendril.zPosition = -1
                kael.addChild(tendril)
                JuiceEngine.pulse(tendril, scale: 1.06)
            }
        }

        // Niveau 3 : yeux rouges par-dessus les yeux violets
        if level >= 3 {
            for dx: CGFloat in [-5, 5] {
                let redEye = SKSpriteNode(
                    color: SKColor(red: 0.95, green: 0.12, blue: 0.08, alpha: 1),
                    size: CGSize(width: 3, height: 3))
                redEye.position = CGPoint(x: dx, y: 35)
                redEye.name = "kaelCorruption"
                redEye.zPosition = 3
                kael.addChild(redEye)
                JuiceEngine.pulse(redEye, scale: 1.4)
            }
        }
    }

    /// Acte II : Dorin garde personnellement la porte nord ; Garen relevé du poste.
    /// Évite le conflit de tap (Dorin/Garen étaient à <8% width l'un de l'autre).
    func repositionDorinToGate(in scene: SKScene) {
        dorin.position = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.72)
        garen.isHidden = true
    }
}
