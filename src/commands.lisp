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

;;; ─────────────────────────────────────────────────────────────────────
;;; Show commands — display objects in the detail pane
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-show-note :name t :menu t)
    ((note 'note-presentation :prompt "note"))
  (setf *current-object* note))

(define-astrolabe-command (com-show-task :name t :menu t)
    ((task 'task-presentation :prompt "task"))
  (setf *current-object* task))

(define-astrolabe-command (com-show-project :name t :menu t)
    ((project 'project-presentation :prompt "project"))
  (setf *current-view* :project)
  (setf *current-project* project)
  (setf *current-object* project))

(define-astrolabe-command (com-show-person :name t :menu t)
    ((person 'person-presentation :prompt "person"))
  (setf *current-object* person))

(define-astrolabe-command (com-show-snippet :name t :menu t)
    ((snippet 'snippet-presentation :prompt "snippet"))
  (setf *current-object* snippet))

(define-astrolabe-command (com-home :name t :menu t) ()
  (setf *current-view* :home)
  (setf *current-object* nil)
  (setf *current-project* nil))

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
  (delete-note note)
  (when (eq *current-object* note) (setf *current-object* nil))
  (format t "~&Deleted note: ~A~%" (note-title note)))

(define-astrolabe-command (com-delete-task :name t :menu t)
    ((task 'task-presentation :prompt "task"))
  (delete-task task)
  (when (eq *current-object* task) (setf *current-object* nil))
  (format t "~&Deleted task: ~A~%" (task-title task)))

(define-astrolabe-command (com-delete-project :name t :menu t)
    ((project 'project-presentation :prompt "project"))
  (delete-project project)
  (when (eq *current-object* project)
    (setf *current-object* nil)
    (setf *current-view* :home)
    (setf *current-project* nil))
  (format t "~&Deleted project: ~A~%" (project-name project)))

(define-astrolabe-command (com-delete-person :name t :menu t)
    ((person 'person-presentation :prompt "person"))
  (delete-person person)
  (when (eq *current-object* person) (setf *current-object* nil))
  (format t "~&Deleted person: ~A~%" (person-name person)))

(define-astrolabe-command (com-delete-snippet :name t :menu t)
    ((snippet 'snippet-presentation :prompt "snippet"))
  (delete-snippet snippet)
  (when (eq *current-object* snippet) (setf *current-object* nil))
  (format t "~&Deleted snippet: ~A~%" (obj-display-title snippet)))

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
