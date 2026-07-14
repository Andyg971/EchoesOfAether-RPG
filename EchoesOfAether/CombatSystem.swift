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
    case potion
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

/// Alliés jouables : Lyra (actes I-II), son écho spectral et Eran (Acte III).
enum CombatAllyKind {
    case lyra, lyraEcho, eran

    var displayName: String {
        switch self {
        case .lyra: return "Lyra"
        case .lyraEcho: return String(localized: "combat.name.lyraEcho")
        case .eran: return "Eran"
        }
    }

    func maxHP(level: Int) -> Int {
        switch self {
        case .lyra: return 160 + (level - 1) * 14
        case .lyraEcho: return 140 + (level - 1) * 12   // spectrale, fragile
        case .eran: return 190 + (level - 1) * 15       // esprit endurci
        }
    }

    func attackDamage(level: Int) -> Int {
        switch self {
        case .lyra, .lyraEcho: return 30 + (level - 1) * 3
        case .eran: return 36 + (level - 1) * 3
        }
    }

    /// Multiplicateur des sorts (les arcanistes frappent plus fort).
    var spellMultiplier: CGFloat {
        switch self {
        case .lyra: return 1.10
        case .lyraEcho: return 1.18
        case .eran: return 1.05
        }
    }

    /// Couleur d'accent (pips d'initiative, plate HP).
    var accentColor: SKColor {
        switch self {
        case .lyra: return SKColor(red: 0.32, green: 0.85, blue: 0.66, alpha: 1)
        case .lyraEcho: return SKColor(red: 0.55, green: 0.90, blue: 0.95, alpha: 1)
        case .eran: return SKColor(red: 0.48, green: 0.75, blue: 1.00, alpha: 1)
        }
    }
}

@MainActor
final class CombatSystem {
    private let root = SKNode()
    private let statusLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // HP bars
    private let kaelHPBack = SKShapeNode()
    private let kaelHPFill = SKShapeNode()
    private let kaelHPGhost = SKShapeNode()   // « dégâts fantômes » qui fondent
    private let kaelHPLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    private let enemyHPBack = SKShapeNode()
    private let enemyHPFill = SKShapeNode()
    private let enemyHPGhost = SKShapeNode()
    private var lastTargetIndexForGhost = -1
    private let enemyHPLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let targetNameLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Tour par tour
    private enum TurnPhase { case intro, playerTurn, playerActing, enemyTurn, finished }
    private enum TurnActor { case player, enemy }
    private var phase: TurnPhase = .intro
    private let turnBanner = SKShapeNode(rectOf: CGSize(width: 240, height: 30), cornerRadius: 15)
    private let turnBannerLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let turnPipsRoot = SKNode()

    // Buttons
private let attackButton = SKShapeNode(rectOf: CGSize(width: 150, height: 54), cornerRadius: 16)
private let blackSlashButton = SKShapeNode(rectOf: CGSize(width: 190, height: 54), cornerRadius: 16)
private let fireButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let iceButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let lightningButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let healButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let boostButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let potionButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
private let weaknessLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
private let boostLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
private let breakLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Sprites combattants (refonte UI : on doit voir les personnages se battre)
    private var kaelSprite: SKNode?
    private var kaelHomePosition: CGPoint = .zero
    private var arenaFloor: SKNode?

    /// Alliés jouables aux côtés de Kael (0 à 2) : Lyra dans les zones
    /// du pacte, l'Écho de Lyra et Eran au Seuil (trio de l'Acte III).
    @MainActor
    final class AllyState {
        var combatant: Combatant
        let kind: CombatAllyKind
        var sprite: SKNode?
        var home: CGPoint = .zero
        let hpBack = SKShapeNode()
        let hpFill = SKShapeNode()
        let hpGhost = SKShapeNode()
        let hpLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

        init(kind: CombatAllyKind, level: Int) {
            self.kind = kind
            let hp = kind.maxHP(level: level)
            self.combatant = Combatant(name: kind.displayName, maxHP: hp, hp: hp)
        }
    }

    private var allies: [AllyState] = []
    /// nil = Kael agit ; sinon index de l'allié en train d'agir.
    private var actingAllyIndex: Int?
    private var actingAlly: AllyState? {
        actingAllyIndex.flatMap { allies.indices.contains($0) ? allies[$0] : nil }
    }
    private var aliveAllies: [AllyState] { allies.filter { $0.combatant.isAlive } }
    /// Position d'origine de l'acteur en train d'agir (FX des sorts).
    private var actorHomePosition: CGPoint {
        actingAlly?.home ?? kaelHomePosition
    }
    private var actorSprite: SKNode? { actingAlly?.sprite ?? kaelSprite }
    // Étiquette de l'acteur courant sur le panneau d'actions
    private let actorTagLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let actionPanel = SKShapeNode()
    private var actionPanelWidth: CGFloat = 288
    // Curseur de sélection (contrôles classiques, zéro tactile) :
    // rangée 0 = techniques, rangée 1 = BOOST/POTION, rangée 2 = cible.
    private var menuRow = 0
    private var menuCol = 0
    private let selectionCursor = SKShapeNode()

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
        let statusIcons = SKNode()   // pictos brûlure/gel/break persistants

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
/// Règle du Boost (façon Octopath) : booster épuise le flux — aucun BP
/// ne se régénère à la manche suivante.
private var boostedThisRound = false
private var bpRecharging = false
private var goldReward = 0
    private var completion: ((Int, Int) -> Void)?
    private weak var parentScene: SKScene?
    private var _player: PlayerState?

    // Audit visuel des sorts (--fx-demo)
    private var fxDemoIndex = 0
    // Ambiance musicale à restaurer en quittant l'arène
    private var moodBeforeCombat: AudioEngine.MusicMood = .calm

    // Combo
    private var comboCount = 0
    private let comboLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Status effect label
    private let statusEffectLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Boss
    private var bossConfig: BossConfig?
    private var isEnraged = false
    private var enemyTurnCount = 0
    private let enrageLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

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
                withLyra: Bool = false,
                allyKinds: [CombatAllyKind] = [],
                completion: @escaping (Int, Int) -> Void) {
        // Ennemis relevés : le joueur doit encaisser une vraie menace.
        let dmg = boss != nil ? 38 : 28
        attach(to: scene,
               enemySpecs: [EnemySpec(name: enemyName, hp: enemyHP,
                                      kind: enemyKind, baseDamage: dmg)],
               goldReward: goldReward, player: player, boss: boss,
               withLyra: withLyra, allyKinds: allyKinds,
               completion: completion)
    }

    /// Combat multi-ennemis (1 à 3). Boss supporté en solo uniquement.
    /// `withLyra` : Lyra rejoint (tour Kael → Lyra → ennemis).
    /// `allyKinds` : composition explicite (Acte III : écho de Lyra + Eran,
    /// trio complet — Kael puis chaque allié, puis les ennemis).
    func attach(to scene: SKScene, enemySpecs: [EnemySpec],
                goldReward: Int = 30, player: PlayerState,
                boss: BossConfig? = nil,
                withLyra: Bool = false,
                allyKinds: [CombatAllyKind] = [],
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
        // Alliés : Lyra via withLyra (compat), composition explicite sinon.
        var kinds = allyKinds
        if kinds.isEmpty, withLyra { kinds = [.lyra] }
        self.allies = kinds.prefix(2).map { AllyState(kind: $0, level: player.level) }
        self.actingAllyIndex = nil
self.resonance = 0
self.playerBP = 0
self.queuedBoost = 0
self.boostedThisRound = false
self.bpRecharging = false
self.comboCount = 0
self.phase = .intro
        self.completion = completion
        self._player = player
        // Musique : thème de combat (ou de boss), restaurée à la fin.
        moodBeforeCombat = AudioEngine.shared.currentMood
        AudioEngine.shared.setMood(boss != nil ? .boss : .combat)
        // Bestiaire : toute espèce affrontée est consignée.
        player.bestiarySeen.formUnion(enemySpecs.prefix(3).map(\.kind.bestiaryID))

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
        playBattleIntroDissolve(scene: scene)
        playEntranceAnimation()

        // Premier tour après l'entrée en scène (le joueur ouvre toujours).
        root.run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.startPlayerTurn() }
        ]))
    }

    /// Transition d'entrée en combat façon SNES : l'écran est couvert de
    /// carrés noirs qui se dissipent en ordre aléatoire, révélant l'arène.
    private func playBattleIntroDissolve(scene: SKScene) {
        let overlay = SKNode()
        overlay.zPosition = 990
        root.addChild(overlay)

        let side: CGFloat = 44
        let cols = Int(ceil(scene.size.width / side))
        let rows = Int(ceil(scene.size.height / side))
        for c in 0...cols {
            for r in 0...rows {
                let square = SKSpriteNode(
                    color: SKColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1),
                    size: CGSize(width: side + 1, height: side + 1))
                square.position = CGPoint(x: CGFloat(c) * side + side / 2,
                                          y: CGFloat(r) * side + side / 2)
                overlay.addChild(square)
                square.run(.sequence([
                    .wait(forDuration: .random(in: 0.05...0.50)),
                    .group([.fadeOut(withDuration: 0.16),
                            .scale(to: 0.1, duration: 0.16)]),
                    .removeFromParent()
                ]))
            }
        }
        overlay.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    }

    /// Faiblesses + boucliers par type d'ennemi.
    static func tactics(for kind: CombatSpriteKind, isBoss: Bool)
        -> (weaknesses: Set<CombatElement>, shieldMax: Int) {
        let weaknesses: Set<CombatElement>
        var shieldMax: Int
        switch kind {
        case .beast:         weaknesses = [.fire, .aether];            shieldMax = 2
        case .wolf:          weaknesses = [.ice, .lightning];          shieldMax = 2
        case .ghoul:         weaknesses = [.fire];                     shieldMax = 3
        case .boneWalker:    weaknesses = [.lightning, .aether];       shieldMax = 3
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
    actingAllyIndex = nil
    retargetIfNeeded()
    // Régénération de BP — sautée si l'équipe a boosté à la manche
    // précédente (le flux d'Aether doit se re-stabiliser).
    if boostedThisRound {
        boostedThisRound = false
        bpRecharging = true
        showEffect(String(localized: "combat.boost.recharging"),
                   color: SKColor(red: 0.72, green: 0.62, blue: 1.00, alpha: 1))
    } else {
        bpRecharging = false
        playerBP = min(3, playerBP + 1)
    }
    statusLabel.text = aliveEnemies.count > 1
        ? String(localized: "combat.turn.chooseMulti")
        : String(localized: "combat.turn.choose")
    showTurnBanner(String(localized: "combat.turn.player"),
                   color: SKColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 1))
    refreshTurnOrder(currentEnemyIndex: nil)
    layoutActionMenu()
    menuRow = 0
    menuCol = 0
    updateSelectionCursor()
    pulseActionPanel()
    updateVisuals()
    runFXDemoIfNeeded()
}

