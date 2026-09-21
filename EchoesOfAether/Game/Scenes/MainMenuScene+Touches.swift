import SpriteKit

// MainMenuScene — touches : surbrillance, slots, suppression avec confirmation.
extension MainMenuScene {
    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        highlightedButton = slotRow(at: point)
        highlightedButton?.run(.scale(to: 0.97, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            clearHighlight()
            return
        }
        defer { clearHighlight() }

        // 1) Bouton de suppression (prioritaire sur la ligne)
        if let slot = deleteSlot(at: point) {
            handleDeleteTap(slot: slot)
            return
        }

        // 2) Tap sur une ligne de slot
        guard let row = slotRow(at: point), row === highlightedButton,
              let slot = row.userData?["slot"] as? Int else {
            resetDeleteConfirmIfNeeded()
            return
        }
        resetDeleteConfirmIfNeeded()
        HapticsEngine.light()
        // Partie terminée (une fin choisie) → relance en New Game+ : acquis
        // conservés, histoire rejouée, difficulté relevée.
        if let meta = SaveManager.metadata(slot: slot), meta.completed,
           let data = SaveManager.load(slot: slot) {
            transitionToGame(slot: slot, newGame: true,
                             seed: NewGamePlusSeed(from: data))
        } else if SaveManager.hasSave(slot: slot) {
            transitionToGame(slot: slot, newGame: false)
        } else {
            transitionToGame(slot: slot, newGame: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearHighlight()
    }

    func handleDeleteTap(slot: Int) {
        HapticsEngine.heavy()
        if confirmDeleteSlot == slot {
            // Deuxième tap : suppression effective.
            SaveManager.delete(slot: slot)
            confirmDeleteSlot = nil
            HapticsEngine.error()
            rebuild()
        } else {
            confirmDeleteSlot = slot
            rebuild()
        }
    }

    func resetDeleteConfirmIfNeeded() {
        guard confirmDeleteSlot != nil else { return }
        confirmDeleteSlot = nil
        rebuild()
    }

    func rebuild() {
        removeAllChildren()
        buildUI()
    }



    /// Renvoie la ligne de slot touchée (en remontant au parent si besoin).
    func slotRow(at point: CGPoint) -> SKShapeNode? {
        for node in nodes(at: point) {
            if let row = node as? SKShapeNode, row.name?.hasPrefix("slotRow") == true {
                return row
            }
            var parent = node.parent
            while let p = parent {
                if let row = p as? SKShapeNode, row.name?.hasPrefix("slotRow") == true {
                    return row
                }
                parent = p.parent
            }
        }
        return nil
    }

    /// Renvoie le slot dont le bouton de suppression a été touché.
    func deleteSlot(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            if let btn = node as? SKShapeNode, btn.name?.hasPrefix("slotDelete") == true,
               let slot = btn.userData?["slot"] as? Int {
                return slot
            }
            if let btn = node.parent as? SKShapeNode, btn.name?.hasPrefix("slotDelete") == true,
               let slot = btn.userData?["slot"] as? Int {
                return slot
            }
        }
        return nil
    }

    func clearHighlight() {
        highlightedButton?.run(.scale(to: 1.0, duration: 0.08))
        highlightedButton = nil
    }
}
