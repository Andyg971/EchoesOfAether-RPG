import SpriteKit

// Commandes d'action au timing : parade, frappe parfaite, verrous du grand coup de boss.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Parade au timing

    /// Temps d'annonce avant le bond : c'est la fenêtre de réaction du joueur.
    /// 0,42 s — assez pour voir et répondre, trop court pour réfléchir.
    static let telegraphDuration: TimeInterval = 0.42
    /// Durée du bond, de l'annonce à l'impact.
    static let lungeDuration: TimeInterval = 0.14

    /// Ouvre la fenêtre. Elle reste ouverte pendant l'annonce ET le bond :
    /// on peut parer dès qu'on voit venir, jusqu'au contact.
    func openBlockWindow() {
        blockArmed = true
        blockPressed = false
        blockBurned = false
    }

    /// Referme et dit si la parade est réussie.
    @discardableResult
    func closeBlockWindow() -> Bool {
        let ok = blockPressed && !blockBurned
        blockArmed = false
        blockPressed = false
        blockBurned = false
        blockPrompt?.removeFromParent()
        blockPrompt = nil
        return ok
    }

    /// Bouton A pendant un coup ennemi. Retourne `true` si l'appui a été
    /// consommé par la parade (le menu ne doit alors rien faire).
    ///
    /// Marteler A ne marche pas : un appui hors fenêtre **brûle** la parade
    /// pour ce coup. Sans cette règle, la parade serait gratuite et le
    /// systeme n'aurait aucun intérêt.
    @discardableResult
    func attemptBlock() -> Bool {
        guard phase == .enemyTurn else { return false }
        if !blockArmed {
            blockBurned = true
            return true
        }
        guard !blockPressed else { return true }
        blockPressed = true
        // Retour immédiat : le joueur doit savoir que son appui a été pris,
        // avant même de connaître le résultat.
        blockPrompt?.run(.sequence([
            .scale(to: 1.5, duration: 0.06),
            .scale(to: 1.0, duration: 0.08)
        ]))
        AudioEngine.shared.playTap()
        HapticsEngine.light()
        return true
    }

    /// L'ennemi s'annonce : il recule pour prendre son élan et un « ! »
    /// s'allume au-dessus de sa cible. Sans annonce, la parade serait une
    /// loterie.
    func telegraphAttack(from foe: EnemyState, isSpecial: Bool) {
        foe.sprite?.run(.sequence([
            .moveBy(x: 26, y: 0, duration: Self.telegraphDuration * 0.7),
            .moveBy(x: -6, y: 0, duration: Self.telegraphDuration * 0.3)
        ]))
        foe.sprite?.forEachDescendantSprite { s in
            let c = s.color, f = s.colorBlendFactor
            s.run(.sequence([
                .colorize(with: isSpecial ? .orange : .white,
                          colorBlendFactor: 0.40, duration: 0.12),
                .colorize(with: c, colorBlendFactor: f, duration: 0.20)
            ]))
        }

        blockPrompt?.removeFromParent()
        let prompt = SKLabelNode(fontNamed: PixelUI.uiFont)
        prompt.text = String(localized: "combat.block.prompt")
        prompt.fontSize = 15
        prompt.fontColor = isSpecial
            ? SKColor(red: 1.00, green: 0.70, blue: 0.25, alpha: 1)
            : SKColor(red: 0.65, green: 0.88, blue: 1.00, alpha: 1)
        prompt.position = CGPoint(x: foe.homePosition.x, y: foe.homePosition.y + 96)
        prompt.zPosition = 900
        root.addChild(prompt)
        prompt.setScale(0.6)
        prompt.run(.sequence([
            .scale(to: 1.0, duration: 0.10),
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.18),
                .fadeAlpha(to: 1.0, duration: 0.18)
            ]))
        ]))
        blockPrompt = prompt
        AudioEngine.shared.playStep()
    }

    /// Éclat bleu net à la parade : pixel art, aucun flou.
    func playBlockEffect(at pos: CGPoint) {
        // Le pareur lève vraiment son bouclier quand son pack en dessine un
        // (le wizard d'Eran a un jeu complet bouclier au bras), et la rune
        // de garde du pack s'allume sur lui.
        if let k = actorSprite ?? kaelSprite {
            CombatSprites.playGuard(on: k)
            if let hero = CombatSprites.heroOf(k) {
                BattleSprites.playEffect(hero.wardEffect, from: pos, to: pos,
                                         in: root, scale: 1.9)
            }
        }
        let ring = SKShapeNode(rectOf: CGSize(width: 52, height: 52))
        ring.strokeColor = SKColor(red: 0.60, green: 0.88, blue: 1.00, alpha: 1)
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 0
        ring.position = pos
        ring.zPosition = 880
        root.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.6, duration: 0.18),
                    .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "combat.block.success")
        label.fontSize = 16
        label.fontColor = SKColor(red: 0.70, green: 0.92, blue: 1.00, alpha: 1)
        label.position = CGPoint(x: pos.x, y: pos.y + 52)
        label.zPosition = 900
        root.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 22, duration: 0.5),
                    .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    /// Un allié tombe : KO visuel, il saute ses tours.
    /// La défaite n'arrive que si Kael tombe.
    func handleAllyDown(_ ally: AllyState) {
    showEffect(String(localized: "combat.status.allyDown \(ally.combatant.name)"),
               color: SKColor(red: 1.00, green: 0.55, blue: 0.45, alpha: 1))
    ally.sprite?.run(.group([
        .rotate(toAngle: -.pi / 2, duration: 0.5, shortestUnitArc: true),
        .moveBy(x: 0, y: -10, duration: 0.5),
        .fadeAlpha(to: 0.45, duration: 0.5)
    ]))
    HapticsEngine.heavy()
    }

    func scheduleNextPlayerTurn(after delay: TimeInterval) {
    root.run(.sequence([
        .wait(forDuration: delay),
        .run { [weak self] in self?.startPlayerTurn() }
    ]))
    }

    func checkEnrage() {
    guard let boss = bossConfig, !isEnraged, let first = enemies.first else { return }
    if CGFloat(first.combatant.hp) / CGFloat(first.combatant.maxHP) <= boss.enrageThreshold {
        triggerEnrage(boss)
    }
    }

    /// Mort individuelle (combat multi) : animation + retarget.
    func handleEnemyDeath(_ e: EnemyState) {
    playEnemyDeathAnimation(e)
    retargetIfNeeded()
    }

    /// Contrôles classiques : le combat ne réagit plus au toucher.
    /// Navigation au joystick (`menuNav`), validation au bouton A
    /// (`menuConfirm`). Le tap est absorbé pour ne pas fuir au monde.
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
    guard isActive else { return false }
    return true
    }
}
