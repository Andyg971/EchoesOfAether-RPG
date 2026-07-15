# Echoes of Aether

> *"Kael. Même le Vide n'a pas su me faire taire."*
> — L'Écho de Lyra, Acte III

RPG iOS dark fantasy construit entièrement en **Swift 6 natif + SpriteKit** — aucun moteur externe, aucune dépendance SPM. Pixel art (sprites LimeZu Modern Exteriors + éléments dessinés en code), musiques et SFX **CC0**, zéro asset généré par IA.

**Paysage uniquement · Contrôles classiques (joystick + A/B) · 3 actes jouables · Combats en trio**

---

## Histoire

**Kael** se réveille dans le village de **Solis**, son passé effacé. Guidé par sa meilleure amie **Lyra**, il s'aventure dans la **Forêt d'Ébène** corrompue, affronte le **Gardien de l'Aether**, et découvre une vérité qu'il ne peut plus ignorer.

**Acte I — L'Éveil**
Kael retrouve ses repères à Solis. Exploration, quêtes, combats contre des créatures corrompues — Lyra se bat à ses côtés dans la forêt. Victoire sur le Gardien du Sanctuaire, sans savoir ce que ses pouvoirs d'Aether noir signifient vraiment.

**Acte II — La Chute de Kael**
De retour en héros, Kael est hanté par des cauchemars. Les Ruines de la Source cachent un Archiviste qui a catalogué chaque âme que Kael a jamais absorbée. Une inscription de la chercheuse disparue **Eran Solace** évoque le **Seuil**. Lyra découvre la vérité. Kael la fait taire. Les **Mines de Cendreval** s'ouvrent en zone annexe (3 combats dont un golem).

**Acte III — Le Seuil**
Le Vide garde tout ce qu'il prend — y compris les échos des morts. **L'Écho de Lyra** attend Kael à l'entrée et rejoint le groupe. **Eran**, premier des Veilleurs devenu écho lui-même, complète le **trio**. Esprits errants à apaiser, stèles qui révèlent le prix qu'Eran a payé (son *nom*), Ombres du Vide à purger — puis le Gardien du Seuil, et un choix : **franchir ou résister**. Deux fins.

---

## Gameplay

