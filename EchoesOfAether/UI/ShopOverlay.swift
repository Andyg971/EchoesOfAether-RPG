import SpriteKit

struct ShopItem {
    let nameKey: LocalizedStringResource
    /// Ligne sous le nom (description localisée)…
    var descKey: LocalizedStringResource? = nil
    let price: Int
    /// Vignette pixel art affichée à gauche de la ligne (arme, potion…).
    var icon: PixelIcons.Kind = .bag
    /// …ou texte déjà composé (stats générées du catalogue), prioritaire.
    var detail: String? = nil
    let canBuy: (PlayerState) -> Bool
    let onBuy: (PlayerState) -> Void

    var descriptionText: String {
        if let detail { return detail }
        if let descKey { return String(localized: descKey) }
        return ""
    }
}

@MainActor
final class ShopOverlay {
    /// Panneau PAYSAGE : assez large pour une ligne de stats complète sous
    /// chaque article. L'ancien 260 pt laissait les descriptions déborder
    /// du cadre et la cinquième ligne passer sous le bouton Fermer.
    static let panelSize = CGSize(width: 520, height: 330)
    static let rowHeight: CGFloat = 46
    /// Haut de la liste sous le titre et l'or, et place réservée au bouton.
    static let listTopInset: CGFloat = 72
    static let listBottomInset: CGFloat = 58

    let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let goldLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let closeButton = SKShapeNode(rectOf: CGSize(width: 100, height: 32))
    var itemNodes: [SKNode] = []

    var items: [ShopItem] = []
    var selection = 0          // curseur (contrôles classiques)
    /// Premier article visible : la liste défile quand le curseur sort.
    var scrollOffset = 0
    var playerState: PlayerState?
    private var completion: (() -> Void)?

    var panelWidth: CGFloat = ShopOverlay.panelSize.width
    var panelHeight: CGFloat = ShopOverlay.panelSize.height

    var isActive: Bool { root.parent != nil && !root.isHidden }

    /// Nombre de lignes qui tiennent entre l'en-tête et le bouton Fermer.
    var visibleRowCount: Int {
        max(1, Int((panelHeight - Self.listTopInset - Self.listBottomInset) / Self.rowHeight))
    }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)

        root.addChild(panel)

        titleLabel.fontSize = 24
        titleLabel.fontColor = SKColor(red: 0.90, green: 0.75, blue: 0.35, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        goldLabel.fontSize = 16
        goldLabel.fontColor = SKColor(red: 0.90, green: 0.80, blue: 0.30, alpha: 1)
        goldLabel.horizontalAlignmentMode = .center
        root.addChild(goldLabel)

        setupCloseButton()
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        panelWidth = min(Self.panelSize.width, max(320, size.width - 160))
        panelHeight = Self.panelSize.height
        root.position = CGPoint(x: size.width / 2, y: (size.height + safeBottom) / 2)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: Palette.nightBlack.withAlphaComponent(0.97),
                           accent: Palette.goldDark)

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 30)
        goldLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 52)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 28)

        // Réduit le panneau s'il ne tient pas en hauteur, l'agrandit sur iPad.
        root.setScale(UIScale.fittingFactor(for: size, contentHeight: panelHeight + 12))
        if isActive { refresh() }
    }

    func open(title: String, items: [ShopItem], player: PlayerState, completion: @escaping () -> Void) {
        self.items = items
        self.playerState = player
        self.completion = completion
        titleLabel.text = title
        selection = 0
        scrollOffset = 0
        root.isHidden = false
        AudioEngine.shared.playShopOpen()
        refresh()
        AccessibilitySettings.announce(title)
        announceSelection()
    }

    /// Joystick haut/bas : déplace le curseur sur les articles.
    func moveSelection(_ dy: Int) {
        guard isActive, !items.isEmpty else { return }
        select((selection - dy + items.count) % items.count)
    }

    /// Bouton A : achète l'article sélectionné (si achetable).
    func confirmSelection() {
        guard isActive, items.indices.contains(selection),
              let player = playerState else { return }
        let item = items[selection]
        guard item.canBuy(player), player.gold >= item.price else {
            HapticsEngine.error()
            return
        }
        player.gold -= item.price
        item.onBuy(player)
        AudioEngine.shared.playPurchase()
        HapticsEngine.success()
        refresh()
        showPurchaseToast()
    }

    /// Toucher une ligne la sélectionne ; toucher la ligne déjà sélectionnée
    /// l'achète. Le bouton Fermer ferme. Le panneau absorbe tous les taps.
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)
        if closeButton.contains(local) {
            HapticsEngine.light()
            close()
            return true
        }
        for node in itemNodes {
            guard let row = node as? SKShapeNode, row.contains(local),
                  let index = row.userData?["index"] as? Int else { continue }
            if index == selection {
                confirmSelection()
            } else {
                select(index)
            }
            return true
        }
        return true
    }

    /// Bouton B : fermeture programmée (contrôles classiques).
    func dismiss() { close() }

    // MARK: - Private

    private func select(_ index: Int) {
        selection = index
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        if scrollToSelection() {
            refresh()
        } else {
            refreshSelectionHighlight()
        }
        announceSelection()
    }

    /// Fait défiler la liste pour garder le curseur visible. Vrai si la
    /// fenêtre a bougé (il faut alors reconstruire les lignes).
    @discardableResult
    func scrollToSelection() -> Bool {
        let previous = scrollOffset
        let visible = visibleRowCount
        if selection < scrollOffset { scrollOffset = selection }
        if selection >= scrollOffset + visible { scrollOffset = selection - visible + 1 }
        scrollOffset = min(max(0, scrollOffset), max(0, items.count - visible))
        return scrollOffset != previous
    }

    /// VoiceOver : annonce l'article sous le curseur (nom + prix).
    private func announceSelection() {
        guard items.indices.contains(selection) else { return }
        let item = items[selection]
        let name = String(localized: item.nameKey)
        let price = String(localized: "shop.price \(item.price)")
        AccessibilitySettings.announce("\(name). \(price)")
    }

    private func setupCloseButton() {
        PixelUI.stylePanel(closeButton, size: CGSize(width: 100, height: 32),
                           fill: SKColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 1),
                           accent: SKColor(red: 0.60, green: 0.45, blue: 0.20, alpha: 0.8))

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "shop.close")
        label.fontSize = 17
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        closeButton.addChild(label)
        root.addChild(closeButton)
    }

    func refresh() {
        guard let player = playerState else { return }
        goldLabel.text = String(localized: "shop.gold \(player.gold)")
        selection = min(selection, max(0, items.count - 1))
        scrollToSelection()
        buildItemList(player: player)
        refreshSelectionHighlight()
    }

    private func close() {
        root.isHidden = true
        // Vider AVANT d'appeler : si la completion rouvre un overlay qui
        // stocke sa propre completion, l'ordre inverse l'écraserait.
        let done = completion
        completion = nil
        done?()
    }
}
