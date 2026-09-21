import SpriteKit
import UIKit

// DialogueSystem — choix de dialogue : curseur, validation, création et mise en page des boutons.
extension DialogueSystem {
    /// Joystick haut/bas : déplace le curseur sur les choix.
    func moveChoiceSelection(_ dy: Int) {
        guard isActive, !choiceNodes.isEmpty else { return }
        let count = choiceNodes.count
        choiceSelection = (choiceSelection - dy + count) % count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshChoiceHighlight()
        if let title = choiceNodes[choiceSelection].userData?["title"] as? String {
            AccessibilitySettings.announce(title)
        }
    }

    /// Le choix sélectionné est encadré d'or, les autres estompés.
    func refreshChoiceHighlight() {
        for (i, node) in choiceNodes.enumerated() {
            let selected = i == choiceSelection
            node.strokeColor = selected
                ? PixelUI.gold
                : SKColor(red: 0.62, green: 0.48, blue: 0.90, alpha: 0.5)
            node.alpha = selected ? 1.0 : 0.72
            node.setScale(selected ? 1.02 : 1.0)
        }
    }

    /// Bouton A pendant un choix : valide le choix sélectionné.
    func confirmChoice() {
        guard isActive, choiceNodes.indices.contains(choiceSelection) else { return }
        let node = choiceNodes[choiceSelection]
        guard let title = node.userData?["title"] as? String,
              let npcSpeaker = node.userData?["responseSpeaker"] as? String,
              let npcText = node.userData?["response"] as? String else { return }
        if let chosenIndex = node.userData?["index"] as? Int {
            lastChoiceIndex = chosenIndex
            onChoiceSelected?(chosenIndex)
        }
        answeredChoiceIndex = index
        pendingNPC = (speaker: npcSpeaker, text: npcText)
        clearChoices()
        let kaelName = String(localized: "dialogue.kael")
        speakerLabel.text = kaelName
        applyPortrait(for: kaelName)
        bodyLabel.text = title
        continueIndicator.isHidden = false
        AudioEngine.shared.playSelect()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    var hasChoicesOnScreen: Bool { !choiceNodes.isEmpty }

    func createChoices(_ options: [DialogueChoice]) {
        guard let sceneRef = root.scene else { return }
        let panelWidth = panelWidth(for: sceneRef.size)
        let buttonWidth = panelWidth - 28
        let minButtonHeight: CGFloat = 28

        for (offset, option) in options.enumerated() {
            // Le label est mesuré AVANT le bouton : un titre qui passe sur
            // 2 lignes (traductions longues, FR en particulier) doit gonfler
            // le bouton plutôt que déborder sur celui d'en dessous.
            let label = SKLabelNode(fontNamed: PixelUI.uiFont)
            label.text = option.title
            label.fontSize = 12 * AccessibilitySettings.textScale
            label.fontColor = .white
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = buttonWidth - 32
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left

            let buttonHeight = max(minButtonHeight, ceil(label.frame.height) + 14)
            choiceHeights.append(buttonHeight)

            let button = SKShapeNode()
            PixelUI.stylePanel(button,
                               size: CGSize(width: buttonWidth, height: buttonHeight),
                               fill: SKColor(red: 0.11, green: 0.09, blue: 0.14, alpha: 1),
                               accent: SKColor(red: 0.62, green: 0.48, blue: 0.90, alpha: 1))
            button.userData = [
                "title": option.title,
                "responseSpeaker": option.responseSpeaker,
                "response": option.response,
                "index": offset
            ]

            // Puce en losange pixel (carré tourné) — plus de cercle ni de
            // glow, cohérent avec le reste de l'UI rétro.
            let bullet = SKSpriteNode(color: SKColor(red: 0.65, green: 0.45, blue: 1, alpha: 1),
                                      size: CGSize(width: 5, height: 5))
            bullet.zRotation = .pi / 4
            bullet.position = CGPoint(x: -buttonWidth / 2 + 12, y: 0)
            button.addChild(bullet)

            label.position = CGPoint(x: -buttonWidth / 2 + 22, y: 0)
            button.addChild(label)

            let chevron = SKLabelNode(fontNamed: PixelUI.uiFont)
            chevron.text = "›"
            chevron.fontSize = 13
            chevron.fontColor = SKColor(red: 0.65, green: 0.55, blue: 0.95, alpha: 0.8)
            chevron.verticalAlignmentMode = .center
            chevron.horizontalAlignmentMode = .right
            chevron.position = CGPoint(x: buttonWidth / 2 - 10, y: 0)
            button.addChild(chevron)

            // Position provisoire — layoutChoices() replace précisément
            // dès que la hauteur dynamique du panneau est connue.
            let yOffset = -CGFloat(offset) * (buttonHeight + 4)
            button.position = CGPoint(x: 0, y: yOffset - 10)

            root.addChild(button)
            choiceNodes.append(button)

            JuiceEngine.popIn(button, delay: Double(offset) * 0.06)
        }
        choiceSelection = 0
        refreshChoiceHighlight()
    }

    func layoutChoices(panelWidth: CGFloat, panelHeight: CGFloat) {
        guard !choiceNodes.isEmpty, choiceHeights.count == choiceNodes.count else { return }
        // Premier bouton à 30pt sous le haut du panneau (même retrait que
        // l'ancien pas fixe) ; chaque bouton suivant colle au précédent avec
        // 4pt d'écart, sur SA hauteur réelle — plus de chevauchement quand
        // un titre passe sur 2 lignes.
        var cursorY = panelHeight / 2 - 30 - choiceHeights[0] / 2

        for (offset, node) in choiceNodes.enumerated() {
            if offset > 0 {
                cursorY -= choiceHeights[offset - 1] / 2 + 4 + choiceHeights[offset] / 2
            }
            node.position = CGPoint(x: 0, y: cursorY)
        }
    }

    func clearChoices() {
        choiceNodes.forEach { $0.removeFromParent() }
        choiceNodes.removeAll()
        choiceHeights.removeAll()
    }
}
