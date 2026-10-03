import ArcaDomain

public struct RuleKnowledge: Equatable, Sendable {
    public let ruleID: String
    public let reviewType: ReviewType
    public let category: String
    public let title: String
    public let problemContext: String
    public let expectedBehavior: String
    public let violationCriteria: String
    public let knowledgeFile: String
    public let supportingKnowledge: String
    public let deprecatedFromVersion: String?
    
    public init(
        ruleID: String,
        reviewType: ReviewType,
        category: String,
        title: String,
        problemContext: String,
        expectedBehavior: String,
        violationCriteria: String,
        knowledgeFile: String,
        supportingKnowledge: String,
        deprecatedFromVersion: String? = nil
    ) {
        self.ruleID = ruleID
        self.reviewType = reviewType
        self.category = category
        self.title = title
        self.problemContext = problemContext
        self.expectedBehavior = expectedBehavior
        self.violationCriteria = violationCriteria
        self.knowledgeFile = knowledgeFile
        self.supportingKnowledge = supportingKnowledge
        self.deprecatedFromVersion = deprecatedFromVersion
    }
    
}
