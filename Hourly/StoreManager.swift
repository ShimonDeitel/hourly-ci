import StoreKit
import Foundation

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let proID = "hourly_pro_monthly"

    @Published var isPro = false

    init() {
        Task { await refresh() }
        Task {
            for await update in Transaction.updates {
                if case .verified(let t) = update {
                    await t.finish()
                    await refresh()
                }
            }
        }
    }

    func refresh() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.proID {
                pro = true
            }
        }
        isPro = pro
    }

    func purchase() async {
        guard let product = try? await Product.products(for: [Self.proID]).first else { return }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result, case .verified(let t) = verification {
            await t.finish()
            await refresh()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
