import CoreGraphics

/// Résolution virtuelle du jeu.
///
/// Tout `Echoes of Aether` est composé pour un paysage « iPhone » : les zones
/// mesurent des multiples de `scene.size.height` (village 2.4×, forêt 2.8×,
/// mines 3.0×…), les arènes de combat placent leurs slots en fractions de
/// `scene.size`, et le HUD s'ancre aux bords. Ce système est cohérent tant que
/// la scène garde les proportions d'un iPhone.
///
/// Sur iPad, `scaleMode = .resizeFill` donnait à la scène la taille réelle de
/// la vue (1210 × 834 pt au lieu de 852 × 393). Conséquences : Kael et les
/// décors gardaient leur taille en points sur un écran deux fois plus grand
/// (sprites minuscules, monde qui ne scrollait plus car `worldHeight` finissait
/// sous la hauteur d'écran), pendant que le HUD, lui, se mettait à l'échelle
/// via son propre facteur `min(w, h) / 390` — soit 2,14× sur iPad. Le monde
/// restait à 1× et l'interface passait à 2× : deux échelles contradictoires
/// dans la même image.
///
/// La correction tient en une idée : **la scène garde une taille virtuelle
/// proche du gabarit iPhone, et SpriteKit met TOUT à l'échelle d'un coup**
/// (`scaleMode = .aspectFill`, avec une taille virtuelle de même rapport
/// d'aspect que la vue — donc agrandissement uniforme, sans recadrage ni
/// déformation).
///
/// - Sur iPhone, le facteur vaut exactement 1 : la scène reste identique au
///   pixel près. Aucune régression possible sur l'appareil de référence.
/// - Sur iPad, le facteur vaut ~1,42 (11") à ~1,61 (13") : la largeur visible
///   reste celle de l'iPhone (la composition horizontale — panneaux de
///   dialogue, boutique, arène — est préservée), et la hauteur supplémentaire
///   du format 4:3 se traduit par « on voit plus de monde vers le haut », ce
///   qu'un RPG en vue de dessus encaisse naturellement.
enum Viewport {

    /// Gabarit de référence : iPhone 15/16/17 Pro en paysage.
    static let designWidth: CGFloat = 852
    static let designHeight: CGFloat = 393

    /// Garde-fou pour un hypothétique écran géant : au-delà, on préfère
    /// montrer plus de monde plutôt que d'agrandir indéfiniment les sprites.
    static let maxScale: CGFloat = 2.2

    /// Facteur d'agrandissement appliqué par SpriteKit à toute la scène.
    ///
    /// `min` des deux rapports (façon aspect-fit) : garantit qu'on voit au
    /// moins la zone de jeu du gabarit, et qu'on déborde sur un seul axe.
    /// Plancher à 1 : sur un écran plus petit que le gabarit (iPhone SE en
    /// paysage), on ne rétrécit pas le jeu — on garde le comportement 1:1
    /// historique.
    static func scale(for viewSize: CGSize) -> CGFloat {
        guard viewSize.width > 0, viewSize.height > 0 else { return 1 }
        let byWidth = viewSize.width / designWidth
        let byHeight = viewSize.height / designHeight
        return min(max(min(byWidth, byHeight), 1), maxScale)
    }

    /// Taille virtuelle à donner à la `SKScene` pour une vue donnée.
    ///
    /// Même rapport d'aspect que la vue (par construction : on divise les deux
    /// côtés par le même facteur), donc `.aspectFill` agrandit sans rien
    /// couper.
    static func sceneSize(for viewSize: CGSize) -> CGSize {
        guard viewSize.width > 0, viewSize.height > 0 else { return viewSize }
        let k = scale(for: viewSize)
        return CGSize(width: viewSize.width / k, height: viewSize.height / k)
    }

    /// Convertit une marge de sécurité (points de vue) en points de scène.
    ///
    /// Sans cette conversion, l'encoche et l'indicateur d'accueil seraient
    /// surcompensés d'un facteur `scale` — le HUD descendrait de 60 pt
    /// virtuels au lieu de 42 sur iPad.
    static func sceneInset(_ inset: CGFloat, for viewSize: CGSize) -> CGFloat {
        inset / scale(for: viewSize)
    }
}
