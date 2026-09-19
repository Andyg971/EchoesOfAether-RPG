import Foundation

/// LES FORMULES DU COMBAT — pures, sans scène, sans acteur, sans hasard.
///
/// Elles vivaient inline dans `CombatSystem+Actions` et `+TurnLoop`, mêlées
/// aux animations, aux sons et aux labels. Impossible à tester sans monter
/// une scène SpriteKit entière : c'est pour ça que les capstones de l'Arbre
/// de l'Aether (Entaille double, Tempête jumelle, Dernier souffle) n'ont
/// jamais eu de test, seulement des captures d'écran.
///
/// Ici chaque fonction prend des nombres et rend des nombres. Le hasard
/// (critique, esquive) est tranché PAR L'APPELANT et passé en booléen, pour
/// que chaque branche soit testable à coup sûr.
///
/// ⚠️ L'ordre des arrondis est celui du code d'origine — `Int(...)` tronque
/// à chaque étape, et la division entière du combo précède la conversion.
/// Le changer modifierait des dégâts d'un point ici ou là ; les tests
/// verrouillent ces valeurs.
enum CombatMath {

    // MARK: - Constantes d'équilibrage

    /// Cible brisée (BREAK) : le payoff uniforme de tout coup porté.
    static let brokenMultiplier: CGFloat = 1.8
    /// Coup critique.
    static let critMultiplier: CGFloat = 1.5
    /// Sort qui touche une faiblesse.
    static let weaknessMultiplier: CGFloat = 1.35
    /// Chaque point de Boost (Octopath) ajoute 55 % de dégâts.
    static let boostStep: CGFloat = 0.55
    /// Frappe au timing réussie (Sea of Stars).
    static let strikeBonus: CGFloat = 1.35
    /// Entaille double : le second coup vaut 55 % du premier.
    static let doubleSlashRatio: CGFloat = 0.55
    /// Parade réussie : le coup ne passe qu'à 35 %.
    static let blockRatio: Double = 0.35

    // MARK: - Multiplicateurs

    /// Boost et frappe au timing se cumulent : bien jouer les deux
    /// récompense vraiment.
    static func actionMultiplier(boost: Int, timedStrike: Bool) -> CGFloat {
        (1.0 + CGFloat(boost) * boostStep) * (timedStrike ? strikeBonus : 1.0)
    }

    /// Combo d'attaques physiques, en dixièmes : 10 = ×1,0, 12 = ×1,2 à
    /// partir du 3e coup, 14 = ×1,4 à partir du 5e.
    static func comboMultiplierTenths(comboCount: Int) -> Int {
        comboCount >= 5 ? 14 : (comboCount >= 3 ? 12 : 10)
    }

    // MARK: - Dégâts portés

    /// Attaque physique. `comboCount` est le compteur APRÈS incrément.
    static func attackDamage(base: Int, comboCount: Int, multiplier: CGFloat,
                             isCrit: Bool, targetBroken: Bool) -> Int {
        // Division entière AVANT la conversion : c'est l'ordre d'origine.
        var dmg = Int(CGFloat(base * comboMultiplierTenths(comboCount: comboCount) / 10) * multiplier)
        if isCrit { dmg = Int(CGFloat(dmg) * critMultiplier) }
        if targetBroken { dmg = Int(CGFloat(dmg) * brokenMultiplier) }
        return dmg
    }

    /// Entaille noire — premier coup.
    static func blackSlashDamage(base: Int, multiplier: CGFloat,
                                 isCrit: Bool, targetBroken: Bool) -> Int {
        var dmg = Int(CGFloat(base) * multiplier)
        if isCrit { dmg = Int(CGFloat(dmg) * critMultiplier) }
        if targetBroken { dmg = Int(CGFloat(dmg) * brokenMultiplier) }
        return dmg
    }

    /// ENTAILLE DOUBLE (capstone de la Lame) : la lame repasse à 55 %.
    /// Uniquement pour Kael (c'est SON arbre), uniquement si la cible tient
    /// encore debout après le premier coup — on ne frappe pas un cadavre.
    /// Rend 0 quand le second coup ne part pas.
    static func doubleSlashEcho(primaryDamage: Int, isKael: Bool,
                                hasCapstone: Bool, targetHPAfterPrimary: Int) -> Int {
        guard isKael, hasCapstone, targetHPAfterPrimary > 0 else { return 0 }
        return max(1, Int(CGFloat(primaryDamage) * doubleSlashRatio))
    }

    /// Sort offensif. `spellMultiplier` est celui de l'espèce (allié) ou de
    /// la voie de l'Aether (Kael).
    static func spellDamage(power: Int, multiplier: CGFloat, spellMultiplier: CGFloat,
                            hitsWeakness: Bool, targetBroken: Bool) -> Int {
        var dmg = Int(CGFloat(power) * multiplier * spellMultiplier)
        if hitsWeakness { dmg = Int(CGFloat(dmg) * weaknessMultiplier) }
        if targetBroken { dmg = Int(CGFloat(dmg) * brokenMultiplier) }
        return dmg
    }

    // MARK: - Dégâts subis

    /// Coup ennemi après parade et ÉGIDE (voie du Souffle). Jamais 0 : le
    /// joueur doit rester attentif, pas devenir invincible.
    static func incomingDamage(raw: Int, blocked: Bool, damageReduction: CGFloat) -> Int {
        var dmg = blocked ? max(1, Int(Double(raw) * blockRatio)) : raw
        if damageReduction > 0 {
            dmg = max(1, Int(CGFloat(dmg) * (1 - damageReduction)))
        }
        return dmg
    }

    /// Applique un coup à Kael avec DERNIER SOUFFLE (capstone du Souffle) :
    /// le coup fatal le laisse à 1 PV, une seule fois par combat, et jamais
    /// s'il n'avait déjà qu'1 PV — sinon le sursis serait infini.
    /// Rend les PV résultants et si le capstone vient de se consommer.
    static func applyHitToKael(hp: Int, damage: Int, hasLastBreath: Bool,
                               lastBreathUsed: Bool) -> (hp: Int, lastBreathTriggered: Bool) {
        let fatal = hp - damage <= 0
        if fatal, hasLastBreath, !lastBreathUsed, hp > 1 {
            return (1, true)
        }
        return (max(0, hp - damage), false)
    }

    // MARK: - Tempête

    /// TEMPÊTE JUMELLE (capstone de l'Aether) : deux Tempêtes par combat
    /// au lieu d'une.
    static func tempestMaxUses(hasTwinTempest: Bool) -> Int {
        hasTwinTempest ? 2 : 1
    }
}
