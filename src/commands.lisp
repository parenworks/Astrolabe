;;;; commands.lisp — CLIM commands for Astrolabe

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Navigation state — tracks what the detail pane should show
;;; ─────────────────────────────────────────────────────────────────────

;;; The current view determines what the navigation pane displays.
;;; Values: :home, :project, :search
(defvar *current-view* :home)

;;; The currently selected object shown in the detail pane.
(defvar *current-object* nil)

;;; When viewing a project, this holds the project object.
(defvar *current-project* nil)

;;; Current search query and results for :search view.
(defvar *search-query* nil)
(defvar *search-results* nil)

;;; Current tag filter for :tag-filter view.
(defvar *filter-tag* nil)
(defvar *filter-results* nil)

;;; Current task filter view: :all, :today, or a project object.
(defvar *task-filter* nil)
(defvar *task-filter-results* nil)

;;; Navigation history stacks for back/forward.
(defvar *nav-history* nil)
(defvar *nav-forward* nil)

(defun current-nav-state ()
  "Capture the current navigation state as a plist."
  (list :view *current-view*
        :object *current-object*
        :project *current-project*))

(defun restore-nav-state (state)
  "Restore navigation state from a plist."
  (setf *current-view* (getf state :view))
  (setf *current-object* (getf state :object))
  (setf *current-project* (getf state :project)))

(defun push-nav-state ()
  "Push current state onto history before navigating."
  (push (current-nav-state) *nav-history*)
  (setf *nav-forward* nil))

