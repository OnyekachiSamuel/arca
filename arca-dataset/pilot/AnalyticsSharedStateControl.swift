import Foundation
internal import SnowplowTracker

open class Analytics {
    private static let shouldUseMicroInstanceKey = "shouldUseMicroInstance"

    public static var shouldUseMicroInstance: Bool {
        get {
            UserDefaults.standard.bool(forKey: shouldUseMicroInstanceKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: shouldUseMicroInstanceKey)
            Analytics.updateTrackerController()
        }
    }

    public static var shared = Analytics()
    private var tracker: TrackerController
    private let notificationCenter: AnalyticsUserNotificationCenterProtocol

    internal init(
        notificationCenter: AnalyticsUserNotificationCenterProtocol = AnalyticsUserNotificationCenterWrapper()
    ) {
        tracker = Self.makeTracker()
        tracker.installAutotracking = true
        tracker.screenViewAutotracking = false
        tracker.lifecycleAutotracking = false
        tracker.screenEngagementAutotracking = false
        tracker.exceptionAutotracking = false
        tracker.diagnosticAutotracking = false
        self.notificationCenter = notificationCenter
    }

    private static func updateTrackerController() {
        Analytics.shared.tracker = makeTracker()
    }
}
