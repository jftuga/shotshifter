// Reading and writing image files with ImageIO. Loading accepts only PNG and JPEG and
// keeps the image's type and properties (such as DPI and orientation) so the output can
// carry them over. Writing goes to a temporary file in the output directory, which is
// then renamed into place so a failure never leaves a partial output.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A loaded PNG or JPEG image with what is needed to write a matching output.
struct ImageFile {
    /// The JPEG compression quality used for output.
    static let jpegQuality = 0.95

    /// The decoded image.
    let image: CGImage
    /// The file type, PNG or JPEG.
    let type: UTType
    /// The image's properties, written back with the output.
    let properties: [String: Any]

    /// Loads a PNG or JPEG file.
    /// - Parameters:
    ///   - path: The file path as given on the command line.
    /// - Returns: The loaded image.
    /// - Throws: `ShotShifterError.unreadableFile` when the file is missing, a directory or undecodable;
    ///   `ShotShifterError.unsupportedImageType` when it is not PNG or JPEG.
    static func load(path: String) throws -> ImageFile {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: path) else {
            throw ShotShifterError.unreadableFile
        }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let identifier = CGImageSourceGetType(source) else {
            throw ShotShifterError.unsupportedImageType("unknown")
        }
        guard let type = UTType(identifier as String), type == .png || type == .jpeg else {
            let name = UTType(identifier as String)?.preferredFilenameExtension ?? identifier as String
            throw ShotShifterError.unsupportedImageType(name)
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ShotShifterError.unreadableFile
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        return ImageFile(image: image, type: type, properties: properties)
    }

    /// Writes an image in this file's type and with this file's properties, atomically.
    /// - Parameters:
    ///   - image: The image to write.
    ///   - path: The output path.
    /// - Throws: `ShotShifterError.writeFailed` when encoding or renaming fails.
    func write(_ image: CGImage, to path: String) throws {
        let output = URL(fileURLWithPath: path)
        let temporary = output.deletingLastPathComponent().appendingPathComponent(".\(output.lastPathComponent).\(UUID().uuidString).tmp")
        guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, type.identifier as CFString, 1, nil) else {
            throw ShotShifterError.writeFailed("cannot create \(temporary.path)")
        }
        var options = properties
        if type == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality as String] = Self.jpegQuality
        }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temporary)
            throw ShotShifterError.writeFailed("cannot encode the image")
        }
        guard rename(temporary.path, output.path) == 0 else {
            let reason = String(cString: strerror(errno))
            try? FileManager.default.removeItem(at: temporary)
            throw ShotShifterError.writeFailed(reason)
        }
    }
}
