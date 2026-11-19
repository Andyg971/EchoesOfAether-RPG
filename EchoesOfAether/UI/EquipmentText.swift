import SpriteKit

/// Textes et couleurs de l'équipement, générés depuis le catalogue : la
/// boutique et l'inventaire affichent toujours les vraies valeurs.
@MainActor
enum EquipmentText {

    /// « ATQ +17 · Entaille +26 · Crit. +5 % » — seulement les bonus non nuls.
    static func summary(_ bonus: EquipmentBonus) -> String {
        var parts: [String] = []
        if bonus.attack != 0 { parts.append(String(localized: "equipment.stat.attack \(bonus.attack)")) }
        if bonus.slash != 0 { parts.append(String(localized: "equipment.stat.slash \(bonus.slash)")) }
        let crit = percent(bonus.crit)
        if crit != 0 { parts.append(String(localized: "equipment.stat.crit \(crit)")) }
        let dodge = percent(bonus.dodge)
        if dodge > 0 { parts.append(String(localized: "equipment.stat.dodgeUp \(dodge)")) }
        if dodge < 0 { parts.append(String(localized: "equipment.stat.dodgeDown \(-dodge)")) }
        if bonus.mpRegen != 0 { parts.append(String(localized: "equipment.stat.mpRegen \(bonus.mpRegen)")) }
        return parts.joined(separator: String(localized: "equipment.stat.separator"))
    }

    /// « Rapide · ATQ +17 · … » : style puis bonus (ligne de boutique).
    static func weaponLine(_ weapon: Weapon) -> String {
        String(localized: weapon.style.nameKey)
            + String(localized: "equipment.stat.separator")
            + summary(weapon.bonus)
    }

    static func armorSummary(maxHP: Int) -> String {
        String(localized: "equipment.stat.maxHP \(maxHP)")
    }

    /// Une entrée de comparaison par stat qui change entre deux tenues.
    /// `trend` : +1 meilleur, -1 moins bon.
    static func comparisons(from old: EquipmentPreview,
                            to new: EquipmentPreview) -> [(text: String, trend: Int)] {
        var out: [(String, Int)] = []
        func add(_ before: Int, _ after: Int, _ text: String) {
            guard before != after else { return }
            out.append((text, after > before ? 1 : -1))
        }
        add(old.attack, new.attack,
            String(localized: "equipment.compare.attack \(old.attack) \(new.attack)"))
        add(old.slash, new.slash,
            String(localized: "equipment.compare.slash \(old.slash) \(new.slash)"))
        add(old.critPercent, new.critPercent,
            String(localized: "equipment.compare.crit \(old.critPercent) \(new.critPercent)"))
        add(old.dodgePercent, new.dodgePercent,
            String(localized: "equipment.compare.dodge \(old.dodgePercent) \(new.dodgePercent)"))
        add(old.mpRegen, new.mpRegen,
            String(localized: "equipment.compare.mpRegen \(old.mpRegen) \(new.mpRegen)"))
        return out
    }

    /// Couleur d'accent du style (étiquette de la ligne).
    static func color(for style: WeaponStyle) -> SKColor {
        switch style {
        case .blade:      SKColor(red: 0.82, green: 0.85, blue: 0.92, alpha: 1)
        case .rapier:     Palette.iceBlue
        case .greatsword: SKColor(red: 0.98, green: 0.55, blue: 0.20, alpha: 1)
        case .echo:       SKColor(red: 0.74, green: 0.58, blue: 1.00, alpha: 1)
        }
    }

    static let gain = SKColor(red: 0.55, green: 0.92, blue: 0.58, alpha: 1)
    static let loss = SKColor(red: 0.95, green: 0.45, blue: 0.40, alpha: 1)

    private static func percent(_ value: Double) -> Int {
        Int((value * 100).rounded())
    }
}