/// Tour d'un allié : même panneau d'actions, le joueur contrôle tout
/// le trio (Kael → allié 1 → allié 2 → ennemis).
private func startAllyTurn(_ index: Int) {
    guard isActive, kael.isAlive, allies.indices.contains(index),
          allies[index].combatant.isAlive, !aliveEnemies.isEmpty else {
        startEnemyTurn(); return
    }
    phase = .playerTurn
    actingAllyIndex = index
    retargetIfNeeded()
    statusLabel.text = String(localized: "combat.turn.choose")
    showTurnBanner(String(localized: "combat.turn.ally \(allies[index].kind.displayName)"),
                   color: allies[index].kind.accentColor)
    refreshTurnOrder(currentEnemyIndex: nil)
    layoutActionMenu()
    menuRow = 0
    menuCol = 0
    updateSelectionCursor()
    pulseActionPanel()
    updateVisuals()
    runFXDemoIfNeeded()
}

/// Audit visuel des sorts : --fx-demo caste automatiquement
/// feu → soin → glace → foudre à chaque tour du joueur.
private func runFXDemoIfNeeded() {
    guard CommandLine.arguments.contains("--fx-demo") else { return }
    // Kits séparés : Kael caste feu, Lyra alterne glace/soin/foudre.
    let order: [CombatSpell]
    switch actingAlly?.kind {
    case .lyra:      order = [.frost, .mend, .thunder]
    case .lyraEcho:  order = [.frost, .mend]
    case .eran:      order = [.thunder]
    case nil:        order = [.ember]
    }
    let spell = order[fxDemoIndex % order.count]
    fxDemoIndex += 1
    root.run(.sequence([
        .wait(forDuration: 0.9),
        .run { [weak self] in
            guard let self, self.phase == .playerTurn else { return }
            self.perform(.spell(spell))
        }
    ]))
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

    // Cible : les alliés encaissent ~40 % des coups quand ils sont debout.
    // Les attaques spéciales de boss visent toujours Kael (enjeu narratif).
    let victim: AllyState? = (!isSpecial && !aliveAllies.isEmpty
                              && Double.random(in: 0...1) < 0.40)
        ? aliveAllies.randomElement() : nil

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
        statusLabel.text = victim != nil
            ? String(localized: "combat.status.enemyHitsAlly \(e.combatant.name) \(victim!.combatant.name) \(dmg)")
            : String(localized: "combat.status.enemyHits \(e.combatant.name) \(dmg)")
    }

    let victimHome = victim?.home ?? kaelHomePosition

    // Esquive : 10 % de chance d'éviter un coup normal (jamais un spécial).
    if !isSpecial, Double.random(in: 0...1) < 0.10 {
        statusLabel.text = String(localized: "combat.status.dodged")
        playEnemyAttackAnimation(e, isSpecial: false, victim: victim, dodged: true)
        playDodgeEffect(sprite: victim?.sprite ?? kaelSprite, home: victimHome)
        updateVisuals()
        proceed()
        return
    }

    if let victim {
        victim.combatant.hp = max(0, victim.combatant.hp - dmg)
    } else {
        kael.hp = max(0, kael.hp - dmg)
    }
    AudioEngine.shared.playDamage()
    JuiceEngine.screenShake(root, intensity: shakeIntensity, duration: 0.15)
    if isSpecial { JuiceEngine.zoomPunch(root, around: victimHome, scale: 1.05) }
    playEnemyAttackAnimation(e, isSpecial: isSpecial, victim: victim)
    root.addChild(ParticleFactory.impactSparks(
        at: victimHome,
        color: sparkColor,
        count: isSpecial ? 12 : 6
    ))
    showFloatingText("-" + String(dmg), at: victimHome,
                     color: SKColor(red: 1.00, green: 0.40, blue: 0.35, alpha: 1))

    if let victim, !victim.combatant.isAlive { handleAllyDown(victim) }
    if !kael.isAlive { handleDefeat(); return }
    updateVisuals()
    proceed()
}

