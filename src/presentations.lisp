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

(define-presentation-type conversation-presentation ()
  :description "a conversation")

(define-presentation-type feed-presentation ()
  :description "a feed")

(define-presentation-type feed-item-presentation ()
  :description "a feed item")

(define-presentation-type notification-presentation ()
  :description "a notification")

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

(defun present-conversation (pane conv)
  "Display a conversation as a clickable presentation in PANE."
  (with-output-as-presentation (pane conv 'conversation-presentation)
    (let ((unread (conv-unread-count conv)))
      (with-drawing-options (pane :ink (if (> unread 0) +yellow+ +white+))
        (format pane "  ~A~A  (~A)~%"
                (if (string-equal (conv-type conv) "muc") "#" "")
                (obj-display-title conv)
                (if (> unread 0)
                    (format nil "~D unread" unread)
                    (conv-type conv)))))))

(defun present-feed (pane feed)
  "Display a feed subscription as a clickable presentation in PANE."
  (with-output-as-presentation (pane feed 'feed-presentation)
    (let ((unread (feed-unread-count feed)))
      (with-drawing-options (pane :ink (if (> unread 0) +yellow+ +white+))
        (format pane "  ~A~A~%"
                (obj-display-title feed)
                (if (> unread 0)
                    (format nil "  (~D)" unread)
                    ""))))))

(defun present-feed-item (pane fi)
  "Display a feed item as a clickable presentation in PANE."
  (with-output-as-presentation (pane fi 'feed-item-presentation)
    (with-drawing-options (pane :ink (if (= (fi-read fi) 0) +cyan+ +white+))
      (format pane "  ~A~A~%"
              (obj-display-title fi)
              (if (fi-author fi)
                  (format nil "  — ~A" (fi-author fi))
                  "")))))

(defun present-notification (pane notif)
  "Display a notification as a clickable presentation in PANE."
  (with-output-as-presentation (pane notif 'notification-presentation)
    (with-drawing-options (pane :ink (if (= (notif-read notif) 0) +yellow+ +white+))
      (format pane "  [~A] ~A~%"
              (notif-type notif)
              (notif-title notif)))))

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

(define-presentation-to-command-translator click-conversation
    (conversation-presentation com-show-conversation astrolabe
     :gesture :select
     :documentation "Show this conversation")
    (object)
  (list object))

(define-presentation-to-command-translator click-feed
    (feed-presentation com-show-feed astrolabe
     :gesture :select
     :documentation "Show this feed")
    (object)
  (list object))

(define-presentation-to-command-translator click-feed-item
    (feed-item-presentation com-show-feed-item astrolabe
     :gesture :select
     :documentation "Show this article")
    (object)
  (list object))

(define-presentation-to-command-translator click-notification
    (notification-presentation com-dismiss-notification astrolabe
     :gesture :select
     :documentation "Dismiss this notification")
    (object)
  (list object))
