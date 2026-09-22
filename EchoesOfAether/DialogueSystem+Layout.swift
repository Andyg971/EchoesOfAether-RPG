import SpriteKit
import UIKit

// DialogueSystem — géométrie du panneau : largeur, hauteur selon les choix, mise en page.
extension DialogueSystem {

    /// Hauteur ajustée au contenu : en-tête (prompt) + somme des boutons de
    /// choix (chacun sur sa hauteur réelle, 1 ou 2 lignes) + marge basse —
    /// plus de grand vide noir sous les choix, et plus de texte qui déborde
    /// sur le bouton suivant quand un titre est long.
    private var panelHeightChoices: CGFloat {
        guard !choiceHeights.isEmpty else { return 68 }
        return 40 + choiceHeights.reduce(0, +) + CGFloat(choiceHeights.count - 1) * 4
    }

    /// Largeur compacte : le panneau ne barre plus tout l'écran.
    func panelWidth(for size: CGSize) -> CGFloat {
        min(size.width - 48, 640)
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        self.safeBottom = safeBottom
        // Accessibilité « gros texte » : agrandit les polices du dialogue.
        // VT323 est étroite : tailles relevées pour garder la lisibilité.
        let ts = AccessibilitySettings.textScale
        speakerLabel.fontSize = 15 * ts
        bodyLabel.fontSize = 14 * ts
        continueIndicator.fontSize = 12 * ts
        let hasChoices = !choiceNodes.isEmpty
        let panelWidth = panelWidth(for: size)

        // Géométrie du portrait AVANT la hauteur : la largeur de texte en
        // dépend, et la hauteur du panneau suit le texte mesuré — les
        // longues répliques (Dorin, Sage…) passent sur 3 lignes sans
        // déborder du cadre.
        let portraitSide: CGFloat = 52
        let portraitX = -panelWidth / 2 + portraitSide / 2 + 10
        // En mode choix, le portrait recouvrait les boutons : on le masque.
        let showPortrait = hasPortrait && !hasChoices
        let textX = showPortrait
            ? portraitX + portraitSide / 2 + 12
            : -panelWidth / 2 + 14
        bodyLabel.preferredMaxLayoutWidth = panelWidth - (textX + panelWidth / 2) - 18

        let bodyHeight = max(16, bodyLabel.frame.height)
        let panelHeight = hasChoices
            ? panelHeightChoices
            : max(panelHeightLine, 34 + bodyHeight + 16)

        // Cadre RPG pixel art (coins carrés, liseré sombre + bordure or)
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight))

        let baseY = panelHeight / 2 + 20 + safeBottom
        root.position = CGPoint(x: size.width / 2, y: baseY)

        // Portrait (44px natif) dans un cadre pixel à gauche ; le texte
        // se décale quand un visage est affiché.
        PixelUI.stylePanel(portraitFrame,
                           size: CGSize(width: portraitSide, height: portraitSide),
                           fill: SKColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1),
                           accent: PixelUI.goldDim)
        portraitFrame.position = CGPoint(x: portraitX, y: 0)
        portraitSprite.position = portraitFrame.position
        portraitSprite.size = CGSize(width: portraitSide - 8, height: portraitSide - 8)
        portraitFrame.isHidden = !showPortrait
        portraitSprite.isHidden = !showPortrait

        speakerLabel.position = CGPoint(x: textX, y: panelHeight / 2 - 16)

        let sepY = panelHeight / 2 - 26
        let sepPath = CGMutablePath()
        sepPath.move(to: CGPoint(x: textX, y: sepY))
        sepPath.addLine(to: CGPoint(x: panelWidth / 2 - 22, y: sepY))
        separator.path = sepPath

        bodyLabel.position = CGPoint(x: textX, y: sepY - 6)

        continueIndicator.position = CGPoint(x: panelWidth / 2 - 18, y: -panelHeight / 2 + 16)

        layoutChoices(panelWidth: panelWidth, panelHeight: panelHeight)
    }
}
