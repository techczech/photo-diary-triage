import AppKit
import Foundation

enum AppChromeKeyboardShortcut: Equatable, Sendable {
    case toggleSidebar
    case toggleInspector

    init?(key: String?, modifiers: NSEvent.ModifierFlags) {
        let relevantModifiers = modifiers.intersection([.command, .option, .control, .shift])
        guard relevantModifiers == [.command, .option],
              let key = key?.lowercased() else { return nil }

        switch key {
        case "s":
            self = .toggleSidebar
        case "i":
            self = .toggleInspector
        default:
            return nil
        }
    }
}

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
        return max(fittedWidth, Self.minCardWidth)
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
        guard itemCount > 1 else { return 1 }
        return 2
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

    func nudged(dx: Int, dy: Int, step: Double = 0.12) -> CompareViewport {
        CompareViewport(
            x: x + (Double(dx) * step),
            y: y + (Double(dy) * step)
        )
    }
}

struct CanvasZoomPanMath {
    static let minimumZoom: CGFloat = 0.25
    static let maximumZoom: CGFloat = 4

    static func clampedZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, minimumZoom), maximumZoom)
    }

    static func zoom(from currentZoom: CGFloat, multiplier: CGFloat) -> CGFloat {
        clampedZoom(currentZoom * max(multiplier, 0.01))
    }

    static func pointerAnchoredOrigin(
        oldContentSize: CGSize,
        newContentSize: CGSize,
        viewportSize: CGSize,
        oldBoundsOrigin: CGPoint,
        anchorDocumentPoint: CGPoint
    ) -> CGPoint {
        let normalizedX = normalized(anchorDocumentPoint.x, size: oldContentSize.width)
        let normalizedY = normalized(anchorDocumentPoint.y, size: oldContentSize.height)
        let viewportOffset = CGPoint(
            x: anchorDocumentPoint.x - oldBoundsOrigin.x,
            y: anchorDocumentPoint.y - oldBoundsOrigin.y
        )
        let newDocumentPoint = CGPoint(
            x: normalizedX * newContentSize.width,
            y: normalizedY * newContentSize.height
        )
        return clampedOrigin(
            CGPoint(
                x: newDocumentPoint.x - viewportOffset.x,
                y: newDocumentPoint.y - viewportOffset.y
            ),
            contentSize: newContentSize,
            viewportSize: viewportSize
        )
    }

    static func draggedOrigin(
        startOrigin: CGPoint,
        translation: CGSize,
        contentSize: CGSize,
        viewportSize: CGSize
    ) -> CGPoint {
        clampedOrigin(
            CGPoint(
                x: startOrigin.x - translation.width,
                y: startOrigin.y - translation.height
            ),
            contentSize: contentSize,
            viewportSize: viewportSize
        )
    }

    static func clampedOrigin(_ origin: CGPoint, contentSize: CGSize, viewportSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, 0), max(contentSize.width - viewportSize.width, 0)),
            y: min(max(origin.y, 0), max(contentSize.height - viewportSize.height, 0))
        )
    }

    private static func normalized(_ value: CGFloat, size: CGFloat) -> CGFloat {
        guard size > 0 else { return 0.5 }
        return min(max(value / size, 0), 1)
    }
}

enum CropSelectionHandle: Equatable, Sendable, CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

enum CropSelectionDragMode: Equatable, Sendable {
    case create
    case move
    case resize(CropSelectionHandle)
}

struct CropSelectionGeometry {
    static func dragMode(at point: CGPoint, in selection: CGRect, tolerance: CGFloat) -> CropSelectionDragMode? {
        // Corner targets first (square hit zones), then full-length edge bands, then interior move.
        for handle in [CropSelectionHandle.topLeft, .topRight, .bottomRight, .bottomLeft] {
            if handleRect(for: handle, in: selection, tolerance: tolerance).contains(point) {
                return .resize(handle)
            }
        }
        for (handle, band) in edgeHitBands(in: selection, tolerance: tolerance) where band.contains(point) {
            return .resize(handle)
        }
        if selection.contains(point) {
            return .move
        }
        return nil
    }

    /// Full-length grab bands straddling each edge, so the whole edge resizes (not just a tiny square).
    static func edgeHitBands(in selection: CGRect, tolerance: CGFloat) -> [(CropSelectionHandle, CGRect)] {
        let t = max(tolerance, 1)
        return [
            (.left, CGRect(x: selection.minX - t, y: selection.minY, width: t * 2, height: selection.height)),
            (.right, CGRect(x: selection.maxX - t, y: selection.minY, width: t * 2, height: selection.height)),
            (.bottom, CGRect(x: selection.minX, y: selection.minY - t, width: selection.width, height: t * 2)),
            (.top, CGRect(x: selection.minX, y: selection.maxY - t, width: selection.width, height: t * 2))
        ]
    }

