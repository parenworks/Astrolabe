;;;; presentations.lisp — CLIM presentation types and translators for Astrolabe

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Presentation types
;;; ─────────────────────────────────────────────────────────────────────

(define-presentation-type note-presentation ()
  :description "a note")

(define-presentation-type task-presentation ()
  :description "a task")

(define-presentation-type project-presentation ()
  :description "a project")

(define-presentation-type person-presentation ()
  :description "a person")

(define-presentation-type snippet-presentation ()
  :description "a snippet")

(define-presentation-type astrolabe-obj ()
  :description "any Astrolabe object")

;;; ─────────────────────────────────────────────────────────────────────
;;; Display helpers — present objects as clickable presentations
;;; ─────────────────────────────────────────────────────────────────────

(defun task-priority-ink (priority)
  "Return a CLIM ink for the given task priority."
  (cond
    ((string-equal priority "A") +red+)
    ((string-equal priority "B") +yellow+)
    (t +white+)))

(defun task-status-marker (status)
  "Return a marker string for the given task status."
  (cond
    ((string-equal status "todo")      "[ ]")
    ((string-equal status "active")    "[~]")
    ((string-equal status "done")      "[x]")
    ((string-equal status "cancelled") "[-]")
    (t                                 "[?]")))

(defun present-note (pane note)
  "Display a note as a clickable presentation in PANE."
  (with-output-as-presentation (pane note 'note-presentation)
    (with-drawing-options (pane :ink +cyan+)
      (format pane "  ~A  ~A~%" (note-title note) (or (obj-created-at note) "")))))

(defun present-task (pane task)
  "Display a task as a clickable presentation in PANE."
  (with-output-as-presentation (pane task 'task-presentation)
    (let ((marker (task-status-marker (task-status task)))
          (ink (task-priority-ink (task-priority task))))
      (with-drawing-options (pane :ink ink)
        (format pane "  ~A ~A~A~%"
                marker
                (task-title task)
                (if (task-due-date task)
                    (format nil "  [~A]" (task-due-date task))
                    ""))))))

(defun present-project (pane project)
  "Display a project as a clickable presentation in PANE."
  (with-output-as-presentation (pane project 'project-presentation)
    (with-drawing-options (pane :ink +green+)
      (format pane "  ~A  (~A)~%" (project-name project) (project-status project)))))

(defun present-person (pane person)
  "Display a person as a clickable presentation in PANE."
  (with-output-as-presentation (pane person 'person-presentation)
    (with-drawing-options (pane :ink +magenta+)
      (format pane "  ~A~A~%"
              (person-name person)
              (if (person-organization person)
                  (format nil "  (~A)" (person-organization person))
                  "")))))

(defun present-snippet (pane snippet)
  "Display a snippet as a clickable presentation in PANE."
  (with-output-as-presentation (pane snippet 'snippet-presentation)
    (with-drawing-options (pane :ink +white+)
      (format pane "  ~A  [~A]~%"
              (obj-display-title snippet)
              (snippet-content-type snippet)))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Presentation translators — click-to-navigate
;;; ─────────────────────────────────────────────────────────────────────

(define-presentation-to-command-translator click-note
    (note-presentation com-show-note astrolabe
     :gesture :select
     :documentation "Show this note")
    (object)
  (list object))

(define-presentation-to-command-translator click-task
    (task-presentation com-show-task astrolabe
     :gesture :select
     :documentation "Show this task")
    (object)
  (list object))

(define-presentation-to-command-translator click-project
    (project-presentation com-show-project astrolabe
     :gesture :select
     :documentation "Show this project")
    (object)
  (list object))

(define-presentation-to-command-translator click-person
    (person-presentation com-show-person astrolabe
     :gesture :select
     :documentation "Show this person")
    (object)
  (list object))

(define-presentation-to-command-translator click-snippet
    (snippet-presentation com-show-snippet astrolabe
     :gesture :select
     :documentation "Show this snippet")
    (object)
  (list object))
