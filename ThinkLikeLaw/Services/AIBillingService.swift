import Foundation

/**
 * AIBillingService — Credit calculation and deduction logic extracted from AIService.
 * Centralizes all billing/cost logic for transparency and testability.
 */
class AIBillingService {
    static let shared = AIBillingService()

    private init() {}

    /// Calculate the credit cost for a given AI tool invocation.
    func calculateCost(tool: AIService.AITool, inputContent: String, outputContent: String, mode: String) -> Int {
        if tool == .chat {
            let chatMode = AIChatMode(rawValue: mode) ?? .fast

            // Base cost + Token-based cost
            let totalChars = inputContent.count + outputContent.count
            let estimatedTokens = Double(totalChars) / 4.0

            // Minimum costs per mode to ensure "impact" is visible
            let minBase: Double = chatMode == .planning ? 15.0 : (chatMode == .normal ? 5.0 : 2.0)
            let tokenCost = estimatedTokens / 15.0 // ~1 credit per 60 tokens

            return Int(ceil((minBase + tokenCost) * chatMode.multiplier))
        } else {
            // Fixed costs for tools based on complexity
            return fixedCost(for: tool)
        }
    }

    /// Fixed credit costs for non-chat tools.
    func fixedCost(for tool: AIService.AITool) -> Int {
        switch tool {
        case .flashcards:     return 50   // Premium generation
        case .generate_notes: return 75   // Deep research
        case .mark:           return 250  // High-fidelity Assessment
        case .verify_answer:  return 5    // Lightweight verification
        default:              return 20   // Standard tool cost
        }
    }

    /// Deduct credits via the metrics service.
    func deductCredits(amount: Int) async {
        try? await SupabaseManager.shared.deductCredits(amount: amount)
    }
}