    /// Move the whole normalized crop rect by integer steps, clamped so it stays inside the image.
    static func nudgedNormalizedRect(_ rect: CropNormalizedRect, dx: Int, dy: Int, step: Double) -> CropNormalizedRect {
        let newX = min(max(rect.x + Double(dx) * step, 0), max(0, 1 - rect.width))
        let newY = min(max(rect.y + Double(dy) * step, 0), max(0, 1 - rect.height))
        return CropNormalizedRect(x: newX, y: newY, width: rect.width, height: rect.height)
    }

    static func updatedRect(
        mode: CropSelectionDragMode,
        startRect: CGRect?,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        documentSize: CGSize
    ) -> CGRect {
        switch mode {
        case .create:
            return CropGeometryMapper.standardizedDocumentRect(
                start: startPoint,
                end: currentPoint,
                documentSize: documentSize
            )
        case .move:
            guard let startRect else { return .zero }
            return movedRect(
                startRect,
                by: CGSize(width: currentPoint.x - startPoint.x, height: currentPoint.y - startPoint.y),
                documentSize: documentSize
            )
        case .resize(let handle):
            guard let startRect else { return .zero }
            return resizedRect(
                startRect,
                handle: handle,
                currentPoint: currentPoint,
                documentSize: documentSize
            )
        }
    }

    static func handleRect(for handle: CropSelectionHandle, in selection: CGRect, tolerance: CGFloat) -> CGRect {
        let side = max(tolerance * 2, 8)
        let center = handlePoint(for: handle, in: selection)
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    static func handleRects(in selection: CGRect, tolerance: CGFloat) -> [CGRect] {
        CropSelectionHandle.allCases.map { handleRect(for: $0, in: selection, tolerance: tolerance) }
    }

    private static func handlePoint(for handle: CropSelectionHandle, in selection: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: selection.minX, y: selection.maxY)
        case .top:
            return CGPoint(x: selection.midX, y: selection.maxY)
        case .topRight:
            return CGPoint(x: selection.maxX, y: selection.maxY)
        case .right:
            return CGPoint(x: selection.maxX, y: selection.midY)
        case .bottomRight:
            return CGPoint(x: selection.maxX, y: selection.minY)
        case .bottom:
            return CGPoint(x: selection.midX, y: selection.minY)
        case .bottomLeft:
            return CGPoint(x: selection.minX, y: selection.minY)
        case .left:
            return CGPoint(x: selection.minX, y: selection.midY)
        }
    }

    private static func movedRect(_ rect: CGRect, by translation: CGSize, documentSize: CGSize) -> CGRect {
        clampedRect(
            CGRect(
                x: rect.minX + translation.width,
                y: rect.minY + translation.height,
                width: rect.width,
                height: rect.height
            ),
            documentSize: documentSize
        )
    }

    private static func resizedRect(
        _ rect: CGRect,
        handle: CropSelectionHandle,
        currentPoint: CGPoint,
        documentSize: CGSize
    ) -> CGRect {
        let point = CGPoint(
            x: min(max(currentPoint.x, 0), max(documentSize.width, 0)),
            y: min(max(currentPoint.y, 0), max(documentSize.height, 0))
        )
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch handle {
        case .topLeft:
            minX = point.x
            maxY = point.y
        case .top:
            maxY = point.y
        case .topRight:
            maxX = point.x
            maxY = point.y
        case .right:
            maxX = point.x
        case .bottomRight:
            maxX = point.x
            minY = point.y
        case .bottom:
            minY = point.y
        case .bottomLeft:
            minX = point.x
            minY = point.y
        case .left:
            minX = point.x
        }

        return clampedRect(
            CGRect(
                x: min(minX, maxX),
                y: min(minY, maxY),
                width: abs(maxX - minX),
                height: abs(maxY - minY)
            ),
            documentSize: documentSize
        )
    }

    private static func clampedRect(_ rect: CGRect, documentSize: CGSize) -> CGRect {
        let width = min(max(rect.width, 0), max(documentSize.width, 0))
        let height = min(max(rect.height, 0), max(documentSize.height, 0))
        return CGRect(
            x: min(max(rect.minX, 0), max(documentSize.width - width, 0)),
            y: min(max(rect.minY, 0), max(documentSize.height - height, 0)),
            width: width,
            height: height
        )
    }
}

enum CompareKeyboardPanDirection: Equatable, Sendable {
    case left
    case down
    case up
    case right

    init?(key: String) {
        switch key.uppercased() {
        case "H":
            self = .left
        case "J":
            self = .down
        case "K":
            self = .up
        case "L":
            self = .right
        default:
            return nil
        }
    }

    var dx: Int {
        switch self {
        case .left:
            return -1
        case .right:
            return 1
        case .down, .up:
            return 0
        }
    }

    var dy: Int {
        switch self {
        case .down:
            return 1
        case .up:
            return -1
        case .left, .right:
            return 0
        }
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
