import SpriteKit

struct Combatant {
    let name: String
    let maxHP: Int
    var hp: Int
    let speed: CGFloat
    var atb: CGFloat = 0

    var isAlive: Bool { hp > 0 }
}

enum CombatAction {
    case attack
    case blackSlash
}

@MainActor
final class CombatSystem {
    private let root = SKNode()
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let kaelBar = SKShapeNode(rectOf: CGSize(width: 220, height: 12), cornerRadius: 6)
    private let enemyBar = SKShapeNode(rectOf: CGSize(width: 220, height: 12), cornerRadius: 6)
    private let attackButton = SKShapeNode(rectOf: CGSize(width: 150, height: 54), cornerRadius: 16)
    private let blackSlashButton = SKShapeNode(rectOf: CGSize(width: 190, height: 54), cornerRadius: 16)

    private var kael = Combatant(name: "Kael", maxHP: 280, hp: 280, speed: 0.35)
    private var enemy = Combatant(name: "Créature", maxHP: 160, hp: 160, speed: 0.18)
    private var resonance = 0
    private var completion: ((Int) -> Void)?

    var isActive: Bool { root.parent != nil }

    func attach(to scene: SKScene, enemyName: String, enemyHP: Int, completion: @escaping (Int) -> Void) {
        self.enemy = Combatant(name: enemyName, maxHP: enemyHP, hp: enemyHP, speed: enemyHP > 200 ? 0.22 : 0.18)
        self.kael.atb = 0
        self.enemy.atb = 0
        self.resonance = 0
        self.completion = completion

        root.removeFromParent()
        root.removeAllChildren()
        root.zPosition = 900
        scene.addChild(root)

        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 0.84)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        statusLabel.fontSize = 19
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 72)
        root.addChild(statusLabel)

        configureBar(kaelBar, color: SKColor(red: 0.40, green: 0.78, blue: 0.56, alpha: 1))
        kaelBar.position = CGPoint(x: scene.size.width * 0.28, y: scene.size.height * 0.55)
        root.addChild(kaelBar)

        configureBar(enemyBar, color: SKColor(red: 0.82, green: 0.22, blue: 0.24, alpha: 1))
        enemyBar.position = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.55)
        root.addChild(enemyBar)

        addCombatantLabel("Kael", at: CGPoint(x: scene.size.width * 0.28, y: scene.size.height * 0.61))
        addCombatantLabel(enemyName, at: CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.61))
        addButton(attackButton, title: "Attaque", at: CGPoint(x: scene.size.width / 2 - 90, y: 86), action: "attack")
        addButton(blackSlashButton, title: "Entaille noire", at: CGPoint(x: scene.size.width / 2 + 95, y: 86), action: "blackSlash")

        updateLabels()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive else { return }
        kael.atb = min(1, kael.atb + kael.speed * CGFloat(deltaTime))
        enemy.atb = min(1, enemy.atb + enemy.speed * CGFloat(deltaTime))

        if enemy.atb >= 1 {
            enemy.atb = 0
            kael.hp = max(0, kael.hp - 18)
            statusLabel.text = "\(enemy.name) frappe Kael. PV \(kael.hp)/\(kael.maxHP)"
        }

        updateButtons()
        updateLabels()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let localPoint = root.convert(point, from: scene)

        if attackButton.contains(localPoint), kael.atb >= 1 {
            perform(.attack)
            return true
        }

        if blackSlashButton.contains(localPoint), kael.atb >= 1 {
            perform(.blackSlash)
            return true
        }

        return true
    }

    private func perform(_ action: CombatAction) {
        kael.atb = 0

        switch action {
        case .attack:
            enemy.hp = max(0, enemy.hp - 42)
            statusLabel.text = "Kael attaque. \(enemy.name) vacille."

        case .blackSlash:
            resonance += 1
            enemy.hp = max(0, enemy.hp - 92)
            statusLabel.text = "Entaille noire. Résonance \(resonance)/3."
            root.run(.sequence([
                .colorize(with: SKColor(red: 0.22, green: 0.02, blue: 0.28, alpha: 1), colorBlendFactor: 0.35, duration: 0.08),
                .colorize(withColorBlendFactor: 0, duration: 0.18)
            ]))
        }

        if !enemy.isAlive {
            let finalResonance = resonance
            statusLabel.text = "\(enemy.name) vaincu."
            root.run(.sequence([.wait(forDuration: 0.65), .run { [weak self] in
                self?.root.removeFromParent()
                self?.completion?(finalResonance)
            }]))
        }
    }

    private func configureBar(_ bar: SKShapeNode, color: SKColor) {
        bar.fillColor = color
        bar.strokeColor = .white.withAlphaComponent(0.35)
        bar.lineWidth = 1
    }

    private func addCombatantLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.position = position
        root.addChild(label)
    }

    private func addButton(_ node: SKShapeNode, title: String, at position: CGPoint, action: String) {
        node.position = position
        node.fillColor = SKColor(red: 0.14, green: 0.14, blue: 0.19, alpha: 1)
        node.strokeColor = SKColor(red: 0.5, green: 0.48, blue: 0.84, alpha: 1)
        node.lineWidth = 2
        node.userData = ["action": action]

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        root.addChild(node)
    }

    private func updateButtons() {
        let ready = kael.atb >= 1
        attackButton.alpha = ready ? 1 : 0.45
        blackSlashButton.alpha = ready ? 1 : 0.45
    }

    private func updateLabels() {
        kaelBar.xScale = max(0.05, CGFloat(kael.hp) / CGFloat(kael.maxHP))
        enemyBar.xScale = max(0.05, CGFloat(enemy.hp) / CGFloat(enemy.maxHP))
        if statusLabel.text?.isEmpty ?? true {
            statusLabel.text = "ATB de Kael: \(Int(kael.atb * 100))%"
        }
    }
}
