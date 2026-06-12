import SpriteKit

struct Combatant {
    let name: String
    let maxHP: Int
    var hp: Int
    var baseDamage: Int = 18
    var statusEffect: StatusEffect? = nil
    var statusTicks: Int = 0
    var stunned: Bool = false

    var isAlive: Bool { hp > 0 }
}

enum CombatAction {
    case attack
    case blackSlash
    case spell(CombatSpell)
}

enum CombatElement: Hashable {
    case physical
    case fire
    case ice
    case lightning
    case aether

    var icon: String {
        switch self {
        case .physical: return String(localized: "combat.element.physical")
        case .fire: return String(localized: "combat.element.fire")
        case .ice: return String(localized: "combat.element.ice")
        case .lightning: return String(localized: "combat.element.lightning")
        case .aether: return String(localized: "combat.element.aether")
        }
    }

    var color: SKColor {
        switch self {
        case .physical: return SKColor(white: 0.90, alpha: 1)
        case .fire: return SKColor(red: 1.00, green: 0.36, blue: 0.16, alpha: 1)
        case .ice: return SKColor(red: 0.45, green: 0.85, blue: 1.00, alpha: 1)
        case .lightning: return SKColor(red: 1.00, green: 0.82, blue: 0.22, alpha: 1)
        case .aether: return SKColor(red: 0.68, green: 0.36, blue: 1.00, alpha: 1)
        }
    }
}

enum CombatSpell: CaseIterable {
    case ember
    case frost
    case thunder
    case mend

    var title: String {
        switch self {
        case .ember: return String(localized: "combat.spell.fire")
        case .frost: return String(localized: "combat.spell.ice")
        case .thunder: return String(localized: "combat.spell.lightning")
        case .mend: return String(localized: "combat.spell.heal")
        }
    }

    var element: CombatElement? {
        switch self {
        case .ember: return .fire
        case .frost: return .ice
        case .thunder: return .lightning
        case .mend: return nil
        }
    }

    var basePower: Int {
        switch self {
        case .ember: return 66
        case .frost: return 58
        case .thunder: return 72
        case .mend: return 78
        }
    }
}

enum StatusEffect {
    case poison        // dégâts par tick
    case aetherBurn    // brûlure d'Éther : dégâts par tour, plus forts
}

struct BossConfig {
    let enrageThreshold: CGFloat   // 0.5 = 50% HP
    let enrageSpeedMult: CGFloat   // 1.5
    let enrageDamageMult: Int      // 2
    let specialAttackInterval: Int // every N enemy turns
    let specialDamage: Int
    let specialName: String        // localized
}

/// Spécification d'un ennemi à l'entrée en combat (API GameManager).
struct EnemySpec {
    let name: String
    let hp: Int
    let kind: CombatSpriteKind
    var baseDamage: Int = 18
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
    private let targetNameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    // Tour par tour
    private enum TurnPhase { case intro, playerTurn, playerActing, enemyTurn, finished }
    private enum TurnActor { case player, enemy }
    private var phase: TurnPhase = .intro
    private let turnBanner = SKShapeNode(rectOf: CGSize(width: 240, height: 30), cornerRadius: 15)
    private let turnBannerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let turnPipsRoot = SKNode()

    // Buttons
private let attackButton = SKShapeNode(rectOf: CGSize(width: 150, height: 54), cornerRadius: 16)
private let blackSlashButton = SKShapeNode(rectOf: CGSize(width: 190, height: 54), cornerRadius: 16)
private let fireButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let iceButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let lightningButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let healButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let boostButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let weaknessLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
private let boostLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
private let breakLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    // Sprites combattants (refonte UI : on doit voir les personnages se battre)
    private var kaelSprite: SKNode?
    private var kaelHomePosition: CGPoint = .zero
    private var arenaFloor: SKNode?

    /// État complet par ennemi : stats, tactique (faiblesses/bouclier)
    /// et nœuds UI (sprite, minibar HP).
    @MainActor
    private final class EnemyState {
        var combatant: Combatant
        let kind: CombatSpriteKind
        var weaknesses: Set<CombatElement>
        var shield: Int
        var shieldMax: Int
        var brokenTurns = 0
        var sprite: SKNode?
        var homePosition: CGPoint = .zero
        let hpBack = SKShapeNode()
        let hpFill = SKShapeNode()

        init(spec: EnemySpec, weaknesses: Set<CombatElement>, shieldMax: Int) {
            self.combatant = Combatant(name: spec.name, maxHP: spec.hp,
                                       hp: spec.hp, baseDamage: spec.baseDamage)
            self.kind = spec.kind
            self.weaknesses = weaknesses
            self.shield = shieldMax
            self.shieldMax = shieldMax
        }
    }

    private var kael = Combatant(name: "Kael", maxHP: 280, hp: 280)
    private var enemies: [EnemyState] = []
    private var targetIndex = 0
    private let targetMarker = SKShapeNode()
private var resonance = 0
private var playerBP = 0
private var queuedBoost = 0
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

    var isActive: Bool { root.parent != nil }

    /// Cible courante des actions du joueur.
    private var target: EnemyState? {
        enemies.indices.contains(targetIndex) ? enemies[targetIndex] : nil
    }
    private var aliveEnemies: [EnemyState] {
        enemies.filter { $0.combatant.isAlive }
    }

    /// Compatibilité : combat à un seul ennemi.
    func attach(to scene: SKScene, enemyName: String, enemyHP: Int,
                goldReward: Int = 30, player: PlayerState,
                enemyKind: CombatSpriteKind = .beast,
                boss: BossConfig? = nil,
                completion: @escaping (Int, Int) -> Void) {
        let dmg = boss != nil ? 24 : 18
        attach(to: scene,
               enemySpecs: [EnemySpec(name: enemyName, hp: enemyHP,
                                      kind: enemyKind, baseDamage: dmg)],
               goldReward: goldReward, player: player, boss: boss,
               completion: completion)
    }

    /// Combat multi-ennemis (1 à 3). Boss supporté en solo uniquement.
    func attach(to scene: SKScene, enemySpecs: [EnemySpec],
                goldReward: Int = 30, player: PlayerState,
                boss: BossConfig? = nil,
                completion: @escaping (Int, Int) -> Void) {
        parentScene = scene
        self.goldReward = goldReward
        self.bossConfig = enemySpecs.count == 1 ? boss : nil
        self.isEnraged = false
        self.enemyTurnCount = 0

        self.enemies = enemySpecs.prefix(3).map { spec in
            let tactics = Self.tactics(for: spec.kind, isBoss: boss != nil)
            return EnemyState(spec: spec, weaknesses: tactics.weaknesses,
                              shieldMax: tactics.shieldMax)
        }
        self.targetIndex = 0

let startHP = min(player.currentHP, player.currentMaxHP)
        self.kael = Combatant(name: "Kael", maxHP: player.currentMaxHP, hp: startHP)
self.resonance = 0
self.playerBP = 0
self.queuedBoost = 0
self.comboCount = 0
self.phase = .intro
        self.completion = completion
        self._player = player

        root.removeFromParent()
        root.removeAllChildren()
        statusLabel.text = ""
        statusEffectLabel.text = ""
        weaknessLabel.text = ""
        boostLabel.text = ""
        breakLabel.alpha = 0
        root.zPosition = 900
        scene.addChild(root)

        let isBoss = bossConfig != nil
        let scrimColor = isBoss
            ? SKColor(red: 0.04, green: 0.02, blue: 0.06, alpha: 0.92)
            : SKColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 0.88)
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = scrimColor
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        setupArenaFloor(scene: scene, enemyKind: enemies[0].kind, isBoss: isBoss)
        setupCombatants(scene: scene)
        setupStatus(scene: scene)
        setupHPBars(scene: scene)
        setupTurnUI(scene: scene)
        setupButtons(scene: scene)
        if isBoss { setupBossUI(scene: scene) }
        setupComboAndStatusUI(scene: scene)
        updateVisuals()
        playEntranceAnimation()

