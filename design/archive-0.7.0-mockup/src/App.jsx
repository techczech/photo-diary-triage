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

const trips = [
  {
    id: "thurne",
    title: "Thurne · 4 August",
    date: "4 August 2013",
    sortKey: "2013-08-04",
    location: "Thurne, Norfolk",
    year: 2013,
    walks: 2,
    photos: 184,
    image: "/archive-covers/thurne.jpg",
  },
  {
    id: "czech",
    title: "Czech Republic Visit",
    date: "29 August – 5 September 2013",
    sortKey: "2013-09-05",
    location: "Prague and North Bohemia",
    year: 2013,
    walks: 9,
    photos: 612,
    image: "/archive-covers/prague.jpg",
  },
  {
    id: "norwich",
    title: "Norwich Morning Walk",
    date: "30 October 2013",
    sortKey: "2013-10-30",
    location: "Norwich, Norfolk",
    year: 2013,
    walks: 1,
    photos: 126,
    image: "/archive-covers/norwich.jpg",
  },
  {
    id: "st-bennets",
    title: "St Benet’s Abbey in Autumn",
    date: "19 October 2013",
    sortKey: "2013-10-19",
    location: "Ludham, Norfolk",
    year: 2013,
    walks: 1,
    photos: 94,
    image: "/archive-covers/st-bennets.jpg",
  },
  {
    id: "womack",
    title: "Womack Water",
    date: "10 November 2013",
    sortKey: "2013-11-10",
    location: "Ludham, Norfolk",
    year: 2013,
    walks: 1,
    photos: 138,
    image: "/archive-covers/womack.jpg",
  },
  {
    id: "broads",
    title: "Broads Trip",
    date: "5–9 July 2013",
    sortKey: "2013-07-09",
    location: "Norfolk Broads",
    year: 2013,
    walks: 6,
    photos: 487,
    image: "/archive-covers/broads.jpg",
  },
  {
    id: "horsey",
    title: "Horsey Trip with Seals",
    date: "14 April 2013",
    sortKey: "2013-04-14",
    location: "Horsey, Norfolk",
    year: 2013,
    walks: 2,
    photos: 203,
    image: "/archive-covers/horsey.jpg",
  },
  {
    id: "whitlingham",
    title: "Whitlingham Broad · Indian Summer",
    date: "24 October 2013",
    sortKey: "2013-10-24",
    location: "Whitlingham, Norfolk",
    year: 2013,
    walks: 1,
    photos: 116,
    image: "/archive-covers/whitlingham.jpg",
  },
  {
    id: "ranworth",
    title: "Cockshoot and Ranworth",
    date: "29 April 2013",
    sortKey: "2013-04-29",
    location: "Ranworth, Norfolk",
    year: 2013,
    walks: 2,
    photos: 172,
    image: "/archive-covers/ranworth.jpg",
  },
];

const yearRows = [
  [2026, 4],
  [2025, 8],
  [2024, 7],
  [2023, 8],
  [2022, 7],
  [2021, 7],
  [2020, 8],
  [2019, 11],
  [2018, 10],
  [2017, 13],
  [2016, 7],
  [2015, 12],
  [2014, 22],
  [2013, 46],
  [2012, 11],
  [2011, 12],
  [2010, 19],
  [2009, 12],
  [2008, 27],
  [2007, 5],
];

