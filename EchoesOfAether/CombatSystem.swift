import SpriteKit

struct Combatant {
    let name: String
    let maxHP: Int
    var hp: Int
    let speed: CGFloat
    var atb: CGFloat = 0
    var baseDamage: Int = 18
    var statusEffect: StatusEffect? = nil
    var statusTicks: Int = 0
    var stunned: Bool = false

    var isAlive: Bool { hp > 0 }
}

enum CombatAction {
    case attack
    case blackSlash
}

enum StatusEffect {
    case poison        // dégâts par tick
    case aetherBurn    // poison + ralentit ATB ennemi
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

    // Sprites combattants (refonte UI : on doit voir les personnages se battre)
    private var kaelSprite: SKNode?
    private var enemySprite: SKNode?
    private var kaelHomePosition: CGPoint = .zero
    private var enemyHomePosition: CGPoint = .zero
    private var arenaFloor: SKNode?

    private var kael = Combatant(name: "Kael", maxHP: 280, hp: 280, speed: 0.35)
    private var enemy = Combatant(name: "Créature", maxHP: 160, hp: 160, speed: 0.18)
    private var resonance = 0
    private var goldReward = 0
    private var completion: ((Int, Int) -> Void)?
    private weak var parentScene: SKScene?
    private var _player: PlayerState?

    // Combo
    private var comboCount = 0
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    // Status effect label
    private let statusEffectLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

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
                enemyKind: CombatSpriteKind = .beast,
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
        self.comboCount = 0
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

        setupArenaFloor(scene: scene, isBoss: boss != nil)
        setupCombatants(scene: scene, enemyKind: enemyKind)
        setupStatus(scene: scene)
        setupHPBars(scene: scene, enemyName: enemyName)
        setupATBBars(scene: scene)
        setupButtons(scene: scene)
        if boss != nil { setupBossUI(scene: scene) }
        setupComboAndStatusUI(scene: scene)
        updateVisuals()
        playEntranceAnimation()
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

            // Appliquer poison/aetherBurn à l'ennemi
            if let status = enemy.statusEffect, enemy.statusTicks > 0 {
                let tickDmg: Int
                switch status {
                case .poison:     tickDmg = 12
                case .aetherBurn: tickDmg = 18
                }
                enemy.hp = max(0, enemy.hp - tickDmg)
                enemy.statusTicks -= 1
                if enemy.statusTicks <= 0 { enemy.statusEffect = nil }
                statusEffectLabel.text = "🟢 \(String(localized: "combat.status.poison")) -\(tickDmg)"
                if !enemy.isAlive { updateVisuals(); checkVictory(); return }
            }

