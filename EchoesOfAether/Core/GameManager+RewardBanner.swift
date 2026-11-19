import SpriteKit

// Bandeau « objet obtenu » : bref, pixel art, en haut de l'écran.
@MainActor
extension GameManager {

    /// Bandeau doré qui s'efface seul (≈3 s). Un seul à la fois.
    func showRewardBanner(_ text: String, icon: PixelIcons.Kind) {
        guard let scene else { return }
        scene.childNode(withName: "rewardBanner")?.removeFromParent()

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 18
        label.fontColor = PixelUI.gold
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center

        let iconNode = PixelIcons.node(icon, pixel: 2)
        let width = label.frame.width + 64
        let banner = SKShapeNode()
        PixelUI.stylePanel(banner, size: CGSize(width: width, height: 40),
                           fill: Palette.nightBlack.withAlphaComponent(0.95),
                           accent: PixelUI.gold)
        banner.name = "rewardBanner"
        banner.zPosition = 1_900
        let top = lastLayout?.top ?? 0
        banner.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - top - 64)
        iconNode.position = CGPoint(x: -width / 2 + 22, y: 0)
        label.position = CGPoint(x: -width / 2 + 42, y: 0)
        banner.addChild(iconNode)
        banner.addChild(label)
        scene.addChild(banner)

        banner.alpha = 0
        banner.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 2.8),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
        AudioEngine.shared.playGoldGain()
        HapticsEngine.success()
        AccessibilitySettings.announce(text)
    }

    /// Eran reçoit des bâtons : on le dit, le joueur saura où les trouver.
    func announceStoryWeapons(_ granted: [Weapon]) {
        guard let first = granted.first else { return }
        let names = granted.map { String(localized: $0.nameKey) }
            .joined(separator: String(localized: "equipment.stat.separator"))
        showRewardBanner(String(localized: "equipment.reward.eran \(names)"),
                         icon: .weapon(first.style))
    }
}
