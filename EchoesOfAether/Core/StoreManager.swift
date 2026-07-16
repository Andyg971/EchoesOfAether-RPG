import StoreKit

/// Achat unique « jeu complet » (StoreKit 2, zéro lib tierce).
///
/// L'Acte I est gratuit ; l'achat débloque les Actes II à IV. Aucune
/// consommable, aucune monnaie réelle : un seul produit non consommable, donc
/// restaurable à vie sur tous les appareils du joueur.
@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    /// Doit correspondre à l'identifiant créé dans App Store Connect.
    static let fullGameID = "com.appmakerstudio.echoesofaether.fullgame"

    /// Le produit `fullGameID` existe-t-il et est-il approuvé dans App Store
    /// Connect ?
    ///
    /// Tant que non : le mur d'achat s'ouvrirait sans prix ni bouton valide et
    /// le joueur resterait coincé à la fin de l'Acte I, **sans aucun moyen de
    /// payer** — les Actes II à IV existent et se terminent, mais rien ne peut
    /// y mener. On débloque donc tout par défaut, et l'on repassera ce drapeau
    /// à `true` le jour où l'achat est réellement en place.
    ///
    /// Une seule ligne à changer, aucun code de paywall supprimé.
    static let isStoreKitConfigured = false

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false

    /// Écoute des transactions signées hors de l'app (achat familial,
    /// remboursement, achat sur un autre appareil).
    private var updatesTask: Task<Void, Never>?

    private init() {}

    // MARK: - Cycle de vie

    /// À appeler une fois au lancement. Ne bloque jamais le jeu : sans réseau,
    /// `product` reste nil et le paywall affiche son état d'erreur.
    func start() async {
        // `--unlock-all` : tests et captures d'écran sans passer par l'achat.
        if CommandLine.arguments.contains("--unlock-all") {
            isUnlocked = true
            return
        }
        // Achat pas encore en place : le jeu entier est ouvert (Actes I à IV).
        // Voir `isStoreKitConfigured`.
        guard Self.isStoreKitConfigured else {
            isUnlocked = true
            return
        }
        await refreshEntitlements()
        await loadProduct()
        listenForTransactions()
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.fullGameID]).first
    }

    /// Prix localisé par l'App Store (jamais de prix écrit en dur).
    var displayPrice: String? { product?.displayPrice }

    // MARK: - Achat

    /// Retourne `true` si le jeu est débloqué à l'issue de l'achat.
    /// `.userCancelled` et `.pending` ne sont pas des erreurs : le joueur
    /// revient simplement au jeu.
    func purchase() async throws -> Bool {
        guard let product else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return isUnlocked
        case .userCancelled:
            return false
        case .pending:
            // « Demander à acheter » : l'achat arrivera via updatesTask.
            return false
        @unknown default:
            return false
        }
    }

    /// Bouton « Restaurer » — exigé par Apple pour tout produit non consommable.
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Droits

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.fullGameID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    private func listenForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        String(localized: "store.error.verification")
    }
}
