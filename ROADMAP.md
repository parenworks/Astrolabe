# Astrolabe — Development Roadmap

## Overview

Astrolabe is developed in phases, each delivering a usable increment. Every phase
builds on the previous one and can be used independently. The goal is to always
have a working application — never a half-built skeleton.

---

## Phase 0: Foundation (v0.1)

**Goal:** A running three-pane application with SQLite storage and basic object CRUD.

This phase proves the architecture works end-to-end: charmed-mcclim rendering a
real application with database-backed objects, presentation clicking, and command
input.

### Deliverables

- [x] **Project scaffold** — ASDF system, package, config
- [x] **Database layer** — SQLite3 connection, schema creation, migrations
- [x] **Core schema** — Tables for notes, tasks, projects, persons, tags, links, snippets, bookmarks, activity_log
- [x] **Object model** — CLOS classes mirroring the DB schema, load/save/delete operations for all types
- [x] **Presentation types** — `note`, `task`, `project`, `person`, `snippet` presentation types with click translators
- [x] **Application frame** — Three-pane layout (navigation | detail | interactor)
- [x] **Home view** — Navigation pane showing tasks, projects, notes, contacts, snippets
- [x] **Detail view** — Display all object types with linked objects and tags
- [x] **Core commands:**
  - `Capture Note [title]` — Create note, auto-link to current context
  - `Add Task [title]` — Create task with status/priority
  - `New Project [name]` — Create project
  - `Add Person [name]` — Add a contact
  - `Capture Snippet [content]` — Save a snippet
  - `Show [object]` — Display in detail pane (also via click)
  - `Complete Task [task]` — Mark done
  - `Delete Note/Task/Project/Person/Snippet` — Soft delete for all types
  - `Home` — Return to home view
- [x] **Click navigation** — Click any presentation to show it in detail pane
- [x] **Entry point** — `(astrolabe:run)` starts the app

### Technical Details

**Database schema (initial):**

```sql
-- Core object tables
CREATE TABLE notes (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    title      TEXT NOT NULL,
    body       TEXT DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT
);

CREATE TABLE tasks (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    title      TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'todo',   -- todo, active, done, cancelled
    priority   TEXT NOT NULL DEFAULT 'B',      -- A, B, C
    due_date   TEXT,                            -- ISO date or NULL
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT
);

CREATE TABLE projects (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    description TEXT DEFAULT '',
    status      TEXT NOT NULL DEFAULT 'active', -- active, paused, complete, archived
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at  TEXT
);

CREATE TABLE persons (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    email      TEXT,
    role       TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT
);

CREATE TABLE tags (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT NOT NULL UNIQUE,
    color TEXT  -- terminal color name: red, green, cyan, etc.
);

CREATE TABLE snippets (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    content    TEXT NOT NULL,
    source     TEXT,              -- where it came from (URL, file path, etc.)
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT
);

-- Tagging (many-to-many)
CREATE TABLE object_tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    object_type TEXT NOT NULL,    -- 'note', 'task', 'project', etc.
    object_id   INTEGER NOT NULL,
    tag_id      INTEGER NOT NULL REFERENCES tags(id),
    UNIQUE(object_type, object_id, tag_id)
);

-- Links between any objects (bidirectional)
CREATE TABLE links (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    source_type TEXT NOT NULL,
    source_id   INTEGER NOT NULL,
    target_type TEXT NOT NULL,
    target_id   INTEGER NOT NULL,
    relation    TEXT,             -- 'belongs-to', 'references', 'captured-from'
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(source_type, source_id, target_type, target_id, relation)
);

-- Full-text search index
CREATE VIRTUAL TABLE notes_fts USING fts5(title, body, content=notes, content_rowid=id);
CREATE VIRTUAL TABLE tasks_fts USING fts5(title, content=tasks, content_rowid=id);
CREATE VIRTUAL TABLE snippets_fts USING fts5(content, source, content=snippets, content_rowid=id);

-- Schema version tracking
CREATE TABLE schema_version (
    version    INTEGER NOT NULL,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Pane layout:**

```
(define-application-frame astrolabe ()
  (...)
  (:panes
   (nav-pane :application
             :display-function 'display-navigation
             :scroll-bars nil)
   (detail-pane :application
                :display-function 'display-detail
                :scroll-bars nil)
   (interactor :interactor
               :scroll-bars nil))
  (:layouts
   (default
    (vertically ()
      (5/6 (horizontally ()
             (1/3 nav-pane)
             (2/3 detail-pane)))
      (1/6 interactor)))))
```

**Presentation types:**

```lisp
(define-presentation-type note ())
(define-presentation-type task ())
(define-presentation-type project ())
(define-presentation-type person ())
(define-presentation-type tag ())
(define-presentation-type astrolabe-object ()
  :description "any Astrolabe object")
