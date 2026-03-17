;;;; views.lisp — Pane display functions for Astrolabe

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Navigation pane — left side, shows lists of objects
;;; ─────────────────────────────────────────────────────────────────────

(defun display-navigation (frame pane)
  "Display function for the navigation pane."
  (declare (ignore frame))
  (display-breadcrumbs pane)
  (case *current-view*
    (:home       (display-home-nav pane))
    (:project    (display-project-nav pane))
    (:search     (display-search-nav pane))
    (:tag-filter (display-tag-filter-nav pane))
    (:tasks      (display-tasks-nav pane))
    (:agenda         (display-agenda-nav pane))
    (:go-results     (display-go-results-nav pane))
    (:conversations  (display-conversations-nav pane))
    (:conversation   (display-conversation-nav pane))
    (:feeds          (display-feeds-nav pane))
    (:feed-items     (display-feed-items-nav pane))
    (:notifications  (display-notifications-nav pane))
    (t               (display-home-nav pane))))

(defun display-home-nav (pane)
  "Display the home screen in the navigation pane."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  ASTROLABE~%")))
  (terpri pane)

  ;; Active tasks
  (with-drawing-options (pane :ink +yellow+)
    (with-text-face (pane :bold)
      (format pane "  Tasks~%")))
  (let ((tasks (load-open-tasks 15)))
    (if tasks
        (dolist (task tasks)
          (present-task pane task))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no open tasks)~%"))))
  (terpri pane)

  ;; Active projects
  (with-drawing-options (pane :ink +green+)
    (with-text-face (pane :bold)
      (format pane "  Projects~%")))
  (let ((projects (load-active-projects 10)))
    (if projects
        (dolist (project projects)
          (present-project pane project))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no active projects)~%"))))
  (terpri pane)

  ;; Recent notes
  (with-drawing-options (pane :ink +cyan+)
    (with-text-face (pane :bold)
      (format pane "  Recent Notes~%")))
  (let ((notes (load-recent-notes 10)))
    (if notes
        (dolist (note notes)
          (present-note pane note))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no notes yet)~%"))))
  (terpri pane)

  ;; Persons
  (with-drawing-options (pane :ink +magenta+)
    (with-text-face (pane :bold)
      (format pane "  Contacts~%")))
  (let ((persons (load-persons 10)))
    (if persons
        (dolist (person persons)
          (present-person pane person))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no contacts yet)~%"))))
  (terpri pane)

  ;; Recent snippets
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  Snippets~%")))
  (let ((snippets (load-recent-snippets 10)))
    (if snippets
        (dolist (snippet snippets)
          (present-snippet pane snippet))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no snippets yet)~%"))))
  (terpri pane)

  ;; Notifications summary
  (let ((notif-count (unread-notification-count)))
    (when (> notif-count 0)
      (with-drawing-options (pane :ink +yellow+)
        (with-text-face (pane :bold)
          (format pane "  Notifications (~D)~%" notif-count)))
      (let ((recent (load-notifications :limit 3 :unread-only t)))
        (dolist (n recent)
          (present-notification pane n)))
      (terpri pane)))

  ;; Conversations summary
  (let ((convs (load-conversations 5)))
    (when convs
      (with-drawing-options (pane :ink +cyan+)
        (with-text-face (pane :bold)
          (format pane "  Conversations~%")))
      (dolist (conv convs)
        (present-conversation pane conv))
      (terpri pane)))

  ;; Feeds summary
  (let ((feeds (load-feeds 5)))
    (when feeds
      (with-drawing-options (pane :ink +green+)
        (with-text-face (pane :bold)
          (format pane "  Feeds~%")))
      (dolist (feed feeds)
        (present-feed pane feed))
      (terpri pane)))

  ;; Bookmarks
  (let ((bookmarks (load-bookmarks 10)))
    (when bookmarks
      (with-drawing-options (pane :ink +white+)
        (with-text-face (pane :bold)
          (format pane "  Bookmarks~%")))
      (dolist (bm bookmarks)
        (let ((obj (when (bookmark-object-type bm)
                    (load-object-by-type-and-id
                     (bookmark-object-type bm) (bookmark-object-id bm)))))
          (if obj
              (present-object pane obj)
              (with-drawing-options (pane :ink +white+)
                (format pane "    ~A~%" (bookmark-title bm)))))))))

(defun display-project-nav (pane)
  "Display a project's contents in the navigation pane."
  (if (null *current-project*)
      (display-home-nav pane)
      (let ((project *current-project*))
        (with-drawing-options (pane :ink +green+)
          (with-text-face (pane :bold)
            (format pane "  ~A~%" (project-name project))))
        (with-drawing-options (pane :ink +white+)
          (format pane "  ~A~%" (project-description project)))
        (terpri pane)

        ;; Project tasks
        (with-drawing-options (pane :ink +yellow+)
          (with-text-face (pane :bold)
            (format pane "  Tasks~%")))
        (let ((tasks (load-project-tasks (obj-id project))))
          (if tasks
              (dolist (task tasks)
                (present-task pane task))
              (with-drawing-options (pane :ink +white+)
                (format pane "    (no tasks)~%"))))
        (terpri pane)

        ;; Project notes (via links)
        (with-drawing-options (pane :ink +cyan+)
          (with-text-face (pane :bold)
            (format pane "  Notes~%")))
        (let ((linked (load-linked-objects project))
              (notes nil))
          (dolist (link linked)
            (when (string-equal (first link) "note")
              (let ((note (load-note (second link))))
                (when note (push note notes)))))
          (if notes
              (dolist (note (nreverse notes))
                (present-note pane note))
              (with-drawing-options (pane :ink +white+)
                (format pane "    (no notes)~%")))))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Breadcrumbs
;;; ─────────────────────────────────────────────────────────────────────

(defun nav-state-label (state)
  "Return a short label for a navigation state."
  (let ((view (getf state :view))
        (obj  (getf state :object)))
    (cond
      (obj  (obj-display-title obj))
      ((eq view :home) "Home")
      ((eq view :search) (format nil "Search: ~A" (or *search-query* "")))
      ((eq view :agenda) "Agenda")
      ((eq view :tasks) "Tasks")
      ((eq view :tag-filter) (format nil "Tag: ~A" (or *filter-tag* "")))
      (t (string-capitalize (symbol-name view))))))

(defun display-breadcrumbs (pane)
  "Display the navigation breadcrumb trail."
  (when *nav-history*
    (with-drawing-options (pane :ink +white+)
      (format pane "  ")
      (let ((trail (reverse (subseq *nav-history* 0 (min 5 (length *nav-history*))))))
        (dolist (state trail)
          (format pane "~A > " (nav-state-label state))))
      (format pane "*~%"))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Helper — present any object by type
;;; ─────────────────────────────────────────────────────────────────────

(defun present-object (pane obj)
  "Present any astrolabe object as a clickable presentation."
  (cond
    ((typep obj 'note)         (present-note pane obj))
    ((typep obj 'task)         (present-task pane obj))
    ((typep obj 'project)      (present-project pane obj))
    ((typep obj 'person)       (present-person pane obj))
    ((typep obj 'snippet)      (present-snippet pane obj))
    ((typep obj 'conversation) (present-conversation pane obj))
    ((typep obj 'feed)         (present-feed pane obj))
    ((typep obj 'feed-item)    (present-feed-item pane obj))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Search results view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-search-nav (pane)
  "Display search results in the navigation pane."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  Search: ~A~%" (or *search-query* ""))))
  (terpri pane)
  (if *search-results*
      (dolist (obj *search-results*)
        (present-object pane obj))
      (with-drawing-options (pane :ink +white+)
        (format pane "    (no results)~%"))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Tag filter view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-tag-filter-nav (pane)
  "Display objects matching a tag filter."
  (with-drawing-options (pane :ink +yellow+)
    (with-text-face (pane :bold)
      (format pane "  Tag: ~A~%" (or *filter-tag* ""))))
  (terpri pane)
  (if *filter-results*
      (dolist (obj *filter-results*)
        (present-object pane obj))
      (with-drawing-options (pane :ink +white+)
        (format pane "    (no tagged objects)~%"))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Task list view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-tasks-nav (pane)
  "Display filtered task list."
  (with-drawing-options (pane :ink +yellow+)
    (with-text-face (pane :bold)
      (format pane "  Tasks~A~%"
              (case *task-filter*
                (:all   " (all open)")
                (:today " (today)")
                (t      "")))))
  (terpri pane)
  (if *task-filter-results*
      (dolist (task *task-filter-results*)
        (present-task pane task))
      (with-drawing-options (pane :ink +white+)
        (format pane "    (no tasks)~%"))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Agenda view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-agenda-nav (pane)
  "Display the daily agenda view."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  AGENDA~%")))
  (with-drawing-options (pane :ink +white+)
    (format pane "  ~A~%"
            (subseq (local-time:format-timestring nil (local-time:now)
                     :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                    0 10)))
  (terpri pane)

  ;; Overdue
  (when *agenda-overdue*
    (with-drawing-options (pane :ink +red+)
      (with-text-face (pane :bold)
        (format pane "  Overdue~%")))
    (dolist (task *agenda-overdue*)
      (present-task pane task))
    (terpri pane))

  ;; Today
  (with-drawing-options (pane :ink +yellow+)
    (with-text-face (pane :bold)
      (format pane "  Today~%")))
  (if *agenda-today*
      (dolist (task *agenda-today*)
        (present-task pane task))
      (with-drawing-options (pane :ink +white+)
        (format pane "    (nothing due today)~%")))
  (terpri pane)

  ;; Upcoming 7 days
  (with-drawing-options (pane :ink +green+)
    (with-text-face (pane :bold)
      (format pane "  Upcoming (7 days)~%")))
  (if *agenda-upcoming*
      (dolist (task *agenda-upcoming*)
        (present-task pane task))
      (with-drawing-options (pane :ink +white+)
        (format pane "    (nothing upcoming)~%")))
  (terpri pane)

  ;; Recent captures
  (when *agenda-recent*
    (with-drawing-options (pane :ink +cyan+)
      (with-text-face (pane :bold)
        (format pane "  Recent captures (24h)~%")))
    (dolist (obj *agenda-recent*)
      (present-object pane obj))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Go (fuzzy find) results view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-go-results-nav (pane)
  "Display fuzzy-find results."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  Jump to:~%")))
  (terpri pane)
  (if *go-results*
      (dolist (obj *go-results*)
        (present-object pane obj))
      (with-drawing-options (pane :ink +white+)
        (format pane "    (no matches)~%"))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Conversations view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-conversations-nav (pane)
  "Display the conversation list."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  CONVERSATIONS~%")))
  (terpri pane)
  (let ((convs (load-conversations)))
    (if convs
        (dolist (conv convs)
          (present-conversation pane conv))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no conversations yet)~%")))))

(defun display-conversation-nav (pane)
  "Display a message thread in the navigation pane."
  (if (null *current-conversation*)
      (display-conversations-nav pane)
      (progn
        (with-drawing-options (pane :ink +white+)
          (with-text-face (pane :bold)
            (format pane "  ~A~%"
                    (obj-display-title *current-conversation*))))
        (with-drawing-options (pane :ink +white+)
          (format pane "  ~A~%" (conv-jid *current-conversation*)))
        (terpri pane)
        (if *current-messages*
            (dolist (msg *current-messages*)
              (let ((nick (or (xmsg-sender-nick msg) "???"))
                    (body (xmsg-body msg))
                    (ts   (xmsg-created-at msg)))
                (with-drawing-options (pane :ink (if (equal nick "me") +green+ +cyan+))
                  (format pane "  <~A> ~A" nick body))
                (when ts
                  (with-drawing-options (pane :ink +white+)
                    (format pane "  ~A" (subseq ts 11 16))))
                (terpri pane)))
            (with-drawing-options (pane :ink +white+)
              (format pane "    (no messages)~%"))))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Feeds view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-feeds-nav (pane)
  "Display the feed subscription list."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  FEEDS~%")))
  (terpri pane)
  (let ((feeds (load-feeds)))
    (if feeds
        (dolist (feed feeds)
          (present-feed pane feed))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no subscriptions yet)~%")
          (format pane "    Use: Subscribe [url]~%")))))

(defun display-feed-items-nav (pane)
  "Display articles for the current feed."
  (if (null *current-feed*)
      (display-feeds-nav pane)
      (progn
        (with-drawing-options (pane :ink +white+)
          (with-text-face (pane :bold)
            (format pane "  ~A~%" (obj-display-title *current-feed*))))
        (when (feed-description *current-feed*)
          (with-drawing-options (pane :ink +white+)
            (format pane "  ~A~%" (feed-description *current-feed*))))
        (terpri pane)
        (if *current-feed-items*
            (dolist (fi *current-feed-items*)
              (present-feed-item pane fi))
            (with-drawing-options (pane :ink +white+)
              (format pane "    (no articles)~%"))))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Notifications view
;;; ─────────────────────────────────────────────────────────────────────

(defun display-notifications-nav (pane)
  "Display notifications in the navigation pane."
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  NOTIFICATIONS~%")))
  (let ((count (unread-notification-count)))
    (when (> count 0)
      (with-drawing-options (pane :ink +yellow+)
        (format pane "  ~D unread~%" count))))
  (terpri pane)
  (let ((notifs (load-notifications :limit 30)))
    (if notifs
        (dolist (notif notifs)
          (present-notification pane notif))
        (with-drawing-options (pane :ink +white+)
          (format pane "    (no notifications)~%")))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Status bar
;;; ─────────────────────────────────────────────────────────────────────

(defun display-status-bar (frame pane)
  "Display the persistent status bar."
  (declare (ignore frame))
  (with-drawing-options (pane :ink +white+)
    (let* ((view-label (case *current-view*
                         (:home "Home")
                         (:project (if *current-project*
                                       (project-name *current-project*)
                                       "Project"))
                         (:search (format nil "Search: ~A" (or *search-query* "")))
                         (:tag-filter (format nil "Tag: ~A" (or *filter-tag* "")))
                         (:tasks "Tasks")
                         (:agenda "Agenda")
                         (:go-results "Jump")
                         (:conversations "Conversations")
                         (:conversation (if *current-conversation*
                                            (obj-display-title *current-conversation*)
                                            "Chat"))
                         (:feeds "Feeds")
                         (:feed-items (if *current-feed*
                                          (obj-display-title *current-feed*)
                                          "Articles"))
                         (:notifications "Notifications")
                         (t "Home")))
           (task-count (length (db-query "SELECT id FROM tasks
                                          WHERE deleted_at IS NULL
                                            AND status IN ('todo','active','waiting')")))
           (notif-count (unread-notification-count))
           (now (subseq (local-time:format-timestring nil (local-time:now)
                          :format '((:hour 2) #\: (:min 2)))
                        0 5)))
      (format pane " ~A  |  ~D open tasks~A  |  ~A"
              view-label task-count
              (if (> notif-count 0) (format nil "  |  ~D notif" notif-count) "")
              now))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Detail pane — right side, shows selected object
;;; ─────────────────────────────────────────────────────────────────────

(defun display-detail (frame pane)
  "Display function for the detail pane."
  (declare (ignore frame))
  (if *current-object*
      (display-object-detail pane *current-object*)
      (display-welcome pane)))

(defun display-welcome (pane)
  "Display a welcome message when nothing is selected."
  (terpri pane)
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  Welcome to Astrolabe~%")))
  (terpri pane)
  (with-drawing-options (pane :ink +white+)
    (format pane "  Navigate notes, tasks, systems, and signals.~%")
    (terpri pane)
    (format pane "  Create:~%")
    (format pane "    Capture Note [title]     — create a note~%")
    (format pane "    Add Task [title]         — create a task~%")
    (format pane "    New Project [name]       — create a project~%")
    (format pane "    Add Person [name]        — add a contact~%")
    (format pane "    Capture Snippet [text]   — save a snippet~%")
    (terpri pane)
    (format pane "  Actions:~%")
    (format pane "    Complete Task [task]     — mark task done~%")
    (format pane "    Link [source] [target]  — link two objects~%")
    (terpri pane)
    (format pane "  Delete:~%")
    (format pane "    Delete Note [note]       — soft-delete a note~%")
    (format pane "    Delete Task [task]       — soft-delete a task~%")
    (format pane "    Delete Project [project] — soft-delete a project~%")
    (format pane "    Delete Person [person]   — soft-delete a contact~%")
    (format pane "    Delete Snippet [snippet] — soft-delete a snippet~%")
    (terpri pane)
    (format pane "  Navigate:~%")
    (format pane "    Home                     — return to home~%")
    (format pane "    Quit                     — exit Astrolabe~%")
    (terpri pane)
    (format pane "  Quick keys:~%")
    (format pane "    C-n  Capture Note~%")
    (format pane "    C-t  Add Task~%")
    (format pane "    C-s  Search~%")
    (format pane "    C-h  Home~%")
    (terpri pane)
    (format pane "  Click any item to see its details.~%")
    (format pane "  Tab cycles focus between panes.~%")))

(defgeneric display-object-detail (pane object)
  (:documentation "Display the detail view for an object."))

(defun display-tags (pane object)
  "Display tags for an object, if any."
  (let ((tags (load-tags-for-object object)))
    (when tags
      (with-drawing-options (pane :ink +yellow+)
        (format pane "  Tags: ~{~A~^, ~}~%" (mapcar #'second tags))))))

(defmethod display-object-detail (pane (note note))
  (terpri pane)
  (with-drawing-options (pane :ink +cyan+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (note-title note))))
  (when (obj-created-at note)
    (with-drawing-options (pane :ink +white+)
      (format pane "  Created: ~A~%" (obj-created-at note))))
  (when (obj-updated-at note)
    (with-drawing-options (pane :ink +white+)
      (format pane "  Updated: ~A~%" (obj-updated-at note))))
  (terpri pane)
  (display-tags pane note)
  (terpri pane)
  (let ((body (note-body note)))
    (when (and body (> (length body) 0))
      (with-drawing-options (pane :ink +white+)
        (format pane "  ~A~%" body))))
  (display-links pane note))

(defmethod display-object-detail (pane (person person))
  (terpri pane)
  (with-drawing-options (pane :ink +magenta+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (person-name person))))
  (with-drawing-options (pane :ink +white+)
    (when (person-first-name person)
      (format pane "  Name:     ~A~A~%"
              (person-first-name person)
              (if (person-last-name person)
                  (format nil " ~A" (person-last-name person)) "")))
    (when (person-nickname person)
      (format pane "  Nickname: ~A~%" (person-nickname person)))
    (when (person-email person)
      (format pane "  Email:    ~A~%" (person-email person)))
    (when (person-email2 person)
      (format pane "  Email 2:  ~A~%" (person-email2 person)))
    (when (person-phone person)
      (format pane "  Phone:    ~A~%" (person-phone person)))
    (when (person-phone2 person)
      (format pane "  Phone 2:  ~A~%" (person-phone2 person)))
    (when (person-organization person)
      (format pane "  Org:      ~A~%" (person-organization person)))
    (when (person-job-title person)
      (format pane "  Title:    ~A~%" (person-job-title person)))
    (when (person-role person)
      (format pane "  Role:     ~A~%" (person-role person)))
    (when (person-website person)
      (format pane "  Website:  ~A~%" (person-website person)))
    (when (person-address person)
      (format pane "  Address:  ~A~%" (person-address person))
      (when (person-city person)
        (format pane "            ~A~A ~A~%"
                (person-city person)
                (if (person-state person)
                    (format nil ", ~A" (person-state person)) "")
                (or (person-postal-code person) "")))
      (when (person-country person)
        (format pane "            ~A~%" (person-country person))))
    (when (person-birthday person)
      (format pane "  Birthday: ~A~%" (person-birthday person)))
    (when (person-xmpp-jid person)
      (format pane "  XMPP:     ~A~%" (person-xmpp-jid person)))
    (when (person-matrix-id person)
      (format pane "  Matrix:   ~A~%" (person-matrix-id person)))
    (when (person-irc-nick person)
      (format pane "  IRC:      ~A~%" (person-irc-nick person)))
    (when (person-last-contacted person)
      (format pane "  Last contact: ~A~%" (person-last-contacted person)))
    (when (person-contact-frequency person)
      (format pane "  Frequency:    ~A~%" (person-contact-frequency person)))
    (when (obj-created-at person)
      (format pane "  Created:  ~A~%" (obj-created-at person))))
  (terpri pane)
  (let ((notes (person-notes person)))
    (when (and notes (> (length notes) 0))
      (with-drawing-options (pane :ink +white+)
        (format pane "  ~A~%" notes))
      (terpri pane)))
  (display-tags pane person)
  (display-links pane person))

(defmethod display-object-detail (pane (snippet snippet))
  (terpri pane)
  (with-drawing-options (pane :ink +white+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (obj-display-title snippet))))
  (with-drawing-options (pane :ink +white+)
    (format pane "  Type: ~A~%" (snippet-content-type snippet))
    (when (snippet-language snippet)
      (format pane "  Language: ~A~%" (snippet-language snippet)))
    (when (snippet-source snippet)
      (format pane "  Source: ~A~%" (snippet-source snippet)))
    (when (obj-created-at snippet)
      (format pane "  Created: ~A~%" (obj-created-at snippet))))
  (terpri pane)
  (with-drawing-options (pane :ink +white+)
    (format pane "  ~A~%" (snippet-content snippet)))
  (terpri pane)
  (display-tags pane snippet)
  (display-links pane snippet))

(defmethod display-object-detail (pane (task task))
  (terpri pane)
  (with-drawing-options (pane :ink (task-priority-ink (task-priority task)))
    (with-text-face (pane :bold)
      (format pane "  ~A ~A~%" (task-status-marker (task-status task)) (task-title task))))
  (with-drawing-options (pane :ink +white+)
    (format pane "  Status:   ~A~%" (task-status task))
    (format pane "  Priority: ~A~%" (task-priority task))
    (when (task-due-date task)
      (format pane "  Due:      ~A~%" (task-due-date task)))
    (when (task-scheduled-date task)
      (format pane "  Scheduled: ~A~%" (task-scheduled-date task)))
    (when (task-completed-at task)
      (format pane "  Completed: ~A~%" (task-completed-at task)))
    (when (task-context task)
      (format pane "  Context:  ~A~%" (task-context task)))
    (when (task-effort-minutes task)
      (format pane "  Effort:   ~Dmin~A~%" (task-effort-minutes task)
              (if (task-actual-minutes task)
                  (format nil " (actual: ~Dmin)" (task-actual-minutes task))
                  "")))
    (when (task-recurrence task)
      (format pane "  Recurs:   ~A~%" (task-recurrence task)))
    (when (obj-created-at task)
      (format pane "  Created:  ~A~%" (obj-created-at task))))
  (display-tags pane task)
  (terpri pane)
  (let ((desc (task-description task)))
    (when (and desc (> (length desc) 0))
      (with-drawing-options (pane :ink +white+)
        (format pane "  ~A~%" desc))
      (terpri pane)))
  (let ((notes (task-notes task)))
    (when (and notes (> (length notes) 0))
      (with-drawing-options (pane :ink +white+)
        (with-text-face (pane :bold)
          (format pane "  Notes:~%"))
        (format pane "  ~A~%" notes))
      (terpri pane)))
  ;; Subtasks
  (when (obj-id task)
    (let ((subtasks (load-subtasks (obj-id task))))
      (when subtasks
        (with-drawing-options (pane :ink +yellow+)
          (with-text-face (pane :bold)
            (format pane "  Subtasks:~%")))
        (dolist (st subtasks)
          (present-task pane st))
        (terpri pane))))
  (display-links pane task))

(defmethod display-object-detail (pane (project project))
  (terpri pane)
  (with-drawing-options (pane :ink +green+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (project-name project))))
  (with-drawing-options (pane :ink +white+)
    (format pane "  Status:   ~A~%" (project-status project))
    (format pane "  Priority: ~A~%" (project-priority project))
    (when (project-area project)
      (format pane "  Area:     ~A~%" (project-area project)))
    (when (project-start-date project)
      (format pane "  Started:  ~A~%" (project-start-date project)))
    (when (project-target-date project)
      (format pane "  Target:   ~A~%" (project-target-date project)))
    (when (project-completed-at project)
      (format pane "  Completed: ~A~%" (project-completed-at project)))
    (when (obj-created-at project)
      (format pane "  Created:  ~A~%" (obj-created-at project))))
  (display-tags pane project)
  (terpri pane)
  (let ((desc (project-description project)))
    (when (and desc (> (length desc) 0))
      (with-drawing-options (pane :ink +white+)
        (format pane "  ~A~%" desc))
      (terpri pane)))
  (let ((pnotes (project-notes project)))
    (when (and pnotes (> (length pnotes) 0))
      (with-drawing-options (pane :ink +white+)
        (with-text-face (pane :bold)
          (format pane "  Notes:~%"))
        (format pane "  ~A~%" pnotes))
      (terpri pane)))
  ;; Task progress
  (let ((tasks (load-project-tasks (obj-id project))))
    (let ((total (length tasks))
          (done (count-if (lambda (tk) (string-equal (task-status tk) "done")) tasks)))
      (with-drawing-options (pane :ink +yellow+)
        (with-text-face (pane :bold)
          (format pane "  Tasks: ~D/~D complete~%" done total))))
    ;; Show open tasks inline
    (let ((open (remove-if (lambda (tk) (string-equal (task-status tk) "done")) tasks)))
      (dolist (task open)
        (present-task pane task))))
  (terpri pane)
  ;; Linked persons
  (let* ((linked (load-linked-objects project))
         (persons nil))
    (dolist (link linked)
      (when (string-equal (first link) "person")
        (let ((p (load-person (second link))))
          (when p (push p persons)))))
    (when persons
      (with-drawing-options (pane :ink +magenta+)
        (with-text-face (pane :bold)
          (format pane "  People:~%")))
      (dolist (p (nreverse persons))
        (present-person pane p))
      (terpri pane)))
  (display-links pane project))

(defmethod display-object-detail (pane (conv conversation))
  (terpri pane)
  (with-drawing-options (pane :ink +cyan+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (obj-display-title conv))))
  (with-drawing-options (pane :ink +white+)
    (format pane "  JID:     ~A~%" (conv-jid conv))
    (format pane "  Type:    ~A~%" (conv-type conv))
    (when (conv-last-activity conv)
      (format pane "  Last:    ~A~%" (conv-last-activity conv)))
    (format pane "  Unread:  ~D~%" (conv-unread-count conv)))
  (terpri pane)
  ;; Show recent messages in detail pane
  (let ((msgs (load-messages (conv-id conv) 20)))
    (when msgs
      (with-drawing-options (pane :ink +white+)
        (with-text-face (pane :bold)
          (format pane "  Recent messages:~%")))
      (terpri pane)
      (dolist (msg (nreverse msgs))
        (let ((nick (or (xmsg-sender-nick msg) "???"))
              (body (xmsg-body msg))
              (ts   (xmsg-created-at msg)))
          (with-drawing-options (pane :ink (if (equal nick "me") +green+ +cyan+))
            (format pane "  <~A> ~A" nick body))
          (when ts
            (with-drawing-options (pane :ink +white+)
              (format pane "  ~A" (subseq ts 11 16))))
          (terpri pane))))))

(defmethod display-object-detail (pane (fi feed-item))
  (terpri pane)
  (with-drawing-options (pane :ink +cyan+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (obj-display-title fi))))
  (with-drawing-options (pane :ink +white+)
    (when (fi-author fi)
      (format pane "  Author:    ~A~%" (fi-author fi)))
    (when (fi-published-at fi)
      (format pane "  Published: ~A~%" (fi-published-at fi)))
    (when (fi-url fi)
      (format pane "  URL:       ~A~%" (fi-url fi)))
    (format pane "  Read:      ~A~%" (if (= (fi-read fi) 1) "yes" "no"))
    (when (= (fi-starred fi) 1)
      (format pane "  Starred:   yes~%")))
  (terpri pane)
  (let ((content (or (fi-content fi) (fi-summary fi) "")))
    (when (> (length content) 0)
      (with-drawing-options (pane :ink +white+)
        (format pane "  ~A~%" content)))))

(defmethod display-object-detail (pane (f feed))
  (terpri pane)
  (with-drawing-options (pane :ink +green+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (obj-display-title f))))
  (with-drawing-options (pane :ink +white+)
    (format pane "  URL:       ~A~%" (feed-url f))
    (when (feed-site-url f)
      (format pane "  Site:      ~A~%" (feed-site-url f)))
    (format pane "  Type:      ~A~%" (feed-feed-type f))
    (format pane "  Unread:    ~D~%" (feed-unread-count f))
    (when (feed-last-fetched f)
      (format pane "  Fetched:   ~A~%" (feed-last-fetched f)))
    (when (and (feed-last-error f) (> (length (feed-last-error f)) 0))
      (with-drawing-options (pane :ink +red+)
        (format pane "  Error:     ~A~%" (feed-last-error f))))
    (when (feed-description f)
      (terpri pane)
      (format pane "  ~A~%" (feed-description f)))))

(defun display-links (pane object)
  "Display linked objects for OBJECT."
  (let ((linked (load-linked-objects object)))
    (when linked
      (with-drawing-options (pane :ink +white+)
        (with-text-face (pane :bold)
          (format pane "  Linked:~%")))
      (dolist (link linked)
        (let* ((type-name (first link))
               (id (second link))
               (relation (third link))
               (obj (load-object-by-type-and-id type-name id)))
          (when obj
            (with-drawing-options (pane :ink +white+)
              (format pane "    ~A " (or relation "—")))
            (present-object pane obj)))))))
