import SpriteKit

// Acte II : village corrompu, ruines, découverte et mort de Lyra.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Act 2 Flow

    func beginAct2() {
        guard scene != nil else { return }
        GameCenterManager.shared.report(.act2Reached)
        // Le cristal-mère de Lyra ne se conclut qu'au comptoir du village
        // (openLyraDialogue, cas .found) — inatteignable dès que l'Acte II
        // commence (Lyra passe sur openAct2LyraDialogue, sans branche de
        // quête). Un joueur qui trouve le cristal puis file au Sanctuaire
        // perdait la conclusion — et l'or — pour toujours. On la solde ici,
        // sans la scène dédiée (elle ne collerait plus au ton de l'Acte II).
        if player.questLyraShards == .found {
            player.questLyraShards = .complete
            player.gold += 50
            syncGold()
            GameCenterManager.shared.report(.lyraQuest)
        }
        phase = .act2
        // Kael rentre du Sanctuaire : il réapparaît sur la CARTE DU MONDE et
        // regagne Solis À PIED (le village a changé pendant son absence). Les
        // retrouvailles + la révélation du Sage se jouent à l'ENTRÉE du village
        // — cf. enterZoneFromMap / playAct2VillageReturn — et non plus ici.
        discoveredPlaces.insert("shrine")
        discoveredPlaces.insert("village")
        enterOverworld(spawnNear: "shrine",
                       objective: String(localized: "hud.objective.act2"))
        saveGame()
    }

    /// Arrivée à Solis en Acte II, jouée à l'entrée du village (retour à pied
    /// depuis la carte) : retrouvailles puis révélation du Sage, cap sur les
    /// Ruines. Idempotente via `player.act2Returned` — rejouée seulement tant
    /// que Kael n'a pas encore franchi la porte de Solis.
    func playAct2VillageReturn() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2ReturnVillageDialogue) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act2SageRevelationDialogue) { [weak self] in
                guard let self else { return }
                player.act2Returned = true
                player.act2SageConsulted = true
                hud.objectiveText = String(localized: "hud.objective.ruins")
                transition(to: .exploration)
                saveGame()
            }
        }
    }

    // MARK: - Act 2 Village NPC interactions

    func tryAct2VillageInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let radius: CGFloat = 32
        // Garen est masqué en Acte II (cf. repositionDorinToGate) — donc absent
        // des candidats. On choisit le PNJ le plus proche dans le rayon pour
        // éviter un conflit de tap quand Dorin (porte nord) est proche d'un autre.
        let candidates: [(node: SKNode, action: () -> Void)] = [
            (world.lyra,     { [weak self] in self?.openAct2LyraDialogue() }),
            (world.dorin,    { [weak self] in self?.handleAct2Dorin(scene: scene) }),
            (world.sage,     { [weak self] in self?.handleAct2Sage(scene: scene) }),
            (world.bram,     { [weak self] in self?.openBramShop() }),
            (world.mara,     { [weak self] in self?.openMaraInteraction(scene: scene) }),
            (world.child,    { [weak self] in self?.openAct2ChildDialogue() }),
            (world.villager, { [weak self] in self?.openAct2VillagerDialogue() })
        ]
        if let action = nearestInteraction(from: point, candidates: candidates, radius: radius) {
            action()
            return true
        }
        return false
    }

    func openAct2LyraDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2LyraAnalysisDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// L'enfant a peur de Kael maintenant — la corruption se voit.
    func openAct2ChildDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.childAct2Dialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// La villageoise avertit Kael : ne pas écouter la Voix.
    func openAct2VillagerDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.villagerAct2Dialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Dorin garde la porte nord (Garen retiré Acte II) :
    /// 1) bloque si !act2DorinPassed
    /// 2) ouvre les ruines si Sage consulté
    /// 3) sinon doute (Dorin attend que Kael consulte le Sage)
    func handleAct2Dorin(scene: SKScene) {
        if !player.act2DorinPassed {
            openDorinBlock(scene: scene)
        } else if player.act2SageConsulted {
            enterRuins()
        } else {
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2DorinDoubtDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Sage / auberge : cauchemar d'abord si pas encore vu.
    func handleAct2Sage(scene: SKScene) {
        if !player.act2NightmareSeen {
            openNightmareSequence(scene: scene)
        } else {
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2SageRevelationDialogue) { [weak self] in
                guard let self else { return }
                player.act2SageConsulted = true
                transition(to: .exploration)
            }
        }
    }

    func openNightmareSequence(scene: SKScene) {
        transition(to: .dialogue)
        // Flash sombre pour simuler le rêve
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.05, green: 0.02, blue: 0.10, alpha: 1),
                                 duration: 0.5)
        dialogue.start(PrototypeContent.act2NightmareDialogue) { [weak self] in
            guard let self else { return }
            player.act2NightmareSeen = true
            // Après le cauchemar : révélation du Sage
            transition(to: .shop)
            shop.open(
                title: String(localized: "shop.inn.title"),
                items: innItems(),
                player: player
            ) { [weak self] in
                guard let self else { return }
                syncGold()
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act2SageRevelationDialogue) { [weak self] in
                    guard let self else { return }
                    player.act2SageConsulted = true
                    transition(to: .exploration)
                }
            }
        }
    }

    func openDorinBlock(scene: SKScene) {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2DorinBlockDialogue) { [weak self] in
            guard let self else { return }
            player.act2DorinPassed = true
            transition(to: .exploration)
        }
    }

    func enterRuins() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .ruins
            hud.objectiveText = String(localized: "hud.objective.ruins")
            showRuins(in: scene)
        } completion: { [weak self] in
            guard let self else { return }
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2RuinsEnterDialogue) { [weak self] in
                guard let self, let scene = self.scene else { return }
                // Vision 1 automatique — flash rouge + corruption niveau 1
                if !player.act2Vision1Seen {
                    player.act2Vision1Seen = true
                    player.kaelCorruptionLevel = max(player.kaelCorruptionLevel, 1)
                    world.applyKaelCorruption(level: player.kaelCorruptionLevel)
                    JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                             color: SKColor(red: 0.65, green: 0.08, blue: 0.05, alpha: 1),
                                             duration: 0.45)
                    JuiceEngine.screenShake(scene, intensity: 3)
                    dialogue.start(PrototypeContent.act2Vision1Dialogue) { [weak self] in
                        self?.transition(to: .exploration)
                    }
                } else {
                    transition(to: .exploration)
                }
            }
        }
    }

}
