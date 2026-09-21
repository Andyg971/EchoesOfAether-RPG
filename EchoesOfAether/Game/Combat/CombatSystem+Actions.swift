import SpriteKit

// Actions du joueur et des alliés : attaque, Entaille noire, sorts, potion, boost.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Actions

    /// Coût exact en Points de Magie d'une action (Kael). Physique = gratuit.
    func mpCost(for action: CombatAction) -> Int {
    switch action {
    case .blackSlash:      return 14
    case .spell(let spell): return spell.mpCost
    case .attack, .potion:  return 0
    }
    }

    /// `timedBonus` : la frappe au timing a été réussie (cf. beginTimedStrike).
    func perform(_ action: CombatAction, timedBonus: Bool = false) {
        guard let scene = parentScene, phase == .playerTurn,
              let foe = target else { return }

        // Points de Magie : l'acteur courant (Kael OU l'allié contrôlé) dépense
        // sa propre réserve. Réserve insuffisante = action refusée, le joueur
        // garde son tour (ex. pour une attaque physique gratuite).
        let cost = mpCost(for: action)
        let actorMP = actingAlly?.combatant.mp ?? kael.mp
        if cost > 0, actorMP < cost {
            showEffect(String(localized: "combat.mp.insufficient"),
                       color: Palette.frost)
            AudioEngine.shared.playTap()
            return   // reste en .playerTurn
        }

        phase = .playerActing
        if cost > 0 {
            if let ally = actingAlly {
                ally.combatant.mp = max(0, ally.combatant.mp - cost)
            } else {
                kael.mp = max(0, kael.mp - cost)
            }
        }
        let boost = queuedBoost
        // Boost (Octopath) et frappe au timing (Sea of Stars) se cumulent :
        // bien jouer les deux récompense vraiment.
        let damageMultiplier = CombatMath.actionMultiplier(boost: boost, timedStrike: timedBonus)
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
        // La voie de l'Aether ne booste que les sorts DE KAEL : c'est son arbre,
        // pas celui du groupe — les alliés gardent leur multiplicateur d'espèce.
        let spellMult: CGFloat = actingAlly.map { $0.kind.spellMultiplier }
            ?? (_player?.spellPowerMultiplier ?? 1.0)

        let ctx = ActionContext(scene: scene, foe: foe, boost: boost,
                                damageMultiplier: damageMultiplier,
                                enemyCenter: enemyCenter, atkDmg: atkDmg,
                                slashDmg: slashDmg, spellMult: spellMult)

        switch action {
        case .attack:
            performAttack(ctx)
        case .blackSlash:
            performBlackSlash(ctx)
        case .potion:
            performPotion()
            return   // la potion clôt elle-même le tour
        case .spell(let spell):
            comboCount = 0
            if spell == .blessing { performBlessing(spell, ctx); return }
            if spell == .mend { performMend(spell, ctx); return }
            guard performOffensiveSpell(spell, ctx) else { return }
        }

        if let foe = target, !foe.combatant.isAlive {
            handleEnemyDeath(foe)
        }
        endPlayerAction()
    }

    /// Clôt l'action de l'acteur courant : victoire, enrage boss,
    /// puis tour de Lyra (si elle n'a pas encore agi) ou phase ennemie.
    func endPlayerAction() {
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

    func applyBoost() {
    guard playerBP > 0, queuedBoost < 3 else { return }
    playerBP -= 1
    queuedBoost += 1
    statusLabel.text = String(localized: "combat.status.boost \(queuedBoost + 1)")
    HapticsEngine.light()
    boostButton.run(.sequence([.scale(to: 1.08, duration: 0.08), .scale(to: 1.0, duration: 0.12)]))
    updateVisuals()
    }

    @discardableResult
    func hitWeakness(on foe: EnemyState, with element: CombatElement) -> Bool {
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
    setBrokenPose(foe, broken: true)
    return true
    }

    /// État « à terre » lisible sur le sprite d'un ennemi cassé : il chancelle
    /// puis reste affaissé et incliné tant qu'il est brisé, redressé au réveil.
    /// Géométrie seule (rotation + affaissement) — on ne touche pas la couleur
    /// pour ne pas écraser les sprites déjà teintés (loup d'ombre).
    func setBrokenPose(_ foe: EnemyState, broken: Bool) {
    guard let s = foe.sprite else { return }
    s.removeAction(forKey: "brokenPose")
    if broken {
        let stagger = SKAction.sequence([
            .rotate(toAngle: 0.28, duration: 0.12, shortestUnitArc: true),
            .rotate(toAngle: 0.20, duration: 0.14, shortestUnitArc: true)
        ])
        stagger.timingMode = .easeOut
        s.run(.group([stagger, .moveBy(x: 0, y: -6, duration: 0.26)]),
              withKey: "brokenPose")
    } else {
        s.run(.group([
            .rotate(toAngle: 0, duration: 0.22, shortestUnitArc: true),
            .moveBy(x: 0, y: 6, duration: 0.22)
        ]), withKey: "brokenPose")
    }
    }

}
