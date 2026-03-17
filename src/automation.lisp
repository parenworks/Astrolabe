;;;; automation.lisp — Phase 4: Automation and scripting infrastructure
;;;; Hooks, templates, shell integration, scheduled actions, batch ops, user commands.

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Hook system — before/after hooks on object CRUD
;;; ─────────────────────────────────────────────────────────────────────

(defvar *hooks* (make-hash-table :test 'equal)
  "Hash table mapping hook-name (string) to list of hook functions.
   Hook names follow the pattern: before-save-note, after-save-note,
   before-delete-task, after-create-project, etc.")

(defun register-hook (hook-name fn)
  "Register FN to be called when HOOK-NAME fires.
   HOOK-NAME is a string like \"after-save-note\".
   FN receives the object as its single argument."
  (push fn (gethash hook-name *hooks* nil))
  hook-name)

(defun unregister-hook (hook-name fn)
  "Remove FN from HOOK-NAME's hook list."
  (setf (gethash hook-name *hooks*)
        (remove fn (gethash hook-name *hooks* nil)))
  hook-name)

(defun run-hooks (hook-name object)
  "Run all hooks registered under HOOK-NAME, passing OBJECT to each."
  (dolist (fn (gethash hook-name *hooks* nil))
    (handler-case (funcall fn object)
      (error (e)
        (format *error-output* "~&Hook ~A error: ~A~%" hook-name e)))))

(defun clear-hooks (&optional hook-name)
  "Clear all hooks, or just those for HOOK-NAME."
  (if hook-name
      (remhash hook-name *hooks*)
      (clrhash *hooks*)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Templates — note/task templates from ~/.astrolabe/templates/
;;; ─────────────────────────────────────────────────────────────────────

(defvar *templates-dir*
  (merge-pathnames "templates/" *data-dir*)
  "Directory for user-defined templates.")

(defun ensure-templates-dir ()
  "Create the templates directory if it does not exist."
  (ensure-directories-exist *templates-dir*))

(defun list-templates ()
  "List available template names (file basenames without extension)."
  (let ((files (directory (merge-pathnames "*.txt" *templates-dir*))))
    (mapcar (lambda (p) (pathname-name p)) files)))

(defun load-template (name)
  "Load a template file by NAME. Returns the template string, or nil."
  (let ((path (merge-pathnames (format nil "~A.txt" name) *templates-dir*)))
    (when (probe-file path)
      (with-open-file (s path :direction :input)
        (let ((content (make-string (file-length s))))
          (read-sequence content s)
          content)))))

(defun expand-template (template-text &optional vars)
  "Expand {{key}} placeholders in TEMPLATE-TEXT using VARS plist.
   Also expands {{date}} and {{time}} automatically."
  (let* ((now (local-time:now))
         (date-str (subseq (local-time:format-timestring nil now
                             :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                           0 10))
         (time-str (subseq (local-time:format-timestring nil now
                             :format '((:hour 2) #\: (:min 2)))
                           0 5))
         (result template-text))
    ;; Built-in variables
    (setf result (cl-ppcre:regex-replace-all "\\{\\{date\\}\\}" result date-str))
    (setf result (cl-ppcre:regex-replace-all "\\{\\{time\\}\\}" result time-str))
    ;; User-supplied variables
    (loop for (key val) on vars by #'cddr
          do (let ((pattern (format nil "\\{\\{~A\\}\\}" (string-downcase (string key)))))
               (setf result (cl-ppcre:regex-replace-all pattern result (or val "")))))
    result))

;;; ─────────────────────────────────────────────────────────────────────
;;; Shell integration — run commands and capture output
;;; ─────────────────────────────────────────────────────────────────────

(defvar *shell-output* nil
  "Last shell command output, displayed in the detail pane.")

(defvar *shell-command* nil
  "Last shell command string that was executed.")

(defvar *shell-exit-code* nil
  "Exit code of the last shell command.")

(defun run-shell-command (command)
  "Run COMMAND via /bin/sh and capture stdout+stderr. Returns (values output exit-code)."
  (multiple-value-bind (output error-output exit-code)
      (uiop:run-program (list "/bin/sh" "-c" command)
                         :output :string
                         :error-output :string
                         :ignore-error-status t)
    (let ((full-output (if (and error-output (> (length error-output) 0))
                           (concatenate 'string output error-output)
                           output)))
      (values full-output exit-code))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Export — object serialization to markdown and reports
;;; ─────────────────────────────────────────────────────────────────────

(defgeneric export-object-markdown (object)
  (:documentation "Export an object as a Markdown string."))

(defmethod export-object-markdown ((note note))
  (format nil "# ~A~%~%~A~%~%---~%Created: ~A~%Updated: ~A~%"
          (note-title note) (or (note-body note) "")
          (or (obj-created-at note) "") (or (obj-updated-at note) "")))

(defmethod export-object-markdown ((task task))
  (format nil "# ~A ~A~%~%- **Status:** ~A~%- **Priority:** ~A~%~A~A~A~%~A~%"
          (task-status-marker (task-status task)) (task-title task)
          (task-status task) (task-priority task)
          (if (task-due-date task) (format nil "- **Due:** ~A~%" (task-due-date task)) "")
          (if (task-context task) (format nil "- **Context:** ~A~%" (task-context task)) "")
          (if (task-description task) (format nil "~%~A~%" (task-description task)) "")
          (if (task-notes task) (format nil "~%### Notes~%~%~A~%" (task-notes task)) "")))

(defmethod export-object-markdown ((project project))
  (let ((tasks (load-project-tasks (obj-id project)))
        (linked (load-linked-objects project)))
    (format nil "# ~A~%~%**Status:** ~A | **Priority:** ~A~A~%~A~%~A## Tasks~%~%~{~A~}~%~A"
            (project-name project)
            (project-status project) (project-priority project)
            (if (project-area project) (format nil " | **Area:** ~A" (project-area project)) "")
            (if (project-description project)
                (format nil "~%~A~%~%" (project-description project)) "")
            (if (project-notes project)
                (format nil "### Notes~%~%~A~%~%" (project-notes project)) "")
            (mapcar (lambda (tk)
                      (format nil "- [~A] ~A~A~%"
                              (if (string-equal (task-status tk) "done") "x" " ")
                              (task-title tk)
                              (if (task-due-date tk)
                                  (format nil " (due ~A)" (task-due-date tk)) "")))
                    tasks)
            (if linked
                (format nil "~%## Links~%~%~{- ~A~%~}"
                        (mapcar (lambda (l) (format nil "~A #~A (~A)"
                                                    (first l) (second l) (or (third l) "")))
                                linked))
                ""))))

(defmethod export-object-markdown ((person person))
  (format nil "# ~A~%~%~A~A~A~A~A~A"
          (person-name person)
          (if (person-email person) (format nil "- **Email:** ~A~%" (person-email person)) "")
          (if (person-phone person) (format nil "- **Phone:** ~A~%" (person-phone person)) "")
          (if (person-organization person) (format nil "- **Org:** ~A~%" (person-organization person)) "")
          (if (person-job-title person) (format nil "- **Title:** ~A~%" (person-job-title person)) "")
          (if (person-website person) (format nil "- **Website:** ~A~%" (person-website person)) "")
          (if (person-notes person) (format nil "~%### Notes~%~%~A~%" (person-notes person)) "")))

(defmethod export-object-markdown ((snippet snippet))
  (format nil "# Snippet~%~%**Type:** ~A~A~A~%~%```~%~A~%```~%"
          (snippet-content-type snippet)
          (if (snippet-language snippet) (format nil " | **Language:** ~A" (snippet-language snippet)) "")
          (if (snippet-source snippet) (format nil " | **Source:** ~A" (snippet-source snippet)) "")
          (snippet-content snippet)))

(defun export-project-report (project)
  "Generate a project status report as Markdown."
  (let* ((tasks (load-project-tasks (obj-id project)))
         (total (length tasks))
         (done (count-if (lambda (tk) (string-equal (task-status tk) "done")) tasks))
         (open (remove-if (lambda (tk) (string-equal (task-status tk) "done")) tasks))
         (pct (if (> total 0) (round (* 100 (/ done total))) 0)))
    (format nil "# Project Report: ~A~%~%**Date:** ~A~%**Status:** ~A~%**Progress:** ~D/~D (~D%)~%~A~%## Open Tasks~%~%~{~A~}~%## Completed~%~%~{~A~}~%"
            (project-name project)
            (subseq (local-time:format-timestring nil (local-time:now)
                      :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                    0 10)
            (project-status project) done total pct
            (if (project-description project)
                (format nil "~%~A~%~%" (project-description project)) "")
            (mapcar (lambda (tk)
                      (format nil "- [~A] **~A** ~A~A~%"
                              (task-priority tk) (task-title tk)
                              (task-status tk)
                              (if (task-due-date tk)
                                  (format nil " — due ~A" (task-due-date tk)) "")))
                    open)
            (mapcar (lambda (tk)
                      (format nil "- ~~[x]~~ ~A~A~%"
                              (task-title tk)
                              (if (task-completed-at tk)
                                  (format nil " — ~A" (task-completed-at tk)) "")))
                    (remove-if-not (lambda (tk) (string-equal (task-status tk) "done")) tasks)))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Scheduled actions — check for overdue/reminder tasks
;;; ─────────────────────────────────────────────────────────────────────

(defvar *last-reminder-check* nil
  "Timestamp of the last reminder check.")

(defun check-reminders ()
  "Check for overdue tasks and scheduled tasks due today.
   Creates notifications for any found. Should be called periodically."
  (let* ((today-str (subseq (local-time:format-timestring nil (local-time:now)
                              :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                            0 10))
         (overdue (mapcar #'make-task-from-row
                          (db-query (format nil "SELECT ~A FROM tasks
                                     WHERE deleted_at IS NULL
                                       AND status IN ('todo','active','waiting')
                                       AND due_date < ?
                                     ORDER BY due_date ASC LIMIT 20" *task-cols*)
                                    today-str)))
         (due-today (mapcar #'make-task-from-row
                            (db-query (format nil "SELECT ~A FROM tasks
                                       WHERE deleted_at IS NULL
                                         AND status IN ('todo','active','waiting')
                                         AND due_date = ?
                                       ORDER BY priority ASC" *task-cols*)
                                      today-str)))
         (scheduled (mapcar #'make-task-from-row
                            (db-query (format nil "SELECT ~A FROM tasks
                                       WHERE deleted_at IS NULL
                                         AND status IN ('todo','active','waiting')
                                         AND scheduled_date = ?
                                       ORDER BY priority ASC" *task-cols*)
                                      today-str)))
         (count 0))
    ;; Create notifications for overdue tasks (only if we haven't already today)
    (when (or (null *last-reminder-check*)
              (not (string= *last-reminder-check* today-str)))
      (dolist (task overdue)
        (create-notification "reminder"
                             (format nil "OVERDUE: ~A (due ~A)" (task-title task) (task-due-date task))
                             :object-type "task" :object-id (obj-id task))
        (incf count))
      (dolist (task due-today)
        (create-notification "reminder"
                             (format nil "Due today: ~A" (task-title task))
                             :object-type "task" :object-id (obj-id task))
        (incf count))
      (dolist (task scheduled)
        (create-notification "reminder"
                             (format nil "Scheduled today: ~A" (task-title task))
                             :object-type "task" :object-id (obj-id task))
        (incf count))
      (setf *last-reminder-check* today-str))
    count))

;;; ─────────────────────────────────────────────────────────────────────
;;; Batch operations — apply actions to multiple objects
;;; ─────────────────────────────────────────────────────────────────────

(defvar *batch-selection* nil
  "List of objects currently selected for batch operations.")

(defun batch-select (object)
  "Add OBJECT to the batch selection."
  (pushnew object *batch-selection* :test #'eq)
  (length *batch-selection*))

(defun batch-deselect (object)
  "Remove OBJECT from the batch selection."
  (setf *batch-selection* (remove object *batch-selection* :test #'eq))
  (length *batch-selection*))

(defun batch-clear ()
  "Clear the batch selection."
  (setf *batch-selection* nil))

(defun batch-apply-tag (tag-name)
  "Tag all objects in the batch selection."
  (dolist (obj *batch-selection*)
    (tag-object obj tag-name))
  (length *batch-selection*))

(defun batch-complete-tasks ()
  "Complete all tasks in the batch selection."
  (let ((count 0))
    (dolist (obj *batch-selection*)
      (when (typep obj 'task)
        (complete-task obj)
        (incf count)))
    count))

(defun batch-delete ()
  "Soft-delete all objects in the batch selection. Returns count deleted."
  (let ((count 0))
    (dolist (obj *batch-selection*)
      (cond
        ((typep obj 'note)    (delete-note obj)    (incf count))
        ((typep obj 'task)    (delete-task obj)    (incf count))
        ((typep obj 'project) (delete-project obj) (incf count))
        ((typep obj 'person)  (delete-person obj)  (incf count))
        ((typep obj 'snippet) (delete-snippet obj) (incf count))))
    (setf *batch-selection* nil)
    count))

;;; ─────────────────────────────────────────────────────────────────────
;;; User commands — load from ~/.astrolabe/commands.lisp
;;; ─────────────────────────────────────────────────────────────────────

(defvar *user-commands-file*
  (merge-pathnames "commands.lisp" *data-dir*)
  "Path to user-defined commands file.")

(defun load-user-commands ()
  "Load user-defined commands from ~/.astrolabe/commands.lisp if it exists."
  (let ((path *user-commands-file*))
    (when (probe-file path)
      (handler-case
          (progn
            (load path)
            (format *error-output* "~&Loaded user commands from ~A~%" path)
            t)
        (error (e)
          (format *error-output* "~&Error loading user commands: ~A~%" e)
          nil)))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Initialization — call from main entry point
;;; ─────────────────────────────────────────────────────────────────────

(defun init-automation ()
  "Initialize the automation subsystem: load user commands, templates, check reminders, LLM."
  (ensure-templates-dir)
  (load-user-commands)
  (check-reminders)
  (check-llm-availability))
