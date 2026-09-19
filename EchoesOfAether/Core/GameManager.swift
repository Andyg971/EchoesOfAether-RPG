import SpriteKit

@MainActor
final class GameManager {
    var state: GameState = .exploration   // setter ouvert : `transition(to:)` vit dans une extension
    var phase: GamePhase = .wake {
        didSet {
            // Chaque zone a son ambiance musicale (cross-fade automatique).
            AudioEngine.shared.setMood(.forPhase(phase))
        }
    }

    let world     = WorldBuilder()
    let hud       = HUDOverlay()
    let dialogue  = DialogueSystem()
    let combat    = CombatSystem()
    let movement  = MovementController()
    let shop      = ShopOverlay()
    let inventory = InventoryOverlay()
    let pause     = PauseOverlay()
    let death     = DeathOverlay()
    let options   = OptionsOverlay()
    let lore      = LoreOverlay()
    let questLog  = QuestLogOverlay()
    let minimap   = MinimapOverlay()
    let worldMap  = WorldMapOverlay()
    let levelUp   = LevelUpOverlay()
    let skills    = SkillTreeOverlay()
    let bubble    = InteractionBubble()
    let tutorial  = TutorialOverlay()
    let paywall   = PaywallOverlay()
    let player    = PlayerState()

    var onReturnToMenu: (() -> Void)?

    /// Slot de sauvegarde actif (injecté au démarrage par la scène).
    var activeSlot: Int = 1
    /// Graine New Game+ en attente (fournie par le menu à `setup`).
    var pendingNewGamePlusSeed: NewGamePlusSeed?

    // Membres accédés par les extensions de domaine (GameManager+*.swift) :
    // `internal` plutôt que `private` pour un découpage multi-fichiers.
    weak var scene: SKScene?
    var resonanceTotal = 0
    var lastCombatStarter: (() -> Void)?   // pour le bouton Réessayer
    /// Suite du récit mise en attente pendant que le mur d'achat est ouvert.
    var pendingUnlockAction: (() -> Void)?

    /// Lyra combat aux côtés de Kael dans les zones du pacte (tant qu'elle
    /// vit) — sauf aux mines : elle l'a annoncé elle-même en y entrant
    /// (« Je garde l'entrée. Si ça tourne mal, tu cries. Promis ? »,
    /// dialogue.mines.enter.lyra1). La suivre dans la galerie contredisait
    /// sa propre réplique.
    var lyraInParty: Bool {
        [.forest, .shrine, .ruins].contains(phase) && !player.lyraDeceased && !inMines
    }

    /// Trio de l'Acte III : l'Écho de Lyra puis Eran rejoignent Kael.
    var act3Party: [CombatAllyKind] {
        var kinds: [CombatAllyKind] = []
        if player.act3EchoJoined { kinds.append(.lyraEcho) }
        if player.act3EranMet { kinds.append(.eran) }
        return kinds
    }
    var prologueNode: SKNode?              // cinématique d'ouverture
    var prologueCompletion: (() -> Void)?
    // Joystick virtuel flottant
    let padBase = SKShapeNode(circleOfRadius: 34)
    let padKnob = SKShapeNode(circleOfRadius: 15)
    // Bouton d'action « A » (bas-droite) : déclenche l'interaction à portée.
    // Plus fiable que taper précisément sur le PNJ/POI.
    let actionButton = SKShapeNode()
    let actionButtonLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    // Bouton « B » : annuler / passer / fermer (contrôles classiques).
    let bButton = SKShapeNode()
    let bButtonLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    var nearbyActionPoint: CGPoint?   // POI courant (coords monde)
    /// Monstres baladeurs de la zone courante (mines, caverne) : patrouillent
    /// et chargent Kael au contact pour déclencher le combat.
    var roamers: [RoamingMonster] = []
    var padActive = false
    var padOrigin = CGPoint.zero
    var padVector = CGVector.zero
    var hintUpdateTimer: TimeInterval = 0
    var minimapTimer: TimeInterval = 0
    var corruptionCinematicShown = false
    var activeInterior: HouseInteriorKind?
    /// Vrai quand Kael est dans les mines de Cendreval (excursion depuis
    /// la forêt — pas une GamePhase : la save garde phase = .forest).
    var inMines = false
    /// Vrai quand Kael arpente la carte du monde (overworld façon FF7) :
    /// il marche entre les lieux, y entre au bouton A, croise des rôdeurs.
    var inOverworld = false
    /// Lieu de l'overworld à portée du bouton A (nil = aucun).
    var overworldTarget: String?
    /// Coffre de la carte à portée du bouton A (nil = aucun).
    var overworldChestTarget: String?
    /// Vrai pendant une prise au lac (fige le déplacement, capte le bouton A).
    var isFishing = false
    /// Le poisson mord : la fenêtre pour ferrer est ouverte.
    var fishingHookable = false
    /// La prise est jouée (évite qu'un timer en retard la rejoue).
    var fishingResolved = false
    /// Vrai quand Kael est au bord du lac, à portée de pêche.
    var fishingSpotInRange = false
    /// Position de Kael sur la carte avant un combat, pour l'y remettre après.
    var overworldReturnPos: CGPoint?
    /// Lieux déjà visités (voyage rapide déverrouillé). S'ajoute à la
    /// découverte dérivée de la progression d'histoire.
    var discoveredPlaces: Set<String> = []
    /// Vrai quand Kael est dans le désert d'Ossara (voyage via la carte
    /// du monde — pas une GamePhase : la save garde la phase d'origine).
    var inDesert = false
    /// Vrai quand Kael explore la Caverne aux Échos (donjon optionnel,
    /// entrée dans la forêt — pas une GamePhase, comme les mines).
    var inCave = false
    /// Vrai quand Kael revisite la forêt DEPUIS LA CARTE alors que l'histoire
    /// est déjà passée à l'Acte II ou plus loin. Contrairement aux mines/la
    /// caverne (des excursions posées PENDANT la phase .forest, qui ne la
    /// changent donc pas), entrer en forêt depuis la carte forçait
    /// `phase = .forest` sans condition — et l'Acte II ne repartait jamais :
    /// un aller simple hors de son propre acte. Ce flag permet de router les
    /// interactions/rôdeurs de la forêt sans toucher à `phase`.
    var inForest = false

    // Rapatriées depuis les extensions (Swift interdit les propriétés
    // stockées hors du type) :
    var menuNavLatched = false
    /// Chasses optionnelles (ghoul/bone) vaincues durant la visite courante
    /// de la forêt : évite qu'elles rechargent Kael en boucle. Remis à zéro
    /// à chaque nouvelle entrée en forêt (`showForest`).
    var forestHuntsCleared: Set<String> = []
    /// Rôdeurs de la CARTE DU MONDE déjà vaincus : un monstre battu ne
    /// réapparaît pas au retour du combat (sinon il ressuscitait pile sur
    /// Kael et le rechargeait aussitôt — combats en boucle). Remis à zéro
    /// à chaque arrivée fraîche sur la carte (`enterOverworld`).
    var overworldRoamersCleared: Set<String> = []
    var lastLayout: (size: CGSize, top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)?
}
