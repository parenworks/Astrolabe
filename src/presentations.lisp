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

(define-presentation-type journal-presentation ()
  :description "a journal entry")

(define-presentation-type document-presentation ()
  :description "a document")

(define-presentation-type event-presentation ()
  :description "an event")

(define-presentation-type invoice-presentation ()
  :description "an invoice")

(define-presentation-type ticket-presentation ()
  :description "a ticket")

(define-presentation-type repository-presentation ()
  :description "a repository")

(define-presentation-type server-presentation ()
  :description "a server")

(define-presentation-type habit-presentation ()
  :description "a habit")

(define-presentation-type bookmark-presentation ()
  :description "a bookmark")

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

(defun present-journal-entry (pane je)
  "Display a journal entry as a clickable presentation in PANE."
  (with-output-as-presentation (pane je 'journal-presentation)
    (with-drawing-options (pane :ink +cyan+)
      (format pane "  ~A~A~%"
              (or (je-entry-date je) "")
              (if (and (je-title je) (> (length (je-title je)) 0))
                  (format nil " — ~A" (je-title je)) "")))))

(defun present-document (pane doc)
  "Display a document as a clickable presentation in PANE."
  (with-output-as-presentation (pane doc 'document-presentation)
    (with-drawing-options (pane :ink +white+)
      (format pane "  ~A~A~%"
              (doc-title doc)
              (if (doc-file-type doc) (format nil "  [~A]" (doc-file-type doc)) "")))))

(defun present-event (pane evt)
  "Display an event as a clickable presentation in PANE."
  (with-output-as-presentation (pane evt 'event-presentation)
    (let ((ink (cond ((string-equal (event-status evt) "cancelled") +red+)
                     ((string-equal (event-status evt) "completed") +white+)
                     (t +cyan+))))
      (with-drawing-options (pane :ink ink)
        (format pane "  ~A  ~A~A~%"
                (or (event-start-time evt) "")
                (event-title evt)
                (if (event-location evt) (format nil "  @ ~A" (event-location evt)) ""))))))

(defun present-invoice (pane inv)
  "Display an invoice as a clickable presentation in PANE."
  (with-output-as-presentation (pane inv 'invoice-presentation)
    (let ((ink (cond ((string-equal (inv-status inv) "overdue") +red+)
                     ((string-equal (inv-status inv) "paid") +green+)
                     ((string-equal (inv-status inv) "sent") +yellow+)
                     (t +white+))))
      (with-drawing-options (pane :ink ink)
        (format pane "  [~A] ~A~%"
                (inv-status inv) (obj-display-title inv))))))

(defun ticket-status-marker (status)
  "Return a marker for ticket status."
  (cond
    ((string-equal status "open")        "OPEN")
    ((string-equal status "in_progress") "WIP ")
    ((string-equal status "resolved")    "DONE")
    ((string-equal status "closed")      "CLSD")
    (t                                   status)))

(defun present-ticket (pane tkt)
  "Display a ticket as a clickable presentation in PANE."
  (with-output-as-presentation (pane tkt 'ticket-presentation)
    (with-drawing-options (pane :ink (task-priority-ink (ticket-priority tkt)))
      (format pane "  [~A] ~A  ~A~%"
              (ticket-status-marker (ticket-status tkt))
              (ticket-priority tkt)
              (ticket-title tkt)))))

(defun present-repository (pane repo)
  "Display a repository as a clickable presentation in PANE."
  (with-output-as-presentation (pane repo 'repository-presentation)
    (with-drawing-options (pane :ink +cyan+)
      (format pane "  ~A  (~A)~%"
              (repo-name repo)
              (or (repo-branch repo) "main")))))

(defun present-server (pane srv)
  "Display a server as a clickable presentation in PANE."
  (with-output-as-presentation (pane srv 'server-presentation)
    (let ((ink (cond ((string-equal (server-status srv) "online") +green+)
                     ((string-equal (server-status srv) "offline") +red+)
                     (t +white+))))
      (with-drawing-options (pane :ink ink)
        (format pane "  ~A  ~A  [~A]~%"
                (server-name srv) (server-hostname srv)
                (server-status srv))))))

(defun present-habit (pane hab)
  "Display a habit as a clickable presentation in PANE."
  (with-output-as-presentation (pane hab 'habit-presentation)
    (with-drawing-options (pane :ink (if (> (habit-streak hab) 0) +green+ +white+))
      (format pane "  ~A  ~A  streak:~D~%"
              (habit-name hab)
              (habit-frequency hab)
              (habit-streak hab)))))

(defun present-bookmark (pane bm)
  "Display a bookmark as a clickable presentation in PANE."
  (with-output-as-presentation (pane bm 'bookmark-presentation)
    (with-drawing-options (pane :ink +cyan+)
      (format pane "  ~A~A~%"
              (bm-title bm)
              (if (bm-url bm) (format nil "  ~A" (bm-url bm)) "")))))

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

(define-presentation-to-command-translator click-journal
    (journal-presentation com-show-journal-entry astrolabe
     :gesture :select
     :documentation "Show this journal entry")
    (object)
  (list object))

(define-presentation-to-command-translator click-document
    (document-presentation com-show-document astrolabe
     :gesture :select
     :documentation "Show this document")
    (object)
  (list object))

(define-presentation-to-command-translator click-event
    (event-presentation com-show-event astrolabe
     :gesture :select
     :documentation "Show this event")
    (object)
  (list object))

(define-presentation-to-command-translator click-invoice
    (invoice-presentation com-show-invoice astrolabe
     :gesture :select
     :documentation "Show this invoice")
    (object)
  (list object))

(define-presentation-to-command-translator click-ticket
    (ticket-presentation com-show-ticket astrolabe
     :gesture :select
     :documentation "Show this ticket")
    (object)
  (list object))

(define-presentation-to-command-translator click-repository
    (repository-presentation com-show-repository astrolabe
     :gesture :select
     :documentation "Show this repository")
    (object)
  (list object))

(define-presentation-to-command-translator click-server
    (server-presentation com-show-server astrolabe
     :gesture :select
     :documentation "Show this server")
    (object)
  (list object))

(define-presentation-to-command-translator click-habit
    (habit-presentation com-show-habit astrolabe
     :gesture :select
     :documentation "Show this habit")
    (object)
  (list object))

(define-presentation-to-command-translator click-bookmark
    (bookmark-presentation com-show-bookmark astrolabe
     :gesture :select
     :documentation "Show this bookmark")
    (object)
  (list object))
