import SpriteKit

// Intérieurs — l'aménagement de chaque boutique : armurerie, apothicaire, auberge.
extension WorldBuilder {
    func buildArmoryInterior(in scene: SKScene, room: CGRect) {
        // ── FOND : long comptoir + Bram derrière ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX - 44, y: room.maxY - 66), scale: 0.30)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX + 44, y: room.maxY - 66), scale: 0.30)
        addShopkeeper("npc_bram", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 52))

        // ── FORGE (droite) : un vrai âtre de brique adossé au mur, pas un
        // feu de camp posé sur le plancher d'une maison. Marmite et billot
        // restent, ils font le poste de travail.
        addCozyPiece("cz_hearth_brick_lit", in: scene,
                     at: CGPoint(x: room.maxX - 56, y: room.maxY - 96), height: 58)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.maxX - 96, y: room.maxY - 70), scale: 0.40)
        addInteriorSprite("me_cut_wood_bench", in: scene, at: CGPoint(x: room.maxX - 56, y: room.maxY - 128), scale: 0.42)

        // ── RÂTELIER À BOIS (gauche) : réserve de la forge ──
        addInteriorSprite("me_cut_wood", in: scene, at: CGPoint(x: room.minX + 46, y: room.maxY - 72), scale: 0.44)
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 78, y: room.maxY - 76), scale: 0.44)
        addInteriorSprite("me_cut_wood", in: scene, at: CGPoint(x: room.minX + 46, y: room.maxY - 104), scale: 0.40)

        // ── STOCK : tonneaux et caisses alignés sur les murs ──
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.minX + 40, y: room.midY + 6), scale: 0.42)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.minX + 40, y: room.midY - 28), scale: 0.42)
        addInteriorSprite("village_crate_1", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 62), scale: 0.40)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 40, y: room.midY - 4), scale: 0.42)
        addInteriorSprite("me_barrel_4", in: scene, at: CGPoint(x: room.maxX - 40, y: room.midY - 38), scale: 0.42)
        addInteriorSprite("village_crate_2", in: scene, at: CGPoint(x: room.maxX - 42, y: room.midY - 70), scale: 0.40)

        // ── ÉTABLI sur le tapis central, avec de quoi s'asseoir pour ferrer ──
        addInteriorSprite("interior_bench_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 34), scale: 0.60)
        addInteriorSprite("me_basket_2", in: scene, at: CGPoint(x: room.midX + 52, y: room.midY - 40), scale: 0.38)
        addCozyPiece("cz_stool", in: scene,
                     at: CGPoint(x: room.midX - 46, y: room.midY - 44), height: 16)
        // Armoire à outils contre le mur du fond, entre le râtelier et le comptoir
        addCozyPiece("cz_cupboard", in: scene,
                     at: CGPoint(x: room.minX + 116, y: room.maxY - 96), height: 48)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 96), text: String(localized: "interior.armory.forge"))
    }

    func buildApothecaryInterior(in scene: SKScene, room: CGRect) {
        // ── FOND : comptoir + étagère de fioles (rangée de vases) ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX - 30, y: room.maxY - 66), scale: 0.28)
        addShopkeeper("npc_mara", in: scene, at: CGPoint(x: room.midX - 30, y: room.maxY - 52))
        addInteriorSprite("me_vase_red", in: scene, at: CGPoint(x: room.midX + 44, y: room.maxY - 62), scale: 0.40)
        addInteriorSprite("me_vase_yellow", in: scene, at: CGPoint(x: room.midX + 70, y: room.maxY - 64), scale: 0.40)
        addInteriorSprite("me_vase_pink", in: scene, at: CGPoint(x: room.midX + 96, y: room.maxY - 62), scale: 0.40)
        addInteriorSprite("me_vase_sunflower", in: scene, at: CGPoint(x: room.midX + 122, y: room.maxY - 64), scale: 0.40)

        // ── SERRE (gauche) : plantes en pots et pousses ──
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.minX + 42, y: room.maxY - 72), scale: 0.44)
        addInteriorSprite("me_big_sprout_4", in: scene, at: CGPoint(x: room.minX + 74, y: room.maxY - 78), scale: 0.42)
        addInteriorSprite("me_big_sprout_5", in: scene, at: CGPoint(x: room.minX + 44, y: room.maxY - 108), scale: 0.42)
        addInteriorSprite("me_big_sprout_6", in: scene, at: CGPoint(x: room.minX + 76, y: room.maxY - 112), scale: 0.40)
        addInteriorSprite("me_vase_sunflower", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 6), scale: 0.42)

        // ── CULTURE : champignons et paniers le long du mur droit ──
        addInteriorSprite("me_mushrooms_1", in: scene, at: CGPoint(x: room.maxX - 44, y: room.midY + 8), scale: 0.42)
        addInteriorSprite("me_mushrooms_2", in: scene, at: CGPoint(x: room.maxX - 44, y: room.midY - 24), scale: 0.42)
        addInteriorSprite("me_basket", in: scene, at: CGPoint(x: room.maxX - 46, y: room.midY - 56), scale: 0.42)
        addInteriorSprite("me_apples", in: scene, at: CGPoint(x: room.maxX - 44, y: room.midY - 84), scale: 0.38)

        // ── TABLE D'ALCHIMIE sur le tapis ──
        addInteriorSprite("interior_potion_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 30), scale: 0.48)
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.midX - 58, y: room.midY - 40), scale: 0.40, flipped: true)

        // ── COIN DE CONSULTATION : on vient chez Mara pour être soigné, il
        // faut donc un endroit où s'asseoir. Âtre éteint : elle fait sécher
        // ses simples au-dessus, pas de flambée en plein cabinet d'herbes.
        addCozyPiece("cz_hearth_stone", in: scene,
                     at: CGPoint(x: room.minX + 118, y: room.maxY - 96), height: 54)
        addCozyPiece("cz_settle_blanket", in: scene,
                     at: CGPoint(x: room.midX + 74, y: room.midY - 44), height: 32)
        addCozyPiece("cz_table_round", in: scene,
                     at: CGPoint(x: room.midX + 118, y: room.midY - 40), height: 28)
        addCozyPiece("cz_chair_3", in: scene,
                     at: CGPoint(x: room.midX + 150, y: room.midY - 46), height: 30, flipped: true)
        // Armoire à simples, alignée sur la serre
        addCozyPiece("cz_dresser", in: scene,
                     at: CGPoint(x: room.minX + 42, y: room.midY - 72), height: 46)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 96), text: String(localized: "interior.apothecary.potions"))
    }

    func buildInnInterior(in scene: SKScene, room: CGRect) {
        // ── BAR (fond droit) : comptoir en L + tonneaux ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 70, y: room.maxY - 66), scale: 0.30)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 150, y: room.maxY - 66), scale: 0.30)
        addShopkeeper("npc_sage", in: scene, at: CGPoint(x: room.maxX - 110, y: room.maxY - 52))
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.maxX - 44, y: room.maxY - 96), scale: 0.40)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.maxX - 44, y: room.maxY - 126), scale: 0.40)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 76, y: room.maxY - 100), scale: 0.38)

        // ── ÂTRE (fond gauche) : la grande cheminée de la salle commune,
        // et devant elle deux fauteuils autour d'une table basse. C'est ce
        // coin-là qui fait une auberge plutôt qu'une salle à manger — un feu
        // de camp posé sur un plancher n'y suffisait pas.
        addCozyPiece("cz_hearth_stone_lit", in: scene,
                     at: CGPoint(x: room.minX + 54, y: room.maxY - 96), height: 60)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.minX + 92, y: room.maxY - 72), scale: 0.42)
        addCozyPiece("cz_armchair_linen", in: scene,
                     at: CGPoint(x: room.minX + 32, y: room.maxY - 150), height: 40)
        addCozyPiece("cz_armchair_ash", in: scene,
                     at: CGPoint(x: room.minX + 104, y: room.maxY - 150), height: 40, flipped: true)
        addCozyPiece("cz_table_low", in: scene,
                     at: CGPoint(x: room.minX + 68, y: room.maxY - 156), height: 16)
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 128, y: room.maxY - 104), scale: 0.38)

        // ── SALLE : deux tablées dressées, chaises dépareillées (une auberge
        // n'achète pas son mobilier en série) ──
        addCozyPiece("cz_table_long", in: scene,
                     at: CGPoint(x: room.midX - 30, y: room.midY - 20), height: 32)
        addCozyPiece("cz_chair_1", in: scene,
                     at: CGPoint(x: room.midX - 74, y: room.midY - 26), height: 30)
        addCozyPiece("cz_chair_2", in: scene,
                     at: CGPoint(x: room.midX + 14, y: room.midY - 26), height: 30, flipped: true)
        addCozyPiece("cz_table_long", in: scene,
                     at: CGPoint(x: room.midX + 84, y: room.midY + 10), height: 32)
        addCozyPiece("cz_chair_4", in: scene,
                     at: CGPoint(x: room.midX + 40, y: room.midY + 4), height: 30)
        addCozyPiece("cz_chair_6", in: scene,
                     at: CGPoint(x: room.midX + 128, y: room.midY + 4), height: 30, flipped: true)
        addInteriorSprite("me_basket", in: scene, at: CGPoint(x: room.midX - 30, y: room.midY + 16), scale: 0.36)

        // ── COIN NUIT (bas gauche) : les lits DESCENDENT sous le coin du feu.
        // Ils partageaient sa hauteur et les fauteuils leur poussaient dessus.
        // Le banc de voyageur disparaît : les fauteuils le remplacent.
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 46, y: room.minY + 96), scale: 0.32)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 46, y: room.minY + 52), scale: 0.32)

        // ── BUFFET derrière le bar : vaisselle et réserve du jour ──
        addCozyPiece("cz_sideboard", in: scene,
                     at: CGPoint(x: room.maxX - 172, y: room.maxY - 100), height: 32)

        // ── CUVE DE BAIN, au coin nuit : on se lave avant de dormir. Seul
        // morceau retenu du lot salle de bain, et repeint en bois — la
        // baignoire acrylique à mitigeur chromé n'avait rien à faire ici.
        addCozyPiece("cz_bathtub_wood", in: scene,
                     at: CGPoint(x: room.minX + 132, y: room.minY + 60), height: 30)

        addServiceMarker(in: scene, at: CGPoint(x: room.maxX - 110, y: room.maxY - 96), text: String(localized: "interior.inn.rest"))
    }

    func addServiceMarker(in scene: SKScene, at position: CGPoint, text: String) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.96, green: 0.84, blue: 0.52, alpha: 0.9)
        label.horizontalAlignmentMode = .center
        label.position = position
        label.zPosition = 60   // libellé flottant : lisible au-dessus du monde
        add(label, to: scene)
        JuiceEngine.float(label, distance: 3)
    }
}
