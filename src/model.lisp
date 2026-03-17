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
    ((string-equal type-name "note")         (load-note id))
    ((string-equal type-name "task")         (load-task id))
    ((string-equal type-name "project")      (load-project id))
    ((string-equal type-name "person")       (load-person id))
    ((string-equal type-name "snippet")      (load-snippet id))
    ((string-equal type-name "conversation") (load-conversation id))
    ((string-equal type-name "feed")         (load-feed id))
    (t nil)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Search (FTS5)
;;; ─────────────────────────────────────────────────────────────────────

(defun search-notes (query &optional (limit 20))
  "Search notes via FTS5. Returns note objects."
  (mapcar #'make-note-from-row
          (db-query (format nil "SELECT ~A FROM notes WHERE id IN
                     (SELECT rowid FROM notes_fts WHERE notes_fts MATCH ?)
                     AND deleted_at IS NULL ORDER BY updated_at DESC LIMIT ?"
                            *note-cols*)
                    query limit)))

(defun search-tasks (query &optional (limit 20))
  "Search tasks via FTS5. Returns task objects."
  (mapcar #'make-task-from-row
          (db-query (format nil "SELECT ~A FROM tasks WHERE id IN
                     (SELECT rowid FROM tasks_fts WHERE tasks_fts MATCH ?)
                     AND deleted_at IS NULL ORDER BY updated_at DESC LIMIT ?"
                            *task-cols*)
                    query limit)))

(defun search-projects (query &optional (limit 20))
  "Search projects via FTS5. Returns project objects."
  (mapcar #'make-project-from-row
          (db-query (format nil "SELECT ~A FROM projects WHERE id IN
                     (SELECT rowid FROM projects_fts WHERE projects_fts MATCH ?)
                     AND deleted_at IS NULL ORDER BY updated_at DESC LIMIT ?"
                            *project-cols*)
                    query limit)))

(defun search-persons (query &optional (limit 20))
  "Search persons via FTS5. Returns person objects."
  (mapcar #'make-person-from-row
          (db-query (format nil "SELECT ~A FROM persons WHERE id IN
                     (SELECT rowid FROM persons_fts WHERE persons_fts MATCH ?)
                     AND deleted_at IS NULL ORDER BY name ASC LIMIT ?"
                            *person-cols*)
                    query limit)))

(defun search-snippets (query &optional (limit 20))
  "Search snippets via FTS5. Returns snippet objects."
  (mapcar #'make-snippet-from-row
          (db-query (format nil "SELECT ~A FROM snippets WHERE id IN
                     (SELECT rowid FROM snippets_fts WHERE snippets_fts MATCH ?)
                     AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?"
                            *snippet-cols*)
                    query limit)))

