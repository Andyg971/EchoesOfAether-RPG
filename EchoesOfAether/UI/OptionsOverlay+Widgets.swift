import SpriteKit

// OptionsOverlay — fabrique des lignes : volume, bascule, cycle, petits boutons, labels.
extension OptionsOverlay {
    enum VolumeKind { case sfx, music }

    func refreshVolumeDisplay(_ kind: VolumeKind) {
        switch kind {
        case .sfx:   sfxLabel?.text = volumeString(sfxVolume)
        case .music: musicLabel?.text = volumeString(musicVolume)
        }
    }

    private func volumeString(_ v: Float) -> String {
        let filled = Int((v * 4).rounded())
        let blocks = String(repeating: "█", count: filled) + String(repeating: "░", count: 4 - filled)
        return blocks
    }

    func makeVolumeRow(value: Float, at pos: CGPoint, kind: VolumeKind) -> SKNode {
        let container = SKNode()
        container.position = pos
        let downName = kind == .sfx ? "sfxDown" : "musicDown"
        let upName   = kind == .sfx ? "sfxUp" : "musicUp"

        let downBtn = makeSmallButton("<", name: downName)
        downBtn.position = CGPoint(x: -70, y: 0)
        container.addChild(downBtn)

        let upBtn = makeSmallButton(">", name: upName)
        upBtn.position = CGPoint(x: 70, y: 0)
        container.addChild(upBtn)

        let volLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        volLabel.text = volumeString(value)
        volLabel.fontSize = 23
        volLabel.fontColor = SKColor(red: 0.55, green: 0.80, blue: 0.55, alpha: 1)
        volLabel.horizontalAlignmentMode = .center
        volLabel.verticalAlignmentMode = .center
        container.addChild(volLabel)
        switch kind {
        case .sfx:   sfxLabel = volLabel
        case .music: musicLabel = volLabel
        }

        return container
    }

    private func makeSmallButton(_ text: String, name: String) -> SKShapeNode {
        // Carré pixel (pas de cercle : le rond casse le style rétro).
        let btn = SKShapeNode(rectOf: CGSize(width: 36, height: 36))
        btn.fillColor = Palette.panelNight
        btn.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.70, alpha: 0.8)
        btn.lineWidth = 2
        btn.glowWidth = 0
        btn.name = name
        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 20
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }



    /// Ligne « libellé … [ON/OFF] » tappable (toute la ligne est la zone).
    func makeToggleRow(_ text: String, isOn: Bool, name: String,
                               at pos: CGPoint, width: CGFloat) -> SKShapeNode {
        let row = SKShapeNode(rectOf: CGSize(width: width, height: 30))
        row.fillColor = SKColor(red: 0.09, green: 0.08, blue: 0.15, alpha: 1)
        row.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.60, alpha: 0.5)
        row.lineWidth = 1
        row.glowWidth = 0
        row.name = name
        row.position = pos

        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 15
        lbl.fontColor = SKColor(white: 0.85, alpha: 1)
        lbl.horizontalAlignmentMode = .left
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: -width / 2 + 12, y: 0)
        lbl.isUserInteractionEnabled = false
        row.addChild(lbl)

        // Badge ON/OFF carré (pas de pilule arrondie en pixel art).
        let pill = SKShapeNode(rectOf: CGSize(width: 46, height: 20))
        pill.glowWidth = 0
        pill.fillColor = isOn
            ? SKColor(red: 0.20, green: 0.55, blue: 0.32, alpha: 1)
            : SKColor(red: 0.20, green: 0.18, blue: 0.26, alpha: 1)
        pill.strokeColor = isOn
            ? SKColor(red: 0.40, green: 0.85, blue: 0.55, alpha: 1)
            : SKColor(red: 0.45, green: 0.40, blue: 0.55, alpha: 0.8)
        pill.lineWidth = 1.2
        pill.position = CGPoint(x: width / 2 - 33, y: 0)
        pill.isUserInteractionEnabled = false
        row.addChild(pill)

        let pillLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        pillLbl.text = isOn ? String(localized: "options.toggle.on")
                            : String(localized: "options.toggle.off")
        pillLbl.fontSize = 13
        pillLbl.fontColor = .white
        pillLbl.verticalAlignmentMode = .center
        pillLbl.horizontalAlignmentMode = .center
        pillLbl.position = pill.position
        pillLbl.isUserInteractionEnabled = false
        row.addChild(pillLbl)

        return row
    }

    /// Ligne « libellé … [valeur] » tappable, qui cycle entre plusieurs états.
    ///
    /// Même géométrie que `makeToggleRow` — c'est le même objet pour le joueur,
    /// avec trois positions au lieu de deux. Le badge est plus large : « Vétéran »
    /// ne tient pas dans les 46 pt d'un ON/OFF.
    func makeCycleRow(_ text: String, value: String, name: String,
                              at pos: CGPoint, width: CGFloat) -> SKShapeNode {
        let row = SKShapeNode(rectOf: CGSize(width: width, height: 30))
        row.fillColor = SKColor(red: 0.09, green: 0.08, blue: 0.15, alpha: 1)
        row.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.60, alpha: 0.5)
        row.lineWidth = 1
        row.glowWidth = 0
        row.name = name
        row.position = pos

        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = text
        lbl.fontSize = 15
        lbl.fontColor = SKColor(white: 0.85, alpha: 1)
        lbl.horizontalAlignmentMode = .left
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: -width / 2 + 12, y: 0)
        lbl.isUserInteractionEnabled = false
        row.addChild(lbl)

        // Badge carré (pas de pilule arrondie en pixel art), accent violet
        // comme le reste de l'écran d'options.
        let badge = SKShapeNode(rectOf: CGSize(width: 88, height: 20))
        badge.glowWidth = 0
        badge.fillColor = SKColor(red: 0.20, green: 0.16, blue: 0.34, alpha: 1)
        badge.strokeColor = SKColor(red: 0.62, green: 0.52, blue: 0.95, alpha: 1)
        badge.lineWidth = 1.2
        badge.position = CGPoint(x: width / 2 - 54, y: 0)
        badge.isUserInteractionEnabled = false
        row.addChild(badge)

        let badgeLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        badgeLbl.text = value
        badgeLbl.fontSize = 13
        badgeLbl.fontColor = .white
        badgeLbl.verticalAlignmentMode = .center
        badgeLbl.horizontalAlignmentMode = .center
        badgeLbl.position = badge.position
        badgeLbl.isUserInteractionEnabled = false
        row.addChild(badgeLbl)

        return row
    }

    func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: PixelUI.uiFont)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        return l
    }
}
