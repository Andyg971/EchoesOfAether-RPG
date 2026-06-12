/// Strings+References.swift
/// Références statiques pour les clés de localisation utilisées avec
/// interpolation (String(localized: "key \(value)")).
/// Ces déclarations permettent à Xcode de trouver les clés dans le source
/// et d'éliminer les warnings "References to this key could not be found".
/// ⚠️ Ne pas supprimer — utilisé uniquement par l'analyseur statique Xcode.

import Foundation

// swiftlint:disable unused_declaration
private enum _StringsReferences {
    // HUD
    static let hudGold:            LocalizedStringResource = "hud.gold %lld"
    static let hudResonance:       LocalizedStringResource = "hud.resonance %lld"

    // Menu — slots de sauvegarde
    static let menuSlot:           LocalizedStringResource = "menu.slot %lld"
    static let menuSlotMeta:       LocalizedStringResource = "menu.slot.meta %@ %lld %lld"

    // Tutoriel
    static let tutorialProgress:   LocalizedStringResource = "tutorial.progress %lld %lld"

    // Shop
    static let shopGold:           LocalizedStringResource = "shop.gold %lld"
    static let shopPrice:          LocalizedStringResource = "shop.price %lld"

    // End screen
    static let endscreenResonance: LocalizedStringResource = "endscreen.resonance %lld"

    // Inventory
    static let inventoryAttack:    LocalizedStringResource = "inventory.attack %lld"
    static let inventoryDefense:   LocalizedStringResource = "inventory.defense %lld"

    // Combat — combos
    static let comboHit:           LocalizedStringResource = "combat.combo.hit %lld"
    static let comboMega:          LocalizedStringResource = "combat.combo.mega %lld"

    // Combat — statuts
    static let statusAttack:       LocalizedStringResource = "combat.status.attack %@"
    static let statusBlackSlash:   LocalizedStringResource = "combat.status.blackSlash %lld"
    static let statusDefeated:     LocalizedStringResource = "combat.status.defeated %@"

    // Combat — tour par tour
    static let turnEnemy:          LocalizedStringResource = "combat.turn.enemy %@"
    static let turnIntent:         LocalizedStringResource = "combat.turn.intent %@"
    static let statusAttackBoost:  LocalizedStringResource = "combat.status.attackBoosted %lld %lld"
    static let statusHeal:         LocalizedStringResource = "combat.status.heal %lld"
    static let statusHealBoost:    LocalizedStringResource = "combat.status.healBoosted %lld %lld"
    static let statusSpellHit:     LocalizedStringResource = "combat.status.spellHit %@ %lld"
    static let statusSpellWeak:    LocalizedStringResource = "combat.status.spellWeak %@ %lld"
    static let statusEnemyHits:    LocalizedStringResource = "combat.status.enemyHits %@ %lld"
}
// swiftlint:enable unused_declaration
