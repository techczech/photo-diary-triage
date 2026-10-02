import Foundation

struct ManifestRenderer {
    func renderWalkManifest(_ manifest: WalkManifest) -> String {
        var lines: [String] = []
        lines.append("# \(manifest.title.nonEmpty ?? "Photo Walk")")
        lines.append("")
        lines.append("- Session ID: `\(manifest.sessionID.uuidString)`")
        if let walkID = manifest.walkID {
            lines.append("- Walk ID: `\(walkID.uuidString)`")
        }
        lines.append("- Source folder: `\(manifest.sourceFolder.path)`")
        lines.append("- Archive folder: `\(manifest.archiveFolder.path)`")
        if let relativePath = manifest.archiveFolderRelativePath {
            lines.append("- OneDrive Pictures relative folder: `\(relativePath)`")
        }
        if let tripFolderRelativePath = manifest.tripFolderRelativePath {
            lines.append("- Trip folder: `\(tripFolderRelativePath)`")
        }
        if let walkDate = manifest.walkDate {
            lines.append("- Walk date: \(DateFormatting.iso8601.string(from: walkDate))")
        }
        if let location = manifest.location.nonEmpty {
            lines.append("- Location: \(location)")
        }
        lines.append("")
        if let latitude = manifest.latitude { lines.append("- Latitude: \(latitude)") }
        if let longitude = manifest.longitude { lines.append("- Longitude: \(longitude)") }
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

        let text = lines.joined(separator: "\n")
        return (try? manifest.descriptions?.setting(in: text)) ?? text
    }

    func renderTripManifest(_ manifest: TripManifest) -> String {
        var lines: [String] = []
        lines.append("# \(manifest.title.nonEmpty ?? "Trip")")
        lines.append("")
        lines.append("- Trip ID: `\(manifest.tripID.uuidString)`")
        lines.append("- Folder: `\(manifest.folder.path)`")
        if let relativePath = manifest.folderRelativePath {
            lines.append("- OneDrive Pictures relative folder: `\(relativePath)`")
        }
        if let startDate = manifest.startDate {
            lines.append("- Start date: \(DateFormatting.iso8601.string(from: startDate))")
        }
        if let endDate = manifest.endDate {
            lines.append("- End date: \(DateFormatting.iso8601.string(from: endDate))")
        }
        lines.append("")
        if let label = manifest.locationLabelOverride {
            lines.append("- Location label override: \(ArchiveManifestText.quotedScalar(label))")
            lines.append("")
        }
        lines.append("## Member Walks")
        lines.append("")
        if manifest.memberWalkFolderPaths.isEmpty {
            lines.append("_No member walks recorded._")
        } else {
            for path in manifest.memberWalkFolderPaths {
                lines.append("- `\(path)`")
            }
        }
        let text = lines.joined(separator: "\n")
        return (try? manifest.descriptions?.setting(in: text)) ?? text
    }

    func renderFileManifest(_ manifest: FileManifest) -> String {
        var lines: [String] = ["---"]
        lines.append("media_item_id: \(manifest.mediaItemID.uuidString)")
        lines.append("archive_path: \(escapeYAML(manifest.archivePath))")
        if let archiveRelativePath = manifest.archiveRelativePath {
            lines.append("archive_relative_path: \(escapeYAML(archiveRelativePath))")
        }
        if let digest = manifest.sha256 { lines.append("sha256: \(digest)") }
        lines.append("source_file_name: \(escapeYAML(manifest.sourceFileName))")
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
        if let location = manifest.locationOverride {
            lines.append("location_override_name: \(escapeYAML(location.name))")
            lines.append("location_override_latitude: \(location.latitude)")
            lines.append("location_override_longitude: \(location.longitude)")
            lines.append("location_assignment_id: \(location.assignmentID.uuidString)")
            lines.append("location_assigned_at: \(DateFormatting.iso8601.string(from: location.assignedAt))")
            lines.append("location_assignment_shared: \(location.isShared)")
        }
        if let evidence = manifest.captureDateEvidence {
            lines.append("capture_date_source: \(evidence.source.rawValue)")
            lines.append("capture_date_precision: \(evidence.precision.rawValue)")
            if let date = evidence.originalCameraDate { lines.append("original_captured_at: \(DateFormatting.iso8601.string(from: date))") }
            if let date = evidence.folderDate { lines.append("folder_date_hint: \(DateFormatting.iso8601.string(from: date))") }
            lines.append("capture_date_conflicts_with_folder: \(evidence.conflictsWithFolder)")
        }
        lines.append("walk_title: \(escapeYAML(manifest.walkTitle))")
        lines.append("walk_location: \(escapeYAML(manifest.walkLocation))")
        lines.append("---")
        lines.append("")
        lines.append(manifest.notes.nonEmpty ?? "_No notes provided._")
        let text = lines.joined(separator: "\n")
        return (try? manifest.descriptions?.setting(in: text)) ?? text
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
        ArchiveManifestText.quotedScalar(value)
    }
}
