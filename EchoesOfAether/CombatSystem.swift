import SpriteKit

struct Combatant {
    let name: String
    let maxHP: Int
    var hp: Int
    let speed: CGFloat
    var atb: CGFloat = 0
    var baseDamage: Int = 18

    var isAlive: Bool { hp > 0 }
}

enum CombatAction {
    case attack
    case blackSlash
}

struct BossConfig {
    let enrageThreshold: CGFloat   // 0.5 = 50% HP
    let enrageSpeedMult: CGFloat   // 1.5
    let enrageDamageMult: Int      // 2
    let specialAttackInterval: Int // every N enemy turns
    let specialDamage: Int
    let specialName: String        // localized
}

@MainActor
final class CombatSystem {
    private let root = SKNode()
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    // HP bars
    private let kaelHPBack = SKShapeNode()
    private let kaelHPFill = SKShapeNode()
    private let kaelHPLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let enemyHPBack = SKShapeNode()
    private let enemyHPFill = SKShapeNode()
    private let enemyHPLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    // ATB bars
    private let kaelATBBack = SKShapeNode()
    private let kaelATBFill = SKShapeNode()
    private let enemyATBBack = SKShapeNode()
    private let enemyATBFill = SKShapeNode()

    // Buttons
    private let attackButton = SKShapeNode(rectOf: CGSize(width: 150, height: 54), cornerRadius: 16)
    private let blackSlashButton = SKShapeNode(rectOf: CGSize(width: 190, height: 54), cornerRadius: 16)

    private var kael = Combatant(name: "Kael", maxHP: 280, hp: 280, speed: 0.35)
    private var enemy = Combatant(name: "Créature", maxHP: 160, hp: 160, speed: 0.18)
    private var resonance = 0
    private var goldReward = 0
    private var completion: ((Int, Int) -> Void)?
    private weak var parentScene: SKScene?
    private var _player: PlayerState?

    // Boss
    private var bossConfig: BossConfig?
    private var isEnraged = false
    private var enemyTurnCount = 0
    private let enrageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let barWidth: CGFloat = 140
    private let barHeight: CGFloat = 14
    private let atbHeight: CGFloat = 8

    var isActive: Bool { root.parent != nil }

    func attach(to scene: SKScene, enemyName: String, enemyHP: Int,
                goldReward: Int = 30, player: PlayerState,
                boss: BossConfig? = nil,
                completion: @escaping (Int, Int) -> Void) {
        parentScene = scene
        self.goldReward = goldReward
        self.bossConfig = boss
        self.isEnraged = false
        self.enemyTurnCount = 0

        let baseSpeed: CGFloat = boss != nil ? 0.25 : (enemyHP > 200 ? 0.22 : 0.18)
        let baseDmg = boss != nil ? 24 : 18
        self.enemy = Combatant(name: enemyName, maxHP: enemyHP, hp: enemyHP,
                               speed: baseSpeed, baseDamage: baseDmg)
        let startHP = min(player.currentHP, player.currentMaxHP)
        self.kael = Combatant(name: "Kael", maxHP: player.currentMaxHP, hp: startHP, speed: 0.35)
        self.kael.atb = 0
        self.enemy.atb = 0
        self.resonance = 0
        self.completion = completion
        self._player = player

        root.removeFromParent()
        root.removeAllChildren()
        root.zPosition = 900
        scene.addChild(root)

        let scrimColor = boss != nil
            ? SKColor(red: 0.04, green: 0.02, blue: 0.06, alpha: 0.92)
            : SKColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 0.88)
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = scrimColor
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        setupStatus(scene: scene)
        setupHPBars(scene: scene, enemyName: enemyName)
        setupATBBars(scene: scene)
        setupButtons(scene: scene)
        if boss != nil { setupBossUI(scene: scene) }
        updateVisuals()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive else { return }
        kael.atb = min(1, kael.atb + kael.speed * CGFloat(deltaTime))
        enemy.atb = min(1, enemy.atb + enemy.speed * CGFloat(deltaTime))

        // Check enrage threshold
        if let boss = bossConfig, !isEnraged {
            let ratio = CGFloat(enemy.hp) / CGFloat(enemy.maxHP)
            if ratio <= boss.enrageThreshold {
                triggerEnrage(boss)
            }
        }

