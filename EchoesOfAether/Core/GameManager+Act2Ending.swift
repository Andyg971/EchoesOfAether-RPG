import SpriteKit

// Acte II — la Découverte, le choix de la corruption, la mort de Lyra, fin d'acte.
extension GameManager {
    // MARK: - Discovery → Lyra Death → Act 2 End

    func openDiscovery() {
        guard scene != nil else { return }
        transition(to: .dialogue)
        // Lyra offre le cristal — moment calme avant la tempête
        dialogue.start(PrototypeContent.act2LyraGiftDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            // Corruption maximale — niveau 3
            player.kaelCorruptionLevel = 3
            player.loreDiscovered.insert("void")
            world.applyKaelCorruption(level: 3)
            GameCenterManager.shared.report(.corruptedSoul)
            JuiceEngine.screenShake(scene, intensity: 4)

            // Cinématique de corruption si pas encore vue
            if !corruptionCinematicShown {
                corruptionCinematicShown = true
                TransitionManager.showCorruptionCinematic(in: scene) { [weak self] in
                    guard let self else { return }
                    dialogue.start(PrototypeContent.act2DiscoveryDialogue) { [weak self] in
                        self?.playCorruptionChoiceThenDeath()
                    }
                }
            } else {
                // Flash rouge si déjà vue
                JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                         color: SKColor(red: 0.7, green: 0.08, blue: 0.05, alpha: 1),
                                         duration: 0.4)
                dialogue.start(PrototypeContent.act2DiscoveryDialogue) { [weak self] in
                    self?.playCorruptionChoiceThenDeath()
                }
            }
        }
    }

    /// La Voix offre à Kael le dernier pas. Les DEUX options tuent Lyra (la
    /// Tempête éclate quoi qu'il arrive) — mais le choix décide s'il est
    /// COMPLICE (index 0 → `kaelChoseCorruption = true`) ou dépassé par son
    /// pouvoir (index 1). Le flag colore l'après (dissolveLyraAndEndAct2).
    func playCorruptionChoiceThenDeath() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2CorruptionChoiceDialogue) { [weak self] in
            guard let self else { return }
            player.kaelChoseCorruption = (dialogue.lastChoiceIndex == 0)
            triggerLyraDeath()
        }
    }

    func triggerLyraDeath() {
        guard let scene else { return }
        // Andy : « on doit VOIR Kael l'attaquer — pas de voile noir. »
        // La scène se joue à découvert : Kael libère la Tempête (blizzard
        // puis foudre, comme en combat), Lyra est frappée et tombe, ses
        // derniers mots se disent sur son corps, puis elle se dissout dans
        // la lumière — c'est la ligne du script (« …avant de disparaître
        // dans la lumière »).
        transition(to: .transition)
        let kael = world.kael
        let lyra = world.lyra
        lyra.isHidden = false
        // Fin du suivi de compagne : c'est son dernier instant debout.
        // Posé avant le dialogue, sinon la boucle d'update la remettrait
        // au pas derrière Kael pendant qu'elle gît au sol.
        player.lyraDeceased = true
        // `facing` : direction de Kael VERS Lyra (+1 = droite).
        let facing: CGFloat = lyra.position.x < kael.position.x ? -1 : 1
        kael.forEachDescendantSprite { $0.xScale = facing * abs($0.xScale) }
        lyra.forEachDescendantSprite { $0.xScale = -facing * abs($0.xScale) }

        // L'élan : un pas de recul, la charge, la frappe.
        kael.run(.sequence([
            .moveBy(x: -facing * 8, y: 0, duration: 0.22),
            .wait(forDuration: 0.12),
            .moveBy(x: facing * 14, y: 0, duration: 0.10)
        ]))

        scene.run(.sequence([
            .wait(forDuration: 0.50),
            .run { [weak self] in
                guard let self else { return }
                BattleSprites.playEffect(.blizzard, from: kael.position,
                                         to: lyra.position,
                                         in: world.worldNode, scale: 1.8)
                AudioEngine.shared.playBlackSlash()
            },
            .wait(forDuration: 0.18),
            .run { [weak self] in
                guard let self, let scene = self.scene else { return }
                BattleSprites.playEffect(.thunder, from: kael.position,
                                         to: lyra.position,
                                         in: world.worldNode, scale: 1.8)
                JuiceEngine.screenShake(scene, intensity: 7)
                HapticsEngine.heavy()
            },
            .wait(forDuration: 0.34),
            .run { [weak self] in
                // Le manager peut avoir disparu (scène détruite) ; sinon on
                // n'a besoin que de `lyra` et `facing`, capturés localement.
                guard self != nil else { return }
                // Lyra est frappée : flash blanc, souffle, elle tombe.
                AudioEngine.shared.playDamage()
                lyra.forEachDescendantSprite { s in
                    s.run(.sequence([
                        .colorize(with: .white, colorBlendFactor: 0.9, duration: 0.06),
                        .colorize(with: SKColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1),
                                  colorBlendFactor: 0.45, duration: 0.30)
                    ]))
                }
                lyra.run(.group([
                    .moveBy(x: facing * 24, y: -4, duration: 0.30),
                    .sequence([
                        .wait(forDuration: 0.10),
                        .rotate(toAngle: -facing * .pi / 2, duration: 0.38,
                                shortestUnitArc: true)
                    ])
                ]))
            },
            .wait(forDuration: 1.15),
            .run { [weak self] in self?.playLyraLastWords() }
        ]))
    }

    /// Les derniers mots, prononcés sur le corps — la scène reste visible.
    private func playLyraLastWords() {
        transition(to: .dialogue)
        let startDeath: () -> Void = { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act2LyraDeathDialogue) { [weak self] in
                self?.dissolveLyraAndEndAct2()
            }
        }
        if player.act2EranFound {
            dialogue.start(PrototypeContent.act2LyraEranLastWordDialogue) { startDeath() }
        } else {
            startDeath()
        }
    }

    /// Lyra se dissout dans la lumière, puis Kael reste seul.
    private func dissolveLyraAndEndAct2() {
        guard let scene else { return }
        let lyra = world.lyra
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: lyra.position,
            color: SKColor(red: 0.95, green: 0.88, blue: 0.55, alpha: 1), count: 20))
        lyra.run(.sequence([
            .fadeOut(withDuration: 1.2),
            .run { [weak lyra] in
                // Le node ressert pour son Écho (Acte III) : rendu intact.
                lyra?.isHidden = true
                lyra?.alpha = 1
                lyra?.zRotation = 0
                lyra?.forEachDescendantSprite { $0.colorBlendFactor = 0 }
            }
        ]))
        scene.run(.sequence([
            .wait(forDuration: 1.5),
            .run { [weak self] in
                guard let self else { return }
                // L'après-mort dépend du choix : complice (« Oui ») ou dépassé
                // et brisé (« … »). Cf. playCorruptionChoiceThenDeath.
                let aloneDialogue = player.kaelChoseCorruption
                    ? PrototypeContent.act2KaelAloneDialogue
                    : PrototypeContent.act2KaelAloneResistedDialogue
                dialogue.start(aloneDialogue) { [weak self] in
                    guard let self, let scene = self.scene else { return }
                    phase = .fallen
                    transition(to: .exploration)
                    saveGame()
                    TransitionManager.showAct2EndScreen(in: scene) { [weak self] in
                        guard let self, let sc = self.scene else { return }
                        TransitionManager.showCredits(in: sc) { [weak self] in
                            self?.beginAct3()
                        }
                    }
                }
            }
        ]))
    }
}
