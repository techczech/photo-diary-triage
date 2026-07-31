import AppKit
import SwiftUI

struct ArchiveSidebarView: View {
    let appState: AppState
    @ObservedObject var state: ArchiveBrowserState

    var body: some View {
        let snapshot = state.snapshot
        List {
            Section {
                archiveFilterRow(
                    title: "Archive",
                    systemImage: "photo.stack",
                    isSelected: snapshot.kindFilter == .all && snapshot.yearFilter == nil
                ) {
                    appState.setArchiveKindFilter(.all)
                    appState.setArchiveYearFilter(nil)
                }
            }

            Section("Entry type") {
                archiveFilterRow(
                    title: "All entries",
                    systemImage: "square.stack.3d.up",
                    count: snapshot.totalEntryCount,
                    isSelected: snapshot.kindFilter == .all
                ) {
                    appState.setArchiveKindFilter(.all)
                }
                archiveFilterRow(
                    title: "Trips",
                    systemImage: "figure.walk",
                    count: snapshot.tripCount,
                    isSelected: snapshot.kindFilter == .trips
                ) {
                    appState.setArchiveKindFilter(.trips)
                }
                archiveFilterRow(
                    title: "Unorganised folders",
                    systemImage: "folder",
                    count: snapshot.unorganisedFolderCount,
                    isSelected: snapshot.kindFilter == .unorganisedFolders
                ) {
                    appState.setArchiveKindFilter(.unorganisedFolders)
                }
            }

            Section("Year filters") {
                archiveFilterRow(
                    title: "All years",
                    systemImage: "calendar",
                    count: snapshot.yearFilters.reduce(0) { $0 + $1.count },
                    isSelected: snapshot.yearFilter == nil
                ) {
                    appState.setArchiveYearFilter(nil)
                }
                ForEach(snapshot.yearFilters) { year in
                    archiveFilterRow(
                        title: year.year,
                        systemImage: nil,
                        count: year.count,
                        isSelected: snapshot.yearFilter == year.year
                    ) {
                        appState.setArchiveYearFilter(year.year)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: snapshot.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    .foregroundStyle(snapshot.errorMessage == nil ? Color.secondary : Color.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.isLoading ? "Refreshing Archive" : "Archive Index")
                        .font(.caption.weight(.semibold))
                    Text(snapshot.errorMessage ?? "\(snapshot.entries.count) visible entries")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    appState.reloadArchiveCatalogue()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh the Archive catalogue")
            }
            .padding(10)
            .background(.bar)
        }
    }

    private func archiveFilterRow(
        title: String,
        systemImage: String?,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 16)
                } else {
                    Color.clear.frame(width: 16, height: 1)
                }
                Text(title)
                Spacer()
                if let count {
                    Text(count.formatted())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
    }

}

struct ArchiveMainPaneView: View {
    let appState: AppState
    @ObservedObject var state: ArchiveBrowserState
    @FocusState private var hasKeyboardFocus: Bool

