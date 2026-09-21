import SpriteKit

// Boucle de tours — l'attaque ennemie : télégraphe, fenêtre de parade, résolution du coup.
extension CombatSystem {
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
    // ÉGIDE (voie du Souffle) : mitigation passive sur Kael uniquement.
    let dmg = CombatMath.incomingDamage(
        raw: rawDamage, blocked: blocked,
        damageReduction: victim == nil ? (_player?.skillDamageReduction ?? 0) : 0)

    if let victim {
        victim.combatant.hp = max(0, victim.combatant.hp - dmg)
    } else {
        // DERNIER SOUFFLE (capstone du Souffle) : le coup fatal laisse Kael
        // à 1 PV, une seule fois par combat. Se déclenche avant l'écran de
        // mort, donc le tour continue normalement.
        let outcome = CombatMath.applyHitToKael(
            hp: kael.hp, damage: dmg,
            hasLastBreath: _player?.hasLastBreath == true,
            lastBreathUsed: lastBreathUsed)
        kael.hp = outcome.hp
        if outcome.lastBreathTriggered {
            lastBreathUsed = true
            showEffect(String(localized: "combat.effect.lastBreath"),
                       color: SKColor(red: 0.45, green: 0.90, blue: 0.60, alpha: 1))
            AudioEngine.shared.playVictory()
            HapticsEngine.success()
            AccessibilitySettings.announce(String(localized: "combat.effect.lastBreath"))
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
