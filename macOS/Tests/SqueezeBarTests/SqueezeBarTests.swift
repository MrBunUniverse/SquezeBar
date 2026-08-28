import XCTest
@testable import SqueezeBar
import CoreGraphics
import ImageIO

final class SqueezeBarTests: XCTestCase {
    
    func testMediaTypeClassification() {
        let pngURL = URL(fileURLWithPath: "/tmp/sample.png")
        let jpgURL = URL(fileURLWithPath: "/tmp/sample.jpg")
        let movURL = URL(fileURLWithPath: "/tmp/sample.mov")
        let mp4URL = URL(fileURLWithPath: "/tmp/sample.mp4")
        let mp3URL = URL(fileURLWithPath: "/tmp/sample.mp3")
        let wavURL = URL(fileURLWithPath: "/tmp/sample.wav")
        let flacURL = URL(fileURLWithPath: "/tmp/sample.flac")
        let m4aURL = URL(fileURLWithPath: "/tmp/sample.m4a")
        let textURL = URL(fileURLWithPath: "/tmp/sample.txt")
        
        XCTAssertEqual(MediaType.classify(url: pngURL), .image)
        XCTAssertEqual(MediaType.classify(url: jpgURL), .image)
        XCTAssertEqual(MediaType.classify(url: movURL), .video)
        XCTAssertEqual(MediaType.classify(url: mp4URL), .video)
        XCTAssertEqual(MediaType.classify(url: mp3URL), .audio)
        XCTAssertEqual(MediaType.classify(url: wavURL), .audio)
        XCTAssertEqual(MediaType.classify(url: flacURL), .audio)
        XCTAssertEqual(MediaType.classify(url: m4aURL), .audio)
        XCTAssertEqual(MediaType.classify(url: textURL), .unsupported)
    }
    
    func testWebPAndAVIFFormatExtensions() {
        let compressor = AcceleratedImageCompressor()
        let sampleURL = URL(fileURLWithPath: "/tmp/sample.png")
        
        var configWebP = CompressionConfiguration()
        configWebP.imageFormatPolicy = .webpModern
        XCTAssertEqual(compressor.outputExtension(for: sampleURL, config: configWebP), "webp")
        
        var configAVIF = CompressionConfiguration()
        configAVIF.imageFormatPolicy = .avifModern
        XCTAssertEqual(compressor.outputExtension(for: sampleURL, config: configAVIF), "avif")
    }
    
    func testImageCompression() throws {
        // Create a synthetic test bitmap image
        let width = 400
        let height = 300
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create CGContext")
            return
        }
        
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.3, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            XCTFail("Failed to create CGImage")
            return
        }
        
        // Save test image to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("squeezebar_test_\(UUID().uuidString).png")
        let destURL = tempDir.appendingPathComponent("squeezebar_test_\(UUID().uuidString)_min.png")
        
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: destURL)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(sourceURL as CFURL, "public.png" as CFString, 1, nil) else {
            XCTFail("Failed creating image destination")
            return
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        
        // Test AcceleratedImageCompressor
        let compressor = AcceleratedImageCompressor()
        let config = CompressionConfiguration(
            formatPolicy: .preserveOriginal,
            qualityPreset: .balanced,
            customQuality: 0.75,
            suffix: "_min"
        )
        
        try compressor.compressImage(from: sourceURL, to: destURL, config: config)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
        let destSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(destSize, 0)
    }
    
    func testModernFormatConversion() throws {
        // Create test JPEG
        let width = 200
        let height = 200
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.1, green: 0.7, blue: 0.4, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = context.makeImage()!
        
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("squeezebar_convert_test_\(UUID().uuidString).jpg")
        let destURL = tempDir.appendingPathComponent("squeezebar_convert_test_\(UUID().uuidString)_min.heic")
        
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: destURL)
        }
        
        let destination = CGImageDestinationCreateWithURL(sourceURL as CFURL, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        
        let compressor = AcceleratedImageCompressor()
        let config = CompressionConfiguration(
            formatPolicy: .modernOptimized,
            qualityPreset: .balanced,
            customQuality: 0.70
        )
        
        let targetExt = compressor.outputExtension(for: sourceURL, config: config)
        XCTAssertEqual(targetExt, "heic")
        
        try compressor.compressImage(from: sourceURL, to: destURL, config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
    }
}

