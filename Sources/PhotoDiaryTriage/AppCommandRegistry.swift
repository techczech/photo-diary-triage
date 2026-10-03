import AppKit
import Foundation
import SwiftUI

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int
    static let shift = Self(rawValue: 1), command = Self(rawValue: 2), option = Self(rawValue: 4), control = Self(rawValue: 8)
    init(rawValue: Int) { self.rawValue = rawValue }
    init(_ native: NSEvent.ModifierFlags) {
        var value = Self([])
        if native.contains(.shift) { value.insert(.shift) }; if native.contains(.command) { value.insert(.command) }
        if native.contains(.option) { value.insert(.option) }; if native.contains(.control) { value.insert(.control) }
        self = value
    }
    var swiftUI: EventModifiers {
        var value: EventModifiers = []
        if contains(.shift) { value.insert(.shift) }; if contains(.command) { value.insert(.command) }
        if contains(.option) { value.insert(.option) }; if contains(.control) { value.insert(.control) }
        return value
    }
}

struct AppShortcut: Codable, Hashable, Sendable {
    let key: String
    let modifiers: ShortcutModifiers
    init(key: String, modifiers: ShortcutModifiers = []) { self.key = key.lowercased(); self.modifiers = modifiers }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(key: try container.decode(String.self, forKey: .key), modifiers: try container.decode(ShortcutModifiers.self, forKey: .modifiers))
    }
    private enum CodingKeys: String, CodingKey { case key, modifiers }
    init?(event: NSEvent) {
        let special: [UInt16: String] = [123:"left",124:"right",125:"down",126:"up",36:"return",76:"return",53:"escape",49:"space"]
        let modifiers = ShortcutModifiers(event.modifierFlags)
        if let key = special[event.keyCode] { self.init(key: key, modifiers: modifiers); return }
        guard var key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1 else { return nil }
        if modifiers.contains(.shift) {
            let shifted = ["+":"=", "_":"-", "?":"/", "<":",", ">":".", "{":"[", "}":"]", "!":"1", "@":"2", "#":"3", "$":"4", "%":"5", "^":"6", "&":"7", "*":"8", "(":"9", ")":"0"]
            key = shifted[key] ?? key
        }
        self.init(key: key, modifiers: modifiers)
    }
    var display: String {
        let keys = ["left":"←", "right":"→", "up":"↑", "down":"↓", "return":"↩", "escape":"Esc", "space":"Space"]
        return (modifiers.contains(.control) ? "⌃" : "") + (modifiers.contains(.option) ? "⌥" : "")
            + (modifiers.contains(.shift) ? "⇧" : "") + (modifiers.contains(.command) ? "⌘" : "") + (keys[key] ?? key.uppercased())
    }
    var menuKey: KeyEquivalent {
        let keys = ["left":"\u{f702}", "right":"\u{f703}", "up":"\u{f700}", "down":"\u{f701}", "return":"\r", "escape":"\u{1b}", "space":" "]
        return KeyEquivalent(Character(keys[key] ?? key))
    }
    var isValid: Bool {
        let arrows = ["left", "right", "up", "down"]
        guard modifiers.rawValue >= 0, modifiers.rawValue <= 15, modifiers.rawValue != 15,
              key.count == 1 || arrows.contains(key) || ["return","escape","space"].contains(key), !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) }) else { return false }
        // OS navigation and the native text-system Command-arrow family stay unclaimed.
        if arrows.contains(key), modifiers.contains(.control) && !modifiers.contains(.command) { return false }
        if arrows.contains(key), modifiers == [.command] || modifiers == [.command, .shift] { return false }
        return true
    }
}

struct AppShortcutOverride: Codable, Hashable, Sendable {
    // Dictionary absence means default; a present nil means explicitly unbound.
    var shortcut: AppShortcut?
}

enum AppCommandScope: String, CaseIterable, Hashable, Sendable {
    case main, settings, editor, review, preview, compare, archiveCards, archiveSidebar, sourceSidebar, commandPanel, helpPanel, shortcutCapture, form, formEditor, information, settingsEditor
    case compareItem, sessionWorkflow, reviewItem, reviewGroup, inspectorPhoto, cropVersion
    case logDetails, logDetailsEditor, location, locationEditor, tripLabel, tripLabelEditor, photoLogActions, walkProposal, walkProposalEditor, googleJob, googleJobEditor, googleAlbum, googleAlbumEditor, googleAccount, googleAccountEditor

    var isTextEditing: Bool {
        [.editor, .settingsEditor, .formEditor, .logDetailsEditor, .locationEditor, .tripLabelEditor, .walkProposalEditor, .googleJobEditor, .googleAlbumEditor, .googleAccountEditor].contains(self)
    }
    var textEditingScope: Self {
        if isTextEditing { return self }
        return switch self {
        case .form: .formEditor
        case .settings: .settingsEditor
        case .logDetails: .logDetailsEditor
        case .location: .locationEditor
        case .tripLabel: .tripLabelEditor
        case .walkProposal: .walkProposalEditor
        case .googleJob: .googleJobEditor
        case .googleAlbum: .googleAlbumEditor
        case .googleAccount: .googleAccountEditor
        case .information: .information
        default: .editor
        }
    }
    var coactiveAncestors: Set<Self> {
        switch self {
        case .compareItem: [.compare]
        case .reviewItem, .reviewGroup: [.review]
        case .walkProposal: [.form]
        case .walkProposalEditor: [.formEditor]
        case .googleJob: [.information]
        case .googleJobEditor: [.information]
        case .googleAlbum: [.googleJob, .information]
        case .googleAlbumEditor: [.googleJobEditor, .information]
        default: []
        }
    }
}

struct AppCommandBinding: Hashable, Sendable {
    let shortcut: AppShortcut
    let scopes: Set<AppCommandScope>
    init(_ shortcut: AppShortcut, scopes: Set<AppCommandScope>) { self.shortcut = shortcut; self.scopes = scopes }
}

