#!/bin/bash
# Vérifie que chaque fichier Swift du disque est bien référencé dans le projet
# Xcode — à la fois comme fichier (PBXFileReference) et comme source à compiler
# (PBXSourcesBuildPhase).
#
# Pourquoi : les fichiers de ce dépôt sont souvent ajoutés hors Xcode. Un
# fichier oublié dans project.pbxproj ne casse rien localement (le fichier
# existe, l'éditeur le montre) mais n'est jamais compilé : le code est mort, et
# un test non enregistré ne s'exécute jamais — vert en apparence, jamais joué.
#
# Usage : ./Tools_check_project_files.sh

set -uo pipefail

PROJECT="EchoesOfAether.xcodeproj/project.pbxproj"
cd "$(dirname "$0")" || exit 1

if [ ! -f "$PROJECT" ]; then
  echo "introuvable : $PROJECT" >&2
  exit 1
fi

manquants=0

while IFS= read -r fichier; do
  nom=$(basename "$fichier")

  # Xcode met le chemin entre guillemets dès qu'il contient un caractère
  # spécial — c'est le cas de toutes les extensions « GameManager+Act2.swift ».
  if ! grep -qF "path = $nom;" "$PROJECT" \
     && ! grep -qF "path = \"$nom\";" "$PROJECT"; then
    echo "✗ $fichier — absent de project.pbxproj (aucun PBXFileReference)"
    manquants=$((manquants + 1))
    continue
  fi

  if ! grep -qF "/* $nom in Sources */" "$PROJECT"; then
    echo "✗ $fichier — référencé mais jamais compilé (absent des Sources)"
    manquants=$((manquants + 1))
  fi
done < <(find EchoesOfAether EchoesOfAetherTests -name '*.swift' | sort)

if [ "$manquants" -gt 0 ]; then
  echo ""
  echo "$manquants fichier(s) Swift non pris en compte par le projet Xcode."
  echo "Ajoute-les à project.pbxproj (PBXFileReference + PBXBuildFile + groupe + Sources)."
  exit 1
fi

echo "✓ tous les fichiers Swift sont compilés par le projet"
