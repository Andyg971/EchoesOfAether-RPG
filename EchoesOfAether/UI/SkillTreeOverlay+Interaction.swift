import SpriteKit

// SkillTreeOverlay — taps, investissement, respec, curseur des contrôles classiques.
extension SkillTreeOverlay {
    // MARK: - Interaction

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, ready else { return isActive }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "skillClose") as? SKShapeNode,
           btn.contains(local) {
            AudioEngine.shared.playUIMove()
            dismiss()
            return true
        }
        if let btn = root.childNode(withName: "skillRespec") as? SKShapeNode,
           btn.contains(local) {
            handleRespecTap()
            return true
        }
        for node in SkillTree.allNodes {
            guard let cell = root.childNode(withName: "skillNode:\(node.id)") as? SKShapeNode,
                  cell.contains(local) else { continue }
            invest(node)
            return true
        }
        return true
    }

    /// Investit un rang, ou explique pourquoi c'est impossible.
    private func invest(_ node: SkillNode) {
        guard let player else { return }
        if let lock = player.skillLock(for: node) {
            setDetail(lock.message, color: SKColor(red: 0.90, green: 0.45, blue: 0.40, alpha: 1))
            AudioEngine.shared.playUIMove()
            HapticsEngine.error()
            AccessibilitySettings.announce(lock.message)
            return
        }
        player.unlockSkill(node)
        respecArmed = false
        rebuild()
        setDetail("\(node.title) — \(node.detail)", color: PixelUI.gold)
        AudioEngine.shared.playUIConfirm()
        HapticsEngine.light()
        AccessibilitySettings.announce(
            "\(node.title). \(node.detail). "
            + String(localized: "skill.points \(player.skillPointsAvailable)"))
    }

    /// Deux temps : le premier tap arme (destructif), le second exécute.
    private func handleRespecTap() {
        guard let player else { return }
        guard player.skillPointsSpent > 0 else {
            setDetail(String(localized: "skill.respec.empty"),
                      color: SKColor(white: 0.65, alpha: 1))
            HapticsEngine.error()
            return
        }
        if !respecArmed {
            respecArmed = true
            rebuild()
            let cost = SkillTree.respecCost(level: player.level)
            setDetail(String(localized: "skill.respec.warning \(cost)"),
                      color: SKColor(red: 0.95, green: 0.65, blue: 0.30, alpha: 1))
            AudioEngine.shared.playUIMove()
            HapticsEngine.light()
            return
        }
        respecArmed = false
        guard onRespec?() == true else {
            rebuild()
            setDetail(String(localized: "skill.respec.noGold"),
                      color: SKColor(red: 0.90, green: 0.45, blue: 0.40, alpha: 1))
            HapticsEngine.error()
            return
        }
        rebuild()
        setDetail(String(localized: "skill.respec.done"), color: PixelUI.gold)
        AudioEngine.shared.playUIConfirm()
        HapticsEngine.success()
        AccessibilitySettings.announce(String(localized: "skill.respec.done"))
    }

    func setDetail(_ text: String, color: SKColor) {
        guard let label = root.childNode(withName: "skillDetail") as? SKLabelNode else { return }
        label.text = text
        label.fontColor = color
    }

    // MARK: - Curseur (contrôles classiques)

    /// Joystick : dx change de voie, dy monte/descend dans la voie.
    func moveSelection(dx: Int, dy: Int) {
        guard isActive, ready else { return }
        let perColumn = 4
        var col = selection / perColumn, row = selection % perColumn
        col = (col + dx + SkillBranch.allCases.count) % SkillBranch.allCases.count
        row = (row - dy + perColumn) % perColumn
        selection = col * perColumn + row
        HapticsEngine.light()
        AudioEngine.shared.playUIMove()
        refreshSelectionHighlight()
        let node = SkillTree.allNodes[selection]
        setDetail("\(node.title) — \(node.detail)", color: SKColor(white: 0.80, alpha: 1))
        AccessibilitySettings.announce("\(node.title). \(node.detail)")
    }

    /// Bouton A : investit sur le nœud sous le curseur.
    func confirmSelection() {
        guard isActive, ready else { return }
        invest(SkillTree.allNodes[selection])
    }

    func refreshSelectionHighlight() {
        for (i, node) in SkillTree.allNodes.enumerated() {
            guard let cell = root.childNode(withName: "skillNode:\(node.id)") as? SKShapeNode
            else { continue }
            let selected = i == selection
            cell.lineWidth = selected ? 3 : 2
            cell.setScale(selected ? 1.03 : 1.0)
        }
    }
}
