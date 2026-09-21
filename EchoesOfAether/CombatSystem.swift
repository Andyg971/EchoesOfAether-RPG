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
    var tempestMaxUses: Int { CombatMath.tempestMaxUses(hasTwinTempest: _player?.hasTwinTempest == true) }
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
// Le multiplicateur BREAK vit dans CombatMath.brokenMultiplier — une seule
// source de vérité, testée.
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

}
