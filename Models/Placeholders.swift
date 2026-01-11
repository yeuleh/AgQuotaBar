import Foundation

struct QuotaModel: Identifiable, Hashable {
    let id: String
    let name: String
    let remainingPercentage: Int?
    let resetTime: Date?
    let isExhausted: Bool
}

struct Account: Identifiable, Hashable {
    let id: String
    let email: String
    let models: [QuotaModel]
}

struct QuotaSnapshot: Hashable {
    let timestamp: Date
    let models: [QuotaModel]
    let userEmail: String?
    let planName: String?
    let isStale: Bool
}

extension Account {
    static let placeholders: [Account] = [
        Account(
            id: "acc-1",
            email: "leon@ulenium.com",
            models: [
                QuotaModel(id: "model-1", name: "Claude 3.5 Sonnet", remainingPercentage: 45, resetTime: nil, isExhausted: false),
                QuotaModel(id: "model-2", name: "Gemini 3.0 Pro", remainingPercentage: 80, resetTime: nil, isExhausted: false)
            ]
        ),
        Account(
            id: "acc-2",
            email: "demo@gmail.com",
            models: [
                QuotaModel(id: "model-3", name: "GPT-4", remainingPercentage: 10, resetTime: nil, isExhausted: false)
            ]
        )
    ]
}
