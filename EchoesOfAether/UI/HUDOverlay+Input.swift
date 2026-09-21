import SpriteKit

// HUDOverlay — zones de tap des boutons et mise en page selon la safe area.
extension HUDOverlay {
    ///
    /// L'alpha est pris en compte : en combat le HUD d'exploration est fondu à
    /// 0, et le joystick doit alors récupérer toute la zone pour naviguer dans
    /// les menus.
    func containsButton(at point: CGPoint, in scene: SKScene) -> Bool {
        guard root.alpha > 0.5 else { return false }
        let local = root.convert(point, from: scene)
        let buttons = [inventoryButton, pauseButton, loreButton, questLogButton, mapButton]
        return buttons.contains { !$0.isHidden && $0.contains(local) }
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        let local = root.convert(point, from: scene)
        if inventoryButton.contains(local) {
            onInventoryTap?()
            return true
        }
        if pauseButton.contains(local) {
            onPauseTap?()
            return true
        }
        if loreButton.contains(local) {
            onLoreTap?()
            return true
        }
        if questLogButton.contains(local) {
            onQuestLogTap?()
            return true
        }
        if !mapButton.isHidden, mapButton.contains(local) {
            onMapTap?()
            return true
        }
        return false
    }

    func layout(in size: CGSize, safeTop: CGFloat = 0, safeLeft: CGFloat = 0, safeRight: CGFloat = 0) {
        // Échelle du HUD, calée sur la LARGEUR du gabarit et non sur le petit
        // côté. L'ancienne formule `min(w, h) / 390` supposait un écran
        // ~19,5:9 : en 4:3 (iPad) le petit côté explose et le HUD partait à
        // 2,14× pendant que le monde restait à 1×. La scène est désormais mise
        // à l'échelle globalement (cf. Viewport) — il ne reste ici qu'un
        // ajustement fin, borné, pour les écrans plus étroits ou plus larges
        // que le gabarit.
        let s = min(max(size.width / Viewport.designWidth, 0.92), 1.15)
        let margin: CGFloat = 16 * s
        let leftEdge = safeLeft + margin
        let rightEdge = size.width - safeRight - margin
        let topY = size.height - safeTop - 26 * s
        // Accessibilité « gros texte » : agrandit uniquement les polices.
        let f = s * AccessibilitySettings.textScale

        objectiveLabel.fontSize = 13 * f
        resonanceLabel.fontSize = 12 * f
        goldLabel.fontSize = 13 * f
        questLabel.fontSize = 11 * f
        interactionHintLabel.fontSize = 13 * f
        hpLabel.fontSize = 12 * f
        levelLabel.fontSize = 12 * f
        xpLabel.fontSize = 9 * f

        objectiveLabel.position = CGPoint(x: leftEdge + 2 * s, y: topY - 5 * s)
        questLabel.position = CGPoint(x: leftEdge + 2 * s, y: topY - 24 * s)

        resonanceLabel.position = CGPoint(x: rightEdge - 2 * s, y: topY - 2 * s)
        goldLabel.position = CGPoint(x: rightEdge - 2 * s, y: topY - 21 * s)

        let statsX = leftEdge + 2 * s
        hpLabel.position = CGPoint(x: statsX, y: topY - 52 * s)
        levelLabel.position = CGPoint(x: statsX, y: topY - 70 * s)
        let barX = statsX + 44 * s + xpBarWidth / 2
        xpBarBack.position = CGPoint(x: barX, y: topY - 69 * s)
        xpBarFill.position = xpBarBack.position
        xpLabel.position = CGPoint(x: statsX + 44 * s, y: topY - 84 * s)

        let buttonSize = 46 * s
        setButton(pauseButton, size: buttonSize)
        pauseButton.position = CGPoint(x: leftEdge + buttonSize / 2, y: topY - 122 * s)
        setButton(inventoryButton, size: buttonSize)
        inventoryButton.position = CGPoint(x: rightEdge - buttonSize / 2, y: topY - 68 * s)
        setButton(loreButton, size: buttonSize)
        loreButton.position = CGPoint(x: rightEdge - buttonSize / 2, y: topY - 122 * s)
        setButton(questLogButton, size: buttonSize)
        questLogButton.position = CGPoint(x: leftEdge + buttonSize / 2, y: topY - 176 * s)
        setButton(mapButton, size: buttonSize)
        mapButton.position = CGPoint(x: rightEdge - buttonSize / 2, y: topY - 176 * s)

        interactionHintLabel.position = CGPoint(x: size.width / 2,
                                                y: size.height * 0.19)
        refreshShadows()
    }
}
