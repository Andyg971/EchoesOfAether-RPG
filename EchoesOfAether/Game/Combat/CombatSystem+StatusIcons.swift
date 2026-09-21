import SpriteKit

// Arène — pictos de statut au-dessus des ennemis : flamme, éclair, bouclier fêlé.
extension CombatSystem {
    /// Pictos de statut persistants au-dessus d'un ennemi : brûlure
    /// (flamme), gel/paralysie (éclair), garde brisée (bouclier fêlé).
    /// Reconstruits à chaque updateVisuals — 3 pictos max, coût nul.
    func refreshStatusIcons(for e: EnemyState) {
        e.statusIcons.removeAllChildren()
        guard e.combatant.isAlive else { return }

        var icons: [SKNode] = []
        if let status = e.combatant.statusEffect {
            let palette: [SKColor] = status == .aetherBurn
                ? [SKColor(red: 1.00, green: 0.58, blue: 0.16, alpha: 1),
                   SKColor(red: 0.88, green: 0.24, blue: 0.06, alpha: 1)]
                : [SKColor(red: 0.45, green: 0.90, blue: 0.40, alpha: 1),
                   SKColor(red: 0.20, green: 0.60, blue: 0.25, alpha: 1)]
            icons.append(Self.makeFlameIcon(palette: palette,
                                            ticks: e.combatant.statusTicks))
        }
        if e.combatant.stunned {
            icons.append(Self.makeBoltIcon())
        }
        if e.brokenTurns > 0 {
            icons.append(Self.makeBrokenShieldIcon())
        }
        guard !icons.isEmpty else { return }

        let spacing: CGFloat = 16
        let x0 = -spacing * CGFloat(icons.count - 1) / 2
        for (i, icon) in icons.enumerated() {
            icon.position = CGPoint(x: x0 + CGFloat(i) * spacing, y: 0)
            e.statusIcons.addChild(icon)
            JuiceEngine.pulse(icon, scale: 1.12)
        }
    }

    /// Flamme pixel (3 carrés étagés) + pips de tours restants.
    static func makeFlameIcon(palette: [SKColor], ticks: Int) -> SKNode {
        let icon = SKNode()
        let base = SKSpriteNode(color: palette[1], size: CGSize(width: 8, height: 6))
        icon.addChild(base)
        let mid = SKSpriteNode(color: palette[0], size: CGSize(width: 6, height: 5))
        mid.position = CGPoint(x: 0, y: 5)
        icon.addChild(mid)
        let tip = SKSpriteNode(color: palette[0], size: CGSize(width: 3, height: 4))
        tip.position = CGPoint(x: 1, y: 9)
        icon.addChild(tip)
        // Pips : tours de statut restants (1 pixel par tick)
        for t in 0..<min(ticks, 3) {
            let pip = SKSpriteNode(color: .white, size: CGSize(width: 2, height: 2))
            pip.position = CGPoint(x: CGFloat(t) * 3 - 3, y: -6)
            icon.addChild(pip)
        }
        return icon
    }

    /// Éclair pixel jaune : gel / paralysie (tour sauté).
    static func makeBoltIcon() -> SKNode {
        let icon = SKNode()
        let yellow = SKColor(red: 1.00, green: 0.88, blue: 0.30, alpha: 1)
        for (dx, dy, w, h) in [(1.5, 6.0, 5.0, 4.0), (-0.5, 2.0, 5.0, 4.0),
                               (1.0, -2.0, 5.0, 4.0), (-1.5, -6.0, 4.0, 4.0)] {
            let seg = SKSpriteNode(color: yellow, size: CGSize(width: w, height: h))
            seg.position = CGPoint(x: dx, y: dy)
            icon.addChild(seg)
        }
        return icon
    }

    /// Bouclier fêlé doré : garde brisée (BREAK).
    static func makeBrokenShieldIcon() -> SKNode {
        let icon = SKNode()
        let gold = Palette.goldCombatBright
        let dark = SKColor(red: 0.35, green: 0.25, blue: 0.05, alpha: 1)
        let body = SKSpriteNode(color: gold, size: CGSize(width: 10, height: 10))
        icon.addChild(body)
        let point = SKSpriteNode(color: gold, size: CGSize(width: 6, height: 3))
        point.position = CGPoint(x: 0, y: -6)
        icon.addChild(point)
        // Fissure : marches sombres en diagonale
        for (dx, dy) in [(-2.0, 3.0), (0.0, 0.0), (2.0, -3.0)] {
            let crack = SKSpriteNode(color: dark, size: CGSize(width: 2, height: 4))
            crack.position = CGPoint(x: dx, y: dy)
            icon.addChild(crack)
        }
        return icon
    }
}
