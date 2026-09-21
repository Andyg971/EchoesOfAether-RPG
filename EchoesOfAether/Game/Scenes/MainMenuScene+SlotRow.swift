import SpriteKit

// MainMenuScene — ligne de slot de sauvegarde (résumé de partie, bouton supprimer).
extension MainMenuScene {
    // MARK: - Slot row

    func makeSlotRow(slot: Int, height: CGFloat, width: CGFloat) -> SKShapeNode {
        let hasSave = SaveManager.hasSave(slot: slot)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        let row = SKShapeNode()
        PixelUI.stylePanel(row, size: CGSize(width: width, height: height),
                           fill: hasSave
                               ? SKColor(red: 0.07, green: 0.12, blue: 0.18, alpha: 0.97)
                               : SKColor(red: 0.13, green: 0.09, blue: 0.20, alpha: 0.97),
                           accent: hasSave
                               ? SKColor(red: 0.38, green: 0.68, blue: 0.95, alpha: 0.9)
                               : SKColor(red: 0.62, green: 0.46, blue: 0.92, alpha: 0.85))
        row.name = "slotRow\(slot)"
        row.userData = ["slot": slot]

        let leftX = -width / 2 + 18

        let titleL = SKLabelNode(fontNamed: PixelUI.uiFont)
        titleL.text = String(localized: "menu.slot \(slot)")
        titleL.fontSize = 22
        titleL.fontColor = .white
        titleL.horizontalAlignmentMode = .left
        titleL.verticalAlignmentMode = .center
        titleL.position = CGPoint(x: leftX, y: 11)
        titleL.isUserInteractionEnabled = false
        row.addChild(titleL)

        let subL = SKLabelNode(fontNamed: PixelUI.uiFont)
        if hasSave, let meta = SaveManager.metadata(slot: slot) {
            if meta.completed {
                // Partie terminée : le tap relance en New Game+ (palier suivant).
                subL.text = String(localized: "menu.slot.newGamePlus \(meta.newGamePlus + 1)")
                subL.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1)
            } else {
                subL.text = String(localized: "menu.slot.meta \(phaseDisplayName(meta.phase)) \(meta.level) \(meta.gold)")
                subL.fontColor = SKColor(red: 0.70, green: 0.80, blue: 0.92, alpha: 0.95)
            }
        } else {
            subL.text = String(localized: "menu.newGame")
            subL.fontColor = SKColor(red: 0.80, green: 0.72, blue: 0.95, alpha: 0.9)
        }
        subL.fontSize = 15
        subL.horizontalAlignmentMode = .left
        subL.verticalAlignmentMode = .center
        subL.position = CGPoint(x: leftX, y: -12)
        subL.isUserInteractionEnabled = false
        row.addChild(subL)

        // Bouton suppression (uniquement si une sauvegarde existe)
        if hasSave {
            let confirming = confirmDeleteSlot == slot
            // Carré pixel (pas de cercle : le rond casse le style rétro).
            let delBtn = SKShapeNode(rect: CGRect(x: -15, y: -15, width: 30, height: 30))
            delBtn.fillColor = confirming
                ? SKColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
                : SKColor(red: 0.16, green: 0.08, blue: 0.10, alpha: 1)
            delBtn.strokeColor = confirming
                ? SKColor(red: 1.0, green: 0.30, blue: 0.25, alpha: 1)
                : SKColor(red: 0.65, green: 0.25, blue: 0.25, alpha: 0.9)
            delBtn.lineWidth = 2
            delBtn.glowWidth = 0
            delBtn.name = "slotDelete\(slot)"
            delBtn.userData = ["slot": slot]
            delBtn.position = CGPoint(x: width / 2 - 26, y: 0)

            let delLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
            delLbl.text = confirming ? "?" : "✕"
            delLbl.fontSize = confirming ? 20 : 17
            delLbl.fontColor = .white
            delLbl.verticalAlignmentMode = .center
            delLbl.horizontalAlignmentMode = .center
            delLbl.isUserInteractionEnabled = false
            delBtn.addChild(delLbl)
            row.addChild(delBtn)

            if confirming {
                let hint = SKLabelNode(fontNamed: PixelUI.uiFont)
                hint.text = String(localized: "menu.slot.deleteConfirm")
                hint.fontSize = 12
                hint.fontColor = SKColor(red: 1.0, green: 0.45, blue: 0.40, alpha: 1)
                hint.horizontalAlignmentMode = .right
                hint.verticalAlignmentMode = .center
                hint.position = CGPoint(x: width / 2 - 50, y: 0)
                hint.isUserInteractionEnabled = false
                row.addChild(hint)
            }
        }

        return row
    }

    /// Nom court de la phase pour l'affichage du slot.
    func phaseDisplayName(_ phase: GamePhase) -> String {
        switch phase {
        case .wake:     return String(localized: "menu.phase.wake")
        case .village:  return String(localized: "menu.phase.village")
        case .forest:   return String(localized: "menu.phase.forest")
        case .shrine:   return String(localized: "menu.phase.shrine")
        case .complete: return String(localized: "menu.phase.complete")
        case .act2:     return String(localized: "menu.phase.act2")
        case .ruins:    return String(localized: "menu.phase.ruins")
        case .fallen:   return String(localized: "menu.phase.fallen")
        case .act3:     return String(localized: "menu.phase.act3")
        case .act4:     return String(localized: "menu.phase.act4")
        }
    }
}
