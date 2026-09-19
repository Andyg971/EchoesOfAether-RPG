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

    func executeEnemyAttack(_ e: EnemyState, then proceed: @escaping () -> Void) {
    guard isActive, phase == .enemyTurn, kael.isAlive, e.combatant.isAlive else { return }

    let isSpecial = bossConfig.map { enemyTurnCount % $0.specialAttackInterval == 0 } ?? false

    // Le groupe a-t-il brisé tous les sceaux ? Alors le grand coup avorte :
    // le boss s'effondre, exposé, et perd son tour. C'est la récompense du
    // travail d'équipe sur les éléments.
    if isSpecial, e.specialLockTotal > 0 {
        if e.specialLocks.isEmpty {
            cancelSpecial(for: e)
            updateVisuals()
            proceed()
            return
        }
        // Sceaux encore debout : le coup part, et les verrous se dissipent.
        e.specialLockTotal = 0
        e.specialLocks.removeAll()
        e.lockIcons.removeAllChildren()
    }

    let dmgMult = isEnraged ? (bossConfig?.enrageDamageMult ?? 1) : 1
    let dmg: Int
    let sparkColor: SKColor
    let shakeIntensity: CGFloat

    // Cible : l'ennemi choisit VRAIMENT sa proie parmi tout le groupe vivant
    // (Kael + alliés), à parts égales — plus de « tout sur Kael ». Les
    // attaques spéciales de boss visent toujours Kael (enjeu narratif).
    let victim: AllyState?
    if isSpecial || aliveAllies.isEmpty {
        victim = nil
    } else {
        // nil = Kael dans le tirage ; chaque membre du groupe a la même chance.
        let pool: [AllyState?] = [nil] + aliveAllies.map { Optional($0) }
        victim = pool.randomElement() ?? nil
    }

    if isSpecial, let boss = bossConfig {
        dmg = boss.specialDamage * dmgMult
        sparkColor = SKColor(red: 0.55, green: 0.15, blue: 0.80, alpha: 1)
        shakeIntensity = 10
        statusLabel.text = boss.specialName
        // Voile violet retiré : la secousse et le nom du coup annoncent le
        // grand coup du boss sans noyer l'écran de couleur.
    } else {
        // Facteur de menace : les monstres frappent plus fort pour que le
        // joueur doive vraiment gérer PV/MP/Boost et ses grosses attaques.
        dmg = Int((CGFloat(e.combatant.baseDamage * dmgMult) * Self.enemyDamageScale).rounded())
        sparkColor = .red
        shakeIntensity = isEnraged ? 6 : 3
        statusLabel.text = victim != nil
            ? String(localized: "combat.status.enemyHitsAlly \(e.combatant.name) \(victim!.combatant.name) \(dmg)")
            : String(localized: "combat.status.enemyHits \(e.combatant.name) \(dmg)")
    }

    let victimHome = victim?.home ?? kaelHomePosition

    // Esquive : 10 % de chance d'éviter un coup normal (jamais un spécial).
    if !isSpecial, Double.random(in: 0...1) < (_player?.dodgeChance ?? 0.10) {
        statusLabel.text = String(localized: "combat.status.dodged")
        playEnemyAttackAnimation(e, isSpecial: false, victim: victim, dodged: true)
        playDodgeEffect(sprite: victim?.sprite ?? kaelSprite, home: victimHome)
        updateVisuals()
        proceed()
        return
    }

    // ── Parade au timing ──
    // Le tour ennemi était un film : les dégâts tombaient AVANT même que le
    // monstre ne bondisse. Désormais il s'annonce, une fenêtre s'ouvre, et
    // l'impact n'arrive qu'après — appuyer sur A au bon moment amortit le coup.
    telegraphAttack(from: e, isSpecial: isSpecial)
    openBlockWindow()

    root.run(.sequence([
        .wait(forDuration: Self.telegraphDuration),
        .run { [weak self] in
            guard let self else { return }
            playEnemyAttackAnimation(e, isSpecial: isSpecial, victim: victim)
        },
        .wait(forDuration: Self.lungeDuration),
        .run { [weak self] in
            guard let self else { return }
            resolveEnemyHit(e, rawDamage: dmg, isSpecial: isSpecial,
                            victim: victim, victimHome: victimHome,
                            sparkColor: sparkColor, shakeIntensity: shakeIntensity,
                            proceed: proceed)
        }
    ]), withKey: "enemyStrike")
    }

    /// Applique le coup, une fois la fenêtre de parade refermée.
    func resolveEnemyHit(_ e: EnemyState, rawDamage: Int, isSpecial: Bool,
                             victim: AllyState?, victimHome: CGPoint,
                             sparkColor: SKColor, shakeIntensity: CGFloat,
                             proceed: @escaping () -> Void) {
    let blocked = closeBlockWindow()
    // Une parade réussie coupe le coup de 65 %. Elle ne l'annule pas : le
    // joueur doit rester attentif, pas devenir invincible.
    var dmg = blocked ? max(1, Int(Double(rawDamage) * 0.35)) : rawDamage
    // ÉGIDE (voie du Souffle) : mitigation passive sur Kael uniquement.
    if victim == nil, let reduction = _player?.skillDamageReduction, reduction > 0 {
        dmg = max(1, Int(CGFloat(dmg) * (1 - reduction)))
    }

    if let victim {
        victim.combatant.hp = max(0, victim.combatant.hp - dmg)
    } else {
        // DERNIER SOUFFLE (capstone du Souffle) : le coup fatal laisse Kael
        // à 1 PV, une seule fois par combat. Se déclenche avant l'écran de
        // mort, donc le tour continue normalement.
        let fatal = kael.hp - dmg <= 0
        if fatal, _player?.hasLastBreath == true, !lastBreathUsed, kael.hp > 1 {
            lastBreathUsed = true
            kael.hp = 1
            showEffect(String(localized: "combat.effect.lastBreath"),
                       color: SKColor(red: 0.45, green: 0.90, blue: 0.60, alpha: 1))
            AudioEngine.shared.playVictory()
            HapticsEngine.success()
            AccessibilitySettings.announce(String(localized: "combat.effect.lastBreath"))
        } else {
            kael.hp = max(0, kael.hp - dmg)
        }
    }

    if blocked {
        statusLabel.text = String(localized: "combat.status.blocked \(dmg)")
        AudioEngine.shared.playSelect()
        HapticsEngine.success()
        playBlockEffect(at: victimHome)
        JuiceEngine.screenShake(root, intensity: 1.5, duration: 0.08)
    } else {
        AudioEngine.shared.playDamage()
        HapticsEngine.heavy()
        JuiceEngine.screenShake(root, intensity: shakeIntensity, duration: 0.15)
        if isSpecial { JuiceEngine.zoomPunch(root, around: victimHome, scale: 1.05) }
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
    }
    showFloatingText("-" + String(dmg), at: victimHome,
                     color: blocked
                        ? SKColor(red: 0.60, green: 0.85, blue: 1.00, alpha: 1)
                        : SKColor(red: 1.00, green: 0.40, blue: 0.35, alpha: 1))

    if let victim, !victim.combatant.isAlive { handleAllyDown(victim) }
    if !kael.isAlive { handleDefeat(); return }
    updateVisuals()
    proceed()
    }
}
