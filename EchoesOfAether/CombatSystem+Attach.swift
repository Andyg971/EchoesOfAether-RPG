import SpriteKit

// CombatSystem — ouverture d'un combat : attach (mono/multi-ennemis), fondu d'intro, tactiques par espèce.
extension CombatSystem {
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