    var body: some View {
        let snapshot = state.snapshot
        VStack(alignment: .leading, spacing: 0) {
            archiveHeader(snapshot)
            Divider()

            Group {
                if snapshot.isLoading && snapshot.entries.isEmpty {
                    ProgressView("Reading the Archive Index and folders…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = snapshot.errorMessage, snapshot.entries.isEmpty {
                    ContentUnavailableView(
                        "Archive unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if snapshot.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No matching Archive entries", systemImage: "magnifyingglass")
                    } description: {
                        Text("Clear search or choose All entries and All years.")
                    } actions: {
                        Button("Clear filters") {
                            appState.updateArchiveSearch("")
                            appState.setArchiveKindFilter(.all)
                            appState.setArchiveYearFilter(nil)
                        }
                    }
                } else if snapshot.viewMode == .timeline {
                    archiveTimeline(snapshot)
                } else {
                    archiveContactSheet(snapshot)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .onAppear {
            hasKeyboardFocus = true
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                appState.moveArchiveSelection(horizontal: 0, vertical: -1)
            case .down:
                appState.moveArchiveSelection(horizontal: 0, vertical: 1)
            case .left:
                appState.moveArchiveSelection(horizontal: -1, vertical: 0)
            case .right:
                appState.moveArchiveSelection(horizontal: 1, vertical: 0)
            default:
                break
            }
        }
        .onKeyPress(.return) {
            appState.openSelectedArchiveItem()
            return .handled
        }
        .onTapGesture {
            hasKeyboardFocus = true
        }
    }

    private func archiveHeader(_ snapshot: ArchiveBrowserSnapshot) -> some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.yearFilter.map { "Archive / \($0)" } ?? "Archive")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Archive")
                    .font(.largeTitle.weight(.semibold))
                Text(visibleSummary(snapshot))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Sort", selection: Binding(
                get: { snapshot.sort },
                set: { appState.setArchiveSort($0) }
            )) {
                ForEach(ArchiveBrowseSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .frame(width: 150)

            Picker("Archive view", selection: Binding(
                get: { snapshot.viewMode },
                set: { appState.setArchiveBrowseViewMode($0) }
            )) {
                Label("Timeline", systemImage: "list.bullet").tag(ArchiveBrowseViewMode.timeline)
                Label("Contact Sheet", systemImage: "square.grid.2x2").tag(ArchiveBrowseViewMode.contactSheet)
            }
            .pickerStyle(.segmented)
            .frame(width: 270)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func archiveTimeline(_ snapshot: ArchiveBrowserSnapshot) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(grouped(snapshot.entries), id: \.year) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                ArchiveTimelineRow(
                                    entry: entry,
                                    archiveRoot: appState.settings.archiveRoot,
                                    showPreview: snapshot.showPreviews,
                                    isSelected: snapshot.selectedEntryID == entry.id,
                                    onSelect: { appState.selectArchiveEntry(entry.id) },
                                    onOpen: {
                                        appState.selectArchiveEntry(entry.id)
                                        appState.openSelectedArchiveItem()
                                    },
                                    onOrganise: entry.kind == .unorganisedFolder ? {
                                        appState.selectArchiveEntry(entry.id)
                                        appState.organiseSelectedUnorganisedFolder()
                                    } : nil
                                )
                                .id(entry.id)
                            }
                        } header: {
                            Text(group.year)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .background(.background)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .onChange(of: snapshot.selectedEntryID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func archiveContactSheet(_ snapshot: ArchiveBrowserSnapshot) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(grouped(snapshot.entries), id: \.year) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.year)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 14)],
                                alignment: .leading,
                                spacing: 18
                            ) {
                                ForEach(group.entries) { entry in
                                    ArchiveContactTile(
                                        entry: entry,
                                        archiveRoot: appState.settings.archiveRoot,
                                        showPreview: snapshot.showPreviews,
                                        isSelected: snapshot.selectedEntryID == entry.id,
                                        onSelect: { appState.selectArchiveEntry(entry.id) },
                                        onOpen: {
                                            appState.selectArchiveEntry(entry.id)
                                            appState.openSelectedArchiveItem()
                                        },
                                        onOrganise: entry.kind == .unorganisedFolder ? {
                                            appState.selectArchiveEntry(entry.id)
                                            appState.organiseSelectedUnorganisedFolder()
                                        } : nil
                                    )
                                    .id(entry.id)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .onChange(of: snapshot.selectedEntryID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func visibleSummary(_ snapshot: ArchiveBrowserSnapshot) -> String {
        let trips = snapshot.entries.filter { $0.kind == .trip }.count
        let folders = snapshot.entries.count - trips
        let search = snapshot.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = search.isEmpty ? "" : "Search “\(search)” · "
        return "\(prefix)\(trips) Trip\(trips == 1 ? "" : "s") · \(folders) unorganised folder\(folders == 1 ? "" : "s")"
    }

    private func grouped(_ entries: [ArchiveBrowseEntry]) -> [(year: String, entries: [ArchiveBrowseEntry])] {
        Dictionary(grouping: entries, by: \.year)
            .map { (year: $0.key, entries: $0.value) }
            .sorted { $0.year > $1.year }
    }
}

struct ArchiveTripPaneView: View {
    let appState: AppState
    @ObservedObject var state: ArchiveBrowserState
    @FocusState private var hasKeyboardFocus: Bool

    var body: some View {
        let snapshot = state.snapshot
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        appState.navigateToParent()
                    } label: {
                        Label("Archive", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Text(snapshot.selectedTrip?.title ?? "Trip")
                        .font(.largeTitle.weight(.semibold))
                    Text("\(snapshot.walks.count) Walk\(snapshot.walks.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            if snapshot.walks.isEmpty {
                ContentUnavailableView(
                    "No indexed Walks",
                    systemImage: "figure.walk",
                    description: Text("Rebuild the Archive Index if this Trip contains manifest-backed Walks.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 230, maximum: 340), spacing: 16)],
                            alignment: .leading,
                            spacing: 18
                        ) {
                            ForEach(snapshot.walks) { walk in
                                ArchiveWalkCard(
                                    walk: walk,
                                    archiveRoot: appState.settings.archiveRoot,
                                    showPreview: snapshot.showPreviews,
                                    isSelected: snapshot.selectedWalkID == walk.id
                                ) {
                                    appState.selectArchiveWalk(walk.id)
                                } onOpen: {
                                    appState.selectArchiveWalk(walk.id)
                                    appState.openSelectedArchiveItem()
                                }
                                .id(walk.id)
                            }
                        }
                        .padding(18)
                    }
                    .onChange(of: snapshot.selectedWalkID) { _, id in
                        guard let id else { return }
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .onAppear { hasKeyboardFocus = true }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                appState.moveArchiveSelection(horizontal: 0, vertical: -1)
            case .down:
                appState.moveArchiveSelection(horizontal: 0, vertical: 1)
            case .left:
                appState.moveArchiveSelection(horizontal: -1, vertical: 0)
            case .right:
                appState.moveArchiveSelection(horizontal: 1, vertical: 0)
            default:
                break
            }
        }
        .onKeyPress(.return) {
            appState.openSelectedArchiveItem()
            return .handled
        }
    }
}

private struct ArchiveTimelineRow: View {
    let entry: ArchiveBrowseEntry
    let archiveRoot: URL
    let showPreview: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onOrganise: (() -> Void)?

    var body: some View {
        HStack(spacing: 18) {
            ArchiveCoverView(
                thumbnailPath: entry.coverThumbnailPath,
                archiveRoot: archiveRoot,
                showPreview: showPreview,
                kind: entry.kind
            )
            .frame(width: 220, height: 118)

            VStack(alignment: .leading, spacing: 7) {
                ArchiveEntryKindBadge(kind: entry.kind)
                Text(entry.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Label(ArchiveDateText.range(start: entry.startDate, end: entry.endDate), systemImage: "calendar")
                    .foregroundStyle(.secondary)
                Label(entry.location ?? "Location not set", systemImage: entry.kind == .trip ? "mappin" : "folder")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                if entry.kind == .trip {
                    Label("\(entry.walkCount) Walk\(entry.walkCount == 1 ? "" : "s")", systemImage: "figure.walk")
                }
                Label("\(entry.photoCount) photo\(entry.photoCount == 1 ? "" : "s")", systemImage: "photo")
                if let onOrganise {
                    Button("Organise as a Trip…", action: onOrganise)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(7)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.11) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Open", action: onOpen)
            if let onOrganise {
                Button("Organise as a Trip…", action: onOrganise)
            }
        }
    }
}

private struct ArchiveContactTile: View {
    let entry: ArchiveBrowseEntry
    let archiveRoot: URL
    let showPreview: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onOrganise: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArchiveCoverView(
                thumbnailPath: entry.coverThumbnailPath,
                archiveRoot: archiveRoot,
                showPreview: showPreview,
                kind: entry.kind
            )
            .frame(height: 150)
            .overlay(alignment: .topLeading) {
                ArchiveEntryKindBadge(kind: entry.kind)
                    .padding(8)
            }

            Text(entry.title)
                .font(.headline)
                .lineLimit(1)
            Text(ArchiveDateText.range(start: entry.startDate, end: entry.endDate))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.kind == .trip
                ? "\(entry.walkCount) Walk\(entry.walkCount == 1 ? "" : "s") · \(entry.photoCount) photos"
                : "\(entry.photoCount) photos · \(entry.archiveRelativePath.replacingOccurrences(of: "/", with: " / "))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(6)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.11) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Open", action: onOpen)
            if let onOrganise {
                Button("Organise as a Trip…", action: onOrganise)
            }
        }
    }
}

private struct ArchiveWalkCard: View {
    let walk: ArchiveWalkSummary
    let archiveRoot: URL
    let showPreview: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArchiveCoverView(
                thumbnailPath: walk.coverThumbnailPath,
                archiveRoot: archiveRoot,
                showPreview: showPreview,
                kind: .trip
            )
            .frame(height: 170)
            Text(walk.title)
                .font(.headline)
            Label(ArchiveDateText.single(walk.date), systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(walk.location ?? "Location not set", systemImage: "mappin")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("\(walk.photoCount) photo\(walk.photoCount == 1 ? "" : "s")", systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(7)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.11) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
    }
}

private struct ArchiveEntryKindBadge: View {
    let kind: ArchiveBrowseEntryKind

    var body: some View {
        Label(kind.title, systemImage: kind == .trip ? "figure.walk" : "folder")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                kind == .trip ? Color(nsColor: .controlBackgroundColor) : Color.orange.opacity(0.14),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(kind == .trip ? Color.secondary.opacity(0.22) : Color.orange.opacity(0.35))
            }
    }
}

private struct ArchiveCoverView: View {
    let thumbnailPath: String?
    let archiveRoot: URL
    let showPreview: Bool
    let kind: ArchiveBrowseEntryKind

    var body: some View {
        Group {
            if showPreview,
               let thumbnailPath,
               let image = NSImage(contentsOf: archiveRoot.appendingPathComponent(thumbnailPath)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    Image(systemName: kind == .trip ? "photo.on.rectangle.angled" : "folder")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private enum ArchiveDateText {
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    static func single(_ date: Date?) -> String {
        date.map(full.string) ?? "Date not indexed"
    }

    static func range(start: Date?, end: Date?) -> String {
        guard let start else { return single(end) }
        guard let end, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return full.string(from: start)
        }
        return "\(full.string(from: start)) – \(full.string(from: end))"
    }
}
