import Foundation

struct QuotaModel: Identifiable, Hashable {
    let id: String
    let name: String
    let remainingPercentage: Int?
    let resetTime: Date?
    let isExhausted: Bool

    var usedPercentage: Int? {
        remainingPercentage.map { percentage in
            min(100, max(0, 100 - percentage))
        }
    }
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

enum ServiceTab: String, CaseIterable, Identifiable, Hashable {
    case codex
    case antigravity
    case glm

    var id: String { rawValue }
}

enum IconDisplayMetric: Hashable {
    case remaining
    case used
}

enum ServicePanelState: Hashable {
    case loading
    case ready
    case needsAuth
    case empty
    case stale
    case failed(String)
}

struct ServiceQuotaWindow: Identifiable, Hashable {
    let id: String
    let title: String
    let usedPercent: Int?
    let detail: String?
    let resetText: String?
}

struct ServiceModelUsage: Identifiable, Hashable {
    let id: String
    let name: String
    let usedPercent: Int?
    let detail: String?
}

struct ServiceUsageGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let window: ServiceQuotaWindow
    let models: [ServiceModelUsage]
}

struct ServicePanelSnapshot: Hashable {
    let service: ServiceTab
    let state: ServicePanelState
    let updatedAt: Date?
    let account: String?
    let plan: String?
    let windows: [ServiceQuotaWindow]
    let groups: [ServiceUsageGroup]
    let notes: [String]
}

extension ServicePanelSnapshot {
    static func codexPlaceholder(updatedAt: Date, account: String? = nil, plan: String? = nil) -> ServicePanelSnapshot {
        ServicePanelSnapshot(
            service: .codex,
            state: .ready,
            updatedAt: updatedAt,
            account: account,
            plan: plan,
            windows: [
                ServiceQuotaWindow(
                    id: "codex-5h",
                    title: "5-hour usage",
                    usedPercent: 22,
                    detail: "1.1M / 5.0M tokens",
                    resetText: "Resets in 2h 41m"
                ),
                ServiceQuotaWindow(
                    id: "codex-weekly",
                    title: "Weekly usage",
                    usedPercent: 36,
                    detail: "9.0M / 25.0M tokens",
                    resetText: "Resets in 3d 20h"
                ),
                ServiceQuotaWindow(
                    id: "codex-review",
                    title: "Code review",
                    usedPercent: 8,
                    detail: "24 / 300",
                    resetText: "Resets in 6d 4h"
                )
            ],
            groups: [],
            notes: ["Codex API integration is in progress."]
        )
    }

    static func glmPlaceholder(updatedAt: Date, account: String? = nil, plan: String? = nil) -> ServicePanelSnapshot {
        ServicePanelSnapshot(
            service: .glm,
            state: .ready,
            updatedAt: updatedAt,
            account: account,
            plan: plan,
            windows: [
                ServiceQuotaWindow(
                    id: "glm-5h",
                    title: "5-hour quota",
                    usedPercent: 18,
                    detail: "0.9M / 5.0M tokens",
                    resetText: "Resets in 1h 10m"
                ),
                ServiceQuotaWindow(
                    id: "glm-mcp",
                    title: "MCP monthly quota",
                    usedPercent: 12,
                    detail: "120 / 1000 calls",
                    resetText: "Resets on 2026-03-01"
                )
            ],
            groups: [],
            notes: ["GLM API integration is in progress."]
        )
    }
}
