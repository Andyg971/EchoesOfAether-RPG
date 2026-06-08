# Echoes of Aether

> *"Elle avait raison. Sur tout. Mais les morts ne parlent pas."*
> — Kael, Acte II

RPG iOS dark fantasy construit entièrement en **Swift 6 natif + SpriteKit** — aucun moteur externe, aucun asset payant. Chaque pixel est dessiné en code.

---

## Histoire

**Kael** se réveille dans le village de **Solis**, son passé effacé. Guidé par sa meilleure amie **Lyra**, il s'aventure dans la **Forêt d'Ébène** corrompue, affronte le **Gardien de l'Aether**, et découvre une vérité qu'il ne peut plus ignorer.

**Acte I — L'Éveil**  
Kael retrouve ses repères à Solis. Exploration, quêtes, combats contre des créatures corrompues, victoire sur le Gardien du Sanctuaire — sans savoir ce que ses pouvoirs d'Aether noir signifient vraiment.

**Acte II — La Chute de Kael**  
De retour en héros, Kael est hanté par des cauchemars. Dorin bloque la porte nord. Les Ruines de la Source cachent un Archiviste qui a catalogué chaque âme que Kael a jamais absorbée. Une inscription cachée de la chercheuse disparue **Eran Solace** évoque une salvation — le **Seuil**. Lyra découvre la vérité. Kael la fait taire. La Voix dit : *"Tu es libre. Viens."* Kael répond : *"Oui."*

**Acte III — (Prévu)**  
Kael comme Lame du Vide. Le Seuil. Eran Solace. Un règlement de comptes.

---

## Gameplay

| Système | Description |
|---------|-------------|
| **Exploration** | Tap-to-move avec marqueur visuel. Interactions NPC par proximité. Changement de zone avec transitions. |
| **Combat ATB** | Active Time Battle — Kael et l'ennemi remplissent leurs jauges. Attaque ou Entaille Noire (signature). Boss avec seuil d'enragement et attaques spéciales. |
| **Dialogues** | Système multi-lignes avec choix ramifiés. Les réponses affectent le ton, pas l'issue (couleur narrative). |
| **Quêtes** | Livraison (Mara → Garen), Jouet perdu (enfant), Éclats d'Aether de Lyra. |
| **Boutique / Inventaire** | Armes (Lame de Fer, Lame Runique), Armures (Cotte de Mailles, Armure Renforcée), Potions, Éclats d'Aether. |
| **Sauvegarde** | Auto-save à chaque transition d'état + sauvegarde manuelle aux **Cristaux d'Aether** placés dans chaque zone. |
| **Corruption** | La corruption visuelle de Kael progresse sur 3 niveaux (aura → vrilles → yeux rouges) à mesure que l'Acte II se déroule. |

---

## Architecture

```
EchoesOfAether/
├── Core/
│   ├── GameState.swift         — Enums GameState/GamePhase, PlayerState, SaveData
│   ├── GameManager.swift       — Coordinateur central. Route les taps, gère la machine d'états
│   └── SaveManager.swift       — Encode/decode JSON vers UserDefaults
├── Game/
│   ├── Scenes/
│   │   ├── WorldBuilder.swift       — Construction de toutes les zones (village, forêt, sanctuaire, ruines)
│   │   ├── MovementController.swift — Tap-to-move avec interpolation de vitesse
│   │   └── TransitionManager.swift  — Transitions fade, écrans de fin d'acte
│   └── Combat/
│       └── CombatSystem.swift       — Moteur ATB, BossConfig, calcul de dégâts
├── UI/
│   ├── HUDOverlay.swift         — Or, Résonance, Objectif, labels de quête
│   ├── DialogueSystem.swift     — Panel, speaker, choix (empilés verticalement)
│   ├── ShopOverlay.swift        — Liste d'items avec logique d'achat
│   └── InventoryOverlay.swift   — Affichage équipement + stats
├── Models/
│   └── WorldNode.swift          — Factory methods pour tous les personnages (Kael, Lyra, Dorin…)
├── Juice/
│   ├── JuiceEngine.swift        — screenShake, flashOverlay, slowMotion, popIn, pulse, float
│   ├── ParticleFactory.swift    — impactSparks, blackAetherBurst, ambientDust, forestFog, shrineAura, ruinsAsh
│   └── AudioEngine.swift        — Déclencheurs d'effets sonores (quête, or, combat)
├── Content/
│   └── PrototypeContent.swift   — Tous les tableaux de dialogues (clés xcstrings FR/EN)
├── GameScene.swift              — SKScene shell — forward touches/update vers GameManager
├── GameViewController.swift     — Hôte UIKit, injection safe area
└── Localizable.xcstrings        — Toutes les strings, FR (base) + EN. Zéro string hard-codée.
```

### Machine d'états

```
GameState:  exploration → dialogue → combat → shop → inventory → transition

GamePhase:
  wake → village → forest → shrine → complete
                                         ↓
                                       act2 → ruins → fallen
```

### Patterns clés

- **@MainActor** partout — SpriteKit + Swift 6 strict concurrency
- **Static factory** — `WorldNode.*()`, `ParticleFactory.*()`, `TransitionManager.*()`
- **Closure callbacks** — `DialogueSystem.start([steps]) { completion }` chaîne les scènes
- **Pont valeur/référence pour la save** — `PlayerState` (class, @MainActor) ↔ `SaveData` (struct Codable)
- **Zéro dépendance externe** — 0 packages SPM, frameworks Apple purs

