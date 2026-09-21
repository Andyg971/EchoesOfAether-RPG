import SpriteKit

// Actions du joueur — le contexte partagé d'une action, l'attaque physique
// et l'Entaille noire. Les sorts et la potion sont dans `+ActionSpells`.
@MainActor
extension CombatSystem {
    /// Tout ce qu'une action lit une fois résolue l'identité de l'acteur
    /// (Kael ou l'allié contrôlé) : multiplicateur, dégâts de base, cible.
    struct ActionContext {
        let scene: SKScene
        let foe: EnemyState
        /// Niveau de boost dépensé sur cette action (0 = aucun).
        let boost: Int
        let damageMultiplier: CGFloat
        let enemyCenter: CGPoint
        let atkDmg: Int
        let slashDmg: Int
        let spellMult: CGFloat
    }

    /// Attaque physique : régénère un peu de Magie, monte le combo, frappe
    /// fort une cible déjà cassée (mais ne brise aucun bouclier).
    func performAttack(_ ctx: ActionContext) {
        let foe = ctx.foe, boost = ctx.boost, enemyCenter = ctx.enemyCenter
        let atkDmg = ctx.atkDmg, damageMultiplier = ctx.damageMultiplier
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
        let isCrit = Double.random(in: 0...1) < (_player?.critChance ?? 0.12)
        // Cible déjà cassée : décharge dévastatrice (l'attaque physique ne
        // brise pas de bouclier, mais frappe fort une cible à terre).
        let hitBroken = foe.brokenTurns > 0
        let finalDmg = CombatMath.attackDamage(base: atkDmg, comboCount: comboCount,
                                               multiplier: damageMultiplier,
                                               isCrit: isCrit, targetBroken: hitBroken)
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
    }

    /// Entaille noire : porte l'Aether, brise ce sceau, monte la résonance ;
    /// à 3 elle étourdit, à 6 elle brûle. Capstone : le second coup à 55 %.
    func performBlackSlash(_ ctx: ActionContext) {
        let foe = ctx.foe, boost = ctx.boost, enemyCenter = ctx.enemyCenter
        let slashDmg = ctx.slashDmg, damageMultiplier = ctx.damageMultiplier
        let scene = ctx.scene
        // L'Entaille noire porte l'Aether : elle brise ce sceau.
        breakSpecialLocks(on: foe, with: [.aether])
        comboCount = 0
        resonance += 1
        let isCrit = Double.random(in: 0...1) < (_player?.critChance ?? 0.12)
        // Était-elle déjà cassée avant ce coup ? (hitWeakness va peut-être
        // la casser maintenant ; dans les deux cas le Black Slash encaisse
        // le bonus Break.)
        let wasBroken = foe.brokenTurns > 0
        let broke = hitWeakness(on: foe, with: .aether)
        let hitBroken = wasBroken || broke
        let finalDmg = CombatMath.blackSlashDamage(base: slashDmg, multiplier: damageMultiplier,
                                                   isCrit: isCrit, targetBroken: hitBroken)
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
        let echoDmg = CombatMath.doubleSlashEcho(
            primaryDamage: finalDmg, isKael: actingAlly == nil,
            hasCapstone: _player?.hasDoubleSlash == true,
            targetHPAfterPrimary: foe.combatant.hp)
        if echoDmg > 0 { foe.combatant.hp = max(0, foe.combatant.hp - echoDmg) }
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
    }
}