/// Un allié tombe : KO visuel, il saute ses tours.
/// La défaite n'arrive que si Kael tombe.
private func handleAllyDown(_ ally: AllyState) {
    showEffect(String(localized: "combat.status.allyDown \(ally.combatant.name)"),
               color: SKColor(red: 1.00, green: 0.55, blue: 0.45, alpha: 1))
    ally.sprite?.run(.group([
        .rotate(toAngle: -.pi / 2, duration: 0.5, shortestUnitArc: true),
        .moveBy(x: 0, y: -10, duration: 0.5),
        .fadeAlpha(to: 0.45, duration: 0.5)
    ]))
    HapticsEngine.heavy()
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

/// Contrôles classiques : le combat ne réagit plus au toucher.
/// Navigation au joystick (`menuNav`), validation au bouton A
/// (`menuConfirm`). Le tap est absorbé pour ne pas fuir au monde.
func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
    guard isActive else { return false }
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
        AudioEngine.shared.setMood(moodBeforeCombat)
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

        let bossTitle = SKLabelNode(fontNamed: PixelUI.uiFont)
        bossTitle.text = enemies.first?.combatant.name ?? ""
        bossTitle.fontSize = 17
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
    if boost > 0 { boostedThisRound = true }

    let enemyCenter = foe.homePosition
    // Stats par acteur : alliés = attaque plus faible, sorts plus forts.
    let level = _player?.level ?? 1
    let atkDmg = actingAlly?.kind.attackDamage(level: level)
        ?? (_player?.attackDamage ?? 42)
    let slashDmg = actingAlly != nil
        ? Int(CGFloat(_player?.blackSlashDamage ?? 92) * 0.85)
        : (_player?.blackSlashDamage ?? 92)
    let spellMult: CGFloat = actingAlly?.kind.spellMultiplier ?? 1.0

    switch action {
    case .attack:
        comboCount += 1
        let comboMult: Int = comboCount >= 5 ? 14 : (comboCount >= 3 ? 12 : 10)
        var finalDmg = Int(CGFloat(atkDmg * comboMult / 10) * damageMultiplier)
        let isCrit = Double.random(in: 0...1) < 0.12
        if isCrit { finalDmg = Int(CGFloat(finalDmg) * 1.5) }
        foe.combatant.hp = max(0, foe.combatant.hp - finalDmg)
        if boost > 0 {
            statusLabel.text = String(localized: "combat.status.attackBoosted \(boost + 1) \(finalDmg)")
        } else {
            statusLabel.text = actingAlly != nil
                ? String(localized: "combat.status.attackAlly \(actingAlly!.combatant.name) \(foe.combatant.name)")
                : String(localized: "combat.status.attack \(foe.combatant.name)")
        }
        AudioEngine.shared.playHit()
        HapticsEngine.medium()
        JuiceEngine.screenShake(root, intensity: boost > 0 ? 7 : 5, duration: 0.2)
        if boost > 0 { JuiceEngine.zoomPunch(root, around: enemyCenter) }
        playActorAttackAnimation(on: foe, strong: boost > 0)
        spawnSlashArc(at: enemyCenter, color: .white, strong: boost > 0)
        root.addChild(ParticleFactory.impactSparks(at: enemyCenter, color: .white, count: 8 + boost * 4))
        if isCrit {
            playCritEffect(at: enemyCenter, damage: finalDmg)
        } else {
            showFloatingText("-" + String(finalDmg), at: enemyCenter, color: .white)
        }
        showComboIfNeeded()

    case .blackSlash:
        comboCount = 0
        resonance += 1
        var finalDmg = Int(CGFloat(slashDmg) * damageMultiplier)
        let isCrit = Double.random(in: 0...1) < 0.12
        if isCrit { finalDmg = Int(CGFloat(finalDmg) * 1.5) }
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
        JuiceEngine.zoomPunch(root, around: enemyCenter, scale: 1.045)
        JuiceEngine.slowMotion(scene: scene, duration: 0.18, factor: 0.25)
        JuiceEngine.flashOverlay(
            in: root,
            size: scene.size,
            color: SKColor(red: 0.30, green: 0.02, blue: 0.40, alpha: 1),
            duration: 0.2
        )
        playActorAttackAnimation(on: foe, strong: true)
        spawnSlashArc(at: enemyCenter, color: CombatElement.aether.color, strong: true)
        root.addChild(ParticleFactory.blackAetherBurst(at: enemyCenter))
        if isCrit {
            playCritEffect(at: enemyCenter, damage: finalDmg)
        } else {
            showFloatingText("-" + String(finalDmg), at: enemyCenter, color: CombatElement.aether.color)
        }

    case .potion:
        comboCount = 0
        // Boire une potion : gros soin de l'acteur, consomme tour et fiole.
        if let p = _player, p.potions > 0 {
            p.potions -= 1
            let heal: Int
            if let ally = actingAlly {
                heal = Int(CGFloat(ally.combatant.maxHP) * 0.40)
                ally.combatant.hp = min(ally.combatant.maxHP,
                                        ally.combatant.hp + heal)
            } else {
                heal = Int(CGFloat(kael.maxHP) * 0.40)
                kael.hp = min(kael.maxHP, kael.hp + heal)
            }
            statusLabel.text = String(localized: "combat.status.potionUsed \(heal)")
            AudioEngine.shared.playHit()
            HapticsEngine.success()
            playMendEffect(boosted: false)
            showFloatingText("+" + String(heal), at: actorHomePosition,
                             color: SKColor(red: 0.45, green: 1.00, blue: 0.62, alpha: 1))
        }
        endPlayerAction()
        return

    case .spell(let spell):
        comboCount = 0
        if spell == .mend {
            let heal = Int(CGFloat(spell.basePower + ((_player?.level ?? 1) - 1) * 5)
                           * damageMultiplier * spellMult)
            // Le soin cible le membre du groupe le plus blessé (% PV).
            let kaelRatio = CGFloat(kael.hp) / CGFloat(kael.maxHP)
            let worstAlly = aliveAllies.min {
                CGFloat($0.combatant.hp) / CGFloat($0.combatant.maxHP)
                    < CGFloat($1.combatant.hp) / CGFloat($1.combatant.maxHP)
            }
            let worstRatio = worstAlly.map {
                CGFloat($0.combatant.hp) / CGFloat($0.combatant.maxHP)
            } ?? 2
            let healPos: CGPoint
            if let ally = worstAlly, worstRatio < kaelRatio {
                ally.combatant.hp = min(ally.combatant.maxHP,
                                        ally.combatant.hp + heal)
                healPos = ally.home
            } else {
                kael.hp = min(kael.maxHP, kael.hp + heal)
                healPos = kaelHomePosition
            }
            statusLabel.text = boost > 0
                ? String(localized: "combat.status.healBoosted \(boost + 1) \(heal)")
                : String(localized: "combat.status.heal \(heal)")
            AudioEngine.shared.playHit()
            HapticsEngine.success()
            playMendEffect(boosted: boost > 0, at: healPos)
            showFloatingText("+" + String(heal), at: healPos, color: SKColor(red: 0.45, green: 1.00, blue: 0.62, alpha: 1))
            endPlayerAction()
            return
        }

        guard let element = spell.element else { return }
        let isWeak = foe.weaknesses.contains(element)
        let broke = isWeak ? hitWeakness(on: foe, with: element) : false
        let levelBonus = ((_player?.level ?? 1) - 1) * 5
        var finalDmg = Int(CGFloat(spell.basePower + levelBonus) * damageMultiplier * spellMult)
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

/// Clôt l'action de l'acteur courant : victoire, enrage boss,
/// puis tour de Lyra (si elle n'a pas encore agi) ou phase ennemie.
private func endPlayerAction() {
    updateVisuals()
    guard !aliveEnemies.isEmpty else { checkVictory(); return }
    checkEnrage()
    // Prochain allié vivant qui n'a pas encore agi cette manche.
    let nextIdx: Int? = {
        let start = actingAllyIndex.map { $0 + 1 } ?? 0
        for i in start..<allies.count where allies[i].combatant.isAlive { return i }
        return nil
    }()
    root.run(.sequence([
        .wait(forDuration: 0.85),
        .run { [weak self] in
            guard let self else { return }
            if let i = nextIdx { self.startAllyTurn(i) } else { self.startEnemyTurn() }
        }
    ]))
}

/// Croissant de slash balayé sur la cible — 100% pixel, zéro glow.
private func spawnSlashArc(at point: CGPoint, color: SKColor, strong: Bool) {
    PixelFX.slashArc(in: root, at: point, color: color, strong: strong)
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
    JuiceEngine.zoomPunch(root, around: foe.homePosition, scale: 1.05)
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

/// Chaque sort a sa mise en scène : projectile de feu, pics de glace,
/// foudre qui tombe, colonne de soin — plus d'anneau générique.
private func playSpellAnimation(_ spell: CombatSpell, on foe: EnemyState, boosted: Bool) {
    // Pose de cast : le lanceur s'imprègne brièvement de la couleur du sort
    let castColor = spell.element?.color
        ?? SKColor(red: 0.40, green: 0.95, blue: 0.60, alpha: 1)
    actorSprite?.forEachDescendantSprite { sprite in
        let prevColor = sprite.color
        let prevFactor = sprite.colorBlendFactor
        sprite.run(.sequence([
            .colorize(with: castColor, colorBlendFactor: 0.45, duration: 0.10),
            .wait(forDuration: 0.12),
            .colorize(with: prevColor, colorBlendFactor: prevFactor, duration: 0.22)
        ]))
    }
    switch spell {
    case .ember:   playEmberEffect(on: foe, boosted: boosted)
    case .frost:   playFrostEffect(on: foe, boosted: boosted)
    case .thunder: playThunderEffect(on: foe, boosted: boosted)
    case .mend:    playMendEffect(boosted: boosted)
    }
    if spell != .mend {
        // L'impact arrive avec un léger retard (le temps du projectile/effet)
        let impactDelay: TimeInterval = switch spell {
        case .ember: 0.46      // charge + vol de la boule de feu
        case .frost: 0.30      // jaillissement des stalactites
        case .thunder: 0.14    // la foudre frappe quasi instantanément
        case .mend: 0
        }
        root.run(.sequence([
            .wait(forDuration: impactDelay),
            .run { [weak self] in self?.playEnemyHitReact(foe, strong: boosted) }
        ]))
    }
}

// MARK: - Moteur de particules pixel (carrés nets, zéro glow)

/// Palettes pixel par élément (du plus clair au plus sombre).
private static let firePalette: [SKColor] = [
    SKColor(red: 1.00, green: 0.96, blue: 0.62, alpha: 1),
    SKColor(red: 1.00, green: 0.58, blue: 0.16, alpha: 1),
    SKColor(red: 0.88, green: 0.24, blue: 0.06, alpha: 1),
    SKColor(red: 0.45, green: 0.10, blue: 0.05, alpha: 1)
]
private static let icePalette: [SKColor] = [
    SKColor(red: 0.92, green: 0.99, blue: 1.00, alpha: 1),
    SKColor(red: 0.56, green: 0.86, blue: 1.00, alpha: 1),
    SKColor(red: 0.30, green: 0.60, blue: 0.95, alpha: 1),
    SKColor(red: 0.16, green: 0.34, blue: 0.72, alpha: 1)
]
private static let boltPalette: [SKColor] = [
    SKColor(red: 1.00, green: 1.00, blue: 0.88, alpha: 1),
    SKColor(red: 1.00, green: 0.90, blue: 0.40, alpha: 1),
    SKColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1)
]
private static let healPalette: [SKColor] = [
    SKColor(red: 0.75, green: 1.00, blue: 0.78, alpha: 1),
    SKColor(red: 0.40, green: 0.95, blue: 0.60, alpha: 1),
    SKColor(red: 0.18, green: 0.70, blue: 0.42, alpha: 1)
]

/// FEU : charge aspirée, boule de feu massive en cloche, traînée épaisse,
/// explosion pixel + onde de choc + flammes résiduelles + fumée.
private func playEmberEffect(on foe: EnemyState, boosted: Bool) {
    let pal = Self.firePalette
    let start = CGPoint(x: actorHomePosition.x + 30, y: actorHomePosition.y + 40)

    // 1. Charge : pixels de braise aspirés vers la main de Kael.
    PixelFX.converge(in: root, to: start, palette: pal,
                     count: boosted ? 14 : 10, radius: 46, duration: 0.18)

    // 2. Noyau de la boule = carrés concentriques tournoyants.
    let ball = SKNode()
    let sizes: [(CGFloat, Int)] = boosted
        ? [(28, 3), (20, 1), (12, 0)] : [(22, 3), (15, 1), (9, 0)]
    for (sz, ci) in sizes {
        let sq = SKSpriteNode(color: pal[ci], size: CGSize(width: sz, height: sz))
        ball.addChild(sq)
    }
    ball.position = start
    ball.zPosition = 826
    ball.setScale(0.2)
    ball.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.25)))
    root.addChild(ball)

    // Traînée : braises carrées lâchées en continu.
    let trail = SKAction.repeatForever(.sequence([
        .run { [weak self, weak ball] in
            guard let self, let ball else { return }
            for _ in 0..<3 {
                let side = CGFloat.random(in: 4...8)
                let ember = SKSpriteNode(color: pal.randomElement() ?? .orange,
                                         size: CGSize(width: side, height: side))
                ember.position = CGPoint(x: ball.position.x + .random(in: -7...7),
                                         y: ball.position.y + .random(in: -7...7))
                ember.zPosition = 825
                self.root.addChild(ember)
                ember.run(.sequence([
                    .group([.fadeOut(withDuration: 0.3), .scale(to: 0.2, duration: 0.3)]),
                    .removeFromParent()
                ]))
            }
        },
        .wait(forDuration: 0.02)
    ]))

    // 3. Vol en cloche : la boule monte puis retombe sur la cible.
    let impact = CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 20)
    let arc = CGMutablePath()
    arc.move(to: start)
    let apex = CGPoint(x: (start.x + impact.x) / 2,
                       y: max(start.y, impact.y) + 70)
    arc.addQuadCurve(to: impact, control: apex)
    let fly = SKAction.follow(arc, asOffset: false, orientToPath: false, duration: 0.26)
    fly.timingMode = .easeIn

    ball.run(.sequence([
        .group([.scale(to: 1.0, duration: 0.16),
                .sequence([.wait(forDuration: 0.16),
                           .run { ball.run(trail, withKey: "trail") }])]),
        .wait(forDuration: 0.04),
        fly,
        .run { [weak self] in
            guard let self else { return }
            ball.removeAction(forKey: "trail")
            let ground = foe.homePosition
            // Explosion radiale massive + gerbe montante + fumée.
            PixelFX.burst(in: self.root, at: ground, palette: pal,
                          count: boosted ? 52 : 34, speed: 130...300,
                          gravity: 380, pixel: 5...11)
            PixelFX.burst(in: self.root, at: ground, palette: pal,
                          count: boosted ? 18 : 12, speed: 70...150,
                          gravity: -120, pixel: 4...8,
                          baseAngle: .pi / 2, spread: .pi * 0.6)
            // Onde de choc au sol, écrasée en perspective.
            PixelFX.shockRing(in: self.root, at: ground, palette: pal,
                              count: boosted ? 26 : 18,
                              fromRadius: 10, toRadius: boosted ? 88 : 66,
                              pixel: 6, flatten: 0.35, duration: 0.32)
            // Flammes qui vacillent au sol + panache de fumée.
            PixelFX.groundFlames(in: self.root, at: ground, palette: pal,
                                 count: boosted ? 10 : 7,
                                 width: boosted ? 80 : 58)
            PixelFX.smoke(in: self.root, at: ground, count: boosted ? 10 : 7)
            JuiceEngine.screenShake(self.root, intensity: boosted ? 10 : 7, duration: 0.24)
        },
        .removeFromParent()
    ]))
}

