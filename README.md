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

```text
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

- **Note** — Title, body (markdown), format, pinned, archived, timestamps, links
- **Task** — Title, description, status (todo/active/done/cancelled/waiting), priority (A/B/C), due date, scheduled date, effort/actual minutes, recurrence, context, subtasks, links
- **Project** — Name, description, status (active/paused/complete/archived), priority, area, start/target dates, owner, notes, links
- **Person** — Full CRM contact: name, email, phone, organization, job title, address, birthday, XMPP/Matrix/IRC handles, contact frequency, links
- **Tag** — Name, color, description. Any object can have multiple tags.
- **Snippet** — Title, content, content type, language, source. Quick capture target.
- **Bookmark** — Pinned reference to a URL or internal object.

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

```text
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
│                     ┃   - Person profile           │
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

```text
Create:
  Capture Note [title]         — Create a note, auto-link to current context
  Add Task [title]             — Create a task
  New Project [name]           — Create a project
  Add Person [name]            — Add a contact
  Capture Snippet [content]    — Save a snippet

Actions:
  Complete Task [task]         — Mark a task done
  Link [source] [target]       — Link two objects
  Tag [object] [tag]           — Add a tag
  Untag [object] [tag]         — Remove a tag
  Edit Note [note] [body]      — Replace note body
  Append Note [note] [text]    — Append to note body
  Bookmark [object]            — Pin an object to home screen
  Unbookmark [object]          — Remove pin

Search & Filter:
  Search [query]               — FTS5 search across all objects
  Go [partial-name]            — Fuzzy jump to any object
  Filter Tag [tag]             — Show all objects with a tag
  Show Tasks                   — All open tasks
  Show Tasks Today             — Tasks due today or overdue
  Agenda                       — Daily planning view

Delete:
  Delete Note/Task/Project/Person/Snippet — Soft delete (with confirmation)

Messaging (XMPP):
  Show Conversations           — List all conversations
  Show Conversation [conv]     — View message thread
  Message [jid] [body]         — Send a message (auto-creates conversation)

Feeds (RSS/Atom):
  Show Feeds                   — List subscribed feeds
  Subscribe [url]              — Add a feed subscription
  Unsubscribe [feed]           — Remove a feed (with confirmation)
  Fetch Feed [feed]            — Download and parse a feed
  Fetch All Feeds              — Refresh all feed subscriptions
  Show Feed [feed]             — View articles in a feed
  Show Feed Item [item]        — Read an article
  Capture Article [item]       — Save article as a note

Notifications:
  Show Notifications           — View all notifications
  Dismiss Notification [notif] — Mark a notification as read
  Dismiss All Notifications    — Clear all notifications

Shell & Export:
  Shell [command]              — Run shell command, show output
  Export [object]              — Export object as Markdown
  Export File [object] [path]  — Export to a file
  Export Project Report [proj] — Generate project status report

Templates:
  List Templates               — Show available templates
  Capture Note Template [name] — Create note from template
  Add Task Template [name]     — Create task from template

Batch Operations:
  Select [object]              — Add to batch selection
  Deselect [object]            — Remove from selection
  Clear Selection              — Clear all selections
  Show Selection               — List selected objects
  Batch Tag [tag]              — Tag all selected objects
  Batch Complete               — Complete all selected tasks
  Batch Delete                 — Delete all selected objects

AI (requires Ollama):
  Summarize [object]           — Generate concise summary
  Extract Tasks [object]       — Pull action items from text
  Rewrite [object]             — Improve writing clarity
  Explain [object]             — Explain code or content
  Auto Tag [object]            — Suggest and apply tags via LLM
  Ask [question]               — Q&A with context from your data
  Daily Digest                 — AI-generated daily briefing
  Similar [object]             — Find related objects via LLM
  Set Model [name]             — Switch Ollama model

Navigate:
  Home                         — Return to home view
  Back                         — Go to previous view
  Forward                      — Go forward in history
  Check Reminders              — Check for overdue/due tasks
  Reload Commands              — Reload user commands
  Quit                         — Exit Astrolabe

Keyboard shortcuts:
  C-n  Capture Note    C-b  Back
  C-t  Add Task        C-f  Forward
  C-s  Search          C-a  Agenda
  C-h  Home            C-g  Go (fuzzy find)
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
| **drakma** | HTTP client for feed fetching | Quicklisp |
| **plump** | XML/HTML parser for RSS/Atom | Quicklisp |
| **yason** | JSON encoding/decoding | Quicklisp |
| **flexi-streams** | Octet-to-string conversion | Quicklisp |
| **Ollama** | Local LLM inference server | [ollama.com](https://ollama.com) |

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

```text
astrolabe/
├── README.md
├── ROADMAP.md
├── astrolabe.asd           # ASDF system definition
├── justfile                # Development task runner
├── src/
│   ├── package.lisp        # Package definition
│   ├── config.lisp         # Configuration and paths
│   ├── db.lisp             # Database schema (15 tables), versioned migrations, FTS5 indexes
│   ├── model.lisp          # CLOS model (note, task, project, person, snippet, bookmark, conversation, message, feed, feed-item, notification, tags, links, search)
│   ├── app.lisp            # Application frame definition
│   ├── presentations.lisp  # CLIM presentation types and click translators
│   ├── feeds.lisp          # RSS/Atom feed fetching and XML parsing (drakma + plump)
│   ├── automation.lisp     # Hooks, templates, shell integration, export, batch ops, user commands
│   ├── llm.lisp            # Ollama LLM integration: summarize, rewrite, explain, auto-tag, Q&A
│   ├── commands.lisp       # CLIM commands, keybindings
│   ├── views.lisp          # Pane display functions (home, search, tasks, conversations, feeds, notifications, detail)
│   └── main.lisp           # Entry point: (astrolabe:run)
```

## License

MIT

## Author

Glenn Skinner / [parenworks](https://github.com/parenworks)
