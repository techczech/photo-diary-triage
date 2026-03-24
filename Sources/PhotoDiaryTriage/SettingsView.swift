import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("SSD Source")
                    .font(.title2.weight(.semibold))

                Text(appState.settings.defaultSourceRootDisplayPath)
                    .font(.callout)
                    .textSelection(.enabled)

                Button("Choose Default SSD Root") {
                    appState.pickDefaultSourceRoot()
                }

                Divider()

                Text("Archive Library")
                    .font(.title2.weight(.semibold))

                Text(appState.settings.archiveRootDisplayPath)
                    .font(.callout)
                    .textSelection(.enabled)

                if appState.archiveYearFolders.isEmpty {
                    Text("No existing `202x` year folders found yet. New year folders will be created as needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Detected year folders: \(appState.archiveYearFolders.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Choose Archive Root") {
                    appState.pickArchiveRoot()
                }

                Divider()

                Text("Review Presentation")
                    .font(.headline)

                Picker("Default Review Mode", selection: Binding(
                    get: { appState.reviewPresentationMode },
                    set: { appState.setReviewPresentationMode($0) }
                )) {
                    Text("Grid").tag(ReviewPresentationMode.grid)
                    Text("List").tag(ReviewPresentationMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Stepper(value: reviewGridCardWidthBinding, in: ReviewGridMetrics.minCardWidth...ReviewGridMetrics.maxCardWidth, step: ReviewGridMetrics.cardWidthStep) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grid card width")
                            .font(.subheadline.weight(.semibold))
                        Text("Current size: \(Int(appState.reviewGridCardWidth)) pt")
                            .font(.callout.monospacedDigit())
                    }
                }

                Divider()

                Text("Grouping")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Burst grouping")
                            .font(.subheadline.weight(.semibold))
                        Text("Photos captured within this threshold stay in the same burst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: burstThresholdBinding, in: 0.5...10, step: 0.5) {
                            Text("Current threshold: \(secondsSummary(appState.settings.burstThresholdSeconds))")
                                .font(.callout.monospacedDigit())
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time-cluster grouping")
                            .font(.subheadline.weight(.semibold))
                        Text("Photos captured within this threshold stay in the same time cluster.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: proximityThresholdBinding, in: 60...7200, step: 60) {
                            Text("Current threshold: \(secondsSummary(appState.settings.proximityThresholdSeconds))")
                                .font(.callout.monospacedDigit())
                        }
                    }
                }

                Divider()

                Text("Backup")
                    .font(.headline)

                Text("Export and restore saved settings and session memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Export Backup") {
                        appState.exportBackup()
                    }

                    Button("Import Backup") {
                        appState.importBackup()
                    }
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 640, idealHeight: 680, alignment: .topLeading)
    }

    private var burstThresholdBinding: Binding<Double> {
        Binding(
            get: { appState.settings.burstThresholdSeconds },
            set: { appState.setBurstThresholdSeconds($0) }
        )
    }

    private var proximityThresholdBinding: Binding<Double> {
        Binding(
            get: { appState.settings.proximityThresholdSeconds },
            set: { appState.setProximityThresholdSeconds($0) }
        )
    }

    private var reviewGridCardWidthBinding: Binding<Double> {
        Binding(
            get: { appState.reviewGridCardWidth },
            set: { appState.setReviewGridCardWidth($0) }
        )
    }

    private func secondsSummary(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1f seconds", seconds)
        }

        let minutes = seconds / 60
        if minutes.rounded(.towardZero) == minutes {
            return String(format: "%.0f minutes", minutes)
        }
        return String(format: "%.1f minutes", minutes)
    }
}
