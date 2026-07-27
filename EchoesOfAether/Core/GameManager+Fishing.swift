import SpriteKit

// Pêche au lac de Solis — mini-jeu d'adresse au bord de l'eau.
//
// Il réutilise VOLONTAIREMENT la compétence que le joueur vient d'acquérir en
// combat (attendre la fenêtre, appuyer sur A) : la détente vient du rythme,
// pas d'un nouveau système à apprendre. Lancer → attente variable → touche →
// ferrer dans la seconde. Rater n'a aucun coût : on relance.
@MainActor
extension GameManager {

    /// Durée pendant laquelle le poisson reste ferrable après la touche.
    private static var hookWindow: TimeInterval { 0.55 }

    // MARK: - Boucle

    /// Lance une prise. Kael reste planté au bord de l'eau le temps du jet.
    func startFishing() {
        guard let scene, !isFishing else { return }
        isFishing = true
        fishingHookable = false
        fishingResolved = false
        HapticsEngine.light()
        AudioEngine.shared.playSelect()

        let anchor = CGPoint(x: world.kael.position.x,
                             y: world.kael.position.y + 58)
        showFishingLabel(String(localized: "fishing.cast"),
                         color: SKColor(white: 0.82, alpha: 1), at: anchor)

        // Attente VARIABLE : impossible d'anticiper, il faut guetter.
        let wait = TimeInterval.random(in: 1.3...3.2)
        scene.run(.sequence([
            .wait(forDuration: wait),
            .run { [weak self] in self?.triggerFishBite() },
            .wait(forDuration: Self.hookWindow),
            .run { [weak self] in self?.resolveFishing(hooked: false) }
        ]), withKey: "fishing")
    }

    /// La touche : « ! » au-dessus de Kael, vibration — c'est LE signal.
    private func triggerFishBite() {
        guard isFishing, !fishingResolved else { return }
        fishingHookable = true
        let anchor = CGPoint(x: world.kael.position.x,
                             y: world.kael.position.y + 58)
        showFishingLabel("!", color: PixelUI.gold, at: anchor, big: true)
        HapticsEngine.medium()
        AudioEngine.shared.playStep()
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: CGPoint(x: anchor.x, y: anchor.y - 30),
            color: SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1), count: 8))
    }

    /// Bouton A pendant la pêche. `true` = l'appui a été consommé.
    @discardableResult
    func attemptHook() -> Bool {
        guard isFishing, !fishingResolved else { return false }
        // Ferrer trop tôt fait fuir le poisson : on ne matraque pas A.
        guard fishingHookable else {
            resolveFishing(hooked: false, tooEarly: true)
            return true
        }
        resolveFishing(hooked: true)
        return true
    }

    /// Clôt la prise et rend la main au joueur.
    private func resolveFishing(hooked: Bool, tooEarly: Bool = false) {
        guard isFishing, !fishingResolved else { return }
        fishingResolved = true
        scene?.removeAction(forKey: "fishing")
        let anchor = CGPoint(x: world.kael.position.x,
                             y: world.kael.position.y + 58)

        if hooked {
            // Prise rare : le lac garde quelques éclats d'Aether au fond.
            let rare = Double.random(in: 0...1) < 0.18
            let gold = Int.random(in: 18...46)
            player.gold += gold
            if rare { player.aetherShards += 1 }
            syncGold()
            AudioEngine.shared.playGoldGain()
            HapticsEngine.success()
            let text = rare
                ? String(localized: "fishing.catchRare \(gold)")
                : String(localized: "fishing.catch \(gold)")
            showFishingLabel(text, color: PixelUI.gold, at: anchor)
            AccessibilitySettings.announce(text)
            world.worldNode.addChild(ParticleFactory.impactSparks(
                at: anchor, color: PixelUI.gold, count: 14))
            saveGame()
        } else {
            HapticsEngine.error()
            let text = tooEarly
                ? String(localized: "fishing.tooEarly")
                : String(localized: "fishing.escaped")
            showFishingLabel(text, color: SKColor(white: 0.72, alpha: 1), at: anchor)
            AccessibilitySettings.announce(text)
        }

        // Court repos avant de pouvoir relancer : évite le spam d'appuis.
        scene?.run(.sequence([
            .wait(forDuration: 0.7),
            .run { [weak self] in
                self?.isFishing = false
                self?.fishingHookable = false
            }
        ]))
    }

    // MARK: - Affichage

    /// Étiquette flottante au-dessus de Kael (pixel, cohérente avec le HUD).
    private func showFishingLabel(_ text: String, color: SKColor,
                                  at pos: CGPoint, big: Bool = false) {
        world.worldNode.childNode(withName: "fishingLabel")?.removeFromParent()
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.name = "fishingLabel"
        label.text = text
        label.fontSize = big ? 26 : 13
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.position = pos
        label.zPosition = 900
        world.worldNode.addChild(label)
        label.setScale(0.7)
        label.run(.sequence([
            .scale(to: 1.0, duration: 0.10),
            .wait(forDuration: big ? 0.5 : 1.1),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }
}
