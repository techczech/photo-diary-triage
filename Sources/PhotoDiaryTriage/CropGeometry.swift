import CoreGraphics

struct CropGeometryMapper {
    static func normalizedCropRect(
        documentRect: CGRect,
        imageSize: CGSize,
        documentSize: CGSize
    ) -> CropNormalizedRect? {
        guard imageSize.width > 0,
              imageSize.height > 0,
              documentSize.width > 0,
              documentSize.height > 0 else {
            return nil
        }

        let visibleDocumentRect = documentRect.intersection(CGRect(origin: .zero, size: documentSize))
        guard visibleDocumentRect.width > 0, visibleDocumentRect.height > 0 else {
            return nil
        }

        let sourceScaleX = imageSize.width / documentSize.width
        let sourceScaleY = imageSize.height / documentSize.height
        let sourceRectFromBottom = CGRect(
            x: visibleDocumentRect.minX * sourceScaleX,
            y: visibleDocumentRect.minY * sourceScaleY,
            width: visibleDocumentRect.width * sourceScaleX,
            height: visibleDocumentRect.height * sourceScaleY
        ).intersection(CGRect(origin: .zero, size: imageSize))
        guard sourceRectFromBottom.width > 0, sourceRectFromBottom.height > 0 else {
            return nil
        }

        let sourceTopY = imageSize.height - sourceRectFromBottom.maxY
        return CropNormalizedRect(
            x: sourceRectFromBottom.minX / imageSize.width,
            y: sourceTopY / imageSize.height,
            width: sourceRectFromBottom.width / imageSize.width,
            height: sourceRectFromBottom.height / imageSize.height
        )
    }

    static func standardizedDocumentRect(start: CGPoint, end: CGPoint, documentSize: CGSize) -> CGRect {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        return rect.intersection(CGRect(origin: .zero, size: documentSize))
    }

    static func documentRect(normalizedRect: CropNormalizedRect, documentSize: CGSize) -> CGRect? {
        guard documentSize.width > 0, documentSize.height > 0 else { return nil }

        return CGRect(
            x: normalizedRect.x * documentSize.width,
            y: (1 - normalizedRect.y - normalizedRect.height) * documentSize.height,
            width: normalizedRect.width * documentSize.width,
            height: normalizedRect.height * documentSize.height
        ).intersection(CGRect(origin: .zero, size: documentSize))
    }
}
