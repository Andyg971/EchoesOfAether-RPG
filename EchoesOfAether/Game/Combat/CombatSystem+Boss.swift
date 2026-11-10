import SpriteKit

// Mécaniques de boss : rage, coup spécial, régénération.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Boss Mechanics


    func triggerEnrage(_ boss: BossConfig) {
        isEnraged = true
        statusLabel.text = String(localized: "combat.boss.enrage")
        enrageLabel.alpha = 1
        enrageLabel.setScale(0.5)
        enrageLabel.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.3), .fadeIn(withDuration: 0.2)]),
            .scale(to: 1.0, duration: 0.15),
            .wait(forDuration: 1.5),
            .fadeOut(withDuration: 0.4)
        ]))

        if let scene = parentScene {
            JuiceEngine.screenShake(root, intensity: 15, duration: 0.5)
            JuiceEngine.flashOverlay(in: root, size: scene.size,
                color: SKColor(red: 0.60, green: 0.05, blue: 0.10, alpha: 1),
                duration: 0.3)
            // Boss aura particles + pulse du sprite (boss = ennemi unique)
            if let boss = enemies.first {
                boss.sprite?.run(.sequence([
                    .scale(to: 1.15, duration: 0.15),
                    .scale(to: 1.0, duration: 0.25)
                ]))
            }
        }

        AudioEngine.shared.playBlackSlash()
    }

    func handleDefeat() {
        phase = .finished
        AudioEngine.shared.setMood(moodBeforeCombat)
        statusLabel.text = String(localized: "combat.status.defeat")
        attackButton.alpha = 0.3
        blackSlashButton.alpha = 0.3
        _player?.currentHP = 0
        playKaelDefeatAnimation()
        root.run(.sequence([
            .wait(forDuration: 1.5),
            .run { [weak self] in
                self?.root.removeFromParent()
                self?.completion?(-1, 0)   // -1 resonance = signal défaite
            }
        ]))
    }

    func setupBossUI(scene: SKScene) {
        enrageLabel.text = String(localized: "combat.boss.enrageLabel")
        enrageLabel.fontSize = 22
        enrageLabel.fontColor = SKColor(red: 0.90, green: 0.20, blue: 0.15, alpha: 1)
        enrageLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.60)
        enrageLabel.zPosition = 950
        enrageLabel.alpha = 0
        root.addChild(enrageLabel)

        // Plaque de nom du boss retirée : coins arrondis hors charte, posée
        // SOUS le bandeau de tour (les deux se chevauchaient) et redondante
        // avec le nom déjà affiché au-dessus de sa barre de PV.
    }
}
