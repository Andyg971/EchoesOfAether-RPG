import Foundation

/// Difficulté choisie par le joueur.
///
/// Le moteur savait déjà moduler les ennemis : le New Game+ leur donne +45 %
/// de PV et +30 % de dégâts par palier, en un seul point de calcul dans
/// `CombatSystem.begin(...)`. Il ne manquait que le curseur inverse — celui
/// qui laisse finir l'histoire à quelqu'un qui vient pour le récit, et qui
/// donne du mordant à celui qui vient pour le combat.
///
/// Les deux facteurs se multiplient : un vétéran en New Game+ 2 affronte des
/// ennemis à 1,30 × 1,90 = 2,47× PV. C'est voulu — le NG+ est un palier de
/// relance, la difficulté est un réglage de confort ; ils s'empilent.
///
/// Le réglage est modifiable **à tout moment** (il n'est lu qu'au début de
/// chaque combat, pas gravé dans la sauvegarde) : un joueur bloqué sur un boss
/// peut redescendre sans recommencer sa partie. C'est un choix délibéré —
/// verrouiller la difficulté en début de partie punit surtout ceux qu'elle est
/// censée aider.
enum Difficulty: Int, CaseIterable {
    /// Pour le récit : les combats restent présents mais ne bloquent pas.
    case story = 0
    /// L'équilibrage d'origine. Toute valeur non reconnue retombe ici.
    case normal = 1
    /// Pour qui vient chercher le système de combat.
    case veteran = 2

    static let storageKey = "difficulty"

    /// Réglage courant. `normal` par défaut et en cas de valeur inconnue —
    /// une sauvegarde de réglages corrompue ne doit pas rendre le jeu
    /// injouable.
    static var current: Difficulty {
        get {
            guard UserDefaults.standard.object(forKey: storageKey) != nil else { return .normal }
            return Difficulty(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .normal
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    /// Réglage suivant dans le cycle (la ligne d'options se tape pour cycler,
    /// comme les bascules voisines — pas de sous-menu pour trois valeurs).
    var next: Difficulty {
        Difficulty(rawValue: (rawValue + 1) % Difficulty.allCases.count) ?? .normal
    }

    /// Multiplicateur de PV ennemis.
    ///
    /// Le mode Histoire raccourcit les combats sans les supprimer (-30 %) ;
    /// Vétéran les allonge assez pour que la gestion des MP et des BREAK
    /// compte vraiment (+30 %).
    var enemyHPMultiplier: Double {
        switch self {
        case .story:   return 0.70
        case .normal:  return 1.00
        case .veteran: return 1.30
        }
    }

    /// Multiplicateur de dégâts ennemis.
    ///
    /// Volontairement moins agressif que les PV côté Vétéran : gonfler les
    /// dégâts transforme un combat en loterie de premier tour, gonfler les PV
    /// laisse au joueur le temps de jouer son système.
    var enemyDamageMultiplier: Double {
        switch self {
        case .story:   return 0.65
        case .normal:  return 1.00
        case .veteran: return 1.25
        }
    }

    /// Clé de localisation du nom affiché.
    var localizationKey: String.LocalizationValue {
        switch self {
        case .story:   return "options.difficulty.story"
        case .normal:  return "options.difficulty.normal"
        case .veteran: return "options.difficulty.veteran"
        }
    }

    var localizedName: String {
        String(localized: localizationKey)
    }
}