        // Premier tour après l'entrée en scène (le joueur ouvre toujours).
        root.run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.startPlayerTurn() }
        ]))
    }

    /// Faiblesses + boucliers par type d'ennemi.
    private static func tactics(for kind: CombatSpriteKind, isBoss: Bool)
        -> (weaknesses: Set<CombatElement>, shieldMax: Int) {
        let weaknesses: Set<CombatElement>
        var shieldMax: Int
        switch kind {
        case .beast:         weaknesses = [.fire, .aether];            shieldMax = 2
        case .wolf:          weaknesses = [.ice, .lightning];          shieldMax = 2
        case .guardian:      weaknesses = [.ice, .aether];             shieldMax = 3
        case .ruinsGuardian: weaknesses = [.fire, .lightning];         shieldMax = 3
        case .archivist:     weaknesses = [.ice, .lightning, .aether]; shieldMax = 4
        }
        if isBoss { shieldMax += 1 }
        return (weaknesses, shieldMax)
    }

/// Combat au tour par tour : plus aucune logique temps réel ici.
/// Les tours s'enchaînent via `startPlayerTurn`/`startEnemyTurn` et des
/// délais SKAction. La boucle de jeu continue d'appeler cette méthode.
func update(deltaTime: TimeInterval) {}

// MARK: - Boucle de tours

private func startPlayerTurn() {
    guard isActive, kael.isAlive, !aliveEnemies.isEmpty else { return }
    phase = .playerTurn
    retargetIfNeeded()
    playerBP = min(3, playerBP + 1)
    statusLabel.text = aliveEnemies.count > 1
        ? String(localized: "combat.turn.chooseMulti")
        : String(localized: "combat.turn.choose")
    showTurnBanner(String(localized: "combat.turn.player"),
                   color: SKColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 1))
    refreshTurnOrder(currentEnemyIndex: nil)
    pulseActionPanel()
    updateVisuals()
}

/// Si la cible est morte, bascule sur le premier ennemi vivant.
private func retargetIfNeeded() {
    guard target?.combatant.isAlive != true,
          let next = enemies.firstIndex(where: { $0.combatant.isAlive }) else { return }
    targetIndex = next
}

/// Phase ennemie : chaque ennemi vivant agit l'un après l'autre.
private func startEnemyTurn() {
    guard isActive, kael.isAlive, !aliveEnemies.isEmpty else { return }
    phase = .enemyTurn
    runEnemyAction(at: 0)
}

private func runEnemyAction(at index: Int) {
    guard isActive, kael.isAlive else { return }
    guard index < enemies.count else {
        scheduleNextPlayerTurn(after: 0.45)
        return
    }
    let e = enemies[index]
    guard e.combatant.isAlive else {
        runEnemyAction(at: index + 1)
        return
    }
    enemyTurnCount += 1
    showTurnBanner(String(localized: "combat.turn.enemy \(e.combatant.name)"),
                   color: SKColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1))
    refreshTurnOrder(currentEnemyIndex: index)
    updateVisuals()

    func proceed(after delay: TimeInterval) {
        root.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.runEnemyAction(at: index + 1) }
        ]))
    }

    // BREAK : tour sauté ; boucliers restaurés à la fin.
    if e.brokenTurns > 0 {
        e.brokenTurns -= 1
        statusLabel.text = String(localized: "combat.status.break \(e.combatant.name)")
        showEffect(String(localized: "combat.effect.shieldRestored"),
                   color: SKColor(red: 0.95, green: 0.75, blue: 0.30, alpha: 1))
        if e.brokenTurns == 0 { e.shield = e.shieldMax }
        updateVisuals()
        proceed(after: 0.9)
        return
    }

    // Statuts (brûlure/poison) tickent au début du tour de l'ennemi.
    if let status = e.combatant.statusEffect, e.combatant.statusTicks > 0 {
        let tickDmg: Int
        switch status {
        case .poison: tickDmg = 12
        case .aetherBurn: tickDmg = 18
        }
        e.combatant.hp = max(0, e.combatant.hp - tickDmg)
        e.combatant.statusTicks -= 1
        if e.combatant.statusTicks <= 0 { e.combatant.statusEffect = nil }
        showEffect(String(localized: "combat.effect.burn \(tickDmg)"),
                   color: SKColor(red: 0.40, green: 0.95, blue: 0.45, alpha: 1))
        showFloatingText("-" + String(tickDmg), at: e.homePosition,
                         color: SKColor(red: 0.40, green: 0.95, blue: 0.45, alpha: 1))
        if !e.combatant.isAlive {
            handleEnemyDeath(e)
            updateVisuals()
            if aliveEnemies.isEmpty { checkVictory(); return }
            proceed(after: 0.8)
            return
        }
        checkEnrage()
    }

    // Gelé/paralysé : tour sauté.
    if e.combatant.stunned {
        e.combatant.stunned = false
        statusLabel.text = String(localized: "combat.status.stunned")
        updateVisuals()
        proceed(after: 0.9)
        return
    }

    // Intention télégraphiée, puis frappe.
    statusLabel.text = String(localized: "combat.turn.intent \(e.combatant.name)")
    e.sprite?.run(.sequence([
        .scale(to: 1.06, duration: 0.18),
        .scale(to: 1.0, duration: 0.18)
    ]))
    root.run(.sequence([
        .wait(forDuration: 0.6),
        .run { [weak self] in self?.executeEnemyAttack(e) { proceed(after: 0.75) } }
    ]))
}

private func executeEnemyAttack(_ e: EnemyState, then proceed: @escaping () -> Void) {
    guard isActive, phase == .enemyTurn, kael.isAlive, e.combatant.isAlive else { return }

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
        dmg = e.combatant.baseDamage * dmgMult
        sparkColor = .red
        shakeIntensity = isEnraged ? 6 : 3
        statusLabel.text = String(localized: "combat.status.enemyHits \(e.combatant.name) \(dmg)")
    }

    kael.hp = max(0, kael.hp - dmg)
    AudioEngine.shared.playDamage()
    JuiceEngine.screenShake(root, intensity: shakeIntensity, duration: 0.15)
    playEnemyAttackAnimation(e, isSpecial: isSpecial)
    root.addChild(ParticleFactory.impactSparks(
        at: kaelHomePosition,
        color: sparkColor,
        count: isSpecial ? 12 : 6
    ))
    showFloatingText("-" + String(dmg), at: kaelHomePosition,
                     color: SKColor(red: 1.00, green: 0.40, blue: 0.35, alpha: 1))

    if !kael.isAlive { handleDefeat(); return }
    updateVisuals()
    proceed()
}

private func scheduleNextPlayerTurn(after delay: TimeInterval) {
    root.run(.sequence([
        .wait(forDuration: delay),
        .run { [weak self] in self?.startPlayerTurn() }
    ]))
}

private func checkEnrage() {
    guard let boss = bossConfig, !isEnraged, let first = enemies.first else { return }
    if CGFloat(first.combatant.hp) / CGFloat(first.combatant.maxHP) <= boss.enrageThreshold {
        triggerEnrage(boss)
    }
}

/// Mort individuelle (combat multi) : animation + retarget.
private func handleEnemyDeath(_ e: EnemyState) {
    playEnemyDeathAnimation(e)
    e.hpBack.run(.fadeOut(withDuration: 0.4))
    e.hpFill.run(.fadeOut(withDuration: 0.4))
    retargetIfNeeded()
}

