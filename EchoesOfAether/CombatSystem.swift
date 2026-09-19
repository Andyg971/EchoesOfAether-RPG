import SpriteKit

@MainActor
final class CombatSystem {
    let root = SKNode()
    let statusLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // HP bars
    let kaelHPBack = SKShapeNode()
    let kaelHPFill = SKShapeNode()
    let kaelHPGhost = SKShapeNode()   // « dégâts fantômes » qui fondent
    let kaelHPLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    // Barre de Points de Magie (Kael) : alimente sorts + Black Slash.
    let kaelMPBack = SKShapeNode()
    let kaelMPFill = SKShapeNode()
    let kaelMPLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    let enemyHPBack = SKShapeNode()
    let enemyHPFill = SKShapeNode()
    let enemyHPGhost = SKShapeNode()
    var lastTargetIndexForGhost = -1
    let enemyHPLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let targetNameLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    /// Faiblesses (losanges d'élément) + bouclier (pips) de la cible.
    /// Reconstruit à chaque changement — voir `refreshTargetInfoRow`.
    let targetInfoRow = SKNode()
    /// Dernier état rendu, pour ne pas reconstruire la rangée à chaque frame.
    var lastTargetInfoKey = ""

    // Tour par tour
    enum TurnPhase { case intro, playerTurn, playerActing, enemyTurn, finished }
    enum TurnActor { case player, enemy }
    var phase: TurnPhase = .intro
    let turnBanner = SKShapeNode(rectOf: CGSize(width: 240, height: 30), cornerRadius: 15)
    let turnBannerLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let turnPipsRoot = SKNode()

