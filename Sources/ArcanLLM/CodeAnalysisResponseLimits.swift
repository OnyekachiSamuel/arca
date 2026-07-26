public struct CodeAnalysisResponseLimits: Equatable, Sendable {
    public let maximumResponseUTF8Bytes: Int
    public let maximumFindingCount: Int
    public let maximumEvidenceCountPerFinding: Int
    public let maximumExplanationUTF8Bytes: Int
    public let maximumEvidenceDescriptionUTF8Bytes: Int
    public let maximumEvidenceExcerptUTF8Bytes: Int

    public init(
        maximumResponseUTF8Bytes: Int = 64_000,
        maximumFindingCount: Int = 100,
        maximumEvidenceCountPerFinding: Int = 20,
        maximumExplanationUTF8Bytes: Int = 2_000,
        maximumEvidenceDescriptionUTF8Bytes: Int = 1_000,
        maximumEvidenceExcerptUTF8Bytes: Int = 8_000
    ) {
        self.maximumResponseUTF8Bytes = maximumResponseUTF8Bytes
        self.maximumFindingCount = maximumFindingCount
        self.maximumEvidenceCountPerFinding = maximumEvidenceCountPerFinding
        self.maximumExplanationUTF8Bytes = maximumExplanationUTF8Bytes
        self.maximumEvidenceDescriptionUTF8Bytes = maximumEvidenceDescriptionUTF8Bytes
        self.maximumEvidenceExcerptUTF8Bytes = maximumEvidenceExcerptUTF8Bytes
    }

    public static let `default` = CodeAnalysisResponseLimits()

    var isValid: Bool {
        maximumResponseUTF8Bytes > 0
            && maximumFindingCount > 0
            && maximumEvidenceCountPerFinding > 0
            && maximumExplanationUTF8Bytes > 0
            && maximumEvidenceDescriptionUTF8Bytes > 0
            && maximumEvidenceExcerptUTF8Bytes > 0
    }
}
