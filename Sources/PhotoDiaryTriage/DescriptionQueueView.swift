import SwiftUI

struct DescriptionQueueView: View {
    @ObservedObject var appState: AppState
    var onClose: (() -> Void)? = nil
    var body: some View {
        let context = appState.commandDescriptionContextKey
        return CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .information, contextKey: context,
            actions: descriptionQueueCommandActions(appState: appState, onClose: { if let onClose { onClose() } else { appState.showDescriptionQueue = false } }),
            ownsWindow: true, fillsAvailableHeight: true) { commands in
        VStack(alignment: .leading, spacing: 12) {
            Text("Local descriptions").font(.title2)
            Text("Archived keepers first, then Walk and Trip summaries. Successful regeneration replaces the active search description and preserves earlier machine revisions.")
                .foregroundStyle(.secondary)
            HStack {
                Button(appState.isDescribing ? "Describing…" : "Resume / retry") { commands.run(.resumeDescriptions) }.disabled(appState.isDescribing)
                Button("Cancel") { commands.run(.cancelDescriptions) }.disabled(!appState.isDescribing)
                Button("Discard failed batches") { commands.run(.discardDescriptions) }.disabled(appState.isDescribing)
                Spacer()
                Button("Close") { commands.run(.closeSheet) }
                    .commandShortcutHint(.closeSheet, appState: appState, scope: .information, help: "Close the queue")
            }
            List(appState.descriptionJobs.filter { $0.state != .discarded }.reversed()) { job in
                DisclosureGroup {
                    if let error = job.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                    if let warning = job.indexWarning { Text(warning).foregroundStyle(.orange).textSelection(.enabled) }
                    if job.state == .committed, let result = job.response {
                        Text(result.text).textSelection(.enabled)
                        Text("\(result.model) · \(result.generatedAt.formatted()) · \(result.inputType)").font(.caption).foregroundStyle(.secondary)
                        if result.totalChildren > 0 { Text("Coverage: \(result.coveredChildren) of \(result.totalChildren) members").font(.caption) }
                    }
                } label: {
                    HStack {
                        Text(job.snapshot.target.path).lineLimit(1)
                        Spacer()
                        Text(job.state == .committed ? "Saved" : job.state.rawValue.capitalized).foregroundStyle(job.state == .failed ? .red : .secondary)
                    }
                }
            }
            if appState.descriptionJobs.isEmpty { Text("Choose archived photos, a Walk, a Trip or a year from Describe in Archive.").foregroundStyle(.secondary) }
        }.padding(20).frame(minWidth: 700, minHeight: 450)
        }
    }
}

struct ArchiveDescriptionControls: View {
    @ObservedObject var appState: AppState
    var body: some View {
        Menu {
            RegisteredWindowControl(id: .describeSelection, title: "Describe selected material", appState: appState)
            RegisteredWindowControl(id: .regenerateDescriptions, title: "Regenerate selected material", appState: appState)
            RegisteredWindowControl(id: .describeTrip, title: "Describe this Trip", appState: appState)
            if let year = appState.descriptionYear {
                RegisteredWindowControl(id: .describeYear, title: "Describe archived material in \(year)", appState: appState)
            }
            Divider()
            RegisteredWindowControl(id: .descriptionQueue, title: "Description queue…", appState: appState)
        } label: { Label(appState.isDescribing ? "Describing…" : "Describe", systemImage: "text.bubble") }
        .help("Describe canonical archived keepers with your selected local model")
        .sheet(isPresented: $appState.showDescriptionQueue) { DescriptionQueueView(appState: appState) }
    }
}

struct DescriptionSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showLocalDescriptionQueue = false
    var body: some View {
        let configuration = appState.settings.lmStudioConfiguration
        let key = localCommandContextKey([appState.commandDescriptionContextKey, configuration.baseURL, configuration.model, String(appState.lmStudioConfigurationRevision)])
        return CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .settings, contextKey: key,
            actions: descriptionSettingsCommandActions(appState: appState, showQueue: { showLocalDescriptionQueue = true }),
            fillsAvailableHeight: true) { commands in
            Form {
                Section("LM Studio") {
                    TextField("Base URL", text: Binding(get: { appState.settings.lmStudioConfiguration.baseURL }, set: { appState.setLMStudio(baseURL: $0) }))
                    TextField("Model identifier", text: Binding(get: { appState.settings.lmStudioConfiguration.model }, set: { appState.setLMStudio(model: $0) }))
                    if !appState.lmStudioModels.isEmpty {
                        Picker("Available model", selection: Binding(get: { appState.settings.lmStudioConfiguration.model }, set: { appState.setLMStudio(model: $0) })) {
                            Text("Choose a model").tag("")
                            ForEach(appState.lmStudioModels, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Button(appState.isRefreshingLMStudioModels ? "Refreshing…" : "Refresh models") { commands.run(.refreshDescriptionModels) }.disabled(appState.isRefreshingLMStudioModels)
                    Text("Start LM Studio's local server and choose a vision-capable model for photographs. Describe runs only when requested in Archive; summaries use recorded child descriptions. Results retain model/date provenance separately from your notes.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Travel descriptions use prepared thumbnails; originals are never downloaded for this action.").font(.caption).foregroundStyle(.secondary)
                    Button("Description queue…") { commands.run(.descriptionQueue) }
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $showLocalDescriptionQueue) { DescriptionQueueView(appState: appState, onClose: { showLocalDescriptionQueue = false }) }
    }
}
