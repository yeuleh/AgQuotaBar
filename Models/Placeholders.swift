import Foundation

struct QuotaModel: Identifiable, Hashable {
    let id: String
    let name: String
    let remainingPercentage: Int
}

struct Account: Identifiable, Hashable {
    let id: String
    let email: String
    let models: [QuotaModel]
}

extension Account {
    static let placeholders: [Account] = [
        Account(
            id: "acc-1",
            email: "leon@ulenium.com",
            models: [
                QuotaModel(id: "model-1", name: "Claude 3.5 Sonnet", remainingPercentage: 45),
                QuotaModel(id: "model-2", name: "Gemini 3.0 Pro", remainingPercentage: 80)
            ]
        ),
        Account(
            id: "acc-2",
            email: "demo@gmail.com",
            models: [
                QuotaModel(id: "model-3", name: "GPT-4", remainingPercentage: 10)
            ]
        )
    ]
}
