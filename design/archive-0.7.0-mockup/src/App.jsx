import { useEffect, useMemo, useRef, useState } from "react";
import {
  Archive,
  CalendarDays,
  Check,
  ChevronDown,
  ChevronRight,
  CircleHelp,
  Command,
  Footprints,
  Folder,
  FolderOpen,
  Grid2X2,
  Image,
  Info,
  List,
  MapPin,
  Menu,
  PanelLeft,
  PanelRight,
  Search,
  Settings,
  SlidersHorizontal,
  X,
} from "lucide-react";

const archiveItems = [
  {
    id: "river-walk-2025",
    kind: "trip",
    title: "River Walk",
    date: "3 July 2025",
    sortKey: "2025-07-03",
    location: "Location not set",
    year: 2025,
    walks: 1,
    photos: 199,
    image: "/archive-covers/2025-july.jpg",
  },
  {
    id: "may-evening-2025",
    kind: "trip",
    title: "May Evening",
    date: "29 May 2025",
    sortKey: "2025-05-29",
    location: "Location not set",
    year: 2025,
    walks: 1,
    photos: 15,
    image: "/archive-covers/2025-may.jpg",
  },
  {
    id: "woodland-flight-2025",
    kind: "trip",
    title: "Woodland Flight",
    date: "13 April 2025",
    sortKey: "2025-04-13",
    location: "Location not set",
    year: 2025,
    walks: 1,
    photos: 25,
    image: "/archive-covers/2025-april.jpg",
  },
  {
    id: "heron-water-2025",
    kind: "trip",
    title: "Heron Water",
    date: "24 March 2025",
    sortKey: "2025-03-24",
    location: "Location not set",
    year: 2025,
    walks: 1,
    photos: 19,
    image: "/archive-covers/2025-march.jpg",
  },
  {
    id: "hill-walk-2024",
    kind: "trip",
    title: "Hill Walk",
    date: "4 July 2024",
    sortKey: "2024-07-04",
    location: "Location not set",
    year: 2024,
    walks: 1,
    photos: 2,
    image: "/archive-covers/2024-july.jpg",
  },
  {
    id: "misty-water-2024",
    kind: "trip",
    title: "Misty Water",
    date: "31 October 2024",
    sortKey: "2024-10-31",
    location: "Location not set",
    year: 2024,
    walks: 1,
    photos: 55,
    image: "/archive-covers/2024-october.jpg",
  },
  {
    id: "herons-in-the-trees-2024",
    kind: "trip",
    title: "Herons in the Trees",
    date: "25 May 2024",
    sortKey: "2024-05-25",
    location: "Location not set",
    year: 2024,
    walks: 1,
    photos: 3,
    image: "/archive-covers/2024-may.jpg",
  },
  {
    id: "march-fields-2024",
    kind: "trip",
    title: "March Fields",
    date: "31 March 2024",
    sortKey: "2024-03-31",
    location: "Location not set",
    year: 2024,
    walks: 1,
    photos: 20,
    image: "/archive-covers/2024-march.jpg",
  },
  {
    id: "winter-garden-2023",
    kind: "trip",
    title: "Winter Garden",
    date: "4 December 2023",
    sortKey: "2023-12-04",
    location: "Location not set",
    year: 2023,
    walks: 1,
    photos: 6,
    image: "/archive-covers/2023-december.jpg",
  },
  {
    id: "wales-coast-2022",
    kind: "trip",
    title: "Wales Coast",
    date: "September 2022",
    sortKey: "2022-09-30",
    location: "Wales",
    year: 2022,
    walks: 5,
    photos: 217,
    image: "/archive-covers/2022-wales.jpg",
  },
  {
    id: "thurne",
    kind: "folder",
    title: "Thurne · 4 August",
    date: "4 August 2013",
    sortKey: "2013-08-04",
    location: "Thurne, Norfolk",
    year: 2013,
    photos: 184,
    path: "2013 / Thurne 4 August",
    image: "/archive-covers/thurne.jpg",
  },
  {
    id: "czech",
    kind: "folder",
    title: "Czech Republic Visit",
    date: "29 August – 5 September 2013",
    sortKey: "2013-09-05",
    location: "Prague and North Bohemia",
    year: 2013,
    photos: 612,
    path: "2013 / Czech Republic Visit",
    image: "/archive-covers/prague.jpg",
  },
  {
    id: "norwich",
    kind: "folder",
    title: "Norwich Morning Walk",
    date: "30 October 2013",
    sortKey: "2013-10-30",
    location: "Norwich, Norfolk",
    year: 2013,
    photos: 126,
    path: "2013 / Norwich Morning Walk",
    image: "/archive-covers/norwich.jpg",
  },
  {
    id: "st-bennets",
    kind: "folder",
    title: "St Benet’s Abbey in Autumn",
    date: "19 October 2013",
    sortKey: "2013-10-19",
    location: "Ludham, Norfolk",
    year: 2013,
    photos: 94,
    path: "2013 / St Benet’s Abbey in Autumn",
    image: "/archive-covers/st-bennets.jpg",
  },
  {
    id: "womack",
    kind: "folder",
    title: "Womack Water",
    date: "10 November 2013",
    sortKey: "2013-11-10",
    location: "Ludham, Norfolk",
    year: 2013,
    photos: 138,
    path: "2013 / Womack Water",
    image: "/archive-covers/womack.jpg",
  },
  {
    id: "broads",
    kind: "folder",
    title: "Broads Trip",
    date: "5–9 July 2013",
    sortKey: "2013-07-09",
    location: "Norfolk Broads",
    year: 2013,
    photos: 487,
    path: "2013 / Broads Trip",
    image: "/archive-covers/broads.jpg",
  },
  {
    id: "horsey",
    kind: "folder",
    title: "Horsey Trip with Seals",
    date: "14 April 2013",
    sortKey: "2013-04-14",
    location: "Horsey, Norfolk",
    year: 2013,
    photos: 203,
    path: "2013 / Horsey Trip with Seals",
    image: "/archive-covers/horsey.jpg",
  },
  {
    id: "whitlingham",
    kind: "folder",
    title: "Whitlingham Broad · Indian Summer",
    date: "24 October 2013",
    sortKey: "2013-10-24",
    location: "Whitlingham, Norfolk",
    year: 2013,
    photos: 116,
    path: "2013 / Whitlingham Broad – Indian Summer",
    image: "/archive-covers/whitlingham.jpg",
  },
  {
    id: "ranworth",
    kind: "folder",
    title: "Cockshoot and Ranworth",
    date: "29 April 2013",
    sortKey: "2013-04-29",
    location: "Ranworth, Norfolk",
    year: 2013,
    photos: 172,
    path: "2013 / Cockshoot and Ranworth",
    image: "/archive-covers/ranworth.jpg",
  },
];

