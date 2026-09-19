import SpriteKit

// Animations des combattants : ruées, esquives, teintes, mort.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Combatant animations

    /// `signature` : l'Entaille noire, qui sort le grand sort du pack (skill2).
    /// `strong` : coup appuyé par le Boost — skill1.
    /// Sinon l'attaque normale (Eran enchaîne ses trois attaques).
    func playActorAttackAnimation(on foe: EnemyState, strong: Bool = false,
                                          signature: Bool = false) {
        guard let k = actorSprite else { return }
        let home = actorHomePosition
        let dx: CGFloat = strong ? 110 : 70
        let lungeIn = SKAction.move(to: CGPoint(x: home.x + dx, y: home.y),
                                    duration: 0.10)
        lungeIn.timingMode = .easeIn
        let lungeOut = SKAction.move(to: home, duration: 0.18)
        lungeOut.timingMode = .easeOut

        // Vraie animation du pack. Sans pack (ennemi contrôlé, node sans
        // corps), rien ne se passe et seule la ruée subsiste — le combat
        // n'est jamais bloqué.
        let clip: BattleSprites.Clip
        if signature {
            CombatSprites.playHeroSkill(on: k, index: 1)   // skill2
            clip = .skill2
        } else if strong {
            CombatSprites.playHeroSkill(on: k, index: 0)   // skill1
            clip = .skill1
        } else {
            CombatSprites.playHeroAttack(on: k)
            clip = .attack
        }
        playActorSpellFX(clip, on: foe)
        // Le tilt d'origine tordait le sprite pour simuler un coup ; les packs
        // portent leur propre gestuelle, on ne la contrarie plus.
        k.run(.sequence([lungeIn, lungeOut]))

        // Attaque forte : images rémanentes derrière la ruée
        if strong {
            for i in 0..<2 {
                guard let ghost = k.copy() as? SKNode else { break }
                ghost.alpha = 0.30 - CGFloat(i) * 0.10
                ghost.position = CGPoint(x: home.x + CGFloat(i) * 26, y: home.y)
                ghost.zPosition = k.zPosition - 0.1
                root.addChild(ghost)
                ghost.run(.sequence([
                    .wait(forDuration: 0.05 + Double(i) * 0.04),
                    .fadeOut(withDuration: 0.20),
                    .removeFromParent()
                ]))
            }
        }
        playEnemyHitReact(foe, strong: strong)
    }

    /// Lance les FX du sort correspondant à l'action de l'acteur courant.
    ///
    /// Les planches d'effets (feu, glace, foudre, tonnerre, blizzard, garde)
    /// dormaient dans le catalogue : `BattleSprites.playEffect` n'avait aucun
    /// appelant. C'est ici qu'elles entrent en scène, chacune chez le
    /// personnage dont elle vient du pack (cf. `Hero.spells(for:)`).
    func playActorSpellFX(_ clip: BattleSprites.Clip, on foe: EnemyState) {
        guard let k = actorSprite, let hero = CombatSprites.heroOf(k) else { return }
        let spells = hero.spells(for: clip)
        guard !spells.isEmpty else { return }
        let from = actorHomePosition
        let to = foe.homePosition

        if clip == .attack {
            // Cycle : un lanceur qui ouvre toujours sur le même élément
            // n'a pas l'air d'en maîtriser cinq.
            let key = ObjectIdentifier(k)
            let step = (spellCycle[key] ?? 0) % spells.count
            spellCycle[key] = step + 1
            BattleSprites.playEffect(spells[step], from: from, to: to, in: root)
            return
        }
        // Sort : la liste est un ENCHAÎNEMENT (le tonnerre tombe, le
        // blizzard suit), décalé pour qu'on lise deux temps.
        for (i, fx) in spells.enumerated() {
            root.run(.sequence([
                .wait(forDuration: 0.18 * Double(i)),
                .run { [weak self] in
                    guard let self else { return }
                    BattleSprites.playEffect(fx, from: from, to: to, in: self.root)
                }
            ]))
        }
    }

    func playEnemyHitReact(_ foe: EnemyState, strong: Bool) {
        guard let e = foe.sprite else { return }
        let dx: CGFloat = strong ? 30 : 16
        let recoil = SKAction.sequence([
            .moveBy(x: dx, y: 0, duration: 0.06),
            .moveBy(x: -dx, y: 0, duration: 0.18)
        ])
        recoil.timingMode = .easeOut
        e.run(recoil)
        // Flash : applique aux SKSpriteNode descendants (pas les SKShape),
        // en restaurant la teinte d'origine (loup d'ombre = teinté).
        e.forEachDescendantSprite { sprite in
            let prevColor = sprite.color
            let prevFactor = sprite.colorBlendFactor
            sprite.run(.sequence([
                .colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
                .colorize(with: prevColor, colorBlendFactor: prevFactor, duration: 0.20)
            ]))
        }
    }

    func playEnemyAttackAnimation(_ foe: EnemyState, isSpecial: Bool,
                                          victim: AllyState? = nil,
                                          dodged: Bool = false) {
        guard let e = foe.sprite else { return }
        CombatSprites.playAttackFrames(on: e, kind: foe.kind)
        let dx: CGFloat = isSpecial ? -130 : -80
        let lungeIn = SKAction.move(to: CGPoint(x: foe.homePosition.x + dx,
                                                 y: foe.homePosition.y),
                                    duration: 0.12)
        lungeIn.timingMode = .easeIn
        let lungeOut = SKAction.move(to: foe.homePosition, duration: 0.22)
        lungeOut.timingMode = .easeOut
        e.run(.sequence([lungeIn, lungeOut]))
        if !dodged { playAllyHitReact(victim: victim) }
    }

    func playAllyHitReact(victim: AllyState? = nil) {
        guard let k = victim?.sprite ?? kaelSprite else { return }
        let recoil = SKAction.sequence([
            .moveBy(x: -18, y: 0, duration: 0.06),
            .moveBy(x: 18, y: 0, duration: 0.18)
        ])
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 0.65, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.20)
        ])
        k.run(recoil)
        k.forEachDescendantSprite { $0.run(flash) }
    }

    func playEnemyDeathAnimation(_ foe: EnemyState) {
        guard let e = foe.sprite else { return }
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
        e.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.6),
                .scale(to: 0.6, duration: 0.6),
                .rotate(byAngle: .pi / 6, duration: 0.6),
                .moveBy(x: 0, y: -20, duration: 0.6)
            ])
        ]))
    }

    func playKaelDefeatAnimation() {
        guard let k = kaelSprite else { return }
        k.run(.group([
            .rotate(toAngle: -.pi / 2, duration: 0.5, shortestUnitArc: true),
            .moveBy(x: 0, y: -10, duration: 0.5),
            .fadeAlpha(to: 0.6, duration: 0.5)
        ]))
    }

    /// Pose de victoire : Kael puis les alliés font un petit saut de joie
    /// en cascade, avec une étincelle dorée. Sprites existants, zéro frame
    /// nouvelle — remplaçable par une vraie anim de victoire plus tard.
    func playVictoryPose() {
        // Bond joyeux : montée franche, retombée amortie, léger balancement.
        func celebrate(_ node: SKNode, delay: TimeInterval) {
            let hop = SKAction.sequence([
                .moveBy(x: 0, y: 26, duration: 0.18),
                .moveBy(x: 0, y: -26, duration: 0.16),
                .moveBy(x: 0, y: 10, duration: 0.10),
                .moveBy(x: 0, y: -10, duration: 0.10)
            ])
            hop.timingMode = .easeOut
            let sway = SKAction.sequence([
                .rotate(toAngle: 0.12, duration: 0.18, shortestUnitArc: true),
                .rotate(toAngle: -0.08, duration: 0.16, shortestUnitArc: true),
                .rotate(toAngle: 0, duration: 0.14, shortestUnitArc: true)
            ])
            // Saut de joie seul : la gerbe dorée au-dessus de la tête est
            // retirée avec toutes les autres.
            node.run(.sequence([
                .wait(forDuration: delay),
                .group([hop, sway])
            ]))
        }
        var delay: TimeInterval = 0.1
        if let k = kaelSprite, (_player?.currentHP ?? 1) > 0 {
            celebrate(k, delay: delay)
        }
        for ally in allies where (ally.combatant.hp) > 0 {
            delay += 0.12
            if let s = ally.sprite { celebrate(s, delay: delay) }
        }
    }
}
