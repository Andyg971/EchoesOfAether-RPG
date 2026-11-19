import SpriteKit

/// Ligne de l'inventaire sur laquelle A (ou un toucher) agit.
enum InventoryAction: String {
    case weapon, accessory, potion

    /// Indice affiché en pied de panneau quand le curseur est sur la ligne.
    var hintKey: LocalizedStringResource {
        switch self {
        case .weapon:    "inventory.hint.weapon"
        case .accessory: "inventory.hint.accessory"
        case .potion:    "inventory.potionHint"
        }
    }

    /// Nom de la zone de toucher (la potion garde son ancien nom).
    var hitName: String { self == .potion ? "potionUse" : "action.\(rawValue)" }
    var frameName: String { "actionFrame.\(rawValue)" }
}

// InventoryOverlay — lignes actionnables, curseur (joystick / manette), A, B.
extension InventoryOverlay {

    /// Le bouton A a-t-il quelque chose à faire ?
    var canConfirm: Bool { isActive && (picker.isOpen || cursor != nil) }

    /// Une ligne n'est actionnable que si elle offre quelque chose : deux
    /// armes au moins dans le groupe (poings de Kael, bâtons de Lyra et
    /// d'Eran), deux accessoires au moins, une potion buvable.
    func installActions(player: PlayerState, rowY: [InventoryAction: CGFloat]) {
        actions = []
        if player.hasWeaponChoice { actions.append(.weapon) }
        if player.ownedAccessoryList.count >= 2 { actions.append(.accessory) }
        if potionUsable { actions.append(.potion) }

        for action in actions {
            guard let y = rowY[action] else { continue }
            addActionZone(action, rowY: y)
        }
        if let current = cursor, actions.contains(current) {
            cursor = current
        } else {
            cursor = actions.first
        }

        if !actions.isEmpty {
            let hint = SKLabelNode(fontNamed: PixelUI.uiFont)
            hint.name = "actionHint"
            hint.fontSize = 15
            hint.fontColor = PixelUI.gold
            hint.horizontalAlignmentMode = .center
            hint.verticalAlignmentMode = .center
            hint.position = CGPoint(x: 0, y: -panelHeight / 2 + 70)
            root.addChild(hint)
            statLabels.append(hint)
        }
        refreshCursor()
    }

    /// Zone de toucher + léger surlignage doré de la ligne.
    private func addActionZone(_ action: InventoryAction, rowY: CGFloat) {
        let size = CGSize(width: largeurColonne - 32, height: lineH)
        let hit = SKShapeNode(rectOf: size)
        hit.fillColor = .clear
        hit.strokeColor = .clear
        hit.name = action.hitName
        hit.position = CGPoint(x: centreColonne, y: rowY - 2)
        root.addChild(hit)
        statLabels.append(hit)

        let frame = SKShapeNode(rectOf: CGSize(width: size.width - 4, height: size.height))
        frame.name = action.frameName
        frame.fillColor = PixelUI.gold.withAlphaComponent(0.10)
        frame.glowWidth = 0
        frame.position = hit.position
        // Au-dessus du fond du panneau (z 0) : à -0,5 le cadre passait
        // dessous et restait invisible.
        frame.zPosition = 0.2
        root.addChild(frame)
        statLabels.append(frame)
    }

    /// Cadre doré plein sur la ligne du curseur, liseré discret sur les
    /// autres ; l'indice du bas dit ce que fera A.
    func refreshCursor() {
        for action in actions {
            guard let frame = root.childNode(withName: action.frameName) as? SKShapeNode else { continue }
            let selected = action == cursor
            frame.strokeColor = selected ? PixelUI.gold : PixelUI.goldDim
            frame.lineWidth = selected ? 2 : 1
        }
        if let hint = root.childNode(withName: "actionHint") as? SKLabelNode {
            hint.text = cursor.map { String(localized: $0.hintKey) }
            hint.isHidden = picker.isOpen
        }
    }

    func action(at local: CGPoint) -> InventoryAction? {
        actions.first { action in
            (root.childNode(withName: action.hitName) as? SKShapeNode)?.contains(local) == true
        }
    }

    // MARK: - Curseur

    /// Joystick : haut/bas parcourt les lignes actionnables (ou le
    /// sélecteur) ; gauche/droite change de héros dans le sélecteur.
    func moveSelection(dx: Int = 0, dy: Int) {
        guard isActive else { return }
        if picker.isOpen {
            if dx != 0 { picker.switchHero(dx) } else { picker.moveSelection(dy) }
            return
        }
        guard dy != 0 else { return }
        guard !actions.isEmpty else { return }
        let index = cursor.flatMap { actions.firstIndex(of: $0) } ?? 0
        cursor = actions[(index - dy + actions.count) % actions.count]
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshCursor()
        if let cursor { AccessibilitySettings.announce(String(localized: cursor.hintKey)) }
    }

    /// Bouton A : agit sur la ligne du curseur (ou équipe dans le sélecteur).
    func confirmSelection() {
        guard isActive else { return }
        if picker.isOpen {
            picker.confirmSelection()
        } else if let cursor {
            perform(cursor)
        }
    }

    func perform(_ action: InventoryAction) {
        guard let player = playerState else { return }
        switch action {
        case .potion:
            useSelectedPotion()
        case .weapon:
            HapticsEngine.light()
            picker.open(.weapons, player: player)
        case .accessory:
            HapticsEngine.light()
            picker.open(.accessories, player: player)
        }
        refreshCursor()
    }

    /// Bouton A / toucher la ligne : boit une potion. Un échec (PV redevenus
    /// pleins entre-temps) reste silencieux.
    func useSelectedPotion() {
        guard potionUsable, onUsePotion?() == true else { return }
        HapticsEngine.success()
        showToast(String(localized: "inventory.healed"))
        rebuild()
    }
}
