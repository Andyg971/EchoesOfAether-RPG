import SpriteKit

/// Palette du jeu.
///
/// ## Pourquoi ce fichier existe
///
/// Un audit des couleurs a compté **650 valeurs RGBA distinctes pour 753
/// usages** — autrement dit, presque chaque couleur du jeu n'est employée
/// qu'une fois. En pixel art, c'est exactement l'inverse de ce qu'on cherche :
/// c'est la palette restreinte qui fait qu'un jeu ressemble à un monde plutôt
/// qu'à un assemblage de zones peintes séparément.
///
/// Le regroupement par proximité montre que ces 650 valeurs ne sont pas
/// 650 intentions. Huit grappes concentrent 279 usages :
///
/// | Couleur voulue | Usages | Variantes distinctes |
/// |----------------|--------|----------------------|
/// | violet nuit (panneaux)  | 88 | 77 |
/// | brun bois               | 47 | 40 |
/// | or                      | 41 | 21 |
/// | noir chaud              | 32 | 30 |
/// | or sombre               | 20 | 16 |
/// | bleu clair              | 19 | 13 |
/// | bleu                    | 18 | 10 |
/// | violet saturé           | 14 | 10 |
///
/// Ce ne sont pas des choix : c'est une même couleur retapée de mémoire à
/// chaque nouveau fichier.
///
/// ## Ce que ce fichier fait — et ne fait pas
///
/// Il **nomme** les valeurs déjà dominantes et migre vers elles les littéraux
/// répétés à l'identique. Aucune valeur n'a été modifiée : la migration est un
/// refactor à zéro changement visuel.
///
/// Il ne **converge** pas les variantes proches — fusionner les quatre ors en
/// un seul est une décision de direction artistique, pas de refactoring, et
/// elle appartient à l'auteur du jeu. Ce fichier la rend triviale : une fois
/// les appels passés par un jeton, changer la couleur partout est une ligne.
/// Voir `PALETTE.md` pour l'inventaire complet des grappes.
enum Palette {

    // MARK: - Fonds et panneaux

    /// Violet nuit — fond des panneaux d'interface. La grappe la plus dérivée
    /// du projet (77 variantes pour une seule couleur voulue).
    static let panelNight = SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1)

    /// Bordure violette des panneaux et boutons d'interface.
    static let panelBorder = SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 0.8)

    /// Noir chaud — ombres et fonds de zones souterraines.
    static let shadowWarm = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)

    /// Parchemin — texte de lore, pages du journal.
    static let parchment = SKColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 0.98)

    // MARK: - Bois et terre

    /// Brun bois — caisses, tonneaux, planchers, mobilier.
    static let wood = SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1)

    /// Brun doré — ferrures, cerclages, bordures de coffres.
    static let woodGold = SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1)

    // MARK: - Or
    //
    // Quatre valeurs pour une seule couleur voulue, réparties par fichier
    // plutôt que par intention : le monde et le combat ont chacun redéfini
    // « l'or » de leur côté. Elles DEVRAIENT converger vers `gold`. Tant que
    // ce n'est pas tranché, elles sont nommées — la dérive est visible dans le
    // code au lieu d'être noyée dans 753 littéraux.

    /// Or de référence — le plus employé (monde, POI, coffres).
    static let gold = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1)

    /// Variante « monde » (`WorldBuilder`, `GameManager`). À converger.
    static let goldWorld = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)

    /// Variante « combat » (`CombatSystem`). À converger.
    static let goldCombat = SKColor(red: 1.00, green: 0.82, blue: 0.35, alpha: 1)

    /// Variante « combat, accent vif » (`CombatSystem`). À converger.
    static let goldCombatBright = SKColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1)

    // MARK: - Éléments

    /// Aether — violet clair. Résonance, titres, pouvoir de Kael.
    static let aether = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)

    /// Aether saturé — sorts et corruption.
    static let aetherDeep = SKColor(red: 0.68, green: 0.36, blue: 1.00, alpha: 1)

    /// Bleu glace — sorts de Lyra, barre d'XP.
    static let frost = SKColor(red: 0.55, green: 0.70, blue: 1.0, alpha: 1)

    /// Vert vitalité — soins et PV.
    static let vitality = SKColor(red: 0.45, green: 1.00, blue: 0.62, alpha: 1)

    /// Vert vitalité atténué — barres et libellés secondaires.
    static let vitalityDim = SKColor(red: 0.40, green: 0.95, blue: 0.60, alpha: 1)
}