```

Each object displayed in the navigation or detail pane is wrapped in
`(with-output-as-presentation ...)` so it becomes clickable.

---

## Phase 1: Productivity Core (v0.2)

**Goal:** Make Astrolabe genuinely useful for daily task and note management.

### Deliverables

- [x] **Search** — Full-text search across all objects using FTS5
  - `Search [query]` command (also `C-s`)
  - Results displayed in navigation pane as clickable presentations
- [x] **Tagging** — Tag any object, filter by tag
  - `Tag [object] [tag-name]` command
  - `Untag [object] [tag-name]` command
  - `Filter Tag [tag]` — Show all objects with a given tag
  - Tags displayed in yellow on every detail view
- [x] **Linking** — Explicit links between objects
  - `Link [source] [target]` command
  - Detail view shows all linked objects
  - Navigate links by clicking
- [x] **Quick capture** — Single-key capture from any context
  - `C-n` capture a note, `C-t` add a task, `C-s` search, `C-h` home
  - Auto-links to whatever project is currently active
- [x] **Task views** — Filtered task lists
  - `Show Tasks` — All open tasks
  - `Show Tasks Today` — Tasks due today or overdue
  - Priority coloring (A=red, B=yellow, C=default)
- [x] **Note editing** — Basic inline note body editing
  - `Edit Note [note] [body]` — replace note body
  - `Append Note [note] [text]` — append to note body
- [x] **Project dashboard** — Rich project view
  - Shows priority, area, dates, description, notes, linked persons
  - Progress indicator (tasks done / total) with inline open tasks
- [x] **Timestamps and sorting** — Rich detail views with all fields (scheduled, effort, context, recurrence, subtasks)

---

## Phase 2: Navigation and Polish (v0.3)

**Goal:** Smooth, efficient navigation and a polished daily-driver experience.

### Deliverables

- [x] **Breadcrumb navigation** — Track navigation history, go back/forward
  - `Back` command (`C-b`), `Forward` command (`C-f`)
  - Breadcrumb trail displayed at top of navigation pane
- [x] **Fuzzy finder** — Quick jump to any object by typing partial name
  - `Go [partial-name]` command (`C-g`) with LIKE matching across all types
  - Single match jumps directly; multiple matches shown in nav pane
- [x] **Agenda view** — Daily planning view (`C-a`)
  - Today's tasks sorted by priority
  - Overdue tasks highlighted in red
  - Upcoming tasks (next 7 days)
  - Recent captures (last 24h)
- [x] **Bookmarks** — Pin frequently accessed objects
  - `Bookmark [object]` / `Unbookmark [object]` commands
  - Bookmarks section on home screen
- [x] **Status bar** — Persistent info line showing:
  - Current view/context
  - Open task count
  - Current time
- [x] **Color theme** — Consistent color scheme
  - Object type colors (notes=cyan, tasks=priority, projects=green, persons=magenta)
  - Priority colors (A=red, B=yellow, C/default=white)
  - Status markers (todo=[ ], active=[~], done=[x], cancelled=[-])
- [x] **Keyboard shortcuts** — Control-key accelerators
  - `C-n` note, `C-t` task, `C-s` search, `C-h` home
  - `C-b` back, `C-f` forward, `C-a` agenda, `C-g` go
- [x] **Confirmation dialogs** — Confirm before destructive actions (yes/no prompt on all deletes)

---

## Phase 3: Communication Integration (v0.4)

**Goal:** Bring messages and feeds into Astrolabe.

### Deliverables

- [ ] **XMPP integration** — Leverage CLabber for XMPP messaging
  - Conversation list in navigation pane
  - Message thread in detail pane
  - Link conversations to projects/persons
  - `Message [person]` command
- [ ] **RSS/Atom feeds** — Subscribe and read feeds
  - Feed list with unread counts
  - Article view in detail pane
  - Capture article as snippet or note
  - `Subscribe [url]` command
- [ ] **Notification system** — Unified notification area
  - New messages, feed items, overdue tasks
  - Notification count on home screen
  - `Show Notifications` command

---

## Phase 4: Automation and Scripting (v0.5)

**Goal:** Make every screen programmable and every workflow automatable.

### Deliverables

- [ ] **Custom commands** — User-defined commands loaded from `~/.astrolabe/commands.lisp`
- [ ] **Hooks** — Before/after hooks on object creation, modification, deletion
- [ ] **Templates** — Note/task templates for recurring patterns
  - `Capture Note :template daily-standup`
- [ ] **Shell integration** — Execute shell commands and capture output
  - `Shell [command]` — Run command, show output in detail pane
  - `SSH [host]` — Open SSH session (if host is a server object)
- [ ] **Export** — Export objects to various formats
  - `Export [object] markdown` — Export as Markdown
  - `Export [project] report` — Generate project report
- [ ] **Scheduled actions** — Timer-based reminders and recurring tasks
- [ ] **Batch operations** — Apply commands to multiple selected objects

---

## Phase 5: Knowledge and Intelligence (v0.6)

**Goal:** Local-first AI assistance for knowledge work.

### Deliverables

- [ ] **Local LLM integration** — Connect to local Ollama or llama.cpp
  - `Summarize [note]` — Generate summary
  - `Extract Tasks [note]` — Pull action items from text
  - `Rewrite [note]` — Improve writing
  - `Explain [snippet]` — Explain code or log entries
- [ ] **Semantic search** — Vector similarity search across notes
  - `Similar [object]` — Find related objects
- [ ] **Auto-tagging** — Suggest tags based on content
- [ ] **Daily digest** — AI-generated summary of the day's activity
- [ ] **Question answering** — Ask questions about your own data
  - `Ask [question]` — Search and synthesize from local data

---

## Phase 6: Extended Objects (v0.7+)

**Goal:** Expand the object model for more real-world use cases.

### Potential Additions

- [ ] **Server/Host** — SSH config, status checks, log tailing
- [ ] **Document** — File references with metadata, preview, version notes
- [ ] **Event/Meeting** — Calendar entries linked to projects/persons
- [ ] **Invoice/Contract** — Business document tracking
- [ ] **Ticket** — Issue tracking with status workflow
- [ ] **Repository** — Git repository references with recent commit display
- [ ] **Bookmark** — Web bookmarks with tags and notes
- [ ] **Habit** — Recurring habit tracking with streaks
- [ ] **Journal** — Daily journal entries (one per day, append-only)

---

## Design Principles

### Always Shippable

Every phase produces a working, usable application. There is no "infrastructure
phase" that doesn't produce user-visible value.

### Objects and Links Over Hierarchy

Astrolabe does not force a rigid hierarchy. A note can belong to multiple projects.
A task can reference multiple persons. A snippet can be linked to anything.
The link system provides flexible, emergent structure.

### Commands Over Menus

Every action is a named command. Commands are discoverable via tab completion.
Commands accept typed arguments. This makes the application both learnable and
automatable.

### Presentations Over Cursors

Objects on screen are presentations, not cursor-addressed lines. This means:
- Click any object to act on it
- The system knows what type of object you clicked
- Context-sensitive actions based on object type and current command

### Local-First Over Cloud

All data is in `~/.astrolabe/astrolabe.db`. Back it up with `cp`. Sync it with
`rsync`. Version it with `git`. No accounts, no servers, no subscriptions.

### Lisp All the Way Down

The application is written in Common Lisp and runs on SBCL. The user can extend
it at runtime by loading Lisp files. Custom commands, presentation types, and
views can be added without modifying the core. The interactor is a Lisp REPL
enhanced with Astrolabe-specific commands.

---

## Technical Notes

### SQLite Usage Patterns

- All queries use parameterized statements (no SQL injection risk)
- Soft deletes via `deleted_at` column — data is never truly lost
- FTS5 indexes maintained via triggers for automatic full-text search updates
- Schema migrations tracked in `schema_version` table
- WAL mode for concurrent read performance
- Single connection held by the application frame

### charmed-mcclim Integration

- Application frame uses `charmed-frame-top-level` for the event loop
- Navigation pane uses `display-function` with output recording for scrolling
- Detail pane likewise uses `display-function` with output recording
- Interactor pane uses McCLIM's built-in `interactor` pane type with DREI editing
- Presentation types registered with CLIM for click-to-navigate
- Tab cycles focus between navigation, detail, and interactor panes
- Scroll (Up/Down/PgUp/PgDn) works on the focused pane
- Ctrl-Q exits cleanly

### Object Identity

Every object has a unique identity composed of `(type, id)`:
- `(:note 42)` — Note with database ID 42
- `(:task 7)` — Task with database ID 7
- `(:project 3)` — Project with database ID 3

This pair is the universal reference used in links, presentation types, and
command arguments.

---

## Milestones

| Version | Phase | Description | Status |
| --- | --- | --- | --- |
| v0.1 | 0 | Foundation — running app with CRUD | **Next** |
| v0.2 | 1 | Productivity — search, tags, capture | Planned |
| v0.3 | 2 | Navigation — fuzzy find, agenda, polish | Planned |
| v0.4 | 3 | Communication — XMPP, RSS | Planned |
| v0.5 | 4 | Automation — scripting, templates, shell | Planned |
| v0.6 | 5 | Intelligence — local LLM, semantic search | Planned |
| v0.7+ | 6 | Extended objects — servers, events, etc. | Future |
