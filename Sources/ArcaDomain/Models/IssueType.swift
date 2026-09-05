public enum IssueType: String, Codable, CaseIterable, Sendable {
  case antiPattern = "anti-pattern"
  case codeSmell = "code-smell"
  case unsafeCode = "unsafe-code"
  case deprecatedAPI = "deprecated-api"
  case securityWeakness = "security-weakness"
  case conventionViolation = "convention-violation"
}