;;; ─────────────────────────────────────────────────────────────────────
;;; Show commands — display objects in the detail pane
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-show-note :name t :menu t)
    ((note 'note-presentation :prompt "note"))
  (push-nav-state)
  (setf *current-object* note))

(define-astrolabe-command (com-show-task :name t :menu t)
    ((task 'task-presentation :prompt "task"))
  (push-nav-state)
  (setf *current-object* task))

(define-astrolabe-command (com-show-project :name t :menu t)
    ((project 'project-presentation :prompt "project"))
  (push-nav-state)
  (setf *current-view* :project)
  (setf *current-project* project)
  (setf *current-object* project))

(define-astrolabe-command (com-show-person :name t :menu t)
    ((person 'person-presentation :prompt "person"))
  (push-nav-state)
  (setf *current-object* person))

(define-astrolabe-command (com-show-snippet :name t :menu t)
    ((snippet 'snippet-presentation :prompt "snippet"))
  (push-nav-state)
  (setf *current-object* snippet))

(define-astrolabe-command (com-home :name t :menu t) ()
  (push-nav-state)
  (setf *current-view* :home)
  (setf *current-object* nil)
  (setf *current-project* nil))

(define-astrolabe-command (com-back :name t :menu t) ()
  (if *nav-history*
      (let ((prev (pop *nav-history*)))
        (push (current-nav-state) *nav-forward*)
        (restore-nav-state prev))
      (format t "~&No history.~%")))

(define-astrolabe-command (com-forward :name t :menu t) ()
  (if *nav-forward*
      (let ((next (pop *nav-forward*)))
        (push (current-nav-state) *nav-history*)
        (restore-nav-state next))
      (format t "~&No forward history.~%")))

;;; ─────────────────────────────────────────────────────────────────────
;;; Create commands
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-capture-note :name t :menu t)
    ((title 'string :prompt "Note title"))
  (let ((note (save-note (make-instance 'note :title title))))
    ;; Auto-link to current project context
    (when *current-project*
      (create-link *current-project* note "contains"))
    (setf *current-object* note)
    (format t "~&Note captured: ~A~%" title)))

(define-astrolabe-command (com-add-task :name t :menu t)
    ((title 'string :prompt "Task title"))
  (let ((task (save-task (make-instance 'task :title title))))
    ;; Auto-link to current project context
    (when *current-project*
      (create-link *current-project* task "contains"))
    (setf *current-object* task)
    (format t "~&Task added: ~A~%" title)))

(define-astrolabe-command (com-new-project :name t :menu t)
    ((name 'string :prompt "Project name"))
  (let ((project (save-project (make-instance 'project :name name))))
    (setf *current-view* :project)
    (setf *current-project* project)
    (setf *current-object* project)
    (format t "~&Project created: ~A~%" name)))

(define-astrolabe-command (com-add-person :name t :menu t)
    ((name 'string :prompt "Person name"))
  (let ((person (save-person (make-instance 'person :name name))))
    (when *current-project*
      (create-link *current-project* person "member"))
    (setf *current-object* person)
    (format t "~&Person added: ~A~%" name)))

(define-astrolabe-command (com-capture-snippet :name t :menu t)
    ((content 'string :prompt "Snippet content"))
  (let ((snippet (save-snippet (make-instance 'snippet :content content))))
    (when *current-project*
      (create-link *current-project* snippet "contains"))
    (setf *current-object* snippet)
    (format t "~&Snippet captured.~%")))

;;; ─────────────────────────────────────────────────────────────────────
;;; Action commands
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-complete-task :name t :menu t)
    ((task 'task-presentation :prompt "task"))
  (complete-task task)
  (format t "~&Task completed: ~A~%" (task-title task)))

(define-astrolabe-command (com-link :name t :menu t)
    ((source 'astrolabe-obj :prompt "source object")
     (target 'astrolabe-obj :prompt "target object"))
  (create-link source target)
  (format t "~&Linked ~A → ~A~%"
          (obj-display-title source) (obj-display-title target)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Delete commands — soft-delete for every object type
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-delete-note :name t :menu t)
    ((note 'note-presentation :prompt "note"))
  (format t "~&Delete note '~A'? " (note-title note))
  (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
    (when (string-equal confirm "yes")
      (delete-note note)
      (when (eq *current-object* note) (setf *current-object* nil))
      (format t "~&Deleted note: ~A~%" (note-title note)))))

(define-astrolabe-command (com-delete-task :name t :menu t)
    ((task 'task-presentation :prompt "task"))
  (format t "~&Delete task '~A'? " (task-title task))
  (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
    (when (string-equal confirm "yes")
      (delete-task task)
      (when (eq *current-object* task) (setf *current-object* nil))
      (format t "~&Deleted task: ~A~%" (task-title task)))))

(define-astrolabe-command (com-delete-project :name t :menu t)
    ((project 'project-presentation :prompt "project"))
  (format t "~&Delete project '~A'? " (project-name project))
  (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
    (when (string-equal confirm "yes")
      (delete-project project)
      (when (eq *current-object* project)
        (setf *current-object* nil)
        (setf *current-view* :home)
        (setf *current-project* nil))
      (format t "~&Deleted project: ~A~%" (project-name project)))))

(define-astrolabe-command (com-delete-person :name t :menu t)
    ((person 'person-presentation :prompt "person"))
  (format t "~&Delete person '~A'? " (person-name person))
  (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
    (when (string-equal confirm "yes")
      (delete-person person)
      (when (eq *current-object* person) (setf *current-object* nil))
      (format t "~&Deleted person: ~A~%" (person-name person)))))

(define-astrolabe-command (com-delete-snippet :name t :menu t)
    ((snippet 'snippet-presentation :prompt "snippet"))
  (format t "~&Delete snippet '~A'? " (obj-display-title snippet))
  (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
    (when (string-equal confirm "yes")
      (delete-snippet snippet)
      (when (eq *current-object* snippet) (setf *current-object* nil))
      (format t "~&Deleted snippet: ~A~%" (obj-display-title snippet)))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Search
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-search :name t :menu t)
    ((query 'string :prompt "Search query"))
  (setf *search-query* query)
  (setf *search-results* (search-all query))
  (setf *current-view* :search)
  (setf *current-object* nil)
  (format t "~&Found ~D results for '~A'~%" (length *search-results*) query))

;;; ─────────────────────────────────────────────────────────────────────
;;; Tagging
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-tag :name t :menu t)
    ((object 'astrolabe-obj :prompt "object")
     (tag-name 'string :prompt "Tag name"))
  (tag-object object tag-name)
  (format t "~&Tagged ~A with '~A'~%" (obj-display-title object) tag-name))

(define-astrolabe-command (com-untag :name t :menu t)
    ((object 'astrolabe-obj :prompt "object")
     (tag-name 'string :prompt "Tag name"))
  (untag-object object tag-name)
  (format t "~&Removed tag '~A' from ~A~%" tag-name (obj-display-title object)))

(define-astrolabe-command (com-filter-tag :name t :menu t)
    ((tag-name 'string :prompt "Tag name"))
  (let* ((rows (load-objects-by-tag tag-name))
         (objects (loop for row in rows
                        for obj = (load-object-by-type-and-id (first row) (second row))
                        when obj collect obj)))
    (setf *filter-tag* tag-name)
    (setf *filter-results* objects)
    (setf *current-view* :tag-filter)
    (setf *current-object* nil)
    (format t "~&~D objects tagged '~A'~%" (length objects) tag-name)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Task views
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-show-tasks :name t :menu t) ()
  (setf *task-filter* :all)
  (setf *task-filter-results* (load-open-tasks 100))
  (setf *current-view* :tasks)
  (setf *current-object* nil)
  (format t "~&Showing ~D open tasks~%" (length *task-filter-results*)))

(define-astrolabe-command (com-show-tasks-today :name t :menu t) ()
  (let* ((today (subseq (local-time:format-timestring nil (local-time:now)
                          :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                        0 10))
         (tasks (mapcar #'make-task-from-row
                        (db-query (format nil "SELECT ~A FROM tasks
                                   WHERE deleted_at IS NULL
                                     AND status IN ('todo','active','waiting')
                                     AND due_date <= ?
                                   ORDER BY priority ASC, due_date ASC" *task-cols*)
                                  today))))
    (setf *task-filter* :today)
    (setf *task-filter-results* tasks)
    (setf *current-view* :tasks)
    (setf *current-object* nil)
    (format t "~&~D tasks due today or overdue~%" (length tasks))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Fuzzy finder
;;; ─────────────────────────────────────────────────────────────────────

(defvar *go-results* nil)

(define-astrolabe-command (com-go :name t :menu t)
    ((partial 'string :prompt "Jump to"))
  (let ((results (fuzzy-find partial)))
    (cond
      ((null results)
       (format t "~&No matches for '~A'~%" partial))
      ((= (length results) 1)
       (push-nav-state)
       (let ((obj (first results)))
         (setf *current-object* obj)
         (when (typep obj 'project)
           (setf *current-view* :project)
           (setf *current-project* obj))))
      (t
       (setf *go-results* results)
       (setf *current-view* :go-results)
       (setf *current-object* nil)
       (format t "~&~D matches for '~A'~%" (length results) partial)))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Agenda view
;;; ─────────────────────────────────────────────────────────────────────

(defvar *agenda-overdue* nil)
(defvar *agenda-today* nil)
(defvar *agenda-upcoming* nil)
(defvar *agenda-recent* nil)

(define-astrolabe-command (com-agenda :name t :menu t) ()
  (push-nav-state)
  (setf *agenda-overdue* (load-overdue-tasks))
  (let* ((today-str (subseq (local-time:format-timestring nil (local-time:now)
                              :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                            0 10))
         (today-tasks (mapcar #'make-task-from-row
                              (db-query (format nil "SELECT ~A FROM tasks
                                         WHERE deleted_at IS NULL
                                           AND status IN ('todo','active','waiting')
                                           AND due_date = ?
                                         ORDER BY priority ASC" *task-cols*)
                                        today-str))))
    (setf *agenda-today* today-tasks))
  (setf *agenda-upcoming* (load-upcoming-tasks 7))
  (setf *agenda-recent* (load-recent-captures))
  (setf *current-view* :agenda)
  (setf *current-object* nil))

;;; ─────────────────────────────────────────────────────────────────────
;;; Bookmarks
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-bookmark :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (bookmark-object object)
  (format t "~&Bookmarked: ~A~%" (obj-display-title object)))

(define-astrolabe-command (com-unbookmark :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (unbookmark-object object)
  (format t "~&Removed bookmark: ~A~%" (obj-display-title object)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Note editing
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-edit-note :name t :menu t)
    ((note 'note-presentation :prompt "note")
     (body 'string :prompt "New body"))
  (setf (note-body note) body)
  (save-note note)
  (setf *current-object* note)
  (format t "~&Note body updated.~%"))

(define-astrolabe-command (com-append-note :name t :menu t)
    ((note 'note-presentation :prompt "note")
     (text 'string :prompt "Text to append"))
  (setf (note-body note)
        (if (and (note-body note) (> (length (note-body note)) 0))
            (concatenate 'string (note-body note) (string #\Newline) text)
            text))
  (save-note note)
  (setf *current-object* note)
  (format t "~&Appended to note.~%"))

;;; ─────────────────────────────────────────────────────────────────────
;;; XMPP — Show conversations, message thread, send message
;;; ─────────────────────────────────────────────────────────────────────

(defvar *current-conversation* nil)
(defvar *current-messages* nil)

(define-astrolabe-command (com-show-conversations :name t :menu t) ()
  (push-nav-state)
  (setf *current-view* :conversations)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-conversation :name t :menu t)
    ((conv 'conversation-presentation :prompt "conversation"))
  (push-nav-state)
  (setf *current-conversation* conv)
  (setf *current-messages* (nreverse (load-messages (conv-id conv))))
  (mark-conversation-read conv)
  (setf *current-view* :conversation)
  (setf *current-object* conv))

(define-astrolabe-command (com-message :name t :menu t)
    ((jid 'string :prompt "JID")
     (body 'string :prompt "Message"))
  (let ((conv (or (load-conversation-by-jid jid)
                  (save-conversation (make-instance 'conversation
                                                    :jid jid
                                                    :display-name jid
                                                    :conv-type "dm")))))
    (save-xmpp-message (make-instance 'xmpp-message
                                      :conversation-id (conv-id conv)
                                      :sender-nick "me"
                                      :body body))
    (create-notification "message" (format nil "Sent to ~A" jid)
                         :body body
                         :object-type "conversation" :object-id (conv-id conv))
    (format t "~&Message sent to ~A~%" jid)))

;;; ─────────────────────────────────────────────────────────────────────
;;; RSS/Atom feeds
;;; ─────────────────────────────────────────────────────────────────────

(defvar *current-feed* nil)
(defvar *current-feed-items* nil)

(define-astrolabe-command (com-subscribe :name t :menu t)
    ((url 'string :prompt "Feed URL"))
  (let ((existing (db-query-single
                   (format nil "SELECT ~A FROM feeds WHERE url=? AND deleted_at IS NULL" *feed-cols*) url)))
    (if existing
        (format t "~&Already subscribed to ~A~%" url)
        (let ((feed (save-feed (make-instance 'feed :url url :title url))))
          (format t "~&Subscribed to ~A~%" url)
          (create-notification "feed" (format nil "Subscribed: ~A" url)
                               :object-type "feed" :object-id (feed-id feed))))))

(define-astrolabe-command (com-unsubscribe :name t :menu t)
    ((feed 'feed-presentation :prompt "feed"))
  (format t "~&Unsubscribe from '~A'? " (obj-display-title feed))
  (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
    (when (string-equal confirm "yes")
      (delete-feed feed)
      (format t "~&Unsubscribed from ~A~%" (obj-display-title feed)))))

(define-astrolabe-command (com-show-feeds :name t :menu t) ()
  (push-nav-state)
  (setf *current-view* :feeds)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-feed :name t :menu t)
    ((feed 'feed-presentation :prompt "feed"))
  (push-nav-state)
  (setf *current-feed* feed)
  (setf *current-feed-items* (load-feed-items (feed-id feed)))
  (setf *current-view* :feed-items)
  (setf *current-object* feed))

(define-astrolabe-command (com-fetch-feed :name t :menu t)
    ((feed 'feed-presentation :prompt "feed"))
  (format t "~&Fetching ~A...~%" (obj-display-title feed))
  (let ((new-count (fetch-and-store-feed feed)))
    (if (feed-last-error feed)
        (format t "~&Error: ~A~%" (feed-last-error feed))
        (progn
          (format t "~&~D new article~:P~%" new-count)
          (when (> new-count 0)
            (create-notification "feed" (format nil "~D new from ~A" new-count (obj-display-title feed))
                                 :object-type "feed" :object-id (feed-id feed)))))))

(define-astrolabe-command (com-fetch-all-feeds :name t :menu t) ()
  (let ((feeds (load-feeds 100))
        (total 0))
    (dolist (feed feeds)
      (format t "~&Fetching ~A... " (obj-display-title feed))
      (let ((n (fetch-and-store-feed feed)))
        (if (feed-last-error feed)
            (format t "error~%")
            (progn
              (format t "~D new~%" n)
              (incf total n)))))
    (format t "~&Done. ~D new article~:P total.~%" total)
    (when (> total 0)
      (create-notification "feed" (format nil "~D new articles from ~D feeds" total (length feeds))))))

(define-astrolabe-command (com-show-feed-item :name t :menu t)
    ((fi 'feed-item-presentation :prompt "article"))
  (push-nav-state)
  (mark-feed-item-read fi)
  (setf *current-object* fi))

(define-astrolabe-command (com-capture-article :name t :menu t)
    ((fi 'feed-item-presentation :prompt "article"))
  (let ((note (save-note (make-instance 'note
                                        :title (or (fi-title fi) "Captured article")
                                        :body (format nil "~A~%~%Source: ~A~%~%~A"
                                                      (or (fi-title fi) "")
                                                      (or (fi-url fi) "")
                                                      (or (fi-summary fi) (fi-content fi) ""))))))
    (setf *current-object* note)
    (format t "~&Captured article as note: ~A~%" (note-title note))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Notifications
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-show-notifications :name t :menu t) ()
  (push-nav-state)
  (setf *current-view* :notifications)
  (setf *current-object* nil))

(define-astrolabe-command (com-dismiss-notification :name t :menu t)
    ((notif 'notification-presentation :prompt "notification"))
  (mark-notification-read notif)
  (when (and (notif-object-type notif) (notif-object-id notif))
    (let ((obj (load-object-by-type-and-id (notif-object-type notif) (notif-object-id notif))))
      (when obj (setf *current-object* obj))))
  (format t "~&Notification dismissed.~%"))

(define-astrolabe-command (com-dismiss-all-notifications :name t :menu t) ()
  (mark-all-notifications-read)
  (format t "~&All notifications dismissed.~%"))

;;; ─────────────────────────────────────────────────────────────────────
;;; Shell integration
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-shell :name t :menu t)
    ((command 'string :prompt "Shell command"))
  (format t "~&$ ~A~%" command)
  (multiple-value-bind (output exit-code) (run-shell-command command)
    (setf *shell-command* command)
    (setf *shell-output* output)
    (setf *shell-exit-code* exit-code)
    (setf *current-view* :shell)
    (setf *current-object* nil)
    (format t "~&Exit ~D~%" exit-code)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Templates
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-list-templates :name t :menu t) ()
  (let ((templates (list-templates)))
    (if templates
        (progn
          (format t "~&Available templates:~%")
          (dolist (name templates)
            (format t "  ~A~%" name)))
        (format t "~&No templates found in ~A~%" *templates-dir*))))

(define-astrolabe-command (com-capture-note-template :name t :menu t)
    ((template-name 'string :prompt "Template name"))
  (let ((tmpl (load-template template-name)))
    (if tmpl
        (let* ((expanded (expand-template tmpl))
               (lines (cl-ppcre:split "\\n" expanded))
               (title (or (first lines) template-name))
               (body (format nil "~{~A~^~%~}" (rest lines)))
               (note (save-note (make-instance 'note :title title :body body))))
          (run-hooks "after-save-note" note)
          (when *current-project*
            (create-link *current-project* note "contains"))
          (setf *current-object* note)
          (format t "~&Note created from template '~A': ~A~%" template-name title))
        (format t "~&Template '~A' not found.~%" template-name))))

(define-astrolabe-command (com-add-task-template :name t :menu t)
    ((template-name 'string :prompt "Template name"))
  (let ((tmpl (load-template template-name)))
    (if tmpl
        (let* ((expanded (expand-template tmpl))
               (lines (cl-ppcre:split "\\n" expanded))
               (title (or (first lines) template-name))
               (desc (format nil "~{~A~^~%~}" (rest lines)))
               (task (save-task (make-instance 'task :title title :description desc))))
          (run-hooks "after-save-task" task)
          (when *current-project*
            (create-link *current-project* task "contains"))
          (setf *current-object* task)
          (format t "~&Task created from template '~A': ~A~%" template-name title))
        (format t "~&Template '~A' not found.~%" template-name))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Export
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-export :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (let ((md (export-object-markdown object)))
    (setf *shell-command* (format nil "Export: ~A" (obj-display-title object)))
    (setf *shell-output* md)
    (setf *shell-exit-code* 0)
    (setf *current-view* :shell)
    (format t "~&Exported ~A to detail pane.~%" (obj-display-title object))))

(define-astrolabe-command (com-export-file :name t :menu t)
    ((object 'astrolabe-obj :prompt "object")
     (path 'string :prompt "File path"))
  (let ((md (export-object-markdown object)))
    (with-open-file (s path :direction :output :if-exists :supersede)
      (write-string md s))
    (format t "~&Exported ~A to ~A~%" (obj-display-title object) path)))

(define-astrolabe-command (com-export-project-report :name t :menu t)
    ((project 'project-presentation :prompt "project"))
  (let ((report (export-project-report project)))
    (setf *shell-command* (format nil "Report: ~A" (project-name project)))
    (setf *shell-output* report)
    (setf *shell-exit-code* 0)
    (setf *current-view* :shell)
    (format t "~&Generated report for ~A.~%" (project-name project))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Scheduled actions
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-check-reminders :name t :menu t) ()
  (let ((count (check-reminders)))
    (if (> count 0)
        (format t "~&~D reminder~:P created.~%" count)
        (format t "~&No new reminders.~%"))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Batch operations
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-select :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (let ((count (batch-select object)))
    (format t "~&Selected ~A (~D in batch)~%" (obj-display-title object) count)))

(define-astrolabe-command (com-deselect :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (let ((count (batch-deselect object)))
    (format t "~&Deselected ~A (~D in batch)~%" (obj-display-title object) count)))

(define-astrolabe-command (com-clear-selection :name t :menu t) ()
  (batch-clear)
  (format t "~&Selection cleared.~%"))

(define-astrolabe-command (com-show-selection :name t :menu t) ()
  (if *batch-selection*
      (progn
        (format t "~&~D objects selected:~%" (length *batch-selection*))
        (dolist (obj *batch-selection*)
          (format t "  ~A: ~A~%" (obj-type-name obj) (obj-display-title obj))))
      (format t "~&No objects selected.~%")))

(define-astrolabe-command (com-batch-tag :name t :menu t)
    ((tag-name 'string :prompt "Tag name"))
  (if *batch-selection*
      (let ((count (batch-apply-tag tag-name)))
        (format t "~&Tagged ~D objects with '~A'.~%" count tag-name))
      (format t "~&No objects selected.~%")))

(define-astrolabe-command (com-batch-complete :name t :menu t) ()
  (if *batch-selection*
      (let ((count (batch-complete-tasks)))
        (format t "~&Completed ~D task~:P.~%" count)
        (batch-clear))
      (format t "~&No objects selected.~%")))

(define-astrolabe-command (com-batch-delete :name t :menu t) ()
  (if *batch-selection*
      (progn
        (format t "~&Delete ~D objects? " (length *batch-selection*))
        (let ((confirm (accept 'string :prompt "yes/no" :default "no")))
          (when (string-equal confirm "yes")
            (let ((count (batch-delete)))
              (format t "~&Deleted ~D objects.~%" count)))))
      (format t "~&No objects selected.~%")))

;;; ─────────────────────────────────────────────────────────────────────
;;; LLM commands
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-summarize :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Summarizing ~A...~%" (obj-display-title object))
        (let ((result (llm-summarize object)))
          (if result
              (progn
                (setf *current-view* :llm)
                (setf *current-object* nil)
                (format t "~&Done.~%"))
              (format t "~&LLM error: ~A~%" (or *llm-response* "unknown")))))))

(define-astrolabe-command (com-extract-tasks :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Extracting tasks from ~A...~%" (obj-display-title object))
        (let ((result (llm-extract-tasks object)))
          (if result
              (progn
                (setf *current-view* :llm)
                (setf *current-object* nil)
                (format t "~&Done.~%"))
              (format t "~&LLM error: ~A~%" (or *llm-response* "unknown")))))))

(define-astrolabe-command (com-rewrite :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Rewriting ~A...~%" (obj-display-title object))
        (let ((result (llm-rewrite object)))
          (if result
              (progn
                (setf *current-view* :llm)
                (setf *current-object* nil)
                (format t "~&Done.~%"))
              (format t "~&LLM error: ~A~%" (or *llm-response* "unknown")))))))

(define-astrolabe-command (com-explain :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Explaining ~A...~%" (obj-display-title object))
        (let ((result (llm-explain object)))
          (if result
              (progn
                (setf *current-view* :llm)
                (setf *current-object* nil)
                (format t "~&Done.~%"))
              (format t "~&LLM error: ~A~%" (or *llm-response* "unknown")))))))

(define-astrolabe-command (com-auto-tag :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Suggesting tags for ~A...~%" (obj-display-title object))
        (let ((tags (llm-auto-tag object)))
          (if tags
              (format t "~&Applied tags: ~{~A~^, ~}~%" tags)
              (format t "~&No tags suggested.~%"))))))

(define-astrolabe-command (com-ask :name t :menu t)
    ((question 'string :prompt "Question"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Thinking...~%")
        ;; Gather context from recent notes and tasks
        (let* ((notes (load-recent-notes 5))
               (tasks (load-open-tasks 10))
               (context (with-output-to-string (s)
                          (dolist (n notes)
                            (format s "Note: ~A~%" (note-title n))
                            (when (note-body n) (format s "~A~%~%" (note-body n))))
                          (dolist (tk tasks)
                            (format s "Task [~A]: ~A~A~%"
                                    (task-priority tk) (task-title tk)
                                    (if (task-due-date tk)
                                        (format nil " (due ~A)" (task-due-date tk)) "")))))
               (result (llm-ask question :context context)))
          (if result
              (progn
                (setf *current-view* :llm)
                (setf *current-object* nil)
                (format t "~&Done.~%"))
              (format t "~&LLM error: ~A~%" (or *llm-response* "unknown")))))))

(define-astrolabe-command (com-daily-digest :name t :menu t) ()
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Generating daily digest...~%")
        (let ((result (llm-daily-digest)))
          (if result
              (progn
                (setf *current-view* :llm)
                (setf *current-object* nil)
                (format t "~&Done.~%"))
              (format t "~&LLM error: ~A~%" (or *llm-response* "unknown")))))))

(define-astrolabe-command (com-similar :name t :menu t)
    ((object 'astrolabe-obj :prompt "object"))
  (if (not *llm-available*)
      (format t "~&Ollama is not running. Start it with: ollama serve~%")
      (progn
        (format t "~&Finding similar objects...~%")
        ;; Use the LLM to generate search keywords, then run FTS
        (let* ((text (object-to-llm-text object))
               (keywords (llm-generate
                          (format nil "Extract 3-5 search keywords from this text. Output only the keywords separated by spaces, nothing else:~%~%~A" text)
                          :system "Output only space-separated keywords, no explanation.")))
          (if keywords
              (let* ((cleaned (string-trim '(#\Space #\Newline #\Return) keywords))
                     (results (search-all cleaned)))
                (setf *search-query* (format nil "Similar to: ~A" (obj-display-title object)))
                (setf *search-results* (remove object results :test #'eq))
                (setf *current-view* :search)
                (setf *current-object* nil)
                (format t "~&Found ~D similar objects.~%" (length *search-results*)))
              (format t "~&Could not generate search terms.~%"))))))

(define-astrolabe-command (com-set-model :name t :menu t)
    ((model-name 'string :prompt "Model name"))
  (setf *ollama-model* model-name)
  (format t "~&LLM model set to: ~A~%" model-name))

;;; ─────────────────────────────────────────────────────────────────────
;;; Phase 6: Extended object commands
;;; ─────────────────────────────────────────────────────────────────────

;; ── Journal ──────────────────────────────────────────────────────────

(define-astrolabe-command (com-journal :name t :menu t) ()
  (let* ((today (subseq (local-time:format-timestring nil (local-time:now)
                          :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                        0 10))
         (existing (load-journal-entry-by-date today)))
    (if existing
        (progn
          (format t "~&Appending to today's journal...~%")
          (let ((text (accept 'string :prompt "text")))
            (setf (je-body existing)
                  (concatenate 'string (je-body existing) (string #\Newline) text))
            (save-journal-entry existing)
            (setf *current-object* existing)
            (format t "~&Journal updated.~%")))
        (progn
          (format t "~&New journal entry for ~A~%" today)
          (let ((text (accept 'string :prompt "text")))
            (let ((je (make-instance 'journal-entry :entry-date today :body text)))
              (save-journal-entry je)
              (setf *current-object* je)
              (format t "~&Journal entry created.~%")))))))

(define-astrolabe-command (com-show-journal :name t :menu t) ()
  (setf *current-view* :journal)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-journal-entry :name t :menu t)
    ((je 'journal-presentation :prompt "entry"))
  (setf *current-object* je))

;; ── Document ─────────────────────────────────────────────────────────

(define-astrolabe-command (com-add-document :name t :menu t)
    ((title 'string :prompt "title"))
  (let* ((path (accept 'string :prompt "file path" :default ""))
         (ftype (accept 'string :prompt "type (pdf/md/txt)" :default ""))
         (doc (make-instance 'document :title title
                             :file-path (if (> (length path) 0) path nil)
                             :file-type (if (> (length ftype) 0) ftype nil))))
    (save-document doc)
    (setf *current-object* doc)
    (format t "~&Document '~A' created.~%" title)))

(define-astrolabe-command (com-show-documents :name t :menu t) ()
  (setf *current-view* :documents)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-document :name t :menu t)
    ((doc 'document-presentation :prompt "document"))
  (setf *current-object* doc))

(define-astrolabe-command (com-delete-document :name t :menu t)
    ((doc 'document-presentation :prompt "document"))
  (delete-document doc)
  (when (eq *current-object* doc) (setf *current-object* nil))
  (format t "~&Document deleted.~%"))

;; ── Event ────────────────────────────────────────────────────────────

(define-astrolabe-command (com-add-event :name t :menu t)
    ((title 'string :prompt "title"))
  (let* ((start (accept 'string :prompt "start (YYYY-MM-DD HH:MM)"))
         (end-str (accept 'string :prompt "end (or empty)" :default ""))
         (loc (accept 'string :prompt "location (or empty)" :default ""))
         (evt (make-instance 'event :title title :start-time start
                             :end-time (if (> (length end-str) 0) end-str nil)
                             :location (if (> (length loc) 0) loc nil))))
    (save-event evt)
    (setf *current-object* evt)
    (format t "~&Event '~A' created.~%" title)))

(define-astrolabe-command (com-show-events :name t :menu t) ()
  (setf *current-view* :events)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-event :name t :menu t)
    ((evt 'event-presentation :prompt "event"))
  (setf *current-object* evt))

(define-astrolabe-command (com-cancel-event :name t :menu t)
    ((evt 'event-presentation :prompt "event"))
  (setf (event-status evt) "cancelled")
  (save-event evt)
  (format t "~&Event cancelled.~%"))

(define-astrolabe-command (com-delete-event :name t :menu t)
    ((evt 'event-presentation :prompt "event"))
  (delete-event evt)
  (when (eq *current-object* evt) (setf *current-object* nil))
  (format t "~&Event deleted.~%"))

;; ── Invoice ──────────────────────────────────────────────────────────

(define-astrolabe-command (com-add-invoice :name t :menu t)
    ((title 'string :prompt "title"))
  (let* ((itype (accept 'string :prompt "type (invoice/contract/quote/receipt)" :default "invoice"))
         (amount-str (accept 'string :prompt "amount (or empty)" :default ""))
         (currency (accept 'string :prompt "currency" :default "USD"))
         (counterparty (accept 'string :prompt "counterparty (or empty)" :default ""))
         (due (accept 'string :prompt "due date YYYY-MM-DD (or empty)" :default ""))
         (inv (make-instance 'invoice :title title :inv-type itype
                             :amount (if (> (length amount-str) 0) (read-from-string amount-str) nil)
                             :currency currency
                             :counterparty (if (> (length counterparty) 0) counterparty nil)
                             :due-date (if (> (length due) 0) due nil))))
    (save-invoice inv)
    (setf *current-object* inv)
    (format t "~&Invoice '~A' created.~%" title)))

(define-astrolabe-command (com-show-invoices :name t :menu t) ()
  (setf *current-view* :invoices)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-invoice :name t :menu t)
    ((inv 'invoice-presentation :prompt "invoice"))
  (setf *current-object* inv))

(define-astrolabe-command (com-mark-paid :name t :menu t)
    ((inv 'invoice-presentation :prompt "invoice"))
  (let ((today (subseq (local-time:format-timestring nil (local-time:now)
                          :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                        0 10)))
    (setf (inv-status inv) "paid")
    (setf (inv-paid-date inv) today)
    (save-invoice inv)
    (format t "~&Invoice marked as paid.~%")))

(define-astrolabe-command (com-delete-invoice :name t :menu t)
    ((inv 'invoice-presentation :prompt "invoice"))
  (delete-invoice inv)
  (when (eq *current-object* inv) (setf *current-object* nil))
  (format t "~&Invoice deleted.~%"))

;; ── Ticket ───────────────────────────────────────────────────────────

(define-astrolabe-command (com-file-ticket :name t :menu t)
    ((title 'string :prompt "title"))
  (let* ((priority (accept 'string :prompt "priority (A/B/C)" :default "B"))
         (desc (accept 'string :prompt "description" :default ""))
         (tkt (make-instance 'ticket :title title :priority priority
                             :description desc)))
    (save-ticket tkt)
    (setf *current-object* tkt)
    (format t "~&Ticket '~A' filed.~%" title)))

(define-astrolabe-command (com-show-tickets :name t :menu t) ()
  (setf *current-view* :tickets)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-ticket :name t :menu t)
    ((tkt 'ticket-presentation :prompt "ticket"))
  (setf *current-object* tkt))

(define-astrolabe-command (com-resolve-ticket :name t :menu t)
    ((tkt 'ticket-presentation :prompt "ticket"))
  (let ((resolution (accept 'string :prompt "resolution" :default "")))
    (resolve-ticket tkt (if (> (length resolution) 0) resolution nil))
    (format t "~&Ticket resolved.~%")))

(define-astrolabe-command (com-delete-ticket :name t :menu t)
    ((tkt 'ticket-presentation :prompt "ticket"))
  (delete-ticket tkt)
  (when (eq *current-object* tkt) (setf *current-object* nil))
  (format t "~&Ticket deleted.~%"))

;; ── Repository ───────────────────────────────────────────────────────

(define-astrolabe-command (com-add-repository :name t :menu t)
    ((name 'string :prompt "name"))
  (let* ((path (accept 'string :prompt "local path" :default ""))
         (remote (accept 'string :prompt "remote URL (or empty)" :default ""))
         (branch (accept 'string :prompt "branch" :default "main"))
         (repo (make-instance 'repository :name name
                              :path (if (> (length path) 0) path nil)
                              :remote-url (if (> (length remote) 0) remote nil)
                              :branch branch)))
    (save-repository repo)
    (setf *current-object* repo)
    (format t "~&Repository '~A' added.~%" name)))

(define-astrolabe-command (com-show-repositories :name t :menu t) ()
  (setf *current-view* :repositories)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-repository :name t :menu t)
    ((repo 'repository-presentation :prompt "repository"))
  (setf *current-object* repo))

(define-astrolabe-command (com-repo-log :name t :menu t)
    ((repo 'repository-presentation :prompt "repository"))
  (let ((commits (repo-recent-commits repo 15)))
    (if commits
        (progn
          (setf *shell-command* (format nil "git log --oneline -15 (~A)" (repo-name repo)))
          (setf *shell-output* (format nil "~{~A~^~%~}" commits))
          (setf *shell-exit-code* 0)
          (setf *current-view* :shell)
          (setf *current-object* nil)
          (format t "~&~D commits.~%" (length commits)))
        (format t "~&Could not read git log (check path).~%"))))

(define-astrolabe-command (com-delete-repository :name t :menu t)
    ((repo 'repository-presentation :prompt "repository"))
  (delete-repository repo)
  (when (eq *current-object* repo) (setf *current-object* nil))
  (format t "~&Repository deleted.~%"))

;; ── Server ───────────────────────────────────────────────────────────

(define-astrolabe-command (com-add-server :name t :menu t)
    ((name 'string :prompt "name"))
  (let* ((hostname (accept 'string :prompt "hostname"))
         (port-str (accept 'string :prompt "SSH port" :default "22"))
         (user (accept 'string :prompt "username (or empty)" :default ""))
         (srv (make-instance 'server :name name :hostname hostname
                             :port (parse-integer port-str :junk-allowed t)
                             :username (if (> (length user) 0) user nil))))
    (save-server srv)
    (setf *current-object* srv)
    (format t "~&Server '~A' added.~%" name)))

(define-astrolabe-command (com-show-servers :name t :menu t) ()
  (setf *current-view* :servers)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-server :name t :menu t)
    ((srv 'server-presentation :prompt "server"))
  (setf *current-object* srv))

(define-astrolabe-command (com-ping-server :name t :menu t)
    ((srv 'server-presentation :prompt "server"))
  (format t "~&Pinging ~A...~%" (server-hostname srv))
  (if (ping-server srv)
      (format t "~&~A is ONLINE.~%" (server-name srv))
      (format t "~&~A is OFFLINE.~%" (server-name srv))))

(define-astrolabe-command (com-delete-server :name t :menu t)
    ((srv 'server-presentation :prompt "server"))
  (delete-server srv)
  (when (eq *current-object* srv) (setf *current-object* nil))
  (format t "~&Server deleted.~%"))

;; ── Habit ────────────────────────────────────────────────────────────

(define-astrolabe-command (com-add-habit :name t :menu t)
    ((name 'string :prompt "habit name"))
  (let* ((freq (accept 'string :prompt "frequency (daily/weekly/monthly)" :default "daily"))
         (hab (make-instance 'habit :name name :frequency freq)))
    (save-habit hab)
    (setf *current-object* hab)
    (format t "~&Habit '~A' created.~%" name)))

(define-astrolabe-command (com-show-habits :name t :menu t) ()
  (setf *current-view* :habits)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-habit :name t :menu t)
    ((hab 'habit-presentation :prompt "habit"))
  (setf *current-object* hab))

(define-astrolabe-command (com-log-habit :name t :menu t)
    ((hab 'habit-presentation :prompt "habit"))
  (let ((streak (log-habit hab)))
    (format t "~&Logged! Streak: ~D~A~%"
            streak
            (if (= streak (habit-best-streak hab)) " (personal best!)" ""))))

(define-astrolabe-command (com-delete-habit :name t :menu t)
    ((hab 'habit-presentation :prompt "habit"))
  (delete-habit hab)
  (when (eq *current-object* hab) (setf *current-object* nil))
  (format t "~&Habit deleted.~%"))

;; ── Bookmark ─────────────────────────────────────────────────────────

(define-astrolabe-command (com-add-bookmark :name t :menu t)
    ((title 'string :prompt "title"))
  (let* ((url (accept 'string :prompt "URL (or empty)" :default ""))
         (bm (make-instance 'bookmark :title title
                            :url (if (> (length url) 0) url nil))))
    (save-bookmark bm)
    (setf *current-object* bm)
    (format t "~&Bookmark '~A' saved.~%" title)))

(define-astrolabe-command (com-show-bookmarks :name t :menu t) ()
  (setf *current-view* :bookmarks)
  (setf *current-object* nil))

(define-astrolabe-command (com-show-bookmark :name t :menu t)
    ((bm 'bookmark-presentation :prompt "bookmark"))
  (setf *current-object* bm))

(define-astrolabe-command (com-delete-bookmark :name t :menu t)
    ((bm 'bookmark-presentation :prompt "bookmark"))
  (delete-bookmark bm)
  (when (eq *current-object* bm) (setf *current-object* nil))
  (format t "~&Bookmark deleted.~%"))

;;; ─────────────────────────────────────────────────────────────────────
;;; Reload user commands
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-reload-commands :name t :menu t) ()
  (if (load-user-commands)
      (format t "~&User commands reloaded.~%")
      (format t "~&No user commands file found at ~A~%" *user-commands-file*)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Quit
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-quit :name t :menu t) ()
  (frame-exit *application-frame*))

;;; ─────────────────────────────────────────────────────────────────────
;;; Keyboard accelerators
;;; ─────────────────────────────────────────────────────────────────────

(add-keystroke-to-command-table
 'astrolabe '(:n :control) :command '(com-capture-note)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:t :control) :command '(com-add-task)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:s :control) :command '(com-search)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:h :control) :command '(com-home)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:b :control) :command '(com-back)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:f :control) :command '(com-forward)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:a :control) :command '(com-agenda)
 :errorp nil)

(add-keystroke-to-command-table
 'astrolabe '(:g :control) :command '(com-go)
 :errorp nil)
