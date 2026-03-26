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
    static let minCardWidth: Double = 240
    static let gridSpacing: Double = 20
    static let gridPadding: Double = 16
    static let cardHorizontalInsets: Double = 24
    static let cardChromeHeight: Double = 118
    static let minImageHeight: Double = 120
    static let preferredImageAspectHeight: Double = 0.72

    let availableSize: CGSize
    let itemCount: Int

    init(availableSize: CGSize, itemCount: Int) {
        self.availableSize = availableSize
        self.itemCount = itemCount
    }

    private struct Candidate: Equatable {
        let columns: Int
        let rows: Int
        let cardWidth: Double
        let imageHeight: Double

        var cardHeight: Double {
            imageHeight + CompareGridMetrics.cardChromeHeight
        }

        var score: Double {
            let visibleImageWidth = max(cardWidth - CompareGridMetrics.cardHorizontalInsets, 1)
            return visibleImageWidth * imageHeight
        }
    }

    private var usableWidth: Double {
        max(availableSize.width - (Self.gridPadding * 2), Self.minCardWidth)
    }

    private var usableHeight: Double {
        max(availableSize.height - (Self.gridPadding * 2), Self.minImageHeight + Self.cardChromeHeight)
    }

    private var bestCandidate: Candidate {
        guard itemCount > 0 else {
            return Candidate(columns: 1, rows: 1, cardWidth: Self.minCardWidth, imageHeight: Self.minImageHeight)
        }

        var chosenCandidate: Candidate?
        for columns in 1...itemCount {
            let rows = Int(ceil(Double(itemCount) / Double(columns)))
            let totalHorizontalSpacing = Double(max(columns - 1, 0)) * Self.gridSpacing
            let totalVerticalSpacing = Double(max(rows - 1, 0)) * Self.gridSpacing
            let cardWidth = max((usableWidth - totalHorizontalSpacing) / Double(columns), Self.minCardWidth)
            let maxCardHeight = max((usableHeight - totalVerticalSpacing) / Double(rows), Self.cardChromeHeight + Self.minImageHeight)
            let fittedImageHeight = max(maxCardHeight - Self.cardChromeHeight, Self.minImageHeight)
            let preferredImageHeight = max(cardWidth * Self.preferredImageAspectHeight, Self.minImageHeight)
            let imageHeight = min(preferredImageHeight, fittedImageHeight)
            let candidate = Candidate(columns: columns, rows: rows, cardWidth: cardWidth, imageHeight: imageHeight)

            if let currentBest = chosenCandidate {
                let rowPreferenceMargin = max(currentBest.score * 0.12, 1)
                if candidate.score > currentBest.score + rowPreferenceMargin ||
                    (abs(candidate.score - currentBest.score) <= rowPreferenceMargin && candidate.rows < currentBest.rows) {
                    chosenCandidate = candidate
                }
            } else {
                chosenCandidate = candidate
            }
        }

        return chosenCandidate ?? Candidate(columns: 1, rows: 1, cardWidth: Self.minCardWidth, imageHeight: Self.minImageHeight)
    }

    var columnCount: Int {
        bestCandidate.columns
    }

    var rowCount: Int {
        bestCandidate.rows
    }

    var cardWidth: Double {
        bestCandidate.cardWidth
    }

    var imageWidth: Double {
        max(cardWidth - Self.cardHorizontalInsets, 1)
    }

    var cardHeight: Double {
        bestCandidate.cardHeight
    }

    var imageHeight: Double {
        bestCandidate.imageHeight
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
