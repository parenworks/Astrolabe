;;;; db.lisp — Database layer for Astrolabe
;;;; SQLite3 schema creation, connection management, and query helpers.

(in-package #:astrolabe)

;;; Current schema version — increment when adding migrations.
(defvar *schema-version* 1)

;;; The active database handle (set by open-database).
(defvar *db* nil)

;;; ─────────────────────────────────────────────────────────────────────
;;; Connection management
;;; ─────────────────────────────────────────────────────────────────────

(defun open-database ()
  "Open (or create) the Astrolabe database and apply schema."
  (ensure-data-dir)
  (setf *db* (sqlite:connect (namestring *db-path*)))
  ;; Enable WAL mode for better concurrent read performance
  (sqlite:execute-non-query *db* "PRAGMA journal_mode=WAL")
  (sqlite:execute-non-query *db* "PRAGMA foreign_keys=ON")
  (apply-schema)
  *db*)

(defun close-database ()
  "Close the database connection."
  (when *db*
    (sqlite:disconnect *db*)
    (setf *db* nil)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Schema creation
;;; ─────────────────────────────────────────────────────────────────────

(defun current-db-version ()
  "Return the current schema version from the database, or 0 if none."
  (handler-case
      (let ((rows (sqlite:execute-to-list
                   *db* "SELECT MAX(version) FROM schema_version")))
        (if (and rows (first rows) (first (first rows)))
            (first (first rows))
            0))
    (error () 0)))

(defun apply-schema ()
  "Apply database schema if not already at current version."
  (let ((version (current-db-version)))
    (when (< version 1)
      (apply-schema-v1))
    ;; Record version
    (when (< version *schema-version*)
      (sqlite:execute-non-query
       *db* "INSERT INTO schema_version (version) VALUES (?)"
       *schema-version*))))

(defun apply-schema-v1 ()
  "Create the full Astrolabe schema."
  ;; Schema version tracking
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS schema_version (
       version    INTEGER NOT NULL,
       applied_at TEXT NOT NULL DEFAULT (datetime('now'))
     )")

  ;; ── Notes ────────────────────────────────────────────────────────────
  ;; A note is a titled block of text — a thought, a meeting recap, a
  ;; reference page, a daily standup log.  Body is markdown by default.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS notes (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       title       TEXT    NOT NULL,
       body        TEXT    DEFAULT '',
       format      TEXT    NOT NULL DEFAULT 'markdown',  -- markdown | plain
       pinned      INTEGER NOT NULL DEFAULT 0,           -- 1 = pinned to top of lists
       archived    INTEGER NOT NULL DEFAULT 0,           -- 1 = hidden from active views
       created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       updated_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       deleted_at  TEXT
     )")

  ;; ── Tasks ────────────────────────────────────────────────────────────
  ;; Tasks support subtasks via parent_id, recurrence, effort estimates,
  ;; completion tracking, and optional assignment to a person.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS tasks (
       id            INTEGER PRIMARY KEY AUTOINCREMENT,
       title         TEXT    NOT NULL,
       description   TEXT    DEFAULT '',
       status        TEXT    NOT NULL DEFAULT 'todo',      -- todo | active | done | cancelled | waiting
       priority      TEXT    NOT NULL DEFAULT 'B',         -- A | B | C
       due_date      TEXT,                                 -- ISO 8601 date or NULL
       scheduled_date TEXT,                                -- date when work should start
       completed_at  TEXT,                                 -- when status changed to done
       parent_id     INTEGER REFERENCES tasks(id),         -- NULL = top-level task
       sort_order    INTEGER NOT NULL DEFAULT 0,           -- manual ordering within a list
       effort_minutes INTEGER,                             -- estimated effort in minutes
       actual_minutes INTEGER,                             -- tracked actual effort
       recurrence    TEXT,                                 -- NULL | daily | weekly | monthly | yearly | cron expression
       recur_after   TEXT,                                 -- next recurrence anchor date
       assigned_to   INTEGER REFERENCES persons(id),       -- person responsible
       context       TEXT,                                 -- GTD-style context: @home, @work, @errands
       notes         TEXT    DEFAULT '',                   -- inline notes (markdown)
       created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
       updated_at    TEXT    NOT NULL DEFAULT (datetime('now')),
       deleted_at    TEXT
     )")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_id)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_date)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON tasks(assigned_to)")

  ;; ── Projects ─────────────────────────────────────────────────────────
  ;; A project groups tasks, notes, persons, and other objects.
  ;; Supports lifecycle dates and an area/category for grouping projects.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS projects (
       id           INTEGER PRIMARY KEY AUTOINCREMENT,
       name         TEXT    NOT NULL,
       description  TEXT    DEFAULT '',
       status       TEXT    NOT NULL DEFAULT 'active', -- active | paused | complete | archived | cancelled
       priority     TEXT    NOT NULL DEFAULT 'B',      -- A | B | C
       area         TEXT,                              -- category: work, personal, oss, client, etc.
       start_date   TEXT,                              -- planned or actual start
       target_date  TEXT,                              -- target completion date
       completed_at TEXT,                              -- actual completion timestamp
       archived_at  TEXT,                              -- when moved to archive (distinct from soft-delete)
       owner_id     INTEGER REFERENCES persons(id),    -- project owner / lead
       notes        TEXT    DEFAULT '',                -- project-level notes (markdown)
       created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
       updated_at   TEXT    NOT NULL DEFAULT (datetime('now')),
       deleted_at   TEXT
     )")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_projects_area ON projects(area)")

  ;; ── Persons (CRM contacts) ──────────────────────────────────────────
  ;; Full contact record: multiple communication channels, organization,
  ;; address, birthday, and a freeform notes field.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS persons (
       id           INTEGER PRIMARY KEY AUTOINCREMENT,
       name         TEXT    NOT NULL,
       first_name   TEXT,
       last_name    TEXT,
       nickname     TEXT,
       email        TEXT,
       email2       TEXT,
       phone        TEXT,
       phone2       TEXT,
       organization TEXT,
       job_title    TEXT,
       role         TEXT,                              -- relationship role: client, colleague, vendor, friend, etc.
       website      TEXT,
       address      TEXT,                              -- freeform mailing address
       city         TEXT,
       state        TEXT,
       postal_code  TEXT,
       country      TEXT,
       birthday     TEXT,                              -- ISO date
       xmpp_jid     TEXT,                              -- for CLabber integration
       matrix_id    TEXT,                              -- @user:server
       irc_nick     TEXT,
       avatar_url   TEXT,
       notes        TEXT    DEFAULT '',                -- freeform notes (markdown)
       last_contacted TEXT,                            -- date of last interaction
       contact_frequency TEXT,                         -- daily | weekly | monthly | quarterly | yearly
       pinned       INTEGER NOT NULL DEFAULT 0,
       created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
       updated_at   TEXT    NOT NULL DEFAULT (datetime('now')),
       deleted_at   TEXT
     )")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_persons_org ON persons(organization)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_persons_name ON persons(name)")

  ;; ── Tags ─────────────────────────────────────────────────────────────
  ;; Tags are reusable labels attached to any object via object_tags.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS tags (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       name        TEXT    NOT NULL UNIQUE,
       color       TEXT,                               -- display color name or hex
       description TEXT    DEFAULT '',
       created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
     )")

  ;; ── Snippets ─────────────────────────────────────────────────────────
  ;; A captured fragment: code, URL, quote, command, log line.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS snippets (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       title       TEXT,                               -- optional short label
       content     TEXT    NOT NULL,
       content_type TEXT   NOT NULL DEFAULT 'text',    -- text | code | url | command | quote | log
       language    TEXT,                               -- programming language (for code snippets)
       source      TEXT,                               -- where it came from (file path, URL, etc.)
       pinned      INTEGER NOT NULL DEFAULT 0,
       created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       updated_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       deleted_at  TEXT
     )")

  ;; ── Bookmarks ────────────────────────────────────────────────────────
  ;; Pinned references to any Astrolabe object, shown on the home screen.
  ;; Also usable for web bookmarks (with url field).
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS bookmarks (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       title       TEXT    NOT NULL,
       url         TEXT,                               -- web URL (for web bookmarks) or NULL
       object_type TEXT,                               -- pinned object type (note, task, project, etc.)
       object_id   INTEGER,                            -- pinned object id
       sort_order  INTEGER NOT NULL DEFAULT 0,
       icon        TEXT,                               -- emoji or icon name
       description TEXT    DEFAULT '',
       created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       deleted_at  TEXT
     )")

  ;; ── Object-tag associations ──────────────────────────────────────────
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS object_tags (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       object_type TEXT    NOT NULL,
       object_id   INTEGER NOT NULL,
       tag_id      INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
       created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       UNIQUE(object_type, object_id, tag_id)
     )")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_object_tags_obj ON object_tags(object_type, object_id)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_object_tags_tag ON object_tags(tag_id)")

  ;; ── Links between objects ────────────────────────────────────────────
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS links (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       source_type TEXT    NOT NULL,
       source_id   INTEGER NOT NULL,
       target_type TEXT    NOT NULL,
       target_id   INTEGER NOT NULL,
       relation    TEXT,                               -- contains, references, blocks, depends-on, etc.
       created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
       UNIQUE(source_type, source_id, target_type, target_id, relation)
     )")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_links_source ON links(source_type, source_id)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_links_target ON links(target_type, target_id)")

  ;; ── Activity log ─────────────────────────────────────────────────────
  ;; An append-only log of all changes for audit trail and daily digest.
  (sqlite:execute-non-query *db*
    "CREATE TABLE IF NOT EXISTS activity_log (
       id          INTEGER PRIMARY KEY AUTOINCREMENT,
       action      TEXT    NOT NULL,                   -- created, updated, deleted, completed, linked, etc.
       object_type TEXT    NOT NULL,
       object_id   INTEGER NOT NULL,
       detail      TEXT,                               -- JSON or freeform description of what changed
       created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
     )")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_activity_date ON activity_log(created_at)")
  (sqlite:execute-non-query *db*
    "CREATE INDEX IF NOT EXISTS idx_activity_obj ON activity_log(object_type, object_id)")

  ;; ── Full-text search indexes ─────────────────────────────────────────
  (sqlite:execute-non-query *db*
    "CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts
       USING fts5(title, body, content=notes, content_rowid=id)")
  (sqlite:execute-non-query *db*
    "CREATE VIRTUAL TABLE IF NOT EXISTS tasks_fts
       USING fts5(title, description, notes, content=tasks, content_rowid=id)")
  (sqlite:execute-non-query *db*
    "CREATE VIRTUAL TABLE IF NOT EXISTS snippets_fts
       USING fts5(title, content, source, content=snippets, content_rowid=id)")
  (sqlite:execute-non-query *db*
    "CREATE VIRTUAL TABLE IF NOT EXISTS persons_fts
       USING fts5(name, first_name, last_name, email, organization, notes, content=persons, content_rowid=id)")
  (sqlite:execute-non-query *db*
    "CREATE VIRTUAL TABLE IF NOT EXISTS projects_fts
       USING fts5(name, description, notes, content=projects, content_rowid=id)"))

;;; ─────────────────────────────────────────────────────────────────────
;;; Query helpers
;;; ─────────────────────────────────────────────────────────────────────

(defun db-query (sql &rest params)
  "Execute a SELECT query, return list of rows (each row is a list)."
  (apply #'sqlite:execute-to-list *db* sql params))

(defun db-query-single (sql &rest params)
  "Execute a SELECT query expecting a single row, return that row or NIL."
  (let ((rows (apply #'db-query sql params)))
    (first rows)))

(defun db-execute (sql &rest params)
  "Execute an INSERT/UPDATE/DELETE statement."
  (apply #'sqlite:execute-non-query *db* sql params))

(defun db-last-insert-id ()
  "Return the rowid of the last INSERT."
  (first (first (sqlite:execute-to-list *db* "SELECT last_insert_rowid()"))))
