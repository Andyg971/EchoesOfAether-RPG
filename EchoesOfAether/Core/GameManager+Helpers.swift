import SpriteKit

// Utilitaires : audits debug, journal de quêtes, entrées de lore.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Helpers

    /// Debug : `--combat-script <n>` descend n fois dans le menu de combat
    /// puis valide. Le combat n'accepte AUCUN tap (`CombatSystem.handleTap`
    /// avale tout) — il se pilote au joystick + A/B, ce qui est impossible à
    /// simuler proprement. Ce script passe par la même API publique que les
    /// contrôles classiques, donc il exerce le vrai chemin de code.
    func scheduleDebugMenuScript() {
        guard let idx = CommandLine.arguments.firstIndex(of: "--combat-script"),
              CommandLine.arguments.indices.contains(idx + 1),
              let steps = Int(CommandLine.arguments[idx + 1]) else { return }
        // Le combat de boss s'ouvre sur un dialogue : naviguer pendant ce
        // temps ne fait rien. On attend donc que le menu ait vraiment la main
        // plutôt que de parier sur un délai fixe.
        func attempt(_ remaining: Int) {
            guard remaining > 0 else { return }
            guard state == .combat, !dialogue.isActive else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard self != nil else { return }
                    attempt(remaining - 1)
                }
                return
            }
            for _ in 0..<steps { combat.menuNav(dx: 0, dy: -1) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.combat.menuConfirm()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { attempt(60) }
    }

    /// Ouvre un overlay par son nom (hook debug --overlay-test).
    func debugShowOverlay(named name: String) {
        guard let scene else { return }
        switch name {
        case "pause":     openPause()
        case "options":   openOptions()
        case "skills":
            // Audit visuel : niveau 20 → 19 points à répartir, quelques rangs
            // déjà posés pour voir les trois états (acquis, ouvert, verrouillé).
            player.level = 20
            player.skillRanks = ["blade.attack": 3, "blade.crit": 1, "aether.mp": 2]
            syncLevelHUD()   // le HUD a été rempli avant ce forçage de niveau
            openSkillTree()
            // Curseur descendu d'un cran : met en pied de page une description
            // avec pourcentage, pour vérifier son formatage à la capture.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.skills.moveSelection(dx: 0, dy: -1)
            }
        case "inventory": openInventory()
        case "questlog":  openQuestLog()
        case "lore":      openLore()
        // « tutorial » ou « tutorial:2 » pour ouvrir droit sur un panneau.
        case let n where n == "tutorial" || n.hasPrefix("tutorial:"):
            tutorial.show(in: scene,
                          startAt: Int(n.split(separator: ":").last ?? "") ?? 0)
        case "levelup":   levelUp.show(newLevel: 5, isMax: false) {}
        case "death":     death.show(in: scene)
        case "paywall":   openPaywall()
        case "shop":
            transition(to: .shop)
            shop.open(title: String(localized: "shop.bram.title"),
                      items: bramItems(), player: player) { [weak self] in
                self?.transition(to: .exploration)
            }
        case "credits":
            // Audit : les crédits seuls. Ils n'étaient atteignables qu'en
            // finissant un acte, donc jamais relus — c'est comme ça que leur
            // bouton « Fermer » a pu passer hors écran sans qu'on le voie.
            TransitionManager.showCredits(in: scene) { [weak self] in
                self?.transition(to: .exploration)
            }
        case "act2end":
            // Audit : écran de fin d'Acte II + continuation complète.
            TransitionManager.showAct2EndScreen(in: scene) { [weak self] in
                guard let self, let sc = self.scene else { return }
                TransitionManager.showCredits(in: sc) { [weak self] in
                    self?.beginAct3()
                }
            }
        case "bestiary":
            // Audit : toutes les espèces révélées, ouverture sur l'onglet
            player.bestiarySeen = Set(CombatSpriteKind.allCases.map(\.bestiaryID))
            transition(to: .inventory)
            lore.open(entries: PrototypeContent.buildLoreEntries(for: player),
                      bestiarySeen: player.bestiarySeen,
                      startOnBestiary: true) { [weak self] in
                self?.transition(to: .exploration)
            }
        case "dialogue":
            // Audit des portraits : un locuteur de chaque famille.
            transition(to: .dialogue)
            dialogue.start([
                // Réplique la plus longue du jeu : vérifie que le panneau
                // grandit avec le texte (3 lignes) sans déborder.
                .line(speaker: "Dorin",
                      text: String(localized: "dialogue.dorin.real.6")),
                .line(speaker: "Kael", text: "Audit portrait Kael."),
                .line(speaker: "Lyra", text: "Audit portrait Lyra."),
                .line(speaker: "Dorin", text: "Audit portrait Dorin."),
                .line(speaker: "Sage", text: "Audit portrait Sage."),
                .line(speaker: String(localized: "dialogue.boss.guardianName"),
                      text: "Audit portrait Gardien."),
                .line(speaker: "Eran", text: "Audit portrait Eran."),
                .line(speaker: String(localized: "dialogue.shrine.voiceName"),
                      text: "Audit sans portrait (voix).")
            ]) { [weak self] in self?.transition(to: .exploration) }
        case "dialoguechoice":
            // Audit du panneau de choix compact (hauteur dynamique).
            transition(to: .dialogue)
            dialogue.start([
                .choice(prompt: "Kael", options: [
                    DialogueChoice(title: "Je garderai l'œil ouvert.",
                                   responseSpeaker: "Villageoise",
                                   response: "Merci, voyageur."),
                    DialogueChoice(title: "La forêt est grande. Je ne promets rien.",
                                   responseSpeaker: "Villageoise",
                                   response: "Je comprends...")
                ])
            ]) { [weak self] in self?.transition(to: .exploration) }
        case "worldmap":
            // Audit de la carte du monde (états des lieux selon la phase).
            worldMap.open(places: buildMapPlaces()) {}
        default: break
        }
    }

    func tapAndMove(_ point: CGPoint, in scene: SKScene) {
        let worldPoint = world.worldNode.convert(point, from: scene)
        let worldSize = CGSize(width: scene.size.width, height: world.worldHeight > 0 ? world.worldHeight : scene.size.height)
        // Trajet stoppé au premier obstacle (maison, arbre, eau…)
        let reachable = world.clampDestination(from: world.nearestFreePoint(to: world.kael.position),
                                               to: worldPoint)
        movement.move(world.kael, to: reachable, in: worldSize)
        let marker = ParticleFactory.tapMarker(at: reachable)
        world.worldNode.addChild(marker)
    }

    func transition(to newState: GameState) {
        let wasCombat = state == .combat
        state = newState
        if newState == .exploration { saveGame() }
        // Bulle d'interaction visible uniquement en exploration ;
        // sinon elle resterait à flotter pendant dialogue/combat/pause.
        if newState != .exploration {
            bubble.hide()
            hud.interactionHint = ""
        }
        // Le combat occupe l'écran entier : HUD d'exploration masqué.
        if newState == .combat {
            hud.setVisible(false)
        } else if wasCombat {
            hud.setVisible(true)
        }
        if newState == .exploration { refreshQuestMarkers() }
        // Les PNJ flânent librement dans le village pendant l'exploration ;
        // ils s'arrêtent net dès qu'un dialogue/combat/menu s'ouvre.
        if newState == .exploration, phase == .village,
           !world.isInsideInterior, let scene {
            world.startVillageWander(in: scene.size)
        } else if newState != .exploration {
            world.stopVillageWander()
        }
    }

    /// « ! » doré au-dessus des PNJ qui ont une quête à proposer.
    func refreshQuestMarkers() {
        world.setQuestMarker(on: world.child,
                             visible: phase == .village && player.questChildToy == .inactive)
        world.setQuestMarker(on: world.villager,
                             visible: phase == .village && player.questMedallion == .inactive)
        world.setQuestMarker(on: world.mara,
                             visible: phase == .village && player.questDelivery == .inactive)
        world.setQuestMarker(on: world.lyra,
                             visible: phase == .village && player.questLyraShards == .inactive)
        world.setQuestMarker(on: world.bram,
                             visible: phase == .village && player.questBramOre == .inactive)
        world.setQuestMarker(on: world.sage,
                             visible: phase == .village && player.questSageHerb == .inactive
                                      && player.talkedToSage)
        world.setQuestMarker(on: world.garen,
                             visible: phase == .village && player.questGarenScout == .inactive
                                      && player.questDelivery == .complete)
    }

    /// Place les marqueurs de collecte des quêtes annexes actives (forêt)
    /// et l'entrée des mines de Cendreval (toujours visible).
    func addSideQuestMarkers(in scene: SKScene) {
        if player.questBramOre == .active    { world.addOreMarker(in: scene) }
        if player.questSageHerb == .active   { world.addHerbMarker(in: scene) }
        if player.questGarenScout == .active { world.addBadgeMarker(in: scene) }
        if player.questLyraShards == .active { world.addCrystalMarker(in: scene) }
        world.addMineEntrance(in: scene)
        world.addCaveEntrance(in: scene)   // donjon optionnel (flanc ouest)
    }
}
