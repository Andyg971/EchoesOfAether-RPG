import CoreHaptics
import UIKit

/// Haptic engine — CoreHaptics sur les appareils compatibles, fallback UIKit sinon.
/// Appeler `HapticsEngine.prepare()` une fois au démarrage (depuis GameScene.didMove).
@MainActor
enum HapticsEngine {

    private static var engine: CHHapticEngine?
    private static var supportsHaptics: Bool = {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }()

    // MARK: - Lifecycle

    /// Initialise le moteur CoreHaptics. À appeler une fois depuis la scene principale.
    static func prepare() {
        guard supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.resetHandler = { Task { @MainActor in HapticsEngine.restartEngine() } }
            e.stoppedHandler = { _ in Task { @MainActor in HapticsEngine.restartEngine() } }
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
    }

    private static func restartEngine() {
        try? engine?.start()
    }

    // MARK: - Public API

    /// Tap léger — UI, sélections menu
    static func light() { play(intensity: 0.38, sharpness: 0.65) }

    /// Impact moyen — attaque normale
    static func medium() { play(intensity: 0.70, sharpness: 0.50) }

    /// Impact lourd — Entaille Noire, boss, mort
    static func heavy() { play(intensity: 1.00, sharpness: 0.80) }

    /// Notification succès — victoire, quête complétée
    static func success() {
        playPattern([(0.00, 0.55, 0.30), (0.12, 1.00, 0.55)])
    }

    /// Notification erreur — défaite
    static func error() {
        playPattern([(0.00, 0.85, 0.90), (0.10, 0.85, 0.90), (0.20, 0.85, 0.90)])
    }

    /// Double impact — combo (×3 ou ×5)
    static func combo() {
        playPattern([(0.00, 0.95, 0.72), (0.08, 0.60, 0.42)])
    }

    // MARK: - Private CoreHaptics

    private static func play(intensity: Float, sharpness: Float) {
        guard supportsHaptics, let engine else {
            uiFallback(intensity: intensity)
            return
        }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return }
        try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
    }

    private static func playPattern(_ events: [(TimeInterval, Float, Float)]) {
        guard supportsHaptics, let engine else {
            uiFallback(intensity: 0.7)
            return
        }
        let hapticEvents: [CHHapticEvent] = events.map { time, intensity, sharpness in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: intensity),
                    .init(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: time
            )
        }
        guard let pattern = try? CHHapticPattern(events: hapticEvents, parameters: []) else { return }
        try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
    }

    // MARK: - UIKit Fallback

    private static func uiFallback(intensity: Float) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch intensity {
        case ..<0.45: style = .light
        case ..<0.75: style = .medium
        default:      style = .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
