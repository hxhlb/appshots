import AppKit
import SwiftUI

struct AppshotsPopoverView: View {
    @ObservedObject var model: AppshotsModel
    @ObservedObject private var updateManager = AppshotsUpdateManager.shared
    private let repositoryURL = URL(string: "https://github.com/EYHN/appshots")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            permissions
            controls
            shortcutSettings
            recentCaptures
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
        .frame(width: 400, height: 620, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Appshots")
                .font(.system(size: 20, weight: .semibold))
            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(model.isCapturing ? .blue : .secondary)
                .lineLimit(2)
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 8) {
            PermissionRow(
                title: "Accessibility",
                granted: model.hasAccessibilityPermission,
                actionTitle: "Grant",
                action: model.requestAccessibilityPermission
            )
            PermissionRow(
                title: "Screen Recording",
                granted: model.hasScreenRecordingPermission,
                actionTitle: "Grant",
                action: model.requestScreenRecordingPermission
            )
        }
    }

    private var controls: some View {
        HStack {
            Button {
                model.captureFrontmostApp()
            } label: {
                Label(model.isCapturing ? "Capturing" : "Capture Current App", systemImage: "camera")
            }
            .disabled(model.isCapturing)
            Spacer()
        }
    }

    private var shortcutSettings: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Hotkey")
                    .font(.callout.weight(.medium))
                Text(model.hotKey.instructionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Picker("Hotkey", selection: $model.hotKey) {
                ForEach(AppshotsHotKey.allCases) { hotKey in
                    Text(hotKey.displayText)
                        .tag(hotKey)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 112)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var recentCaptures: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Shots")
                .font(.headline)

            if model.recentCaptures.isEmpty == false {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.recentCaptures) { record in
                            AppshotRecordCard(record: record) {
                                model.copyAppshotMarkup(for: record)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 320)
            } else {
                Text("No appshots yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .center)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Link(destination: repositoryURL) {
                Label("github.com/EYHN/appshots", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            .help("Open GitHub repository")

            Spacer()

            FooterUpdateButton(
                state: updateManager.updateState,
                status: updateManager.statusText,
                action: updateManager.runPrimaryAction
            )

            Button("Quit") {
                model.quit()
            }
            .controlSize(.small)
        }
        .font(.caption)
    }
}

private struct FooterUpdateButton: View {
    var state: AppshotsUpdateManager.UpdateState
    var status: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: iconName)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(state == .downloadingUpdate)
        .help(status)
    }

    private var title: String {
        switch state {
        case .checkForUpdate:
            "Updates"
        case .downloadingUpdate:
            "Downloading"
        case .installUpdate:
            "Install"
        }
    }

    private var iconName: String {
        switch state {
        case .checkForUpdate:
            "arrow.down.circle"
        case .downloadingUpdate:
            "arrow.down.circle.fill"
        case .installUpdate:
            "checkmark.circle.fill"
        }
    }
}

private struct AppshotRecordCard: View {
    var record: AppshotRecord
    var copyAction: () -> Void

    var body: some View {
        Button(action: copyAction) {
            HStack(alignment: .top, spacing: 14) {
                ScreenshotThumbnail(url: record.screenshotURL)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(record.appName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(record.windowTitle.isEmpty ? "Untitled window" : record.windowTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .help("Copy app-shot markup")
    }
}

private struct PermissionRow: View {
    var title: String
    var granted: Bool
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
                .font(.callout)
            Spacer()
            if granted {
                Text("Allowed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button(actionTitle, action: action)
            }
        }
    }
}

private struct ScreenshotThumbnail: View {
    var url: URL?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 108, height: 76)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .clipped()
    }

    private var image: NSImage? {
        guard let url else { return nil }
        return NSImage(contentsOf: url)
    }
}
