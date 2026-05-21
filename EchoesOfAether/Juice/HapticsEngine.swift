import UIKit

/// Wrapper léger autour de UIImpactFeedbackGenerator.
/// Utilisé sur tous les impacts majeurs du jeu.
@MainActor
enum HapticsEngine {

    // MARK: - Impact

    /// Tap léger — UI, sélections
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Impact moyen — attaque normale
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Impact lourd — Entaille Noire, boss enrage, mort
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Notification succès — victoire, quête complétée
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Notification erreur — défaite
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Double impact — combo
    static func combo() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            gen.impactOccurred(intensity: 0.6)
        }
    }
}
