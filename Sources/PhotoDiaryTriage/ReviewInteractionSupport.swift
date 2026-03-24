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
