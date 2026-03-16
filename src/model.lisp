;;;; model.lisp — Object model for Astrolabe
;;;; CLOS classes mirroring the database schema, with load/save/delete operations.

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Base class
;;; ─────────────────────────────────────────────────────────────────────

(defclass astrolabe-object ()
  ((id         :initarg :id         :accessor obj-id         :initform nil)
   (created-at :initarg :created-at :accessor obj-created-at :initform nil)
   (updated-at :initarg :updated-at :accessor obj-updated-at :initform nil)
   (deleted-at :initarg :deleted-at :accessor obj-deleted-at :initform nil))
  (:documentation "Base class for all Astrolabe persistent objects."))

(defgeneric obj-type-name (object)
  (:documentation "Return the string type name for this object (e.g. \"note\", \"task\")."))

(defgeneric obj-display-title (object)
  (:documentation "Return a short display title for this object."))

;;; ─────────────────────────────────────────────────────────────────────
;;; Note
;;; ─────────────────────────────────────────────────────────────────────

(defclass note (astrolabe-object)
  ((title    :initarg :title    :accessor note-title    :initform "")
   (body     :initarg :body     :accessor note-body     :initform "")
   (format   :initarg :format   :accessor note-format   :initform "markdown")
   (pinned   :initarg :pinned   :accessor note-pinned   :initform 0)
   (archived :initarg :archived :accessor note-archived :initform 0)))

(defmethod obj-type-name ((obj note)) "note")
(defmethod obj-display-title ((obj note)) (note-title obj))

(defparameter *note-cols*
  "id, title, body, format, pinned, archived, created_at, updated_at, deleted_at")

(defun make-note-from-row (row)
  (make-instance 'note :id (nth 0 row) :title (nth 1 row) :body (nth 2 row)
                 :format (nth 3 row) :pinned (nth 4 row) :archived (nth 5 row)
                 :created-at (nth 6 row) :updated-at (nth 7 row) :deleted-at (nth 8 row)))

(defun save-note (note)
  (if (obj-id note)
      (progn
        (db-execute "UPDATE notes SET title=?, body=?, format=?, pinned=?, archived=?,
                     updated_at=datetime('now') WHERE id=?"
                    (note-title note) (note-body note) (note-format note)
                    (note-pinned note) (note-archived note) (obj-id note))
        note)
      (progn
        (db-execute "INSERT INTO notes (title, body, format, pinned, archived) VALUES (?,?,?,?,?)"
                    (note-title note) (note-body note) (note-format note)
                    (note-pinned note) (note-archived note))
        (setf (obj-id note) (db-last-insert-id))
        (db-execute "INSERT INTO notes_fts (rowid, title, body) VALUES (?, ?, ?)"
                    (obj-id note) (note-title note) (note-body note))
        note)))

(defun load-note (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM notes WHERE id=? AND deleted_at IS NULL" *note-cols*) id)))
    (when row (make-note-from-row row))))