            // Stun : l'ennemi perd son tour
            if enemy.stunned {
                enemy.stunned = false
                statusLabel.text = String(localized: "combat.status.stunned")
                updateVisuals()
                return
            }

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
            playEnemyAttackAnimation(isSpecial: isSpecial)
            root.addChild(ParticleFactory.impactSparks(
                at: kaelHomePosition,
                color: sparkColor,
                count: isSpecial ? 12 : 6
            ))

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
            root.addChild(ParticleFactory.blackAetherBurst(at: enemyHomePosition))
            // Pulse rapide du sprite boss pour signaler l'enrage
            enemySprite?.run(.sequence([
                .scale(to: 1.15, duration: 0.15),
                .scale(to: 1.0, duration: 0.25)
            ]))
        }

        AudioEngine.shared.playBlackSlash()
    }

    private func handleDefeat() {
        statusLabel.text = String(localized: "combat.status.defeat")
        attackButton.alpha = 0.3
        blackSlashButton.alpha = 0.3
        _player?.currentHP = 0
        playKaelDefeatAnimation()
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
        enrageLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.60)
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

        let enemyCenter = enemyHomePosition

        let atkDmg = _player?.attackDamage ?? 42
        let slashDmg = _player?.blackSlashDamage ?? 92

        switch action {
        case .attack:
            comboCount += 1
            let comboMult: Int = comboCount >= 5 ? 14 : (comboCount >= 3 ? 12 : 10)
            let finalDmg = atkDmg * comboMult / 10
            enemy.hp = max(0, enemy.hp - finalDmg)
            statusLabel.text = String(localized: "combat.status.attack \(enemy.name)")
            AudioEngine.shared.playHit()
            HapticsEngine.medium()
            JuiceEngine.screenShake(root, intensity: 5, duration: 0.2)
            playKaelAttackAnimation(strong: false)
            root.addChild(ParticleFactory.impactSparks(at: enemyCenter, color: .white, count: 8))
            showComboIfNeeded()

        case .blackSlash:
            comboCount = 0   // reset combo sur Entaille Noire
            resonance += 1
            // Stun à résonance 3 ; AetherBurn à résonance 6+
            if resonance == 3 {
                enemy.stunned = true
                statusEffectLabel.text = "🔵 \(String(localized: "combat.status.stun"))"
            } else if resonance >= 6 && enemy.statusEffect == nil {
                enemy.statusEffect = .aetherBurn
                enemy.statusTicks = 3
                statusEffectLabel.text = "🔥 \(String(localized: "combat.status.aetherBurn"))"
            }
            enemy.hp = max(0, enemy.hp - slashDmg)
            statusLabel.text = String(localized: "combat.status.blackSlash \(resonance)")
            AudioEngine.shared.playBlackSlash()
            HapticsEngine.heavy()
            JuiceEngine.screenShake(root, intensity: 12, duration: 0.35)
            JuiceEngine.slowMotion(scene: scene, duration: 0.18, factor: 0.25)
            JuiceEngine.flashOverlay(
                in: root,
                size: scene.size,
                color: SKColor(red: 0.30, green: 0.02, blue: 0.40, alpha: 1),
                duration: 0.2
            )
            playKaelAttackAnimation(strong: true)
            root.addChild(ParticleFactory.blackAetherBurst(at: enemyCenter))
        }

        updateVisuals()
        checkVictory()
    }

    private func showComboIfNeeded() {
        guard comboCount >= 3 else { return }
        let text = comboCount >= 5
            ? String(localized: "combat.combo.mega \(comboCount)")
            : String(localized: "combat.combo.hit \(comboCount)")
        comboLabel.text = text
        comboLabel.setScale(0.5)
        comboLabel.alpha = 1
        comboLabel.run(.sequence([
            .group([.scale(to: 1.3, duration: 0.15), .fadeIn(withDuration: 0.1)]),
            .scale(to: 1.0, duration: 0.1),
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.3)
        ]))
        HapticsEngine.combo()
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

        playEnemyDeathAnimation()
        if isBoss, let scene = parentScene {
            // Epic boss death: slow-mo + big burst + flash
            JuiceEngine.slowMotion(scene: scene, duration: 0.4, factor: 0.15)
            JuiceEngine.screenShake(root, intensity: 18, duration: 0.6)
            root.addChild(ParticleFactory.blackAetherBurst(at: enemyHomePosition))
            root.addChild(ParticleFactory.impactSparks(at: enemyHomePosition,
                                                       color: .white, count: 20))
            JuiceEngine.flashOverlay(in: root, size: scene.size,
                color: SKColor(red: 0.50, green: 0.25, blue: 0.80, alpha: 1),
                duration: 0.35)
        }

        // Restauration PV 100% entre combats — Kael se soigne après victoire.
        // (Tension narrative gardée via difficulté/boss, pas via attrition de PV.)
        if let p = _player {
            p.currentHP = p.currentMaxHP
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

    private func setupComboAndStatusUI(scene: SKScene) {
        // Combo label (au-dessus des sprites)
        comboLabel.fontSize = 24
        comboLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1)
        comboLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.62)
        comboLabel.zPosition = 920
        comboLabel.alpha = 0
        root.addChild(comboLabel)

        // Status effect label (sous l'ennemi)
        statusEffectLabel.fontSize = 13
        statusEffectLabel.fontColor = SKColor(red: 0.55, green: 0.90, blue: 0.55, alpha: 1)
        statusEffectLabel.position = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.32)
        statusEffectLabel.zPosition = 910
        statusEffectLabel.alpha = 0
        root.addChild(statusEffectLabel)
    }

    // MARK: - Arena visuals

    private func setupArenaFloor(scene: SKScene, isBoss: Bool) {
        let floor = SKNode()
        floor.zPosition = -5

        // Sol perspectif : ellipse sombre sous les combattants
        let floorY = scene.size.height * 0.40
        let groundEllipse = SKShapeNode(ellipseOf: CGSize(width: scene.size.width * 1.1, height: 140))
        groundEllipse.fillColor = isBoss
            ? SKColor(red: 0.10, green: 0.04, blue: 0.14, alpha: 1)
            : SKColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1)
        groundEllipse.strokeColor = isBoss
            ? SKColor(red: 0.45, green: 0.15, blue: 0.70, alpha: 0.4)
            : SKColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 0.3)
        groundEllipse.lineWidth = 2
        groundEllipse.position = CGPoint(x: scene.size.width / 2, y: floorY - 30)
        floor.addChild(groundEllipse)

        // Trait d'horizon subtil (sépare arène / fond)
        let horizon = SKShapeNode(rectOf: CGSize(width: scene.size.width, height: 1))
        horizon.fillColor = isBoss
            ? SKColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 0.25)
            : SKColor(white: 0.35, alpha: 0.2)
        horizon.strokeColor = .clear
        horizon.position = CGPoint(x: scene.size.width / 2, y: floorY + 24)
        floor.addChild(horizon)

        root.addChild(floor)
        arenaFloor = floor
    }

    private func setupCombatants(scene: SKScene, enemyKind: CombatSpriteKind) {
        let spriteY = scene.size.height * 0.42
        let kaelX = scene.size.width * 0.30
        let enemyX = scene.size.width * 0.70

        let k = CombatSprites.kael()
        k.position = CGPoint(x: kaelX, y: spriteY)
        k.zPosition = 5
        root.addChild(k)
        kaelSprite = k
        kaelHomePosition = k.position

        let e = CombatSprites.enemy(kind: enemyKind)
        // Inverser horizontalement pour qu'il regarde Kael
        e.xScale = -1
        e.position = CGPoint(x: enemyX, y: spriteY)
        e.zPosition = 5
        root.addChild(e)
        enemySprite = e
        enemyHomePosition = e.position
    }

    private func playEntranceAnimation() {
        guard let k = kaelSprite, let e = enemySprite else { return }
        k.alpha = 0
        e.alpha = 0
        let kStart = CGPoint(x: kaelHomePosition.x - 80, y: kaelHomePosition.y)
        let eStart = CGPoint(x: enemyHomePosition.x + 80, y: enemyHomePosition.y)
        k.position = kStart
        e.position = eStart
        k.run(.group([
            .fadeIn(withDuration: 0.35),
            .move(to: kaelHomePosition, duration: 0.45)
        ]))
        e.run(.sequence([
            .wait(forDuration: 0.1),
            .group([
                .fadeIn(withDuration: 0.35),
                .move(to: enemyHomePosition, duration: 0.45)
            ])
        ]))
    }

    // MARK: - Combatant animations

    private func playKaelAttackAnimation(strong: Bool = false) {
        guard let k = kaelSprite else { return }
        let dx: CGFloat = strong ? 110 : 70
        let lungeIn = SKAction.move(to: CGPoint(x: kaelHomePosition.x + dx,
                                                 y: kaelHomePosition.y),
                                    duration: 0.10)
        lungeIn.timingMode = .easeIn
        let lungeOut = SKAction.move(to: kaelHomePosition, duration: 0.18)
        lungeOut.timingMode = .easeOut
        let tilt = SKAction.sequence([
            .rotate(toAngle: -0.15, duration: 0.08, shortestUnitArc: true),
            .rotate(toAngle: 0, duration: 0.16, shortestUnitArc: true)
        ])
        k.run(.group([.sequence([lungeIn, lungeOut]), tilt]))
        playEnemyHitReact(strong: strong)
    }

    private func playEnemyHitReact(strong: Bool) {
        guard let e = enemySprite else { return }
        let dx: CGFloat = strong ? 30 : 16
        let recoil = SKAction.sequence([
            .moveBy(x: dx, y: 0, duration: 0.06),
            .moveBy(x: -dx, y: 0, duration: 0.18)
        ])
        recoil.timingMode = .easeOut
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.20)
        ])
        e.run(recoil)
        // Flash : applique aux SKSpriteNode enfants (pas les SKShape)
        e.enumerateChildNodes(withName: "//*") { node, _ in
            if let sprite = node as? SKSpriteNode { sprite.run(flash) }
        }
    }

    private func playEnemyAttackAnimation(isSpecial: Bool) {
        guard let e = enemySprite else { return }
        let dx: CGFloat = isSpecial ? -130 : -80
        let lungeIn = SKAction.move(to: CGPoint(x: enemyHomePosition.x + dx,
                                                 y: enemyHomePosition.y),
                                    duration: 0.12)
        lungeIn.timingMode = .easeIn
        let lungeOut = SKAction.move(to: enemyHomePosition, duration: 0.22)
        lungeOut.timingMode = .easeOut
        e.run(.sequence([lungeIn, lungeOut]))
        playKaelHitReact()
    }

    private func playKaelHitReact() {
        guard let k = kaelSprite else { return }
        let recoil = SKAction.sequence([
            .moveBy(x: -18, y: 0, duration: 0.06),
            .moveBy(x: 18, y: 0, duration: 0.18)
        ])
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 0.65, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.20)
        ])
        k.run(recoil)
        k.enumerateChildNodes(withName: "//*") { node, _ in
            if let sprite = node as? SKSpriteNode { sprite.run(flash) }
        }
    }

    private func playEnemyDeathAnimation() {
        guard let e = enemySprite else { return }
        e.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.6),
                .scale(to: 0.6, duration: 0.6),
                .rotate(byAngle: .pi / 6, duration: 0.6),
                .moveBy(x: 0, y: -20, duration: 0.6)
            ])
        ]))
    }

    private func playKaelDefeatAnimation() {
        guard let k = kaelSprite else { return }
        k.run(.group([
            .rotate(toAngle: -.pi / 2, duration: 0.5, shortestUnitArc: true),
            .moveBy(x: 0, y: -10, duration: 0.5),
            .fadeAlpha(to: 0.6, duration: 0.5)
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
        let barY = scene.size.height * 0.78

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
        let atbY = scene.size.height * 0.72

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
