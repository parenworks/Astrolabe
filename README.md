# Astrolabe

**A terminal-native personal operations console built on Common Lisp and McCLIM.**

Navigate notes, tasks, systems, and signals — all from the terminal.

## Vision

Astrolabe is a unified workbench for knowledge work in the terminal. Instead of jumping between tmux panes, browser tabs, notes apps, and scripts, Astrolabe provides a single coherent environment where everything is connected.

It is not a file manager, not a notes app, not a dashboard. It is a **daily cockpit** — a terminal-native operating environment for getting real work done.

## Philosophy

- **Local-first** — Your data lives on your machine in a SQLite database. No cloud, no sync service, no account. You own everything.
- **Object-oriented** — Everything on screen is a typed object: a project, a task, a note, a person, a server. Click it, act on it, navigate into it.
- **Keyboard-driven** — Every action is a keystroke or command away. Mouse support for clicking objects, but the keyboard is primary.
- **Composable** — Every screen is scriptable. Press a key on a host to SSH in. Press a key on a task to create a linked note. Press a key on a document to export it.
- **Hackable** — Written in Common Lisp. Extend it at runtime. Add new object types, commands, and views without restarting.
- **Beautiful** — Not a messy ncurses throwback. Clean layouts, thoughtful use of color, proper Unicode box-drawing, and a design sensibility that respects the terminal medium.

## Architecture

### Framework: charmed-mcclim

