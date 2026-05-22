import Foundation

enum PhotoLogStatusPolicy {
    static func isMembershipLocked(status: String) -> Bool {
        status == LifecycleState.imported.rawValue || status == LifecycleState.sourceCleaned.rawValue
    }

    static func membershipLockMessage(status: String) -> String? {
        switch status {
        case LifecycleState.imported.rawValue:
            return "Copied; item editing is locked. Continue the log to review backup and cleanup."
        case LifecycleState.sourceCleaned.rawValue:
            return "Source cleaned; item editing is locked."
        default:
            return nil
        }
    }
}