(defun search-all (query &optional (limit 10))
  "Search all object types. Returns a list of mixed objects."
  (let ((results nil))
    (dolist (note (search-notes query limit)) (push note results))
    (dolist (task (search-tasks query limit)) (push task results))
    (dolist (project (search-projects query limit)) (push project results))
    (dolist (person (search-persons query limit)) (push person results))
    (dolist (snippet (search-snippets query limit)) (push snippet results))
    (nreverse results)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Fuzzy find — LIKE-based matching across all object types
;;; ─────────────────────────────────────────────────────────────────────

(defun fuzzy-find (partial &optional (limit 20))
  "Find objects whose display name contains PARTIAL (case-insensitive). Returns mixed list."
  (let ((pattern (concatenate 'string "%" partial "%"))
        (results nil))
    (dolist (row (db-query (format nil "SELECT ~A FROM notes WHERE deleted_at IS NULL AND title LIKE ? LIMIT ?"
                                   *note-cols*) pattern limit))
      (push (make-note-from-row row) results))
    (dolist (row (db-query (format nil "SELECT ~A FROM tasks WHERE deleted_at IS NULL AND title LIKE ? LIMIT ?"
                                   *task-cols*) pattern limit))
      (push (make-task-from-row row) results))
    (dolist (row (db-query (format nil "SELECT ~A FROM projects WHERE deleted_at IS NULL AND name LIKE ? LIMIT ?"
                                   *project-cols*) pattern limit))
      (push (make-project-from-row row) results))
    (dolist (row (db-query (format nil "SELECT ~A FROM persons WHERE deleted_at IS NULL AND name LIKE ? LIMIT ?"
                                   *person-cols*) pattern limit))
      (push (make-person-from-row row) results))
    (dolist (row (db-query (format nil "SELECT ~A FROM snippets WHERE deleted_at IS NULL AND title LIKE ? LIMIT ?"
                                   *snippet-cols*) pattern limit))
      (push (make-snippet-from-row row) results))
    (nreverse results)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Agenda queries
;;; ─────────────────────────────────────────────────────────────────────

(defun load-overdue-tasks (&optional (limit 50))
  "Load tasks whose due_date is before today."
  (let ((today (subseq (local-time:format-timestring nil (local-time:now)
                         :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                       0 10)))
    (mapcar #'make-task-from-row
            (db-query (format nil "SELECT ~A FROM tasks
                       WHERE deleted_at IS NULL
                         AND status IN ('todo','active','waiting')
                         AND due_date < ?
                       ORDER BY due_date ASC, priority ASC LIMIT ?" *task-cols*)
                      today limit))))

(defun load-upcoming-tasks (days &optional (limit 50))
  "Load tasks due within the next DAYS days."
  (let* ((now (local-time:now))
         (today (subseq (local-time:format-timestring nil now
                          :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                        0 10))
         (future (subseq (local-time:format-timestring
                          nil (local-time:timestamp+ now days :day)
                          :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                         0 10)))
    (mapcar #'make-task-from-row
            (db-query (format nil "SELECT ~A FROM tasks
                       WHERE deleted_at IS NULL
                         AND status IN ('todo','active','waiting')
                         AND due_date >= ? AND due_date <= ?
                       ORDER BY due_date ASC, priority ASC LIMIT ?" *task-cols*)
                      today future limit))))

(defun load-recent-captures (&optional (hours 24) (limit 20))
  "Load objects created in the last HOURS hours. Returns mixed list."
  (let ((cutoff (local-time:format-timestring
                 nil (local-time:timestamp- (local-time:now) hours :hour)
                 :format '((:year 4) #\- (:month 2) #\- (:day 2) #\Space
                           (:hour 2) #\: (:min 2) #\: (:sec 2))))
        (results nil))
    (dolist (row (db-query (format nil "SELECT ~A FROM notes WHERE deleted_at IS NULL AND created_at >= ? ORDER BY created_at DESC LIMIT ?"
                                   *note-cols*) cutoff limit))
      (push (make-note-from-row row) results))
    (dolist (row (db-query (format nil "SELECT ~A FROM tasks WHERE deleted_at IS NULL AND created_at >= ? ORDER BY created_at DESC LIMIT ?"
                                   *task-cols*) cutoff limit))
      (push (make-task-from-row row) results))
    (dolist (row (db-query (format nil "SELECT ~A FROM snippets WHERE deleted_at IS NULL AND created_at >= ? ORDER BY created_at DESC LIMIT ?"
                                   *snippet-cols*) cutoff limit))
      (push (make-snippet-from-row row) results))
    (nreverse results)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Bookmark helpers for pinning astrolabe objects
;;; ─────────────────────────────────────────────────────────────────────

(defun bookmark-object (object)
  "Create a bookmark pointing to an astrolabe object."
  (save-bookmark (make-instance 'bookmark
                                :title (obj-display-title object)
                                :object-type (obj-type-name object)
                                :object-id (obj-id object))))

(defun unbookmark-object (object)
  "Remove bookmark for an astrolabe object."
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM bookmarks WHERE object_type=? AND object_id=? AND deleted_at IS NULL"
                      *bookmark-cols*)
              (obj-type-name object) (obj-id object))))
    (when row
      (delete-bookmark (make-bookmark-from-row row)))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Tags
;;; ─────────────────────────────────────────────────────────────────────

(defun create-tag (name &optional color description)
  "Create a tag. Returns the tag row (id name color description created_at)."
  (let ((existing (db-query-single "SELECT id, name, color, description, created_at
                                    FROM tags WHERE name=?" name)))
    (if existing
        existing
        (progn
          (db-execute "INSERT INTO tags (name, color, description) VALUES (?,?,?)"
                      name color (or description ""))
          (db-query-single "SELECT id, name, color, description, created_at
                            FROM tags WHERE id=?" (db-last-insert-id))))))

(defun load-tag-by-name (name)
  "Load a tag by its name."
  (db-query-single "SELECT id, name, color, description, created_at FROM tags WHERE name=?" name))

(defun load-all-tags ()
  "Load all tags."
  (db-query "SELECT id, name, color, description, created_at FROM tags ORDER BY name ASC"))

(defun tag-object (object tag-name)
  "Apply a tag to an object. Creates the tag if it doesn't exist."
  (let ((tag (create-tag tag-name)))
    (db-execute "INSERT OR IGNORE INTO object_tags (object_type, object_id, tag_id)
                 VALUES (?,?,?)"
                (obj-type-name object) (obj-id object) (first tag))))

(defun untag-object (object tag-name)
  "Remove a tag from an object."
  (let ((tag (load-tag-by-name tag-name)))
    (when tag
      (db-execute "DELETE FROM object_tags WHERE object_type=? AND object_id=? AND tag_id=?"
                  (obj-type-name object) (obj-id object) (first tag)))))

(defun load-tags-for-object (object)
  "Load all tags for an object. Returns a list of (id name color description) rows."
  (db-query "SELECT t.id, t.name, t.color, t.description
             FROM tags t
             JOIN object_tags ot ON ot.tag_id = t.id
             WHERE ot.object_type=? AND ot.object_id=?
             ORDER BY t.name ASC"
            (obj-type-name object) (obj-id object)))

(defun load-objects-by-tag (tag-name &optional (limit 50))
  "Load all objects with a given tag. Returns a list of (object_type object_id) rows."
  (db-query "SELECT ot.object_type, ot.object_id
             FROM object_tags ot
             JOIN tags t ON t.id = ot.tag_id
             WHERE t.name=?
             ORDER BY ot.created_at DESC LIMIT ?"
            tag-name limit))

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

;;; ─────────────────────────────────────────────────────────────────────
;;; Conversation (XMPP)
;;; ─────────────────────────────────────────────────────────────────────

(defclass conversation ()
  ((id            :initarg :id            :accessor conv-id            :initform nil)
   (jid           :initarg :jid           :accessor conv-jid           :initform "")
   (display-name  :initarg :display-name  :accessor conv-display-name  :initform nil)
   (conv-type     :initarg :conv-type     :accessor conv-type          :initform "dm")
   (person-id     :initarg :person-id     :accessor conv-person-id     :initform nil)
   (project-id    :initarg :project-id    :accessor conv-project-id    :initform nil)
   (unread-count  :initarg :unread-count  :accessor conv-unread-count  :initform 0)
   (pinned        :initarg :pinned        :accessor conv-pinned        :initform 0)
   (last-activity :initarg :last-activity :accessor conv-last-activity :initform nil)
   (created-at    :initarg :created-at    :accessor conv-created-at    :initform nil)
   (deleted-at    :initarg :deleted-at    :accessor conv-deleted-at    :initform nil)))

(defmethod obj-type-name ((obj conversation)) "conversation")
(defmethod obj-display-title ((obj conversation))
  (or (conv-display-name obj) (conv-jid obj)))

(defparameter *conv-cols*
  "id, jid, display_name, type, person_id, project_id, unread_count, pinned, last_activity, created_at, deleted_at")

(defun make-conv-from-row (row)
  (make-instance 'conversation
                 :id (nth 0 row) :jid (nth 1 row)
                 :display-name (nth 2 row) :conv-type (nth 3 row)
                 :person-id (nth 4 row) :project-id (nth 5 row)
                 :unread-count (or (nth 6 row) 0) :pinned (or (nth 7 row) 0)
                 :last-activity (nth 8 row)
                 :created-at (nth 9 row) :deleted-at (nth 10 row)))

(defun save-conversation (conv)
  (if (conv-id conv)
      (progn
        (db-execute "UPDATE conversations SET jid=?, display_name=?, type=?,
                     person_id=?, project_id=?, unread_count=?, pinned=?, last_activity=?
                     WHERE id=?"
                    (conv-jid conv) (conv-display-name conv) (conv-type conv)
                    (conv-person-id conv) (conv-project-id conv)
                    (conv-unread-count conv) (conv-pinned conv) (conv-last-activity conv)
                    (conv-id conv))
        conv)
      (progn
        (db-execute "INSERT INTO conversations (jid, display_name, type, person_id, project_id)
                     VALUES (?,?,?,?,?)"
                    (conv-jid conv) (conv-display-name conv) (conv-type conv)
                    (conv-person-id conv) (conv-project-id conv))
        (setf (conv-id conv) (db-last-insert-id))
        conv)))

(defun load-conversation (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM conversations WHERE id=? AND deleted_at IS NULL" *conv-cols*) id)))
    (when row (make-conv-from-row row))))

(defun load-conversation-by-jid (jid)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM conversations WHERE jid=? AND deleted_at IS NULL" *conv-cols*) jid)))
    (when row (make-conv-from-row row))))

(defun load-conversations (&optional (limit 50))
  "Load active conversations, pinned first, then by last activity."
  (mapcar #'make-conv-from-row
          (db-query (format nil "SELECT ~A FROM conversations WHERE deleted_at IS NULL
                     ORDER BY pinned DESC, last_activity DESC NULLS LAST LIMIT ?" *conv-cols*) limit)))

(defun delete-conversation (conv)
  (when (conv-id conv)
    (db-execute "UPDATE conversations SET deleted_at=datetime('now') WHERE id=?" (conv-id conv))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Message (XMPP)
;;; ─────────────────────────────────────────────────────────────────────

(defclass xmpp-message ()
  ((id              :initarg :id              :accessor xmsg-id              :initform nil)
   (conversation-id :initarg :conversation-id :accessor xmsg-conversation-id :initform nil)
   (sender-jid      :initarg :sender-jid      :accessor xmsg-sender-jid      :initform nil)
   (sender-nick     :initarg :sender-nick     :accessor xmsg-sender-nick     :initform nil)
   (body            :initarg :body            :accessor xmsg-body            :initform "")
   (stanza-id       :initarg :stanza-id       :accessor xmsg-stanza-id       :initform nil)
   (level           :initarg :level           :accessor xmsg-level           :initform nil)
   (encrypted       :initarg :encrypted       :accessor xmsg-encrypted       :initform 0)
   (edited          :initarg :edited          :accessor xmsg-edited          :initform 0)
   (created-at      :initarg :created-at      :accessor xmsg-created-at      :initform nil)))

(defparameter *xmsg-cols*
  "id, conversation_id, sender_jid, sender_nick, body, stanza_id, level, encrypted, edited, created_at")

(defun make-xmsg-from-row (row)
  (make-instance 'xmpp-message
                 :id (nth 0 row) :conversation-id (nth 1 row)
                 :sender-jid (nth 2 row) :sender-nick (nth 3 row)
                 :body (nth 4 row) :stanza-id (nth 5 row)
                 :level (nth 6 row) :encrypted (or (nth 7 row) 0)
                 :edited (or (nth 8 row) 0) :created-at (nth 9 row)))

(defun save-xmpp-message (msg)
  (if (xmsg-id msg)
      msg
      (progn
        (db-execute "INSERT INTO messages (conversation_id, sender_jid, sender_nick, body, stanza_id, level, encrypted)
                     VALUES (?,?,?,?,?,?,?)"
                    (xmsg-conversation-id msg) (xmsg-sender-jid msg) (xmsg-sender-nick msg)
                    (xmsg-body msg) (xmsg-stanza-id msg) (xmsg-level msg) (xmsg-encrypted msg))
        (setf (xmsg-id msg) (db-last-insert-id))
        ;; Update conversation last_activity
        (db-execute "UPDATE conversations SET last_activity=datetime('now'),
                     unread_count = unread_count + 1 WHERE id=?"
                    (xmsg-conversation-id msg))
        msg)))

(defun load-messages (conversation-id &optional (limit 100))
  "Load messages for a conversation, most recent first."
  (mapcar #'make-xmsg-from-row
          (db-query (format nil "SELECT ~A FROM messages WHERE conversation_id=?
                     ORDER BY created_at DESC LIMIT ?" *xmsg-cols*)
                    conversation-id limit)))

(defun mark-conversation-read (conv)
  "Reset unread count for a conversation."
  (when (conv-id conv)
    (db-execute "UPDATE conversations SET unread_count=0 WHERE id=?" (conv-id conv))
    (setf (conv-unread-count conv) 0)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Feed (RSS/Atom)
;;; ─────────────────────────────────────────────────────────────────────

(defclass feed ()
  ((id             :initarg :id             :accessor feed-id             :initform nil)
   (url            :initarg :url            :accessor feed-url            :initform "")
   (title          :initarg :title          :accessor feed-title          :initform nil)
   (description    :initarg :description    :accessor feed-description    :initform "")
   (site-url       :initarg :site-url       :accessor feed-site-url       :initform nil)
   (feed-type      :initarg :feed-type      :accessor feed-feed-type      :initform "rss")
   (last-fetched   :initarg :last-fetched   :accessor feed-last-fetched   :initform nil)
   (fetch-interval :initarg :fetch-interval :accessor feed-fetch-interval :initform 3600)
   (unread-count   :initarg :unread-count   :accessor feed-unread-count   :initform 0)
   (error-count    :initarg :error-count    :accessor feed-error-count    :initform 0)
   (last-error     :initarg :last-error     :accessor feed-last-error     :initform nil)
   (pinned         :initarg :pinned         :accessor feed-pinned         :initform 0)
   (created-at     :initarg :created-at     :accessor feed-created-at     :initform nil)
   (deleted-at     :initarg :deleted-at     :accessor feed-deleted-at     :initform nil)))

(defmethod obj-type-name ((obj feed)) "feed")
(defmethod obj-display-title ((obj feed))
  (or (feed-title obj) (feed-url obj)))

(defparameter *feed-cols*
  "id, url, title, description, site_url, feed_type, last_fetched, fetch_interval, unread_count, error_count, last_error, pinned, created_at, deleted_at")

(defun make-feed-from-row (row)
  (make-instance 'feed
                 :id (nth 0 row) :url (nth 1 row) :title (nth 2 row)
                 :description (nth 3 row) :site-url (nth 4 row) :feed-type (nth 5 row)
                 :last-fetched (nth 6 row) :fetch-interval (or (nth 7 row) 3600)
                 :unread-count (or (nth 8 row) 0) :error-count (or (nth 9 row) 0)
                 :last-error (nth 10 row) :pinned (or (nth 11 row) 0)
                 :created-at (nth 12 row) :deleted-at (nth 13 row)))

(defun save-feed (f)
  (if (feed-id f)
      (progn
        (db-execute "UPDATE feeds SET url=?, title=?, description=?, site_url=?, feed_type=?,
                     last_fetched=?, fetch_interval=?, unread_count=?, error_count=?, last_error=?, pinned=?
                     WHERE id=?"
                    (feed-url f) (feed-title f) (feed-description f) (feed-site-url f)
                    (feed-feed-type f) (feed-last-fetched f) (feed-fetch-interval f)
                    (feed-unread-count f) (feed-error-count f) (feed-last-error f)
                    (feed-pinned f) (feed-id f))
        f)
      (progn
        (db-execute "INSERT INTO feeds (url, title, description, site_url, feed_type) VALUES (?,?,?,?,?)"
                    (feed-url f) (feed-title f) (feed-description f) (feed-site-url f) (feed-feed-type f))
        (setf (feed-id f) (db-last-insert-id))
        f)))

(defun load-feed (id)
  (let ((row (db-query-single
              (format nil "SELECT ~A FROM feeds WHERE id=? AND deleted_at IS NULL" *feed-cols*) id)))
    (when row (make-feed-from-row row))))

(defun load-feeds (&optional (limit 50))
  "Load active feed subscriptions."
  (mapcar #'make-feed-from-row
          (db-query (format nil "SELECT ~A FROM feeds WHERE deleted_at IS NULL
                     ORDER BY pinned DESC, title ASC LIMIT ?" *feed-cols*) limit)))

(defun delete-feed (f)
  (when (feed-id f)
    (db-execute "UPDATE feeds SET deleted_at=datetime('now') WHERE id=?" (feed-id f))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Feed Item
;;; ─────────────────────────────────────────────────────────────────────

(defclass feed-item ()
  ((id           :initarg :id           :accessor fi-id           :initform nil)
   (feed-id      :initarg :feed-id      :accessor fi-feed-id      :initform nil)
   (title        :initarg :title        :accessor fi-title        :initform nil)
   (url          :initarg :url          :accessor fi-url          :initform nil)
   (author       :initarg :author       :accessor fi-author       :initform nil)
   (summary      :initarg :summary      :accessor fi-summary      :initform "")
   (content      :initarg :content      :accessor fi-content      :initform "")
   (published-at :initarg :published-at :accessor fi-published-at :initform nil)
   (guid         :initarg :guid         :accessor fi-guid         :initform nil)
   (item-read    :initarg :item-read    :accessor fi-read         :initform 0)
   (starred      :initarg :starred      :accessor fi-starred      :initform 0)
   (created-at   :initarg :created-at   :accessor fi-created-at   :initform nil)))

(defmethod obj-type-name ((obj feed-item)) "feed_item")
(defmethod obj-display-title ((obj feed-item))
  (or (fi-title obj) "(untitled)"))

(defparameter *fi-cols*
  "id, feed_id, title, url, author, summary, content, published_at, guid, read, starred, created_at")

(defun make-fi-from-row (row)
  (make-instance 'feed-item
                 :id (nth 0 row) :feed-id (nth 1 row) :title (nth 2 row)
                 :url (nth 3 row) :author (nth 4 row) :summary (nth 5 row)
                 :content (nth 6 row) :published-at (nth 7 row) :guid (nth 8 row)
                 :item-read (or (nth 9 row) 0) :starred (or (nth 10 row) 0)
                 :created-at (nth 11 row)))

(defun save-feed-item (fi)
  (if (fi-id fi)
      (progn
        (db-execute "UPDATE feed_items SET title=?, url=?, author=?, summary=?, content=?,
                     published_at=?, guid=?, read=?, starred=? WHERE id=?"
                    (fi-title fi) (fi-url fi) (fi-author fi) (fi-summary fi) (fi-content fi)
                    (fi-published-at fi) (fi-guid fi) (fi-read fi) (fi-starred fi) (fi-id fi))
        fi)
      (progn
        (db-execute "INSERT OR IGNORE INTO feed_items (feed_id, title, url, author, summary, content, published_at, guid)
                     VALUES (?,?,?,?,?,?,?,?)"
                    (fi-feed-id fi) (fi-title fi) (fi-url fi) (fi-author fi)
                    (fi-summary fi) (fi-content fi) (fi-published-at fi) (fi-guid fi))
        (setf (fi-id fi) (db-last-insert-id))
        fi)))

(defun load-feed-items (feed-id &key (limit 50) unread-only)
  "Load items for a feed."
  (mapcar #'make-fi-from-row
          (db-query (format nil "SELECT ~A FROM feed_items WHERE feed_id=?~A
                     ORDER BY published_at DESC NULLS LAST, created_at DESC LIMIT ?"
                           *fi-cols*
                           (if unread-only " AND read=0" ""))
                    feed-id limit)))

(defun load-unread-feed-items (&optional (limit 50))
  "Load all unread items across all feeds."
  (mapcar #'make-fi-from-row
          (db-query (format nil "SELECT ~A FROM feed_items WHERE read=0
                     ORDER BY published_at DESC NULLS LAST, created_at DESC LIMIT ?" *fi-cols*)
                    limit)))

(defun mark-feed-item-read (fi)
  (when (fi-id fi)
    (db-execute "UPDATE feed_items SET read=1 WHERE id=?" (fi-id fi))
    (setf (fi-read fi) 1)
    ;; Decrement feed unread count
    (db-execute "UPDATE feeds SET unread_count = MAX(0, unread_count - 1) WHERE id=?" (fi-feed-id fi))))

(defun star-feed-item (fi)
  (when (fi-id fi)
    (db-execute "UPDATE feed_items SET starred=1 WHERE id=?" (fi-id fi))
    (setf (fi-starred fi) 1)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Notifications
;;; ─────────────────────────────────────────────────────────────────────

(defclass notification ()
  ((id          :initarg :id          :accessor notif-id          :initform nil)
   (notif-type  :initarg :notif-type  :accessor notif-type        :initform "system")
   (title       :initarg :title       :accessor notif-title       :initform "")
   (body        :initarg :body        :accessor notif-body        :initform "")
   (object-type :initarg :object-type :accessor notif-object-type :initform nil)
   (object-id   :initarg :object-id   :accessor notif-object-id   :initform nil)
   (notif-read  :initarg :notif-read  :accessor notif-read        :initform 0)
   (created-at  :initarg :created-at  :accessor notif-created-at  :initform nil)))

(defparameter *notif-cols*
  "id, type, title, body, object_type, object_id, read, created_at")

(defun make-notif-from-row (row)
  (make-instance 'notification
                 :id (nth 0 row) :notif-type (nth 1 row) :title (nth 2 row)
                 :body (nth 3 row) :object-type (nth 4 row) :object-id (nth 5 row)
                 :notif-read (or (nth 6 row) 0) :created-at (nth 7 row)))

(defun create-notification (type title &key body object-type object-id)
  "Create a new notification."
  (db-execute "INSERT INTO notifications (type, title, body, object_type, object_id) VALUES (?,?,?,?,?)"
              type title (or body "") object-type object-id)
  (make-instance 'notification
                 :id (db-last-insert-id) :notif-type type :title title
                 :body (or body "") :object-type object-type :object-id object-id))

(defun load-notifications (&key (limit 50) unread-only)
  "Load notifications."
  (mapcar #'make-notif-from-row
          (db-query (format nil "SELECT ~A FROM notifications~A
                     ORDER BY created_at DESC LIMIT ?"
                           *notif-cols*
                           (if unread-only " WHERE read=0" ""))
                    limit)))

(defun unread-notification-count ()
  "Return count of unread notifications."
  (let ((row (db-query-single "SELECT COUNT(*) FROM notifications WHERE read=0")))
    (if row (first row) 0)))

(defun mark-notification-read (notif)
  (when (notif-id notif)
    (db-execute "UPDATE notifications SET read=1 WHERE id=?" (notif-id notif))
    (setf (notif-read notif) 1)))

(defun mark-all-notifications-read ()
  "Dismiss all notifications."
  (db-execute "UPDATE notifications SET read=1 WHERE read=0"))
