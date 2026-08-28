import Foundation

/// ARBRE DE L'AETHER — la progression que Kael CHOISIT.
///
/// Le niveau donne des stats automatiques ; l'arbre donne un build. Trois
/// voies, 39 points de contenu pour ~29 points gagnés (1 par niveau de L2 à
/// L30) : on ne peut pas tout prendre, donc chaque point est un choix.
///
/// - `blade`  : attaque, critique, Entaille noire — la voie de l'acier.
/// - `aether` : Magie, puissance des sorts, Tempête — la voie du mage.
/// - `breath` : PV, esquive, mitigation — la voie de celui qui encaisse.
enum SkillBranch: String, CaseIterable, Codable {
    case blade, aether, breath

    var title: String {
        switch self {
        case .blade:  return String(localized: "skill.branch.blade.name")
        case .aether: return String(localized: "skill.branch.aether.name")
        case .breath: return String(localized: "skill.branch.breath.name")
        }
    }

    var subtitle: String {
        switch self {
        case .blade:  return String(localized: "skill.branch.blade.desc")
        case .aether: return String(localized: "skill.branch.aether.desc")
        case .breath: return String(localized: "skill.branch.breath.desc")
        }
    }
}

/// Un nœud de l'arbre. `valuePerRank` porte la valeur brute du bonus
/// (points d'attaque, pourcentage, PV…) ; les capstones l'ignorent — leur
/// effet est booléen et se lit dans `CombatSystem`.
struct SkillNode: Identifiable, Equatable {
    let id: String
    let branch: SkillBranch
    /// Profondeur dans la voie (0 → 3). Le tier 3 est le capstone.
    let tier: Int
    let maxRank: Int
    let costPerRank: Int
    let valuePerRank: Int

    var isCapstone: Bool { tier == 3 }

    /// Clés en dur (pas d'interpolation d'`id`) : Xcode ne sait extraire que
    /// les littéraux, et une clé dynamique passerait silencieusement à la
    /// trappe au moment de la traduction.
    var title: String {
        switch id {
        case "blade.attack":    return String(localized: "skill.blade.attack.name")
        case "blade.crit":      return String(localized: "skill.blade.crit.name")
        case "blade.slash":     return String(localized: "skill.blade.slash.name")
        case "blade.capstone":  return String(localized: "skill.blade.capstone.name")
        case "aether.mp":       return String(localized: "skill.aether.mp.name")
        case "aether.power":    return String(localized: "skill.aether.power.name")
        case "aether.regen":    return String(localized: "skill.aether.regen.name")
        case "aether.capstone": return String(localized: "skill.aether.capstone.name")
        case "breath.hp":       return String(localized: "skill.breath.hp.name")
        case "breath.dodge":    return String(localized: "skill.breath.dodge.name")
        case "breath.ward":     return String(localized: "skill.breath.ward.name")
        default:                return String(localized: "skill.breath.capstone.name")
        }
    }

    /// Description : les nœuds chiffrés affichent leur valeur par rang, les
    /// capstones ont un texte fixe (leur effet n'est pas un nombre).
    var detail: String {
        let v = valuePerRank
        switch id {
        case "blade.attack":    return String(localized: "skill.blade.attack.desc \(v)")
        case "blade.crit":      return String(localized: "skill.blade.crit.desc \(v)")
        case "blade.slash":     return String(localized: "skill.blade.slash.desc \(v)")
        case "blade.capstone":  return String(localized: "skill.blade.capstone.desc")
        case "aether.mp":       return String(localized: "skill.aether.mp.desc \(v)")
        case "aether.power":    return String(localized: "skill.aether.power.desc \(v)")
        case "aether.regen":    return String(localized: "skill.aether.regen.desc \(v)")
        case "aether.capstone": return String(localized: "skill.aether.capstone.desc")
        case "breath.hp":       return String(localized: "skill.breath.hp.desc \(v)")
        case "breath.dodge":    return String(localized: "skill.breath.dodge.desc \(v)")
        case "breath.ward":     return String(localized: "skill.breath.ward.desc \(v)")
        default:                return String(localized: "skill.breath.capstone.desc")
        }
    }

    /// Points à investir DANS LA VOIE avant que ce nœud s'ouvre.
    /// Progression 0 / 2 / 5 / 8 : le capstone demande un vrai engagement
    /// (8 + 3 = 11 points sur les 13 de la voie) sans exiger de tout maxer.
    var branchRequirement: Int {
        switch tier {
        case 0: return 0
        case 1: return 2
        case 2: return 5
        default: return 8
        }
    }
}

/// Données pures, volontairement NON isolées au MainActor : `PlayerState`
/// les lit depuis ses stats dérivées, qui sont appelées hors du main actor.
enum SkillTree {

    /// Registre complet. 13 points par voie, 39 au total.
    static let allNodes: [SkillNode] = [
        // ── LAME ──
        .init(id: "blade.attack",   branch: .blade,  tier: 0, maxRank: 3, costPerRank: 1, valuePerRank: 3),
        .init(id: "blade.crit",     branch: .blade,  tier: 1, maxRank: 3, costPerRank: 1, valuePerRank: 3),
        .init(id: "blade.slash",    branch: .blade,  tier: 2, maxRank: 2, costPerRank: 2, valuePerRank: 14),
        .init(id: "blade.capstone", branch: .blade,  tier: 3, maxRank: 1, costPerRank: 3, valuePerRank: 0),
        // ── AETHER ──
        .init(id: "aether.mp",       branch: .aether, tier: 0, maxRank: 3, costPerRank: 1, valuePerRank: 8),
        .init(id: "aether.power",    branch: .aether, tier: 1, maxRank: 3, costPerRank: 1, valuePerRank: 6),
        .init(id: "aether.regen",    branch: .aether, tier: 2, maxRank: 2, costPerRank: 2, valuePerRank: 4),
        .init(id: "aether.capstone", branch: .aether, tier: 3, maxRank: 1, costPerRank: 3, valuePerRank: 0),
        // ── SOUFFLE ──
        .init(id: "breath.hp",       branch: .breath, tier: 0, maxRank: 3, costPerRank: 1, valuePerRank: 18),
        .init(id: "breath.dodge",    branch: .breath, tier: 1, maxRank: 3, costPerRank: 1, valuePerRank: 3),
        .init(id: "breath.ward",     branch: .breath, tier: 2, maxRank: 2, costPerRank: 2, valuePerRank: 4),
        .init(id: "breath.capstone", branch: .breath, tier: 3, maxRank: 1, costPerRank: 3, valuePerRank: 0)
    ]