        if enemy.atb >= 1 {
            enemy.atb = 0
            enemyTurnCount += 1

            let isSpecial = bossConfig.map { enemyTurnCount % $0.specialAttackInterval == 0 } ?? false
            let dmgMult = isEnraged ? (bossConfig?.enrageDamageMult ?? 1) : 1
            let dmg: Int
            let sparkColor: SKColor
            let shakeIntensity: CGFloat

            if isSpecial, let boss = bossConfig {
                dmg = boss.specialDamage * dmgMult
                sparkColor = SKColor(red: 0.55, green: 0.15, blue: 0.80, alpha: 1)
                shakeIntensity = 10
                statusLabel.text = boss.specialName
                if let scene = parentScene {
                    JuiceEngine.flashOverlay(in: root, size: scene.size,
                        color: SKColor(red: 0.40, green: 0.05, blue: 0.55, alpha: 1),
                        duration: 0.25)
                }
            } else {
                dmg = enemy.baseDamage * dmgMult
                sparkColor = .red
                shakeIntensity = isEnraged ? 6 : 3
                statusLabel.text = String(localized: "combat.status.enemyHit \(enemy.name) \(kael.hp - dmg > 0 ? kael.hp - dmg : 0) \(kael.maxHP)")
            }

            kael.hp = max(0, kael.hp - dmg)
            AudioEngine.shared.playDamage()
            JuiceEngine.screenShake(root, intensity: shakeIntensity, duration: 0.15)
            if let scene = parentScene {
                root.addChild(ParticleFactory.impactSparks(
                    at: CGPoint(x: scene.size.width * 0.28, y: scene.size.height * 0.55),
                    color: sparkColor,
                    count: isSpecial ? 12 : 6
                ))
            }

            if !kael.isAlive { handleDefeat(); return }
        }

        updateVisuals()
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

    // MARK: - Boss Mechanics

