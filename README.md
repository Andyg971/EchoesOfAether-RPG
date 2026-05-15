# Echoes of Aether — V1 iOS Prototype

Prototype iOS SpriteKit gratuit, sans assets externes.

## Contenu jouable

- Exploration tactile en portrait.
- Dialogue d'ouverture avec Lyra.
- Choix de réponse pour incarner Kael : silence, froideur, pragmatisme.
- Rencontre avec Dorin.
- Combat ATB simplifié.
- Action signature de Kael : Entaille noire.
- Jauge narrative : Résonance noire.
- Deux combats prototype : Bête corrompue et Gardien fêlé.
- Fin V1 qui amorce la trahison de Kael.

## Ouvrir dans Xcode

Ouvre le projet :

```sh
open EchoesOfAether.xcodeproj
```

Scheme :

```text
EchoesOfAether
```

Bundle id :

```text
com.appmakerstudio.echoesofaether
```

## Build terminal

```sh
xcodebuild -project EchoesOfAether.xcodeproj \
  -scheme EchoesOfAether \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath DerivedData \
  build
```

## Direction technique

La V1 utilise UIKit + SpriteKit volontairement :

- UIKit garde le bootstrap iOS simple.
- SpriteKit gère la boucle de jeu, les nodes, les touches et les overlays.
- Les assets sont des formes temporaires pour tester le gameplay avant d'acheter ou d'intégrer des packs.

## Prochaine passe

- Ajouter de vrais contrôles de déplacement, joystick ou tap-to-move plus lisible.
- Séparer exploration, dialogue et combat en scènes/états plus stricts.
- Ajouter feedback visuel sur l'ATB et l'Entaille noire.
- Ajouter une mini-map de Solis et une vraie transition forêt.
- Ajouter sauvegarde locale de progression prototype.