Astrolabe is built on [charmed-mcclim](https://github.com/parenworks/charmed-mcclim), a McCLIM backend for terminal applications using the [charmed](https://github.com/parenworks/charmed) terminal library.

**Why McCLIM?** McCLIM (the Common Lisp Interface Manager) provides exactly the primitives Astrolabe needs:

| McCLIM Feature | Astrolabe Use |
| --- | --- |
| **Presentation types** | Every object on screen (task, note, project, person) is a typed, clickable presentation. Click a project → see its context. The system knows *what* you clicked, not just *where*. |
| **Presentation translators** | Context-sensitive actions. Click a task in the home view → show detail. Click it in a project view → offer to link, edit, or complete. Same object, different context, different actions. |
| **Commands** | All user actions are CLIM commands with typed arguments. Tab-completion, argument prompting, and help come for free. `Capture Note`, `Add Task`, `Search` — all first-class commands. |
| **Pane layouts** | Horizontal and vertical splits, resizable. Home pane, detail pane, interactor — all managed by McCLIM's layout protocol. |
| **Input editing (DREI)** | Rich text input with completion, history, and editing. The interactor pane is a full input editor, not a raw text field. |
| **Output recording** | Everything written to a pane is recorded as output records. This enables scrolling, hit-detection for mouse clicks, and incremental redisplay. |

### Terminal Backend: charmed

The charmed library provides the terminal abstraction layer:

- **Screen buffer** — Double-buffered cell grid with dirty tracking for efficient updates
- **Input handling** — Keyboard events, mouse events (click, drag, release, scroll), resize
- **Text styling** — Bold, italic, dim, underline, 256-color and RGB color support
- **Unicode** — Full Unicode rendering including box-drawing characters

### Database: SQLite3

All persistent data is stored in a single SQLite database file (`~/.astrolabe/astrolabe.db`).

**Why SQLite?**

- Zero configuration — no server process, no setup
- Single file — easy to back up, move, version
- ACID transactions — data integrity guaranteed
- Full SQL — powerful querying for search and reporting
- Excellent Common Lisp support via `cl-sqlite`

### Data Model

Astrolabe's core data model is built around **objects** and **links**:

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Project  │────▶│   Task   │────▶│   Note   │
└──────────┘     └──────────┘     └──────────┘
     │                │                │
     │                │                │
     ▼                ▼                ▼
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Person   │     │   Tag    │     │  Snippet │
└──────────┘     └──────────┘     └──────────┘
```

**Core object types:**

- **Note** — Title, body, tags, timestamps, links to other objects
- **Task** — Title, status (todo/active/done/cancelled), priority (A/B/C), due date, links
- **Project** — Name, description, status (active/paused/complete/archived), links to tasks and notes
- **Person** — Name, email, role, links to projects/tasks/notes
- **Tag** — Name, color. Objects can have multiple tags.
- **Snippet** — A captured fragment of text, code, URL, or command. Quick capture target.

**Link system:**

Any object can be linked to any other object via a `links` table. Links are bidirectional and typed (e.g., "task belongs to project", "note references person", "snippet captured from project context").

```sql
CREATE TABLE links (
    id          INTEGER PRIMARY KEY,
    source_type TEXT NOT NULL,    -- 'note', 'task', 'project', etc.
    source_id   INTEGER NOT NULL,
    target_type TEXT NOT NULL,
    target_id   INTEGER NOT NULL,
    relation    TEXT,             -- 'belongs-to', 'references', 'captured-from', etc.
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### UI Layout

Astrolabe uses a three-pane layout:

```
┌─────────────────────┃─────────────────────────────┐
│                     ┃                              │
│   Navigation Pane   ┃      Detail Pane             │
│                     ┃                              │
│   - Home / Agenda   ┃   Shows context for the      │
│   - Project list    ┃   selected item:             │
│   - Recent notes    ┃                              │
│   - Active tasks    ┃   - Note body                │
│   - Search results  ┃   - Task details + links     │
│   - Inbox / Alerts  ┃   - Project dashboard        │
│                     ┃   - Person profile            │
│                     ┃                              │
│                     ┃                              │
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│ > command interactor                               │
│   Tab-complete commands, capture notes, search     │
└────────────────────────────────────────────────────┘
```

- **Navigation pane** (top-left): Lists of objects. Click to select. Shows different views depending on context: home screen, project contents, search results, etc.
- **Detail pane** (top-right): Rich display for the selected object. Shows the object's content and all its linked objects.
- **Interactor pane** (bottom): Command input with DREI editing, tab completion, and history.

### Command System

All actions are CLIM commands:

```
Capture Note [title]        — Create a new note, auto-linked to current context
Add Task [title]            — Create a new task
Show [object]               — Display object in detail pane
Search [query]              — Full-text search across all objects
Link [source] [target]      — Create a link between two objects
Complete Task [task]         — Mark a task as done
Tag [object] [tag]          — Add a tag to an object
Open Project [project]      — Navigate into a project view
Home                        — Return to home/agenda view
```

Commands accept presentation arguments — click an object on screen to provide it as an argument to the current command.

## Dependencies

| Dependency | Purpose | Source |
| --- | --- | --- |
| **SBCL** | Common Lisp implementation | [sbcl.org](http://www.sbcl.org) |
| **McCLIM** | CLIM implementation | [github.com/McCLIM/McCLIM](https://github.com/McCLIM/McCLIM) |
| **charmed-mcclim** | Terminal backend for McCLIM | [github.com/parenworks/charmed-mcclim](https://github.com/parenworks/charmed-mcclim) |
| **charmed** | Terminal abstraction library | [github.com/parenworks/charmed](https://github.com/parenworks/charmed) |
| **cl-sqlite** | SQLite3 bindings for CL | Quicklisp |
| **local-time** | Date/time handling | Quicklisp |
| **cl-ppcre** | Regular expressions | Quicklisp |

## Quick Start

```bash
# Clone
git clone git@github.com:parenworks/astrolabe.git
cd astrolabe

# Ensure dependencies are available
# (McCLIM, charmed-mcclim, charmed must be on ASDF path)

# Run
sbcl --noinform \
  --eval '(push #P"/path/to/charmed/" asdf:*central-registry*)' \
  --eval '(push #P"/path/to/charmed-mcclim/Backends/charmed/" asdf:*central-registry*)' \
  --eval '(push #P"." asdf:*central-registry*)' \
  --eval '(asdf:load-system :astrolabe)' \
  --eval '(astrolabe:run)'
```

On first run, Astrolabe creates `~/.astrolabe/astrolabe.db` with the initial schema.

## Project Structure

```
astrolabe/
├── README.md
├── ROADMAP.md
├── astrolabe.asd           # ASDF system definition
├── src/
│   ├── package.lisp        # Package definition
│   ├── config.lisp         # Configuration and paths
│   ├── db.lisp             # Database schema, migrations, queries
│   ├── model.lisp          # Object model (note, task, project, person, tag)
│   ├── presentations.lisp  # CLIM presentation types and translators
│   ├── commands.lisp       # CLIM commands (capture, search, show, etc.)
│   ├── views.lisp          # Pane display functions (home, detail, navigation)
│   └── app.lisp            # Application frame definition and entry point
└── docs/
    └── DESIGN.md           # Detailed design notes
```

## License

MIT

## Author

Glenn Skinner / [parenworks](https://github.com/parenworks)