/// GLACE : brume givrée au sol, éventail de stalactites cristallines,
/// scintillements sur les pointes, éclats à l'impact.
private func playFrostEffect(on foe: EnemyState, boosted: Bool) {
    let pal = Self.icePalette
    let count = boosted ? 6 : 4

    // Brume de givre qui rampe au sol avant le jaillissement.
    for _ in 0..<(boosted ? 12 : 8) {
        let side = CGFloat.random(in: 4...8)
        let mist = SKSpriteNode(color: pal[0].withAlphaComponent(0.55),
                                size: CGSize(width: side, height: side))
        mist.position = CGPoint(x: foe.homePosition.x + .random(in: -50...50),
                                y: foe.homePosition.y - 30 + .random(in: -4...6))
        mist.zPosition = 824
        mist.alpha = 0
        root.addChild(mist)
        mist.run(.sequence([
            .group([.fadeAlpha(to: 0.55, duration: 0.10),
                    .moveBy(x: .random(in: -20...20), y: 4, duration: 0.5)]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    for i in 0..<count {
        let h: CGFloat = CGFloat.random(in: 30...46) * (boosted ? 1.25 : 1.0)
        let spike = SKNode()
        let steps = 5
        for s in 0..<steps {
            let f = CGFloat(s)
            // Cristal : plus clair au sommet, arêtes latérales pixel
            let core = SKSpriteNode(
                color: s >= steps - 2 ? pal[0] : pal[1],
                size: CGSize(width: max(2, 14 - f * 2.5), height: h / CGFloat(steps) + 1))
            core.position = CGPoint(x: 0, y: (f + 0.5) * h / CGFloat(steps))
            spike.addChild(core)
            if s < steps - 1 {
                let edge = SKSpriteNode(color: pal[2],
                                        size: CGSize(width: 2, height: h / CGFloat(steps)))
                edge.position = CGPoint(x: -(14 - f * 2.5) / 2, y: core.position.y)
                spike.addChild(edge)
            }
        }
        spike.position = CGPoint(x: foe.homePosition.x + CGFloat(i - count / 2) * 15,
                                 y: foe.homePosition.y - 30)
        spike.zPosition = 826
        spike.yScale = 0
        root.addChild(spike)
        spike.run(.sequence([
            .wait(forDuration: Double(i) * 0.05),
            .scaleY(to: 1.0, duration: 0.08),   // jaillit sec
            .run { [weak self] in
                guard let self else { return }
                // Sparkle 16-bit sur la pointe fraîchement sortie.
                PixelFX.twinkle(in: self.root,
                                at: CGPoint(x: spike.position.x + .random(in: -4...4),
                                            y: spike.position.y + h - 2),
                                color: pal[1], size: 3,
                                delay: Double.random(in: 0...0.1))
            },
            .wait(forDuration: 0.28),
            .run { [weak self] in
                guard let self else { return }
                // Se brise en éclats pixel qui retombent
                PixelFX.burst(in: self.root,
                              at: CGPoint(x: spike.position.x, y: spike.position.y + h * 0.5),
                              palette: pal, count: boosted ? 12 : 8,
                              speed: 80...180, gravity: 420, pixel: 3...6)
            },
            .group([.fadeOut(withDuration: 0.18), .scaleY(to: 0.5, duration: 0.18)]),
            .removeFromParent()
        ]))
    }
    // Souffle givré : anneau écrasé qui s'étend au sol.
    PixelFX.shockRing(in: root, at: CGPoint(x: foe.homePosition.x,
                                            y: foe.homePosition.y - 26),
                      palette: pal, count: boosted ? 20 : 14,
                      fromRadius: 8, toRadius: boosted ? 70 : 52,
                      pixel: 4, flatten: 0.3, duration: 0.28)
    root.run(.sequence([.wait(forDuration: 0.12),
                        .run { [weak self] in
                            JuiceEngine.screenShake(self?.root ?? SKNode(),
                                                    intensity: boosted ? 6 : 4, duration: 0.14)
                        }]))
}

/// FOUDRE : éclairs pixel en escalier (zéro diagonale lissée), double flash,
/// onde de choc rasante + crépitement résiduel sur la cible.
private func playThunderEffect(on foe: EnemyState, boosted: Bool) {
    guard let scene = parentScene else { return }
    let pal = Self.boltPalette
    let hit = CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 6)

    // 2-3 éclairs en marches d'escalier, carrés nets uniquement.
    let strands = boosted ? 3 : 2
    for strand in 0..<strands {
        let offsetX = CGFloat(strand - strands / 2) * 10
        let top = CGPoint(x: hit.x + offsetX + .random(in: -14...14),
                          y: scene.size.height + 10)
        let bolt = PixelFX.bolt(in: root, from: top,
                                to: CGPoint(x: hit.x + offsetX * 0.4, y: hit.y),
                                core: strand == 0 ? pal[0] : pal[1],
                                edge: pal[2],
                                width: strand == 0 ? (boosted ? 8 : 6) : 4,
                                jitter: 22)
        bolt.alpha = 0
        bolt.run(.sequence([
            .wait(forDuration: Double(strand) * 0.03),
            .fadeIn(withDuration: 0.02),
            .wait(forDuration: 0.07),
            .fadeAlpha(to: 0.25, duration: 0.04),
            .fadeAlpha(to: 1.0, duration: 0.03),
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ]))
    }
    // Double flash : blanc sec puis jaune, comme un vrai orage.
    JuiceEngine.flashOverlay(in: root, size: scene.size,
                             color: .white, duration: 0.05)
    root.run(.sequence([.wait(forDuration: 0.06), .run { [weak self] in
        guard let self, let scene = self.parentScene else { return }
        JuiceEngine.flashOverlay(in: self.root, size: scene.size,
                                 color: SKColor(red: 0.98, green: 0.94, blue: 0.60, alpha: 1),
                                 duration: 0.09)
    }]))
    JuiceEngine.screenShake(root, intensity: boosted ? 9 : 6, duration: 0.18)
    // Éclats projetés horizontalement au point d'impact (rasants).
    PixelFX.burst(in: root, at: hit, palette: pal, count: boosted ? 28 : 18,
                  speed: 140...320, gravity: 300, pixel: 3...6,
                  baseAngle: 0, spread: .pi * 0.5)
    PixelFX.burst(in: root, at: hit, palette: pal, count: boosted ? 28 : 18,
                  speed: 140...320, gravity: 300, pixel: 3...6,
                  baseAngle: .pi, spread: .pi * 0.5)
    // Onde de choc électrique rasante au sol.
    PixelFX.shockRing(in: root, at: hit, palette: pal,
                      count: boosted ? 24 : 16,
                      fromRadius: 6, toRadius: boosted ? 84 : 60,
                      pixel: 5, flatten: 0.3, duration: 0.26)
    // Crépitement résiduel : étincelles qui claquent sur l'ennemi.
    for i in 0..<(boosted ? 8 : 5) {
        PixelFX.twinkle(in: root,
                        at: CGPoint(x: foe.homePosition.x + .random(in: -26...26),
                                    y: foe.homePosition.y + .random(in: -20...36)),
                        color: pal[1], size: 3,
                        delay: 0.10 + Double(i) * 0.06)
    }
}

/// SOIN : anneau béni au sol, colonne de carrés translucides, spirale de
/// pixels verts montants + scintillements 16-bit.
private func playMendEffect(boosted: Bool, at targetHome: CGPoint? = nil) {
    let pal = Self.healPalette
    let home = targetHome ?? actorHomePosition
    let base = CGPoint(x: home.x, y: home.y - 18)

    // Anneau de bénédiction écrasé qui s'ouvre aux pieds du soigné.
    PixelFX.shockRing(in: root, at: base, palette: pal,
                      count: boosted ? 22 : 16,
                      fromRadius: 6, toRadius: boosted ? 62 : 46,
                      pixel: 5, flatten: 0.32, duration: 0.4)
    // Scintillements autour du corps pendant le soin.
    for i in 0..<(boosted ? 7 : 5) {
        PixelFX.twinkle(in: root,
                        at: CGPoint(x: home.x + .random(in: -30...30),
                                    y: home.y + .random(in: -14...60)),
                        color: pal[0], size: 3,
                        delay: 0.1 + Double(i) * 0.09)
    }

    // Colonne bâtie en carrés empilés (pixel, pas de rect lisse)
    let colW: CGFloat = boosted ? 48 : 36
    let column = SKNode()
    let rows = 10
    for r in 0..<rows {
        for _ in 0..<3 {
            let side = CGFloat.random(in: 5...9)
            let sq = SKSpriteNode(color: pal[Int.random(in: 0...2)].withAlphaComponent(0.5),
                                  size: CGSize(width: side, height: side))
            sq.position = CGPoint(x: .random(in: -colW/2...colW/2),
                                  y: CGFloat(r) * 13 + .random(in: -4...4))
            column.addChild(sq)
        }
    }
    column.position = base
    column.zPosition = 824
    column.alpha = 0
    root.addChild(column)
    column.run(.sequence([
        .fadeIn(withDuration: 0.12),
        .wait(forDuration: 0.35),
        .fadeOut(withDuration: 0.3),
        .removeFromParent()
    ]))

    // Spirale ascendante de pixels
    for i in 0..<(boosted ? 16 : 10) {
        let side = CGFloat.random(in: 4...7)
        let mote = SKSpriteNode(color: pal.randomElement() ?? .green,
                                size: CGSize(width: side, height: side))
        let angle = CGFloat(i) * 0.7
        mote.position = CGPoint(x: base.x + cos(angle) * 16, y: base.y)
        mote.zPosition = 826
        root.addChild(mote)
        let rise: CGFloat = .random(in: 70...110)
        mote.run(.sequence([
            .wait(forDuration: Double(i) * 0.04),
            .group([
                .moveBy(x: -cos(angle) * 20, y: rise, duration: 0.6),
                .fadeOut(withDuration: 0.6),
                .scale(to: 0.4, duration: 0.6)
            ]),
            .removeFromParent()
        ]))
    }
    // Croix de lumière brève au-dessus du soigné
    let cross = SKNode()
    let vBar = SKSpriteNode(color: pal[0], size: CGSize(width: 4, height: 18))
    let hBar = SKSpriteNode(color: pal[0], size: CGSize(width: 14, height: 4))
    hBar.position = CGPoint(x: 0, y: 4)
    cross.addChild(vBar); cross.addChild(hBar)
    cross.position = CGPoint(x: home.x, y: home.y + 70)
    cross.zPosition = 830
    cross.setScale(0.3); cross.alpha = 0
    root.addChild(cross)
    cross.run(.sequence([
        .group([.scale(to: 1.0, duration: 0.15), .fadeIn(withDuration: 0.1)]),
        .wait(forDuration: 0.2),
        .fadeOut(withDuration: 0.25),
        .removeFromParent()
    ]))
    let healedAlly = allies.first { $0.home == home }
    let healedSprite = healedAlly?.sprite ?? kaelSprite
    let baseScale: CGFloat = healedAlly != nil ? 0.95 : 1.10
    healedSprite?.run(.sequence([
        .scale(to: baseScale * 1.07, duration: 0.12),
        .scale(to: baseScale, duration: 0.18)
    ]))
}

/// CRITIQUE : dégâts dorés en gros, éclat d'étincelles, punch caméra.
private func playCritEffect(at position: CGPoint, damage: Int) {
    let gold = SKColor(red: 1.00, green: 0.84, blue: 0.25, alpha: 1)
    showEffect(String(localized: "combat.effect.crit"), color: gold)
    root.addChild(ParticleFactory.impactSparks(at: position, color: gold, count: 12))
    JuiceEngine.zoomPunch(root, around: position, scale: 1.05)
    HapticsEngine.heavy()

    let label = SKLabelNode(fontNamed: PixelUI.uiFont)
    label.text = "-" + String(damage)
    label.fontSize = 33
    label.fontColor = gold
    label.position = CGPoint(x: position.x, y: position.y + 72)
    label.zPosition = 940
    label.setScale(0.4)
    root.addChild(label)
    label.run(.sequence([
        .group([.scale(to: 1.25, duration: 0.12), .fadeIn(withDuration: 0.06)]),
        .scale(to: 1.0, duration: 0.08),
        .group([.moveBy(x: 0, y: 36, duration: 0.5), .fadeOut(withDuration: 0.5)]),
        .removeFromParent()
    ]))
}

/// ESQUIVE : pas de côté vif du sprite, aucun dégât.
private func playDodgeEffect(sprite: SKNode?, home: CGPoint) {
    showEffect(String(localized: "combat.effect.dodge"),
               color: SKColor(red: 0.65, green: 0.95, blue: 1.00, alpha: 1))
    showFloatingText(String(localized: "combat.effect.dodge"), at: home,
                     color: SKColor(red: 0.65, green: 0.95, blue: 1.00, alpha: 1))
    guard let sprite else { return }
    let dash = SKAction.sequence([
        .moveBy(x: -30, y: 0, duration: 0.08),
        .wait(forDuration: 0.16),
        .moveBy(x: 30, y: 0, duration: 0.12)
    ])
    dash.timingMode = .easeOut
    sprite.run(dash)
    AudioEngine.shared.playStep()
    HapticsEngine.light()
}

private func showFloatingText(_ text: String, at position: CGPoint, color: SKColor) {
    let label = SKLabelNode(fontNamed: PixelUI.uiFont)
    label.text = text
    label.fontSize = 25
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

        AudioEngine.shared.setMood(moodBeforeCombat)
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

    statusEffectLabel.fontSize = 16
    statusEffectLabel.fontColor = SKColor(red: 0.55, green: 0.90, blue: 0.55, alpha: 1)
    statusEffectLabel.position = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.32)
    statusEffectLabel.zPosition = 930
    statusEffectLabel.alpha = 0
    root.addChild(statusEffectLabel)

    weaknessLabel.fontSize = 15
    weaknessLabel.fontColor = SKColor(red: 0.94, green: 0.86, blue: 0.62, alpha: 1)
    weaknessLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.695)
    weaknessLabel.zPosition = 920
    root.addChild(weaknessLabel)

    boostLabel.fontSize = 16
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

        // Décor d'arrière-plan : silhouettes selon la zone, dans une
        // couche qui dérive lentement (parallaxe subtile).
        let decorLayer = SKNode()
        floor.addChild(decorLayer)
        addBackgroundDecor(to: decorLayer, size: size, kind: enemyKind, palette: palette)
        let drift = SKAction.sequence([
            .moveBy(x: 6, y: 0, duration: 7.0),
            .moveBy(x: -6, y: 0, duration: 7.0)
        ])
        drift.timingMode = .easeInEaseOut
        decorLayer.run(.repeatForever(drift))

        // Nappe de brume au-dessus du décor, dérive en sens inverse
        let mist = SKSpriteNode(color: palette.haloColor.withAlphaComponent(0.16),
                                size: CGSize(width: size.width * 1.3, height: 46))
        mist.position = CGPoint(x: size.width / 2, y: size.height * 0.50)
        floor.addChild(mist)
        let mistDrift = SKAction.sequence([
            .moveBy(x: -18, y: 0, duration: 9.0),
            .moveBy(x: 18, y: 0, duration: 9.0)
        ])
        mistDrift.timingMode = .easeInEaseOut
        mist.run(.repeatForever(mistDrift))

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

        // Runes subtiles au sol (boss only) — losanges pixel, zéro glow.
        if isBoss {
            for dx: CGFloat in [-90, 0, 90] {
                let rune = SKSpriteNode(
                    color: SKColor(red: 0.85, green: 0.50, blue: 1, alpha: 0.7),
                    size: CGSize(width: 6, height: 6))
                rune.zRotation = .pi / 4
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
        case .beast, .wolf, .ghoul, .boneWalker:
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
        case .beast, .wolf, .ghoul, .boneWalker:
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

        // Alliés en retrait derrière Kael (profondeur 3/4, diagonale)
        let allySlots: [(x: CGFloat, y: CGFloat)] = [(0.13, 0.45), (0.10, 0.54)]
        for (i, ally) in allies.enumerated() {
            let node = CombatSprites.ally(kind: ally.kind)
            node.position = CGPoint(x: scene.size.width * allySlots[i].x,
                                    y: scene.size.height * allySlots[i].y)
            node.setScale(0.95)
            node.zPosition = 5.4 - CGFloat(i) * 0.1
            root.addChild(node)
            ally.sprite = node
            ally.home = node.position
        }

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

            e.statusIcons.position = CGPoint(x: node.position.x,
                                             y: node.position.y + 46)
            e.statusIcons.zPosition = 860
            root.addChild(e.statusIcons)
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
        for (i, ally) in allies.enumerated() {
            guard let node = ally.sprite else { continue }
            node.alpha = 0
            node.position = CGPoint(x: ally.home.x - 70, y: ally.home.y)
            node.run(.sequence([
                .wait(forDuration: 0.12 + Double(i) * 0.10),
                .group([
                    .fadeIn(withDuration: 0.35),
                    .move(to: ally.home, duration: 0.45)
                ])
            ]))
        }
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

    private func playActorAttackAnimation(on foe: EnemyState, strong: Bool = false) {
        guard let k = actorSprite else { return }
        let home = actorHomePosition
        let dx: CGFloat = strong ? 110 : 70
        let lungeIn = SKAction.move(to: CGPoint(x: home.x + dx, y: home.y),
                                    duration: 0.10)
        lungeIn.timingMode = .easeIn
        let lungeOut = SKAction.move(to: home, duration: 0.18)
        lungeOut.timingMode = .easeOut
        let tilt = SKAction.sequence([
            .rotate(toAngle: -0.15, duration: 0.08, shortestUnitArc: true),
            .rotate(toAngle: 0, duration: 0.16, shortestUnitArc: true)
        ])
        k.run(.group([.sequence([lungeIn, lungeOut]), tilt]))

        // Attaque forte : images rémanentes derrière la ruée
        if strong {
            for i in 0..<2 {
                guard let ghost = k.copy() as? SKNode else { break }
                ghost.alpha = 0.30 - CGFloat(i) * 0.10
                ghost.position = CGPoint(x: home.x + CGFloat(i) * 26, y: home.y)
                ghost.zPosition = k.zPosition - 0.1
                root.addChild(ghost)
                ghost.run(.sequence([
                    .wait(forDuration: 0.05 + Double(i) * 0.04),
                    .fadeOut(withDuration: 0.20),
                    .removeFromParent()
                ]))
            }
        }
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
        // Flash : applique aux SKSpriteNode descendants (pas les SKShape),
        // en restaurant la teinte d'origine (loup d'ombre = teinté).
        e.forEachDescendantSprite { sprite in
            let prevColor = sprite.color
            let prevFactor = sprite.colorBlendFactor
            sprite.run(.sequence([
                .colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
                .colorize(with: prevColor, colorBlendFactor: prevFactor, duration: 0.20)
            ]))
        }
    }

    private func playEnemyAttackAnimation(_ foe: EnemyState, isSpecial: Bool,
                                          victim: AllyState? = nil,
                                          dodged: Bool = false) {
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
        if !dodged { playAllyHitReact(victim: victim) }
    }

    private func playAllyHitReact(victim: AllyState? = nil) {
        guard let k = victim?.sprite ?? kaelSprite else { return }
        let recoil = SKAction.sequence([
            .moveBy(x: -18, y: 0, duration: 0.06),
            .moveBy(x: 18, y: 0, duration: 0.18)
        ])
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 0.65, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.20)
        ])
        k.run(recoil)
        k.forEachDescendantSprite { $0.run(flash) }
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
        statusLabel.fontSize = 16
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.645)
        root.addChild(statusLabel)
    }

    private func setupHPBars(scene: SKScene) {
        // Position des plates selon la taille du groupe (1 à 3 héros).
        let kaelXFrac: CGFloat
        let allyXFracs: [CGFloat]
        switch allies.count {
        case 0:  kaelXFrac = 0.28; allyXFracs = []
        case 1:  kaelXFrac = 0.18; allyXFracs = [0.42]
        default: kaelXFrac = 0.13; allyXFracs = [0.335, 0.54]
        }
        let kaelX = scene.size.width * kaelXFrac
        let enemyX = scene.size.width * (allies.count == 2 ? 0.80 : 0.72)
        let barY = scene.size.height * 0.78

        configureBar(kaelHPBack, kaelHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.40, green: 0.78, blue: 0.56, alpha: 1),
                     at: CGPoint(x: kaelX, y: barY), ghost: kaelHPGhost)
        // Plate de droite = CIBLE courante (nom + HP mis à jour au retarget)
        configureBar(enemyHPBack, enemyHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.82, green: 0.22, blue: 0.24, alpha: 1),
                     at: CGPoint(x: enemyX, y: barY), ghost: enemyHPGhost)

        kaelHPLabel.fontSize = 15
        kaelHPLabel.fontColor = .white
        kaelHPLabel.position = CGPoint(x: kaelX, y: barY - 18)
        root.addChild(kaelHPLabel)

        enemyHPLabel.fontSize = 15
        enemyHPLabel.fontColor = .white
        enemyHPLabel.position = CGPoint(x: enemyX, y: barY - 18)
        root.addChild(enemyHPLabel)

        addCombatantLabel("Kael", at: CGPoint(x: kaelX, y: barY + 16))

        // Plates des alliés : même gabarit, accent de leur couleur.
        let allyBarWidth = allies.count == 2 ? barWidth * 0.86 : barWidth
        for (i, ally) in allies.enumerated() {
            let x = scene.size.width * allyXFracs[i]
            configureBar(ally.hpBack, ally.hpFill,
                         width: allyBarWidth, height: barHeight,
                         color: ally.kind.accentColor,
                         at: CGPoint(x: x, y: barY), ghost: ally.hpGhost)
            ally.hpLabel.fontSize = 15
            ally.hpLabel.fontColor = .white
            ally.hpLabel.position = CGPoint(x: x, y: barY - 18)
            root.addChild(ally.hpLabel)
            addCombatantLabel(ally.combatant.name, at: CGPoint(x: x, y: barY + 16))
        }
        targetNameLabel.fontSize = 19
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
        targetMarker.lineWidth = 4
        targetMarker.lineCap = .butt
        targetMarker.lineJoin = .miter
        targetMarker.glowWidth = 0
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
        PixelUI.stylePanel(turnBanner, size: CGSize(width: 240, height: 30),
                           fill: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.92),
                           accent: SKColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 0.9))
        turnBanner.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 26)
        turnBanner.zPosition = 940
        turnBanner.alpha = 0
        root.addChild(turnBanner)

        turnBannerLabel.fontSize = 17
        turnBannerLabel.fontColor = .white
        turnBannerLabel.verticalAlignmentMode = .center
        turnBannerLabel.position = turnBanner.position
        turnBannerLabel.zPosition = 941
        turnBannerLabel.alpha = 0
        root.addChild(turnBannerLabel)

        // Trio : la file d'initiative monte au-dessus des noms pour ne
        // pas traverser les plates HP (4 plates = centre occupé).
        turnPipsRoot.position = CGPoint(x: scene.size.width / 2,
                                        y: scene.size.height * (allies.count == 2 ? 0.87 : 0.745))
        turnPipsRoot.zPosition = 935
        root.addChild(turnPipsRoot)
    }

    /// Anime la bannière au changement de tour.
    private func showTurnBanner(_ text: String, color: SKColor) {
        turnBannerLabel.text = text
        PixelUI.stylePanel(turnBanner, size: CGSize(width: 240, height: 30),
                           fill: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.92),
                           accent: color.withAlphaComponent(0.9))
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

        // -1 = Kael ; -2 - i = allié i ; n ≥ 0 = enemies[n] (vivants)
        let aliveIdx = enemies.indices.filter { enemies[$0].combatant.isAlive }
        var round: [Int] = [-1]
        for (i, ally) in allies.enumerated() where ally.combatant.isAlive {
            round.append(-2 - i)
        }
        round += aliveIdx
        guard !round.isEmpty else { return }
        // Décale la manche pour démarrer sur l'acteur courant
        let startPos: Int
        if let cur = currentEnemyIndex, let p = round.firstIndex(of: cur) {
            startPos = p
        } else if let i = actingAllyIndex, let p = round.firstIndex(of: -2 - i) {
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

            // Pip pixel : carré net, bord clair pour l'acteur courant.
            let side: CGFloat = isCurrent ? 20 : 15
            let pip = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                               width: side, height: side))
            pip.position = CGPoint(x: x0 + CGFloat(i) * spacing, y: 0)
            if isEnemy {
                pip.fillColor = SKColor(red: 0.42, green: 0.12, blue: 0.14, alpha: 0.95)
            } else if actor <= -2, allies.indices.contains(-2 - actor) {
                pip.fillColor = allies[-2 - actor].kind.accentColor
                    .withAlphaComponent(0.55)
            } else {
                pip.fillColor = SKColor(red: 0.12, green: 0.26, blue: 0.42, alpha: 0.95)
            }
            pip.strokeColor = isCurrent
                ? SKColor(red: 1.00, green: 0.92, blue: 0.55, alpha: 1)
                : SKColor(white: 0.45, alpha: 0.8)
            pip.lineWidth = isCurrent ? 2 : 1
            pip.glowWidth = 0
            if skipped { pip.alpha = 0.35 }
            turnPipsRoot.addChild(pip)

            let letter = SKLabelNode(fontNamed: PixelUI.uiFont)
            if skipped {
                letter.text = "✕"
            } else if isEnemy {
                let name = enemies[actor].combatant.name
                letter.text = String(name.prefix(1))
            } else if actor <= -2, allies.indices.contains(-2 - actor) {
                letter.text = String(allies[-2 - actor].kind.displayName.prefix(1))
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
    // Panneau compact façon menu SNES : une rangée de techniques par
    // acteur. Kael : ATTAQUE + FEU + AETHER. Lyra : ATTAQUE + GLACE +
    // FOUDRE + SOIN. `layoutActionMenu` répartit à chaque tour.
    let panelWidth = min(scene.size.width - 18, 288)
    actionPanelWidth = panelWidth
    let panelHeight: CGFloat = 54
    let panelY: CGFloat = 62

    PixelUI.stylePanel(actionPanel, size: CGSize(width: panelWidth, height: panelHeight),
                       fill: SKColor(red: 0.045, green: 0.038, blue: 0.045, alpha: 0.96),
                       accent: PixelUI.goldDim)
    actionPanel.position = CGPoint(x: scene.size.width / 2, y: panelY)
    actionPanel.zPosition = 850
    root.addChild(actionPanel)

    // Étiquette de l'acteur courant, posée sur le bord haut du panneau.
    actorTagLabel.fontSize = 12
    actorTagLabel.horizontalAlignmentMode = .left
    actorTagLabel.verticalAlignmentMode = .center
    actorTagLabel.position = CGPoint(x: scene.size.width / 2 - panelWidth / 2 + 8,
                                     y: panelY + panelHeight / 2)
    actorTagLabel.zPosition = 856
    actorTagLabel.isHidden = true
    root.addChild(actorTagLabel)

    // Création des 6 boutons (positions posées par layoutActionMenu)
    let buttonH: CGFloat = 32
    addButton(attackButton, title: String(localized: "combat.button.attack"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1), stroke: SKColor(white: 0.62, alpha: 1), fontSize: 12,
              chip: CombatElement.physical.color)
    addButton(fireButton, title: String(localized: "combat.button.fire"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.26, green: 0.07, blue: 0.03, alpha: 1), stroke: SKColor(red: 0.85, green: 0.38, blue: 0.18, alpha: 1), fontSize: 12,
              chip: CombatElement.fire.color)
    addButton(iceButton, title: String(localized: "combat.button.ice"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.03, green: 0.14, blue: 0.23, alpha: 1), stroke: SKColor(red: 0.42, green: 0.72, blue: 0.90, alpha: 1), fontSize: 12,
              chip: CombatElement.ice.color)
    addButton(blackSlashButton, title: String(localized: "combat.button.aether"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.17, green: 0.06, blue: 0.26, alpha: 1), stroke: SKColor(red: 0.62, green: 0.40, blue: 0.85, alpha: 1), fontSize: 12,
              chip: CombatElement.aether.color)
    addButton(lightningButton, title: String(localized: "combat.button.lightning"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.24, green: 0.18, blue: 0.03, alpha: 1), stroke: SKColor(red: 0.85, green: 0.70, blue: 0.25, alpha: 1), fontSize: 12,
              chip: CombatElement.lightning.color)
    addButton(healButton, title: String(localized: "combat.button.heal"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.03, green: 0.20, blue: 0.09, alpha: 1), stroke: SKColor(red: 0.38, green: 0.80, blue: 0.48, alpha: 1), fontSize: 12,
              chip: SKColor(red: 0.40, green: 0.95, blue: 0.60, alpha: 1))

    addButton(boostButton, title: String(localized: "combat.button.boost"), at: CGPoint(x: scene.size.width / 2 - 46, y: panelY + 56), width: 84, height: 22,
              fill: SKColor(red: 0.15, green: 0.09, blue: 0.24, alpha: 1), stroke: SKColor(red: 0.62, green: 0.48, blue: 0.82, alpha: 1), fontSize: 12)
    addButton(potionButton, title: String(localized: "combat.button.potion"), at: CGPoint(x: scene.size.width / 2 + 46, y: panelY + 56), width: 84, height: 22,
              fill: SKColor(red: 0.06, green: 0.18, blue: 0.11, alpha: 1), stroke: SKColor(red: 0.38, green: 0.75, blue: 0.48, alpha: 1), fontSize: 12)

    layoutActionMenu()

    // Curseur : cadre doré posé sur le bouton sélectionné
    PixelUI.stylePanel(selectionCursor, size: CGSize(width: 84, height: 36),
                       fill: .clear, accent: PixelUI.gold)
    selectionCursor.zPosition = 866
    root.addChild(selectionCursor)
    updateSelectionCursor()
}

