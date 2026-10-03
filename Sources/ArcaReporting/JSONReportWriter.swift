import ArcaDomain
import Foundation

public struct JSONReportWriter {
    public init() {}
    
    public func write(
        _ json: String,
        report: LLMIssueDetectionReport,
        resultsRoot: URL,
        timestamp: Date = Date()
    ) throws -> URL {
        let directory = resultsRoot
            .appendingPathComponent("arca-results", isDirectory: true)
            .appendingPathComponent(directoryName(for: report), isDirectory: true)
        let destination = directory.appendingPathComponent(
            fileName(for: report, timestamp: timestamp),
            isDirectory: false
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw JSONReportWritingError(destinationPath: destination.path)
        }
        
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw JSONReportWritingError(destinationPath: destination.path)
        }
        
        do {
            try Data(json.utf8).write(to: destination, options: .atomic)
            return destination
        } catch {
            throw JSONReportWritingError(destinationPath: destination.path)
        }
    }
    
    private func directoryName(for report: LLMIssueDetectionReport) -> String {
        switch report.promptVariant {
        case .baseline:
            "baseline"
        case .guided:
            "guided-analysis"
        }
    }
    
    private func fileName(
        for report: LLMIssueDetectionReport,
        timestamp: Date
    ) -> String {
        let sourceName = sanitized(
            URL(fileURLWithPath: report.filePath)
                .deletingPathExtension()
                .lastPathComponent
        )
        let reviewSuffix = report.reviewType.map {
            "-\($0.commandLineName)"
        } ?? ""
        let requestID = report.requestID.uuidString
            .prefix(8)
            .lowercased()
        return "\(sourceName)\(reviewSuffix)-\(timestampString(timestamp))-\(requestID).json"
    }
    
    private func timestampString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
    }
    
    private func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "._-")
        )
        let result = value.unicodeScalars.map {
            allowed.contains($0) ? Character(String($0)) : "-"
        }
        let name = String(result)
        return name.isEmpty ? "source" : name
    }
}

public struct JSONReportWritingError: LocalizedError, Equatable, Sendable {
    public let destinationPath: String
    
    public var errorDescription: String? {
        "ARCA could not write the JSON report to '\(destinationPath)'."
    }
    
    public init(destinationPath: String) {
        self.destinationPath = destinationPath
    }
}
