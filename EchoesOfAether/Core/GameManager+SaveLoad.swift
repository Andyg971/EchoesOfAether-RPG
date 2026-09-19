import SpriteKit

// Sauvegarde / chargement, helpers de localisation.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Save / Load

    func saveGame() {
        let data = player.toSaveData(phase: phase, resonance: resonanceTotal)
        SaveManager.save(data, slot: activeSlot)
    }

    func restoreFrom(save: SaveData, scene: SKScene) {
        player.load(from: save)
        resonanceTotal = save.resonanceTotal
        phase = save.phase
        inMines = false   // la save ne stocke jamais l'excursion aux mines
        inDesert = false  // ni le voyage au désert : respawn en zone d'origine

        hud.goldValue = player.gold
        hud.resonanceValue = resonanceTotal

        switch phase {
        case .wake:
            startWakeSequence()
        case .village:
            hud.objectiveText = String(localized: "hud.objective.village")
            transition(to: .exploration)
        case .forest:
            hud.objectiveText = String(localized: "hud.objective.forest")
            showForest(in: scene)
            if player.questChildToy == .active {
                world.addToyMarker(in: scene)
            }
            if player.questMedallion == .active {
                world.addMedallionMarker(in: scene)
            }
            addSideQuestMarkers(in: scene)
            // Spawn à l'orée sud du trek (la forêt scrolle).
            world.kael.position = CGPoint(x: scene.size.width * 0.5,
                                          y: world.worldHeight * 0.05)
            transition(to: .exploration)
        case .shrine:
            hud.objectiveText = String(localized: "hud.objective.shrine")
            world.switchToShrine(in: scene)
            transition(to: .exploration)
        case .complete:
            // Save interrompue entre la fin de l'Acte I et le début de
            // l'Acte II : sans relance, aucun déclencheur de suite (cul-de-sac,
            // même famille que le boss forêt déjà vaincu). On reprend la suite.
            hud.objectiveText = String(localized: "hud.objective.complete")
            transition(to: .exploration)
            requireFullGame { [weak self] in self?.beginAct2() }

        case .act2:
            world.switchToVillage(in: scene)
            world.repositionDorinToGate(in: scene)
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            if player.act2Returned {
                hud.objectiveText = String(localized: "hud.objective.ruins")
                transition(to: .exploration)
            } else {
                // Save faite avant d'avoir regagné Solis (ex. quittée sur la
                // carte, en route vers le village) : on rejoue l'arrivée ici
                // plutôt que de la perdre.
                playAct2VillageReturn()
            }

        case .ruins:
            hud.objectiveText = player.ruinsProgress >= 2
                ? String(localized: "hud.objective.discovery")
                : String(localized: "hud.objective.ruins")
            showRuins(in: scene)
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            transition(to: .exploration)

        case .fallen:
            hud.objectiveText = String(localized: "hud.objective.fallen")
            showRuins(in: scene)
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            transition(to: .exploration)
            // Save interrompue à la fin de l'Acte II : re-propose la suite.
            TransitionManager.showAct2EndScreen(in: scene) { [weak self] in
                self?.beginAct3()
            }

        case .act3:
            hud.objectiveText = player.act3BossDefeated
                ? String(localized: "hud.objective.act3End")
                : (player.act3EranMet
                    ? String(localized: "hud.objective.act3Boss")
                    : String(localized: "hud.objective.act3"))
            showThreshold(in: scene)
            world.applyKaelCorruption(level: 3)
            corruptionCinematicShown = true
            transition(to: .exploration)

        case .act4:
            hud.objectiveText = player.act4BossDefeated
                ? String(localized: "hud.objective.act4End")
                : (player.act4VoiceConfronted
                    ? String(localized: "hud.objective.act4Boss")
                    : String(localized: "hud.objective.act4"))
            showVoidHeart(in: scene)
            world.applyKaelCorruption(level: 3)
            corruptionCinematicShown = true
            transition(to: .exploration)
        }
    }

    // MARK: - Localization helpers

    /// Résout les clés de hint via un switch statique
    /// pour que Xcode puisse les trouver dans le code source.
    func localizedHint(_ key: String) -> String {
        switch key {
        case "hint.talk":    return String(localized: "hint.talk")
        case "hint.shop":    return String(localized: "hint.shop")
        case "hint.fight":   return String(localized: "hint.fight")
        case "hint.examine": return String(localized: "hint.examine")
        case "hint.enter":   return String(localized: "hint.enter")
        case "hint.exit":    return String(localized: "hint.exit")
        default:             return key
        }
    }
}