/// Boutons de la rangée courante du curseur.
private var currentMenuRowButtons: [SKShapeNode] {
    menuRow == 1 ? [boostButton, potionButton] : currentActorButtons
}

/// Replace le cadre doré sur le bouton sélectionné (rangée cible :
/// le chevron au-dessus de l'ennemi sert déjà de curseur).
private func updateSelectionCursor() {
    if menuRow == 2 {
        selectionCursor.isHidden = true
        return
    }
    let row = currentMenuRowButtons
    guard !row.isEmpty else { selectionCursor.isHidden = true; return }
    menuCol = min(menuCol, row.count - 1)
    let button = row[menuCol]
    let size = button.frame.size
    PixelUI.stylePanel(selectionCursor,
                       size: CGSize(width: size.width + 6, height: size.height + 6),
                       fill: .clear, accent: PixelUI.gold)
    selectionCursor.position = button.position
    selectionCursor.isHidden = phase != .playerTurn
    selectionCursor.removeAllActions()
    JuiceEngine.pulse(selectionCursor, scale: 1.04)
}

/// Navigation joystick dans le menu de combat.
/// dy : +1 monte (techniques → BOOST → cible), -1 descend.
func menuNav(dx: Int, dy: Int) {
    guard phase == .playerTurn else { return }
    if dy != 0 {
        let maxRow = aliveEnemies.count > 1 ? 2 : 1
        menuRow = min(max(menuRow + dy, 0), maxRow)
        menuCol = min(menuCol, currentMenuRowButtons.count - 1)
    } else if dx != 0 {
        if menuRow == 2 {
            cycleTarget(direction: dx)
        } else {
            let count = currentMenuRowButtons.count
            menuCol = (menuCol + dx + count) % count
        }
    }
    HapticsEngine.light()
    AudioEngine.shared.playStep()
    updateSelectionCursor()
    updateVisuals()
}

