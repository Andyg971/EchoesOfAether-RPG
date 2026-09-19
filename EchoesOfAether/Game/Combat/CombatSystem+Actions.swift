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
    let damageMultiplier = (1.0 + CGFloat(boost) * 0.55)
        * (timedBonus ? Self.strikeBonus : 1.0)
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

    switch action {
    case .attack:
        // L'attaque physique régénère un peu de Magie de l'acteur : incite à
        // alterner frappe physique et sorts plutôt que spammer la magie.
        if let ally = actingAlly {
            ally.combatant.mp = min(ally.combatant.maxMP,
                                    ally.combatant.mp + (_player?.attackMPRegen ?? 6))
        } else {
            kael.mp = min(kael.maxMP, kael.mp + (_player?.attackMPRegen ?? 6))
        }
        breakSpecialLocks(on: foe, with: [.physical])
        comboCount += 1
        let comboMult: Int = comboCount >= 5 ? 14 : (comboCount >= 3 ? 12 : 10)
        var finalDmg = Int(CGFloat(atkDmg * comboMult / 10) * damageMultiplier)
        let isCrit = Double.random(in: 0...1) < (_player?.critChance ?? 0.12)
        if isCrit { finalDmg = Int(CGFloat(finalDmg) * 1.5) }
        // Cible déjà cassée : décharge dévastatrice (l'attaque physique ne
        // brise pas de bouclier, mais frappe fort une cible à terre).
        let hitBroken = foe.brokenTurns > 0
        if hitBroken { finalDmg = Int(CGFloat(finalDmg) * Self.brokenDamageMultiplier) }
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
        if isCrit {
            playCritEffect(at: enemyCenter, damage: finalDmg)
        } else {
            showFloatingText("-" + String(finalDmg), at: enemyCenter,
                             color: hitBroken ? Self.brokenHitColor : .white)
        }
        showComboIfNeeded()

    case .blackSlash:
        // L'Entaille noire porte l'Aether : elle brise ce sceau.
        breakSpecialLocks(on: foe, with: [.aether])
        comboCount = 0
        resonance += 1
        var finalDmg = Int(CGFloat(slashDmg) * damageMultiplier)
        let isCrit = Double.random(in: 0...1) < (_player?.critChance ?? 0.12)
        if isCrit { finalDmg = Int(CGFloat(finalDmg) * 1.5) }
        // Était-elle déjà cassée avant ce coup ? (hitWeakness va peut-être
        // la casser maintenant ; dans les deux cas le Black Slash encaisse
        // le bonus Break.)
        let wasBroken = foe.brokenTurns > 0
        let broke = hitWeakness(on: foe, with: .aether)
        let hitBroken = wasBroken || broke
        if hitBroken { finalDmg = Int(CGFloat(finalDmg) * Self.brokenDamageMultiplier) }
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
        // ENTAILLE DOUBLE (capstone de la voie de la Lame) : la lame repasse
        // aussitôt, à 55 %. Second coup uniquement pour Kael — c'est son arbre.
        var echoDmg = 0
        if actingAlly == nil, _player?.hasDoubleSlash == true, foe.combatant.hp > 0 {
            echoDmg = max(1, Int(CGFloat(finalDmg) * 0.55))
            foe.combatant.hp = max(0, foe.combatant.hp - echoDmg)
        }
        statusLabel.text = boost > 0 ? String(localized: "combat.status.blackSlashBoosted \(boost + 1)") : String(localized: "combat.status.blackSlash \(resonance)")
        AudioEngine.shared.playBlackSlash()
        HapticsEngine.heavy()
        // AUCUN VOILE VIOLET. Le flash de l'Entaille noire noyait tout
        // l'écran de violet pendant un tiers de seconde : c'est ce qu'on
        // voyait comme un grand carré de couleur posé sur le jeu. Le poids
        // du coup passe par le MOUVEMENT — ralenti, secousse, zoom — qui ne
        // colore rien.
        JuiceEngine.screenShake(root, intensity: 18 + CGFloat(boost) * 4, duration: 0.45)
        JuiceEngine.zoomPunch(root, around: enemyCenter, scale: 1.075)
        JuiceEngine.slowMotion(scene: scene, duration: 0.30, factor: 0.16)
        // L'Entaille noire est le coup signature : le GRAND sort du pack.
        playActorAttackAnimation(on: foe, strong: true, signature: true)
        // Éclats violets retirés : les actions de Kael se contentent
        // désormais de leur animation et de leur arc, comme les techniques
        // d'Eran qui n'existent que par leur pack. Plus de gerbe de carrés
        // projetés par-dessus le sprite.
        if isCrit {
            playCritEffect(at: enemyCenter, damage: finalDmg)
        } else {
            showFloatingText("-" + String(finalDmg), at: enemyCenter,
                             color: hitBroken ? Self.brokenHitColor : CombatElement.aether.color)
        }
        // Le second coup s'annonce à part, légèrement décalé : sans ça le
        // joueur croit à un seul gros chiffre et le capstone ne se voit pas.
        if echoDmg > 0 {
            let echo = echoDmg
            root.run(.sequence([
                .wait(forDuration: 0.22),
                .run { [weak self] in
                    guard let self else { return }
                    showFloatingText("-" + String(echo),
                                     at: CGPoint(x: enemyCenter.x + 26, y: enemyCenter.y + 18),
                                     color: CombatElement.aether.color)
                    showEffect(String(localized: "combat.effect.doubleSlash"),
                               color: CombatElement.aether.color)
                    AudioEngine.shared.playHit()
                    HapticsEngine.medium()
                }
            ]))
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
                             color: Palette.vitality)
        }
        endPlayerAction()
        return

    case .spell(let spell):
        comboCount = 0
        if spell == .blessing {
            // Nova sacrée de Lyra : soigne TOUT le groupe d'un coup.
            let heal = Int(CGFloat(spell.power(at: _player?.level ?? 1))
                           * damageMultiplier * spellMult)
            kael.hp = min(kael.maxHP, kael.hp + heal)
            for ally in aliveAllies {
                ally.combatant.hp = min(ally.combatant.maxHP,
                                        ally.combatant.hp + heal)
            }
            statusLabel.text = String(localized: "combat.status.blessing \(heal)")
            AudioEngine.shared.playQuestComplete()
            HapticsEngine.success()
            playSpellAnimation(spell, on: foe, boosted: boost > 0)
            // Un chiffre par soigné : on voit le groupe entier remonter.
            showFloatingText("+" + String(heal), at: kaelHomePosition,
                             color: Palette.vitality)
            for ally in aliveAllies {
                showFloatingText("+" + String(heal), at: ally.home,
                                 color: Palette.vitality)
            }
            endPlayerAction()
            return
        }
        if spell == .mend {
            let heal = Int(CGFloat(spell.power(at: _player?.level ?? 1))
                           * damageMultiplier * spellMult)
            // Le joueur a désigné sa cible : on la respecte. Sans choix
            // explicite (IA, sécurité), on retombe sur le plus blessé.
            let index = chosenHealIndex ?? (healTargets.enumerated().min {
                Double($0.element.hp) / Double($0.element.maxHP)
                    < Double($1.element.hp) / Double($1.element.maxHP)
            }?.offset ?? 0)
            chosenHealIndex = nil
            let who = healTargets.indices.contains(index)
                ? healTargets[index].name : kael.name
            let healPos = applyHeal(heal, toIndex: index)
            statusLabel.text = boost > 0
                ? String(localized: "combat.status.healBoostedOn \(who) \(boost + 1) \(heal)")
                : String(localized: "combat.status.healOn \(who) \(heal)")
            AudioEngine.shared.playHit()
            HapticsEngine.success()
            playSpellAnimation(spell, on: foe, boosted: boost > 0)
            showFloatingText("+" + String(heal), at: healPos, color: Palette.vitality)
            endPlayerAction()
            return
        }

        guard let element = spell.element else { return }
        // Tempête : elle porte glace ET foudre — une seule des deux suffit à
        // toucher la faiblesse. C'est sa raison d'être.
        let hitElements = spell.elements
        breakSpecialLocks(on: foe, with: hitElements)
        let isWeak = hitElements.contains { foe.weaknesses.contains($0) }
        let breakElement = hitElements.first { foe.weaknesses.contains($0) } ?? element
        let broke = isWeak ? hitWeakness(on: foe, with: breakElement) : false
        var finalDmg = Int(CGFloat(spell.power(at: _player?.level ?? 1))
                           * damageMultiplier * spellMult)
        if isWeak { finalDmg = Int(CGFloat(finalDmg) * 1.35) }
        // Payoff Break uniforme (était ×1.25, incohérent avec attaque/slash).
        let hitBroken = foe.brokenTurns > 0 || broke
        if hitBroken { finalDmg = Int(CGFloat(finalDmg) * Self.brokenDamageMultiplier) }
        foe.combatant.hp = max(0, foe.combatant.hp - finalDmg)
        statusLabel.text = isWeak
            ? String(localized: "combat.status.spellWeak \(spell.title(at: _player?.level ?? 1)) \(finalDmg)")
            : String(localized: "combat.status.spellHit \(spell.title(at: _player?.level ?? 1)) \(finalDmg)")
        applySpellSideEffect(spell, on: foe, wasWeak: isWeak, boosted: boost > 0)
        AudioEngine.shared.playBlackSlash()
        HapticsEngine.heavy()
        JuiceEngine.screenShake(root, intensity: isWeak ? 8 : 4, duration: 0.18)
        playSpellAnimation(spell, on: foe, boosted: boost > 0)
        showFloatingText("-" + String(finalDmg), at: enemyCenter,
                         color: hitBroken ? Self.brokenHitColor : element.color)
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

    func applySpellSideEffect(_ spell: CombatSpell, on foe: EnemyState,
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
    case .mend, .blessing:
        break   // sorts sacrés : ils soignent, ils n'affligent pas
    case .tempest:
        // Fusion des deux : elle gèle ET paralyse. C'est ce qui en fait
        // un ultime et pas un gros sort de plus.
        if Double.random(in: 0...1) < (wasWeak ? 0.75 : 0.50) {
            foe.combatant.stunned = true
            showEffect(String(localized: "combat.effect.paralyzed"), color: CombatElement.lightning.color)
        }
    case .windBlade:
        break   // pure puissance, aucun statut
    case .emberStrike:
        // La lame embrasée laisse brûler, comme le sort de feu de Kael.
        if wasWeak || boosted {
            foe.combatant.statusEffect = .aetherBurn
            foe.combatant.statusTicks = boosted ? 3 : 2
            showEffect(String(localized: "combat.effect.burnApplied"), color: CombatElement.fire.color)
        }
    }
    }

    /// Chaque sort a sa mise en scène : projectile de feu, pics de glace,
    /// foudre qui tombe, colonne de soin — plus d'anneau générique.
    func playSpellAnimation(_ spell: CombatSpell, on foe: EnemyState, boosted: Bool) {
    // ── Le lanceur joue sa VRAIE gestuelle de sort ──
    // Les deux sorts du pack ne sont pas interchangeables :
    //   skill1 = sphère d'énergie protectrice → soutien, donc le SOIN.
    //   skill2 = incantation bâton levé, anneau magique → l'OFFENSIF.
    // L'élément n'est pas porté par la gestuelle mais par le projectile
    // (feu orange, glace bleue, foudre jaune) : une même incantation sert
    // les trois, c'est le FX qui les distingue.
    // Sans pack (ennemi contrôlé), rien : le combat continue.
    // Soin → skill1 (sphère/étincelles protectrices) ; Bénédiction et sorts
    // offensifs → skill2 (la grande incantation).
    if let actor = actorSprite {
        CombatSprites.playHeroSkill(on: actor, index: spell == .mend ? 0 : 1)
    }

    // Teinte de cast : repli pour un sprite sans pack (ennemi contrôlé).
    // Sur un héros à pack, sa propre animation porte déjà le sort — le
    // repeindre en orange par-dessus salissait ses couleurs d'origine.
    let hasPack = actorSprite?.childNode(withName: "body") != nil
    if !hasPack {
        let castColor = spell.element?.color
            ?? Palette.vitalityDim
        actorSprite?.forEachDescendantSprite { sprite in
            let prevColor = sprite.color
            let prevFactor = sprite.colorBlendFactor
            sprite.run(.sequence([
                .colorize(with: castColor, colorBlendFactor: 0.45, duration: 0.10),
                .wait(forDuration: 0.12),
                .colorize(with: prevColor, colorBlendFactor: prevFactor, duration: 0.22)
            ]))
        }
    }

    // ── Le FX du pack, projeté du lanceur vers la cible ──
    // Boost : le sort passe à sa forme majeure (blizzard pour la glace,
    // foudre du ciel pour l'éclair).
    //
    // `usedPackFX` retient si le pack a fourni l'effet : dans ce cas les
    // anciens effets codés à la main ne doivent PAS se jouer par-dessus.
    // Sinon on empile deux boules de feu — celle du pack et la mienne.
    var usedPackFX = false
    if let parent = actorSprite?.parent {
        let from = actorHomePosition
        let to = foe.homePosition
        // Les sorts sacrés de Lyra éclosent sur le GROUPE, pas sur l'ennemi :
        // leur cible est le lanceur, pas la Bête.
        let fx: BattleSprites.Effect? = switch spell {
        case .ember:       .fire
        case .frost:       boosted ? .blizzard : .ice
        case .thunder:     boosted ? .thunder : .lightning
        case .mend:        .lyraHeal
        case .blessing:    .lyraBlessing
        case .windBlade:   .eranWind
        case .emberStrike: .eranEmber
        case .tempest:     .blizzard   // + la foudre, jouée juste après
        }
        let target = (spell == .mend || spell == .blessing) ? from : to
        if let fx, !BattleSprites.effectTextures(fx).isEmpty {
            BattleSprites.playEffect(fx, from: from, to: target, in: parent,
                                     scale: boosted ? 2.0 : 1.6)
            usedPackFX = true
        }
        // Tempête : le blizzard part, la foudre tombe derrière. Les deux
        // éléments doivent se voir — sinon rien ne dit que c'est une fusion.
        if spell == .tempest {
            parent.run(.sequence([
                .wait(forDuration: 0.16),
                .run { [weak self] in
                    guard self != nil else { return }
                    BattleSprites.playEffect(.thunder, from: from, to: target,
                                             in: parent, scale: boosted ? 2.4 : 2.0)
                }
            ]))
        }
    }

    // Anciens effets, codés à la main avant l'arrivée des packs (boule de
    // braise, stalactites, colonne de foudre). Ils ne servent PLUS que de
    // repli : quand le pack fournit son propre effet, jouer les deux
    // empilait deux sorts l'un sur l'autre.
    if !usedPackFX {
        switch spell {
        case .ember:   playEmberEffect(on: foe, boosted: boosted)
        case .frost:   playFrostEffect(on: foe, boosted: boosted)
        case .thunder: playThunderEffect(on: foe, boosted: boosted)
        case .mend:    playMendEffect(boosted: boosted)
        case .blessing:
            playMendEffect(boosted: boosted, at: kaelHomePosition)
            for ally in aliveAllies {
                playMendEffect(boosted: boosted, at: ally.home)
            }
        case .windBlade, .emberStrike, .tempest:
            break   // ces techniques n'existent que par leur pack
        }
    } else if spell == .blessing {
        // La nova du pack éclot sur le lanceur ; l'anneau de soin marque
        // chaque autre membre pour qu'on voie bien que TOUT le groupe monte.
        for ally in aliveAllies where ally.home != actorHomePosition {
            playMendEffect(boosted: boosted, at: ally.home)
        }
        if actorHomePosition != kaelHomePosition {
            playMendEffect(boosted: boosted, at: kaelHomePosition)
        }
    }
    // Les sorts sacrés ne frappent personne : aucun recul d'ennemi.
    if spell != .mend && spell != .blessing {
        // L'impact arrive avec un léger retard (le temps du projectile/effet)
        let impactDelay: TimeInterval = switch spell {
        case .ember: 0.46      // charge + vol de la boule de feu
        case .frost: 0.30      // jaillissement des stalactites
        case .thunder: 0.14    // la foudre frappe quasi instantanément
        case .windBlade: 0.20  // le temps du bond
        case .emberStrike: 0.24
        case .tempest: 0.34    // blizzard puis foudre
        case .mend, .blessing: 0
        }
        root.run(.sequence([
            .wait(forDuration: impactDelay),
            .run { [weak self] in self?.playEnemyHitReact(foe, strong: boosted) }
        ]))
    }
    }
}
