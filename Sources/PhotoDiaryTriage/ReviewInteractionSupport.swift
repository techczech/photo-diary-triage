import AppKit
import Foundation

struct ReviewGridMetrics: Equatable, Sendable {
    static let defaultCardWidth: Double = 280
    static let minCardWidth: Double = 220
    static let maxCardWidth: Double = 420
    static let cardWidthStep: Double = 20
    static let gridSpacing: Double = 18
    static let gridPadding: Double = 8

    let availableWidth: Double
    let cardWidth: Double

    var columnCount: Int {
        let clampedWidth = max(cardWidth, 1)
        let usableWidth = max(availableWidth - (Self.gridPadding * 2) + Self.gridSpacing, clampedWidth)
        return max(1, Int(usableWidth / (clampedWidth + Self.gridSpacing)))
    }

    static func thumbnailHeight(for cardWidth: Double) -> Double {
        max(150, cardWidth * 0.68)
    }
}

struct CompareGridMetrics: Equatable, Sendable {
    static let defaultCardWidth: Double = 520
    static let minCardWidth: Double = 260
    static let maxCardWidth: Double = 760
    static let cardWidthStep: Double = 40
    static let gridSpacing: Double = 24
    static let gridPadding: Double = 24

    let availableWidth: Double
    let targetCardWidth: Double
    let itemCount: Int
    let zoomScale: Double

    init(availableWidth: Double, targetCardWidth: Double, itemCount: Int, zoomScale: Double = 1) {
        self.availableWidth = availableWidth
        self.targetCardWidth = targetCardWidth
        self.itemCount = itemCount
        self.zoomScale = zoomScale
    }

    private var effectiveTargetCardWidth: Double {
        min(max(targetCardWidth * zoomScale, Self.minCardWidth), Self.maxCardWidth)
    }

    var columnCount: Int {
        guard itemCount > 0 else { return 1 }
        let clampedWidth = effectiveTargetCardWidth
        let usableWidth = max(availableWidth - (Self.gridPadding * 2) + Self.gridSpacing, clampedWidth)
        return max(1, min(itemCount, Int(usableWidth / (clampedWidth + Self.gridSpacing))))
    }

    var cardWidth: Double {
        let columns = max(columnCount, 1)
        let totalSpacing = Double(max(columns - 1, 0)) * Self.gridSpacing
        let usableWidth = max(availableWidth - (Self.gridPadding * 2), Self.minCardWidth)
        let fittedWidth = (usableWidth - totalSpacing) / Double(columns)
        let requestedWidth = min(max(effectiveTargetCardWidth, Self.minCardWidth), Self.maxCardWidth)
        return min(max(min(fittedWidth, requestedWidth), Self.minCardWidth), Self.maxCardWidth)
    }

    var imageHeight: Double {
        max(220, min(560, cardWidth * 0.72))
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
