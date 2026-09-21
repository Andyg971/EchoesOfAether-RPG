import SpriteKit

// Effets de repli codés à la main (feu, glace, foudre, soin) — ne jouent que si le pack ne fournit pas de sprite.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Moteur de particules pixel (carrés nets, zéro glow)

    /// Palettes pixel par élément (du plus clair au plus sombre).
    static let firePalette: [SKColor] = [
    SKColor(red: 1.00, green: 0.96, blue: 0.62, alpha: 1),
    SKColor(red: 1.00, green: 0.58, blue: 0.16, alpha: 1),
    SKColor(red: 0.88, green: 0.24, blue: 0.06, alpha: 1),
    SKColor(red: 0.45, green: 0.10, blue: 0.05, alpha: 1)
    ]
    static let icePalette: [SKColor] = [
    SKColor(red: 0.92, green: 0.99, blue: 1.00, alpha: 1),
    SKColor(red: 0.56, green: 0.86, blue: 1.00, alpha: 1),
    SKColor(red: 0.30, green: 0.60, blue: 0.95, alpha: 1),
    SKColor(red: 0.16, green: 0.34, blue: 0.72, alpha: 1)
    ]
    static let boltPalette: [SKColor] = [
    SKColor(red: 1.00, green: 1.00, blue: 0.88, alpha: 1),
    SKColor(red: 1.00, green: 0.90, blue: 0.40, alpha: 1),
    SKColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1)
    ]
    static let healPalette: [SKColor] = [
    SKColor(red: 0.75, green: 1.00, blue: 0.78, alpha: 1),
    Palette.vitalityDim,
    SKColor(red: 0.18, green: 0.70, blue: 0.42, alpha: 1)
    ]

    /// pixels verts montants + scintillements 16-bit.
    func playMendEffect(boosted: Bool, at targetHome: CGPoint? = nil) {
    let pal = Self.healPalette
    let home = targetHome ?? actorHomePosition
    let base = CGPoint(x: home.x, y: home.y - 18)

    // Anneau de bénédiction écrasé qui s'ouvre aux pieds du soigné.
    PixelFX.shockRing(in: root, at: base, palette: pal,
                      count: boosted ? 22 : 16,
                      fromRadius: 6, toRadius: boosted ? 62 : 46,
                      pixel: 5, flatten: 0.32, duration: 0.4)
    // Scintillements, colonne de carrés empilés et spirale de motes retirés :
    // aucune attaque ni aucun sort du jeu ne projette de carrés de couleur.
    // L'anneau au sol et la croix de soin portent seuls le sort de Lyra.
    // Croix de lumière brève au-dessus du soigné
    let cross = SKNode()
    let vBar = SKSpriteNode(color: pal[0], size: CGSize(width: 4, height: 18))
    let hBar = SKSpriteNode(color: pal[0], size: CGSize(width: 14, height: 4))
    hBar.position = CGPoint(x: 0, y: 4)
    cross.addChild(vBar); cross.addChild(hBar)
    cross.position = CGPoint(x: home.x, y: home.y + 70)
    cross.zPosition = 830
    cross.setScale(0.3); cross.alpha = 0
    root.addChild(cross)
    cross.run(.sequence([
        .group([.scale(to: 1.0, duration: 0.15), .fadeIn(withDuration: 0.1)]),
        .wait(forDuration: 0.2),
        .fadeOut(withDuration: 0.25),
        .removeFromParent()
    ]))
    let healedAlly = allies.first { $0.home == home }
    let healedSprite = healedAlly?.sprite ?? kaelSprite
    let baseScale: CGFloat = healedAlly != nil ? 0.95 : 1.10
    healedSprite?.run(.sequence([
        .scale(to: baseScale * 1.07, duration: 0.12),
        .scale(to: baseScale, duration: 0.18)
    ]))
    }

    /// CRITIQUE : dégâts dorés en gros, éclat d'étincelles, punch caméra.
    func playCritEffect(at position: CGPoint, damage: Int) {
    let gold = SKColor(red: 1.00, green: 0.84, blue: 0.25, alpha: 1)
    showEffect(String(localized: "combat.effect.crit"), color: gold)
    // Gerbe d'éclats retirée : le mot CRITIQUE, le coup de zoom et le gros
    // chiffre doré disent déjà le critique, sans carrés projetés.
    JuiceEngine.zoomPunch(root, around: position, scale: 1.05)
    HapticsEngine.heavy()

    let label = SKLabelNode(fontNamed: PixelUI.uiFont)
    label.text = "-" + String(damage)
    label.fontSize = 33
    label.fontColor = gold
    label.position = CGPoint(x: position.x, y: position.y + 72)
    label.zPosition = 940
    label.setScale(0.4)
    root.addChild(label)
    label.run(.sequence([
        .group([.scale(to: 1.25, duration: 0.12), .fadeIn(withDuration: 0.06)]),
        .scale(to: 1.0, duration: 0.08),
        .group([.moveBy(x: 0, y: 36, duration: 0.5), .fadeOut(withDuration: 0.5)]),
        .removeFromParent()
    ]))
    }

    /// ESQUIVE : pas de côté vif du sprite, aucun dégât.
    func playDodgeEffect(sprite: SKNode?, home: CGPoint) {
    showEffect(String(localized: "combat.effect.dodge"),
               color: SKColor(red: 0.65, green: 0.95, blue: 1.00, alpha: 1))
    showFloatingText(String(localized: "combat.effect.dodge"), at: home,
                     color: SKColor(red: 0.65, green: 0.95, blue: 1.00, alpha: 1))
    guard let sprite else { return }
    let dash = SKAction.sequence([
        .moveBy(x: -30, y: 0, duration: 0.08),
        .wait(forDuration: 0.16),
        .moveBy(x: 30, y: 0, duration: 0.12)
    ])
    dash.timingMode = .easeOut
    sprite.run(dash)
    AudioEngine.shared.playStep()
    HapticsEngine.light()
    }

    func showFloatingText(_ text: String, at position: CGPoint, color: SKColor) {
    let label = SKLabelNode(fontNamed: PixelUI.uiFont)
    label.text = text
    label.fontSize = 25
    label.fontColor = color
    label.position = CGPoint(x: position.x, y: position.y + 72)
    label.zPosition = 940
    root.addChild(label)
    label.run(.sequence([
        .group([.moveBy(x: 0, y: 34, duration: 0.45), .fadeOut(withDuration: 0.45)]),
        .removeFromParent()
    ]))
    }

    func showEffect(_ text: String, color: SKColor) {
    statusEffectLabel.text = text
    statusEffectLabel.fontColor = color
    statusEffectLabel.alpha = 1
    statusEffectLabel.run(.sequence([.fadeIn(withDuration: 0.08), .wait(forDuration: 0.85), .fadeOut(withDuration: 0.35)]))
    }

    func showComboIfNeeded() {

        guard comboCount >= 3 else { return }
        let text = comboCount >= 5
            ? String(localized: "combat.combo.mega \(comboCount)")
            : String(localized: "combat.combo.hit \(comboCount)")
        comboLabel.text = text
        comboLabel.setScale(0.5)
        comboLabel.alpha = 1
        comboLabel.run(.sequence([
            .group([.scale(to: 1.3, duration: 0.15), .fadeIn(withDuration: 0.1)]),
            .scale(to: 1.0, duration: 0.1),
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.3)
        ]))
        HapticsEngine.combo()
    }

    func checkVictory() {
        guard aliveEnemies.isEmpty, let last = enemies.last else { return }
        phase = .finished
        let finalResonance = resonance
        let finalGold = goldReward
        let isBoss = bossConfig != nil
        statusLabel.text = String(localized: "combat.status.defeated \(last.combatant.name)")
        AudioEngine.shared.playVictory()
        attackButton.alpha = 0.3
        blackSlashButton.alpha = 0.3

        enemies.filter { $0.sprite?.alpha ?? 0 > 0 }.forEach { playEnemyDeathAnimation($0) }
        // Les héros survivants fêtent la victoire (saut de joie en cascade).
        playVictoryPose()
        if isBoss, let scene = parentScene {
            // Mort de boss : ralenti + secousse + flash. La gerbe de carrés
            // est retirée — aucune attaque du jeu n'en projette.
            JuiceEngine.slowMotion(scene: scene, duration: 0.4, factor: 0.15)
            JuiceEngine.screenShake(root, intensity: 18, duration: 0.6)
            // Voile violet retiré aussi : le ralenti et la secousse portent
            // la mort du boss.
        }

        // Restauration PV 100% entre combats — Kael se soigne après victoire.
        // (Tension narrative gardée via difficulté/boss, pas via attrition de PV.)
        // XP : combat normal = Σ maxHP/3, boss = maxHP × 1.5.
        if let p = _player {
            p.currentHP = p.currentMaxHP
            let totalHP = enemies.reduce(0) { $0 + $1.combatant.maxHP }
            let xpReward = isBoss ? Int(Double(totalHP) * 1.5) : totalHP / 3
            p.gainXP(xpReward)
        }

        AudioEngine.shared.setMood(moodBeforeCombat)
        let delay: TimeInterval = isBoss ? 1.8 : 0.8
        root.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                self?.root.removeFromParent()
                self?.completion?(finalResonance, finalGold)
            }
        ]))
    }

    func setupComboAndStatusUI(scene: SKScene) {
    comboLabel.fontSize = 24
    comboLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1)
    comboLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.56)
    comboLabel.zPosition = 920
    comboLabel.alpha = 0
    root.addChild(comboLabel)

    statusEffectLabel.fontSize = 16
    statusEffectLabel.fontColor = SKColor(red: 0.55, green: 0.90, blue: 0.55, alpha: 1)
    statusEffectLabel.position = CGPoint(x: scene.size.width * 0.72, y: scene.size.height * 0.32)
    statusEffectLabel.zPosition = 930
    statusEffectLabel.alpha = 0
    root.addChild(statusEffectLabel)

    boostLabel.fontSize = 16
    boostLabel.fontColor = SKColor(red: 0.72, green: 0.62, blue: 1.00, alpha: 1)
    boostLabel.position = CGPoint(x: scene.size.width / 2, y: 220)
    boostLabel.zPosition = 920
    root.addChild(boostLabel)

    breakLabel.fontSize = 34
    breakLabel.fontColor = Palette.goldCombatBright
    breakLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.56)
    breakLabel.zPosition = 950
    breakLabel.alpha = 0
    root.addChild(breakLabel)
    }
}
