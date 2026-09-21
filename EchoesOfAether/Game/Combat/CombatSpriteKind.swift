import SpriteKit

// Types de sprites de l'arène de combat + fiches de bestiaire.
/// Types de sprites utilisés dans l'arène de combat.
enum CombatSpriteKind: CaseIterable {
    case beast          // Bête corrompue (forêt 1)
    case wolf           // Loup d'ombre (forêt 2)
    case ghoul          // Goule corrompue (forêt, optionnel)
    case boneWalker     // Squelette errant (forêt, optionnel)
    case guardian       // Gardien de l'Aether — boss Acte I
    case ruinsGuardian  // Gardien des Ruines (Acte II)
    case archivist      // Archiviste — boss Acte II

    /// Identifiant stable pour la persistance du bestiaire.
    var bestiaryID: String {
        switch self {
        case .beast: return "beast"
        case .wolf: return "wolf"
        case .ghoul: return "ghoul"
        case .boneWalker: return "boneWalker"
        case .guardian: return "guardian"
        case .ruinsGuardian: return "ruinsGuardian"
        case .archivist: return "archivist"
        }
    }

    /// Nom d'espèce localisé (réutilise les clés de combat).
    var speciesName: String {
        switch self {
        case .beast: return String(localized: "combat.enemy.beast")
        case .wolf: return String(localized: "combat.enemy.wolf")
        case .ghoul: return String(localized: "combat.enemy.ghoul")
        case .boneWalker: return String(localized: "combat.enemy.bonewalker")
        case .guardian: return String(localized: "combat.enemy.guardian")
        case .ruinsGuardian: return String(localized: "combat.enemy.ruinsGuardian")
        case .archivist: return String(localized: "combat.enemy.archivist")
        }
    }

    /// Notice de bestiaire.
    var bestiaryDescription: String {
        switch self {
        case .beast: return String(localized: "bestiary.beast.desc")
        case .wolf: return String(localized: "bestiary.wolf.desc")
        case .ghoul: return String(localized: "bestiary.ghoul.desc")
        case .boneWalker: return String(localized: "bestiary.boneWalker.desc")
        case .guardian: return String(localized: "bestiary.guardian.desc")
        case .ruinsGuardian: return String(localized: "bestiary.ruinsGuardian.desc")
        case .archivist: return String(localized: "bestiary.archivist.desc")
        }
    }

    /// Asset de vignette (frame idle 1) ; nil = silhouette programmatique.
    var thumbnailAsset: String? {
        switch self {
        case .beast: return "enemy_beast_idle_1"
        case .wolf: return "enemy_shadewolf_idle_1"
        case .ghoul: return "enemy_ghoul_idle_1"
        case .boneWalker: return "enemy_bone_idle_1"
        case .guardian: return nil
        case .ruinsGuardian: return nil
        // Vignette du bestiaire : l'Archiviste dans son premier état, le
        // bleu. C'est celui sous lequel le joueur l'aborde.
        case .archivist: return "enemy_archivist_blue_idle_1"
        }
    }
}
