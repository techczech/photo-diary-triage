import Foundation

enum BrowserNodeKind: String, Hashable, Sendable {
    case sessionSection
    case archiveSection
    case sessionRoot
    case archiveRoot
    case year
    case month
    case day
    case unknownDate
    case photosFolder
    case burstsFolder
    case timeClustersFolder
    case burstGroup
    case timeCluster
    case archiveWalkFolder
}

struct BrowserNode: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var subtitle: String?
    var kind: BrowserNodeKind
    var parentID: String?
    var mediaItemIDs: [UUID]
    var children: [BrowserNode]?
    var folderURL: URL?

    var isContainer: Bool {
        !(children?.isEmpty ?? true)
    }
}

enum ActivePane: Sendable {
    case sidebar
    case folders
    case media
}

enum ReviewPresentationMode: String, Codable, CaseIterable, Sendable {
    case grid
    case list
}

enum DayOrganizationMode: String, Codable, CaseIterable, Sendable {
    case days
    case daysAndBursts
    case daysAndClusters
    case daysClustersAndBursts

    var title: String {
        switch self {
        case .days:
            return "Days"
        case .daysAndBursts:
            return "Days + Bursts"
        case .daysAndClusters:
            return "Days + Clusters"
        case .daysClustersAndBursts:
            return "Days + Clusters + Bursts"
        }
    }
}

struct InlineDaySection: Identifiable, Hashable, Sendable {
    let id: String
    let dayNode: BrowserNode
    let photosNode: BrowserNode?
    let burstFolderNode: BrowserNode?
    let timeClusterFolderNode: BrowserNode?

    var mediaItemIDs: [UUID] {
        dayNode.mediaItemIDs
    }
}

enum InlineSectionKind: String, Hashable, Sendable {
    case day
    case cluster
    case burst
    case remainder
}

struct InlineSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let kind: InlineSectionKind
    let mediaItemIDs: [UUID]
    let photoItemIDs: [UUID]
    let children: [InlineSection]
}