/// Bouton A : active le bouton sélectionné (ou valide la cible).
func menuConfirm() {
    guard phase == .playerTurn else { return }
    if menuRow == 2 {
        // Cible choisie : redescend sur les techniques
        menuRow = 0
        updateSelectionCursor()
        return
    }
    let row = currentMenuRowButtons
    guard row.indices.contains(menuCol) else { return }
    let button = row[menuCol]
    if button === boostButton { applyBoost(); return }
    if button === potionButton {
        if (_player?.potions ?? 0) > 0 { perform(.potion) }
        return
    }
    if button === attackButton { perform(.attack); return }
    if button === blackSlashButton { perform(.blackSlash); return }
    if button === fireButton { perform(.spell(.ember)); return }
    if button === iceButton { perform(.spell(.frost)); return }
    if button === lightningButton { perform(.spell(.thunder)); return }
    if button === healButton { perform(.spell(.mend)); return }
}

/// Fait tourner la cible parmi les ennemis vivants.
private func cycleTarget(direction: Int) {
    let alive = enemies.indices.filter { enemies[$0].combatant.isAlive }
    guard alive.count > 1, let cur = alive.firstIndex(of: targetIndex) else { return }
    targetIndex = alive[(cur + direction + alive.count) % alive.count]
}

/// Boutons de techniques de l'acteur courant — kits complémentaires.
/// Kael : feu + Aether. Lyra : glace/foudre/soin. Écho de Lyra :
/// glace/soin. Eran : foudre + Aether.
private var currentActorButtons: [SKShapeNode] {
    switch actingAlly?.kind {
    case .lyra:     return [attackButton, iceButton, lightningButton, healButton]
    case .lyraEcho: return [attackButton, iceButton, healButton]
    case .eran:     return [attackButton, lightningButton, blackSlashButton]
    case nil:       return [attackButton, fireButton, blackSlashButton]
    }
}

