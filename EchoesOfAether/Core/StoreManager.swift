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

    /// Le mur d'achat est-il actif ? (L'Acte I gratuit, la suite payante.)
    ///
    /// ⚠️ Ne soumettre une version avec `true` QUE si le produit `fullGameID`
    /// existe dans App Store Connect et part en revue AVEC cette version
    /// (« Achats intégrés » de la fiche). Sans lui, le mur s'ouvrirait sans
    /// prix et le joueur resterait coincé à la fin de l'Acte I. En local, le
    /// schéma Xcode charge `EchoesOfAether.storekit` : l'achat se teste sans
    /// App Store Connect. `false` rouvre tout le jeu, sans rien supprimer.
    static let isStoreKitConfigured = true

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false
    /// Vrai dès que les droits sont connus (lus, ou jeu ouvert d'office).
    /// Avant, `isUnlocked` vaut `false` même pour un acheteur : le mur ne doit
    /// pas s'ouvrir sur cette ignorance (sauvegarde rechargée dès le lancement).
    private(set) var isReady = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    /// Écoute des transactions signées hors de l'app (achat familial,
    /// remboursement, achat sur un autre appareil).
    private var updatesTask: Task<Void, Never>?

    private init() {}

    #if DEBUG
    /// Tests uniquement : fixe l'état d'achat. Le singleton survit d'un test à
    /// l'autre — un test qui passe par `setup` (donc `start()`) le laissait
    /// « débloqué » pour toute la suite, et les tests du mur d'achat se
    /// sautaient selon l'ordre d'exécution.
    func setUnlockedForTesting(_ unlocked: Bool) {
        isUnlocked = unlocked
        markReady()
    }

    /// Tests uniquement : revient à « droits pas encore lus » (lancement).
    func setNotReadyForTesting() { isReady = false }
    #endif

    // MARK: - Cycle de vie

    /// À appeler une fois au lancement. Ne bloque jamais le jeu : sans réseau,
    /// `product` reste nil et le paywall affiche son état d'erreur.
    func start() async {
        // `--unlock-all` : tests et captures d'écran sans passer par l'achat.
        if CommandLine.arguments.contains("--unlock-all") {
            isUnlocked = true
            markReady()
            return
        }
        // Mur d'achat coupé : le jeu entier est ouvert (Actes I à IV).
        // Voir `isStoreKitConfigured`.
        guard Self.isStoreKitConfigured else {
            isUnlocked = true
            markReady()
            return
        }
        listenForTransactions()
        // Les droits d'abord (lus en cache, même hors ligne) : c'est eux que
        // le mur attend. Le prix, lui, peut arriver après.
        await refreshEntitlements()
        markReady()
        await loadProduct()
    }

    /// Attend que les droits soient connus. Retour immédiat s'ils le sont.
    func waitUntilReady() async {
        guard !isReady else { return }
        await withCheckedContinuation { readyWaiters.append($0) }
    }

    private func markReady() {
        isReady = true
        let waiters = readyWaiters
        readyWaiters.removeAll()
        waiters.forEach { $0.resume() }
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
        // Prix non chargé au lancement (hors ligne) : on retente à l'achat.
        if product == nil { await loadProduct() }
        guard let product else { throw StoreError.productUnavailable }
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
    case productUnavailable

    var errorDescription: String? {
        switch self {
        case .failedVerification: String(localized: "store.error.verification")
        case .productUnavailable: String(localized: "paywall.status.unavailable")
        }
    }
}
