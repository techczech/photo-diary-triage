import SwiftUI

struct DescriptionQueueView: View {
    @ObservedObject var appState: AppState
    var onClose: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local descriptions").font(.title2)
            Text("Archived keepers first, then Walk and Trip summaries. Successful regeneration replaces the active search description and preserves earlier machine revisions.")
                .foregroundStyle(.secondary)
            HStack {
                Button(appState.isDescribing ? "Describing…" : "Resume / retry") { appState.startDescriptionResume() }.disabled(appState.isDescribing)
                Button("Cancel") { appState.cancelDescriptions() }.disabled(!appState.isDescribing)
                Button("Discard failed batches") { Task { await appState.discardFailedDescriptions() } }.disabled(appState.isDescribing)
                Spacer()
                Button("Close") { if let onClose { onClose() } else { appState.showDescriptionQueue = false } }.keyboardShortcut(.cancelAction)
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

struct ArchiveDescriptionControls: View {
    @ObservedObject var appState: AppState
    var body: some View {
                Menu {
                    Button("Describe selected material") { Task { await appState.describeCurrentMaterial() } }
                        .disabled(appState.contextualDescriptionTargets.isEmpty || appState.isDescribing)
                    Button("Regenerate selected material") { Task { await appState.describeCurrentMaterial(regenerate: true) } }
                        .disabled(appState.contextualDescriptionTargets.isEmpty || appState.isDescribing)
                    Button("Describe this Trip") { Task { await appState.describeCurrentTrip() } }
                        .disabled(appState.descriptionTripPath == nil || appState.isDescribing)
                    if let year = appState.descriptionYear {
                        Button("Describe archived material in \(year)") { Task { await appState.describeCurrentYear() } }.disabled(appState.isDescribing)
                    }
                    Divider()
                    Button("Description queue…") { Task { await appState.loadDescriptionQueue() } }
                } label: { Label(appState.isDescribing ? "Describing…" : "Describe", systemImage: "text.bubble") }
                .help("Describe canonical archived keepers with your selected local model")

        .sheet(isPresented: $appState.showDescriptionQueue) { DescriptionQueueView(appState: appState) }
    }
}
