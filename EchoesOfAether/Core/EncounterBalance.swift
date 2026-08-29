import Foundation

/// RÉGLAGE DES RENCONTRES — la courbe de difficulté du jeu, en un seul endroit.
///
/// Ces chiffres vivaient éparpillés dans quatre `GameManager+Acte*.swift`, au
/// milieu de la logique de scène. Personne ne pouvait les lire côte à côte, et
/// la courbe était partie à l'envers sans que rien ne le signale : l'Archiviste
/// qui CLÔT l'Acte II avait moins de PV (520) que le Gardien de l'Acte I (620).
///
/// Les rassembler ici les rend comparables d'un coup d'œil ET testables :
/// `EncounterBalanceTests` verrouille la monotonie de la courbe, donc une
/// régression de ce genre casse désormais la suite au lieu de passer en
/// production.
///
/// ## Comment ces valeurs sont choisies
///
/// La référence est la puissance de l'Entaille noire de Kael à chaque acte
/// (`92 + arme × 35 + (niveau − 1) × 4`, plus l'Arbre de l'Aether) :
///
/// | Acte | Niveau typique | Entaille noire | PV du boss | Tours visés |
/// |------|----------------|----------------|------------|-------------|
/// | I    | 2-4            | ~130           | 860        | 7-8         |
/// | II   | 8-12           | ~165           | 1100       | 7-8         |
/// | III  | 18-22          | ~240           | 1750       | 7-8         |
/// | IV   | 25-30          | ~275           | 2200       | 8           |
///
/// Un BREAK rend 1,8× de dégâts : qui exploite les faiblesses tient le rythme
/// haut de la fourchette, qui frappe au hasard sent le mur. Les multiplicateurs
/// de `Difficulty` et du New Game+ se composent par-dessus.
///
/// ## Pourquoi les PV plutôt que les dégâts
///
/// Gonfler les dégâts transforme un combat en loterie de premier tour ; gonfler
/// les PV laisse au joueur le temps de jouer son système. C'est la règle que
/// `Difficulty` applique déjà pour le mode Vétéran, on la suit ici aussi.
enum EncounterBalance {

    // MARK: - Boss majeurs (un par acte)

    /// Acte I — le Gardien fêlé, au Sanctuaire.
    enum Guardian {
        static let hp = 860
        static let enrageThreshold: CGFloat = 0.55
        static let specialDamage = 78
    }

    /// Acte II — l'Archiviste. Son combat est une énigme : il se recompose
    /// tant que son registre (bouclier) tient, on ne le bat qu'en le brisant.
    enum Archivist {
        static let hp = 1100
        static let enrageThreshold: CGFloat = 0.50
        static let specialDamage = 74
    }

    /// Acte III — le Gardien du Seuil, l'Ombre d'Eran.
    enum ThresholdGuardian {
        static let hp = 1750
        static let enrageThreshold: CGFloat = 0.60
        static let specialDamage = 92
    }

    /// Acte IV — l'Avatar du Vide, dernier affrontement du jeu.
    enum VoidAvatar {
        static let hp = 2200
        static let enrageThreshold: CGFloat = 0.55
        static let specialDamage = 98
    }

    /// Les quatre boss d'acte, dans l'ordre de la narration. Sert au test de
    /// monotonie : chaque acte doit demander plus que le précédent.
    static let actBossHP: [Int] = [Guardian.hp, Archivist.hp,
                                   ThresholdGuardian.hp, VoidAvatar.hp]

    // MARK: - Boss de donjons optionnels

    /// Sentinelle des ruines (Acte II), Golem de cendre (mines de Cendreval),
    /// Colosse des sables (désert d'Ossara). Contenu facultatif atteint à des
    /// niveaux variables : durci plus prudemment que les boss d'acte, un
    /// joueur peut y arriver en avance par la carte du monde.
    enum SideBoss {
        static let ruinsSentinel = 500
        static let ashGolem = 780
        static let sandColossus = 880
    }

    // MARK: - Ennemis ordinaires de fin de partie

    /// Les rencontres ordinaires devenaient TRIVIALES en fin de jeu : une
    /// goule d'Acte I tenait 2 tours (200 PV contre ~110 de dégâts), un
    /// marcheur d'os d'Acte IV n'en tenait plus qu'un seul (340 PV contre
    /// ~275, et 486 sur un BREAK). La difficulté des combats de base baissait
    /// donc à mesure qu'on progressait.
    ///
    /// On rétablit le rapport d'origine — environ 1,8 fois les dégâts d'un
    /// tour — pour que deux tours restent nécessaires jusqu'au bout.
    enum LateEnemy {
        /// Acte III — les Ombres du Vide.
        static let voidShadeStrong = 460
        static let voidShadeSwift = 400
        /// Acte IV — gardiens du Cœur.
        static let devourerStrong = 540
        static let devourerSwift = 470
    }
}