(defun load-recent-notes (&optional (limit 20))
  (mapcar #'make-note-from-row
          (db-query (format nil "SELECT ~A FROM notes WHERE deleted_at IS NULL AND archived=0
                     ORDER BY pinned DESC, updated_at DESC LIMIT ?" *note-cols*) limit)))

(defun delete-note (note)
  (when (obj-id note)
    (db-execute "UPDATE notes SET deleted_at=datetime('now') WHERE id=?" (obj-id note))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Task
;;; ─────────────────────────────────────────────────────────────────────

(defclass task (astrolabe-object)
  ((title          :initarg :title          :accessor task-title          :initform "")
   (description    :initarg :description    :accessor task-description    :initform "")
   (status         :initarg :status         :accessor task-status         :initform "todo")
   (priority       :initarg :priority       :accessor task-priority       :initform "B")
   (due-date       :initarg :due-date       :accessor task-due-date       :initform nil)
   (scheduled-date :initarg :scheduled-date :accessor task-scheduled-date :initform nil)
   (completed-at   :initarg :completed-at   :accessor task-completed-at   :initform nil)
   (parent-id      :initarg :parent-id      :accessor task-parent-id      :initform nil)
   (sort-order     :initarg :sort-order     :accessor task-sort-order     :initform 0)
   (effort-minutes :initarg :effort-minutes :accessor task-effort-minutes :initform nil)
   (actual-minutes :initarg :actual-minutes :accessor task-actual-minutes :initform nil)
   (recurrence     :initarg :recurrence     :accessor task-recurrence     :initform nil)
   (recur-after    :initarg :recur-after    :accessor task-recur-after    :initform nil)
   (assigned-to    :initarg :assigned-to    :accessor task-assigned-to    :initform nil)
   (context        :initarg :context        :accessor task-context        :initform nil)
   (notes          :initarg :notes          :accessor task-notes          :initform "")))

(defmethod obj-type-name ((obj task)) "task")
(defmethod obj-display-title ((obj task)) (task-title obj))

(defparameter *task-cols*
  "id, title, description, status, priority, due_date, scheduled_date,
   completed_at, parent_id, sort_order, effort_minutes, actual_minutes,
   recurrence, recur_after, assigned_to, context, notes,
   created_at, updated_at, deleted_at")

(defun make-task-from-row (row)
  (make-instance 'task
                 :id             (nth 0 row)  :title          (nth 1 row)
                 :description    (nth 2 row)  :status         (nth 3 row)
                 :priority       (nth 4 row)  :due-date       (nth 5 row)
                 :scheduled-date (nth 6 row)  :completed-at   (nth 7 row)
                 :parent-id      (nth 8 row)  :sort-order     (nth 9 row)
                 :effort-minutes (nth 10 row) :actual-minutes (nth 11 row)
                 :recurrence     (nth 12 row) :recur-after    (nth 13 row)
                 :assigned-to    (nth 14 row) :context        (nth 15 row)
                 :notes          (nth 16 row) :created-at     (nth 17 row)
                 :updated-at     (nth 18 row) :deleted-at     (nth 19 row)))

(defun save-task (task)
  (if (obj-id task)
      (progn
        (db-execute "UPDATE tasks SET title=?, description=?, status=?, priority=?,
                     due_date=?, scheduled_date=?, completed_at=?, parent_id=?,
                     sort_order=?, effort_minutes=?, actual_minutes=?,
                     recurrence=?, recur_after=?, assigned_to=?, context=?, notes=?,
                     updated_at=datetime('now') WHERE id=?"
                    (task-title task) (task-description task) (task-status task)
                    (task-priority task) (task-due-date task) (task-scheduled-date task)
                    (task-completed-at task) (task-parent-id task) (task-sort-order task)
                    (task-effort-minutes task) (task-actual-minutes task)
                    (task-recurrence task) (task-recur-after task)
                    (task-assigned-to task) (task-context task) (task-notes task)
                    (obj-id task))
        task)
      (progn
        (db-execute "INSERT INTO tasks (title, description, status, priority, due_date,
                     scheduled_date, parent_id, sort_order, effort_minutes,
                     recurrence, assigned_to, context, notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)"
                    (task-title task) (task-description task) (task-status task)
                    (task-priority task) (task-due-date task) (task-scheduled-date task)
                    (task-parent-id task) (task-sort-order task) (task-effort-minutes task)
                    (task-recurrence task) (task-assigned-to task) (task-context task)
                    (task-notes task))
        (setf (obj-id task) (db-last-insert-id))
        (db-execute "INSERT INTO tasks_fts (rowid, title, description, notes) VALUES (?,?,?,?)"
                    (obj-id task) (task-title task) (task-description task) (task-notes task))
        task)))

(defun load-task (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM tasks WHERE id=? AND deleted_at IS NULL" *task-cols*) id)))
    (when row (make-task-from-row row))))

(defun load-open-tasks (&optional (limit 50))
  "Load open tasks (todo, active, waiting), ordered by priority then due date."
  (mapcar #'make-task-from-row
          (db-query (format nil "SELECT ~A FROM tasks
                     WHERE deleted_at IS NULL AND status IN ('todo','active','waiting')
                     ORDER BY priority ASC, due_date ASC NULLS LAST, created_at DESC
                     LIMIT ?" *task-cols*) limit)))

(defun load-project-tasks (project-id &optional (limit 50))
  "Load tasks linked to a project."
  (mapcar #'make-task-from-row
          (db-query (format nil "SELECT ~{t.~A~^, ~} FROM tasks t
                     JOIN links l ON l.target_type='task' AND l.target_id=t.id
                     WHERE l.source_type='project' AND l.source_id=?
                       AND t.deleted_at IS NULL
                     ORDER BY t.sort_order ASC, t.priority ASC, t.due_date ASC NULLS LAST
                     LIMIT ?"
                            '("id" "title" "description" "status" "priority" "due_date"
                              "scheduled_date" "completed_at" "parent_id" "sort_order"
                              "effort_minutes" "actual_minutes" "recurrence" "recur_after"
                              "assigned_to" "context" "notes"
                              "created_at" "updated_at" "deleted_at"))
                    project-id limit)))

(defun load-subtasks (parent-id &optional (limit 50))
  "Load subtasks of a given task."
  (mapcar #'make-task-from-row
          (db-query (format nil "SELECT ~A FROM tasks
                     WHERE parent_id=? AND deleted_at IS NULL
                     ORDER BY sort_order ASC, priority ASC LIMIT ?" *task-cols*)
                    parent-id limit)))

(defun complete-task (task)
  "Mark a task as done and record completion time."
  (setf (task-status task) "done")
  (setf (task-completed-at task) "now")
  (db-execute "UPDATE tasks SET status='done', completed_at=datetime('now'),
               updated_at=datetime('now') WHERE id=?" (obj-id task))
  task)

(defun delete-task (task)
  (when (obj-id task)
    (db-execute "UPDATE tasks SET deleted_at=datetime('now') WHERE id=?" (obj-id task))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Project
;;; ─────────────────────────────────────────────────────────────────────

(defclass project (astrolabe-object)
  ((name         :initarg :name         :accessor project-name         :initform "")
   (description  :initarg :description  :accessor project-description  :initform "")
   (status       :initarg :status       :accessor project-status       :initform "active")
   (priority     :initarg :priority     :accessor project-priority     :initform "B")
   (area         :initarg :area         :accessor project-area         :initform nil)
   (start-date   :initarg :start-date   :accessor project-start-date   :initform nil)
   (target-date  :initarg :target-date  :accessor project-target-date  :initform nil)
   (completed-at :initarg :completed-at :accessor project-completed-at :initform nil)
   (archived-at  :initarg :archived-at  :accessor project-archived-at  :initform nil)
   (owner-id     :initarg :owner-id     :accessor project-owner-id     :initform nil)
   (notes        :initarg :notes        :accessor project-notes        :initform "")))

(defmethod obj-type-name ((obj project)) "project")
(defmethod obj-display-title ((obj project)) (project-name obj))

(defparameter *project-cols*
  "id, name, description, status, priority, area, start_date, target_date,
   completed_at, archived_at, owner_id, notes, created_at, updated_at, deleted_at")

(defun make-project-from-row (row)
  (make-instance 'project
                 :id           (nth 0 row)  :name         (nth 1 row)
                 :description  (nth 2 row)  :status       (nth 3 row)
                 :priority     (nth 4 row)  :area         (nth 5 row)
                 :start-date   (nth 6 row)  :target-date  (nth 7 row)
                 :completed-at (nth 8 row)  :archived-at  (nth 9 row)
                 :owner-id     (nth 10 row) :notes        (nth 11 row)
                 :created-at   (nth 12 row) :updated-at   (nth 13 row)
                 :deleted-at   (nth 14 row)))

(defun save-project (project)
  (if (obj-id project)
      (progn
        (db-execute "UPDATE projects SET name=?, description=?, status=?, priority=?,
                     area=?, start_date=?, target_date=?, completed_at=?, archived_at=?,
                     owner_id=?, notes=?, updated_at=datetime('now') WHERE id=?"
                    (project-name project) (project-description project)
                    (project-status project) (project-priority project)
                    (project-area project) (project-start-date project)
                    (project-target-date project) (project-completed-at project)
                    (project-archived-at project) (project-owner-id project)
                    (project-notes project) (obj-id project))
        project)
      (progn
        (db-execute "INSERT INTO projects (name, description, status, priority, area,
                     start_date, target_date, owner_id, notes) VALUES (?,?,?,?,?,?,?,?,?)"
                    (project-name project) (project-description project)
                    (project-status project) (project-priority project)
                    (project-area project) (project-start-date project)
                    (project-target-date project) (project-owner-id project)
                    (project-notes project))
        (setf (obj-id project) (db-last-insert-id))
        (db-execute "INSERT INTO projects_fts (rowid, name, description, notes) VALUES (?,?,?,?)"
                    (obj-id project) (project-name project)
                    (project-description project) (project-notes project))
        project)))

(defun load-project (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM projects WHERE id=? AND deleted_at IS NULL"
                      *project-cols*) id)))
    (when row (make-project-from-row row))))

(defun load-active-projects (&optional (limit 20))
  (mapcar #'make-project-from-row
          (db-query (format nil "SELECT ~A FROM projects
                     WHERE deleted_at IS NULL AND status IN ('active','paused')
                     ORDER BY priority ASC, updated_at DESC LIMIT ?" *project-cols*) limit)))

(defun archive-project (project)
  "Archive a project (distinct from soft-delete)."
  (setf (project-status project) "archived")
  (db-execute "UPDATE projects SET status='archived', archived_at=datetime('now'),
               updated_at=datetime('now') WHERE id=?" (obj-id project))
  project)

(defun delete-project (project)
  (when (obj-id project)
    (db-execute "UPDATE projects SET deleted_at=datetime('now') WHERE id=?" (obj-id project))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Person (CRM contact)
;;; ─────────────────────────────────────────────────────────────────────

(defclass person (astrolabe-object)
  ((name              :initarg :name              :accessor person-name              :initform "")
   (first-name        :initarg :first-name        :accessor person-first-name        :initform nil)
   (last-name         :initarg :last-name         :accessor person-last-name         :initform nil)
   (nickname          :initarg :nickname          :accessor person-nickname          :initform nil)
   (email             :initarg :email             :accessor person-email             :initform nil)
   (email2            :initarg :email2            :accessor person-email2            :initform nil)
   (phone             :initarg :phone             :accessor person-phone             :initform nil)
   (phone2            :initarg :phone2            :accessor person-phone2            :initform nil)
   (organization      :initarg :organization      :accessor person-organization      :initform nil)
   (job-title         :initarg :job-title         :accessor person-job-title         :initform nil)
   (role              :initarg :role              :accessor person-role              :initform nil)
   (website           :initarg :website           :accessor person-website           :initform nil)
   (address           :initarg :address           :accessor person-address           :initform nil)
   (city              :initarg :city              :accessor person-city              :initform nil)
   (state             :initarg :state             :accessor person-state             :initform nil)
   (postal-code       :initarg :postal-code       :accessor person-postal-code       :initform nil)
   (country           :initarg :country           :accessor person-country           :initform nil)
   (birthday          :initarg :birthday          :accessor person-birthday          :initform nil)
   (xmpp-jid          :initarg :xmpp-jid          :accessor person-xmpp-jid          :initform nil)
   (matrix-id         :initarg :matrix-id         :accessor person-matrix-id         :initform nil)
   (irc-nick          :initarg :irc-nick          :accessor person-irc-nick          :initform nil)
   (avatar-url        :initarg :avatar-url        :accessor person-avatar-url        :initform nil)
   (notes             :initarg :notes             :accessor person-notes             :initform "")
   (last-contacted    :initarg :last-contacted    :accessor person-last-contacted    :initform nil)
   (contact-frequency :initarg :contact-frequency :accessor person-contact-frequency :initform nil)
   (pinned            :initarg :pinned            :accessor person-pinned            :initform 0)))

(defmethod obj-type-name ((obj person)) "person")
(defmethod obj-display-title ((obj person)) (person-name obj))

(defparameter *person-cols*
  "id, name, first_name, last_name, nickname, email, email2, phone, phone2,
   organization, job_title, role, website, address, city, state, postal_code,
   country, birthday, xmpp_jid, matrix_id, irc_nick, avatar_url, notes,
   last_contacted, contact_frequency, pinned, created_at, updated_at, deleted_at")

(defun make-person-from-row (row)
  (make-instance 'person
                 :id               (nth 0 row)  :name              (nth 1 row)
                 :first-name       (nth 2 row)  :last-name         (nth 3 row)
                 :nickname         (nth 4 row)  :email             (nth 5 row)
                 :email2           (nth 6 row)  :phone             (nth 7 row)
                 :phone2           (nth 8 row)  :organization      (nth 9 row)
                 :job-title        (nth 10 row) :role              (nth 11 row)
                 :website          (nth 12 row) :address           (nth 13 row)
                 :city             (nth 14 row) :state             (nth 15 row)
                 :postal-code      (nth 16 row) :country           (nth 17 row)
                 :birthday         (nth 18 row) :xmpp-jid          (nth 19 row)
                 :matrix-id        (nth 20 row) :irc-nick          (nth 21 row)
                 :avatar-url       (nth 22 row) :notes             (nth 23 row)
                 :last-contacted   (nth 24 row) :contact-frequency (nth 25 row)
                 :pinned           (nth 26 row) :created-at        (nth 27 row)
                 :updated-at       (nth 28 row) :deleted-at        (nth 29 row)))

(defun save-person (person)
  (if (obj-id person)
      (progn
        (db-execute "UPDATE persons SET name=?, first_name=?, last_name=?, nickname=?,
                     email=?, email2=?, phone=?, phone2=?, organization=?, job_title=?,
                     role=?, website=?, address=?, city=?, state=?, postal_code=?, country=?,
                     birthday=?, xmpp_jid=?, matrix_id=?, irc_nick=?, avatar_url=?, notes=?,
                     last_contacted=?, contact_frequency=?, pinned=?,
                     updated_at=datetime('now') WHERE id=?"
                    (person-name person) (person-first-name person) (person-last-name person)
                    (person-nickname person) (person-email person) (person-email2 person)
                    (person-phone person) (person-phone2 person) (person-organization person)
                    (person-job-title person) (person-role person) (person-website person)
                    (person-address person) (person-city person) (person-state person)
                    (person-postal-code person) (person-country person)
                    (person-birthday person) (person-xmpp-jid person) (person-matrix-id person)
                    (person-irc-nick person) (person-avatar-url person) (person-notes person)
                    (person-last-contacted person) (person-contact-frequency person)
                    (person-pinned person) (obj-id person))
        person)
      (progn
        (db-execute "INSERT INTO persons (name, first_name, last_name, nickname,
                     email, email2, phone, phone2, organization, job_title,
                     role, website, address, city, state, postal_code, country,
                     birthday, xmpp_jid, matrix_id, irc_nick, avatar_url, notes,
                     last_contacted, contact_frequency, pinned)
                     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
                    (person-name person) (person-first-name person) (person-last-name person)
                    (person-nickname person) (person-email person) (person-email2 person)
                    (person-phone person) (person-phone2 person) (person-organization person)
                    (person-job-title person) (person-role person) (person-website person)
                    (person-address person) (person-city person) (person-state person)
                    (person-postal-code person) (person-country person)
                    (person-birthday person) (person-xmpp-jid person) (person-matrix-id person)
                    (person-irc-nick person) (person-avatar-url person) (person-notes person)
                    (person-last-contacted person) (person-contact-frequency person)
                    (person-pinned person))
        (setf (obj-id person) (db-last-insert-id))
        (db-execute "INSERT INTO persons_fts (rowid, name, first_name, last_name, email, organization, notes)
                     VALUES (?,?,?,?,?,?,?)"
                    (obj-id person) (person-name person) (person-first-name person)
                    (person-last-name person) (person-email person)
                    (person-organization person) (person-notes person))
        person)))

(defun load-person (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM persons WHERE id=? AND deleted_at IS NULL"
                      *person-cols*) id)))
    (when row (make-person-from-row row))))

(defun load-persons (&optional (limit 50))
  "Load all active persons, pinned first."
  (mapcar #'make-person-from-row
          (db-query (format nil "SELECT ~A FROM persons WHERE deleted_at IS NULL
                     ORDER BY pinned DESC, name ASC LIMIT ?" *person-cols*) limit)))

(defun delete-person (person)
  (when (obj-id person)
    (db-execute "UPDATE persons SET deleted_at=datetime('now') WHERE id=?" (obj-id person))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Snippet
;;; ─────────────────────────────────────────────────────────────────────

(defclass snippet (astrolabe-object)
  ((title        :initarg :title        :accessor snippet-title        :initform nil)
   (content      :initarg :content      :accessor snippet-content      :initform "")
   (content-type :initarg :content-type :accessor snippet-content-type :initform "text")
   (language     :initarg :language     :accessor snippet-language     :initform nil)
   (source       :initarg :source       :accessor snippet-source       :initform nil)
   (pinned       :initarg :pinned       :accessor snippet-pinned       :initform 0)))

(defmethod obj-type-name ((obj snippet)) "snippet")
(defmethod obj-display-title ((obj snippet))
  (or (snippet-title obj)
      (let ((content (snippet-content obj)))
        (if (> (length content) 40)
            (concatenate 'string (subseq content 0 40) "...")
            content))))

(defparameter *snippet-cols*
  "id, title, content, content_type, language, source, pinned,
   created_at, updated_at, deleted_at")

(defun make-snippet-from-row (row)
  (make-instance 'snippet
                 :id           (nth 0 row) :title        (nth 1 row)
                 :content      (nth 2 row) :content-type (nth 3 row)
                 :language     (nth 4 row) :source       (nth 5 row)
                 :pinned       (nth 6 row) :created-at   (nth 7 row)
                 :updated-at   (nth 8 row) :deleted-at   (nth 9 row)))

(defun save-snippet (snippet)
  (if (obj-id snippet)
      (progn
        (db-execute "UPDATE snippets SET title=?, content=?, content_type=?, language=?,
                     source=?, pinned=?, updated_at=datetime('now') WHERE id=?"
                    (snippet-title snippet) (snippet-content snippet)
                    (snippet-content-type snippet) (snippet-language snippet)
                    (snippet-source snippet) (snippet-pinned snippet) (obj-id snippet))
        snippet)
      (progn
        (db-execute "INSERT INTO snippets (title, content, content_type, language, source, pinned)
                     VALUES (?,?,?,?,?,?)"
                    (snippet-title snippet) (snippet-content snippet)
                    (snippet-content-type snippet) (snippet-language snippet)
                    (snippet-source snippet) (snippet-pinned snippet))
        (setf (obj-id snippet) (db-last-insert-id))
        (db-execute "INSERT INTO snippets_fts (rowid, title, content, source) VALUES (?,?,?,?)"
                    (obj-id snippet) (snippet-title snippet) (snippet-content snippet)
                    (snippet-source snippet))
        snippet)))

(defun load-snippet (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM snippets WHERE id=? AND deleted_at IS NULL"
                      *snippet-cols*) id)))
    (when row (make-snippet-from-row row))))

(defun load-recent-snippets (&optional (limit 20))
  (mapcar #'make-snippet-from-row
          (db-query (format nil "SELECT ~A FROM snippets WHERE deleted_at IS NULL
                     ORDER BY pinned DESC, created_at DESC LIMIT ?" *snippet-cols*) limit)))

(defun delete-snippet (snippet)
  (when (obj-id snippet)
    (db-execute "UPDATE snippets SET deleted_at=datetime('now') WHERE id=?" (obj-id snippet))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Bookmark
;;; ─────────────────────────────────────────────────────────────────────

(defclass bookmark ()
  ((id          :initarg :id          :accessor bookmark-id          :initform nil)
   (title       :initarg :title       :accessor bookmark-title       :initform "")
   (url         :initarg :url         :accessor bookmark-url         :initform nil)
   (object-type :initarg :object-type :accessor bookmark-object-type :initform nil)
   (object-id   :initarg :object-id   :accessor bookmark-object-id   :initform nil)
   (sort-order  :initarg :sort-order  :accessor bookmark-sort-order  :initform 0)
   (icon        :initarg :icon        :accessor bookmark-icon        :initform nil)
   (description :initarg :description :accessor bookmark-description :initform "")
   (created-at  :initarg :created-at  :accessor bookmark-created-at  :initform nil)
   (deleted-at  :initarg :deleted-at  :accessor bookmark-deleted-at  :initform nil)))

(defparameter *bookmark-cols*
  "id, title, url, object_type, object_id, sort_order, icon, description, created_at, deleted_at")

(defun make-bookmark-from-row (row)
  (make-instance 'bookmark
                 :id          (nth 0 row) :title       (nth 1 row)
                 :url         (nth 2 row) :object-type (nth 3 row)
                 :object-id   (nth 4 row) :sort-order  (nth 5 row)
                 :icon        (nth 6 row) :description (nth 7 row)
                 :created-at  (nth 8 row) :deleted-at  (nth 9 row)))

(defun save-bookmark (bm)
  (if (bookmark-id bm)
      (progn
        (db-execute "UPDATE bookmarks SET title=?, url=?, object_type=?, object_id=?,
                     sort_order=?, icon=?, description=? WHERE id=?"
                    (bookmark-title bm) (bookmark-url bm) (bookmark-object-type bm)
                    (bookmark-object-id bm) (bookmark-sort-order bm)
                    (bookmark-icon bm) (bookmark-description bm) (bookmark-id bm))
        bm)
      (progn
        (db-execute "INSERT INTO bookmarks (title, url, object_type, object_id, sort_order, icon, description)
                     VALUES (?,?,?,?,?,?,?)"
                    (bookmark-title bm) (bookmark-url bm) (bookmark-object-type bm)
                    (bookmark-object-id bm) (bookmark-sort-order bm)
                    (bookmark-icon bm) (bookmark-description bm))
        (setf (bookmark-id bm) (db-last-insert-id))
        bm)))

(defun load-bookmarks (&optional (limit 20))
  (mapcar #'make-bookmark-from-row
          (db-query (format nil "SELECT ~A FROM bookmarks WHERE deleted_at IS NULL
                     ORDER BY sort_order ASC, created_at DESC LIMIT ?" *bookmark-cols*) limit)))

(defun delete-bookmark (bm)
  (when (bookmark-id bm)
    (db-execute "UPDATE bookmarks SET deleted_at=datetime('now') WHERE id=?" (bookmark-id bm))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Links
;;; ─────────────────────────────────────────────────────────────────────

(defun create-link (source target &optional (relation "references"))
  "Create a link between two astrolabe objects."
  (db-execute "INSERT OR IGNORE INTO links (source_type, source_id, target_type, target_id, relation)
               VALUES (?, ?, ?, ?, ?)"
              (obj-type-name source) (obj-id source)
              (obj-type-name target) (obj-id target)
              relation))

(defun load-linked-objects (object)
  "Load all objects linked from OBJECT. Returns a list of (type id relation) triples."
  (db-query "SELECT target_type, target_id, relation FROM links
             WHERE source_type=? AND source_id=?
             UNION
             SELECT source_type, source_id, relation FROM links
             WHERE target_type=? AND target_id=?"
            (obj-type-name object) (obj-id object)
            (obj-type-name object) (obj-id object)))

(defun load-object-by-type-and-id (type-name id)
  "Load an object given its type name string and database ID."
  (cond
    ((string-equal type-name "note")    (load-note id))
    ((string-equal type-name "task")    (load-task id))
    ((string-equal type-name "project") (load-project id))
    ((string-equal type-name "person")  (load-person id))
    ((string-equal type-name "snippet") (load-snippet id))
    (t nil)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Activity log
;;; ─────────────────────────────────────────────────────────────────────

(defun log-activity (action object &optional detail)
  "Record an activity log entry."
  (db-execute "INSERT INTO activity_log (action, object_type, object_id, detail) VALUES (?,?,?,?)"
              action (obj-type-name object) (obj-id object) detail))

(defun load-recent-activity (&optional (limit 50))
  "Load recent activity log entries as raw rows."
  (db-query "SELECT id, action, object_type, object_id, detail, created_at
             FROM activity_log ORDER BY created_at DESC LIMIT ?" limit))
