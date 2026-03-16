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
;;; Quit
;;; ─────────────────────────────────────────────────────────────────────

(define-astrolabe-command (com-quit :name t :menu t) ()
  (frame-exit *application-frame*))
