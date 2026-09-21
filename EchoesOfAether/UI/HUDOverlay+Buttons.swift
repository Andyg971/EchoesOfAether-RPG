import SpriteKit

// HUDOverlay — les cinq boutons d'icônes pixel (pause, inventaire, lore, quêtes, carte).
extension HUDOverlay {
    // MARK: - Private

    func setButton(_ node: SKShapeNode, size: CGFloat) {
        let rect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        node.path = CGPath(rect: rect, transform: nil)
    }

    func setupPauseButton() {
        let icon = SKNode()
        for x in [-5.0, 5.0] {
            let bar = SKShapeNode(rectOf: CGSize(width: 4, height: 18))
            bar.fillColor = SKColor(red: 0.92, green: 0.86, blue: 1, alpha: 1)
            bar.strokeColor = .clear
            bar.position = CGPoint(x: x, y: 0)
            icon.addChild(bar)
        }
        finishIconButton(pauseButton, icon: icon)
    }

    func setupInventoryButton() {
        let icon = SKNode()
        let pack = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
        pack.fillColor = SKColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 1)
        pack.strokeColor = SKColor(red: 0.90, green: 0.72, blue: 0.38, alpha: 0.9)
        pack.lineWidth = 1.4
        pack.glowWidth = 0
        icon.addChild(pack)

        let flap = SKShapeNode(rectOf: CGSize(width: 14, height: 5))
        flap.fillColor = SKColor(red: 0.25, green: 0.16, blue: 0.08, alpha: 1)
        flap.strokeColor = .clear
        flap.position = CGPoint(x: 0, y: 3)
        icon.addChild(flap)

        // Anse carrée (pas d'ellipse en pixel art)
        let handle = SKShapeNode(rectOf: CGSize(width: 12, height: 6))
        handle.fillColor = .clear
        handle.strokeColor = SKColor(red: 0.90, green: 0.72, blue: 0.38, alpha: 0.85)
        handle.lineWidth = 1.3
        handle.glowWidth = 0
        handle.position = CGPoint(x: 0, y: 12)
        icon.addChild(handle)

        finishIconButton(inventoryButton, icon: icon)
    }

    func setupLoreButton() {
        // Icône livre : couverture + tranche + ligne de reliure
        let icon = SKNode()
        let cover = SKShapeNode(rectOf: CGSize(width: 20, height: 22))
        cover.fillColor = SKColor(red: 0.16, green: 0.20, blue: 0.34, alpha: 1)
        cover.strokeColor = SKColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 0.9)
        cover.lineWidth = 1.4
        cover.glowWidth = 0
        icon.addChild(cover)

        let spine = SKShapeNode(rectOf: CGSize(width: 3, height: 22))
        spine.fillColor = SKColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 0.9)
        spine.strokeColor = .clear
        spine.position = CGPoint(x: -8.5, y: 0)
        icon.addChild(spine)

        for dy in [-4.0, 0.0, 4.0] {
            let line = SKShapeNode(rectOf: CGSize(width: 11, height: 1.4))
            line.fillColor = SKColor(red: 0.70, green: 0.82, blue: 1.0, alpha: 0.65)
            line.strokeColor = .clear
            line.position = CGPoint(x: 1, y: dy)
            icon.addChild(line)
        }
        finishIconButton(loreButton, icon: icon)
    }

    func setupQuestLogButton() {
        // Icône parchemin : rouleau doré + lignes de texte
        let icon = SKNode()
        let scroll = SKShapeNode(rectOf: CGSize(width: 18, height: 22))
        scroll.fillColor = SKColor(red: 0.28, green: 0.22, blue: 0.12, alpha: 1)
        scroll.strokeColor = PixelUI.gold.withAlphaComponent(0.9)
        scroll.lineWidth = 1.4
        scroll.glowWidth = 0
        icon.addChild(scroll)

        for dy in [4.0, 0.0, -4.0] {
            let line = SKShapeNode(rectOf: CGSize(width: 11, height: 1.4))
            line.fillColor = PixelUI.gold.withAlphaComponent(0.7)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: dy)
            icon.addChild(line)
        }
        // Rouleaux haut/bas
        for dy in [11.0, -11.0] {
            let roll = SKShapeNode(rectOf: CGSize(width: 20, height: 3))
            roll.fillColor = PixelUI.gold
            roll.strokeColor = .clear
            roll.position = CGPoint(x: 0, y: dy)
            icon.addChild(roll)
        }
        finishIconButton(questLogButton, icon: icon)
    }

    func setupMapButton() {
        // Icône carte du monde : parchemin déplié + plis + croix du trésor
        let icon = SKNode()
        let sheet = SKShapeNode(rectOf: CGSize(width: 24, height: 18))
        sheet.fillColor = SKColor(red: 0.72, green: 0.58, blue: 0.34, alpha: 1)
        sheet.strokeColor = SKColor(red: 0.32, green: 0.24, blue: 0.12, alpha: 1)
        sheet.lineWidth = 1.4
        sheet.glowWidth = 0
        icon.addChild(sheet)

        for x in [-8.0, 8.0] {
            let fold = SKShapeNode(rectOf: CGSize(width: 1.4, height: 18))
            fold.fillColor = SKColor(red: 0.45, green: 0.35, blue: 0.18, alpha: 1)
            fold.strokeColor = .clear
            fold.position = CGPoint(x: x, y: 0)
            icon.addChild(fold)
        }
        // Trajet pointillé + destination
        for (i, p) in [CGPoint(x: -4, y: -4), CGPoint(x: 0, y: 0),
                       CGPoint(x: 3, y: 4)].enumerated() {
            let dot = SKShapeNode(rectOf: CGSize(width: 2, height: 2))
            dot.fillColor = SKColor(red: 0.30, green: 0.22, blue: 0.10, alpha: 1)
            dot.strokeColor = .clear
            dot.position = p
            dot.zPosition = CGFloat(i) * 0.01
            icon.addChild(dot)
        }
        let marker = SKShapeNode(rectOf: CGSize(width: 4, height: 4))
        marker.fillColor = SKColor(red: 0.80, green: 0.25, blue: 0.20, alpha: 1)
        marker.strokeColor = .clear
        marker.position = CGPoint(x: 6, y: 5)
        marker.zRotation = .pi / 4
        icon.addChild(marker)

        finishIconButton(mapButton, icon: icon)
    }

    /// Bouton « icône seule » : plus de plaque noire — la forme du bouton
    /// reste la zone tactile (44 pt, invisible), l'icône est agrandie et
    /// reçoit une ombre portée dure (même recette que les labels du HUD).
    func finishIconButton(_ button: SKShapeNode, icon: SKNode) {
        button.fillColor = .clear
        button.strokeColor = .clear
        button.lineWidth = 0

        icon.setScale(1.3)
        let shadow = darkSilhouette(of: icon)
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        button.addChild(shadow)
        button.addChild(icon)
        root.addChild(button)
    }

    /// Copie sombre de l'icône (ombre portée) : chaque forme garde sa
    /// géométrie mais passe en quasi-noir.
    func darkSilhouette(of node: SKNode) -> SKNode {
        guard let copy = node.copy() as? SKNode else { return SKNode() }
        paintDark(copy)
        return copy
    }

    func paintDark(_ node: SKNode) {
        let dark = SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 0.80)
        if let shape = node as? SKShapeNode {
            if shape.fillColor != .clear { shape.fillColor = dark }
            if shape.strokeColor != .clear { shape.strokeColor = dark }
        }
        for child in node.children { paintDark(child) }
    }
}