func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
    guard isActive else { return false }
    let localPoint = root.convert(point, from: scene)
    let ready = phase == .playerTurn

    // Sélection de cible : toucher un ennemi vivant le cible.
    if ready, enemies.count > 1 {
        for (i, e) in enemies.enumerated()
        where e.combatant.isAlive && i != targetIndex {
            if localPoint.distance(to: e.homePosition) < 70 {
                targetIndex = i
                HapticsEngine.light()
                AudioEngine.shared.playStep()
                updateVisuals()
                return true
            }
        }
    }

    if boostButton.contains(localPoint), ready {
        applyBoost()
        return true
    }
    if attackButton.contains(localPoint), ready {
        perform(.attack)
        return true
    }
    if blackSlashButton.contains(localPoint), ready {
        perform(.blackSlash)
        return true
    }
    if fireButton.contains(localPoint), ready {
        perform(.spell(.ember))
        return true
    }
    if iceButton.contains(localPoint), ready {
        perform(.spell(.frost))
        return true
    }
    if lightningButton.contains(localPoint), ready {
        perform(.spell(.thunder))
        return true
    }
    if healButton.contains(localPoint), ready {
        perform(.spell(.mend))
        return true
    }

    return true
}

// MARK: - Boss Mechanics


    private func triggerEnrage(_ boss: BossConfig) {
        isEnraged = true
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
            // Boss aura particles + pulse du sprite (boss = ennemi unique)
            if let boss = enemies.first {
                root.addChild(ParticleFactory.blackAetherBurst(at: boss.homePosition))
                boss.sprite?.run(.sequence([
                    .scale(to: 1.15, duration: 0.15),
                    .scale(to: 1.0, duration: 0.25)
                ]))
            }
        }

        AudioEngine.shared.playBlackSlash()
    }

    private func handleDefeat() {
        phase = .finished
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
        bossTitle.text = "⚔ " + (enemies.first?.combatant.name ?? "") + " ⚔"
        bossTitle.fontSize = 14
        bossTitle.fontColor = SKColor(red: 0.80, green: 0.55, blue: 1, alpha: 1)
        bossTitle.verticalAlignmentMode = .center
        bossTitle.position = plate.position
        bossTitle.zPosition = 911
        root.addChild(bossTitle)
    }

    // MARK: - Actions

private func perform(_ action: CombatAction) {
    guard let scene = parentScene, phase == .playerTurn,
          let foe = target else { return }
    phase = .playerActing
    let boost = queuedBoost
    let damageMultiplier = 1.0 + CGFloat(boost) * 0.55
    queuedBoost = 0

    let enemyCenter = foe.homePosition
    let atkDmg = _player?.attackDamage ?? 42
    let slashDmg = _player?.blackSlashDamage ?? 92

    switch action {
    case .attack:
        comboCount += 1
        let comboMult: Int = comboCount >= 5 ? 14 : (comboCount >= 3 ? 12 : 10)
        let finalDmg = Int(CGFloat(atkDmg * comboMult / 10) * damageMultiplier)
        foe.combatant.hp = max(0, foe.combatant.hp - finalDmg)
        statusLabel.text = boost > 0
            ? String(localized: "combat.status.attackBoosted \(boost + 1) \(finalDmg)")
            : String(localized: "combat.status.attack \(foe.combatant.name)")
        AudioEngine.shared.playHit()
        HapticsEngine.medium()
        JuiceEngine.screenShake(root, intensity: boost > 0 ? 7 : 5, duration: 0.2)
        playKaelAttackAnimation(on: foe, strong: boost > 0)
        spawnSlashArc(at: enemyCenter, color: .white, strong: boost > 0)
        root.addChild(ParticleFactory.impactSparks(at: enemyCenter, color: .white, count: 8 + boost * 4))
        showFloatingText("-" + String(finalDmg), at: enemyCenter, color: .white)
        showComboIfNeeded()

    case .blackSlash:
        comboCount = 0
        resonance += 1
        let finalDmg = Int(CGFloat(slashDmg) * damageMultiplier)
        let broke = hitWeakness(on: foe, with: .aether)
        if resonance == 3 {
            foe.combatant.stunned = true
            showEffect(String(localized: "combat.effect.stun"), color: SKColor(red: 0.45, green: 0.70, blue: 1.00, alpha: 1))
        } else if broke {
            showEffect(String(localized: "combat.effect.breakAether"), color: CombatElement.aether.color)
        } else if resonance >= 6 && foe.combatant.statusEffect == nil {
            foe.combatant.statusEffect = .aetherBurn
            foe.combatant.statusTicks = 3
            showEffect(String(localized: "combat.effect.burnAether"), color: SKColor(red: 0.95, green: 0.35, blue: 1.00, alpha: 1))
        }
        foe.combatant.hp = max(0, foe.combatant.hp - finalDmg)
        statusLabel.text = boost > 0 ? String(localized: "combat.status.blackSlashBoosted \(boost + 1)") : String(localized: "combat.status.blackSlash \(resonance)")
        AudioEngine.shared.playBlackSlash()
        HapticsEngine.heavy()
        JuiceEngine.screenShake(root, intensity: 12 + CGFloat(boost) * 3, duration: 0.35)
        JuiceEngine.slowMotion(scene: scene, duration: 0.18, factor: 0.25)
        JuiceEngine.flashOverlay(
            in: root,
            size: scene.size,
            color: SKColor(red: 0.30, green: 0.02, blue: 0.40, alpha: 1),
            duration: 0.2
        )
        playKaelAttackAnimation(on: foe, strong: true)
        spawnSlashArc(at: enemyCenter, color: CombatElement.aether.color, strong: true)
        root.addChild(ParticleFactory.blackAetherBurst(at: enemyCenter))
        showFloatingText("-" + String(finalDmg), at: enemyCenter, color: CombatElement.aether.color)

    case .spell(let spell):
        comboCount = 0
        if spell == .mend {
            let heal = Int(CGFloat(spell.basePower + ((_player?.level ?? 1) - 1) * 5) * damageMultiplier)
            kael.hp = min(kael.maxHP, kael.hp + heal)
            statusLabel.text = boost > 0
                ? String(localized: "combat.status.healBoosted \(boost + 1) \(heal)")
                : String(localized: "combat.status.heal \(heal)")
            AudioEngine.shared.playHit()
            HapticsEngine.success()
            playSpellAnimation(spell, on: foe, boosted: boost > 0)
            showFloatingText("+" + String(heal), at: kaelHomePosition, color: SKColor(red: 0.45, green: 1.00, blue: 0.62, alpha: 1))
            endPlayerAction()
            return
        }

        guard let element = spell.element else { return }
        let isWeak = foe.weaknesses.contains(element)
        let broke = isWeak ? hitWeakness(on: foe, with: element) : false
        let levelBonus = ((_player?.level ?? 1) - 1) * 5
        var finalDmg = Int(CGFloat(spell.basePower + levelBonus) * damageMultiplier)
        if isWeak { finalDmg = Int(CGFloat(finalDmg) * 1.35) }
        if foe.brokenTurns > 0 || broke { finalDmg = Int(CGFloat(finalDmg) * 1.25) }
        foe.combatant.hp = max(0, foe.combatant.hp - finalDmg)
        statusLabel.text = isWeak
            ? String(localized: "combat.status.spellWeak \(spell.title) \(finalDmg)")
            : String(localized: "combat.status.spellHit \(spell.title) \(finalDmg)")
        applySpellSideEffect(spell, on: foe, wasWeak: isWeak, boosted: boost > 0)
        AudioEngine.shared.playBlackSlash()
        HapticsEngine.heavy()
        JuiceEngine.screenShake(root, intensity: isWeak ? 8 : 4, duration: 0.18)
        playSpellAnimation(spell, on: foe, boosted: boost > 0)
        showFloatingText("-" + String(finalDmg), at: enemyCenter, color: element.color)
    }

    if let foe = target, !foe.combatant.isAlive {
        handleEnemyDeath(foe)
    }
    endPlayerAction()
}