enum AppCommandID: String, CaseIterable, Codable, Hashable, Sendable {
    case chooseSource
    case chooseDefaultSourceRoot
    case chooseArchiveRoot
    case migrateLayout
    case backfillThumbnails
    case rebuildIndex
    case exportBackup
    case importBackup
    case timeline
    case contactSheet
    case searchArchive
    case openArchive
    case organiseFolder
    case prepareThumbnails
    case toggleCovers
    case refreshArchive
    case cancelBackfill
    case focusSidebar
    case focusReview
    case toggleInspector
    case flatReview
    case groupedReview
    case gridLayout
    case listLayout
    case filterAll
    case filterIncluded
    case filterCandidate
    case filterExcluded
    case filterUndecided
    case filterCropped
    case groupDays
    case groupDaysBursts
    case groupDaysClusters
    case groupDaysClustersBursts
    case expandAll
    case collapseAll
    case previousGroup
    case nextGroup
    case expandGroup
    case collapseGroup
    case markIncluded
    case markExcluded
    case markCandidate
    case clearTriage
    case toggleRAW
    case createPhotoLog
    case newPhotoLog
    case compare
    case open
    case openFocusedPhoto, clearArchiveFilters, deselectReviewPhotos, toggleReviewMap
    case includeDisplayedRAW, excludeDisplayedRAW, retryDisplayedThumbnail, compareDisplayedGroup, toggleDisplayedGroup, focusDisplayedGroup, showCropVersion
    case viewOriginal
    case goUp
    case deselectAll
    case copyIncluded
    case openDestination
    case moveWalk
    case confirmBackup
    case cleanupSource
    case toggleSidebar
    case selectAll
    case find
    case settings
    case palette
    case contextActions
    case keyboardHelp
    case rebindCommand
    case describeSelection
    case regenerateDescriptions
    case describeTrip
    case describeYear
    case descriptionQueue
    case resumeDescriptions
    case cancelDescriptions
    case discardDescriptions
    case deliverTrip
    case deliverPhotoLog
    case markPreviousUpload
    case clearPreviousUpload
    case googleQueue
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case extendLeft
    case extendRight
    case extendUp
    case extendDown
    case toggleSelection
    case activateFocused
    case closeSurface
    case zoomIn
    case zoomOut
    case zoomReset
    case cropVisible
    case panLeft
    case panDown
    case panUp
    case panRight
    case removeCompareItem
    case sidebarPrevious
    case sidebarNext
    case sidebarApply
    case palettePrevious
    case paletteNext
    case paletteRun
    case closeCommandPanel
    case cancelShortcutCapture
    case confirmSheet
    case confirmAndOpenSheet
    case closeSheet
    case confirmGoogleDelivery
    case resumeGoogleDelivery
    case cancelGoogleDelivery
    case chooseHistoricalSource
    case openDefaultSource
    case reloadSource
    case importSyncedPhotoLogs
    case refreshDescriptionModels
    case showCamera
    case showPhotoLogs
    case showArchive
    case showArchiveMap
    case retryArchiveSearch
    case retryArchiveFolderLoad
    case openSelectedFolderInFinder
    case toggleHistoricalDateSource
    case chooseOneDrivePictures
    case useArchiveForOneDrivePictures
    case saveLogDetails, saveLogAndStartNext
    case openPhotoLog, showPhotoLogContents, editPhotoLogDetails, editPhotoLogMembership, addMarkedToPhotoLog, deletePhotoLog
    case saveLocation, clearLocation, retryLocationSave, pinLocationAtMapCentre
    case editTripLabel, saveTripLabel, useWalkLocations, cancelTripLabelEdit
    case mergeWalkProposal, splitWalkProposal
    case connectGoogleAccount, cancelGoogleSignIn, disconnectGoogleAccount, refreshGoogleAccount, saveGoogleClientSecret
    case findGoogleAlbum, adoptGoogleAlbum, reviewGoogleAlbumAbsent, abandonGoogleJob
    case previousPreviewPhoto, nextPreviewPhoto, closeImageSurface, saveManualCrop, cancelManualCrop
    case toggleManualCrop, toggleComparePanLock, fewerCompareColumns, moreCompareColumns, resetCompareColumns
    case openLinkedPhoto, includeDisplayedPhoto, excludeDisplayedPhoto, candidateDisplayedPhoto
    case clearDisplayedPhotoTriage, toggleDisplayedPhotoRAW, cropDisplayedPhoto, removeDisplayedComparePhoto, downloadDisplayedOriginal
}

@MainActor
struct AppCommandDefinition: Identifiable {
    let id: AppCommandID
    let title: String
    let task: String
    let scopes: Set<AppCommandScope>
    let defaults: [AppCommandBinding]
    let enabled: (AppState) -> Bool
    let run: (AppState) -> Void
    var needsSurfaceHandler: Bool = false
    var commitsDraft: Bool = false
}

@MainActor
struct AppCommandRegistry {
    static let mainScopes: Set<AppCommandScope> = [.main, .review, .archiveCards, .archiveSidebar, .sourceSidebar]
    static let sessionWorkflowIDs: Set<AppCommandID> = [.newPhotoLog, .copyIncluded, .openDestination, .confirmBackup, .cleanupSource]
    static let sessionWorkflowScopes = mainScopes.union([.sessionWorkflow])
    static let imageScopes: Set<AppCommandScope> = [.review, .preview, .compare]
    static let allScopes = Set(AppCommandScope.allCases)
    static let reserved: [AppShortcut: AppCommandID] = [
        .init(key:"p",modifiers:[.command,.shift]):.palette, .init(key:"k",modifiers:[.command]):.contextActions,
        .init(key:"p",modifiers:[.command]):.toggleInspector, .init(key:"f",modifiers:[.command]):.find,
        .init(key:"f",modifiers:[.command,.shift]):.searchArchive, .init(key:",",modifiers:[.command]):.settings,
        .init(key:"/",modifiers:[.command]):.keyboardHelp, .init(key:",",modifiers:[.command,.shift]):.rebindCommand
    ]
    static let reservedUnbound: Set<AppShortcut> = [.init(key:"k",modifiers:[.command,.shift])]
    let overrides: [String: AppShortcutOverride]
    init(overrides: [String: AppShortcutOverride] = [:]) { self.overrides = overrides }

    static let contextualCommands: Set<AppCommandID> = [.openArchive, .organiseFolder, .moveWalk, .open, .viewOriginal,
        .markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW, .createPhotoLog, .newPhotoLog, .compare,
        .describeSelection, .regenerateDescriptions, .describeTrip, .describeYear, .deliverTrip, .deliverPhotoLog,
        .markPreviousUpload, .clearPreviousUpload, .cropVisible, .removeCompareItem, .confirmSheet, .confirmAndOpenSheet, .closeSheet, .confirmGoogleDelivery, .saveLogDetails, .saveLogAndStartNext, .openPhotoLog, .showPhotoLogContents, .editPhotoLogDetails, .editPhotoLogMembership, .addMarkedToPhotoLog, .deletePhotoLog, .saveLocation, .clearLocation, .retryLocationSave, .pinLocationAtMapCentre, .editTripLabel, .saveTripLabel, .useWalkLocations, .cancelTripLabelEdit, .mergeWalkProposal, .splitWalkProposal, .findGoogleAlbum, .adoptGoogleAlbum, .reviewGoogleAlbumAbsent, .abandonGoogleJob, .saveManualCrop, .cancelManualCrop, .downloadDisplayedOriginal, .cropDisplayedPhoto, .removeDisplayedComparePhoto, .openLinkedPhoto, .includeDisplayedPhoto, .candidateDisplayedPhoto, .excludeDisplayedPhoto, .clearDisplayedPhotoTriage, .toggleDisplayedPhotoRAW]

