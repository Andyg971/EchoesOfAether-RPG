import SpriteKit

// Boucle de tours : ordre d'initiative, tours ennemis, résolution des coups, statuts.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Boucle de tours

    func startPlayerTurn() {
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
    // Le rappel des touches vivait ici, planté au milieu de l'arène à chaque
    // tour, toute la partie — un tutoriel collé à l'écran. Il est passé dans
    // le panneau « Combat » du TutorialOverlay, vu une fois et relançable
    // depuis les Options. Le bandeau de tour dit déjà à qui de jouer ; le
    // statusLabel reprend son seul vrai rôle : raconter le coup qui vient de
    // partir.
    statusLabel.text = ""
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
    func startAllyTurn(_ index: Int) {
    guard isActive, kael.isAlive, allies.indices.contains(index),
          allies[index].combatant.isAlive, !aliveEnemies.isEmpty else {
        startEnemyTurn(); return
    }
    phase = .playerTurn
    actingAllyIndex = index
    retargetIfNeeded()
    statusLabel.text = ""
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
    func runFXDemoIfNeeded() {
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
    func retargetIfNeeded() {
    guard target?.combatant.isAlive != true,
          let next = enemies.firstIndex(where: { $0.combatant.isAlive }) else { return }
    targetIndex = next
    }

    /// Phase ennemie : chaque ennemi vivant agit l'un après l'autre.
    func startEnemyTurn() {
    guard isActive, kael.isAlive, !aliveEnemies.isEmpty else { return }
    phase = .enemyTurn
    runEnemyAction(at: 0)
    }

    func runEnemyAction(at index: Int) {
    guard isActive, kael.isAlive else { return }
    guard index < enemies.count else {
        // Mécanique propre au boss (Archiviste) : il se recompose tant qu'il
        // n'est pas brisé. Résolu AVANT les sceaux pour que le joueur voie
        // d'abord le soin, puis la charge.
        applyBossRegenIfNeeded()
        // Fin de la phase ennemie : si le boss prépare sa spéciale pour la
        // manche suivante, il pose ses sceaux MAINTENANT — le groupe a un
        // tour entier pour les briser.
        armSpecialLocksIfNeeded()
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
        if e.brokenTurns == 0 {
            e.shield = e.shieldMax
            setBrokenPose(e, broken: false)   // l'ennemi se redresse
        }
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

}
