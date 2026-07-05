import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            Form {
                Section("SSD Source") {
                    Text(appState.settings.defaultSourceRootDisplayPath)
                        .textSelection(.enabled)

                    Button("Choose Default SSD Root") {
                        appState.pickDefaultSourceRoot()
                    }
                }

                Section("Archive Library") {
                    Text(appState.settings.archiveRootDisplayPath)
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
                }

                Section("Travel Sync") {
                    Picker("Machine Role", selection: Binding(
                        get: { appState.settings.archiveMachineRole },
                        set: { appState.setArchiveMachineRole($0) }
                    )) {
                        ForEach(ArchiveMachineRole.allCases, id: \.self) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)

                    Text(appState.settings.oneDrivePicturesRootDisplayPath)
                        .textSelection(.enabled)

                    HStack {
                        Button("Use Archive Root") {
                            appState.setOneDrivePicturesRoot(appState.settings.archiveRoot)
                        }

                        Button("Choose OneDrive Pictures Root") {
                            appState.pickOneDrivePicturesRoot()
                        }
                    }

                    Button("Import Synced Photo Log State") {
                        appState.importOneDrivePhotoLogState()
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Locations", systemImage: "folder")
            }

            Form {
                Section("Review Presentation") {
                    Picker("Default Review Mode", selection: Binding(
                        get: { appState.reviewPresentationMode },
                        set: { appState.setReviewPresentationMode($0) }
                    )) {
                        Text("Grid").tag(ReviewPresentationMode.grid)
                        Text("List").tag(ReviewPresentationMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Stepper(value: reviewGridColumnCountBinding, in: 1...ReviewGridMetrics.maxSuggestedColumns, step: 1) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Grid columns")
                            Text("Current columns: \(appState.reviewGridPreferredColumnCount)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Grouping") {
                    Stepper(value: burstThresholdBinding, in: 0.5...10, step: 0.5) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Burst grouping")
                            Text("Current threshold: \(secondsSummary(appState.settings.burstThresholdSeconds))")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: proximityThresholdBinding, in: 60...7200, step: 60) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time-cluster grouping")
                            Text("Current threshold: \(secondsSummary(appState.settings.proximityThresholdSeconds))")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Archive Naming") {
                    Picker("Weekday token", selection: Binding(
                        get: { appState.settings.weekdayTokenStyle },
                        set: { appState.setWeekdayTokenStyle($0) }
                    )) {
                        ForEach(WeekdayTokenStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)

                    TextField("Walk label", text: Binding(
                        get: { appState.settings.walkDisplayLabel },
                        set: { appState.setWalkDisplayLabel($0) }
                    ))

                    TextField("Trip label", text: Binding(
                        get: { appState.settings.tripDisplayLabel },
                        set: { appState.setTripDisplayLabel($0) }
                    ))
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Review", systemImage: "square.grid.3x3")
            }

            Form {
                Section("Backup") {
                    Text("Export and restore saved settings and session memory.")
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
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Backup", systemImage: "externaldrive.badge.timemachine")
            }
        }
        .scenePadding()
        .frame(width: 620, height: 430)
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

    private var reviewGridColumnCountBinding: Binding<Int> {
        Binding(
            get: { appState.reviewGridPreferredColumnCount },
            set: { appState.setReviewGridColumnCount($0) }
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