    // Buttons
let attackButton = SKShapeNode(rectOf: CGSize(width: 150, height: 54), cornerRadius: 16)
let blackSlashButton = SKShapeNode(rectOf: CGSize(width: 190, height: 54), cornerRadius: 16)
let fireButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let iceButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let lightningButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let healButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
/// Bénédiction — sort signature de Lyra (nova sacrée, soin de groupe).
let blessingButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
/// TEMPÊTE — l'ultime de Kael, une fois par combat.
let tempestButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
/// Techniques d'Eran : bourrasque (vent) et lame ardente (feu).
let windButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let emberButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let boostButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let potionButton = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 10)
let boostLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
let breakLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Sprites combattants (refonte UI : on doit voir les personnages se battre)
    var kaelSprite: SKNode?
    var kaelHomePosition: CGPoint = .zero
    var arenaFloor: SKNode?

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
        let mpBack = SKShapeNode()
        let mpFill = SKShapeNode()
        let mpLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

        init(kind: CombatAllyKind, level: Int) {
            self.kind = kind
            let hp = kind.maxHP(level: level)
            // Les alliés ont leur propre réserve de Magie. Elle dépend de ce
            // qu'ils sont : Lyra canalise le sacré à longueur de journée,
            // Eran est un homme d'acier — sa magie tient dans sa lame.
            let mp = kind.maxMP(level: level)
            self.combatant = Combatant(name: kind.displayName, maxHP: hp, hp: hp,
                                       mp: mp, maxMP: mp)
        }
    }

    var allies: [AllyState] = []
    /// nil = Kael agit ; sinon index de l'allié en train d'agir.
    var actingAllyIndex: Int?
    var actingAlly: AllyState? {
        actingAllyIndex.flatMap { allies.indices.contains($0) ? allies[$0] : nil }
    }
    var aliveAllies: [AllyState] { allies.filter { $0.combatant.isAlive } }
    /// Position d'origine de l'acteur en train d'agir (FX des sorts).
    var actorHomePosition: CGPoint {
        actingAlly?.home ?? kaelHomePosition
    }
    var actorSprite: SKNode? { actingAlly?.sprite ?? kaelSprite }
    // Étiquette de l'acteur courant sur le panneau d'actions
    let actorTagLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let actionPanel = SKShapeNode()
    var actionPanelWidth: CGFloat = 288
    // Curseur de sélection (contrôles classiques, zéro tactile) :
    // rangée 0 = techniques, rangée 1 = BOOST/POTION, rangée 2 = cible.
    /// Soin en attente d'une cible : le joueur a choisi SOIN, il doit
    /// maintenant désigner qui soigner. `nil` = pas en mode ciblage de soin.
    /// Avant, le soin partait tout seul sur le membre le plus blessé — le
    /// joueur ne décidait rien.
    // ── Parade au timing ──
    /// Fenêtre ouverte : un appui sur A pare le coup en cours.
    var blockArmed = false
    /// Le joueur a appuyé dans la fenêtre.
    var blockPressed = false
    /// Appui hors fenêtre : la parade est brûlée pour ce coup. C'est ce qui
    /// empêche de marteler A à l'aveugle.
    var blockBurned = false
    /// Le « ! » affiché au-dessus de l'ennemi qui s'annonce.
    var blockPrompt: SKLabelNode?

    // ── Frappe au timing (pendant du bloc, côté offensif) ──
    /// L'action est lancée : l'élan court, A est capté par la frappe et non
    /// par le menu. Le combat cesse d'être un menu passif : chaque coup se
    /// mérite (modèle Sea of Stars).
    var strikeWindupActive = false
    /// Fenêtre ouverte : un appui sur A décuple le coup.
    var strikeArmed = false
    /// Le joueur a appuyé dans la fenêtre.
    var strikePressed = false
    /// Appui trop tôt : le bonus est brûlé pour ce coup (interdit le matraquage).
    var strikeBurned = false
    /// Le repère lumineux affiché au-dessus de l'acteur pendant l'élan.
    var strikePrompt: SKLabelNode?
    /// La Tempête est un atout rare : une seule fois par combat, deux avec
    /// le capstone TEMPÊTE JUMELLE (voie de l'Aether).
    var tempestUses = 0
    var tempestMaxUses: Int { _player?.hasTwinTempest == true ? 2 : 1 }
    var tempestSpent: Bool { tempestUses >= tempestMaxUses }
    /// DERNIER SOUFFLE : le sursis ne joue qu'une fois par combat.
    var lastBreathUsed = false

    var pendingHealSpell: CombatSpell?
    var healTargetIndex = 0
    /// Cible validée, lue par le cas `.mend` de `perform`. nil = pas de
    /// choix explicite, on retombe sur l'ancien automatisme.
    var chosenHealIndex: Int?
    var menuRow = 0
    var menuCol = 0
    let selectionCursor = SKShapeNode()

    /// État complet par ennemi : stats, tactique (faiblesses/bouclier)
    /// et nœuds UI (sprite, minibar HP).
    @MainActor
    final class EnemyState {
        var combatant: Combatant
        let kind: CombatSpriteKind
        var weaknesses: Set<CombatElement>
        var shield: Int
        var shieldMax: Int
        var brokenTurns = 0
        var sprite: SKNode?
        var homePosition: CGPoint = .zero
        let statusIcons = SKNode()   // pictos brûlure/gel/break persistants
        /// VERROUS du grand coup : le boss annonce sa spéciale une manche à
        /// l'avance et se couvre de sceaux élémentaires. Les briser tous
        /// avant qu'il frappe annule le coup et l'expose (modèle Sea of Stars).
        var specialLocks: [CombatElement] = []
        /// Nombre de verrous posés à l'annonce (0 = aucune spéciale en charge).
        var specialLockTotal = 0
        /// Rangée de sceaux affichée au-dessus de l'ennemi.
        let lockIcons = SKNode()

        init(spec: EnemySpec, weaknesses: Set<CombatElement>, shieldMax: Int) {
            self.combatant = Combatant(name: spec.name, maxHP: spec.hp,
                                       hp: spec.hp, baseDamage: spec.baseDamage)
            self.kind = spec.kind
            self.weaknesses = weaknesses
            self.shield = shieldMax
            self.shieldMax = shieldMax
        }
    }

    var kael = Combatant(name: "Kael", maxHP: 280, hp: 280)
    var enemies: [EnemyState] = []
    var targetIndex = 0
    let targetMarker = SKShapeNode()