    static func nodes(in branch: SkillBranch) -> [SkillNode] {
        allNodes.filter { $0.branch == branch }.sorted { $0.tier < $1.tier }
    }

    static func node(id: String) -> SkillNode? {
        allNodes.first { $0.id == id }
    }

    /// Coût d'une refonte complète à la forge de Bram. Monte avec le niveau
    /// pour que remodeler un build tardif reste une vraie dépense.
    static func respecCost(level: Int) -> Int {
        120 + max(0, level - 1) * 18
    }
}

// MARK: - État du joueur

extension PlayerState {

    /// Points gagnés depuis le début : 1 par niveau après le premier.
    var skillPointsTotal: Int { max(0, level - 1) }

    var skillPointsSpent: Int {
        skillRanks.reduce(0) { total, entry in
            guard let node = SkillTree.node(id: entry.key) else { return total }
            return total + node.costPerRank * min(entry.value, node.maxRank)
        }
    }

    var skillPointsAvailable: Int { max(0, skillPointsTotal - skillPointsSpent) }

    func skillRank(_ id: String) -> Int {
        guard let node = SkillTree.node(id: id) else { return 0 }
        return min(skillRanks[id] ?? 0, node.maxRank)
    }

    func skillPointsSpent(in branch: SkillBranch) -> Int {
        SkillTree.nodes(in: branch).reduce(0) {
            $0 + skillRank($1.id) * $1.costPerRank
        }
    }

    /// Raison pour laquelle un nœud n'est pas investissable, ou nil si OK.
    /// Sert à la fois au gate logique et au texte affiché sous le nœud.
    func skillLock(for node: SkillNode) -> SkillLock? {
        if skillRank(node.id) >= node.maxRank { return .maxed }
        let inBranch = skillPointsSpent(in: node.branch)
        if inBranch < node.branchRequirement {
            return .needsBranchPoints(node.branchRequirement - inBranch)
        }
        if skillPointsAvailable < node.costPerRank { return .notEnoughPoints }
        return nil
    }

    func canUnlock(_ node: SkillNode) -> Bool { skillLock(for: node) == nil }

    /// Investit un rang. Retourne false si le nœud est verrouillé.
    @discardableResult
    func unlockSkill(_ node: SkillNode) -> Bool {
        guard canUnlock(node) else { return false }
        skillRanks[node.id] = skillRank(node.id) + 1
        // Un gain de PV max doit être ressenti tout de suite, pas au prochain
        // repos : on crédite les PV courants du delta.
        if node.id == "breath.hp" { currentHP += node.valuePerRank }
        return true
    }

    /// Refonte complète : tous les points redeviennent disponibles.
    func respecSkills() {
        skillRanks.removeAll()
        currentHP = min(currentHP, currentMaxHP)
    }

    // MARK: - Bonus dérivés

    var skillAttackBonus: Int  { skillRank("blade.attack") * 3 }
    var skillCritBonus: Double { Double(skillRank("blade.crit")) * 0.03 }
    var skillSlashBonus: Int   { skillRank("blade.slash") * 14 }

    var skillMaxMPBonus: Int   { skillRank("aether.mp") * 8 }
    var skillMPRegenBonus: Int { skillRank("aether.regen") * 4 }
    /// Multiplicateur de dégâts des sorts DE KAEL (les alliés gardent le leur).
    var spellPowerMultiplier: CGFloat {
        1.0 + CGFloat(skillRank("aether.power")) * 0.06
    }

    var skillMaxHPBonus: Int    { skillRank("breath.hp") * 18 }
    var skillDodgeBonus: Double { Double(skillRank("breath.dodge")) * 0.03 }
    /// Fraction des dégâts subis retirée par la voie du Souffle (0 → 0.08).
    var skillDamageReduction: CGFloat {
        CGFloat(skillRank("breath.ward")) * 0.04
    }

    // MARK: - Capstones

    /// Entaille double — l'Entaille noire frappe une seconde fois à 55 %.
    var hasDoubleSlash: Bool { skillRank("blade.capstone") > 0 }
    /// Tempête jumelle — la Tempête part deux fois par combat au lieu d'une.
    var hasTwinTempest: Bool { skillRank("aether.capstone") > 0 }
    /// Dernier souffle — survit à 1 PV au coup fatal, une fois par combat.
    var hasLastBreath: Bool { skillRank("breath.capstone") > 0 }
}

/// Pourquoi un nœud est verrouillé — porte le texte affiché au joueur.
enum SkillLock: Equatable {
    case maxed
    case needsBranchPoints(Int)
    case notEnoughPoints

    var message: String {
        switch self {
        case .maxed:
            return String(localized: "skill.lock.maxed")
        case .needsBranchPoints(let missing):
            return String(localized: "skill.lock.branch \(missing)")
        case .notEnoughPoints:
            return String(localized: "skill.lock.points")
        }
    }
}
