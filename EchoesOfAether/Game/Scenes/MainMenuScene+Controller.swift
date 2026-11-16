import SpriteKit

// Menu principal à la manette : haut/bas choisit le slot, A lance,
// X supprime (deux pressions, comme au tap), B annule la suppression.
extension MainMenuScene {

    func setupControllerNavigation() {
        let input = GameControllerInput.shared
        input.start()
        input.onPress = { [weak self] button in
            self?.handleControllerPress(button)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let v = GameControllerInput.shared.stick
        let magnitude = max(abs(v.dx), abs(v.dy))
        if controllerNavLatched {
            if magnitude < 0.30 { controllerNavLatched = false }
            return
        }
        guard magnitude > 0.60, abs(v.dy) > abs(v.dx) else { return }
        controllerNavLatched = true
        moveControllerSelection(v.dy > 0 ? -1 : 1)
    }

    private func moveControllerSelection(_ step: Int) {
        let next = min(max(controllerSlot + step, 1), SaveManager.slotCount)
        guard next != controllerSlot else { return }
        controllerSlot = next
        if confirmDeleteSlot != nil {
            confirmDeleteSlot = nil
            rebuild()
        }
        HapticsEngine.light()
        refreshControllerSelection()
    }

    private func handleControllerPress(_ button: GameControllerInput.Button) {
        switch button {
        case .confirm:
            if confirmDeleteSlot != nil { resetDeleteConfirmIfNeeded() }
            launchSlot(controllerSlot)
        case .west:
            if SaveManager.hasSave(slot: controllerSlot) {
                handleDeleteTap(slot: controllerSlot)
            }
        case .back:
            resetDeleteConfirmIfNeeded()
        default:
            break
        }
    }

    /// Surligne le slot choisi à la manette (rien tant qu'aucune n'est branchée).
    func refreshControllerSelection() {
        let connected = GameControllerInput.shared.isConnected
        for slot in 1...SaveManager.slotCount {
            guard let row = childNode(withName: "slotRow\(slot)") else { continue }
            let selected = connected && slot == controllerSlot
            row.run(.scale(to: selected ? 1.04 : 1.0, duration: 0.08))
        }
    }
}
