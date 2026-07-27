#!/usr/bin/env python3
"""Choisit un simulateur iOS disponible et imprime son UDID.

Les noms de simulateurs changent à chaque version de Xcode (« iPhone 16 Pro »,
« iPhone 17 Pro »…) : les coder en dur dans la CI la casse à chaque mise à jour
de l'image GitHub. On demande donc à `simctl` ce qui existe réellement, et on
prend le plus récent de la famille voulue.

Usage : ./Tools_pick_simulator.py iPhone
        ./Tools_pick_simulator.py iPad
"""

import json
import re
import subprocess
import sys


def version_runtime(identifiant: str) -> tuple:
    """`…SimRuntime.iOS-26-0` → (26, 0), pour trier numériquement.

    Un tri alphabétique placerait iOS-9 après iOS-26.
    """
    nombres = re.findall(r"\d+", identifiant.rsplit(".", 1)[-1])
    return tuple(int(n) for n in nombres)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    famille = sys.argv[1]

    brut = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        capture_output=True, text=True, check=True,
    ).stdout
    appareils = json.loads(brut)["devices"]

    candidats = []
    for runtime, liste in appareils.items():
        if "iOS" not in runtime:
            continue
        for appareil in liste:
            if appareil.get("isAvailable") and appareil["name"].startswith(famille):
                candidats.append((version_runtime(runtime), appareil))

    if not candidats:
        print("aucun simulateur %s disponible" % famille, file=sys.stderr)
        return 1

    version, appareil = max(candidats, key=lambda c: c[0])
    print("%s — iOS %s" % (appareil["name"],
                           ".".join(str(n) for n in version)), file=sys.stderr)
    print(appareil["udid"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
