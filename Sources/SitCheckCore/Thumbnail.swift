import CoreImage
import CoreVideo
import Foundation
import ImageIO

/// 사진 일지용 작은 JPEG를 만들고 읽는다.
/// Core Image로 줄인 뒤 ImageIO로 직접 쓰고 읽어, 픽셀 크기가 파일에 그대로 남고 화면에서도 그 크기로 보이게 한다.
public enum ThumbnailEncoder {
    public static let defaultWidth: CGFloat = 320

    /// 카메라 프레임을 거울처럼 좌우 반전하고 가로 `width` 픽셀로 줄여 JPEG로 만든다.
    public static func jpeg(from pixels: CVPixelBuffer, width: CGFloat = defaultWidth, quality: Double = 0.7,
                            context: CIContext) -> Data? {
        let source = CIImage(cvPixelBuffer: pixels)
        let extent = source.extent
        guard extent.width >= 1, extent.height >= 1, extent.width.isFinite, extent.height.isFinite else { return nil }
        // 좌우 반전 (원점은 그대로 둔다)
        var image = source.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: extent.maxX + extent.minX, ty: 0))
        let scale = min(1, width / extent.width)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rect = CGRect(x: (extent.minX * scale).rounded(.up), y: (extent.minY * scale).rounded(.up),
                          width: (extent.width * scale).rounded(.down), height: (extent.height * scale).rounded(.down))
        guard rect.width >= 1, rect.height >= 1,
              let cg = context.createCGImage(image, from: rect, format: .RGBA8,
                                             colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { return nil }
        return jpeg(cg, quality: quality)
    }

    public static func jpeg(_ image: CGImage, quality: Double = 0.7) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// 저장한 사진을 읽는다. 읽지 못하면 nil.
    public static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    public static func load(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
