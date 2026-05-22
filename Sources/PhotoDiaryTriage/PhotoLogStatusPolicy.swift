import Foundation

enum PhotoLogStatusPolicy {
    static let editLogActionTitle = "Edit Log"
    static let editLogHelp = "Add or remove photos from this log and change their S/C/X status. Mark source-inbox photos with S/C/X to add them; clear photos to undecided to return them to the source inbox."
    static let detailsActionTitle = "Details"
    static let detailsHelp = "Edit title, notes, date range, and scope only. This does not change which photos belong to the log."
    static let detailsSheetTitle = "Photo Log Details"
    static let detailsSheetSubtitle = "Update title, notes, and scope only. Use Edit Log in the photo log library to add or remove photos and change S/C/X status."

    static func isMembershipLocked(status: String) -> Bool {
        status == LifecycleState.imported.rawValue || status == LifecycleState.sourceCleaned.rawValue
    }

    static func membershipLockMessage(status: String) -> String? {
        switch status {
        case LifecycleState.imported.rawValue:
            return "Copied; Edit Log is locked. Continue the log to review backup and cleanup."
        case LifecycleState.sourceCleaned.rawValue:
            return "Source cleaned; Edit Log is locked."
        default:
            return nil
        }
    }

    static func editLogStatusMessage(title: String) -> String {
        "Editing log \(title). Change S/C/X status, mark more source-inbox photos with S/C/X to add them, or clear photos to undecided to return them to the source inbox."
    }
}
