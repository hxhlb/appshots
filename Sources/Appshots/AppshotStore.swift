import Foundation
import ImageIO
import UniformTypeIdentifiers
@preconcurrency import KWWKComputerUseCore

struct AppshotRecord: Codable, Identifiable, Equatable {
    var id: String
    var createdAt: Date
    var appName: String
    var bundleID: String
    var pid: Int32
    var windowTitle: String
    var nodeCount: Int
    var selectedTextLength: Int
    var windowFrame: CGRect
    var screenshotPath: String?
    var axTextPath: String
    var fileBaseName: String
    var captureNumber: Int

    var screenshotURL: URL? {
        screenshotPath.map(URL.init(fileURLWithPath:))
    }

    var axTextURL: URL {
        URL(fileURLWithPath: axTextPath)
    }

    var appshotMarkup: String {
        "[app-shots image=\"\(screenshotPath ?? "")\" content=\"\(axTextPath)\" ]"
    }
}

struct AppshotStore {
    private var fileManager: FileManager { .default }

    var rootURL: URL {
        URL(fileURLWithPath: "/tmp/appshots", isDirectory: true)
    }

    func ensureRootDirectory() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func removeCapture(_ record: AppshotRecord) throws {
        if let screenshotURL = record.screenshotURL,
           fileManager.fileExists(atPath: screenshotURL.path) {
            try fileManager.removeItem(at: screenshotURL)
        }

        let axTextURL = record.axTextURL
        if fileManager.fileExists(atPath: axTextURL.path) {
            try fileManager.removeItem(at: axTextURL)
        }
    }

    func save(
        target: FrontmostAppTarget,
        output: ComputerUseCommandOutput
    ) throws -> AppshotRecord {
        guard let metadata = output.metadata else {
            throw AppshotStoreError.missingSnapshotMetadata
        }

        try ensureRootDirectory()

        let appName = metadata.appName.isEmpty ? target.name : metadata.appName
        let bundleID = metadata.bundleID.isEmpty ? target.bundleID : metadata.bundleID
        let fileBaseName = sanitizedFileBaseName(appName: appName, bundleID: bundleID)
        let captureNumber = nextAvailableCaptureNumber(for: fileBaseName)
        let screenshotURL = rootURL.appendingPathComponent("\(fileBaseName)-\(captureNumber).png")
        let axTextURL = rootURL.appendingPathComponent("\(fileBaseName)-axtree-\(captureNumber).txt")

        let copiedScreenshotURL = try copyScreenshotIfAvailable(
            sourcePath: metadata.screenshotPath,
            to: screenshotURL
        )
        let storedOutput = outputWithLocalScreenshotPath(
            output,
            originalMetadata: metadata,
            copiedScreenshotURL: copiedScreenshotURL
        )

        try storedOutput.text.write(to: axTextURL, atomically: true, encoding: .utf8)

        return AppshotRecord(
            id: "\(fileBaseName)-\(captureNumber)",
            createdAt: Date(),
            appName: appName,
            bundleID: bundleID,
            pid: metadata.pid,
            windowTitle: metadata.windowTitle,
            nodeCount: metadata.nodeSignatures.count,
            selectedTextLength: 0,
            windowFrame: metadata.windowFrame.cgRect,
            screenshotPath: copiedScreenshotURL?.path,
            axTextPath: axTextURL.path,
            fileBaseName: fileBaseName,
            captureNumber: captureNumber
        )
    }

    private func copyScreenshotIfAvailable(
        sourcePath: String?,
        to destinationURL: URL
    ) throws -> URL? {
        guard let sourcePath,
              fileManager.fileExists(atPath: sourcePath)
        else {
            return nil
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let destination = CGImageDestinationCreateWithURL(
                  destinationURL as CFURL,
                  UTType.png.identifier as CFString,
                  1,
                  nil
              )
        else {
            throw AppshotStoreError.unreadableScreenshot(sourceURL.path)
        }

        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw AppshotStoreError.unreadableScreenshot(sourceURL.path)
        }

        return destinationURL
    }

    private func nextAvailableCaptureNumber(for fileBaseName: String) -> Int {
        var number = 1
        while true {
            let screenshotURL = rootURL.appendingPathComponent("\(fileBaseName)-\(number).png")
            let axTextURL = rootURL.appendingPathComponent("\(fileBaseName)-axtree-\(number).txt")
            if fileManager.fileExists(atPath: screenshotURL.path) == false,
               fileManager.fileExists(atPath: axTextURL.path) == false {
                return number
            }
            number += 1
        }
    }

    private func sanitizedFileBaseName(appName: String, bundleID: String) -> String {
        let readableName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = readableName.isEmpty ? fallbackName : readableName
        let disallowed = CharacterSet(charactersIn: "/:\u{0}\"")
            .union(.controlCharacters)
            .union(.newlines)
        let sanitizedScalars = rawName.unicodeScalars.map { scalar in
            disallowed.contains(scalar) ? "-" : String(scalar)
        }
        let sanitized = sanitizedScalars
            .joined()
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .-_"))

        return sanitized.isEmpty ? "appshot" : sanitized
    }

    private func outputWithLocalScreenshotPath(
        _ output: ComputerUseCommandOutput,
        originalMetadata: ComputerUseSnapshotMetadata,
        copiedScreenshotURL: URL?
    ) -> ComputerUseCommandOutput {
        guard let copiedScreenshotURL else {
            return output
        }

        var metadata = originalMetadata
        var storedOutput = output
        let copiedPath = copiedScreenshotURL.path

        if let originalPath = originalMetadata.screenshotPath, originalPath != copiedPath {
            storedOutput.text = storedOutput.text.replacingOccurrences(
                of: originalPath,
                with: copiedPath
            )
        }

        metadata.screenshotPath = copiedPath
        storedOutput.metadata = metadata
        return storedOutput
    }
}

enum AppshotStoreError: LocalizedError {
    case missingSnapshotMetadata
    case unreadableScreenshot(String)

    var errorDescription: String? {
        switch self {
        case .missingSnapshotMetadata:
            return "App state output did not include snapshot metadata."
        case .unreadableScreenshot(let path):
            return "Could not read screenshot at \(path)."
        }
    }
}