    private func triggerEnrage(_ boss: BossConfig) {
        isEnraged = true
        enemy.atb = 0  // reset ATB on enrage

        statusLabel.text = String(localized: "combat.boss.enrage")
        enrageLabel.alpha = 1
        enrageLabel.setScale(0.5)
        enrageLabel.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.3), .fadeIn(withDuration: 0.2)]),
            .scale(to: 1.0, duration: 0.15),
            .wait(forDuration: 1.5),
            .fadeOut(withDuration: 0.4)
        ]))

        if let scene = parentScene {
            JuiceEngine.screenShake(root, intensity: 15, duration: 0.5)
            JuiceEngine.flashOverlay(in: root, size: scene.size,
                color: SKColor(red: 0.60, green: 0.05, blue: 0.10, alpha: 1),
                duration: 0.3)
            // Boss aura particles
            let center = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.55)
            root.addChild(ParticleFactory.blackAetherBurst(at: center))
        }

        AudioEngine.shared.playBlackSlash()
    }

    private func handleDefeat() {
        statusLabel.text = String(localized: "combat.status.defeat")
        attackButton.alpha = 0.3
        blackSlashButton.alpha = 0.3
        _player?.currentHP = 0
        root.run(.sequence([
            .wait(forDuration: 1.5),
            .run { [weak self] in
                self?.root.removeFromParent()
                self?.completion?(-1, 0)   // -1 resonance = signal défaite
            }
        ]))
    }

    private func setupBossUI(scene: SKScene) {
        enrageLabel.text = String(localized: "combat.boss.enrageLabel")
        enrageLabel.fontSize = 22
        enrageLabel.fontColor = SKColor(red: 0.90, green: 0.20, blue: 0.15, alpha: 1)
        enrageLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.68)
        enrageLabel.zPosition = 950
        enrageLabel.alpha = 0
        root.addChild(enrageLabel)

        // Boss name plate
        let plate = SKShapeNode(rectOf: CGSize(width: 200, height: 28), cornerRadius: 8)
        plate.fillColor = SKColor(red: 0.12, green: 0.06, blue: 0.18, alpha: 0.8)
        plate.strokeColor = SKColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 0.6)
        plate.lineWidth = 1.5
        plate.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 48)
        plate.zPosition = 910
        root.addChild(plate)

        let bossTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bossTitle.text = "⚔ " + enemy.name + " ⚔"
        bossTitle.fontSize = 14
        bossTitle.fontColor = SKColor(red: 0.80, green: 0.55, blue: 1, alpha: 1)
        bossTitle.verticalAlignmentMode = .center
        bossTitle.position = plate.position
        bossTitle.zPosition = 911
        root.addChild(bossTitle)
    }

    // MARK: - Actions

    private func perform(_ action: CombatAction) {
        guard let scene = parentScene else { return }
        kael.atb = 0

        let enemyCenter = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.55)

        let atkDmg = _player?.attackDamage ?? 42
        let slashDmg = _player?.blackSlashDamage ?? 92

        switch action {
        case .attack:
            enemy.hp = max(0, enemy.hp - atkDmg)
            statusLabel.text = String(localized: "combat.status.attack \(enemy.name)")
            AudioEngine.shared.playHit()
            JuiceEngine.screenShake(root, intensity: 5, duration: 0.2)
            root.addChild(ParticleFactory.impactSparks(at: enemyCenter, color: .white, count: 8))

        case .blackSlash:
            resonance += 1
            enemy.hp = max(0, enemy.hp - slashDmg)
            statusLabel.text = String(localized: "combat.status.blackSlash \(resonance)")
            AudioEngine.shared.playBlackSlash()
            JuiceEngine.screenShake(root, intensity: 12, duration: 0.35)
            JuiceEngine.slowMotion(scene: scene, duration: 0.18, factor: 0.25)
            JuiceEngine.flashOverlay(
                in: root,
                size: scene.size,
                color: SKColor(red: 0.30, green: 0.02, blue: 0.40, alpha: 1),
                duration: 0.2
            )
            root.addChild(ParticleFactory.blackAetherBurst(at: enemyCenter))
        }

        updateVisuals()
        checkVictory()
    }

    private func checkVictory() {
        guard !enemy.isAlive else { return }
        let finalResonance = resonance
        let finalGold = goldReward
        let isBoss = bossConfig != nil
        statusLabel.text = String(localized: "combat.status.defeated \(enemy.name)")
        AudioEngine.shared.playVictory()
        attackButton.alpha = 0.3
        blackSlashButton.alpha = 0.3

        if isBoss, let scene = parentScene {
            // Epic boss death: slow-mo + big burst + flash
            JuiceEngine.slowMotion(scene: scene, duration: 0.4, factor: 0.15)
            JuiceEngine.screenShake(root, intensity: 18, duration: 0.6)
            let center = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.55)
            root.addChild(ParticleFactory.blackAetherBurst(at: center))
            root.addChild(ParticleFactory.impactSparks(at: center, color: .white, count: 20))
            JuiceEngine.flashOverlay(in: root, size: scene.size,
                color: SKColor(red: 0.50, green: 0.25, blue: 0.80, alpha: 1),
                duration: 0.35)
        }

        // Restore 25% HP on victory
        if let p = _player {
            let healed = max(1, p.currentMaxHP / 4)
            p.currentHP = min(p.currentMaxHP, kael.hp + healed)
        }

        let delay: TimeInterval = isBoss ? 1.8 : 0.8
        root.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                self?.root.removeFromParent()
                self?.completion?(finalResonance, finalGold)
            }
        ]))
    }

    // MARK: - Setup

    private func setupStatus(scene: SKScene) {
        statusLabel.fontSize = 17
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 72)
        root.addChild(statusLabel)
    }

    private func setupHPBars(scene: SKScene, enemyName: String) {
        let kaelX = scene.size.width * 0.28
        let enemyX = scene.size.width * 0.72
        let barY = scene.size.height * 0.58

        configureBar(kaelHPBack, kaelHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.40, green: 0.78, blue: 0.56, alpha: 1),
                     at: CGPoint(x: kaelX, y: barY))
        configureBar(enemyHPBack, enemyHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.82, green: 0.22, blue: 0.24, alpha: 1),
                     at: CGPoint(x: enemyX, y: barY))

        kaelHPLabel.fontSize = 12
        kaelHPLabel.fontColor = .white
        kaelHPLabel.position = CGPoint(x: kaelX, y: barY - 18)
        root.addChild(kaelHPLabel)

        enemyHPLabel.fontSize = 12
        enemyHPLabel.fontColor = .white
        enemyHPLabel.position = CGPoint(x: enemyX, y: barY - 18)
        root.addChild(enemyHPLabel)

        addCombatantLabel("Kael", at: CGPoint(x: kaelX, y: barY + 16))
        addCombatantLabel(enemyName, at: CGPoint(x: enemyX, y: barY + 16))
    }

    private func setupATBBars(scene: SKScene) {
        let kaelX = scene.size.width * 0.28
        let enemyX = scene.size.width * 0.72
        let atbY = scene.size.height * 0.52

        configureBar(kaelATBBack, kaelATBFill, width: barWidth, height: atbHeight,
                     color: SKColor(red: 0.52, green: 0.42, blue: 0.88, alpha: 1),
                     at: CGPoint(x: kaelX, y: atbY))
        configureBar(enemyATBBack, enemyATBFill, width: barWidth, height: atbHeight,
                     color: SKColor(red: 0.70, green: 0.30, blue: 0.30, alpha: 1),
                     at: CGPoint(x: enemyX, y: atbY))

        addSmallLabel("ATB", at: CGPoint(x: kaelX, y: atbY + 10))
        addSmallLabel("ATB", at: CGPoint(x: enemyX, y: atbY + 10))
    }

    private func setupButtons(scene: SKScene) {
        addButton(attackButton, title: String(localized: "combat.button.attack"),
                  at: CGPoint(x: scene.size.width / 2 - 90, y: 86))
        addButton(blackSlashButton, title: String(localized: "combat.button.blackSlash"),
                  at: CGPoint(x: scene.size.width / 2 + 95, y: 86))

        blackSlashButton.strokeColor = SKColor(red: 0.60, green: 0.20, blue: 0.80, alpha: 1)
    }

    // MARK: - Helpers

    private func configureBar(_ back: SKShapeNode, _ fill: SKShapeNode,
                              width: CGFloat, height: CGFloat,
                              color: SKColor, at position: CGPoint) {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)

        back.path = path
        back.fillColor = SKColor(white: 0.15, alpha: 1)
        back.strokeColor = SKColor(white: 0.3, alpha: 1)
        back.lineWidth = 1
        back.position = position
        root.addChild(back)

        fill.path = path
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.position = position
        fill.xScale = 1.0
        root.addChild(fill)
    }

    private func addCombatantLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.position = position
        root.addChild(label)
    }

    private func addSmallLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = 10
        label.fontColor = SKColor(white: 0.6, alpha: 1)
        label.position = position
        root.addChild(label)
    }

    private func addButton(_ node: SKShapeNode, title: String, at position: CGPoint) {
        node.position = position
        node.fillColor = SKColor(red: 0.14, green: 0.14, blue: 0.19, alpha: 1)
        node.strokeColor = SKColor(red: 0.5, green: 0.48, blue: 0.84, alpha: 1)
        node.lineWidth = 2

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        root.addChild(node)
    }

    private func updateVisuals() {
        let kaelHPRatio = max(0.02, CGFloat(kael.hp) / CGFloat(kael.maxHP))
        let enemyHPRatio = max(0.02, CGFloat(enemy.hp) / CGFloat(enemy.maxHP))

        kaelHPFill.xScale = kaelHPRatio
        enemyHPFill.xScale = enemyHPRatio

        kaelHPLabel.text = "\(kael.hp)/\(kael.maxHP)"
        enemyHPLabel.text = "\(enemy.hp)/\(enemy.maxHP)"

        kaelATBFill.xScale = max(0.02, kael.atb)
        enemyATBFill.xScale = max(0.02, enemy.atb)

        let ready = kael.atb >= 1
        attackButton.alpha = ready ? 1 : 0.4
        blackSlashButton.alpha = ready ? 1 : 0.4

        if statusLabel.text?.isEmpty ?? true {
            statusLabel.text = String(localized: "combat.status.charging")
        }
    }
}
