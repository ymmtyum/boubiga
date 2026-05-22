//
//  EntitlementManager.swift
//  boubiga
//
//  Created by Codex on 2026/05/22.
//

import Foundation
import Combine
import StoreKit

@MainActor
final class EntitlementManager: ObservableObject {
    @Published private(set) var isPro = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var latestErrorMessage: String?

    let proProductID = "boubiga_pro_lifetime"

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [proProductID])
            latestErrorMessage = products.isEmpty ? "Pro商品の設定を確認してください。" : nil
        } catch {
            latestErrorMessage = "Pro商品の読み込みに失敗しました。"
        }

        await refreshEntitlements()
    }

    func purchasePro() async {
        guard let product = products.first(where: { $0.id == proProductID }) else {
            latestErrorMessage = "Pro商品がまだ読み込まれていません。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                _ = try checkVerified(verification)
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            latestErrorMessage = "購入処理に失敗しました。"
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
        } catch {
            latestErrorMessage = "購入の復元に失敗しました。"
        }
    }

    func refreshEntitlements() async {
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == proProductID {
                hasPro = true
            }
        }

        isPro = hasPro
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        }
    }
}
