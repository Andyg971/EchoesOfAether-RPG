import SpriteKit
import UIKit

// Habillage UI pixel art commun + parcours des sprites descendants.

/// Habillage UI pixel art commun (cadres RPG rétro : coins carrés,
/// double bordure, coins crantés dorés). Utilisé par les dialogues,
/// les boutons de combat, les bulles et les panneaux.
@MainActor
enum PixelUI {
    static let gold = SKColor(red: 0.86, green: 0.70, blue: 0.38, alpha: 1)
    static let goldDim = SKColor(red: 0.55, green: 0.44, blue: 0.24, alpha: 0.45)
    static let panelFill = SKColor(red: 0.075, green: 0.058, blue: 0.048, alpha: 0.97)

    /// Police pixel art (VT323, embarquée en DataAsset et enregistrée au
    /// lancement par `registerPixelFont`). Fallback Menlo si absente.
    static var uiFont: String {
        UIFont(name: "VT323-Regular", size: 10) != nil ? "VT323-Regular" : "Menlo-Bold"
    }

    /// Enregistre la police pixel du bundle (DataAsset "PixelFont") —
    /// aucun Info.plist requis. À appeler une fois au démarrage.
    static func registerPixelFont() {
        guard UIFont(name: "VT323-Regular", size: 10) == nil,
              let asset = NSDataAsset(name: "PixelFont"),
              let provider = CGDataProvider(data: asset.data as CFData),
              let font = CGFont(provider) else { return }
        CTFontManagerRegisterGraphicsFont(font, nil)
    }

    /// Applique le cadre pixel à un SKShapeNode existant (le path est
    /// remplacé par un rectangle net). Style SNES : liseré sombre
    /// extérieur + bordure accent — pas de coins crantés ni de double
    /// trait intérieur. Ré-applicable : nettoie ses anciennes
    /// décorations avant de les recréer.
    static func stylePanel(_ shape: SKShapeNode, size: CGSize,
                           fill: SKColor = panelFill,
                           accent: SKColor = gold) {
        shape.path = CGPath(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                         width: size.width, height: size.height),
                            transform: nil)
        shape.fillColor = fill
        shape.strokeColor = accent
        shape.lineWidth = 2
        shape.glowWidth = 0

        shape.childNode(withName: "pixelInner")?.removeFromParent()
        shape.childNode(withName: "pixelCorners")?.removeFromParent()
        shape.childNode(withName: "pixelOuter")?.removeFromParent()
        let outer = SKShapeNode(rect: CGRect(x: -size.width / 2 - 2,
                                             y: -size.height / 2 - 2,
                                             width: size.width + 4,
                                             height: size.height + 4))
        outer.name = "pixelOuter"
        outer.fillColor = .clear
        outer.strokeColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 0.9)
        outer.lineWidth = 2
        outer.zPosition = -0.1
        shape.addChild(outer)
    }

    /// Bouton pixel réutilisable : même cadre RPG rétro que `stylePanel`
    /// (double bordure sombre + accent) et un label centré. Remplace les
    /// usines `makeButton` que chaque écran (mort, pause, options,
    /// tutoriel) dupliquait avec un simple `SKShapeNode(rectOf:)` à liseré
    /// unique — look plat qui tranchait avec le reste de l'UI.
    @discardableResult
    static func makeButton(_ text: String, size: CGSize,
                           fill: SKColor, accent: SKColor,
                           fontSize: CGFloat, name: String? = nil) -> SKShapeNode {
        let btn = SKShapeNode()
        stylePanel(btn, size: size, fill: fill, accent: accent)
        btn.name = name

        let lbl = SKLabelNode(fontNamed: uiFont)
        lbl.text = text
        lbl.fontSize = fontSize
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }
}

extension SKNode {
    /// Parcourt récursivement les SKSpriteNode DESCENDANTS de ce node.
    /// ⚠️ Ne pas remplacer par `enumerateChildNodes(withName: "//*")` :
    /// le préfixe `//` cherche depuis la RACINE de la scène, pas depuis
    /// ce node — ça corrompait des sprites étrangers (ex. le Kael du
    /// monde recevait les textures d'attaque des ennemis).
    func forEachDescendantSprite(_ body: (SKSpriteNode) -> Void) {
        for child in children {
            if let sprite = child as? SKSpriteNode { body(sprite) }
            child.forEachDescendantSprite(body)
        }
    }
}