    static let commands: [AppCommandDefinition] = {
        let mainScopes = Self.mainScopes, imageScopes = Self.imageScopes, allScopes = Self.allScopes
        var result: [AppCommandDefinition] = [
            .init(id: .chooseSource, title: "Choose source folder…", task: "Sources", scopes: mainScopes, defaults: [.init(.init(key: "o", modifiers: [.command]), scopes: mainScopes)], enabled: { _ in true }, run: { s in s.pickSourceFolder() }, needsSurfaceHandler: false),
            .init(id: .chooseDefaultSourceRoot, title: "Choose default SSD source root…", task: "Sources", scopes: mainScopes.union([.settings, .settingsEditor]), defaults: [], enabled: { _ in true }, run: { s in s.pickDefaultSourceRoot() }),
            .init(id: .chooseArchiveRoot, title: "Set Archive root…", task: "Archive", scopes: mainScopes.union([.settings, .settingsEditor]), defaults: [], enabled: { _ in true }, run: { s in s.pickArchiveRoot() }, needsSurfaceHandler: false),
            .init(id: .migrateLayout, title: "Migrate Archive layout…", task: "Archive", scopes: mainScopes, defaults: [], enabled: { _ in true }, run: { s in s.migrateArchiveLayoutInteractively() }, needsSurfaceHandler: false),
            .init(id: .backfillThumbnails, title: "Backfill Archive thumbnails…", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.canWriteArchiveIndex && !s.archiveBackfillIsRunning }, run: { s in s.backfillArchiveIndexThumbnailsInteractively() }, needsSurfaceHandler: false),
            .init(id: .rebuildIndex, title: "Rebuild Archive index…", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.canWriteArchiveIndex }, run: { s in s.rebuildArchiveIndexInteractively() }, needsSurfaceHandler: false),
            .init(id: .exportBackup, title: "Export app-state backup…", task: "Recovery", scopes: mainScopes.union([.settings, .settingsEditor]), defaults: [], enabled: { _ in true }, run: { s in s.exportBackup() }, needsSurfaceHandler: false),
            .init(id: .importBackup, title: "Import app-state backup…", task: "Recovery", scopes: mainScopes.union([.settings, .settingsEditor]), defaults: [], enabled: { _ in true }, run: { s in s.importBackup() }, needsSurfaceHandler: false),
            .init(id: .timeline, title: "Show Archive Timeline", task: "Archive", scopes: mainScopes, defaults: [.init(.init(key: "1", modifiers: [.command]), scopes: mainScopes)], enabled: { s in s.workspaceMode == .archiveView }, run: { s in s.setArchiveBrowseViewMode(.timeline) }, needsSurfaceHandler: false),
            .init(id: .contactSheet, title: "Show Archive Contact Sheet", task: "Archive", scopes: mainScopes, defaults: [.init(.init(key: "2", modifiers: [.command]), scopes: mainScopes)], enabled: { s in s.workspaceMode == .archiveView }, run: { s in s.setArchiveBrowseViewMode(.contactSheet) }, needsSurfaceHandler: false),
            .init(id: .searchArchive, title: "Search the Archive", task: "Find", scopes: mainScopes, defaults: [.init(.init(key: "f", modifiers: [.command, .shift]), scopes: mainScopes)], enabled: { _ in true }, run: { s in s.setWorkspaceMode(.archiveView); s.requestArchiveSearchFocus() }, needsSurfaceHandler: false),
            .init(id: .openArchive, title: "Open selected Archive entry", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView && s.canOpenSelectedArchiveItem }, run: { s in s.openSelectedArchiveItem() }, needsSurfaceHandler: false),
            .init(id: .organiseFolder, title: "Organise selected folder as a Trip…", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView && s.canOrganiseSelectedUnorganisedFolder }, run: { s in s.organiseSelectedUnorganisedFolder() }, needsSurfaceHandler: false),
            .init(id: .prepareThumbnails, title: "Prepare current folder thumbnails…", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.canPrepareCurrentArchiveFolderThumbnails && !s.archiveBackfillIsRunning }, run: { s in s.prepareCurrentArchiveFolderThumbnailsInteractively() }, needsSurfaceHandler: false),
            .init(id: .toggleCovers, title: "Show or hide Archive photo previews", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView }, run: { s in s.setShowArchivePreviews(!s.settings.showArchivePreviews) }, needsSurfaceHandler: false),
            .init(id: .refreshArchive, title: "Refresh Archive catalogue", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView }, run: { s in s.reloadArchiveCatalogue() }, needsSurfaceHandler: false),
            .init(id: .cancelBackfill, title: "Cancel Archive thumbnail preparation", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.archiveBackfillIsRunning }, run: { s in s.cancelArchiveIndexThumbnailBackfill() }, needsSurfaceHandler: false),
            .init(id: .focusSidebar, title: "Focus sidebar navigation", task: "Navigation", scopes: mainScopes, defaults: [.init(.init(key: "1", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { _ in true }, run: { s in s.focusSidebarNavigation() }, needsSurfaceHandler: false),
            .init(id: .focusReview, title: "Focus review or Archive cards", task: "Navigation", scopes: mainScopes, defaults: [.init(.init(key: "2", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.focusReviewSurface() }, needsSurfaceHandler: false),
            .init(id: .toggleInspector, title: "Show or hide Inspector", task: "View", scopes: allScopes, defaults: [.init(.init(key: "p", modifiers: [.command]), scopes: allScopes)], enabled: { _ in true }, run: { s in s.toggleDetailsInspector() }, needsSurfaceHandler: false),
            .init(id: .flatReview, title: "Show flat review", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "3", modifiers: [.command]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.showFlatReview() }, needsSurfaceHandler: false),
            .init(id: .groupedReview, title: "Show grouped review", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "4", modifiers: [.command]), scopes: mainScopes)], enabled: { s in s.canUseGroupedReviewMode }, run: { s in s.showGroupedReview() }, needsSurfaceHandler: false),
            .init(id: .gridLayout, title: "Show review grid", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "g", modifiers: [.command, .option]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewPresentationMode(.grid) }, needsSurfaceHandler: false),
            .init(id: .listLayout, title: "Show review list", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "l", modifiers: [.command, .option]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewPresentationMode(.list) }, needsSurfaceHandler: false),
            .init(id: .filterAll, title: "Show all photos", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "a", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewFilter(.all) }, needsSurfaceHandler: false),
            .init(id: .filterIncluded, title: "Show included photos", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "i", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewFilter(.included) }, needsSurfaceHandler: false),
            .init(id: .filterCandidate, title: "Show candidate photos", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "c", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewFilter(.candidate) }, needsSurfaceHandler: false),
            .init(id: .filterExcluded, title: "Show excluded photos", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "x", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewFilter(.excluded) }, needsSurfaceHandler: false),
            .init(id: .filterUndecided, title: "Show undecided photos", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "u", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewFilter(.undecided) }, needsSurfaceHandler: false),
            .init(id: .filterCropped, title: "Show cropped photos", task: "Review", scopes: mainScopes, defaults: [], enabled: { s in s.canFocusReviewSurface }, run: { s in s.setReviewFilter(.cropped) }, needsSurfaceHandler: false),
            .init(id: .groupDays, title: "Group by days", task: "Grouping", scopes: mainScopes, defaults: [], enabled: { s in s.canUseGroupedReviewMode }, run: { s in s.setDayOrganizationMode(.days) }, needsSurfaceHandler: false),
            .init(id: .groupDaysBursts, title: "Group by days and bursts", task: "Grouping", scopes: mainScopes, defaults: [], enabled: { s in s.canUseGroupedReviewMode }, run: { s in s.setDayOrganizationMode(.daysAndBursts) }, needsSurfaceHandler: false),
            .init(id: .groupDaysClusters, title: "Group by days and clusters", task: "Grouping", scopes: mainScopes, defaults: [.init(.init(key: "3", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canUseGroupedReviewMode }, run: { s in s.setDayOrganizationMode(.daysAndClusters) }, needsSurfaceHandler: false),
            .init(id: .groupDaysClustersBursts, title: "Group by days, clusters and bursts", task: "Grouping", scopes: mainScopes, defaults: [.init(.init(key: "4", modifiers: [.command, .control]), scopes: mainScopes)], enabled: { s in s.canUseGroupedReviewMode }, run: { s in s.setDayOrganizationMode(.daysClustersAndBursts) }, needsSurfaceHandler: false),
            .init(id: .expandAll, title: "Expand all review groups", task: "Grouping", scopes: mainScopes, defaults: [.init(.init(key: "]", modifiers: [.command, .option]), scopes: mainScopes)], enabled: { s in s.canExpandAllGroupedSections }, run: { s in s.expandAllInlineSections() }, needsSurfaceHandler: false),
            .init(id: .collapseAll, title: "Collapse all review groups", task: "Grouping", scopes: mainScopes, defaults: [.init(.init(key: "[", modifiers: [.command, .option]), scopes: mainScopes)], enabled: { s in s.canCollapseAllGroupedSections }, run: { s in s.collapseAllInlineSections() }, needsSurfaceHandler: false),
            .init(id: .previousGroup, title: "Previous review group", task: "Grouping", scopes: [.review], defaults: [.init(.init(key: "up", modifiers: [.command, .option]), scopes: [.review])], enabled: { s in s.canUseGroupedSectionNavigation }, run: { s in s.focusPreviousInlineSection() }, needsSurfaceHandler: false),
            .init(id: .nextGroup, title: "Next review group", task: "Grouping", scopes: [.review], defaults: [.init(.init(key: "down", modifiers: [.command, .option]), scopes: [.review])], enabled: { s in s.canUseGroupedSectionNavigation }, run: { s in s.focusNextInlineSection() }, needsSurfaceHandler: false),
            .init(id: .expandGroup, title: "Expand focused review group", task: "Grouping", scopes: [.review], defaults: [.init(.init(key: "right", modifiers: [.command, .option]), scopes: [.review])], enabled: { s in s.canUseGroupedSectionNavigation }, run: { s in s.expandFocusedInlineSection() }, needsSurfaceHandler: false),
            .init(id: .collapseGroup, title: "Collapse focused review group", task: "Grouping", scopes: [.review], defaults: [.init(.init(key: "left", modifiers: [.command, .option]), scopes: [.review])], enabled: { s in s.canUseGroupedSectionNavigation }, run: { s in s.collapseFocusedInlineSection() }, needsSurfaceHandler: false),
            .init(id: .markIncluded, title: "Include selected photos for import", task: "Triage", scopes: mainScopes.union(imageScopes), defaults: [.init(.init(key: "i", modifiers: [.command]), scopes: mainScopes.union(imageScopes))], enabled: { s in s.canMarkSelectionForImport }, run: { s in s.markCurrentSelectionForImport() }, needsSurfaceHandler: false),
            .init(id: .markExcluded, title: "Exclude selected photos from import", task: "Triage", scopes: mainScopes.union(imageScopes), defaults: [.init(.init(key: "x", modifiers: [.command, .shift]), scopes: mainScopes.union(imageScopes))], enabled: { s in s.canExcludeSelectionFromImport }, run: { s in s.excludeCurrentSelectionFromImport() }, needsSurfaceHandler: false),
            .init(id: .markCandidate, title: "Mark selected photos as candidates", task: "Triage", scopes: mainScopes.union(imageScopes), defaults: [], enabled: { s in s.canMarkSelectionAsCandidate }, run: { s in s.markCurrentSelectionAsCandidate() }, needsSurfaceHandler: false),
            .init(id: .clearTriage, title: "Clear selected photos to undecided", task: "Triage", scopes: mainScopes.union(imageScopes), defaults: [.init(.init(key: "i", modifiers: [.command, .shift]), scopes: mainScopes.union(imageScopes))], enabled: { s in s.canUnmarkSelectionForImport }, run: { s in s.unmarkCurrentSelectionForImport() }, needsSurfaceHandler: false),
            .init(id: .toggleRAW, title: "Toggle RAW companion import", task: "Triage", scopes: mainScopes.union(imageScopes), defaults: [.init(.init(key: "r", modifiers: [.command, .option]), scopes: mainScopes.union(imageScopes))], enabled: { s in s.canToggleRawForSelection }, run: { s in s.toggleRawForCurrentMediaSelection() }, needsSurfaceHandler: false),
            .init(id: .createPhotoLog, title: "Create Photo Log…", task: "Sources", scopes: mainScopes, defaults: [.init(.init(key: "w", modifiers: [.command, .shift]), scopes: mainScopes)], enabled: { s in s.canPresentPhotoLogCreation }, run: { s in s.presentPhotoLogCreation() }, needsSurfaceHandler: false),
            .init(id: .newPhotoLog, title: "Start new Photo Log", task: "Sources", scopes: Self.sessionWorkflowScopes, defaults: [], enabled: { s in s.canStartNewPhotoLogSession }, run: { s in s.startNewPhotoLogSession() }, needsSurfaceHandler: false),
            .init(id: .compare, title: "Compare selected photos", task: "Review", scopes: mainScopes, defaults: [.init(.init(key: "c", modifiers: [.command, .shift]), scopes: mainScopes)], enabled: { s in s.canOpenComparison }, run: { s in s.openComparisonForCurrentSelection() }, needsSurfaceHandler: false),
            .init(id: .open, title: "Open current selection", task: "Navigation", scopes: mainScopes.union([.compare]), defaults: [.init(.init(key: "return", modifiers: [.command]), scopes: mainScopes.union([.compare]))], enabled: { s in s.canOpenCurrentSelection }, run: { s in s.openCurrentSelection() }, needsSurfaceHandler: false),
            .init(id: .openFocusedPhoto, title: "Open focused photo preview", task: "Review", scopes: mainScopes, defaults: [], enabled: { s in s.focusedReviewItemID.map { !s.orderedMediaItems(for: [$0]).isEmpty } ?? false }, run: { s in s.openFocusedReviewItem() }),
            .init(id: .clearArchiveFilters, title: "Clear Archive search and filters", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView }, run: { s in s.updateArchiveSearch(""); s.setArchiveKindFilter(.all); s.setArchiveYearFilter(nil) }),
            .init(id: .viewOriginal, title: "Download selected Archive photo to view", task: "Archive", scopes: mainScopes.union([.preview, .compare]), defaults: [.init(.init(key: "d", modifiers: [.command, .shift]), scopes: mainScopes.union([.preview, .compare]))], enabled: { s in s.canDownloadBlockedArchiveSelectionToView }, run: { s in s.downloadBlockedArchiveSelectionToView() }, needsSurfaceHandler: false),
            .init(id: .goUp, title: "Go to parent", task: "Navigation", scopes: mainScopes, defaults: [.init(.init(key: "u", modifiers: [.command, .option]), scopes: mainScopes)], enabled: { s in s.canNavigateToParent }, run: { s in s.navigateToParent() }, needsSurfaceHandler: false),
            .init(id: .deselectReviewPhotos, title: "Deselect photos in review", task: "Review", scopes: mainScopes, defaults: [], enabled: { s in !s.selectedMediaItemIDs.isEmpty }, run: { s in s.deselectAllVisibleMedia() }),
            .init(id: .deselectAll, title: "Deselect all photos", task: "Review", scopes: mainScopes.union(imageScopes), defaults: [.init(.init(key: "a", modifiers: [.command, .shift]), scopes: mainScopes.union(imageScopes))], enabled: { s in s.canClearCurrentSelection }, run: { s in s.clearCurrentSelection() }, needsSurfaceHandler: false),
            .init(id: .copyIncluded, title: "Copy included files into Archive", task: "Import", scopes: Self.sessionWorkflowScopes, defaults: [.init(.init(key: "m", modifiers: [.command, .shift]), scopes: Self.sessionWorkflowScopes)], enabled: { s in s.canCommitImport }, run: { s in s.commitImport() }, needsSurfaceHandler: false),
            .init(id: .openDestination, title: "Open copied Archive folder", task: "Import", scopes: Self.sessionWorkflowScopes, defaults: [], enabled: { s in s.canOpenArchiveDestination }, run: { s in s.openArchiveDestinationForCurrentSession() }, needsSurfaceHandler: false),
            .init(id: .moveWalk, title: "Move selected Walk to Trip…", task: "Archive", scopes: mainScopes, defaults: [.init(.init(key: "t", modifiers: [.command, .shift]), scopes: mainScopes)], enabled: { s in s.canMoveSelectedArchiveWalkToTrip }, run: { s in s.moveSelectedArchiveWalkToTrip() }, needsSurfaceHandler: false),
            .init(id: .confirmBackup, title: "Confirm backup and enable cleanup", task: "Recovery", scopes: Self.sessionWorkflowScopes, defaults: [.init(.init(key: "b", modifiers: [.command, .shift]), scopes: Self.sessionWorkflowScopes)], enabled: { s in s.canConfirmBackup }, run: { s in s.markBackupConfirmed() }, needsSurfaceHandler: false),
            .init(id: .cleanupSource, title: "Clean imported files from source SSD", task: "Recovery", scopes: Self.sessionWorkflowScopes, defaults: [.init(.init(key: "k", modifiers: [.command, .option]), scopes: Self.sessionWorkflowScopes)], enabled: { s in s.canCleanupImportedSources }, run: { s in s.cleanupImportedSources() }, needsSurfaceHandler: false),
            .init(id: .toggleSidebar, title: "Show or hide sidebar", task: "View", scopes: allScopes, defaults: [.init(.init(key: "s", modifiers: [.command, .option]), scopes: allScopes)], enabled: { _ in true }, run: { s in s.toggleSidebarVisibility() }, needsSurfaceHandler: false),
            .init(id: .selectAll, title: "Select all visible photos", task: "Review", scopes: mainScopes.union(imageScopes), defaults: [.init(.init(key: "a", modifiers: [.command]), scopes: mainScopes.union(imageScopes))], enabled: { s in s.canFocusReviewSurface }, run: { s in s.selectAllVisibleMedia() }, needsSurfaceHandler: false),
            .init(id: .find, title: "Find in current view", task: "Find", scopes: mainScopes, defaults: [.init(.init(key: "f", modifiers: [.command]), scopes: mainScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .settings, title: "Open Settings", task: "App", scopes: allScopes, defaults: [.init(.init(key: ",", modifiers: [.command]), scopes: allScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .palette, title: "Find and run a command", task: "Commands", scopes: allScopes, defaults: [.init(.init(key: "p", modifiers: [.command, .shift]), scopes: allScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .contextActions, title: "Actions for current selection", task: "Commands", scopes: allScopes, defaults: [.init(.init(key: "k", modifiers: [.command]), scopes: allScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .keyboardHelp, title: "Keyboard shortcuts", task: "Commands", scopes: allScopes, defaults: [.init(.init(key: "/", modifiers: [.command]), scopes: allScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .rebindCommand, title: "Rebind highlighted command", task: "Commands", scopes: [.commandPanel], defaults: [.init(.init(key: ",", modifiers: [.command, .shift]), scopes: [.commandPanel])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .describeSelection, title: "Describe selected material", task: "Descriptions", scopes: mainScopes, defaults: [], enabled: { s in !s.contextualDescriptionTargets.isEmpty && !s.isDescribing }, run: { s in s.startDescriptionCommand(.targets(s.contextualDescriptionTargets, regenerate: false)) }, needsSurfaceHandler: false),
            .init(id: .regenerateDescriptions, title: "Regenerate selected descriptions", task: "Descriptions", scopes: mainScopes, defaults: [], enabled: { s in !s.contextualDescriptionTargets.isEmpty && !s.isDescribing }, run: { s in s.startDescriptionCommand(.targets(s.contextualDescriptionTargets, regenerate: true)) }, needsSurfaceHandler: false),
            .init(id: .describeTrip, title: "Describe this Trip", task: "Descriptions", scopes: mainScopes, defaults: [], enabled: { s in s.descriptionTripPath != nil && !s.isDescribing }, run: { s in if let path = s.descriptionTripPath { s.startDescriptionCommand(.targets([(.trip, path)], regenerate: false)) } }, needsSurfaceHandler: false),
            .init(id: .describeYear, title: "Describe current Archive year", task: "Descriptions", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView && s.descriptionYear != nil && !s.isDescribing }, run: { s in if let year = s.descriptionYear { s.startDescriptionCommand(.year(year)) } }, needsSurfaceHandler: false),
            .init(id: .descriptionQueue, title: "Open description queue", task: "Descriptions", scopes: mainScopes.union([.settings, .settingsEditor]), defaults: [], enabled: { _ in true }, run: { s in Self.prepare(s) { state in await state.loadDescriptionQueue() } }, needsSurfaceHandler: false),
            .init(id: .resumeDescriptions, title: "Resume or retry descriptions", task: "Descriptions", scopes: mainScopes.union([.information]), defaults: [], enabled: { s in !s.isDescribing }, run: { s in s.startDescriptionResume() }, needsSurfaceHandler: false),
            .init(id: .cancelDescriptions, title: "Cancel descriptions", task: "Descriptions", scopes: mainScopes.union([.information]), defaults: [], enabled: { s in s.isDescribing }, run: { s in s.cancelDescriptions() }, needsSurfaceHandler: false),
            .init(id: .discardDescriptions, title: "Discard failed description batches", task: "Descriptions", scopes: mainScopes.union([.information]), defaults: [], enabled: { s in !s.isDescribing }, run: { s in s.startDescriptionDiscard() }, needsSurfaceHandler: false),
            .init(id: .deliverTrip, title: "Review sending this Trip to Google Photos…", task: "Google Photos", scopes: mainScopes, defaults: [], enabled: { s in s.descriptionTripPath != nil && !s.isDeliveringGooglePhotos }, run: { s in Self.prepare(s) { state in await state.reviewGoogleTrip() } }, needsSurfaceHandler: false),
            .init(id: .deliverPhotoLog, title: "Review sending this Photo Log to Google Photos…", task: "Google Photos", scopes: mainScopes, defaults: [], enabled: { s in s.canDeliverGooglePhotoLog && !s.isDeliveringGooglePhotos }, run: { s in Self.prepare(s) { state in await state.reviewGooglePhotoLog() } }, needsSurfaceHandler: false),
            .init(id: .markPreviousUpload, title: "Mark selection previously uploaded", task: "Google Photos", scopes: mainScopes, defaults: [], enabled: { s in s.canMarkGoogleMaterial }, run: { s in Self.prepare(s) { state in await state.markGoogleMaterial(clear: false) } }, needsSurfaceHandler: false),
            .init(id: .clearPreviousUpload, title: "Clear previous-upload marks", task: "Google Photos", scopes: mainScopes, defaults: [], enabled: { s in s.canMarkGoogleMaterial }, run: { s in Self.prepare(s) { state in await state.markGoogleMaterial(clear: true) } }, needsSurfaceHandler: false),
            .init(id: .googleQueue, title: "Open Google Photos delivery queue", task: "Google Photos", scopes: mainScopes.union([.googleAccount, .googleAccountEditor]), defaults: [], enabled: { _ in true }, run: { s in Self.prepare(s) { state in await state.loadGoogleDeliveryQueue() } }, needsSurfaceHandler: false),
            .init(id: .moveLeft, title: "Move left", task: "Keyboard context", scopes: imageScopes.union([.archiveCards]), defaults: [.init(.init(key: "left", modifiers: []), scopes: imageScopes.union([.archiveCards]))], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .moveRight, title: "Move right", task: "Keyboard context", scopes: imageScopes.union([.archiveCards]), defaults: [.init(.init(key: "right", modifiers: []), scopes: imageScopes.union([.archiveCards]))], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .moveUp, title: "Move up", task: "Keyboard context", scopes: imageScopes.union([.archiveCards]), defaults: [.init(.init(key: "up", modifiers: []), scopes: imageScopes.union([.archiveCards]))], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .moveDown, title: "Move down", task: "Keyboard context", scopes: imageScopes.union([.archiveCards]), defaults: [.init(.init(key: "down", modifiers: []), scopes: imageScopes.union([.archiveCards]))], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .extendLeft, title: "Extend selection left", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "left", modifiers: [.shift]), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .extendRight, title: "Extend selection right", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "right", modifiers: [.shift]), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .extendUp, title: "Extend selection up", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "up", modifiers: [.shift]), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .extendDown, title: "Extend selection down", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "down", modifiers: [.shift]), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .toggleSelection, title: "Toggle focused photo selection", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "space", modifiers: []), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .activateFocused, title: "Open focused item or group", task: "Keyboard context", scopes: imageScopes.union([.archiveCards]), defaults: [.init(.init(key: "return", modifiers: []), scopes: imageScopes.union([.archiveCards]))], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .closeSurface, title: "Close current view or leave its focus", task: "Keyboard context", scopes: imageScopes.union([.archiveCards, .archiveSidebar]), defaults: [.init(.init(key: "escape", modifiers: []), scopes: imageScopes.union([.archiveCards, .archiveSidebar]))], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .zoomIn, title: "More grid columns or zoom in", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "=", modifiers: []), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .zoomOut, title: "Fewer grid columns or zoom out", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "-", modifiers: []), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .zoomReset, title: "Reset grid columns or zoom to Fit", task: "Keyboard context", scopes: imageScopes, defaults: [.init(.init(key: "0", modifiers: []), scopes: imageScopes)], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .cropVisible, title: "Crop visible image area", task: "Keyboard context", scopes: [.preview, .compare], defaults: [.init(.init(key: "v", modifiers: []), scopes: [.preview, .compare])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .panLeft, title: "Pan image left", task: "Keyboard context", scopes: [.preview, .compare], defaults: [.init(.init(key: "h", modifiers: []), scopes: [.preview, .compare])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .panDown, title: "Pan image down", task: "Keyboard context", scopes: [.preview, .compare], defaults: [.init(.init(key: "j", modifiers: []), scopes: [.preview, .compare])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .panUp, title: "Pan image up", task: "Keyboard context", scopes: [.preview, .compare], defaults: [.init(.init(key: "k", modifiers: []), scopes: [.preview, .compare])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .panRight, title: "Pan image right", task: "Keyboard context", scopes: [.preview, .compare], defaults: [.init(.init(key: "l", modifiers: []), scopes: [.preview, .compare])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .removeCompareItem, title: "Remove focused comparison photo", task: "Keyboard context", scopes: [.compare], defaults: [.init(.init(key: "q", modifiers: []), scopes: [.compare])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .sidebarPrevious, title: "Previous sidebar filter", task: "Keyboard context", scopes: [.archiveSidebar], defaults: [.init(.init(key: "up", modifiers: []), scopes: [.archiveSidebar])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .sidebarNext, title: "Next sidebar filter", task: "Keyboard context", scopes: [.archiveSidebar], defaults: [.init(.init(key: "down", modifiers: []), scopes: [.archiveSidebar])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .sidebarApply, title: "Apply highlighted sidebar filter", task: "Keyboard context", scopes: [.archiveSidebar], defaults: [.init(.init(key: "return", modifiers: []), scopes: [.archiveSidebar])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .palettePrevious, title: "Previous command", task: "Keyboard context", scopes: [.commandPanel], defaults: [.init(.init(key: "up", modifiers: []), scopes: [.commandPanel])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .paletteNext, title: "Next command", task: "Keyboard context", scopes: [.commandPanel], defaults: [.init(.init(key: "down", modifiers: []), scopes: [.commandPanel])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .paletteRun, title: "Run highlighted command", task: "Keyboard context", scopes: [.commandPanel], defaults: [.init(.init(key: "return", modifiers: []), scopes: [.commandPanel])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .closeCommandPanel, title: "Close command panel", task: "Keyboard context", scopes: [.commandPanel, .helpPanel], defaults: [.init(.init(key: "escape", modifiers: []), scopes: [.commandPanel, .helpPanel])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .cancelShortcutCapture, title: "Cancel shortcut change", task: "Commands", scopes: [.shortcutCapture], defaults: [.init(.init(key: "escape"), scopes: [.shortcutCapture])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .confirmSheet, title: "Confirm current form", task: "Current form", scopes: [.form, .formEditor], defaults: [.init(.init(key: "return", modifiers: [.command]), scopes: [.form, .formEditor]), .init(.init(key: "return"), scopes: [.form])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true, commitsDraft: true),
            .init(id: .confirmAndOpenSheet, title: "Confirm and open", task: "Current form", scopes: [.form, .formEditor], defaults: [], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true, commitsDraft: true),
            .init(id: .closeSheet, title: "Close or cancel current sheet", task: "Current form", scopes: [.form, .formEditor, .information], defaults: [.init(.init(key: "escape"), scopes: [.form, .formEditor, .information])], enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true),
            .init(id: .confirmGoogleDelivery, title: "Send the reviewed originals to Google Photos", task: "Google Photos", scopes: [.form, .formEditor], defaults: [], enabled: { s in s.googleDeliveryReview != nil && !s.isDeliveringGooglePhotos }, run: { _ in }, needsSurfaceHandler: true, commitsDraft: true),
            .init(id: .resumeGoogleDelivery, title: "Resume or retry Google Photos delivery", task: "Google Photos", scopes: mainScopes.union([.information]), defaults: [], enabled: { s in !s.isDeliveringGooglePhotos }, run: { s in s.startGoogleResume() }),
            .init(id: .cancelGoogleDelivery, title: "Cancel running Google Photos delivery", task: "Google Photos", scopes: mainScopes.union([.information]), defaults: [], enabled: { s in s.isDeliveringGooglePhotos }, run: { s in s.cancelGoogleDelivery() }),
            .init(id: .chooseHistoricalSource, title: "Choose historical source folder…", task: "Sources", scopes: mainScopes, defaults: [], enabled: { _ in true }, run: { s in s.pickSourceFolder(historical: true) }),
            .init(id: .openDefaultSource, title: "Open default source folder", task: "Sources", scopes: mainScopes, defaults: [], enabled: { _ in true }, run: { s in s.openDefaultSourceWorkspace() }),
            .init(id: .reloadSource, title: "Reload current source folder", task: "Sources", scopes: mainScopes, defaults: [], enabled: { s in s.sidebarState.snapshot.canReloadSourceWorkspace }, run: { s in s.reloadCurrentSourceWorkspace() }),
            .init(id: .importSyncedPhotoLogs, title: "Import synced Photo Log state", task: "Recovery", scopes: [.settings, .settingsEditor], defaults: [], enabled: { _ in true }, run: { s in s.importOneDrivePhotoLogState() }),
            .init(id: .refreshDescriptionModels, title: "Refresh local description models", task: "Descriptions", scopes: [.settings, .settingsEditor], defaults: [], enabled: { s in !s.isRefreshingLMStudioModels }, run: { s in Self.prepare(s) { state in await state.refreshLMStudioModels() } }),
            .init(id: .showCamera, title: "Show Camera and source triage", task: "Navigation", scopes: mainScopes, defaults: [], enabled: { _ in true }, run: { s in s.setWorkspaceMode(.cameraTriage) }),
            .init(id: .showPhotoLogs, title: "Show Photo Logs", task: "Navigation", scopes: mainScopes, defaults: [], enabled: { _ in true }, run: { s in s.openPhotoLogLibrary() }),
            .init(id: .showArchive, title: "Show Archive", task: "Navigation", scopes: mainScopes, defaults: [], enabled: { _ in true }, run: { s in s.setWorkspaceMode(.archiveView) }),
            .init(id: .showArchiveMap, title: "Show Archive Map", task: "Archive", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView }, run: { s in s.setArchiveBrowseViewMode(.map) }),
            .init(id: .retryArchiveSearch, title: "Retry current Archive search", task: "Recovery", scopes: mainScopes, defaults: [], enabled: { s in s.canRetryCurrentArchiveSearch }, run: { s in s.retryCurrentArchiveSearch() }),
            .init(id: .retryArchiveFolderLoad, title: "Reload current Archive photo folder", task: "Recovery", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .archiveView && s.isBrowsingArchivePhotos }, run: { s in s.retryArchiveFolderLoad() }),
            .init(id: .openSelectedFolderInFinder, title: "Open selected folder in Finder", task: "Navigation", scopes: mainScopes, defaults: [], enabled: { s in s.canOpenSelectedBrowserFolder }, run: { s in s.openSelectedBrowserFolder() }),
            .init(id: .toggleHistoricalDateSource, title: "Change historical folder date source", task: "Sources", scopes: mainScopes, defaults: [], enabled: { s in s.workspaceMode == .cameraTriage && s.hasHistoricalSources }, run: { s in s.toggleHistoricalFolderDates() }),
            .init(id: .chooseOneDrivePictures, title: "Choose OneDrive Pictures root…", task: "App", scopes: [.settings, .settingsEditor], defaults: [], enabled: { _ in true }, run: { s in s.pickOneDrivePicturesRoot() }),
            .init(id: .useArchiveForOneDrivePictures, title: "Use Archive root for OneDrive Pictures", task: "App", scopes: [.settings, .settingsEditor], defaults: [], enabled: { _ in true }, run: { s in s.setOneDrivePicturesRoot(s.settings.archiveRoot) }),
        ]
        func local(_ id: AppCommandID, _ title: String, _ task: String, _ scopes: Set<AppCommandScope>, save: Bool = false, commitsDraft: Bool = false) {
            result.append(.init(id: id, title: title, task: task, scopes: scopes,
                defaults: save ? [.init(.init(key: "return", modifiers: [.command]), scopes: scopes)] : [],
                enabled: { _ in true }, run: { _ in }, needsSurfaceHandler: true, commitsDraft: save || commitsDraft))
        }
        local(.includeDisplayedRAW, "Include this photo's RAW companions", "Photo", [.reviewItem])
        local(.excludeDisplayedRAW, "Exclude this photo's RAW companions", "Photo", [.reviewItem])
        local(.retryDisplayedThumbnail, "Retry this photo's thumbnail", "Photo", [.reviewItem, .inspectorPhoto])
        local(.compareDisplayedGroup, "Compare this photo group", "Grouping", [.reviewGroup])
        local(.toggleDisplayedGroup, "Expand or collapse this photo group", "Grouping", [.reviewGroup])
        local(.focusDisplayedGroup, "Focus this photo group", "Grouping", [.reviewGroup])
        local(.showCropVersion, "Show this crop version", "Photo", [.cropVersion])
        local(.toggleReviewMap, "Show or hide Review Map", "Review", [.review])
        local(.saveLogDetails, "Save edited Log details", "Photo Logs", [.logDetails, .logDetailsEditor], save: true)
        local(.saveLogAndStartNext, "Save edited Log and start the next", "Photo Logs", [.logDetails, .logDetailsEditor], commitsDraft: true)
        local(.openPhotoLog, "Continue this Photo Log", "Photo Logs", [.photoLogActions])
        local(.showPhotoLogContents, "Show this Photo Log's contents", "Photo Logs", [.photoLogActions])
        local(.editPhotoLogDetails, "Edit this Photo Log's details", "Photo Logs", [.photoLogActions])
        local(.editPhotoLogMembership, "Edit this Photo Log's membership", "Photo Logs", [.photoLogActions])
        local(.addMarkedToPhotoLog, "Add marked source photos to this Log", "Photo Logs", [.photoLogActions])
        local(.deletePhotoLog, "Delete this Photo Log…", "Photo Logs", [.photoLogActions])
        local(.saveLocation, "Save edited location", "Locations", [.location, .locationEditor], save: true)
        local(.clearLocation, "Clear this location assignment", "Locations", [.location, .locationEditor])
        local(.retryLocationSave, "Retry this unfinished location save", "Locations", [.location, .locationEditor])
        local(.pinLocationAtMapCentre, "Pin this location at the map centre", "Locations", [.location, .locationEditor])
        local(.editTripLabel, "Edit this Trip's location label", "Locations", [.tripLabel, .tripLabelEditor])
        local(.saveTripLabel, "Save edited Trip location label", "Locations", [.tripLabel, .tripLabelEditor], save: true)
        local(.useWalkLocations, "Use Walk locations for this Trip", "Locations", [.tripLabel, .tripLabelEditor])
        local(.cancelTripLabelEdit, "Cancel Trip label editing", "Locations", [.tripLabel, .tripLabelEditor])
        local(.mergeWalkProposal, "Merge this Walk with the previous proposal", "Copy plan", [.walkProposal, .walkProposalEditor], commitsDraft: true)
        local(.splitWalkProposal, "Split this proposed Walk", "Copy plan", [.walkProposal, .walkProposalEditor], commitsDraft: true)
        local(.connectGoogleAccount, "Connect a Google Photos account…", "Google Photos", [.googleAccount, .googleAccountEditor], commitsDraft: true)
        local(.cancelGoogleSignIn, "Cancel Google Photos sign-in", "Google Photos", [.googleAccount, .googleAccountEditor])
        local(.disconnectGoogleAccount, "Disconnect this Google Photos account", "Google Photos", [.googleAccount, .googleAccountEditor])
        local(.refreshGoogleAccount, "Refresh Google Photos account status", "Google Photos", [.googleAccount, .googleAccountEditor])
        local(.saveGoogleClientSecret, "Save the entered Google client secret to Keychain", "Google Photos", [.googleAccount, .googleAccountEditor], commitsDraft: true)
        local(.findGoogleAlbum, "Find the album created by this delivery…", "Google Photos", [.googleJob, .googleJobEditor])
        local(.adoptGoogleAlbum, "Use this album for the captured delivery", "Google Photos", [.googleAlbum, .googleAlbumEditor])
        local(.reviewGoogleAlbumAbsent, "Review confirmation that this delivery created no album…", "Google Photos", [.googleJob, .googleJobEditor])
        local(.abandonGoogleJob, "Stop this saved Google Photos delivery", "Google Photos", [.googleJob, .googleJobEditor])
        local(.previousPreviewPhoto, "Show previous photo", "Preview", [.preview])
        local(.nextPreviewPhoto, "Show next photo", "Preview", [.preview])
        local(.closeImageSurface, "Close image view", "Images", [.preview, .compare])
        local(.saveManualCrop, "Save selected crop", "Images", [.preview, .compare], commitsDraft: true)
        local(.cancelManualCrop, "Cancel selected crop", "Images", [.preview, .compare])
        local(.toggleManualCrop, "Toggle Compare drag crop", "Compare", [.compare])
        local(.toggleComparePanLock, "Toggle Compare pan lock", "Compare", [.compare])
        local(.fewerCompareColumns, "Fewer Compare columns", "Compare", [.compare])
        local(.moreCompareColumns, "More Compare columns", "Compare", [.compare])
        local(.resetCompareColumns, "Reset Compare columns", "Compare", [.compare])
        local(.openLinkedPhoto, "Open linked crop or original", "Images", [.preview, .compareItem, .reviewItem])
        local(.includeDisplayedPhoto, "Include this displayed photo", "Photo", [.compareItem, .reviewItem])
        local(.excludeDisplayedPhoto, "Exclude this displayed photo", "Photo", [.compareItem, .reviewItem])
        local(.candidateDisplayedPhoto, "Mark this displayed photo as candidate", "Photo", [.compareItem, .reviewItem])
        local(.clearDisplayedPhotoTriage, "Clear this displayed photo decision", "Photo", [.compareItem, .reviewItem])
        local(.toggleDisplayedPhotoRAW, "Toggle this displayed photo's RAW companions", "Photo", [.compareItem, .reviewItem])
        local(.cropDisplayedPhoto, "Crop this displayed photo's visible area", "Compare photo", [.compareItem])
        local(.removeDisplayedComparePhoto, "Remove this displayed photo from Compare", "Compare photo", [.compareItem])
        local(.downloadDisplayedOriginal, "Download this displayed original to view", "Images", [.preview, .compareItem])
        func alias(_ id: AppCommandID, _ key: String, _ mods: ShortcutModifiers = [], scopes: Set<AppCommandScope>) {
            guard let index = result.firstIndex(where: { $0.id == id }) else { return }
            let old = result[index]
            result[index] = .init(id: old.id, title: old.title, task: old.task, scopes: old.scopes,
                defaults: old.defaults + [.init(.init(key:key,modifiers:mods),scopes:scopes)], enabled: old.enabled, run: old.run, needsSurfaceHandler: old.needsSurfaceHandler, commitsDraft: old.commitsDraft)
        }
        alias(.toggleInspector, "i", [.command,.option], scopes: allScopes)
        alias(.keyboardHelp, "/", [.command,.shift], scopes: allScopes)
        alias(.markIncluded,"s",scopes:imageScopes); alias(.markExcluded,"x",scopes:imageScopes)
        alias(.markCandidate,"c",scopes:imageScopes); alias(.clearTriage,"d",scopes:imageScopes)
        alias(.toggleRAW,"r",scopes:imageScopes); alias(.selectAll,"a",scopes:imageScopes)
        alias(.previousGroup,"up",[.option],scopes:[.review]); alias(.nextGroup,"down",[.option],scopes:[.review])
        alias(.expandGroup,"right",[.option],scopes:[.review]); alias(.collapseGroup,"left",[.option],scopes:[.review])
        alias(.zoomIn,"=",[.shift],scopes:imageScopes); alias(.zoomOut,"-",[.shift],scopes:imageScopes)
        return result
    }()

    /// Capture before scheduling: a later Task must never borrow another selection,
    /// archive, account or local-model configuration from the shared AppState.
    private static func prepare(_ state: AppState, operation: @escaping @MainActor (AppState) async -> Void) {
        let selection = CommandSelectionFingerprint(state), configuration = state.settings.lmStudioConfiguration, revision = state.lmStudioConfigurationRevision
        Task { [weak state] in
            guard let state, selection == CommandSelectionFingerprint(state),
                  configuration == state.settings.lmStudioConfiguration, revision == state.lmStudioConfigurationRevision, !Task.isCancelled else { return }
            await operation(state)
        }
    }

    static func definition(_ id: AppCommandID) -> AppCommandDefinition { commands.first { $0.id == id }! }
    func bindings(_ id: AppCommandID) -> [AppCommandBinding] {
        let definition = Self.definition(id)
        guard let override = overrides[id.rawValue] else { return definition.defaults }
        guard let shortcut = override.shortcut, shortcut.isValid, Self.preservesTextInput(shortcut, for: definition) else { return [] }
        guard Self.reserved[shortcut].map({ $0 == id }) ?? !Self.reservedUnbound.contains(shortcut) else { return [] }
        return [.init(shortcut, scopes: definition.scopes)]
    }
    func claims(for event: NSEvent, scope: AppCommandScope) -> [AppCommandID] {
        guard let shortcut = AppShortcut(event: event) else { return [] }
        return Self.commands.filter { command in bindings(command.id).contains { $0.shortcut == shortcut && $0.scopes.contains(scope) } }.map(\.id)
    }
    func command(for event: NSEvent, scope: AppCommandScope) -> AppCommandID? {
        let claims = claims(for: event, scope: scope); return claims.count == 1 ? claims[0] : nil
    }
    private static func preservesTextInput(_ shortcut: AppShortcut, for command: AppCommandDefinition) -> Bool {
        guard command.scopes.contains(where: { $0.isTextEditing || [.information, .commandPanel, .helpPanel, .shortcutCapture].contains($0) }) else { return true }
        // Only these existing pane keys are grammar while a search field is editing.
        let grammar: [AppCommandID: String] = [.palettePrevious: "up", .paletteNext: "down", .paletteRun: "return", .closeCommandPanel: "escape", .cancelShortcutCapture: "escape", .closeSheet: "escape"]
        if shortcut.modifiers.isEmpty, grammar[command.id] == shortcut.key { return true }
        guard shortcut.modifiers.contains(.command) else { return false }
        let nativeEditKeys: Set<String> = ["a", "c", "v", "x", "z", "y", "b", "i", "u"]
        if nativeEditKeys.contains(shortcut.key), shortcut.modifiers == [.command] || shortcut.modifiers == [.command, .shift] { return false }
        if ["left", "right", "up", "down"].contains(shortcut.key), !shortcut.modifiers.contains(.control) { return false }
        return true
    }

    func validateDefault(for id: AppCommandID) -> String? {
        var updated = overrides; updated[id.rawValue] = nil
        if let collision = Self.init(overrides: updated).collisions().first(where: { $0.0 == id || $0.1 == id }) {
            let other = collision.0 == id ? collision.1 : collision.0
            return "The default conflicts with " + Self.definition(other).title + ". Change or unassign that shortcut first."
        }
        return nil
    }
    func displayedShortcuts(_ id: AppCommandID, scope: AppCommandScope? = nil) -> String {
        let chords = bindings(id).filter { scope.map($0.scopes.contains) ?? true }.map(\.shortcut.display)
        return chords.isEmpty ? "Unassigned" : Array(NSOrderedSet(array: chords)) .compactMap { $0 as? String }.joined(separator: " · ")
    }
    private static func canBeCoactive(_ a: Set<AppCommandScope>, _ b: Set<AppCommandScope>) -> Bool {
        !a.isDisjoint(with: b) || a.contains { !$0.coactiveAncestors.isDisjoint(with: b) }
            || b.contains { !$0.coactiveAncestors.isDisjoint(with: a) }
    }
    func collisions() -> [(AppCommandID, AppCommandID, AppShortcut)] {
        var result: [(AppCommandID, AppCommandID, AppShortcut)] = []
        for (index, command) in Self.commands.enumerated() {
            for other in Self.commands.dropFirst(index + 1) {
                for a in bindings(command.id) { for b in bindings(other.id) where a.shortcut == b.shortcut && Self.canBeCoactive(a.scopes, b.scopes) {
                    result.append((command.id,other.id,a.shortcut))
                } }
            }
        }
        return result
    }
    func validate(_ override: AppShortcutOverride, for id: AppCommandID) -> String? {
        guard let shortcut = override.shortcut else { return nil }
        guard shortcut.isValid, Self.preservesTextInput(shortcut, for: Self.definition(id)) else { return "This shortcut conflicts with native text or system navigation." }
        if Self.reservedUnbound.contains(shortcut) || Self.reserved[shortcut].map({ $0 != id }) == true { return "That shortcut is reserved for another command surface." }
        var updated = overrides; updated[id.rawValue] = override
        if let collision = Self.init(overrides:updated).collisions().first(where: { $0.0 == id || $0.1 == id }) {
            let other = collision.0 == id ? collision.1 : collision.0
            return "Already used by " + Self.definition(other).title + "."
        }
        return nil
    }
}
