import Foundation

struct ManifestRenderer {
    func renderWalkManifest(_ manifest: WalkManifest) -> String {
        var lines: [String] = []
        lines.append("# \(manifest.title.nonEmpty ?? "Photo Walk")")
        lines.append("")
        lines.append("- Session ID: `\(manifest.sessionID.uuidString)`")
        lines.append("- Source folder: `\(manifest.sourceFolder.path)`")
        lines.append("- Archive folder: `\(manifest.archiveFolder.path)`")
        if let relativePath = manifest.archiveFolderRelativePath {
            lines.append("- OneDrive Pictures relative folder: `\(relativePath)`")
        }
        if let walkDate = manifest.walkDate {
            lines.append("- Walk date: \(DateFormatting.iso8601.string(from: walkDate))")
        }
        if let location = manifest.location.nonEmpty {
            lines.append("- Location: \(location)")
        }
        lines.append("")
        lines.append("## Notes")
        lines.append("")
        lines.append(manifest.notes.nonEmpty ?? "_No notes provided._")
        lines.append("")
        lines.append("## Source Report")
        lines.append("")
        lines.append("- Total source files: \(manifest.summary.totalSourceFiles)")
        lines.append("- Visible review items: \(manifest.summary.visibleItems)")
        lines.append("- Imported files: \(manifest.summary.importedFiles)")
        lines.append("- Excluded files: \(manifest.summary.excludedFiles)")
        lines.append("- Candidate files: \(manifest.summary.candidateFiles)")
        lines.append("- Undecided files: \(manifest.summary.undecidedFiles)")
        lines.append("- Files left on source SSD: \(manifest.summary.skippedFiles)")
        lines.append("- Cleanup pending: \(manifest.summary.cleanupPendingFiles)")
        lines.append("- Source files cleaned: \(manifest.summary.cleanedSourceFiles)")
        lines.append("")
        lines.append("## Imported Files")
        lines.append("")

        if manifest.importedFiles.isEmpty {
            lines.append("_No imported files._")
        } else {
            for file in manifest.importedFiles {
                let portablePath = file.archiveRelativePath.map { " (`\($0)`)" } ?? ""
                lines.append("- `\(file.sourceFileName)` -> `\(file.archivePath)`\(portablePath)")
            }
        }

        lines.append("")
        lines.append("## Excluded Files")
        lines.append("")

        if manifest.excludedFiles.isEmpty {
            lines.append("_No excluded files._")
        } else {
            for file in manifest.excludedFiles {
                lines.append("- `\(file.sourceFileName)` (`\(file.relativePath)`) - \(file.reason)")
            }
        }

        return lines.joined(separator: "\n")
    }

    func renderFileManifest(_ manifest: FileManifest) -> String {
        var lines: [String] = ["---"]
        lines.append("media_item_id: \(manifest.mediaItemID.uuidString)")
        lines.append("archive_path: \(manifest.archivePath)")
        if let archiveRelativePath = manifest.archiveRelativePath {
            lines.append("archive_relative_path: \(escapeYAML(archiveRelativePath))")
        }
        lines.append("source_file_name: \(manifest.sourceFileName)")
        if !manifest.companionArchivePaths.isEmpty {
            lines.append("companion_archive_paths:")
            for path in manifest.companionArchivePaths {
                lines.append("  - \(escapeYAML(path))")
            }
        }
        if !manifest.companionArchiveRelativePaths.isEmpty {
            lines.append("companion_archive_relative_paths:")
            for path in manifest.companionArchiveRelativePaths {
                lines.append("  - \(escapeYAML(path))")
            }
        }
        if let capturedAt = manifest.capturedAt {
            lines.append("captured_at: \(DateFormatting.iso8601.string(from: capturedAt))")
        }
        if let cameraModel = manifest.cameraModel {
            lines.append("camera_model: \(escapeYAML(cameraModel))")
        }
        if let lensModel = manifest.lensModel {
            lines.append("lens_model: \(escapeYAML(lensModel))")
        }
        if let pixelWidth = manifest.pixelWidth {
            lines.append("pixel_width: \(pixelWidth)")
        }
        if let pixelHeight = manifest.pixelHeight {
            lines.append("pixel_height: \(pixelHeight)")
        }
        if let latitude = manifest.latitude {
            lines.append("latitude: \(latitude)")
        }
        if let longitude = manifest.longitude {
            lines.append("longitude: \(longitude)")
        }
        lines.append("walk_title: \(escapeYAML(manifest.walkTitle))")
        lines.append("walk_location: \(escapeYAML(manifest.walkLocation))")
        lines.append("---")
        lines.append("")
        lines.append(manifest.notes.nonEmpty ?? "_No notes provided._")
        return lines.joined(separator: "\n")
    }

    func renderLog(_ events: [SessionLogEvent]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        return events.compactMap { event in
            guard let data = try? encoder.encode(event), let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        }.joined(separator: "\n")
    }

    private func escapeYAML(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
