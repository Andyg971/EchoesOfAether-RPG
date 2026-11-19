import SpriteKit

// Manettes physiques : le stick alimente le joystick virtuel et les boutons
// rejouent les gestes tactiles (A, B, pause…), sans second chemin de logique.
@MainActor
extension GameManager {

    func setupControllerInput() {
        let input = GameControllerInput.shared
        input.start()
        input.onPress = { [weak self] button in self?.handleControllerPress(button) }
    }

    /// Recopie le stick / la croix dans `padVector`. Le pouce garde la
    /// priorité s'il tient déjà le joystick tactile.
    func applyControllerStick() {
        let vector = GameControllerInput.shared.stick
        if vector != .zero {
            guard controllerDriving || !padActive else { return }
            controllerDriving = true
            padActive = true
            padVector = vector
        } else if controllerDriving {
            controllerDriving = false
            padActive = false
            padVector = .zero
            movement.setManualWalk(world.kael, dx: 0, active: false)
        }
    }

    func handleControllerPress(_ button: GameControllerInput.Button) {
        guard let scene, state != .transition else { return }
        switch button {
        case .confirm: handleControllerConfirm(in: scene)
        case .back: handleBPress()
        case .start: toggleControllerPause()
        case .north: if canOpenFromController { openInventory() }
        case .select: if canOpenFromController, worldMapAvailable { openWorldMap() }
        case .west: if canOpenFromController { openQuestLog() }
        case .shoulderLeft: shiftControllerTab(-1)
        case .shoulderRight: shiftControllerTab(1)
        }
    }

    /// Exploration libre : aucun overlay, dialogue ni cinématique par-dessus.
    private var canOpenFromController: Bool {
        state == .exploration && !death.isActive && !tutorial.isActive
            && !dismissableOverlayActive && !skills.isActive && !paywall.isActive
            && !isFishing && prologueNode == nil
    }

    private func toggleControllerPause() {
        if pause.isActive { handleBPress(); return }
        if canOpenFromController || state == .dialogue { openPause() }
    }

    private func shiftControllerTab(_ step: Int) {
        if lore.isActive { lore.navigateTabs(step) }
        if inventory.picker.isOpen { inventory.picker.switchHero(step) }
    }

    /// A : prioritaire sur les couches qui n'ont qu'un geste tactile, puis
    /// la logique commune du bouton A.
    private func handleControllerConfirm(in scene: SKScene) {
        if tutorial.isActive { popActionButton(); tutorial.advanceExternally(); return }
        if levelUp.handleTap(at: .zero, in: scene) { return }
        if death.isActive { popActionButton(); death.confirmSelection(); return }
        if TransitionManager.confirmActiveEndOverlay(in: scene) { return }
        if prologueNode != nil { endPrologue(); return }
        // Panneaux sans sélection au curseur : A ne doit pas déclencher
        // l'interaction du monde cachée derrière eux.
        if options.isActive { options.confirmCursor(in: scene); return }
        if worldMap.isActive { worldMap.confirmCursor(in: scene); return }
        if lore.isActive || questLog.isActive { return }
        handleAPress(in: scene)
    }
}