---

## Outils & Frameworks

| Outil | Usage |
|-------|-------|
| **Swift 6** | Strict concurrency, actors, Sendable |
| **SpriteKit** | Tout le rendu 2D — nodes, actions, sans physics |
| **UIKit** | Hôte GameViewController, safe area insets |
| **Foundation** | Système de save Codable, String(localized:) |
| **AVFoundation** | Wrapper moteur audio |
| **Xcode 16+** | Build, simulateur, éditeur xcstrings |
| **GitHub CLI (`gh`)** | Création de repo, CI-ready |

### Stack de Juice

| Effet | Déclencheur |
|-------|-------------|
| `screenShake` | Chaque coup en combat, événements de corruption |
| `flashOverlay` | Entaille Noire, séquences de vision, découvertes |
| `slowMotion` (0.15s) | Impact de l'Entaille Noire |
| `blackAetherBurst` | VFX particules Entaille Noire |
| `impactSparks` | Attaques normales, ramassage d'objets |
| `popIn` | Entrée des éléments UI |
| `pulse` / `float` | Décorations de zone ambiantes, objets interactifs |
| `ambientDust` / `forestFog` / `shrineAura` / `ruinsAsh` | Atmosphère par zone |

---

## Localisation

**100% localisé** — FR (base) + EN. Zéro string hard-codée.

Utilise `Localizable.xcstrings` (format unifié Xcode 15+).  
Tous les dialogues, labels HUD, noms de combat, items de boutique, textes de quête, labels du monde.

Pour tester en anglais : `Scheme → Edit Scheme → Run → Options → App Language → English`

---

## Lancer le projet

```bash
git clone https://github.com/Andyg971/EchoesOfAether-RPG.git
cd EchoesOfAether-RPG
open EchoesOfAether/EchoesOfAether.xcodeproj
# ▶ Run sur simulateur iPhone (portrait)
```

**Prérequis :** iOS 17+ / Xcode 16+ / aucune dépendance externe

---

## État actuel

| Fonctionnalité | Statut |
|----------------|--------|
| Acte I — L'Éveil | ✅ Complet |
| Acte II — La Chute de Kael | ✅ Complet |
| Acte III — Le Seuil | ✅ Jouable (zone du Seuil dédiée + boss final + vraie fin) |
| Menu principal / Pause / Options / Mort | ✅ Complet |
| Combat ATB (sorts, statuts, combo, break, boss) | ✅ Complet |
| Journal de quêtes + Journal de lore | ✅ Complet |
| Minimap / Indicateur d'interaction / Haptics | ✅ Complet |
| GameCenter (auth + achievements) | ✅ Câblé |
| Localisation FR + EN | ✅ Complet (459 clés) |
| AppIcon 1024 | ✅ Présent |
| Graphismes placeholder | ✅ (formes programmatiques) |
| Audio (SFX + musique) | 🔴 Stub silencieux (à réimplémenter) |
| Assets réels | 🟡 Partiel (tiles RPG Maker MV intégrées) |
| Build App Store | 🟡 Prêt côté build, audio + Acte III à finir |

---

## Roadmap — Ce qui reste

### 🔴 Indispensable

- [ ] **Audio réel** — `AudioEngine` est un stub no-op (crash IO thread iOS 26 simulateur). Réimplémenter avec `AVAudioPlayerNode` + `AVAudioPCMBuffer` pré-rendus. Débloque aussi le slider SFX (déjà câblé sur `masterVolume`) et le volume musique.
- [x] **Acte III jouable** — Zone du Seuil dédiée (assets existants : escalier, statues d'anges, piliers, arbres morts), boss final « Gardien du Seuil » (ATB + enrage), vraie fin (Kael franchit le Seuil → crédits). Reste : enrichissement narratif et embranchements de fin.

### 🟡 Important

- [ ] **Slots de sauvegarde multiples** — une seule save (`echoes_save.json`), écrasée en continu.
- [ ] **Tutoriel / onboarding** — tap-to-move, combat ATB et sorts ne sont jamais expliqués.
- [ ] **Support iPad adaptatif** — `TARGETED_DEVICE_FAMILY = 1,2` mais layout non adaptatif.
- [ ] **Accessibilité** — Dynamic Type, option « réduire les animations » (flashs/screen shakes fréquents).
- [ ] **Fix proximité Dorin/Garen** — conflits de tap possibles en Acte II.

### 🟢 Nice-to-have

- [ ] **Tests unitaires** — `PlayerState` (courbe XP, save/load), transitions de quêtes.
- [ ] **Musique d'ambiance par zone** (dépend de l'audio réel).

### ✅ Déjà livré (anciennes entrées roadmap)

Menu principal · Écran de mort + Réessayer · Restauration PV (cristaux/repos) · Menu pause ·
Écran d'options (+ sélecteur langue FR/EN) · Journal de quêtes · Journal de lore (bouton HUD) ·
Indicateur d'interaction (bulle + hint) · Indicateur de sauvegarde (flash) · Minimap ·
Système de combo · Effets de statut (poison / Brûlure d'Aether) · Cinématique de corruption ·
Crédits · Achievements GameCenter · Haptics CoreHaptics · Orientation portrait verrouillée.

---

## Bundle ID

```
com.appmakerstudio.echoesofaether
```

---

*Built with [Claude Code](https://claude.ai/code)*  
*"Le Seuil peut encore—" / "Trop tard, Lyra."*