/// Clôt l'action du joueur : victoire, enrage boss, puis phase ennemie.
private func endPlayerAction() {
    updateVisuals()
    guard !aliveEnemies.isEmpty else { checkVictory(); return }
    checkEnrage()
    root.run(.sequence([
        .wait(forDuration: 0.85),
        .run { [weak self] in self?.startEnemyTurn() }
    ]))
}

/// Croissant de slash balayé sur la cible — lisibilité du coup de Kael.
private func spawnSlashArc(at point: CGPoint, color: SKColor, strong: Bool) {
    let path = CGMutablePath()
    path.addArc(center: .zero, radius: strong ? 46 : 36,
                startAngle: .pi * 0.75, endAngle: -.pi * 0.25, clockwise: true)
    let arc = SKShapeNode(path: path)
    arc.strokeColor = color
    arc.lineWidth = strong ? 7 : 5
    arc.lineCap = .round
    arc.glowWidth = strong ? 10 : 6
    arc.fillColor = .clear
    arc.position = point
    arc.zPosition = 830
    arc.alpha = 0
    root.addChild(arc)
    arc.run(.sequence([
        .group([.fadeIn(withDuration: 0.05),
                .rotate(byAngle: -.pi * 0.9, duration: 0.18)]),
        .fadeOut(withDuration: 0.12),
        .removeFromParent()
    ]))
}

private func applyBoost() {
    guard playerBP > 0, queuedBoost < 3 else { return }
    playerBP -= 1
    queuedBoost += 1
    statusLabel.text = String(localized: "combat.status.boost \(queuedBoost + 1)")
    HapticsEngine.light()
    boostButton.run(.sequence([.scale(to: 1.08, duration: 0.08), .scale(to: 1.0, duration: 0.12)]))
    updateVisuals()
}

@discardableResult
private func hitWeakness(on foe: EnemyState, with element: CombatElement) -> Bool {
    guard foe.weaknesses.contains(element), foe.brokenTurns == 0 else { return false }
    foe.shield = max(0, foe.shield - 1)
    showEffect(String(localized: "combat.effect.shieldHit \(element.icon) \(foe.shield) \(foe.shieldMax)"),
               color: element.color)
    guard foe.shield == 0 else { return false }
    foe.brokenTurns = 1
    breakLabel.text = "BREAK"
    breakLabel.alpha = 1
    breakLabel.setScale(0.6)
    breakLabel.run(.sequence([
        .group([.scale(to: 1.35, duration: 0.16), .fadeIn(withDuration: 0.08)]),
        .scale(to: 1.0, duration: 0.10),
        .wait(forDuration: 0.55),
        .fadeOut(withDuration: 0.25)
    ]))
    JuiceEngine.screenShake(root, intensity: 9, duration: 0.20)
    return true
}

private func applySpellSideEffect(_ spell: CombatSpell, on foe: EnemyState,
                                  wasWeak: Bool, boosted: Bool) {
    switch spell {
    case .ember:
        if wasWeak || boosted {
            foe.combatant.statusEffect = .aetherBurn
            foe.combatant.statusTicks = boosted ? 3 : 2
            showEffect(String(localized: "combat.effect.burnApplied"), color: CombatElement.fire.color)
        }
    case .frost:
        // Tour par tour : la glace peut geler l'ennemi (il saute son tour).
        if Double.random(in: 0...1) < (wasWeak ? 0.45 : 0.25) {
            foe.combatant.stunned = true
            showEffect(String(localized: "combat.effect.frozen"), color: CombatElement.ice.color)
        }
    case .thunder:
        // La foudre paralyse plus souvent, surtout sur faiblesse.
        if Double.random(in: 0...1) < (wasWeak ? 0.60 : 0.30) {
            foe.combatant.stunned = true
            showEffect(String(localized: "combat.effect.paralyzed"), color: CombatElement.lightning.color)
        }
    case .mend:
        break
    }
}

private func playSpellAnimation(_ spell: CombatSpell, on foe: EnemyState, boosted: Bool) {
    let target = spell == .mend ? kaelHomePosition : foe.homePosition
    let color: SKColor
    switch spell {
    case .ember: color = CombatElement.fire.color
    case .frost: color = CombatElement.ice.color
    case .thunder: color = CombatElement.lightning.color
    case .mend: color = SKColor(red: 0.45, green: 1.00, blue: 0.62, alpha: 1)
    }
    root.addChild(ParticleFactory.impactSparks(at: target, color: color, count: boosted ? 22 : 14))
    let ring = SKShapeNode(circleOfRadius: spell == .mend ? 28 : 34)
    ring.position = target
    ring.fillColor = .clear
    ring.strokeColor = color
    ring.lineWidth = boosted ? 4 : 2
    ring.glowWidth = boosted ? 8 : 4
    ring.zPosition = 825
    root.addChild(ring)
    ring.run(.sequence([
        .group([.scale(to: boosted ? 2.2 : 1.7, duration: 0.26), .fadeOut(withDuration: 0.28)]),
        .removeFromParent()
    ]))
    if spell == .mend {
        kaelSprite?.run(.sequence([.scale(to: 1.18, duration: 0.12), .scale(to: 1.10, duration: 0.18)]))
    } else {
        playEnemyHitReact(foe, strong: boosted)
    }
}

private func showFloatingText(_ text: String, at position: CGPoint, color: SKColor) {
    let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    label.text = text
    label.fontSize = 22
    label.fontColor = color
    label.position = CGPoint(x: position.x, y: position.y + 72)
    label.zPosition = 940
    root.addChild(label)
    label.run(.sequence([
        .group([.moveBy(x: 0, y: 34, duration: 0.45), .fadeOut(withDuration: 0.45)]),
        .removeFromParent()
    ]))
}