/// Répartit la rangée de boutons de l'acteur courant dans le panneau,
/// masque ceux de l'autre acteur.
private func layoutActionMenu() {
    guard let scene = parentScene else { return }
    let visible = currentActorButtons
    let hidden = [attackButton, fireButton, iceButton,
                  blackSlashButton, lightningButton, healButton]
        .filter { !visible.contains($0) }
    hidden.forEach { $0.isHidden = true }

    let count = CGFloat(visible.count)
    let gap: CGFloat = 8
    let buttonW = (actionPanelWidth - 16 - gap * (count - 1)) / count
    let totalW = buttonW * count + gap * (count - 1)
    let startX = scene.size.width / 2 - totalW / 2 + buttonW / 2
    for (i, button) in visible.enumerated() {
        button.isHidden = false
        resizeButton(button, width: buttonW)
        button.position = CGPoint(x: startX + CGFloat(i) * (buttonW + gap),
                                  y: actionPanel.position.y)
    }
}

/// Redimensionne un bouton existant (repasse le style pixel, recadre
/// la pastille + le label à gauche).
private func resizeButton(_ node: SKShapeNode, width: CGFloat) {
    guard let label = node.children.compactMap({ $0 as? SKLabelNode }).first,
          let diamond = node.children.compactMap({ $0 as? SKSpriteNode }).first
    else { return }
    let stroke = node.strokeColor
    let fill = node.fillColor
    PixelUI.stylePanel(node, size: CGSize(width: width, height: 32),
                       fill: fill, accent: stroke)
    let chipSide: CGFloat = 7
    let contentW = label.frame.width + chipSide + 6
    label.position = CGPoint(x: -contentW / 2 + chipSide + 6, y: 0)
    diamond.position = CGPoint(x: -contentW / 2 + chipSide / 2, y: 0)
}

