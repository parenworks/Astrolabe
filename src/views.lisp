;;;; views.lisp — Pane display functions for Astrolabe

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Navigation pane — left side, shows lists of objects
;;; ─────────────────────────────────────────────────────────────────────

(defun display-navigation (frame pane)
  "Display function for the navigation pane."
  (declare (ignore frame))
  (case *current-view*
    (:home    (display-home-nav pane))
    (:project (display-project-nav pane))
    (t        (display-home-nav pane))))

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
          (format pane "    (no notes yet)~%")))))

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
    (format pane "  Commands:~%")
    (format pane "    Capture Note [title]   — create a note~%")
    (format pane "    Add Task [title]       — create a task~%")
    (format pane "    New Project [name]     — create a project~%")
    (format pane "    Complete Task [task]   — mark task done~%")
    (format pane "    Home                   — return to home~%")
    (format pane "    Quit                   — exit Astrolabe~%")
    (terpri pane)
    (format pane "  Click any item to see its details.~%")
    (format pane "  Tab cycles focus between panes.~%")))

(defgeneric display-object-detail (pane object)
  (:documentation "Display the detail view for an object."))

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
  (let ((body (note-body note)))
    (when (and body (> (length body) 0))
      (with-drawing-options (pane :ink +white+)
        (format pane "  ~A~%" body))))
  ;; Show linked objects
  (display-links pane note))

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
    (when (obj-created-at task)
      (format pane "  Created:  ~A~%" (obj-created-at task))))
  (terpri pane)
  (display-links pane task))

(defmethod display-object-detail (pane (project project))
  (terpri pane)
  (with-drawing-options (pane :ink +green+)
    (with-text-face (pane :bold)
      (format pane "  ~A~%" (project-name project))))
  (with-drawing-options (pane :ink +white+)
    (format pane "  Status: ~A~%" (project-status project))
    (when (obj-created-at project)
      (format pane "  Created: ~A~%" (obj-created-at project)))
    (terpri pane)
    (let ((desc (project-description project)))
      (when (and desc (> (length desc) 0))
        (format pane "  ~A~%" desc)
        (terpri pane))))
  ;; Show task count
  (let ((tasks (load-project-tasks (obj-id project))))
    (let ((total (length tasks))
          (done (count-if (lambda (tk) (string-equal (task-status tk) "done")) tasks)))
      (with-drawing-options (pane :ink +yellow+)
        (format pane "  Tasks: ~D/~D complete~%" done total))))
  (terpri pane)
  (display-links pane project))

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
            (cond
              ((typep obj 'note)    (present-note pane obj))
              ((typep obj 'task)    (present-task pane obj))
              ((typep obj 'project) (present-project pane obj)))))))))
