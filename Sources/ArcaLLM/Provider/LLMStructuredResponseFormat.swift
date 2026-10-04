public enum LLMStructuredResponseFormat: Equatable, Sendable {
    case codeAnalysis(requiresRuleID: Bool)
}
