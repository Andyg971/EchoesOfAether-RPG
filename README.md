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
| Acte III — Le Seuil | 🔲 Prévu |
| Graphismes placeholder | ✅ (formes programmatiques) |
| Assets réels | 🔲 Prévu |
| Build App Store | 🔲 Prévu |

---

## Roadmap — Ce qui manque avant les assets

### 🔴 Indispensable

- [ ] **Menu principal** — Démarrer / Continuer / Options. Le jeu démarre directement en gameplay.
- [ ] **Écran de mort / Game Over** — En cas de défaite au combat, montrer un écran avec "Réessayer" plutôt que revenir silencieusement à l'exploration.
- [ ] **Restauration des PV entre les combats** — Les PV de Kael ne se régénèrent jamais.
- [ ] **Menu pause** — Pause en jeu avec Reprendre / Options / Menu Principal.
- [ ] **Écran d'options** — Volume musique, volume SFX, changement de langue.
- [ ] **Journal de quêtes** — Liste visible des quêtes actives/terminées dans l'inventaire.
- [ ] **Indicateur d'interaction** — Prompt "Toucher pour parler" quand Kael est proche d'un NPC.
- [ ] **Indicateur de sauvegarde** — Flash visuel quand le jeu sauvegarde (le joueur ne sait pas).
- [ ] **Squelette Acte III** — Kael comme antagoniste. Eran Solace. La mécanique du Seuil.

### 🟡 Important

- [ ] **Minimap** — Représentation en points de la zone + position de Kael.
- [ ] **Système de combo** — Chaîner les attaques pour un bonus de résonance.
- [ ] **Effets de statut** — Poison, étourdissement, Brûlure d'Aether pour plus de profondeur.
- [ ] **Cinématique transformation Kael** — Moment visuel quand la corruption atteint le niveau 3.
- [ ] **Journal de lore** — Notes de Kael sur les découvertes (inscription Eran, révélations Archiviste).
- [ ] **Fix proximité Dorin/Garen** — Les deux sont à h×0.72-0.74 en Acte II, conflits de tap.

### 🟢 Nice-to-have

- [ ] **Crédits**
- [ ] **Achievements** (GameCenter)
- [ ] **Support iPad** (layout adaptatif)
- [ ] **Haptics** CoreHaptics sur les impacts majeurs

---

## Bundle ID

```
com.appmakerstudio.echoesofaether
```

---

*Built with [Claude Code](https://claude.ai/code)*  
*"Le Seuil peut encore—" / "Trop tard, Lyra."*