| Système | Description |
|---------|-------------|
| **Contrôles classiques** | Zéro tactile de gameplay : joystick virtuel (déplacement + navigation des menus au flick), bouton **A** (interagir / valider), bouton **B** (annuler / passer / fermer). Curseur de sélection doré partout : combat, choix de dialogue, boutique, pause, onglets du journal. |
| **Exploration** | Bulle de parole RPG blanche (« … », « ! », « ? », « » ») au-dessus des PNJ/POI, hints « A · Parler ». PNJ qui déambulent seuls (village, esprits du Seuil). Vignette d'ambiance par zone. |
| **Combat tour par tour** | Solo, **duo** (Kael + Lyra, actes I-II) ou **trio** (Kael + Écho de Lyra + Eran, acte III). Kits complémentaires par personnage (Kael FEU/AETHER · Lyra GLACE/FOUDRE/SOIN · Écho GLACE/SOIN · Eran FOUDRE/AETHER). Faiblesses, boucliers, BREAK, statuts avec **icônes persistantes** (flamme/éclair/bouclier fêlé), **critiques** (12 %, ×1.5), **esquives** (10 %), combo, boss avec enragement. Boost façon Octopath : booster coupe la régénération de BP une manche. |
| **Juice combat** | Entrée en scène « dissolution » SNES, parallaxe du décor, micro-zoom caméra sur les gros coups, ghost HP bars, images rémanentes, pose de cast colorée par élément. |
| **Dialogues** | Portraits pixel des locuteurs (Kael = visage de l'icône de l'app), choix ramifiés au curseur, B passe jusqu'au prochain choix. |
| **Quêtes** | 8 quêtes actes I-II + Mines de Cendreval + 3 quêtes annexes acte III (échos égarés, stèles du Vide, Ombres du Vide). |
| **Donjons optionnels** | Mines de Cendreval (3 combats + veine d'or), désert d'Ossara (carte du monde), **Caverne aux Échos** (entrée forêt : gardien d'ossements + coffre — 150 or + 3 éclats). |
| **Boutique / Inventaire** | 3 paliers d'armes/armures (jusqu'à l'**Aetherite**), vitrine progressive (seul le palier suivant est affiché), potions, éclats. |
| **Bestiaire** | Journal de l'Éther à onglets : Chroniques + Bestiaire (7 espèces, faiblesses/boucliers/lore, silhouettes tant que non croisées). |
| **Sauvegarde** | 3 slots, auto-save, cristaux d'Aether, **sync iCloud** (Key-Value Store, la save la plus récente gagne). |
| **New Game+** | Après une fin, relancer conserve niveau/or/équipement et durcit les combats (+45 % PV, +30 % dégâts par palier). Le slot terminé affiche « Nouvelle Partie + » ; les deux fins donnent une vraie raison de recommencer. |
| **Audio** | 9 musiques CC0 (village, forêt, mines, auberge, combat, boss, Seuil, titre, finale) avec cross-fade par zone + 11 SFX 8-bit CC0 (Juhani Junkala) + 5 ambiances foley CC0 (couche sous la musique). Synthèse procédurale en repli. |

---

## Architecture

```
EchoesOfAether/
├── Core/
│   ├── GameState.swift         — GameState/GamePhase, PlayerState, SaveData (Codable, rétro-compatible)
│   ├── GameManager.swift       — Coordinateur central : états, boutons A/B, hints, quêtes, zones
│   └── SaveManager.swift       — JSON sur disque + miroir iCloud KVS (résolution par horodatage)
├── Game/
│   ├── Scenes/
│   │   ├── WorldBuilder.swift       — Toutes les zones (village, forêt, sanctuaire, ruines, mines, Seuil, intérieurs)
│   │   ├── MainMenuScene.swift      — Écran-titre (art de l'icône, ciel étoilé, slots)
│   │   ├── MovementController.swift — Marche procédurale (bob + poussière)
│   │   └── TransitionManager.swift  — Fades, écrans de fin
│   └── Combat/
│       ├── CombatSprites.swift      — Sprites d'arène (Kael, alliés, ennemis, boss)
│       └── PixelFX.swift            — FX pixel des sorts (zéro glow)
├── UI/                          — HUD (ombres portées, safe areas island), Dialogue (portraits),
│                                  Shop/Inventory/Lore/QuestLog/Pause/Options (curseur + dismiss B)
├── Juice/
│   ├── JuiceEngine.swift        — screenShake, zoomPunch, flash, slowMotion, pulse…
│   ├── ParticleFactory.swift    — étincelles, brumes, fumées de cheminée, papillons, atmosphères
│   ├── HapticsEngine.swift      — CoreHaptics
│   └── AudioEngine.swift        — AVAudioEngine : musiques/SFX fichiers CC0 + synthèse en repli
├── Resources/
│   ├── Music/ (9 × .m4a CC0)  SFX/ (11 × .wav CC0)  Ambience/ (5 × .m4a CC0)
├── CombatSystem.swift           — Moteur tour par tour : alliés génériques (AllyState), crit/esquive,
│                                  curseur de menu, statuts, boss
├── PrototypeContent.swift       — Tous les dialogues (clés xcstrings FR/EN)
├── Marketing/                   — Trailer 39 s (gameplay réel + cartes titre pixel)
└── Localizable.xcstrings        — ~750 clés, FR (base) + EN. Zéro string hard-codée.
```

### Machine d'états

```
GameState:  exploration → dialogue → combat → shop → inventory → transition

GamePhase:
  wake → village → forest → shrine → complete
                                         ↓
                                       act2 → ruins → fallen → act3 (Le Seuil)
                              (+ Mines de Cendreval en zone annexe)
```

### Patterns clés

- **@MainActor** partout — SpriteKit + Swift 6 strict concurrency
- **Static factory** — `WorldNode.*()`, `CombatSprites.*()`, `ParticleFactory.*()`
- **Closure callbacks** — `DialogueSystem.start([steps]) { completion }` chaîne les scènes
- **Alliés génériques** — `CombatAllyKind` + `AllyState` : duo/trio sans dupliquer le moteur
- **Pont valeur/référence pour la save** — `PlayerState` (class, @MainActor) ↔ `SaveData` (struct Codable, champs optionnels rétro-compatibles)
- **Zéro dépendance externe** — 0 packages SPM, frameworks Apple purs

---

## Assets & licences

| Type | Source | Licence |
|------|--------|---------|
| Sprites personnages/décors | LimeZu Modern Exteriors/Interiors + tiles RPG Maker MV | achetés/inclus |
| Portraits de dialogue | têtes extraites des sprites + Kael depuis l'icône de l'app + 2 dessinés à la main (Gardien, Eran) | maison |
| Sols générés | planchers de bois, tapis, vignettes — dessinés en code (nearest, pixel net) | maison |
| Musiques (9) | cynicmusic, pauliuw, Brandon75689, Juhani Junkala, RandomMind, CodeManu, kindland, nene — OpenGameArt | **CC0** |
| SFX (11) | « 512 Sound Effects » — Juhani Junkala, OpenGameArt | **CC0** |
| Ambiances (5) | foley de zone — village/forêt/mines/désert/intérieur, OpenGameArt | **CC0** |
| Police | VT323 | OFL |

**Zéro asset généré par IA.**

---

## Localisation

**100 % localisé** — FR (base) + EN, ~750 clés. Zéro string hard-codée.
Dialogues, HUD, combat, boutique, quêtes, bestiaire, tutoriel, hints boutons (« A · Parler »).

Pour tester en anglais : `Scheme → Edit Scheme → Run → Options → App Language → English`

---

## Lancer le projet

```bash
git clone https://github.com/Andyg971/EchoesOfAether-RPG.git
cd EchoesOfAether-RPG
open EchoesOfAether/EchoesOfAether.xcodeproj
# ▶ Run sur simulateur iPhone (PAYSAGE)
```

**Prérequis :** iOS 17+ / Xcode 16+ / aucune dépendance externe
**iCloud :** activer la capability *iCloud → Key-value storage* sur l'App ID pour la sync des saves.

### Args de debug (audit visuel)

`--zone-village|forest|shrine|ruins|mines|threshold` · `--interior inn|armory|apothecary` · `--combat-test|multi|trio` · `--boss-test` · `--fx-demo` · `--overlay-test dialogue|bestiary|shop|…` · `--skip-dialogue` · `--cam-y <frac>`

---

## État actuel

| Fonctionnalité | Statut |
|----------------|--------|
| Acte I — L'Éveil (duo Kael + Lyra) | ✅ Complet |
| Acte II — La Chute (ruines, Archiviste, mines de Cendreval) | ✅ Complet |
| Acte III — Le Seuil (trio, quêtes annexes, 2 fins) | ✅ Complet |
| Contrôles classiques (joystick + A/B, curseur, zéro tactile) | ✅ Complet |
| Combat (duo/trio, crit, esquive, statuts, break, boss) | ✅ Complet |
| Musiques + SFX réels (CC0) | ✅ Complet |
| Sauvegarde 3 slots + iCloud KVS | ✅ Complet |
| Bestiaire / Lore / Quêtes / Minimap / Tutoriel | ✅ Complet |
| Menu principal (art de l'icône) / Pause / Options / Mort | ✅ Complet |
| HUD safe-areas Dynamic Island, sans plaques | ✅ Complet |
| GameCenter (auth + achievements) | ✅ Câblé |
| Localisation FR + EN | ✅ ~750 clés |
| Trailer marketing (39 s, 1920×886) | ✅ `Marketing/` |
| Frames d'animation Kael (walk/attack) | 🟡 Pack de sprites à intégrer (procédural en attendant) |
| Build App Store | 🟡 Privacy manifest + screenshots à faire |

---

## Roadmap — Ce qui reste

- [ ] **Frames walk/attack/cast de Kael** — pack de sprites acheté à intégrer (`kael_walk_1..6`…)
- [ ] **Accessibilité** — VoiceOver sur les overlays, option « réduire les animations »
- [ ] **Audit EN complet** — run intégral en anglais
- [ ] **Support iPad adaptatif** — layout non adaptatif pour l'instant
- [ ] **App Store** — privacy manifest, screenshots 6.9", page produit FR/EN, TestFlight

---

## Bundle ID

```
com.appmakerstudio.echoesofaether
```

---

*Built with [Claude Code](https://claude.ai/code)*
*"Trois voix contre le Vide. Ça me va." — Eran*
