import SpriteKit
import UIKit

// DialogueSystem — portraits : couleur d'accent, asset ou pixel-art dessiné en code, application.
extension DialogueSystem {
    /// Couleur d'accent dérivée du nom du speaker — stable pour un même speaker.
    private func portraitColor(for speaker: String) -> SKColor {
        // Couleurs fixes pour les speakers principaux ; fallback via hash sinon.
        let key = speaker.lowercased()
        if key.contains("kael") {
            return SKColor(red: 0.55, green: 0.20, blue: 0.85, alpha: 1)
        }
        if key.contains("lyra") {
            return SKColor(red: 0.25, green: 0.70, blue: 0.45, alpha: 1)
        }
        if key.contains("dorin") {
            return SKColor(red: 0.85, green: 0.62, blue: 0.25, alpha: 1)
        }
        if key.contains("bram") {
            return SKColor(red: 0.70, green: 0.45, blue: 0.25, alpha: 1)
        }
        if key.contains("mara") {
            return SKColor(red: 0.30, green: 0.75, blue: 0.40, alpha: 1)
        }
        if key.contains("garen") {
            return SKColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 1)
        }
        if key.contains("sage") || key.contains("archi") {
            return SKColor(red: 0.45, green: 0.30, blue: 0.85, alpha: 1)
        }
        if key.contains("voix") || key.contains("voice") {
            return SKColor(red: 0.20, green: 0.20, blue: 0.30, alpha: 1)
        }
        // Fallback hash → teinte stable
        let hash = abs(speaker.hashValue)
        let hue = CGFloat(hash % 360) / 360
        return SKColor(hue: hue, saturation: 0.55, brightness: 0.75, alpha: 1)
    }

    /// Asset de portrait pixel par locuteur (nil = pas de visage :
    /// voix, cristal, plaque… le panneau retombe en mode texte seul).
    private func portraitAsset(for speaker: String) -> String? {
        let key = speaker.lowercased()
        // Andy : les visages de Kael et d'Eran étaient inversés → on les
        // échange. Kael parle avec « portrait_eran », Eran avec l'icône (Kael).
        // Seuls les 4 compagnons principaux ont un visage en dialogue ;
        // Andy : les PNJ de base (marchands, gardes, sage, enfant…) restent
        // en texte seul, pas de portrait générique.
        let table: [(String, String)] = [
            ("kael", "portrait_eran"),
            ("lyra", "portrait_lyra"),
            ("dorin", "portrait_dorin"),
            ("eran", "portrait_kael_icon")
        ]
        for (needle, asset) in table where key.contains(needle) { return asset }
        return nil
    }

    // MARK: - Portraits dessinés en code (habitants d'Ossara)

    static private var codePortraitCache: [String: SKTexture] = [:]

    /// Portrait pixel dessiné en code pour un locuteur (marchand/caravanier du
    /// désert), sinon nil. Renvoie (id de cache, texture) pour l'anim de pop.
    private func codePortrait(for speaker: String) -> (String, SKTexture)? {
        let key = speaker.lowercased()
        // Désactivé : seuls les 4 compagnons principaux ont un visage.
        let deserty: [String] = []
        guard deserty.contains(where: key.contains) else { return nil }
        let id = "code:desertMerchant"
        if let t = Self.codePortraitCache[id] { return (id, t) }
        let t = Self.renderPortrait(Self.desertMerchantMap,
                                    palette: Self.desertMerchantPalette)
        Self.codePortraitCache[id] = t
        return (id, t)
    }

    static private func renderPortrait(_ map: [String],
                                       palette: [Character: SKColor]) -> SKTexture {
        let rows = map.count
        let cols = map.map(\.count).max() ?? 0
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            for (r, line) in map.enumerated() {
                for (c, ch) in line.enumerated() {
                    guard let color = palette[ch] else { continue }
                    color.setFill()
                    ctx.cgContext.fill(CGRect(x: c, y: r, width: 1, height: 1))
                }
            }
        }
        let tex = SKTexture(image: image); tex.filteringMode = .nearest
        return tex
    }

    static private let desertMerchantPalette: [Character: SKColor] = [
        "o": SKColor(red: 0.12, green: 0.10, blue: 0.10, alpha: 1),
        "T": SKColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 1),   // turban
        "t": SKColor(red: 0.70, green: 0.62, blue: 0.45, alpha: 1),
        "B": SKColor(red: 0.72, green: 0.36, blue: 0.26, alpha: 1),   // bandeau
        "S": SKColor(red: 0.82, green: 0.62, blue: 0.44, alpha: 1),   // peau
        "N": SKColor(red: 0.66, green: 0.48, blue: 0.34, alpha: 1),   // nez
        "E": SKColor(red: 0.14, green: 0.11, blue: 0.10, alpha: 1),   // œil
        "b": SKColor(red: 0.28, green: 0.20, blue: 0.14, alpha: 1),   // barbe
        "R": SKColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1)    // robe
    ]

    static private let desertMerchantMap = [
        ".....oooooo.....",
        "...oTTTTTTTTo...",
        "..oTTTTTTTTTTo..",
        "..oTttttttttTo..",
        "..oBBBBBBBBBBo..",
        "..oTSSSSSSSSTo..",
        "..oSSSSSSSSSSo..",
        "..oSSEESSEESSo..",
        "..oSSSSSSSSSSo..",
        "..oSSSSNNSSSSo..",
        "..oSbSSSSSSbSo..",
        "..oSbbSSSSbbSo..",
        "..oSbbbbbbbbSo..",
        "..obbbbbbbbbbo..",
        "...obbbbbbbbo...",
        "....obbbbbbo....",
        "..oRRRRRRRRRRo..",
        ".oRRRRRRRRRRRRo.",
        ".oRRRRRRRRRRRRo.",
        ".oRRRRRRRRRRRRo."
    ]

    /// Nom teinté à la couleur du locuteur + portrait pixel si disponible.
    func applyPortrait(for speaker: String) {
        let color = portraitColor(for: speaker)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        speakerLabel.fontColor = b < 0.6
            ? SKColor(hue: h, saturation: min(s, 0.6), brightness: 0.80, alpha: 1)
            : color

        // Portrait dessiné en code (habitants d'Ossara) — prime sur l'asset
        // générique portrait_villager.
        if let (id, tex) = codePortrait(for: speaker) {
            let changed = portraitSprite.userData?["asset"] as? String != id
            portraitSprite.texture = tex
            hasPortrait = true
            if changed {
                portraitSprite.userData = ["asset": id]
                portraitSprite.setScale(0.82)
                portraitSprite.run(.sequence([
                    .scale(to: 1.06, duration: 0.10),
                    .scale(to: 1.0, duration: 0.10)
                ]))
            }
            return
        }

        if let asset = portraitAsset(for: speaker), UIImage(named: asset) != nil {
            let changed = portraitSprite.userData?["asset"] as? String != asset
            let texture = SKTexture(imageNamed: asset)
            texture.filteringMode = .nearest
            portraitSprite.texture = texture
            hasPortrait = true
            if changed {
                portraitSprite.userData = ["asset": asset]
                // Pop du portrait quand le locuteur change
                portraitSprite.setScale(0.82)
                portraitSprite.run(.sequence([
                    .scale(to: 1.06, duration: 0.10),
                    .scale(to: 1.0, duration: 0.10)
                ]))
            }
        } else {
            hasPortrait = false
            portraitSprite.userData = nil
        }
    }

    /// Le dialogue est modal, mais le toucher direct marche aussi :
    /// tap sur un choix = sélection + validation, tap sur le panneau =
    /// avancer d'une réplique. Le joystick + A/B restent disponibles
    /// (contrôles classiques).
}
