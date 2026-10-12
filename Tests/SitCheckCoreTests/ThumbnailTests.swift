import CoreImage
import CoreVideo
import XCTest
@testable import SitCheckCore

final class ThumbnailTests: XCTestCase {
    /// 왼쪽 절반은 빨강, 오른쪽 절반은 파랑인 BGRA 프레임
    private func frame(width: Int, height: Int, format: OSType = kCVPixelFormatType_32BGRA) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, attrs, &buffer), kCVReturnSuccess)
        let pixels = try XCTUnwrap(buffer)
        if format == kCVPixelFormatType_32BGRA {
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pixels)
            for y in 0..<height {
                for x in 0..<width {
                    let p = base + y * stride + x * 4
                    let left = x < width / 2
                    p[0] = left ? 0 : 255   // B
                    p[1] = 0                // G
                    p[2] = left ? 255 : 0   // R
                    p[3] = 255              // A
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
        }
        return pixels
    }

    func testCameraFrameBecomesMirroredJPEGOfExpectedSize() throws {
        let context = CIContext()
        let data = try XCTUnwrap(ThumbnailEncoder.jpeg(from: try frame(width: 640, height: 480), context: context))
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8], "JPEG 시작 표지")
        let image = try XCTUnwrap(ThumbnailEncoder.load(data))
        XCTAssertEqual(image.width, 320)
        XCTAssertEqual(image.height, 240)

        // 거울처럼 뒤집혀 왼쪽이 파랑, 오른쪽이 빨강이어야 한다.
        let rgba = try XCTUnwrap(pixelsRGBA(image))
        let row = 120 * image.width
        let left = rgba[(row + 40) * 4 ..< (row + 40) * 4 + 3]
        let right = rgba[(row + 280) * 4 ..< (row + 280) * 4 + 3]
        XCTAssertGreaterThan(Int(left[left.startIndex + 2]), 150, "왼쪽은 파랑")
        XCTAssertLessThan(Int(left[left.startIndex]), 100)
        XCTAssertGreaterThan(Int(right[right.startIndex]), 150, "오른쪽은 빨강")
        XCTAssertLessThan(Int(right[right.startIndex + 2]), 100)
    }

    func testYUVCameraFormatsEncode() throws {
        let context = CIContext()
        for format in [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_422YpCbCr8] {
            let data = try XCTUnwrap(ThumbnailEncoder.jpeg(from: try frame(width: 1280, height: 720, format: format),
                                                           context: context), "\(format)")
            let image = try XCTUnwrap(ThumbnailEncoder.load(data))
            XCTAssertEqual(image.width, 320)
            XCTAssertEqual(image.height, 180)
        }
    }

    func testSmallFramesAreNotEnlargedAndFilesRoundTrip() throws {
        let data = try XCTUnwrap(ThumbnailEncoder.jpeg(from: try frame(width: 200, height: 150), context: CIContext()))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thumb-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let image = try XCTUnwrap(ThumbnailEncoder.load(url))
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 150)
        XCTAssertNil(ThumbnailEncoder.load(url.appendingPathExtension("missing")))
    }

    private func pixelsRGBA(_ image: CGImage) -> [UInt8]? {
        var out = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ok = out.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return ok ? out : nil
    }
}
