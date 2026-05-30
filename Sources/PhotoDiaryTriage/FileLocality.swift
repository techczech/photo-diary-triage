import Foundation

enum FileLocality: String, Codable, Hashable, Sendable {
    case local
    case onlineOnly = "online_only"
    case unknown

    var isOnlineOnly: Bool {
        self == .onlineOnly
    }

    var displayLabel: String {
        switch self {
        case .local:
            return "Local"
        case .onlineOnly:
            return "Online-only"
        case .unknown:
            return "Unknown"
        }
    }
}

struct FileLocalityDetector {
    static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .fileSizeKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
        .isUbiquitousItemKey,
        .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemIsDownloadingKey
    ]

    static func locality(for url: URL) -> FileLocality {
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
            return .unknown
        }
        return locality(for: values)
    }

    static func locality(for values: URLResourceValues) -> FileLocality {
        locality(
            isRegularFile: values.isRegularFile,
            fileSize: values.fileSize,
            fileAllocatedSize: values.fileAllocatedSize,
            totalFileAllocatedSize: values.totalFileAllocatedSize,
            isUbiquitousItem: values.isUbiquitousItem,
            downloadingStatus: values.ubiquitousItemDownloadingStatus
        )
    }

    static func locality(
        isRegularFile: Bool?,
        fileSize: Int?,
        fileAllocatedSize: Int?,
        totalFileAllocatedSize: Int?,
        isUbiquitousItem: Bool?,
        downloadingStatus: URLUbiquitousItemDownloadingStatus?
    ) -> FileLocality {
        if isRegularFile == false {
            return .unknown
        }

        let logicalSize = fileSize ?? 0
        guard logicalSize > 0 else {
            return .local
        }

        if downloadingStatus == .notDownloaded {
            return .onlineOnly
        }

        if isUbiquitousItem == true {
            if totalFileAllocatedSize == 0 || fileAllocatedSize == 0 {
                return .onlineOnly
            }
            return .local
        }

        return .local
    }
}
