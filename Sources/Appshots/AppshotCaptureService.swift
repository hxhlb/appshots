import AppKit
import Foundation
@preconcurrency import KWWKComputerUseCore

enum AppshotCaptureService {
    static func capture(target: FrontmostAppTarget) throws -> AppshotRecord {
        let client = ComputerUseClient()
        defer { client.finish() }

        let appIdentifier = target.bundleID.isEmpty ? target.name : target.bundleID
        let output = try client.getAppState(
            app: appIdentifier,
            includeScreenshot: true,
            options: ComputerUseAppStateOptions(
                useBackgroundActivation: false,
                filterVisibleNodes: false,
                includeElementIndexes: false,
                includeOtherWindows: false,
                preserveTextAreaNewlines: true
            )
        )

        return try AppshotStore().save(
            target: target,
            output: output
        )
    }
}
