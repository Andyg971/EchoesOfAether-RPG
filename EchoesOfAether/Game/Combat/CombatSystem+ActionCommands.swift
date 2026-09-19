import SpriteKit

// Commandes d'action au timing : parade, frappe parfaite, verrous du grand coup de boss.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Parade au timing

    /// Temps d'annonce avant le bond : c'est la fenêtre de réaction du joueur.
    /// 0,42 s — assez pour voir et répondre, trop court pour réfléchir.
    static let telegraphDuration: TimeInterval = 0.42
    /// Durée du bond, de l'annonce à l'impact.
    static let lungeDuration: TimeInterval = 0.14

    /// Ouvre la fenêtre. Elle reste ouverte pendant l'annonce ET le bond :
    /// on peut parer dès qu'on voit venir, jusqu'au contact.
    func openBlockWindow() {
        blockArmed = true
        blockPressed = false
        blockBurned = false
    }

    /// Referme et dit si la parade est réussie.
    @discardableResult
    func closeBlockWindow() -> Bool {
        let ok = blockPressed && !blockBurned
        blockArmed = false
        blockPressed = false
        blockBurned = false
        blockPrompt?.removeFromParent()
        blockPrompt = nil
        return ok
    }

    // MARK: - Frappe au timing (action command offensive)

    /// Délai d'élan avant l'ouverture de la fenêtre : le joueur doit ATTENDRE
    /// le bon moment, pas appuyer d'avance.
    static let strikeWindup: TimeInterval = 0.26
    /// Durée de la fenêtre — même exigence que la parade.
    static let strikeWindow: TimeInterval = 0.38
    // Le bonus de frappe vit dans CombatMath.strikeBonus.

    /// Les actions qui se méritent au timing (offensives uniquement : ni
    /// potion, ni soin, ni bénédiction).
    func usesTimedStrike(_ action: CombatAction) -> Bool {
        switch action {
        case .attack, .blackSlash:
            return true
        case .potion:
            return false
        case .spell(let spell):
            return spell != .mend && spell != .blessing
        }
    }

    /// Point d'entrée UNIQUE des actions choisies par le joueur : les actions
    /// offensives passent par la frappe au timing, les autres partent
    /// directement. Les MP sont vérifiés avant l'élan pour ne pas faire jouer
    /// une animation qui finirait en « Magie insuffisante ».
    func execute(_ action: CombatAction) {
        guard phase == .playerTurn, !strikeWindupActive else { return }
        let cost = mpCost(for: action)
        let actorMP = actingAlly?.combatant.mp ?? kael.mp
        if cost > 0, actorMP < cost {
            showEffect(String(localized: "combat.mp.insufficient"),
                       color: Palette.frost)
            AudioEngine.shared.playTap()
            return
        }
        if usesTimedStrike(action) {
            beginTimedStrike(action)
        } else {
            perform(action)
        }
    }

    /// Lance l'élan : repère au-dessus de l'acteur, fenêtre qui s'ouvre puis
    /// se referme, et enfin l'action résolue avec (ou sans) le bonus.
    func beginTimedStrike(_ action: CombatAction) {
        strikeWindupActive = true
        strikeArmed = false
        strikePressed = false
        strikeBurned = false
        showStrikePrompt()

        root.run(.sequence([
            .wait(forDuration: Self.strikeWindup),
            .run { [weak self] in
                guard let self, strikeWindupActive else { return }
                strikeArmed = true
                armStrikePrompt()
            },
            .wait(forDuration: Self.strikeWindow),
            .run { [weak self] in
                guard let self, strikeWindupActive else { return }
                let landed = strikePressed && !strikeBurned
                closeStrikeWindow()
                if landed { playStrikeFlourish() }
                perform(action, timedBonus: landed)
            }
        ]), withKey: "timedStrike")
    }

    func closeStrikeWindow() {
        strikeWindupActive = false
        strikeArmed = false
        strikePressed = false
        strikeBurned = false
        strikePrompt?.removeFromParent()
        strikePrompt = nil
    }

    /// Bouton A pendant l'élan d'une action offensive. Retourne `true` si
    /// l'appui a été consommé (le menu ne doit alors rien faire).
    @discardableResult
    func attemptStrike() -> Bool {
        guard strikeWindupActive else { return false }
        if !strikeArmed {
            strikeBurned = true    // trop tôt : bonus perdu pour ce coup
            return true
        }
        guard !strikePressed else { return true }
        strikePressed = true
        strikePrompt?.run(.sequence([
            .scale(to: 1.6, duration: 0.06),
            .scale(to: 1.0, duration: 0.08)
        ]))
        AudioEngine.shared.playSelect()
        HapticsEngine.light()
        return true
    }

    /// Repère discret pendant l'élan (le joueur voit que ça se prépare).
    func showStrikePrompt() {
        strikePrompt?.removeFromParent()
        let prompt = SKLabelNode(fontNamed: PixelUI.uiFont)
        prompt.text = String(localized: "combat.strike.prompt")
        prompt.fontSize = 15
        prompt.fontColor = SKColor(white: 0.75, alpha: 1)
        let anchor = actingAlly?.home ?? kaelHomePosition
        prompt.position = CGPoint(x: anchor.x, y: anchor.y + 96)
        prompt.zPosition = 900
        prompt.alpha = 0.55
        root.addChild(prompt)
        strikePrompt = prompt
    }

    /// La fenêtre s'ouvre : le repère s'allume en or et pulse — c'est LE signal.
    func armStrikePrompt() {
        guard let prompt = strikePrompt else { return }
        prompt.fontColor = PixelUI.gold
        prompt.alpha = 1
        prompt.setScale(0.8)
        prompt.run(.sequence([
            .scale(to: 1.15, duration: 0.08),
            .scale(to: 1.0, duration: 0.08)
        ]))
        AudioEngine.shared.playStep()
    }

    /// Éclat doré sur l'acteur quand la frappe est réussie.
    func playStrikeFlourish() {
        let anchor = actingAlly?.home ?? kaelHomePosition
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
        showFloatingText(String(localized: "combat.strike.perfect"),
                         at: CGPoint(x: anchor.x, y: anchor.y + 70),
                         color: PixelUI.gold)
        HapticsEngine.success()
    }

    // MARK: - Verrous du grand coup (charge de boss)

    /// Régénération de boss conditionnée au bouclier : l'Archiviste relit son
    /// registre et se recompose tant qu'il n'a pas été BRISÉ. Taper fort ne
    /// suffit plus — il faut viser ses faiblesses pour l'ouvrir, sinon le
    /// combat ne finit jamais. C'est ce qui en fait une énigme, pas un mur.
    func applyBossRegenIfNeeded() {
        guard let boss = bossConfig, boss.regenPercent > 0,
              let foe = enemies.first, foe.combatant.isAlive else { return }
        // Brisé = incapable de se recomposer : la fenêtre du groupe.
        guard foe.brokenTurns == 0, foe.shield > 0 else { return }
        guard foe.combatant.hp < foe.combatant.maxHP else { return }

        let heal = max(1, Int(CGFloat(foe.combatant.maxHP) * boss.regenPercent))
        foe.combatant.hp = min(foe.combatant.maxHP, foe.combatant.hp + heal)
        statusLabel.text = boss.regenName
        showFloatingText("+" + String(heal), at: foe.homePosition,
                         color: SKColor(red: 0.55, green: 0.95, blue: 0.70, alpha: 1))
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
        foe.sprite?.run(.sequence([
            .scale(to: 1.06, duration: 0.14),
            .scale(to: 1.0, duration: 0.14)
        ]))
        updateVisuals()
    }

    /// Le boss annonce sa spéciale UNE MANCHE À L'AVANCE et se couvre de
    /// sceaux élémentaires. Le groupe a un tour complet pour tous les briser :
    /// s'il y parvient, le coup est annulé et le boss s'effondre, exposé.
    /// C'est ce qui transforme un boss « sac à PV » en énigme à résoudre.
    func armSpecialLocksIfNeeded() {
        guard let boss = bossConfig,
              let foe = enemies.first, foe.combatant.isAlive,
              foe.specialLockTotal == 0 else { return }
        // La prochaine action ennemie sera-t-elle la spéciale ?
        guard (enemyTurnCount + 1) % boss.specialAttackInterval == 0 else { return }

        // Deux sceaux tirés parmi ce que le groupe peut réellement porter
        // (l'attaque physique compte : aucun verrou n'est infaisable).
        let pool: [CombatElement] = [.physical, .fire, .ice, .lightning, .aether]
        foe.specialLocks = Array(pool.shuffled().prefix(2))
        foe.specialLockTotal = foe.specialLocks.count
        refreshLockIcons(for: foe)

        statusLabel.text = String(localized: "combat.locks.charging \(foe.combatant.name)")
        showEffect(String(localized: "combat.locks.warning"),
                   color: SKColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1))
        AudioEngine.shared.playBlackSlash()
        HapticsEngine.heavy()
        JuiceEngine.screenShake(root, intensity: 6, duration: 0.25)
        foe.sprite?.run(.sequence([
            .scale(to: 1.10, duration: 0.18),
            .scale(to: 1.0, duration: 0.18)
        ]))
    }

    /// Retire les sceaux touchés par les éléments d'une action.
    func breakSpecialLocks(on foe: EnemyState, with elements: [CombatElement]) {
        guard foe.specialLockTotal > 0, !foe.specialLocks.isEmpty else { return }
        let before = foe.specialLocks.count
        for element in elements {
            if let idx = foe.specialLocks.firstIndex(of: element) {
                foe.specialLocks.remove(at: idx)
            }
        }
        guard foe.specialLocks.count < before else { return }

        refreshLockIcons(for: foe)
        AudioEngine.shared.playQuestComplete()
        HapticsEngine.medium()
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
        showFloatingText(String(localized: "combat.locks.broken"),
                         at: CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 96),
                         color: Palette.goldCombat)
    }

    /// Redessine la rangée de sceaux (un losange par verrou restant).
    func refreshLockIcons(for foe: EnemyState) {
        foe.lockIcons.removeAllChildren()
        guard !foe.specialLocks.isEmpty else { return }
        let spacing: CGFloat = 20
        let startX = -CGFloat(foe.specialLocks.count - 1) * spacing / 2
        for (i, element) in foe.specialLocks.enumerated() {
            let seal = SKSpriteNode(color: element.color,
                                    size: CGSize(width: 11, height: 11))
            seal.zRotation = .pi / 4          // losange, cohérent avec les faiblesses
            seal.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            let ring = SKShapeNode(rectOf: CGSize(width: 16, height: 16))
            ring.strokeColor = SKColor(red: 1.00, green: 0.72, blue: 0.25, alpha: 1)
            ring.fillColor = .clear
            ring.lineWidth = 1.5
            ring.zRotation = .pi / 4
            ring.position = seal.position
            foe.lockIcons.addChild(ring)
            foe.lockIcons.addChild(seal)
        }
        foe.lockIcons.run(.sequence([
            .scale(to: 1.25, duration: 0.08),
            .scale(to: 1.0, duration: 0.10)
        ]))
    }

    /// Tous les sceaux ont sauté : le grand coup avorte et le boss s'expose.
    func cancelSpecial(for foe: EnemyState) {
        foe.specialLockTotal = 0
        foe.lockIcons.removeAllChildren()
        foe.shield = 0
        foe.brokenTurns = max(foe.brokenTurns, 2)
        setBrokenPose(foe, broken: true)
        statusLabel.text = String(localized: "combat.locks.cancelled \(foe.combatant.name)")
        showEffect(String(localized: "combat.locks.cancelledEffect"),
                   color: Palette.goldCombat)
        AudioEngine.shared.playQuestComplete()
        HapticsEngine.success()
        JuiceEngine.screenShake(root, intensity: 9, duration: 0.3)
        if let scene = parentScene {
            JuiceEngine.flashOverlay(in: root, size: scene.size,
                color: SKColor(red: 1.00, green: 0.80, blue: 0.30, alpha: 1),
                duration: 0.22)
        }
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
    }

    /// Bouton A pendant un coup ennemi. Retourne `true` si l'appui a été
    /// consommé par la parade (le menu ne doit alors rien faire).
    ///
    /// Marteler A ne marche pas : un appui hors fenêtre **brûle** la parade
    /// pour ce coup. Sans cette règle, la parade serait gratuite et le
    /// systeme n'aurait aucun intérêt.
    @discardableResult
    func attemptBlock() -> Bool {
        guard phase == .enemyTurn else { return false }
        if !blockArmed {
            blockBurned = true
            return true
        }
        guard !blockPressed else { return true }
        blockPressed = true
        // Retour immédiat : le joueur doit savoir que son appui a été pris,
        // avant même de connaître le résultat.
        blockPrompt?.run(.sequence([
            .scale(to: 1.5, duration: 0.06),
            .scale(to: 1.0, duration: 0.08)
        ]))
        AudioEngine.shared.playTap()
        HapticsEngine.light()
        return true
    }

    /// L'ennemi s'annonce : il recule pour prendre son élan et un « ! »
    /// s'allume au-dessus de sa cible. Sans annonce, la parade serait une
    /// loterie.
    func telegraphAttack(from foe: EnemyState, isSpecial: Bool) {
        foe.sprite?.run(.sequence([
            .moveBy(x: 26, y: 0, duration: Self.telegraphDuration * 0.7),
            .moveBy(x: -6, y: 0, duration: Self.telegraphDuration * 0.3)
        ]))
        foe.sprite?.forEachDescendantSprite { s in
            let c = s.color, f = s.colorBlendFactor
            s.run(.sequence([
                .colorize(with: isSpecial ? .orange : .white,
                          colorBlendFactor: 0.40, duration: 0.12),
                .colorize(with: c, colorBlendFactor: f, duration: 0.20)
            ]))
        }

        blockPrompt?.removeFromParent()
        let prompt = SKLabelNode(fontNamed: PixelUI.uiFont)
        prompt.text = String(localized: "combat.block.prompt")
        prompt.fontSize = 15
        prompt.fontColor = isSpecial
            ? SKColor(red: 1.00, green: 0.70, blue: 0.25, alpha: 1)
            : SKColor(red: 0.65, green: 0.88, blue: 1.00, alpha: 1)
        prompt.position = CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 96)
        prompt.zPosition = 900
        root.addChild(prompt)
        prompt.setScale(0.6)
        prompt.run(.sequence([
            .scale(to: 1.0, duration: 0.10),
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.18),
                .fadeAlpha(to: 1.0, duration: 0.18)
            ]))
        ]))
        blockPrompt = prompt
        AudioEngine.shared.playStep()
    }

    /// Éclat bleu net à la parade : pixel art, aucun flou.
    func playBlockEffect(at pos: CGPoint) {
        // Le pareur lève vraiment son bouclier quand son pack en dessine un
        // (le wizard d'Eran a un jeu complet bouclier au bras), et la rune
        // de garde du pack s'allume sur lui.
        if let k = actorSprite ?? kaelSprite {
            CombatSprites.playGuard(on: k)
            if let hero = CombatSprites.heroOf(k) {
                BattleSprites.playEffect(hero.wardEffect, from: pos, to: pos,
                                         in: root, scale: 1.9)
            }
        }
        let ring = SKShapeNode(rectOf: CGSize(width: 52, height: 52))
        ring.strokeColor = SKColor(red: 0.60, green: 0.88, blue: 1.00, alpha: 1)
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 0
        ring.position = pos
        ring.zPosition = 880
        root.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.6, duration: 0.18),
                    .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "combat.block.success")
        label.fontSize = 16
        label.fontColor = SKColor(red: 0.70, green: 0.92, blue: 1.00, alpha: 1)
        label.position = CGPoint(x: pos.x, y: pos.y + 52)
        label.zPosition = 900
        root.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 22, duration: 0.5),
                    .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    /// Un allié tombe : KO visuel, il saute ses tours.
    /// La défaite n'arrive que si Kael tombe.
    func handleAllyDown(_ ally: AllyState) {
    showEffect(String(localized: "combat.status.allyDown \(ally.combatant.name)"),
               color: SKColor(red: 1.00, green: 0.55, blue: 0.45, alpha: 1))
    ally.sprite?.run(.group([
        .rotate(toAngle: -.pi / 2, duration: 0.5, shortestUnitArc: true),
        .moveBy(x: 0, y: -10, duration: 0.5),
        .fadeAlpha(to: 0.45, duration: 0.5)
    ]))
    HapticsEngine.heavy()
    }

    func scheduleNextPlayerTurn(after delay: TimeInterval) {
    root.run(.sequence([
        .wait(forDuration: delay),
        .run { [weak self] in self?.startPlayerTurn() }
    ]))
    }

    func checkEnrage() {
    guard let boss = bossConfig, !isEnraged, let first = enemies.first else { return }
    if CGFloat(first.combatant.hp) / CGFloat(first.combatant.maxHP) <= boss.enrageThreshold {
        triggerEnrage(boss)
    }
    }

    /// Mort individuelle (combat multi) : animation + retarget.
    func handleEnemyDeath(_ e: EnemyState) {
    playEnemyDeathAnimation(e)
    retargetIfNeeded()
    }

    /// Contrôles classiques : le combat ne réagit plus au toucher.
    /// Navigation au joystick (`menuNav`), validation au bouton A
    /// (`menuConfirm`). Le tap est absorbé pour ne pas fuir au monde.
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
    guard isActive else { return false }
    return true
    }
}