const commands = [
  ["Search the Archive", "⌘⇧F"],
  ["Show Timeline", "⌘1"],
  ["Show Contact Sheet", "⌘2"],
  ["Open selected Trip", "↩"],
  ["Selected Trip actions", "⌘K"],
  ["Show Trip inspector", "⌘P"],
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
  const [selectedId, setSelectedId] = useState("thurne");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState("date");
  const [selectedYear, setSelectedYear] = useState("all");
  const [inspectorOpen, setInspectorOpen] = useState(false);
  const [openSurface, setOpenSurface] = useState(null);
  const [toast, setToast] = useState("");
  const searchRef = useRef(null);
  const contentRef = useRef(null);

  const filtered = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    const result = trips.filter((trip) => {
      const inYear = selectedYear === "all" || trip.year === selectedYear;
      const matches =
        !normalized ||
        [trip.title, trip.date, trip.location, String(trip.year)]
          .join(" ")
          .toLocaleLowerCase()
          .includes(normalized);
      return inYear && matches;
    });
    return result.toSorted((a, b) =>
      sort === "title" ? a.title.localeCompare(b.title) : b.sortKey.localeCompare(a.sortKey),
    );
  }, [query, selectedYear, sort]);

  const selectedTrip = trips.find((trip) => trip.id === selectedId) || trips[0];

  useEffect(() => {
    localStorage.setItem("walkfolio-archive-view", view);
  }, [view]);

  useEffect(() => {
    if (filtered.length && !filtered.some((trip) => trip.id === selectedId)) {
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

      const current = Math.max(0, filtered.findIndex((trip) => trip.id === selectedId));
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
          document.querySelector(`[data-trip="${filtered[next].id}"]`)?.scrollIntoView({
            block: "nearest",
          });
        });
      }
      if (event.key === "Enter") {
        event.preventDefault();
        setOpenSurface("trip");
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
        <button className="toolbar-button finder-button" onClick={() => showToast("Would open the selected Trip in Finder.")}>
          <FolderOpen size={16} />
          <span>Open in Finder</span>
        </button>
        <label className="search-field">
          <Search size={16} aria-hidden="true" />
          <input
            ref={searchRef}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search photos, Walks and Trips"
            aria-label="Search photos, Walks and Trips"
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
          className={`sidebar-trip ${selectedYear === "all" ? "selected" : ""}`}
          onClick={() => setSelectedYear("all")}
        >
          <Image size={17} />
          <span>Trips</span>
          <span className="count">184</span>
        </button>
        <p className="sidebar-label">Years</p>
        <div className="year-list">
          {yearRows.map(([year, count]) => (
            <button
              key={year}
              className={selectedYear === year ? "selected" : ""}
              onClick={() => setSelectedYear(year)}
            >
              <span>{year}</span>
              <span className="count">{count}</span>
            </button>
          ))}
        </div>
        <div className="sidebar-footer">
          <Archive size={17} />
          <div>
            <strong>Archive Index</strong>
            <span>184 Trips · 23,572 Walks</span>
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
              {query && <span>Search results</span>}
            </div>
            <h1>{query ? `Results for “${query}”` : selectedYear === "all" ? "Trips" : String(selectedYear)}</h1>
            <p>
              {filtered.length} {filtered.length === 1 ? "Trip" : "Trips"}
              {!query && " in chronological order"}
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
          aria-label={`${view === "timeline" ? "Timeline" : "Contact Sheet"} of Trips`}
        >
          {!filtered.length ? (
            <div className="empty-state">
              <Search size={34} />
              <h2>No Trips match this search</h2>
              <p>Try a place, date, Trip title, or clear the current filters.</p>
              <button className="primary-button" onClick={() => { setQuery(""); setSelectedYear("all"); }}>
                Clear search and filters
              </button>
            </div>
          ) : view === "timeline" ? (
            <div className="timeline-list">
              <h2 className="year-heading">2013</h2>
              {filtered.map((trip) => (
                <button
                  key={trip.id}
                  data-trip={trip.id}
                  className={`timeline-row ${selectedId === trip.id ? "selected" : ""}`}
                  onClick={() => setSelectedId(trip.id)}
                  onDoubleClick={() => setOpenSurface("trip")}
                >
                  <img src={trip.image} alt="" />
                  <div className="trip-copy">
                    <strong>{trip.title}</strong>
                    <Meta icon={CalendarDays}>{trip.date}</Meta>
                    <Meta icon={MapPin}>{trip.location}</Meta>
                  </div>
                  <div className="trip-counts">
                    <Meta icon={Footprints}>{trip.walks} {trip.walks === 1 ? "Walk" : "Walks"}</Meta>
                    <Meta icon={Image}>{trip.photos} photos</Meta>
                  </div>
                  <ChevronRight size={17} className="disclosure" />
                </button>
              ))}
            </div>
          ) : (
            <div className="contact-sheet">
              <h2 className="year-heading">2013</h2>
              <div className="tile-grid">
                {filtered.map((trip) => (
                  <button
                    key={trip.id}
                    data-trip={trip.id}
                    className={`trip-tile ${selectedId === trip.id ? "selected" : ""}`}
                    onClick={() => setSelectedId(trip.id)}
                    onDoubleClick={() => setOpenSurface("trip")}
                  >
                    <img src={trip.image} alt="" />
                    <span className="tile-title">{trip.title}</span>
                    <span className="tile-date">{trip.date}</span>
                    <span className="tile-counts">{trip.walks} {trip.walks === 1 ? "Walk" : "Walks"} · {trip.photos} photos</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        <footer className="statusbar">
          <span><Check size={13} /> Archive Index ready</span>
          <span>
            {view === "timeline" ? "Timeline" : "Contact Sheet"} · {filtered.length}{" "}
            {filtered.length === 1 ? "Trip" : "Trips"}
          </span>
          <span>Arrow keys move · Return opens</span>
        </footer>
      </section>

      {inspectorOpen && (
        <aside className="inspector">
          <header>
            <strong>Trip</strong>
            <button className="icon-button" onClick={() => setInspectorOpen(false)} aria-label="Close inspector">
              <X size={16} />
            </button>
          </header>
          <img src={selectedTrip.image} alt="" />
          <h2>{selectedTrip.title}</h2>
          <Meta icon={CalendarDays}>{selectedTrip.date}</Meta>
          <Meta icon={MapPin}>{selectedTrip.location}</Meta>
          <div className="inspector-stats">
            <div><strong>{selectedTrip.walks}</strong><span>Walks</span></div>
            <div><strong>{selectedTrip.photos}</strong><span>Photos</span></div>
          </div>
          <button className="primary-button" onClick={() => setOpenSurface("trip")}>Open Trip</button>
          <button className="secondary-button" onClick={() => setOpenSurface("actions")}>Trip actions</button>
        </aside>
      )}

      {openSurface === "trip" && (
        <Modal title={selectedTrip.title} onClose={() => setOpenSurface(null)} className="trip-modal">
          <img src={selectedTrip.image} alt="" />
          <div className="trip-modal-body">
            <div className="trip-summary">
              <Meta icon={CalendarDays}>{selectedTrip.date}</Meta>
              <Meta icon={MapPin}>{selectedTrip.location}</Meta>
              <Meta icon={Footprints}>{selectedTrip.walks} Walks</Meta>
              <Meta icon={Image}>{selectedTrip.photos} photos</Meta>
            </div>
            <p>This is the Trip destination. In Walkfolio it opens the Trip’s Walks, then each Walk opens its photo grid.</p>
            <button className="primary-button" onClick={() => { setOpenSurface(null); showToast("Trip navigation is represented, not implemented, in this mockup."); }}>
              Open Walks
            </button>
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
            <input autoFocus placeholder="Trip, Walk, year, or workspace" />
          </label>
          <div className="command-list">
            <button onClick={() => setOpenSurface(null)}><span>Archive · Trips</span><kbd>Current</kbd></button>
            <button onClick={() => setOpenSurface(null)}><span>Triage</span></button>
            <button onClick={() => setOpenSurface(null)}><span>Photo Logs</span></button>
          </div>
        </Modal>
      )}

      {openSurface === "actions" && (
        <Modal title={`Actions for ${selectedTrip.title}`} onClose={() => setOpenSurface(null)} className="action-modal">
          <div className="command-list">
            <button onClick={() => setOpenSurface("trip")}><span>Open Trip</span><kbd>↩</kbd></button>
            <button onClick={() => { setInspectorOpen(true); setOpenSurface(null); }}><span>Show inspector</span><kbd>⌘P</kbd></button>
            <button onClick={() => showToast("Would reveal this Trip in Finder.")}><span>Reveal in Finder</span></button>
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
