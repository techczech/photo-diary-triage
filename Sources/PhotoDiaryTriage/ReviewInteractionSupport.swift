import AppKit
import Foundation

struct ReviewGridMetrics: Equatable, Sendable {
    static let defaultCardWidth: Double = 280
    static let minCardWidth: Double = 220
    static let maxCardWidth: Double = 420
    static let gridSpacing: Double = 18
    static let gridPadding: Double = 8
    static let defaultColumnCount: Int = 4
    static let maxSuggestedColumns: Int = 12

    let availableWidth: Double
    let requestedColumnCount: Int

    static func defaultRequestedColumnCount() -> Int {
        defaultColumnCount
    }

    static func columnCount(forLegacyCardWidth width: Double) -> Int {
        switch width {
        case ..<240:
            return 6
        case ..<280:
            return 5
        case ..<340:
            return 4
        case ..<390:
            return 3
        default:
            return 2
        }
    }

    var columnCount: Int {
        max(1, min(requestedColumnCount, Self.maxSuggestedColumns))
    }

    var cardWidth: Double {
        let columns = max(columnCount, 1)
        let usableWidth = max(availableWidth - (Self.gridPadding * 2), Self.minCardWidth)
        let totalSpacing = Double(max(columns - 1, 0)) * Self.gridSpacing
        let fittedWidth = (usableWidth - totalSpacing) / Double(columns)
        return min(max(fittedWidth, Self.minCardWidth), Self.maxCardWidth)
    }

    static func thumbnailHeight(for cardWidth: Double) -> Double {
        max(150, cardWidth * 0.68)
    }

    static func estimatedCardHeight(for cardWidth: Double) -> Double {
        thumbnailHeight(for: cardWidth) + 90
    }
}

struct CompareGridMetrics: Equatable, Sendable {
    static let minCardWidth: Double = 180
    static let gridSpacing: Double = 20
    static let gridPadding: Double = 16
    static let cardHorizontalInsets: Double = 24
    static let defaultMaxColumns: Int = 4

    let availableWidth: Double
    let requestedColumnCount: Int
    let itemCount: Int

    init(availableWidth: Double, requestedColumnCount: Int, itemCount: Int) {
        self.availableWidth = availableWidth
        self.requestedColumnCount = requestedColumnCount
        self.itemCount = itemCount
    }

    static func defaultColumnCount(for itemCount: Int) -> Int {
        guard itemCount > 0 else { return 1 }
        return min(itemCount, defaultMaxColumns)
    }

    private var usableWidth: Double {
        max(availableWidth - (Self.gridPadding * 2), Self.minCardWidth)
    }

    var columnCount: Int {
        guard itemCount > 0 else { return 1 }
        return max(1, min(itemCount, requestedColumnCount))
    }

    var rowCount: Int {
        max(1, Int(ceil(Double(itemCount) / Double(columnCount))))
    }

    var cardWidth: Double {
        let columns = max(columnCount, 1)
        let totalSpacing = Double(max(columns - 1, 0)) * Self.gridSpacing
        return max((usableWidth - totalSpacing) / Double(columns), Self.minCardWidth)
    }

    var imageWidth: Double {
        max(cardWidth - Self.cardHorizontalInsets, 1)
    }
}

struct CompareViewport: Equatable, Sendable {
    var x: Double
    var y: Double

    static let zero = CompareViewport(x: 0, y: 0)

    init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    static func normalizedOrigin(contentSize: CGSize, viewportSize: CGSize, boundsOrigin: CGPoint) -> CompareViewport {
        let maxX = max(contentSize.width - viewportSize.width, 0)
        let maxY = max(contentSize.height - viewportSize.height, 0)
        let normalizedX = maxX > 0 ? boundsOrigin.x / maxX : 0
        let normalizedY = maxY > 0 ? boundsOrigin.y / maxY : 0
        return CompareViewport(x: normalizedX, y: normalizedY)
    }

    func contentOrigin(contentSize: CGSize, viewportSize: CGSize) -> CGPoint {
        let maxX = max(contentSize.width - viewportSize.width, 0)
        let maxY = max(contentSize.height - viewportSize.height, 0)
        return CGPoint(x: maxX * x, y: maxY * y)
    }
}

struct ReviewGridClickContext: Equatable, Sendable {
    let isShiftPressed: Bool
    let isCommandPressed: Bool
    let clickCount: Int

    init(modifiers: NSEvent.ModifierFlags, clickCount: Int) {
        isShiftPressed = modifiers.contains(.shift)
        isCommandPressed = modifiers.contains(.command)
        self.clickCount = clickCount
    }

    var isDoubleClick: Bool {
        clickCount >= 2
    }
}