private func showEffect(_ text: String, color: SKColor) {
    statusEffectLabel.text = text
    statusEffectLabel.fontColor = color
    statusEffectLabel.alpha = 1
    statusEffectLabel.run(.sequence([.fadeIn(withDuration: 0.08), .wait(forDuration: 0.85), .fadeOut(withDuration: 0.35)]))
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
        guard aliveEnemies.isEmpty, let last = enemies.last else { return }
        phase = .finished
        let finalResonance = resonance
        let finalGold = goldReward
        let isBoss = bossConfig != nil
        statusLabel.text = String(localized: "combat.status.defeated \(last.combatant.name)")
        AudioEngine.shared.playVictory()
        attackButton.alpha = 0.3
        blackSlashButton.alpha = 0.3

        enemies.filter { $0.sprite?.alpha ?? 0 > 0 }.forEach { playEnemyDeathAnimation($0) }
        if isBoss, let scene = parentScene, let boss = enemies.first {
            // Epic boss death: slow-mo + big burst + flash
            JuiceEngine.slowMotion(scene: scene, duration: 0.4, factor: 0.15)
            JuiceEngine.screenShake(root, intensity: 18, duration: 0.6)
            root.addChild(ParticleFactory.blackAetherBurst(at: boss.homePosition))
            root.addChild(ParticleFactory.impactSparks(at: boss.homePosition,
                                                       color: .white, count: 20))
            JuiceEngine.flashOverlay(in: root, size: scene.size,
                color: SKColor(red: 0.50, green: 0.25, blue: 0.80, alpha: 1),
                duration: 0.35)
        }

        // Restauration PV 100% entre combats — Kael se soigne après victoire.
        // (Tension narrative gardée via difficulté/boss, pas via attrition de PV.)
        // XP : combat normal = Σ maxHP/3, boss = maxHP × 1.5.
        if let p = _player {
            p.currentHP = p.currentMaxHP
            let totalHP = enemies.reduce(0) { $0 + $1.combatant.maxHP }
            let xpReward = isBoss ? Int(Double(totalHP) * 1.5) : totalHP / 3
            p.gainXP(xpReward)
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
    comboLabel.fontSize = 24
    comboLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1)
    comboLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.56)
    comboLabel.zPosition = 920
    comboLabel.alpha = 0
    root.addChild(comboLabel)

    statusEffectLabel.fontSize = 13
    statusEffectLabel.fontColor = SKColor(red: 0.55, green: 0.90, blue: 0.55, alpha: 1)
    statusEffectLabel.position = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.32)
    statusEffectLabel.zPosition = 930
    statusEffectLabel.alpha = 0
    root.addChild(statusEffectLabel)

    weaknessLabel.fontSize = 12
    weaknessLabel.fontColor = SKColor(red: 0.94, green: 0.86, blue: 0.62, alpha: 1)
    weaknessLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.695)
    weaknessLabel.zPosition = 920
    root.addChild(weaknessLabel)

    boostLabel.fontSize = 13
    boostLabel.fontColor = SKColor(red: 0.72, green: 0.62, blue: 1.00, alpha: 1)
    boostLabel.position = CGPoint(x: scene.size.width / 2, y: 220)
    boostLabel.zPosition = 920
    root.addChild(boostLabel)

    breakLabel.fontSize = 34
    breakLabel.fontColor = SKColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1)
    breakLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.56)
    breakLabel.zPosition = 950
    breakLabel.alpha = 0
    root.addChild(breakLabel)
}

    // MARK: - Arena visuals

    private func setupArenaFloor(scene: SKScene, enemyKind: CombatSpriteKind, isBoss: Bool) {
        let floor = SKNode()
        floor.zPosition = -5

        let size = scene.size
        let palette = arenaPalette(for: enemyKind, isBoss: isBoss)
        let floorY = size.height * 0.40

        // Ciel/voûte : bande pleine en haut, teinte de zone
        let sky = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.55))
        sky.fillColor = palette.skyColor
        sky.strokeColor = .clear
        sky.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        floor.addChild(sky)

        // Halo central — concentre le regard sur les combattants
        let halo = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.4, height: 360))
        halo.fillColor = palette.haloColor
        halo.strokeColor = .clear
        halo.position = CGPoint(x: size.width / 2, y: floorY + 20)
        halo.alpha = 0.55
        floor.addChild(halo)

        // Décor d'arrière-plan : silhouettes selon la zone
        addBackgroundDecor(to: floor, size: size, kind: enemyKind, palette: palette)

        // Ligne d'horizon : trait fin lumineux
        let horizon = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
        horizon.fillColor = palette.horizonColor
        horizon.strokeColor = .clear
        horizon.position = CGPoint(x: size.width / 2, y: floorY + 30)
        floor.addChild(horizon)

        // Plateforme circulaire : ombre principale + bord lumineux
        let stageOuter = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.15, height: 150))
        stageOuter.fillColor = palette.stageEdgeColor
        stageOuter.strokeColor = .clear
        stageOuter.position = CGPoint(x: size.width / 2, y: floorY - 32)
        floor.addChild(stageOuter)

        let stage = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.05, height: 130))
        stage.fillColor = palette.stageColor
        stage.strokeColor = palette.stageStrokeColor
        stage.lineWidth = 2
        stage.position = CGPoint(x: size.width / 2, y: floorY - 28)
        floor.addChild(stage)

        // Runes subtiles au sol (boss only)
        if isBoss {
            for dx: CGFloat in [-90, 0, 90] {
                let rune = SKShapeNode(circleOfRadius: 3)
                rune.fillColor = SKColor(red: 0.85, green: 0.50, blue: 1, alpha: 0.7)
                rune.strokeColor = .clear
                rune.glowWidth = 4
                rune.position = CGPoint(x: size.width / 2 + dx, y: floorY - 48)
                floor.addChild(rune)
                JuiceEngine.pulse(rune, scale: 1.4)
            }
        }

        root.addChild(floor)
        arenaFloor = floor
    }

    private struct ArenaPalette {
        let skyColor: SKColor
        let haloColor: SKColor
        let horizonColor: SKColor
        let stageColor: SKColor
        let stageEdgeColor: SKColor
        let stageStrokeColor: SKColor
        let decorColor: SKColor
    }

    private func arenaPalette(for kind: CombatSpriteKind, isBoss: Bool) -> ArenaPalette {
        switch kind {
        case .beast, .wolf:
            // Forêt d'Ébène : verts très sombres
            return ArenaPalette(
                skyColor: SKColor(red: 0.05, green: 0.09, blue: 0.07, alpha: 1),
                haloColor: SKColor(red: 0.18, green: 0.30, blue: 0.22, alpha: 0.35),
                horizonColor: SKColor(red: 0.30, green: 0.55, blue: 0.38, alpha: 0.4),
                stageColor: SKColor(red: 0.07, green: 0.10, blue: 0.08, alpha: 1),
                stageEdgeColor: SKColor(red: 0.03, green: 0.05, blue: 0.04, alpha: 1),
                stageStrokeColor: SKColor(red: 0.25, green: 0.45, blue: 0.30, alpha: 0.5),
                decorColor: SKColor(red: 0.04, green: 0.08, blue: 0.05, alpha: 1)
            )
        case .guardian:
            // Sanctuaire de l'Aether : violets profonds
            return ArenaPalette(
                skyColor: SKColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 1),
                haloColor: SKColor(red: 0.40, green: 0.18, blue: 0.65, alpha: 0.45),
                horizonColor: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.55),
                stageColor: SKColor(red: 0.10, green: 0.06, blue: 0.16, alpha: 1),
                stageEdgeColor: SKColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 1),
                stageStrokeColor: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.6),
                decorColor: SKColor(red: 0.08, green: 0.05, blue: 0.14, alpha: 1)
            )
        case .ruinsGuardian, .archivist:
            // Ruines de la Source : marron-rouge délavé
            let bossBoost: CGFloat = isBoss ? 1.2 : 1.0
            return ArenaPalette(
                skyColor: SKColor(red: 0.08 * bossBoost, green: 0.04, blue: 0.05, alpha: 1),
                haloColor: SKColor(red: 0.45, green: 0.18, blue: 0.15, alpha: 0.4),
                horizonColor: SKColor(red: 0.80, green: 0.35, blue: 0.20, alpha: 0.45),
                stageColor: SKColor(red: 0.10, green: 0.06, blue: 0.05, alpha: 1),
                stageEdgeColor: SKColor(red: 0.04, green: 0.02, blue: 0.02, alpha: 1),
                stageStrokeColor: SKColor(red: 0.60, green: 0.28, blue: 0.18, alpha: 0.55),
                decorColor: SKColor(red: 0.10, green: 0.06, blue: 0.05, alpha: 1)
            )
        }
    }

    /// Silhouettes d'arrière-plan adaptées à la zone. Tente d'abord les
    /// sprites pixel art importés depuis `Assets.xcassets` (Modern Exteriors) ;
    /// fallback automatique sur les shapes programmatiques si l'asset manque.
    private func addBackgroundDecor(to floor: SKNode, size: CGSize,
                                     kind: CombatSpriteKind, palette: ArenaPalette) {
        let baseY = size.height * 0.48
        let decorColor = palette.decorColor
        let edgeColor = palette.stageStrokeColor.withAlphaComponent(0.25)

        switch kind {
        case .beast, .wolf:
            // Forêt : 6 arbres répartis en profondeur (mix tree_medium_1/2/3/big)
            let treeAssets = ["tree_medium_1", "tree_medium_2", "tree_medium_3",
                               "tree_big", "tree_medium_1", "tree_medium_2"]
            let positions: [(x: CGFloat, h: CGFloat, scale: CGFloat)] = [
                (0.08, 130, 0.9), (0.22, 95, 0.7), (0.40, 150, 1.0),
                (0.60, 105, 0.8), (0.78, 140, 0.95), (0.92, 100, 0.75)
            ]
            for (i, p) in positions.enumerated() {
                let pos = CGPoint(x: size.width * p.x, y: baseY)
                let node = decorSprite(name: treeAssets[i], pixelScale: p.scale * 3.5)
                    ?? makeTreeSilhouette(height: p.h, color: decorColor, edge: edgeColor)
                node.position = pos
                if PixelArtSprites.exists(treeAssets[i]) == false {
                    node.setScale(p.scale)
                }
                node.alpha = 0.85
                floor.addChild(node)
            }
        case .guardian:
            // Sanctuaire : 4 piliers (marble tombstone → pilier pierre)
            let assets = ["pillar_grey_1", "pillar_grey_2", "pillar_grey_1", "pillar_grey_2"]
            for (i, x) in [CGFloat(0.12), 0.32, 0.68, 0.88].enumerated() {
                let pos = CGPoint(x: size.width * x, y: baseY - 30)
                let node = decorSprite(name: assets[i], pixelScale: 4.0)
                    ?? makePillarSilhouette(height: 200, color: decorColor, edge: edgeColor)
                node.position = pos
                node.alpha = 0.9
                floor.addChild(node)
            }
        case .ruinsGuardian, .archivist:
            // Ruines : colonnes brisées + ossements épars
            let columnSpecs: [(x: CGFloat, h: CGFloat)] = [(0.12, 130), (0.50, 90), (0.86, 160)]
            for c in columnSpecs {
                let pos = CGPoint(x: size.width * c.x, y: baseY - 20)
                let node = decorSprite(name: "column_broken_1", pixelScale: 4.0)
                    ?? makeBrokenColumn(height: c.h, color: decorColor, edge: edgeColor)
                node.position = pos
                node.alpha = 0.9
                floor.addChild(node)
            }
            if let bones = decorSprite(name: "bones_1", pixelScale: 2.5) {
                bones.position = CGPoint(x: size.width * 0.30, y: baseY - 70)
                bones.alpha = 0.85
                floor.addChild(bones)
            }
        }
    }

    /// Charge un sprite pixel art comme décor avec ancre centrée bas.
    /// Le facteur `pixelScale` upscale les pixels 16×16 vers une taille
    /// lisible à l'écran (×3.5 = ~56pt, équivalent silhouette précédente).
    private func decorSprite(name: String, pixelScale: CGFloat) -> SKNode? {
        PixelArtSprites.still(name: name, scale: pixelScale,
                              anchor: CGPoint(x: 0.5, y: 0))
    }

    private func makeTreeSilhouette(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        // Tronc
        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = color
        trunk.strokeColor = edge
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: height * 0.2)
        node.addChild(trunk)
        // Couronne triangulaire
        let crown = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -28, y: 0))
        p.addLine(to: CGPoint(x: 28, y: 0))
        p.addLine(to: CGPoint(x: 0, y: height * 0.85))
        p.closeSubpath()
        crown.path = p
        crown.fillColor = color
        crown.strokeColor = edge
        crown.lineWidth = 1
        crown.position = CGPoint(x: 0, y: height * 0.25)
        node.addChild(crown)
        return node
    }

    private func makePillarSilhouette(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 22, height: height), cornerRadius: 2)
        shaft.fillColor = color
        shaft.strokeColor = edge
        shaft.lineWidth = 1
        node.addChild(shaft)
        // Chapiteau
        let cap = SKShapeNode(rectOf: CGSize(width: 32, height: 10), cornerRadius: 1)
        cap.fillColor = color
        cap.strokeColor = edge
        cap.position = CGPoint(x: 0, y: height / 2 + 4)
        node.addChild(cap)
        // Base
        let base = SKShapeNode(rectOf: CGSize(width: 30, height: 8), cornerRadius: 1)
        base.fillColor = color
        base.strokeColor = edge
        base.position = CGPoint(x: 0, y: -height / 2 - 2)
        node.addChild(base)
        return node
    }

    private func makeBrokenColumn(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 26, height: height), cornerRadius: 1)
        shaft.fillColor = color
        shaft.strokeColor = edge
        shaft.lineWidth = 1
        node.addChild(shaft)
        // Sommet brisé : triangle inversé
        let top = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -13, y: height / 2))
        p.addLine(to: CGPoint(x: 13, y: height / 2))
        p.addLine(to: CGPoint(x: -5, y: height / 2 + 12))
        p.closeSubpath()
        top.path = p
        top.fillColor = color
        top.strokeColor = edge
        node.addChild(top)
        // Base trapézoïdale
        let base = SKShapeNode(rectOf: CGSize(width: 34, height: 10), cornerRadius: 1)
        base.fillColor = color
        base.strokeColor = edge
        base.position = CGPoint(x: 0, y: -height / 2 - 4)
        node.addChild(base)
        return node
    }

    private func setupCombatants(scene: SKScene) {
        // Perspective 3/4 à la Octopath : Kael au premier plan (bas-gauche),
        // ennemis étagés à droite (formation selon leur nombre).
        let k = CombatSprites.kael()
        k.position = CGPoint(x: scene.size.width * 0.25, y: scene.size.height * 0.36)
        k.setScale(1.10)
        k.zPosition = 6
        root.addChild(k)
        kaelSprite = k
        kaelHomePosition = k.position

        let formations: [[(x: CGFloat, y: CGFloat)]] = [
            [(0.74, 0.46)],
            [(0.68, 0.40), (0.81, 0.52)],
            [(0.65, 0.36), (0.76, 0.46), (0.86, 0.56)]
        ]
        let slots = formations[min(enemies.count, 3) - 1]
        let scale: CGFloat = enemies.count == 1 ? 0.90 : 0.78

        for (i, e) in enemies.enumerated() {
            let node = CombatSprites.enemy(kind: e.kind)
            // xScale négatif : l'ennemi regarde Kael.
            node.xScale = -scale
            node.yScale = scale
            node.position = CGPoint(x: scene.size.width * slots[i].x,
                                    y: scene.size.height * slots[i].y)
            // Plus bas à l'écran = plus proche = devant
            node.zPosition = 5 - CGFloat(i) * 0.1 + (0.5 - slots[i].y)
            root.addChild(node)
            e.sprite = node
            e.homePosition = node.position
        }
    }

    private func playEntranceAnimation() {
        guard let k = kaelSprite else { return }
        k.alpha = 0
        k.position = CGPoint(x: kaelHomePosition.x - 80, y: kaelHomePosition.y)
        k.run(.group([
            .fadeIn(withDuration: 0.35),
            .move(to: kaelHomePosition, duration: 0.45)
        ]))
        for (i, e) in enemies.enumerated() {
            guard let node = e.sprite else { continue }
            node.alpha = 0
            node.position = CGPoint(x: e.homePosition.x + 80, y: e.homePosition.y)
            node.run(.sequence([
                .wait(forDuration: 0.1 + Double(i) * 0.12),
                .group([
                    .fadeIn(withDuration: 0.35),
                    .move(to: e.homePosition, duration: 0.45)
                ])
            ]))
        }
    }

    // MARK: - Combatant animations

    private func playKaelAttackAnimation(on foe: EnemyState, strong: Bool = false) {
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
        playEnemyHitReact(foe, strong: strong)
    }

    private func playEnemyHitReact(_ foe: EnemyState, strong: Bool) {
        guard let e = foe.sprite else { return }
        let dx: CGFloat = strong ? 30 : 16
        let recoil = SKAction.sequence([
            .moveBy(x: dx, y: 0, duration: 0.06),
            .moveBy(x: -dx, y: 0, duration: 0.18)
        ])
        recoil.timingMode = .easeOut
        e.run(recoil)
        // Flash : applique aux SKSpriteNode enfants (pas les SKShape),
        // en restaurant la teinte d'origine (loup d'ombre = teinté).
        e.enumerateChildNodes(withName: "//*") { node, _ in
            guard let sprite = node as? SKSpriteNode else { return }
            let prevColor = sprite.color
            let prevFactor = sprite.colorBlendFactor
            sprite.run(.sequence([
                .colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
                .colorize(with: prevColor, colorBlendFactor: prevFactor, duration: 0.20)
            ]))
        }
    }

    private func playEnemyAttackAnimation(_ foe: EnemyState, isSpecial: Bool) {
        guard let e = foe.sprite else { return }
        CombatSprites.playAttackFrames(on: e, kind: foe.kind)
        let dx: CGFloat = isSpecial ? -130 : -80
        let lungeIn = SKAction.move(to: CGPoint(x: foe.homePosition.x + dx,
                                                 y: foe.homePosition.y),
                                    duration: 0.12)
        lungeIn.timingMode = .easeIn
        let lungeOut = SKAction.move(to: foe.homePosition, duration: 0.22)
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

    private func playEnemyDeathAnimation(_ foe: EnemyState) {
        guard let e = foe.sprite else { return }
        root.addChild(ParticleFactory.impactSparks(at: foe.homePosition,
                                                   color: SKColor(white: 0.9, alpha: 1),
                                                   count: 10))
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
        // Ligne de log dédiée au-dessus de l'arène : jamais en collision
        // avec les plaques de nom (h-72 chevauchait sur grands iPhone).
        statusLabel.fontSize = 13
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.645)
        root.addChild(statusLabel)
    }

    private func setupHPBars(scene: SKScene) {
        let kaelX = scene.size.width * 0.28
        let enemyX = scene.size.width * 0.72
        let barY = scene.size.height * 0.78

        configureBar(kaelHPBack, kaelHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.40, green: 0.78, blue: 0.56, alpha: 1),
                     at: CGPoint(x: kaelX, y: barY))
        // Plate de droite = CIBLE courante (nom + HP mis à jour au retarget)
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
        targetNameLabel.fontSize = 16
        targetNameLabel.fontColor = .white
        targetNameLabel.position = CGPoint(x: enemyX, y: barY + 16)
        root.addChild(targetNameLabel)

        // Minibars HP sous chaque ennemi (lisibilité multi-cibles)
        if enemies.count > 1 {
            for e in enemies {
                configureBar(e.hpBack, e.hpFill, width: 64, height: 7,
                             color: SKColor(red: 0.85, green: 0.30, blue: 0.30, alpha: 1),
                             at: CGPoint(x: e.homePosition.x, y: e.homePosition.y - 46))
            }
        }

        // Marqueur de cible : chevron doré au-dessus de l'ennemi visé
        let chevron = CGMutablePath()
        chevron.move(to: CGPoint(x: -9, y: 9))
        chevron.addLine(to: CGPoint(x: 0, y: 0))
        chevron.addLine(to: CGPoint(x: 9, y: 9))
        targetMarker.path = chevron
        targetMarker.strokeColor = SKColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1)
        targetMarker.lineWidth = 3.5
        targetMarker.lineCap = .round
        targetMarker.glowWidth = 2
        targetMarker.zPosition = 870
        root.addChild(targetMarker)
        targetMarker.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 0.4),
            .moveBy(x: 0, y: -6, duration: 0.4)
        ])))
    }

    /// UI tour par tour : bannière de tour (haut centre) + file
    /// d'initiative (pips des 4 prochains acteurs).
    private func setupTurnUI(scene: SKScene) {
        turnBanner.fillColor = SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.92)
        turnBanner.strokeColor = SKColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 0.9)
        turnBanner.lineWidth = 1.5
        turnBanner.glowWidth = 2
        turnBanner.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 26)
        turnBanner.zPosition = 940
        turnBanner.alpha = 0
        root.addChild(turnBanner)

        turnBannerLabel.fontSize = 14
        turnBannerLabel.fontColor = .white
        turnBannerLabel.verticalAlignmentMode = .center
        turnBannerLabel.position = turnBanner.position
        turnBannerLabel.zPosition = 941
        turnBannerLabel.alpha = 0
        root.addChild(turnBannerLabel)

        turnPipsRoot.position = CGPoint(x: scene.size.width / 2,
                                        y: scene.size.height * 0.745)
        turnPipsRoot.zPosition = 935
        root.addChild(turnPipsRoot)
    }

    /// Anime la bannière au changement de tour.
    private func showTurnBanner(_ text: String, color: SKColor) {
        turnBannerLabel.text = text
        turnBanner.strokeColor = color.withAlphaComponent(0.9)
        let pop: SKAction = .sequence([
            .group([.fadeIn(withDuration: 0.12), .scale(to: 1.06, duration: 0.12)]),
            .scale(to: 1.0, duration: 0.10)
        ])
        turnBanner.setScale(0.92)
        turnBannerLabel.setScale(0.92)
        turnBanner.run(pop)
        turnBannerLabel.run(pop)
    }

    /// Redessine la file d'initiative : manche = [Kael, E1, E2…] répétée.
    /// Acteur courant en grand + glow ; ennemis break/gelés marqués ✕.
    /// `currentEnemyIndex` : nil = tour joueur, sinon index de l'ennemi
    /// en train d'agir.
    private func refreshTurnOrder(currentEnemyIndex: Int?) {
        turnPipsRoot.removeAllChildren()

        // -1 = Kael ; n ≥ 0 = enemies[n] (vivants uniquement)
        let aliveIdx = enemies.indices.filter { enemies[$0].combatant.isAlive }
        let round: [Int] = [-1] + aliveIdx
        guard !round.isEmpty else { return }
        // Décale la manche pour démarrer sur l'acteur courant
        let startPos: Int
        if let cur = currentEnemyIndex, let p = round.firstIndex(of: cur) {
            startPos = p
        } else {
            startPos = 0
        }
        let count = min(5, max(4, round.count + 1))
        let actors: [Int] = (0..<count).map { round[(startPos + $0) % round.count] }

        let spacing: CGFloat = 30
        let x0 = -spacing * CGFloat(actors.count - 1) / 2

        for (i, actor) in actors.enumerated() {
            let isCurrent = i == 0
            let isEnemy = actor >= 0
            var skipped = false
            if isEnemy, !isCurrent {
                let e = enemies[actor]
                if e.brokenTurns > 0 || e.combatant.stunned { skipped = true }
            }

            let pip = SKShapeNode(circleOfRadius: isCurrent ? 12 : 9)
            pip.position = CGPoint(x: x0 + CGFloat(i) * spacing, y: 0)
            pip.fillColor = isEnemy
                ? SKColor(red: 0.42, green: 0.12, blue: 0.14, alpha: 0.95)
                : SKColor(red: 0.12, green: 0.26, blue: 0.42, alpha: 0.95)
            pip.strokeColor = isCurrent
                ? SKColor(red: 1.00, green: 0.92, blue: 0.55, alpha: 1)
                : SKColor(white: 0.55, alpha: 0.8)
            pip.lineWidth = isCurrent ? 2 : 1
            pip.glowWidth = isCurrent ? 3 : 0
            if skipped { pip.alpha = 0.35 }
            turnPipsRoot.addChild(pip)

            let letter = SKLabelNode(fontNamed: "AvenirNext-Bold")
            if skipped {
                letter.text = "✕"
            } else if isEnemy {
                let name = enemies[actor].combatant.name
                letter.text = String(name.prefix(1))
            } else {
                letter.text = "K"
            }
            letter.fontSize = isCurrent ? 12 : 9
            letter.fontColor = .white
            letter.verticalAlignmentMode = .center
            letter.position = pip.position
            if skipped { letter.alpha = 0.5 }
            turnPipsRoot.addChild(letter)
        }
    }

    /// Petit pulse du panneau d'actions quand la main revient au joueur.
    private func pulseActionPanel() {
        for (i, button) in [attackButton, fireButton, iceButton,
                            blackSlashButton, lightningButton, healButton].enumerated() {
            button.run(.sequence([
                .wait(forDuration: Double(i) * 0.03),
                .scale(to: 1.07, duration: 0.10),
                .scale(to: 1.0, duration: 0.12)
            ]))
        }
        HapticsEngine.light()
    }

