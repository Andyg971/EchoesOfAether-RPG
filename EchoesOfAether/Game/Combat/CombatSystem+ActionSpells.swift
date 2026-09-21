import SpriteKit

// Actions du joueur — potion et sorts : soins (potion, Mend, Blessing) qui
// clôturent eux-mêmes le tour, sort offensif, effets secondaires, mise en scène.
@MainActor
extension CombatSystem {
    /// Boire une potion : gros soin de l'acteur, consomme tour et fiole.
    func performPotion() {
        comboCount = 0
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
    }

    /// Nova sacrée de Lyra : soigne TOUT le groupe d'un coup.
    func performBlessing(_ spell: CombatSpell, _ ctx: ActionContext) {
        let foe = ctx.foe, boost = ctx.boost
        let damageMultiplier = ctx.damageMultiplier, spellMult = ctx.spellMult
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

    /// Soin ciblé : la cible désignée par le joueur, sinon le plus blessé.
    func performMend(_ spell: CombatSpell, _ ctx: ActionContext) {
        let foe = ctx.foe, boost = ctx.boost
        let damageMultiplier = ctx.damageMultiplier, spellMult = ctx.spellMult
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

    /// Sort offensif : faiblesse, Break, dégâts, effets secondaires.
    /// Renvoie `false` si le sort n'a pas d'élément (rien n'est joué).
    func performOffensiveSpell(_ spell: CombatSpell, _ ctx: ActionContext) -> Bool {
        let foe = ctx.foe, boost = ctx.boost, enemyCenter = ctx.enemyCenter
        let damageMultiplier = ctx.damageMultiplier, spellMult = ctx.spellMult
        guard let element = spell.element else { return false }
        // Tempête : elle porte glace ET foudre — une seule des deux suffit à
        // toucher la faiblesse. C'est sa raison d'être.
        let hitElements = spell.elements
        breakSpecialLocks(on: foe, with: hitElements)
        let isWeak = hitElements.contains { foe.weaknesses.contains($0) }
        let breakElement = hitElements.first { foe.weaknesses.contains($0) } ?? element
        let broke = isWeak ? hitWeakness(on: foe, with: breakElement) : false
        // Payoff Break uniforme (était ×1.25, incohérent avec attaque/slash).
        let hitBroken = foe.brokenTurns > 0 || broke
        let finalDmg = CombatMath.spellDamage(
            power: spell.power(at: _player?.level ?? 1),
            multiplier: damageMultiplier, spellMultiplier: spellMult,
            hitsWeakness: isWeak, targetBroken: hitBroken)
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
        return true
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
