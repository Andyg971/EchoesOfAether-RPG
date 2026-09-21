import SpriteKit

// Indice d'interaction — les zones à POI en coordonnées monde : intérieurs,
// mines, désert, forêt, carte du monde. Chaque méthode renvoie l'indice
// du POI à portée (ou rien), sans toucher au HUD.
@MainActor
extension GameManager {
    /// Intérieur d'une boutique : la porte de sortie, ou le comptoir.
    func interiorHint(kaelPos: CGPoint, radius: CGFloat, in scene: SKScene) -> InteractionHint {
        var r = InteractionHint()
        guard let activeInterior else { return r }
        let exit = world.interiorExitPosition(in: scene.size)
        if kaelPos.distance(to: exit) < radius {
            r.hint = String(localized: "hint.exit")
            r.bubbleAction = .enter
            r.bubbleAnchor = CGPoint(x: exit.x, y: exit.y + 34)
            r.actionPoint = exit
        } else {
            let servicePoint = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.62)
            if kaelPos.distance(to: servicePoint) < radius {
                switch activeInterior {
                case .armory: r.hint = String(localized: "hint.interior.armory")
                case .apothecary: r.hint = String(localized: "hint.interior.apothecary")
                case .inn: r.hint = String(localized: "hint.interior.inn")
                }
                r.bubbleAction = activeInterior == .inn ? .talk : .shop
                r.bubbleAnchor = CGPoint(x: servicePoint.x, y: servicePoint.y + 42)
                r.actionPoint = servicePoint
            }
        }
        return r
    }

    /// POI des mines : plaque, veine, sortie — en coordonnées MONDE via MinesPOI.
    func minesHint(kaelPos: CGPoint, radius: CGFloat, in scene: SKScene) -> InteractionHint {
        var r = InteractionHint()
        // POI des mines : plaque, veine, sortie — en coordonnées MONDE
        // via MinesPOI (la descente scrolle sur 2,5 écrans). Les combats
        // n'ont plus de hint : ils partent au contact des rôdeurs.
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        var checkpoints: [(CGPoint, String)] = [
            (MinesPOI.plaque.scaled(w: w, h: h), "hint.examine"),
            (CGPoint(x: w * 0.50, y: h * MinesPOI.exitY), "hint.exit")
        ]
        if !player.minesGoldTaken {
            checkpoints.append((MinesPOI.goldVein.scaled(w: w, h: h), "hint.examine"))
        }
        if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
        }
        return r
    }

    /// POI du désert : PNJ, coffre, oasis, sortie — via `DesertPOI`.
    func desertHint(kaelPos: CGPoint, radius: CGFloat, in scene: SKScene) -> InteractionHint {
        var r = InteractionHint()
        // POI du désert : PNJ, coffre, oasis, sortie. En coordonnées
        // MONDE et par `DesertPOI` : ces points dataient du désert à un
        // écran — depuis qu'Ossara scrolle sur trois, le coffre et
        // l'oasis s'allumaient à un tiers de leur sprite. Les combats
        // n'ont plus de hint : ils partent au contact des rôdeurs.
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        var checkpoints: [(CGPoint, String)] = [
            (CGPoint(x: w * 0.50, y: h * DesertPOI.exitY), "hint.exit"),
            (DesertPOI.npcCaravanier.scaled(w: w, h: h), "hint.talk"),
            (DesertPOI.npcMerchant.scaled(w: w, h: h), "hint.talk"),
            (DesertPOI.npcChild.scaled(w: w, h: h), "hint.talk")
        ]
        if !player.desertChestTaken {
            checkpoints.append((CGPoint(x: w * 0.10, y: h * DesertPOI.chestY),
                                "hint.examine"))
        }
        if !player.desertOasisUsed {
            checkpoints.append((DesertPOI.oasis.scaled(w: w, h: h), "hint.examine"))
        }
        if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
        }
        return r
    }

    /// Forêt revisitée depuis la carte : mêmes POI qu'en Acte I, sans le seuil du sanctuaire.
    func forestHint(kaelPos: CGPoint, radius: CGFloat, in scene: SKScene) -> InteractionHint {
        var r = InteractionHint()
        // Revisite de la forêt depuis la carte (Acte II+) : mêmes POI
        // qu'en Acte I, sauf le seuil du sanctuaire — cf. le garde
        // `!inForest` de tryForestInteraction, ce bouton ne fait plus
        // rien ici, donc pas de bulle « Entrer » trompeuse.
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let checkpoints: [(CGPoint, String)] = [
            (CGPoint(x: w*0.88, y: h*0.30), "hint.enter")   // Mines de Cendreval
        ]
        if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
        }
        return r
    }

    /// Carte du monde : lieu ouvert, spot de pêche, trésor à l'écart. Met à jour `overworldTarget`, `fishingSpotInRange`, `overworldChestTarget`.
    func overworldHint(kaelPos: CGPoint, radius: CGFloat, in scene: SKScene) -> InteractionHint {
        var r = InteractionHint()
        // Carte du monde : à l'approche d'un lieu OUVERT, « A · Entrer … ».
        // Les lieux verrouillés par l'histoire ne proposent rien (anti-saut).
        overworldTarget = nil
        var best: (dist: CGFloat, place: (id: String, pos: CGPoint, title: String))?
        for place in world.overworldPlaces where placeDiscovered(place.id) {
            let d = kaelPos.distance(to: place.pos)
            if d < 130, best == nil || d < best!.dist { best = (d, place) }
        }
        if let hit = best {
            r.hint = String(localized: "hint.enterPlace \(hit.place.title)")
            r.bubbleAction = .enter
            r.bubbleAnchor = CGPoint(x: hit.place.pos.x, y: hit.place.pos.y + 62)
            r.actionPoint = hit.place.pos
            overworldTarget = hit.place.id
        }
        // Bord du lac : « A · Pêcher » (mini-jeu d'adresse au calme).
        fishingSpotInRange = false
        let shore = WorldBuilder.overworldFishingSpot(
            w: world.worldWidth > 0 ? world.worldWidth : scene.size.width,
            h: world.worldHeight > 0 ? world.worldHeight : scene.size.height)
        if kaelPos.distance(to: shore) < 96 {
            r.hint = localizedHint("hint.fish")
            r.bubbleAction = .examine
            r.bubbleAnchor = CGPoint(x: shore.x, y: shore.y + 44)
            r.actionPoint = shore
            overworldTarget = nil
            fishingSpotInRange = true
        }
        // Trésor à l'écart des chemins : prioritaire s'il est plus près
        // que le lieu voisin (on ne rate pas un coffre à côté d'une porte).
        overworldChestTarget = nil
        let w = world.worldWidth > 0 ? world.worldWidth : scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        for chest in WorldBuilder.overworldChests
        where !player.overworldChestsTaken.contains(chest.id) {
            let pos = CGPoint(x: w * chest.at.x, y: h * chest.at.y)
            let d = kaelPos.distance(to: pos)
            guard d < 70, best == nil || d < best!.dist else { continue }
            r.hint = localizedHint("hint.examine")
            r.bubbleAction = .examine
            r.bubbleAnchor = CGPoint(x: pos.x, y: pos.y + 46)
            r.actionPoint = pos
            overworldTarget = nil
            overworldChestTarget = chest.id
        }
        return r
    }
}
