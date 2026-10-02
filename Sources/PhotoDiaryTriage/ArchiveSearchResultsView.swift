import SwiftUI

struct ArchiveSearchResultsView: View {
    let appState: AppState
    let snapshot: ArchiveBrowserSnapshot
    let layout: ArchiveGridLayout
    let focusCards: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if !snapshot.searchResults.isEmpty {
                        Text("Matching photos · \(snapshot.searchResults.count)").font(.headline)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            ForEach(snapshot.searchResults) { photo in
                                ArchiveSearchPhotoCard(photo: photo, archiveRoot: appState.settings.archiveRoot,
                                    showPreview: snapshot.showPreviews,
                                    isSelected: snapshot.searchSelection == .photo(photo.id)) {
                                        focusCards(); appState.selectArchiveSearchResult(photo.id)
                                    } open: { appState.openArchiveSearchPhoto(photo) }
                                    .id(ArchiveSearchItemID.photo(photo.id))
                            }
                        }
                    }
                    Text("Matching Trips and folders · \(snapshot.entries.count)").font(.headline)
                    ForEach(snapshot.yearGroups, id: \.year) { group in
                        Text(group.year).font(.headline).foregroundStyle(.secondary)
                        if snapshot.viewMode == .timeline {
                            ForEach(group.entries) { entry in
                                ArchiveTimelineRow(entry: entry, archiveRoot: appState.settings.archiveRoot,
                                    showPreview: snapshot.showPreviews, isSelected: snapshot.searchSelection == .entry(entry.id),
                                    onSelect: { select(entry) }, onOpen: { open(entry) }, onOrganise: organise(entry))
                                    .id(ArchiveSearchItemID.entry(entry.id))
                            }
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                                ForEach(group.entries) { entry in
                                    ArchiveContactTile(entry: entry, archiveRoot: appState.settings.archiveRoot,
                                        showPreview: snapshot.showPreviews, isSelected: snapshot.searchSelection == .entry(entry.id),
                                        onSelect: { select(entry) }, onOpen: { open(entry) }, onOrganise: organise(entry))
                                        .id(ArchiveSearchItemID.entry(entry.id))
                                }
                            }
                        }
                    }
                }.padding(18)
            }
            .onChange(of: snapshot.searchSelection, initial: true) { _, id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0, maximum: layout.maximumCardWidth), spacing: layout.spacing), count: layout.columnCount)
    }
    private func select(_ entry: ArchiveBrowseEntry) { focusCards(); appState.selectArchiveEntry(entry.id) }
    private func open(_ entry: ArchiveBrowseEntry) { select(entry); appState.openSelectedArchiveItem() }
    private func organise(_ entry: ArchiveBrowseEntry) -> (() -> Void)? {
        guard entry.kind == .unorganisedFolder else { return nil }
        return { select(entry); appState.organiseSelectedUnorganisedFolder() }
    }
}

private struct ArchiveSearchPhotoCard: View {
    let photo: ArchivePhotoSummary
    let archiveRoot: URL
    let showPreview: Bool
    let isSelected: Bool
    let select: () -> Void
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArchiveCoverView(thumbnailPath: photo.thumbnailPath, archiveRoot: archiveRoot,
                showPreview: showPreview, kind: .trip).frame(height: 150)
            Text(photo.title).font(.headline).lineLimit(2)
            Text(photo.archiveRelativePath).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            if let location = photo.location { Text(location).font(.caption).lineLimit(1) }
            if let description = photo.aiDescription, !description.isEmpty {
                Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(9).frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.11) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: open)
        .onTapGesture(perform: select)
        .contextMenu { Button("Open matching photo", action: open) }
    }
}