const tripCount = archiveItems.filter((item) => item.kind === "trip").length;
const folderCount = archiveItems.filter((item) => item.kind === "folder").length;
const walkCount = archiveItems.reduce(
  (total, item) => total + (item.kind === "trip" ? item.walks || 0 : 0),
  0,
);
const yearRows = [...new Set(archiveItems.map((item) => item.year))]
  .sort((a, b) => b - a)
  .map((year) => [year, archiveItems.filter((item) => item.year === year).length]);

const commands = [
  ["Search the Archive", "⌘⇧F"],
  ["Show Timeline", "⌘1"],
  ["Show Contact Sheet", "⌘2"],
  ["Open selected item", "↩"],
  ["Selected item actions", "⌘K"],
  ["Show item inspector", "⌘P"],
  ["Navigation switcher", "⌘⇧K"],
  ["Settings", "⌘,"],
  ["Shortcut guide", "⌘/"],
];

function Meta({ icon: Icon, children }) {
  return (
    <span className="meta">
      <Icon aria-hidden="true" size={15} strokeWidth={1.8} />
      {children}
    </span>
  );
}

function EntryBadge({ kind }) {
  const isFolder = kind === "folder";
  return (
    <span className={`entry-badge ${kind}`}>
      {isFolder ? <Folder size={12} aria-hidden="true" /> : <Footprints size={12} aria-hidden="true" />}
      {isFolder ? "Unorganised folder" : "Trip"}
    </span>
  );
}

