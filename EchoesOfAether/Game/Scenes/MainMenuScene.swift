import SpriteKit

final class MainMenuScene: SKScene {

    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var safeAreaLeft: CGFloat = 0
    var safeAreaRight: CGFloat = 0

    private var buttonsBuilt = false
    private weak var highlightedButton: SKShapeNode?
    /// Slot en attente de confirmation de suppression (nil = aucun).
    private var confirmDeleteSlot: Int?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.035, green: 0.030, blue: 0.055, alpha: 1)
        // Migration de l'ancienne sauvegarde unique vers le slot 1 (une fois).
        SaveManager.migrateLegacyIfNeeded()
        buildUI()

        // Auto-tap pour test E2E si lancé avec --auto-tap
        if CommandLine.arguments.contains("--auto-tap") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                NSLog("[E2E] Auto-tap newGame")
                SaveManager.delete(slot: 1)
                self?.transitionToGame(slot: 1, newGame: true)
            }
        }

        // Audit visuel : les args --combat/--boss/--zone-* sautent le menu
        // sur le slot 2 (scratch) sans toucher aux sauvegardes joueur.
        let debugZoneArgs = ["--combat-test", "--combat-multi", "--boss-test",
                             "--zone-forest", "--zone-shrine", "--zone-ruins",
                             "--zone-village", "--zone-threshold", "--zone-mines",
                             "--interior"]
        if CommandLine.arguments.contains(where: debugZoneArgs.contains) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                SaveManager.delete(slot: 2)
                self?.transitionToGame(slot: 2, newGame: true)
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard buttonsBuilt else { return }
        confirmDeleteSlot = nil
        removeAllChildren()
        buildUI()
    }

    // MARK: - Build

    private func buildUI() {
        buttonsBuilt = true
        let w = size.width
        let h = size.height
        let safeTop = max(safeAreaTop, 0)
        let safeBottom = max(safeAreaBottom, 0)
        let contentTop = h - safeTop - 32
        let contentBottom = safeBottom + 34

        buildRPGBackdrop(w: w, h: h)
        addChild(ParticleFactory.ambientDust(in: size))

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = String(localized: "menu.title")
        titleLabel.fontSize = min(38, w * 0.095)
        titleLabel.fontColor = SKColor(red: 0.86, green: 0.78, blue: 1, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: w / 2, y: min(h - safeTop - h * 0.18, contentTop - 56))
        titleLabel.zPosition = 20
        addChild(titleLabel)
        JuiceEngine.float(titleLabel, distance: 4)

        let titleGlow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleGlow.text = titleLabel.text
        titleGlow.fontSize = titleLabel.fontSize
        titleGlow.fontColor = SKColor(red: 0.42, green: 0.20, blue: 0.75, alpha: 0.32)
        titleGlow.horizontalAlignmentMode = .center
        titleGlow.position = CGPoint(x: titleLabel.position.x, y: titleLabel.position.y - 2)
        titleGlow.zPosition = 19
        addChild(titleGlow)

        let sub = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        sub.text = String(localized: "menu.subtitle")
        sub.fontSize = 13
        sub.fontColor = SKColor(red: 0.74, green: 0.70, blue: 0.82, alpha: 0.78)
        sub.horizontalAlignmentMode = .center
        sub.verticalAlignmentMode = .center
        sub.preferredMaxLayoutWidth = min(w - 48, 360)
        sub.numberOfLines = 2
        sub.position = CGPoint(x: w / 2, y: titleLabel.position.y - 40)
        sub.zPosition = 20
        addChild(sub)

        // En-tête « Choisis un emplacement »
        let slotsTitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        slotsTitle.text = String(localized: "menu.chooseSlot")
        slotsTitle.fontSize = 13
        slotsTitle.fontColor = SKColor(white: 0.62, alpha: 1)
        slotsTitle.horizontalAlignmentMode = .center
        slotsTitle.verticalAlignmentMode = .center
        slotsTitle.zPosition = 20

        // Empilement vertical des slots, centré dans la zone disponible.
        let rowHeight: CGFloat = 66
        let spacing: CGFloat = 16
        let count = SaveManager.slotCount
        let blockHeight = CGFloat(count) * rowHeight + CGFloat(count - 1) * spacing
        let centerY = max(contentBottom + blockHeight / 2 + 40, h * 0.42)
        let topRowY = centerY + blockHeight / 2 - rowHeight / 2

        slotsTitle.position = CGPoint(x: w / 2, y: centerY + blockHeight / 2 + 26)
        addChild(slotsTitle)

        for i in 0..<count {
            let slot = i + 1
            let rowY = topRowY - CGFloat(i) * (rowHeight + spacing)
            let row = makeSlotRow(slot: slot, height: rowHeight)
            row.position = CGPoint(x: w / 2, y: rowY)
            row.zPosition = 20
            addChild(row)
            JuiceEngine.popIn(row, delay: 0.1 + Double(i) * 0.08)
        }

        let version = SKLabelNode(fontNamed: "AvenirNext-Regular")
        version.text = String(localized: "menu.version")
        version.fontSize = 10
        version.fontColor = SKColor(white: 0.46, alpha: 0.9)
        version.horizontalAlignmentMode = .center
        version.verticalAlignmentMode = .center
        version.position = CGPoint(x: w / 2, y: contentBottom)
        version.zPosition = 20
        addChild(version)
    }

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
        if SaveManager.hasSave(slot: slot) {
            transitionToGame(slot: slot, newGame: false)
        } else {
            transitionToGame(slot: slot, newGame: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearHighlight()
    }

    private func handleDeleteTap(slot: Int) {
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

    private func resetDeleteConfirmIfNeeded() {
        guard confirmDeleteSlot != nil else { return }
        confirmDeleteSlot = nil
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()
        buildUI()
    }

    // MARK: - Transition

    private func transitionToGame(slot: Int, newGame: Bool) {
        guard let view = self.view else { return }
        if newGame {
            // Nouvelle partie dans ce slot : on efface toute sauvegarde résiduelle.
            SaveManager.delete(slot: slot)
        }

        let gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.safeAreaTop = safeAreaTop
        gameScene.safeAreaBottom = safeAreaBottom
        gameScene.safeAreaLeft = safeAreaLeft
        gameScene.safeAreaRight = safeAreaRight
        gameScene.activeSlot = slot
        view.presentScene(gameScene, transition: .fade(with: .black, duration: 0.5))
    }

    // MARK: - Slot row

    private func makeSlotRow(slot: Int, height: CGFloat) -> SKShapeNode {
        let width = min(max(size.width - 56, 268), 360)
        let hasSave = SaveManager.hasSave(slot: slot)

        let row = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 14)
        row.fillColor = hasSave
            ? SKColor(red: 0.07, green: 0.12, blue: 0.18, alpha: 0.94)
            : SKColor(red: 0.13, green: 0.09, blue: 0.20, alpha: 0.92)
        row.strokeColor = hasSave
            ? SKColor(red: 0.38, green: 0.68, blue: 0.95, alpha: 0.9)
            : SKColor(red: 0.62, green: 0.46, blue: 0.92, alpha: 0.85)
        row.lineWidth = 2
        row.glowWidth = 1.2
        row.name = "slotRow\(slot)"
        row.userData = ["slot": slot]

        let leftX = -width / 2 + 18

        let titleL = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        titleL.text = String(localized: "menu.slot \(slot)")
        titleL.fontSize = 17
        titleL.fontColor = .white
        titleL.horizontalAlignmentMode = .left
        titleL.verticalAlignmentMode = .center
        titleL.position = CGPoint(x: leftX, y: hasSave ? 11 : 0)
        titleL.isUserInteractionEnabled = false
        row.addChild(titleL)

        let subL = SKLabelNode(fontNamed: "AvenirNext-Regular")
        if hasSave, let meta = SaveManager.metadata(slot: slot) {
            subL.text = String(localized: "menu.slot.meta \(phaseDisplayName(meta.phase)) \(meta.level) \(meta.gold)")
            subL.fontColor = SKColor(red: 0.70, green: 0.80, blue: 0.92, alpha: 0.95)
        } else {
            subL.text = String(localized: "menu.newGame")
            subL.fontColor = SKColor(red: 0.80, green: 0.72, blue: 0.95, alpha: 0.9)
        }
        subL.fontSize = 11
        subL.horizontalAlignmentMode = .left
        subL.verticalAlignmentMode = .center
        subL.position = CGPoint(x: leftX, y: -12)
        subL.isUserInteractionEnabled = false
        if hasSave { row.addChild(subL) } else {
            subL.position = CGPoint(x: leftX, y: 0)
            row.addChild(subL)
        }

        // Bouton suppression (uniquement si une sauvegarde existe)
        if hasSave {
            let confirming = confirmDeleteSlot == slot
            let delBtn = SKShapeNode(circleOfRadius: 16)
            delBtn.fillColor = confirming
                ? SKColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
                : SKColor(red: 0.16, green: 0.08, blue: 0.10, alpha: 1)
            delBtn.strokeColor = confirming
                ? SKColor(red: 1.0, green: 0.30, blue: 0.25, alpha: 1)
                : SKColor(red: 0.65, green: 0.25, blue: 0.25, alpha: 0.9)
            delBtn.lineWidth = 1.5
            delBtn.name = "slotDelete\(slot)"
            delBtn.userData = ["slot": slot]
            delBtn.position = CGPoint(x: width / 2 - 26, y: 0)

            let delLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            delLbl.text = confirming ? "?" : "✕"
            delLbl.fontSize = confirming ? 16 : 14
            delLbl.fontColor = .white
            delLbl.verticalAlignmentMode = .center
            delLbl.horizontalAlignmentMode = .center
            delLbl.isUserInteractionEnabled = false
            delBtn.addChild(delLbl)
            row.addChild(delBtn)

            if confirming {
                let hint = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
                hint.text = String(localized: "menu.slot.deleteConfirm")
                hint.fontSize = 9
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
    private func phaseDisplayName(_ phase: GamePhase) -> String {
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
        }
    }

    // MARK: - Helpers

    private func buildRPGBackdrop(w: CGFloat, h: CGFloat) {
        let sky = SKShapeNode(rectOf: CGSize(width: w, height: h))
        sky.fillColor = SKColor(red: 0.035, green: 0.030, blue: 0.055, alpha: 1)
        sky.strokeColor = .clear
        sky.position = CGPoint(x: w / 2, y: h / 2)
        sky.zPosition = -20
        addChild(sky)

        let moon = SKShapeNode(circleOfRadius: min(w, h) * 0.105)
        moon.fillColor = SKColor(red: 0.62, green: 0.58, blue: 0.78, alpha: 0.20)
        moon.strokeColor = SKColor(red: 0.82, green: 0.75, blue: 1, alpha: 0.16)
        moon.glowWidth = 12
        moon.position = CGPoint(x: w * 0.74, y: h * 0.80)
        moon.zPosition = -18
        addChild(moon)
        JuiceEngine.pulse(moon, scale: 1.04)

        // La chapelle de la Source sous la lune, gardée par les anges —
        // le lieu où tout se joue, en vitrine dès le titre.
        addBackdropSprite("gy_chapel", at: CGPoint(x: w * 0.50, y: h * 0.34), scale: 0.62, alpha: 0.80, z: -12)
        addBackdropSprite("me_statue_angel", at: CGPoint(x: w * 0.33, y: h * 0.30), scale: 0.22, alpha: 0.66, z: -11)
        addBackdropSprite("me_statue_angel", at: CGPoint(x: w * 0.67, y: h * 0.30), scale: 0.22, alpha: 0.66, z: -11)
        addBackdropSprite("gy_tree", at: CGPoint(x: w * 0.10, y: h * 0.26), scale: 0.60, alpha: 0.75, z: -8)
        addBackdropSprite("gy_tree", at: CGPoint(x: w * 0.90, y: h * 0.24), scale: 0.64, alpha: 0.78, z: -8)
        addBackdropSprite("gy_candle", at: CGPoint(x: w * 0.24, y: h * 0.22), scale: 0.50, alpha: 0.85, z: -6)
        addBackdropSprite("gy_candle", at: CGPoint(x: w * 0.76, y: h * 0.22), scale: 0.50, alpha: 0.85, z: -6)

        let ground = SKShapeNode(rectOf: CGSize(width: w * 1.20, height: h * 0.36), cornerRadius: 0)
        ground.fillColor = SKColor(red: 0.025, green: 0.040, blue: 0.030, alpha: 0.92)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: w / 2, y: h * 0.13)
        ground.zPosition = -6
        addChild(ground)

        let aether = SKShapeNode(ellipseOf: CGSize(width: w * 0.72, height: 34))
        aether.fillColor = SKColor(red: 0.25, green: 0.10, blue: 0.44, alpha: 0.12)
        aether.strokeColor = SKColor(red: 0.68, green: 0.42, blue: 1, alpha: 0.20)
        aether.glowWidth = 8
        aether.position = CGPoint(x: w / 2, y: h * 0.24)
        aether.zPosition = -4
        addChild(aether)
        JuiceEngine.pulse(aether, scale: 1.08)
    }

    private func addBackdropSprite(_ name: String, at position: CGPoint,
                                   scale: CGFloat, alpha: CGFloat, z: CGFloat) {
        guard let sprite = PixelArtSprites.still(name: name, scale: scale,
                                                  anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        sprite.position = position
        sprite.alpha = alpha
        sprite.zPosition = z
        addChild(sprite)
    }

    /// Renvoie la ligne de slot touchée (en remontant au parent si besoin).
    private func slotRow(at point: CGPoint) -> SKShapeNode? {
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
    private func deleteSlot(at point: CGPoint) -> Int? {
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

    private func clearHighlight() {
        highlightedButton?.run(.scale(to: 1.0, duration: 0.08))
        highlightedButton = nil
    }
}
