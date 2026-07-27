import SpriteKit

/// Monstre baladeur : patrouille librement une zone, repère le héros à
/// proximité (« ! » d'alerte), puis le charge — le contact déclenche le
/// combat. Remplace les POI de combat statiques (halo + crâne + bouton
/// « A · Combattre ») par des rencontres vivantes, façon overworld RPG.
@MainActor
final class RoamingMonster {

    let node: SKNode
    /// Combat déclenché au contact (fourni par le GameManager).
    let startCombat: () -> Void

    private let home: CGPoint
    private let patrolRadius: CGFloat
    private let detectRadius: CGFloat
    private let contactRadius: CGFloat
    private let patrolSpeed: CGFloat
    private let chaseSpeed: CGFloat
    private let worldHeight: CGFloat

    private enum Mode { case patrol, chase }
    private var mode: Mode = .patrol
    private var wanderTarget: CGPoint
    private var wanderTimer: TimeInterval = 0
    private var triggered = false
    private var alerted = false
    /// Sursis avant que le monstre puisse repérer le héros. Évite qu'au
    /// retour d'un combat (ou à l'arrivée dans une zone) un rôdeur posé
    /// juste à côté de Kael le charge dans la seconde — enchaînement de
    /// combats dont le joueur ne peut pas sortir.
    private var graceTime: TimeInterval
    /// ZONE REFUGE (coordonnées monde) : le monstre n'y met jamais les pieds
    /// et abandonne la poursuite dès que le héros s'y abrite. C'est ce qui
    /// fait d'un village un VRAI abri et non un décor.
    private let sanctuary: CGRect?

    init(node: SKNode, home: CGPoint, worldHeight: CGFloat,
         patrolRadius: CGFloat = 70, detectRadius: CGFloat = 155,
         contactRadius: CGFloat = 44, patrolSpeed: CGFloat = 34,
         chaseSpeed: CGFloat = 104, graceTime: TimeInterval = 0,
         sanctuary: CGRect? = nil,
         startCombat: @escaping () -> Void) {
        self.sanctuary = sanctuary
        self.node = node
        self.home = home
        self.worldHeight = worldHeight
        self.patrolRadius = patrolRadius
        self.detectRadius = detectRadius
        self.contactRadius = contactRadius
        self.patrolSpeed = patrolSpeed
        self.chaseSpeed = chaseSpeed
        self.graceTime = graceTime
        self.startCombat = startCombat
        self.wanderTarget = home
        node.position = home
    }

    /// Avance le monstre d'une frame. Retourne `true` si le contact avec le
    /// héros vient de déclencher le combat (l'appelant doit alors nettoyer).
    func update(deltaTime: TimeInterval, heroPos: CGPoint) -> Bool {
        guard !triggered else { return false }
        // Le héros s'est mis à l'abri : la meute renonce et reprend sa ronde.
        if let sanctuary, sanctuary.contains(heroPos) {
            if mode == .chase {
                mode = .patrol
                alerted = false
                node.childNode(withName: "alert")?.removeFromParent()
            }
            patrol(deltaTime: deltaTime)
            return false
        }
        let dist = node.position.distance(to: heroPos)

        // Sursis : le monstre patrouille sans voir le héros (le joueur a le
        // temps de s'éloigner après un combat).
        if graceTime > 0 {
            graceTime -= deltaTime
            patrol(deltaTime: deltaTime)
            return false
        }

        switch mode {
        case .patrol:
            if dist < detectRadius {
                mode = .chase
                if !alerted { alerted = true; flashAlert() }
            } else {
                patrol(deltaTime: deltaTime)
            }

        case .chase:
            step(toward: heroPos, speed: chaseSpeed, dt: deltaTime)
            if dist < contactRadius {
                triggered = true
                startCombat()
                return true
            }
            // Le héros a semé le monstre : retour en patrouille.
            if dist > detectRadius * 1.7 {
                mode = .patrol
                alerted = false
                node.childNode(withName: "alert")?.removeFromParent()
            }
        }
        return false
    }

    /// Flânerie autour du point d'origine (mode patrouille et sursis).
    private func patrol(deltaTime: TimeInterval) {
        wanderTimer -= deltaTime
        if node.position.distance(to: wanderTarget) < 8 || wanderTimer <= 0 {
            wanderTarget = CGPoint(
                x: home.x + .random(in: -patrolRadius...patrolRadius),
                y: home.y + .random(in: -patrolRadius...patrolRadius))
            wanderTimer = .random(in: 1.5...3.5)
        }
        step(toward: wanderTarget, speed: patrolSpeed, dt: deltaTime)
    }

    private func step(toward dest: CGPoint, speed: CGFloat, dt: TimeInterval) {
        let dx = dest.x - node.position.x
        let dy = dest.y - node.position.y
        let d = max(0.001, hypot(dx, dy))
        let move = min(d, speed * CGFloat(dt))
        let next = CGPoint(x: node.position.x + dx / d * move,
                           y: node.position.y + dy / d * move)
        // Refuge : le monstre s'arrête à la lisière, il n'y entre jamais.
        if let sanctuary, sanctuary.contains(next) { return }
        node.position = next
        // Orientation : le sprite regarde vers son déplacement horizontal.
        if abs(dx) > 1,
           let sprite = node.children.compactMap({ $0 as? SKSpriteNode }).first {
            let mag = abs(sprite.xScale == 0 ? 1 : sprite.xScale)
            sprite.xScale = dx < 0 ? -mag : mag
        }
        // Tri en profondeur : MÊME échelle que les acteurs et les props
        // (cf. WorldBuilder.depthLayer). Sur son ancienne plage (20→40) le
        // monstre passait devant tous les arbres, où qu'il soit.
        let span = worldHeight > 0 ? worldHeight : 402
        node.zPosition = 40 - (node.position.y / span) * 40
    }

    /// Point d'exclamation rouge au moment du repérage (feedback d'aggro).
    private func flashAlert() {
        let bubble = SKLabelNode(fontNamed: PixelUI.uiFont)
        bubble.name = "alert"
        bubble.text = "!"
        bubble.fontSize = 24
        bubble.fontColor = SKColor(red: 1.0, green: 0.28, blue: 0.22, alpha: 1)
        bubble.verticalAlignmentMode = .bottom
        bubble.position = CGPoint(x: 0, y: 54)
        bubble.zPosition = 60
        node.addChild(bubble)
        bubble.setScale(0.4)
        bubble.run(.sequence([
            .scale(to: 1.4, duration: 0.10),
            .scale(to: 1.0, duration: 0.10),
            .wait(forDuration: 1.2),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}
