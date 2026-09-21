import SpriteKit

// Utilitaires : textes flottants, effets d'annonce, barres.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Helpers


    func configureBar(_ back: SKShapeNode, _ fill: SKShapeNode,
                              width: CGFloat, height: CGFloat,
                              color: SKColor, at position: CGPoint,
                              ghost: SKShapeNode? = nil) {
        // Barres rectangulaires nettes — pas de bouts arrondis en pixel art.
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = CGPath(rect: rect, transform: nil)

        back.path = path
        back.fillColor = SKColor(white: 0.13, alpha: 1)
        back.strokeColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 0.9)
        back.lineWidth = 2
        back.position = position
        root.addChild(back)

        // Barre fantôme : blanche, fond après les dégâts (feedback juteux)
        if let ghost {
            ghost.path = path
            ghost.fillColor = SKColor(white: 0.92, alpha: 0.55)
            ghost.strokeColor = .clear
            ghost.position = position
            ghost.xScale = 1.0
            root.addChild(ghost)
        }

        fill.path = path
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.position = position
        fill.xScale = 1.0
        root.addChild(fill)
    }

    /// Barre fantôme : suit la vraie barre avec un temps de retard quand
    /// les PV baissent ; se cale instantanément quand ils remontent.
    func updateGhostBar(_ ghost: SKShapeNode, to ratio: CGFloat) {
        if ratio >= ghost.xScale - 0.001 {
            ghost.removeAllActions()
            ghost.xScale = ratio
            return
        }
        ghost.removeAllActions()
        let melt = SKAction.scaleX(to: ratio, duration: 0.35)
        melt.timingMode = .easeOut
        ghost.run(.sequence([.wait(forDuration: 0.30), melt]))
    }


    func addCombatantLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 19
        label.fontColor = .white
        label.position = position
        root.addChild(label)
    }

    func addSmallLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 13
        label.fontColor = SKColor(white: 0.6, alpha: 1)
        label.position = position
        root.addChild(label)
    }

    func addButton(_ node: SKShapeNode, title: String, at position: CGPoint,
                           width: CGFloat, height: CGFloat,
                           fill: SKColor, stroke: SKColor,
                           fontSize: CGFloat = 14,
                           chip: SKColor? = nil) {
        node.removeAllChildren()
        PixelUI.stylePanel(node, size: CGSize(width: width, height: height),
                           fill: fill, accent: stroke)
        node.position = position
        node.zPosition = 860

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = title
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        // Pastille d'élément : losange pixel net à gauche du texte.
        if let chip {
            label.horizontalAlignmentMode = .left
            let textW = label.frame.width
            let chipSide: CGFloat = 7
            let contentW = textW + chipSide + 6
            label.position = CGPoint(x: -contentW / 2 + chipSide + 6, y: 0)

            let diamond = SKSpriteNode(color: chip,
                                       size: CGSize(width: chipSide, height: chipSide))
            diamond.zRotation = .pi / 4
            diamond.position = CGPoint(x: -contentW / 2 + chipSide / 2, y: 0)
            node.addChild(diamond)
        }

        root.addChild(node)
    }
}