private func setupButtons(scene: SKScene) {
    let panelWidth = min(scene.size.width - 18, 320)
    let panelHeight: CGFloat = 110
    let panelY: CGFloat = 76

    let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 10)
    panel.fillColor = SKColor(red: 0.035, green: 0.030, blue: 0.060, alpha: 0.96)
    panel.strokeColor = SKColor(red: 0.72, green: 0.58, blue: 1.00, alpha: 0.8)
    panel.lineWidth = 1.5
    panel.position = CGPoint(x: scene.size.width / 2, y: panelY)
    panel.zPosition = 850
    root.addChild(panel)

    let buttonW = (panelWidth - 28) / 3
    let buttonH: CGFloat = 32
    let x0 = scene.size.width / 2 - buttonW - 4
    let x1 = scene.size.width / 2
    let x2 = scene.size.width / 2 + buttonW + 4
    let topY = panelY + 16
    let bottomY = panelY - 22

    addButton(attackButton, title: String(localized: "combat.button.attack"), at: CGPoint(x: x0, y: topY), width: buttonW, height: buttonH,
              fill: SKColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1), stroke: CombatElement.physical.color, fontSize: 10)
    addButton(fireButton, title: String(localized: "combat.button.fire"), at: CGPoint(x: x1, y: topY), width: buttonW, height: buttonH,
              fill: SKColor(red: 0.32, green: 0.075, blue: 0.035, alpha: 1), stroke: CombatElement.fire.color, fontSize: 11)
    addButton(iceButton, title: String(localized: "combat.button.ice"), at: CGPoint(x: x2, y: topY), width: buttonW, height: buttonH,
              fill: SKColor(red: 0.035, green: 0.18, blue: 0.28, alpha: 1), stroke: CombatElement.ice.color, fontSize: 11)
    addButton(blackSlashButton, title: String(localized: "combat.button.aether"), at: CGPoint(x: x0, y: bottomY), width: buttonW, height: buttonH,
              fill: SKColor(red: 0.22, green: 0.07, blue: 0.34, alpha: 1), stroke: CombatElement.aether.color, fontSize: 10)
    addButton(lightningButton, title: String(localized: "combat.button.lightning"), at: CGPoint(x: x1, y: bottomY), width: buttonW, height: buttonH,
              fill: SKColor(red: 0.30, green: 0.22, blue: 0.035, alpha: 1), stroke: CombatElement.lightning.color, fontSize: 10)
    addButton(healButton, title: String(localized: "combat.button.heal"), at: CGPoint(x: x2, y: bottomY), width: buttonW, height: buttonH,
              fill: SKColor(red: 0.035, green: 0.26, blue: 0.10, alpha: 1), stroke: SKColor(red: 0.40, green: 1.00, blue: 0.56, alpha: 1), fontSize: 11)

    addButton(boostButton, title: String(localized: "combat.button.boost"), at: CGPoint(x: scene.size.width / 2, y: panelY + 48), width: 88, height: 22,
              fill: SKColor(red: 0.20, green: 0.10, blue: 0.38, alpha: 1), stroke: SKColor(red: 0.86, green: 0.68, blue: 1.00, alpha: 1), fontSize: 9)
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

    private func addButton(_ node: SKShapeNode, title: String, at position: CGPoint,
                           width: CGFloat, height: CGFloat,
                           fill: SKColor, stroke: SKColor,
                           fontSize: CGFloat = 14) {
        node.removeAllChildren()
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        node.path = CGPath(roundedRect: rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        node.position = position
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 1.8
        node.glowWidth = 1.5
        node.zPosition = 860

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        root.addChild(node)
    }

    private func updateVisuals() {
        let kaelHPRatio = max(0.02, CGFloat(kael.hp) / CGFloat(kael.maxHP))
        kaelHPFill.xScale = kaelHPRatio
        kaelHPLabel.text = String(kael.hp) + "/" + String(kael.maxHP)

        // Plate de droite = cible courante
        if let foe = target {
            let c = foe.combatant
            enemyHPFill.xScale = max(0.02, CGFloat(c.hp) / CGFloat(c.maxHP))
            enemyHPLabel.text = String(c.hp) + "/" + String(c.maxHP)
            targetNameLabel.text = c.name
            let weaknessText = foe.weaknesses.map { $0.icon }.sorted().joined(separator: "  ")
            weaknessLabel.text = String(localized: "combat.hud.weakness") + " " + weaknessText
                + "   " + String(localized: "combat.hud.shield") + " "
                + String(foe.shield) + "/" + String(foe.shieldMax)
            enemyHPBack.strokeColor = foe.brokenTurns > 0
                ? SKColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1)
                : SKColor(white: 0.3, alpha: 1)
            // Marqueur de cible au-dessus du sprite visé (multi uniquement)
            let markerVisible = enemies.count > 1 && c.isAlive && phase != .finished
            targetMarker.isHidden = !markerVisible
            if markerVisible {
                targetMarker.position = CGPoint(x: foe.homePosition.x,
                                                y: foe.homePosition.y + 64)
            }
        } else {
            targetMarker.isHidden = true
        }

        // Minibars HP par ennemi
        for e in enemies {
            let c = e.combatant
            e.hpFill.xScale = max(0.02, CGFloat(c.hp) / CGFloat(c.maxHP))
        }

        let ready = phase == .playerTurn && kael.isAlive && !aliveEnemies.isEmpty
        for button in [attackButton, blackSlashButton, fireButton, iceButton, lightningButton, healButton] {
            button.alpha = ready ? 1 : 0.36
        }
        boostButton.alpha = (ready && playerBP > 0 && queuedBoost < 3) ? 1 : 0.34

        let bpPips = (0..<3).map { $0 < playerBP ? "●" : "○" }.joined()
        boostLabel.text = queuedBoost > 0 ? "BP " + bpPips + "   " + String(localized: "combat.status.boost \(queuedBoost + 1)") : "BP " + bpPips

        if statusLabel.text?.isEmpty ?? true {
            statusLabel.text = String(localized: "combat.status.battleStart")
        }
    }
}

