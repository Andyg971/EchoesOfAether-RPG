#if DEBUG
import SpriteKit
import os

/// Mesure du FPS SUR APPAREIL (debug uniquement, jamais compilé en Release).
///
/// `--fps-probe` : toutes les 5 s, journalise la cadence moyenne, la pire
/// image, la part d'images lentes (> 20 ms, soit une image sautée à 60 Hz)
/// et le nombre de nœuds de la scène. Lecture :
/// `xcrun devicectl device process launch --console … --fps-probe`
/// ou Console.app, sous-système `com.appmakerstudio.echoesofaether`,
/// catégorie `fps`.
///
/// `--fps-walk` : Kael marche seul (joystick virtuel qui tourne lentement)
/// pour que la caméra défile — une scène immobile ne mesure pas le pire cas.
@MainActor
final class FrameRateProbe {
    private static let log = Logger(subsystem: "com.appmakerstudio.echoesofaether",
                                    category: "fps")
    private static let window: TimeInterval = 5
    private static let slowFrame: TimeInterval = 1.0 / 50

    private let walks: Bool
    private var frames = 0
    private var slow = 0
    private var worst: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var walkClock: TimeInterval = 0

    /// `nil` sans `--fps-probe` : aucun coût hors mesure.
    init?(arguments: [String]) {
        guard arguments.contains("--fps-probe") else { return nil }
        walks = arguments.contains("--fps-walk")
    }

    /// Une image rendue. `delta` : durée depuis la précédente (secondes).
    func frame(delta: TimeInterval, scene: SKScene, manager: GameManager) {
        if walks { steer(manager, delta: delta) }
        // Les premières images d'une zone (chargement, fondu) faussent tout.
        guard delta > 0, delta < 1 else { return }
        frames += 1
        elapsed += delta
        worst = max(worst, delta)
        if delta > Self.slowFrame { slow += 1 }
        guard elapsed >= Self.window else { return }
        let fps = Double(frames) / elapsed
        let slowPct = Double(slow) / Double(frames) * 100
        let nodes = Self.count(scene)
        Self.log.notice("""
            fps=\(fps, format: .fixed(precision: 1)) \
            worstMs=\(self.worst * 1000, format: .fixed(precision: 1)) \
            slowPct=\(slowPct, format: .fixed(precision: 1)) \
            nodes=\(nodes)
            """)
        frames = 0; slow = 0; worst = 0; elapsed = 0
    }

    private func steer(_ manager: GameManager, delta: TimeInterval) {
        walkClock += delta
        let angle = walkClock * 0.35
        manager.padActive = true
        manager.padVector = CGVector(dx: cos(angle), dy: sin(angle * 0.7))
    }

    private static func count(_ node: SKNode) -> Int {
        node.children.reduce(1) { $0 + count($1) }
    }
}
#endif
