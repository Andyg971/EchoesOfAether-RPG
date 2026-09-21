import SpriteKit

// Verrous du grand coup : la charge de boss se brise par ses éléments.
extension CombatSystem {
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
}
