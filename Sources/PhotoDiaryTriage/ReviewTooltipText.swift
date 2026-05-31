enum ReviewTooltipText {
    static let gridSelection = "Click to select. Shift-click extends the selection, Command-click toggles selection, and double-click opens preview."

    static let selectShortcut = "S / Cmd-I"
    static let candidateShortcut = "C"
    static let excludeShortcut = "X / Cmd-Shift-X"
    static let clearShortcut = "D / Cmd-Shift-I"
    static let rawShortcut = "R / Cmd-Option-R"

    static let selectForImport = "Select this item for import (\(selectShortcut))"
    static let markAsCandidate = "Mark this item as a candidate (\(candidateShortcut))"
    static let excludeFromImport = "Exclude this item from import (\(excludeShortcut))"
    static let clearTriageState = "Clear this item back to undecided (\(clearShortcut))"
    static let toggleRawCompanions = "Toggle RAW companions for this item (\(rawShortcut))"
    static let includeRawCompanions = "Include RAW companions for this item (\(rawShortcut))"

    static let triageActionTooltips = [
        selectForImport,
        markAsCandidate,
        excludeFromImport,
        clearTriageState,
        toggleRawCompanions,
        includeRawCompanions
    ]
}
