import SpriteKit

// Frappe au timing (action command offensif, façon Sea of Stars).
extension CombatSystem {
    // MARK: - Frappe au timing (action command offensive)

    /// Délai d'élan avant l'ouverture de la fenêtre : le joueur doit ATTENDRE
    /// le bon moment, pas appuyer d'avance.
    static let strikeWindup: TimeInterval = 0.26
    /// Durée de la fenêtre — même exigence que la parade.
    static let strikeWindow: TimeInterval = 0.38
    // Le bonus de frappe vit dans CombatMath.strikeBonus.

    /// Les actions qui se méritent au timing (offensives uniquement : ni
    /// potion, ni soin, ni bénédiction).
    func usesTimedStrike(_ action: CombatAction) -> Bool {
        switch action {
        case .attack, .blackSlash:
            return true
        case .potion:
            return false
        case .spell(let spell):
            return spell != .mend && spell != .blessing
        }
    }

    /// Point d'entrée UNIQUE des actions choisies par le joueur : les actions
    /// offensives passent par la frappe au timing, les autres partent
    /// directement. Les MP sont vérifiés avant l'élan pour ne pas faire jouer
    /// une animation qui finirait en « Magie insuffisante ».
    func execute(_ action: CombatAction) {
        guard phase == .playerTurn, !strikeWindupActive else { return }
        let cost = mpCost(for: action)
        let actorMP = actingAlly?.combatant.mp ?? kael.mp
        if cost > 0, actorMP < cost {
            showEffect(String(localized: "combat.mp.insufficient"),
                       color: Palette.frost)
            AudioEngine.shared.playTap()
            return
        }
        if usesTimedStrike(action) {
            beginTimedStrike(action)
        } else {
            perform(action)
        }
    }

    /// Lance l'élan : repère au-dessus de l'acteur, fenêtre qui s'ouvre puis
    /// se referme, et enfin l'action résolue avec (ou sans) le bonus.
    func beginTimedStrike(_ action: CombatAction) {
        strikeWindupActive = true
        strikeArmed = false
        strikePressed = false
        strikeBurned = false
        showStrikePrompt()

        root.run(.sequence([
            .wait(forDuration: Self.strikeWindup),
            .run { [weak self] in
                guard let self, strikeWindupActive else { return }
                strikeArmed = true
                armStrikePrompt()
            },
            .wait(forDuration: Self.strikeWindow),
            .run { [weak self] in
                guard let self, strikeWindupActive else { return }
                let landed = strikePressed && !strikeBurned
                closeStrikeWindow()
                if landed { playStrikeFlourish() }
                perform(action, timedBonus: landed)
            }
        ]), withKey: "timedStrike")
    }

    func closeStrikeWindow() {
        strikeWindupActive = false
        strikeArmed = false
        strikePressed = false
        strikeBurned = false
        strikePrompt?.removeFromParent()
        strikePrompt = nil
    }

    /// Bouton A pendant l'élan d'une action offensive. Retourne `true` si
    /// l'appui a été consommé (le menu ne doit alors rien faire).
    @discardableResult
    func attemptStrike() -> Bool {
        guard strikeWindupActive else { return false }
        if !strikeArmed {
            strikeBurned = true    // trop tôt : bonus perdu pour ce coup
            return true
        }
        guard !strikePressed else { return true }
        strikePressed = true
        strikePrompt?.run(.sequence([
            .scale(to: 1.6, duration: 0.06),
            .scale(to: 1.0, duration: 0.08)
        ]))
        AudioEngine.shared.playSelect()
        HapticsEngine.light()
        return true
    }

    /// Repère discret pendant l'élan (le joueur voit que ça se prépare).
    func showStrikePrompt() {
        strikePrompt?.removeFromParent()
        let prompt = SKLabelNode(fontNamed: PixelUI.uiFont)
        prompt.text = String(localized: "combat.strike.prompt")
        prompt.fontSize = 15
        prompt.fontColor = SKColor(white: 0.75, alpha: 1)
        let anchor = actingAlly?.home ?? kaelHomePosition
        prompt.position = CGPoint(x: anchor.x, y: anchor.y + 96)
        prompt.zPosition = 900
        prompt.alpha = 0.55
        root.addChild(prompt)
        strikePrompt = prompt
    }

    /// La fenêtre s'ouvre : le repère s'allume en or et pulse — c'est LE signal.
    func armStrikePrompt() {
        guard let prompt = strikePrompt else { return }
        prompt.fontColor = PixelUI.gold
        prompt.alpha = 1
        prompt.setScale(0.8)
        prompt.run(.sequence([
            .scale(to: 1.15, duration: 0.08),
            .scale(to: 1.0, duration: 0.08)
        ]))
        AudioEngine.shared.playStep()
    }

    /// Éclat doré sur l'acteur quand la frappe est réussie.
    func playStrikeFlourish() {
        let anchor = actingAlly?.home ?? kaelHomePosition
        // Carrés de couleur retirés : aucune attaque du jeu n'en projette.
        showFloatingText(String(localized: "combat.strike.perfect"),
                         at: CGPoint(x: anchor.x, y: anchor.y + 70),
                         color: PixelUI.gold)
        HapticsEngine.success()
    }
}
