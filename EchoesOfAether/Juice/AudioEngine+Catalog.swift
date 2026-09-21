import AVFoundation
import os

// AudioEngine — catalogue : SFX, ambiances musicales, nappes d'ambiance.
extension AudioEngine {
    // MARK: - Sons

    enum Sound: CaseIterable {
        case tap, select, hit, blackSlash, damage
        case gold, purchase, quest, victory, step, shopOpen
        /// Sons d'interface DOUX, synthétisés (pas de fichier). Les SFX
        /// embarqués sont taillés pour l'action : `sfx_tap` tient 0,17 s à
        /// 0,28 de RMS avec un facteur de crête de 1,8 — une tonalité quasi
        /// carrée, sans décroissance, qui agresse dès qu'on l'entend en
        /// rafale dans un menu. Ces deux-là sont des sinus à faible niveau.
        case uiMove, uiConfirm

        /// SFX CC0 embarqué (Juhani Junkala) ; nil = synthèse.
        var fileName: String? {
            switch self {
            case .uiMove, .uiConfirm: return nil   // synthétisés
            case .tap:        return "sfx_tap"
            case .select:     return "sfx_select"
            case .hit:        return "sfx_hit"
            case .blackSlash: return "sfx_blackslash"
            case .damage:     return "sfx_damage"
            case .gold:       return "sfx_gold"
            case .purchase:   return "sfx_purchase"
            case .quest:      return "sfx_quest"
            case .victory:    return "sfx_victory"
            case .step:       return "sfx_step"
            case .shopOpen:   return "sfx_shopopen"
            }
        }
    }

    /// Ambiance musicale par zone. Chaque cas a sa propre boucle pré-rendue
    /// (drone + harmoniques + battement). Aucune dépendance audio externe.
    enum MusicMood: CaseIterable {
        case calm        // village / éveil
        case tense       // forêt corrompue
        case sacred      // sanctuaire
        case ruins       // ruines / Acte II / Kael déchu
        case voidThreshold // Acte III, le Seuil
        case mines       // galeries de Cendreval
        case inn         // intérieurs (auberge, échoppes)
        case combat      // combat standard — variante 1
        case combat2     // combat standard — variante 2
        case combat3     // combat standard — variante 3
        // Un seul thème pour tous les boss (Gardien, Archiviste, Seuil,
        // Avatar du Vide) : chacun avait son propre cas, mais trois d'entre
        // eux retombaient sur la piste de repli d'un AUTRE combat faute de
        // fichier dédié — la Menace de l'Archiviste sonnait comme les mines,
        // pas comme elle-même. Une seule piste, assumée, vaut mieux que
        // quatre promesses tenues à un quart.
        case boss
        case title       // écran-titre
        case finale      // vraie fin / crédits — aube nouvelle

        /// Ambiance associée à une phase de jeu.
        static func forPhase(_ phase: GamePhase) -> MusicMood {
            switch phase {
            case .wake, .village, .complete: return .calm
            case .forest:                    return .tense
            case .shrine:                    return .sacred
            case .act2, .ruins, .fallen:     return .ruins
            case .act3, .act4:               return .voidThreshold
            }
        }

        /// Piste CC0 embarquée (OpenGameArt) ; nil = boucle synthétisée.
        var fileName: String? {
            switch self {
            case .calm:          return "music_village"
            case .tense:         return "music_forest"
            case .sacred:        return "music_title"
            case .ruins:         return "music_mines"
            case .voidThreshold: return "music_threshold"
            case .mines:         return "music_mines"
            case .inn:           return "music_inn"
            case .combat:        return "music_combat"
            case .combat2:       return "music_combat2"
            case .combat3:       return "music_combat3"
            case .boss:          return "music_boss"
            case .title:         return "music_title"
            case .finale:        return "music_finale"
            }
        }

        /// Piste de REPLI quand `fileName` n'est pas (encore) embarquée.
        /// Permet d'ajouter `music_combat2.m4a`, `music_boss_void.m4a`… dans
        /// Resources/Music plus tard : le code les prend automatiquement, et
        /// en attendant chaque boss sonne déjà différemment grâce aux pistes
        /// existantes. Aucun combat ne se retrouve muet.
        var fallbackFileName: String? {
            switch self {
            case .combat2, .combat3:  return "music_combat"
            default:                  return nil
            }
        }

        /// Mood de repli pour la synthèse des cas sans piste dédiée.
        var synthFallback: MusicMood {
            switch self {
            case .mines: return .ruins
            case .inn: return .calm
            case .combat, .combat2, .combat3: return .tense
            case .boss: return .voidThreshold
            case .title: return .sacred
            case .finale: return .sacred
            default: return self
            }
        }
    }

    /// Couche foley bouclée par zone. Chaque cas mappe un fichier CC0
    /// embarqué (Resources/Ambience). `.none` coupe l'ambiance.
    enum Ambience: CaseIterable {
        case none
        case village   // brise légère + oiseaux lointains
        case forest    // vent dans les feuilles + insectes
        case mines     // goutte-à-goutte souterrain, réverbéré
        case desert    // vent chaud, sable
        case interior  // crépitement de feu, calme

        /// Fichier CC0 embarqué ; nil = silence (aucune synthèse de repli).
        var fileName: String? {
            switch self {
            case .none:     return nil
            case .village:  return "amb_village"
            case .forest:   return "amb_forest"
            case .mines:    return "amb_mines"
            case .desert:   return "amb_desert"
            case .interior: return "amb_interior"
            }
        }
    }
}