var resonance = 0
var playerBP = 0
var queuedBoost = 0
/// Payoff du Break (façon Octopath) : un ennemi au bouclier cassé subit
/// bien plus de dégâts de TOUTE source pendant qu'il est à terre. C'est la
/// récompense qui rend le ciblage des faiblesses + la décharge du Boost
/// vraiment satisfaisants. Auparavant seuls les sorts avaient un maigre
/// bonus (×1.25) ; l'attaque et le Black Slash n'en avaient aucun.
static let brokenDamageMultiplier: CGFloat = 1.8
/// Facteur de menace global des attaques ennemies normales : > 1 rend les
/// monstres plus dangereux (le joueur galère, doit utiliser ses options).
/// Réglable d'un seul endroit après playtests.
static let enemyDamageScale: CGFloat = 1.5
/// Facteur de robustesse global : les ennemis encaissent davantage → les
/// combats durent plus (Andy les trouvait « trop rapides / trop faciles »).
static let enemyHPScale: CGFloat = 1.4
/// Couleur du dégât flottant quand le coup profite du bonus Break :
/// ambre vif, pour que le joueur SENTE le moment de décharger.
static let brokenHitColor = SKColor(red: 1.0, green: 0.66, blue: 0.15, alpha: 1)
/// Règle du Boost (façon Octopath) : booster épuise le flux — aucun BP
/// ne se régénère à la manche suivante.
var boostedThisRound = false
var bpRecharging = false
var goldReward = 0
    var completion: ((Int, Int) -> Void)?
    weak var parentScene: SKScene?

    /// Compteur d'attaques par lanceur : sert à faire tourner les éléments
    /// d'une attaque simple (glace, puis foudre, puis glace…).
    var spellCycle: [ObjectIdentifier: Int] = [:]
    var _player: PlayerState?

    // Audit visuel des sorts (--fx-demo)
    var fxDemoIndex = 0
    // Ambiance musicale à restaurer en quittant l'arène
    var moodBeforeCombat: AudioEngine.MusicMood = .calm

    // Combo
    var comboCount = 0
    let comboLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Status effect label
    let statusEffectLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    // Boss
    var bossConfig: BossConfig?
    var isEnraged = false
    var enemyTurnCount = 0
    let enrageLabel = SKLabelNode(fontNamed: PixelUI.uiFont)

    let barWidth: CGFloat = 140
    let barHeight: CGFloat = 14

    var isActive: Bool { root.parent != nil }

    /// Cible courante des actions du joueur.
    var target: EnemyState? {
        enemies.indices.contains(targetIndex) ? enemies[targetIndex] : nil
    }
    var aliveEnemies: [EnemyState] {
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
        // Frappe au timing : aucun élan résiduel d'un combat précédent.
        root.removeAction(forKey: "timedStrike")
        closeStrikeWindow()

        // New Game+ : les ennemis encaissent et frappent plus fort à chaque
        // relance (+45 % PV, +30 % dégâts par palier). La progression conservée
        // du joueur compense ; la difficulté reste devant lui.
        let ngp = max(0, player.newGamePlus)
        // Difficulté choisie par le joueur, relue à CHAQUE combat : on peut
        // redescendre devant un boss sans recommencer la partie.
        let difficulty = Difficulty.current
        // Robustesse de base (tous combats) × réglage joueur × bonus New Game+.
        let hpMult = Double(Self.enemyHPScale)
            * difficulty.enemyHPMultiplier
            * (1.0 + 0.45 * Double(ngp))
        let dmgMult = difficulty.enemyDamageMultiplier * (1.0 + 0.30 * Double(ngp))
        self.enemies = enemySpecs.prefix(3).map { spec in
            let scaled = EnemySpec(
                name: spec.name,
                hp: Int((Double(spec.hp) * hpMult).rounded()),
                kind: spec.kind,
                baseDamage: Int((Double(spec.baseDamage) * dmgMult).rounded()))
            let tactics = Self.tactics(for: scaled.kind, isBoss: boss != nil)
            return EnemyState(spec: scaled, weaknesses: tactics.weaknesses,
                              shieldMax: tactics.shieldMax)
        }
        self.targetIndex = 0
        self.tempestUses = 0
        self.lastBreathUsed = false
        // Compteurs de sprites remis à zéro : l'enchaînement d'attaques des
        // packs, et surtout la teinte de l'Archiviste. Sans ça il rouvrait le
        // combat dans la couleur où le précédent s'était arrêté — on tombait
        // sur un boss violet d'entrée, sa montée en puissance déjà jouée.
        CombatSprites.resetChains()

let startHP = min(player.currentHP, player.currentMaxHP)
        self.kael = Combatant(name: "Kael", maxHP: player.currentMaxHP, hp: startHP,
                              mp: player.maxMP, maxMP: player.maxMP)
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
        // Musique, restaurée à la fin : chaque boss a SON thème ; les combats
        // ordinaires alternent entre trois pistes pour ne pas lasser.
        moodBeforeCombat = AudioEngine.shared.currentMood
        if let boss {
            AudioEngine.shared.setMood(boss.music)
        } else {
            AudioEngine.shared.setCombatMood()
        }
        // Bestiaire : toute espèce affrontée est consignée.
        player.bestiarySeen.formUnion(enemySpecs.prefix(3).map(\.kind.bestiaryID))

        root.removeFromParent()
        root.removeAllChildren()
        // Posé une fois, pour la durée de l'intro. `updateVisuals` le remettait
        // dès que le label était vide — un repli inoffensif tant que la ligne
        // portait le rappel des touches et n'était donc jamais vide. Depuis
        // qu'elle l'est entre deux actions, ce repli annonçait « Le combat
        // commence… » à chaque tour, y compris au douzième.
        statusLabel.text = String(localized: "combat.status.battleStart")
        statusEffectLabel.text = ""
        boostLabel.text = ""
        breakLabel.alpha = 0
        // `root.removeAllChildren` a détaché la rangée : sans reset, la clé
        // ferait croire qu'elle est encore à l'écran au combat suivant.
        targetInfoRow.removeAllChildren()
        lastTargetInfoKey = ""
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
    func playBattleIntroDissolve(scene: SKScene) {
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
}