function Modal({ title, onClose, children, className = "" }) {
  return (
    <div className="scrim" role="presentation" onMouseDown={onClose}>
      <section
        className={`modal ${className}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="modal-header">
          <h2>{title}</h2>
          <button className="icon-button" onClick={onClose} aria-label={`Close ${title}`}>
            <X size={17} />
          </button>
        </header>
        {children}
      </section>
    </div>
  );
}

export function App() {
  const [view, setView] = useState(() => localStorage.getItem("walkfolio-archive-view") || "timeline");
  const [selectedId, setSelectedId] = useState("river-walk-2025");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState("date");
  const [selectedYear, setSelectedYear] = useState("all");
  const [selectedKind, setSelectedKind] = useState("all");
  const [inspectorOpen, setInspectorOpen] = useState(false);
  const [openSurface, setOpenSurface] = useState(null);
  const [toast, setToast] = useState("");
  const searchRef = useRef(null);
  const contentRef = useRef(null);

  const filtered = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    const result = archiveItems.filter((item) => {
      const inYear = selectedYear === "all" || item.year === selectedYear;
      const isSelectedKind = selectedKind === "all" || item.kind === selectedKind;
      const matches =
        !normalized ||
        [item.title, item.date, item.location, item.path, item.kind, String(item.year)]
          .join(" ")
          .toLocaleLowerCase()
          .includes(normalized);
      return inYear && isSelectedKind && matches;
    });
    return result.toSorted((a, b) =>
      sort === "title" ? a.title.localeCompare(b.title) : b.sortKey.localeCompare(a.sortKey),
    );
  }, [query, selectedKind, selectedYear, sort]);

  const selectedItem = archiveItems.find((item) => item.id === selectedId) || archiveItems[0];
  const groupedItems = useMemo(
    () =>
      [...new Set(filtered.map((item) => item.year))]
        .sort((a, b) => b - a)
        .map((year) => ({
          year,
          items: filtered.filter((item) => item.year === year),
        })),
    [filtered],
  );
  const filteredTrips = filtered.filter((item) => item.kind === "trip").length;
  const filteredFolders = filtered.filter((item) => item.kind === "folder").length;
  const visibleSummary = [
    `${filteredTrips} ${filteredTrips === 1 ? "Trip" : "Trips"}`,
    `${filteredFolders} unorganised ${filteredFolders === 1 ? "folder" : "folders"}`,
  ].join(" · ");

  useEffect(() => {
    localStorage.setItem("walkfolio-archive-view", view);
  }, [view]);

  useEffect(() => {
    if (filtered.length && !filtered.some((item) => item.id === selectedId)) {
      setSelectedId(filtered[0].id);
    }
  }, [filtered, selectedId]);

  useEffect(() => {
    const handleKey = (event) => {
      const isTyping = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
      const modifier = event.metaKey || event.ctrlKey;

      if (modifier && event.shiftKey && event.key.toLowerCase() === "f") {
        event.preventDefault();
        searchRef.current?.focus();
        return;
      }
      if (modifier && event.shiftKey && event.key.toLowerCase() === "p") {
        event.preventDefault();
        setOpenSurface("palette");
        return;
      }
      if (modifier && event.shiftKey && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpenSurface("navigator");
        return;
      }
      if (modifier && !event.shiftKey && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpenSurface("actions");
        return;
      }
      if (modifier && !event.shiftKey && event.key.toLowerCase() === "p") {
        event.preventDefault();
        setInspectorOpen((value) => !value);
        return;
      }
      if (modifier && event.key === "/") {
        event.preventDefault();
        setOpenSurface("shortcuts");
        return;
      }
      if (modifier && event.key === ",") {
        event.preventDefault();
        setOpenSurface("settings");
        return;
      }
      if (modifier && event.key === "1") {
        event.preventDefault();
        setView("timeline");
        return;
      }
      if (modifier && event.key === "2") {
        event.preventDefault();
        setView("grid");
        return;
      }
      if (event.key === "Escape") {
        setOpenSurface(null);
        return;
      }
      if (isTyping || openSurface || !filtered.length) return;

      const current = Math.max(0, filtered.findIndex((item) => item.id === selectedId));
      let next = current;
      if (view === "timeline") {
        if (event.key === "ArrowDown") next = Math.min(filtered.length - 1, current + 1);
        if (event.key === "ArrowUp") next = Math.max(0, current - 1);
      } else {
        const width = window.innerWidth;
        const columns = width > 1320 ? 4 : width > 1020 ? 3 : width > 760 ? 2 : 1;
        if (event.key === "ArrowRight") next = Math.min(filtered.length - 1, current + 1);
        if (event.key === "ArrowLeft") next = Math.max(0, current - 1);
        if (event.key === "ArrowDown") next = Math.min(filtered.length - 1, current + columns);
        if (event.key === "ArrowUp") next = Math.max(0, current - columns);
      }
      if (next !== current) {
        event.preventDefault();
        setSelectedId(filtered[next].id);
        requestAnimationFrame(() => {
          document.querySelector(`[data-entry="${filtered[next].id}"]`)?.scrollIntoView({
            block: "nearest",
          });
        });
      }
      if (event.key === "Enter") {
        event.preventDefault();
        setOpenSurface("item");
      }
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [filtered, openSurface, selectedId, view]);

  const changeView = (nextView) => {
    setView(nextView);
    requestAnimationFrame(() => contentRef.current?.focus());
  };

  const showToast = (message) => {
    setToast(message);
    window.setTimeout(() => setToast(""), 2200);
  };

  return (
    <main className={`app-shell ${inspectorOpen ? "with-inspector" : ""}`}>
      <header className="titlebar">
        <div className="window-controls" aria-hidden="true">
          <span className="traffic red" />
          <span className="traffic amber" />
          <span className="traffic green" />
        </div>
        <button className="toolbar-button sidebar-toggle" aria-label="Toggle sidebar">
          <PanelLeft size={17} />
        </button>
        <strong className="app-name">Walkfolio</strong>
        <nav className="workspace-switcher" aria-label="Workspace">
          <button className="active">Archive</button>
          <button onClick={() => showToast("Triage remains unchanged in this mockup.")}>Triage</button>
          <button onClick={() => showToast("Photo Logs remain unchanged in this mockup.")}>Photo Logs</button>
        </nav>
        <button
          className="toolbar-button finder-button"
          onClick={() => showToast(`Would reveal “${selectedItem.title}” in Finder.`)}
        >
          <FolderOpen size={16} />
          <span>Open in Finder</span>
        </button>
        <label className="search-field">
          <Search size={16} aria-hidden="true" />
          <input
            ref={searchRef}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search photos, Trips and folders"
            aria-label="Search photos, Trips and folders"
          />
          {query && (
            <button onClick={() => setQuery("")} aria-label="Clear search">
              <X size={14} />
            </button>
          )}
          <kbd>⌘⇧F</kbd>
        </label>
        <button className="icon-button" onClick={() => setOpenSurface("palette")} aria-label="Open command palette">
          <Command size={17} />
        </button>
        <button className="icon-button" onClick={() => setOpenSurface("settings")} aria-label="Open Settings">
          <Settings size={17} />
        </button>
        <button className="icon-button" onClick={() => setOpenSurface("shortcuts")} aria-label="Open shortcut guide">
          <CircleHelp size={17} />
        </button>
        <button className="icon-button" onClick={() => setInspectorOpen((value) => !value)} aria-label="Toggle inspector">
          <PanelRight size={17} />
        </button>
      </header>

      <aside className="sidebar">
        <div className="sidebar-heading">
          <Archive size={18} />
          <span>Archive</span>
        </div>
        <button
          className={`sidebar-trip ${selectedYear === "all" && selectedKind === "all" ? "selected" : ""}`}
          onClick={() => { setSelectedYear("all"); setSelectedKind("all"); }}
        >
          <Image size={17} />
          <span>All</span>
          <span className="count">{archiveItems.length}</span>
        </button>
        <p className="sidebar-label">Contents</p>
        <div className="kind-list">
          <button
            className={selectedKind === "trip" ? "selected" : ""}
            onClick={() => setSelectedKind(selectedKind === "trip" ? "all" : "trip")}
            aria-pressed={selectedKind === "trip"}
          >
            <Footprints size={14} />
            <span>Trips</span>
            <span className="count">{tripCount}</span>
          </button>
          <button
            className={selectedKind === "folder" ? "selected" : ""}
            onClick={() => setSelectedKind(selectedKind === "folder" ? "all" : "folder")}
            aria-pressed={selectedKind === "folder"}
          >
            <Folder size={14} />
            <span>Unorganised folders</span>
            <span className="count">{folderCount}</span>
          </button>
        </div>
        <p className="sidebar-label">Filter by year</p>
        <div className="year-list">
          {yearRows.map(([year, count]) => (
            <button
              key={year}
              className={selectedYear === year ? "selected" : ""}
              onClick={() => setSelectedYear(year)}
              aria-label={`Filter Archive by ${year}`}
            >
              <span>{year}</span>
              <span className="count">{count}</span>
            </button>
          ))}
        </div>
        <div className="sidebar-footer">
          <Archive size={17} />
          <div>
            <strong>Archive contents</strong>
            <span>{tripCount} Trips · {folderCount} folders · {walkCount} Walks</span>
          </div>
          <ChevronRight size={14} />
        </div>
      </aside>

      <section className="content">
        <header className="content-header">
          <div>
            <div className="eyebrow">
              <Archive size={15} />
              Archive
              {selectedYear !== "all" && <span>{selectedYear}</span>}
              {query && <span>Search results</span>}
            </div>
            <h1>{query ? `Results for “${query}”` : "Archive"}</h1>
            <p>
              {visibleSummary}
              {!query && selectedYear === "all" &&
                ` across ${groupedItems.length} ${groupedItems.length === 1 ? "year" : "years"}`}
              {!query && selectedYear !== "all" && " in this year"}
            </p>
          </div>
          <div className="content-controls">
            <label className="sort-control">
              <SlidersHorizontal size={14} />
              <span>Sort</span>
              <select value={sort} onChange={(event) => setSort(event.target.value)}>
                <option value="date">Newest first</option>
                <option value="title">Title</option>
              </select>
              <ChevronDown size={13} />
            </label>
            <div className="view-switcher" aria-label="Archive view">
              <button
                className={view === "timeline" ? "active" : ""}
                onClick={() => changeView("timeline")}
                aria-pressed={view === "timeline"}
              >
                <List size={15} />
                Timeline
              </button>
              <button
                className={view === "grid" ? "active" : ""}
                onClick={() => changeView("grid")}
                aria-pressed={view === "grid"}
              >
                <Grid2X2 size={15} />
                Contact Sheet
              </button>
            </div>
          </div>
        </header>

        <div
          ref={contentRef}
          className={`archive-content ${view}`}
          tabIndex={0}
          aria-label={`${view === "timeline" ? "Timeline" : "Contact Sheet"} of Archive entries`}
        >
          {!filtered.length ? (
            <div className="empty-state">
              <Search size={34} />
              <h2>No Archive items match</h2>
              <p>Try a place, date, Trip, folder name, or clear the current filters.</p>
              <button className="primary-button" onClick={() => { setQuery(""); setSelectedYear("all"); setSelectedKind("all"); }}>
                Clear search and filters
              </button>
            </div>
          ) : view === "timeline" ? (
            <div className="timeline-list">
              {groupedItems.map((group) => (
                <section className="year-group" key={group.year}>
                  <h2 className="year-heading">{group.year}</h2>
                  {group.items.map((item) => (
                    <button
                      key={item.id}
                      data-entry={item.id}
                      className={`timeline-row ${item.kind} ${selectedId === item.id ? "selected" : ""}`}
                      onClick={() => setSelectedId(item.id)}
                      onDoubleClick={() => setOpenSurface("item")}
                    >
                      <img src={item.image} alt="" />
                      <div className="trip-copy">
                        <EntryBadge kind={item.kind} />
                        <strong>{item.title}</strong>
                        <Meta icon={CalendarDays}>{item.date}</Meta>
                        <Meta icon={item.kind === "trip" ? MapPin : FolderOpen}>
                          {item.kind === "trip" ? item.location : item.path}
                        </Meta>
                      </div>
                      <div className="trip-counts">
                        {item.kind === "trip" ? (
                          <Meta icon={Footprints}>{item.walks} {item.walks === 1 ? "Walk" : "Walks"}</Meta>
                        ) : (
                          <Meta icon={Folder}>Folder</Meta>
                        )}
                        <Meta icon={Image}>{item.photos} photos</Meta>
                      </div>
                      <ChevronRight size={17} className="disclosure" />
                    </button>
                  ))}
                </section>
              ))}
            </div>
          ) : (
            <div className="contact-sheet">
              {groupedItems.map((group) => (
                <section className="year-group" key={group.year}>
                  <h2 className="year-heading">{group.year}</h2>
                  <div className="tile-grid">
                    {group.items.map((item) => (
                      <button
                        key={item.id}
                        data-entry={item.id}
                        className={`trip-tile ${item.kind} ${selectedId === item.id ? "selected" : ""}`}
                        onClick={() => setSelectedId(item.id)}
                        onDoubleClick={() => setOpenSurface("item")}
                      >
                        <img src={item.image} alt="" />
                        <EntryBadge kind={item.kind} />
                        <span className="tile-title">{item.title}</span>
                        <span className="tile-date">{item.date}</span>
                        <span className="tile-counts">
                          {item.kind === "trip"
                            ? `${item.walks} ${item.walks === 1 ? "Walk" : "Walks"} · ${item.photos} photos`
                            : `${item.photos} photos · Opens as a folder`}
                        </span>
                      </button>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          )}
        </div>

        <footer className="statusbar">
          <span><Check size={13} /> Archive ready</span>
          <span>{view === "timeline" ? "Timeline" : "Contact Sheet"} · {visibleSummary}</span>
          <span>Arrow keys move · Return opens</span>
        </footer>
      </section>

      {inspectorOpen && (
        <aside className="inspector">
          <header>
            <strong>{selectedItem.kind === "trip" ? "Trip" : "Unorganised folder"}</strong>
            <button className="icon-button" onClick={() => setInspectorOpen(false)} aria-label="Close inspector">
              <X size={16} />
            </button>
          </header>
          <img src={selectedItem.image} alt="" />
          <h2>{selectedItem.title}</h2>
          <Meta icon={CalendarDays}>{selectedItem.date}</Meta>
          <Meta icon={selectedItem.kind === "trip" ? MapPin : FolderOpen}>
            {selectedItem.kind === "trip" ? selectedItem.location : selectedItem.path}
          </Meta>
          <div className="inspector-stats">
            {selectedItem.kind === "trip" ? (
              <div><strong>{selectedItem.walks}</strong><span>Walks</span></div>
            ) : (
              <div><strong>As is</strong><span>No file changes</span></div>
            )}
            <div><strong>{selectedItem.photos}</strong><span>Photos</span></div>
          </div>
          <button className="primary-button" onClick={() => setOpenSurface("item")}>
            {selectedItem.kind === "trip" ? "Open Trip" : "Open Photos"}
          </button>
          <button className="secondary-button" onClick={() => setOpenSurface("actions")}>
            {selectedItem.kind === "trip" ? "Trip actions" : "Folder actions"}
          </button>
        </aside>
      )}

      {openSurface === "item" && (
        <Modal title={selectedItem.title} onClose={() => setOpenSurface(null)} className="trip-modal">
          <img src={selectedItem.image} alt="" />
          <div className="trip-modal-body">
            <EntryBadge kind={selectedItem.kind} />
            <div className="trip-summary">
              <Meta icon={CalendarDays}>{selectedItem.date}</Meta>
              <Meta icon={selectedItem.kind === "trip" ? MapPin : FolderOpen}>
                {selectedItem.kind === "trip" ? selectedItem.location : selectedItem.path}
              </Meta>
              {selectedItem.kind === "trip" && (
                <Meta icon={Footprints}>{selectedItem.walks} {selectedItem.walks === 1 ? "Walk" : "Walks"}</Meta>
              )}
              <Meta icon={Image}>{selectedItem.photos} photos</Meta>
            </div>
            {selectedItem.kind === "trip" ? (
              <>
                <p>This Trip opens to its Walks. Each Walk then opens its photo grid.</p>
                <button className="primary-button" onClick={() => { setOpenSurface(null); showToast("Trip navigation is represented, not implemented, in this mockup."); }}>
                  Open Walks
                </button>
              </>
            ) : (
              <>
                <p>This folder opens directly to its photo grid. Browsing it does not move, rename, or rewrite anything.</p>
                <div className="modal-actions">
                  <button className="primary-button" onClick={() => { setOpenSurface(null); showToast("Folder photo browsing is represented, not implemented, in this mockup."); }}>
                    Open Photos
                  </button>
                  <button className="secondary-button" onClick={() => { setOpenSurface(null); showToast("Organisation would begin as a separate, reviewable action."); }}>
                    Organise as a Trip…
                  </button>
                </div>
              </>
            )}
          </div>
        </Modal>
      )}

      {openSurface === "palette" && (
        <Modal title="Commands" onClose={() => setOpenSurface(null)} className="command-modal">
          <label className="palette-search">
            <Search size={16} />
            <input autoFocus placeholder="Type a command" />
          </label>
          <div className="command-list">
            {commands.map(([label, shortcut]) => (
              <button key={label} onClick={() => setOpenSurface(null)}>
                <span>{label}</span><kbd>{shortcut}</kbd>
              </button>
            ))}
          </div>
        </Modal>
      )}

      {openSurface === "navigator" && (
        <Modal title="Go to" onClose={() => setOpenSurface(null)} className="command-modal">
          <label className="palette-search">
            <Search size={16} />
            <input autoFocus placeholder="Trip, folder, Walk, year, or workspace" />
          </label>
          <div className="command-list">
            <button onClick={() => setOpenSurface(null)}><span>Archive · All</span><kbd>Current</kbd></button>
            <button onClick={() => setOpenSurface(null)}><span>Triage</span></button>
            <button onClick={() => setOpenSurface(null)}><span>Photo Logs</span></button>
          </div>
        </Modal>
      )}

      {openSurface === "actions" && (
        <Modal title={`Actions for ${selectedItem.title}`} onClose={() => setOpenSurface(null)} className="action-modal">
          <div className="command-list">
            <button onClick={() => setOpenSurface("item")}>
              <span>{selectedItem.kind === "trip" ? "Open Trip" : "Open Photos"}</span><kbd>↩</kbd>
            </button>
            {selectedItem.kind === "folder" && (
              <button onClick={() => { setOpenSurface(null); showToast("Organisation would begin as a separate, reviewable action."); }}>
                <span>Organise as a Trip…</span>
              </button>
            )}
            <button onClick={() => { setInspectorOpen(true); setOpenSurface(null); }}><span>Show inspector</span><kbd>⌘P</kbd></button>
            <button onClick={() => showToast(`Would reveal “${selectedItem.title}” in Finder.`)}><span>Reveal in Finder</span></button>
          </div>
        </Modal>
      )}

      {openSurface === "shortcuts" && (
        <Modal title="Keyboard shortcuts" onClose={() => setOpenSurface(null)} className="shortcut-modal">
          <div className="shortcut-list">
            {commands.map(([label, shortcut]) => (
              <div key={label}><span>{label}</span><kbd>{shortcut}</kbd></div>
            ))}
          </div>
          <p className="modal-note">Every command is available from the command palette and can be rebound in Settings.</p>
        </Modal>
      )}

      {openSurface === "settings" && (
        <Modal title="Settings" onClose={() => setOpenSurface(null)} className="settings-modal">
          <div className="settings-sidebar">
            <button className="active"><SlidersHorizontal size={15} /> Archive browsing</button>
            <button><Command size={15} /> Keyboard</button>
            <button><Info size={15} /> Changes</button>
          </div>
          <div className="settings-content">
            <label className="setting-row">
              <span><strong>Default Archive view</strong><small>Used when no remembered view exists.</small></span>
              <select value={view} onChange={(event) => setView(event.target.value)}>
                <option value="timeline">Timeline</option>
                <option value="grid">Contact Sheet</option>
              </select>
            </label>
            <label className="setting-row">
              <span><strong>Show cover photographs</strong><small>Turn off for the fastest browsing.</small></span>
              <input type="checkbox" defaultChecked />
            </label>
            <div className="settings-history">
              <strong>Recent settings changes</strong>
              <p>No changes in this prototype.</p>
            </div>
          </div>
        </Modal>
      )}

      {toast && <div className="toast" role="status">{toast}</div>}
    </main>
  );
}