// MARK: - Helpers



    private func configureBar(_ back: SKShapeNode, _ fill: SKShapeNode,
                              width: CGFloat, height: CGFloat,
                              color: SKColor, at position: CGPoint,
                              ghost: SKShapeNode? = nil) {
        // Barres rectangulaires nettes — pas de bouts arrondis en pixel art.
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = CGPath(rect: rect, transform: nil)

        back.path = path
        back.fillColor = SKColor(white: 0.13, alpha: 1)
        back.strokeColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 0.9)
        back.lineWidth = 2
        back.position = position
        root.addChild(back)

        // Barre fantôme : blanche, fond après les dégâts (feedback juteux)
        if let ghost {
            ghost.path = path
            ghost.fillColor = SKColor(white: 0.92, alpha: 0.55)
            ghost.strokeColor = .clear
            ghost.position = position
            ghost.xScale = 1.0
            root.addChild(ghost)
        }

        fill.path = path
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.position = position
        fill.xScale = 1.0
        root.addChild(fill)
    }

    /// Barre fantôme : suit la vraie barre avec un temps de retard quand
    /// les PV baissent ; se cale instantanément quand ils remontent.
    private func updateGhostBar(_ ghost: SKShapeNode, to ratio: CGFloat) {
        if ratio >= ghost.xScale - 0.001 {
            ghost.removeAllActions()
            ghost.xScale = ratio
            return
        }
        ghost.removeAllActions()
        let melt = SKAction.scaleX(to: ratio, duration: 0.35)
        melt.timingMode = .easeOut
        ghost.run(.sequence([.wait(forDuration: 0.30), melt]))
    }

    /// Pictos de statut persistants au-dessus d'un ennemi : brûlure
    /// (flamme), gel/paralysie (éclair), garde brisée (bouclier fêlé).
    /// Reconstruits à chaque updateVisuals — 3 pictos max, coût nul.
    private func refreshStatusIcons(for e: EnemyState) {
        e.statusIcons.removeAllChildren()
        guard e.combatant.isAlive else { return }

        var icons: [SKNode] = []
        if let status = e.combatant.statusEffect {
            let palette: [SKColor] = status == .aetherBurn
                ? [SKColor(red: 1.00, green: 0.58, blue: 0.16, alpha: 1),
                   SKColor(red: 0.88, green: 0.24, blue: 0.06, alpha: 1)]
                : [SKColor(red: 0.45, green: 0.90, blue: 0.40, alpha: 1),
                   SKColor(red: 0.20, green: 0.60, blue: 0.25, alpha: 1)]
            icons.append(Self.makeFlameIcon(palette: palette,
                                            ticks: e.combatant.statusTicks))
        }
        if e.combatant.stunned {
            icons.append(Self.makeBoltIcon())
        }
        if e.brokenTurns > 0 {
            icons.append(Self.makeBrokenShieldIcon())
        }
        guard !icons.isEmpty else { return }

        let spacing: CGFloat = 16
        let x0 = -spacing * CGFloat(icons.count - 1) / 2
        for (i, icon) in icons.enumerated() {
            icon.position = CGPoint(x: x0 + CGFloat(i) * spacing, y: 0)
            e.statusIcons.addChild(icon)
            JuiceEngine.pulse(icon, scale: 1.12)
        }
    }

    /// Flamme pixel (3 carrés étagés) + pips de tours restants.
    private static func makeFlameIcon(palette: [SKColor], ticks: Int) -> SKNode {
        let icon = SKNode()
        let base = SKSpriteNode(color: palette[1], size: CGSize(width: 8, height: 6))
        icon.addChild(base)
        let mid = SKSpriteNode(color: palette[0], size: CGSize(width: 6, height: 5))
        mid.position = CGPoint(x: 0, y: 5)
        icon.addChild(mid)
        let tip = SKSpriteNode(color: palette[0], size: CGSize(width: 3, height: 4))
        tip.position = CGPoint(x: 1, y: 9)
        icon.addChild(tip)
        // Pips : tours de statut restants (1 pixel par tick)
        for t in 0..<min(ticks, 3) {
            let pip = SKSpriteNode(color: .white, size: CGSize(width: 2, height: 2))
            pip.position = CGPoint(x: CGFloat(t) * 3 - 3, y: -6)
            icon.addChild(pip)
        }
        return icon
    }

    /// Éclair pixel jaune : gel / paralysie (tour sauté).
    private static func makeBoltIcon() -> SKNode {
        let icon = SKNode()
        let yellow = SKColor(red: 1.00, green: 0.88, blue: 0.30, alpha: 1)
        for (dx, dy, w, h) in [(1.5, 6.0, 5.0, 4.0), (-0.5, 2.0, 5.0, 4.0),
                               (1.0, -2.0, 5.0, 4.0), (-1.5, -6.0, 4.0, 4.0)] {
            let seg = SKSpriteNode(color: yellow, size: CGSize(width: w, height: h))
            seg.position = CGPoint(x: dx, y: dy)
            icon.addChild(seg)
        }
        return icon
    }

    /// Bouclier fêlé doré : garde brisée (BREAK).
    private static func makeBrokenShieldIcon() -> SKNode {
        let icon = SKNode()
        let gold = SKColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1)
        let dark = SKColor(red: 0.35, green: 0.25, blue: 0.05, alpha: 1)
        let body = SKSpriteNode(color: gold, size: CGSize(width: 10, height: 10))
        icon.addChild(body)
        let point = SKSpriteNode(color: gold, size: CGSize(width: 6, height: 3))
        point.position = CGPoint(x: 0, y: -6)
        icon.addChild(point)
        // Fissure : marches sombres en diagonale
        for (dx, dy) in [(-2.0, 3.0), (0.0, 0.0), (2.0, -3.0)] {
            let crack = SKSpriteNode(color: dark, size: CGSize(width: 2, height: 4))
            crack.position = CGPoint(x: dx, y: dy)
            icon.addChild(crack)
        }
        return icon
    }

    private func addCombatantLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 19
        label.fontColor = .white
        label.position = position
        root.addChild(label)
    }

    private func addSmallLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 13
        label.fontColor = SKColor(white: 0.6, alpha: 1)
        label.position = position
        root.addChild(label)
    }

    private func addButton(_ node: SKShapeNode, title: String, at position: CGPoint,
                           width: CGFloat, height: CGFloat,
                           fill: SKColor, stroke: SKColor,
                           fontSize: CGFloat = 14,
                           chip: SKColor? = nil) {
        node.removeAllChildren()
        PixelUI.stylePanel(node, size: CGSize(width: width, height: height),
                           fill: fill, accent: stroke)
        node.position = position
        node.zPosition = 860

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = title
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        // Pastille d'élément : losange pixel net à gauche du texte.
        if let chip {
            label.horizontalAlignmentMode = .left
            let textW = label.frame.width
            let chipSide: CGFloat = 7
            let contentW = textW + chipSide + 6
            label.position = CGPoint(x: -contentW / 2 + chipSide + 6, y: 0)

            let diamond = SKSpriteNode(color: chip,
                                       size: CGSize(width: chipSide, height: chipSide))
            diamond.zRotation = .pi / 4
            diamond.position = CGPoint(x: -contentW / 2 + chipSide / 2, y: 0)
            node.addChild(diamond)
        }

        root.addChild(node)
    }

    private func updateVisuals() {
        let kaelHPRatio = max(0.02, CGFloat(kael.hp) / CGFloat(kael.maxHP))
        kaelHPFill.xScale = kaelHPRatio
        kaelHPLabel.text = String(kael.hp) + "/" + String(kael.maxHP)
        updateGhostBar(kaelHPGhost, to: kaelHPRatio)

        for ally in allies {
            let c = ally.combatant
            let ratio = max(0.02, CGFloat(c.hp) / CGFloat(c.maxHP))
            ally.hpFill.xScale = ratio
            ally.hpLabel.text = String(c.hp) + "/" + String(c.maxHP)
            updateGhostBar(ally.hpGhost, to: ratio)
        }

        // Étiquette d'acteur sur le panneau d'actions (qui joue ?)
        if let ally = actingAlly {
            actorTagLabel.text = "◆ " + ally.kind.displayName.uppercased()
            actorTagLabel.fontColor = ally.kind.accentColor
        } else {
            actorTagLabel.text = "◆ KAEL"
            actorTagLabel.fontColor = SKColor(red: 0.62, green: 0.82, blue: 1.00, alpha: 1)
        }
        actorTagLabel.isHidden = allies.isEmpty
            || !(phase == .playerTurn || phase == .playerActing)

        // Plate de droite = cible courante
        if let foe = target {
            let c = foe.combatant
            let enemyRatio = max(0.02, CGFloat(c.hp) / CGFloat(c.maxHP))
            enemyHPFill.xScale = enemyRatio
            // Changement de cible : la barre fantôme saute sans animer
            if lastTargetIndexForGhost != targetIndex {
                lastTargetIndexForGhost = targetIndex
                enemyHPGhost.removeAllActions()
                enemyHPGhost.xScale = enemyRatio
            } else {
                updateGhostBar(enemyHPGhost, to: enemyRatio)
            }
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
            refreshStatusIcons(for: e)
        }

        let ready = phase == .playerTurn && kael.isAlive && !aliveEnemies.isEmpty
        for button in [attackButton, blackSlashButton, fireButton, iceButton, lightningButton, healButton] {
            button.alpha = ready ? 1 : 0.36
        }
        selectionCursor.isHidden = !ready || menuRow == 2
        boostButton.alpha = (ready && playerBP > 0 && queuedBoost < 3) ? 1 : 0.34
        let potionCount = _player?.potions ?? 0
        potionButton.alpha = (ready && potionCount > 0) ? 1 : 0.34
        if let label = potionButton.children.compactMap({ $0 as? SKLabelNode }).first {
            label.text = String(localized: "combat.button.potion") + " ×" + String(potionCount)
        }

        let bpPips = (0..<3).map { $0 < playerBP ? "●" : "○" }.joined()
        if queuedBoost > 0 {
            boostLabel.text = "BP " + bpPips + "   "
                + String(localized: "combat.status.boost \(queuedBoost + 1)")
        } else if bpRecharging {
            boostLabel.text = "BP " + bpPips + "   "
                + String(localized: "combat.boost.recharging")
        } else {
            boostLabel.text = "BP " + bpPips
        }

        if statusLabel.text?.isEmpty ?? true {
            statusLabel.text = String(localized: "combat.status.battleStart")
        }
    }
}

