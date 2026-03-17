;;;; llm.lisp — Phase 5: Local LLM integration via Ollama
;;;; Provides AI-assisted knowledge work: summarize, extract tasks, rewrite,
;;;; explain, auto-tag, ask questions, and daily digest.

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Configuration
;;; ─────────────────────────────────────────────────────────────────────

(defvar *ollama-host* "http://127.0.0.1:11434"
  "Ollama API base URL.")

(defvar *ollama-model* "mistral"
  "Default Ollama model name.")

(defvar *llm-timeout* 120
  "HTTP timeout in seconds for LLM requests.")

(defvar *llm-available* nil
  "Whether the Ollama service is reachable. Set by check-llm-availability.")

;;; ─────────────────────────────────────────────────────────────────────
;;; Last LLM response — displayed in the detail pane
;;; ─────────────────────────────────────────────────────────────────────

(defvar *llm-prompt* nil
  "The last prompt sent to the LLM.")

(defvar *llm-response* nil
  "The last response from the LLM.")

(defvar *llm-model-used* nil
  "The model used for the last LLM call.")

;;; ─────────────────────────────────────────────────────────────────────
;;; JSON helpers (using yason)
;;; ─────────────────────────────────────────────────────────────────────

(defun json-encode (alist)
  "Encode an alist as a JSON string using yason."
  (with-output-to-string (s)
    (yason:encode
     (let ((ht (make-hash-table :test 'equal)))
       (loop for (key . val) in alist
             do (setf (gethash key ht) val))
       ht)
     s)))

(defun json-decode (string)
  "Decode a JSON string into a hash table using yason."
  (let ((yason:*parse-json-booleans-as-symbols* t)
        (yason:*parse-json-null-as-keyword* t))
    (yason:parse string)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Core API — talk to Ollama
;;; ─────────────────────────────────────────────────────────────────────

(defun check-llm-availability ()
  "Check if Ollama is running. Sets *llm-available* and returns it."
  (handler-case
      (progn
        (drakma:http-request (format nil "~A/api/tags" *ollama-host*)
                             :method :get
                             :connection-timeout 3)
        (setf *llm-available* t))
    (error ()
      (setf *llm-available* nil))))

(defun llm-generate (prompt &key (model *ollama-model*) (system nil))
  "Send PROMPT to Ollama and return the response text.
   Blocks until complete (stream=false). Returns nil on error."
  (handler-case
      (let* ((payload `(("model" . ,model)
                        ("prompt" . ,prompt)
                        ("stream" . nil)
                        ,@(when system `(("system" . ,system)))))
             (body (json-encode payload))
             (response (drakma:http-request
                        (format nil "~A/api/generate" *ollama-host*)
                        :method :post
                        :content-type "application/json"
                        :content body
                        :connection-timeout *llm-timeout*
                        :read-timeout *llm-timeout*))
             (result (json-decode (if (typep response '(vector (unsigned-byte 8)))
                                      (flexi-streams:octets-to-string response)
                                      response))))
        (setf *llm-model-used* model)
        (setf *llm-prompt* prompt)
        (let ((text (gethash "response" result)))
          (setf *llm-response* text)
          text))
    (error (e)
      (let ((msg (format nil "LLM error: ~A" e)))
        (setf *llm-response* msg)
        nil))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Object-to-text conversion for LLM context
;;; ─────────────────────────────────────────────────────────────────────

(defgeneric object-to-llm-text (object)
  (:documentation "Convert an object to a text representation for LLM input."))

(defmethod object-to-llm-text ((note note))
  (format nil "Title: ~A~%~%~A"
          (note-title note) (or (note-body note) "")))

(defmethod object-to-llm-text ((task task))
  (format nil "Task: ~A~%Status: ~A~%Priority: ~A~A~A~A"
          (task-title task) (task-status task) (task-priority task)
          (if (task-due-date task) (format nil "~%Due: ~A" (task-due-date task)) "")
          (if (task-description task) (format nil "~%~%~A" (task-description task)) "")
          (if (task-notes task) (format nil "~%~%Notes: ~A" (task-notes task)) "")))

(defmethod object-to-llm-text ((project project))
  (format nil "Project: ~A~%Status: ~A~A~A"
          (project-name project) (project-status project)
          (if (project-description project) (format nil "~%~%~A" (project-description project)) "")
          (if (project-notes project) (format nil "~%~%Notes: ~A" (project-notes project)) "")))

(defmethod object-to-llm-text ((snippet snippet))
  (format nil "~A~A~%~%~A"
          (if (snippet-language snippet) (format nil "Language: ~A~%" (snippet-language snippet)) "")
          (if (snippet-source snippet) (format nil "Source: ~A~%" (snippet-source snippet)) "")
          (snippet-content snippet)))

(defmethod object-to-llm-text ((person person))
  (format nil "Person: ~A~A~A~A"
          (person-name person)
          (if (person-organization person) (format nil "~%Organization: ~A" (person-organization person)) "")
          (if (person-job-title person) (format nil "~%Title: ~A" (person-job-title person)) "")
          (if (person-notes person) (format nil "~%~%Notes: ~A" (person-notes person)) "")))

(defmethod object-to-llm-text ((obj t))
  (format nil "~A: ~A" (obj-type-name obj) (obj-display-title obj)))

;;; ─────────────────────────────────────────────────────────────────────
;;; High-level LLM operations
;;; ─────────────────────────────────────────────────────────────────────

(defun llm-summarize (object)
  "Generate a summary of OBJECT using the LLM."
  (let ((text (object-to-llm-text object)))
    (llm-generate
     (format nil "Summarize the following in 2-3 concise sentences:~%~%~A" text)
     :system "You are a concise note-taking assistant. Respond with only the summary, no preamble.")))

(defun llm-extract-tasks (object)
  "Extract action items from OBJECT's text."
  (let ((text (object-to-llm-text object)))
    (llm-generate
     (format nil "Extract action items and tasks from the following text. List each task on its own line, prefixed with '- [ ] '. If there are no clear action items, say 'No action items found.'~%~%~A" text)
     :system "You are a task extraction assistant. Output only the task list, no preamble.")))

(defun llm-rewrite (object)
  "Rewrite OBJECT's text for clarity and conciseness."
  (let ((text (object-to-llm-text object)))
    (llm-generate
     (format nil "Rewrite the following for clarity and conciseness, preserving all key information:~%~%~A" text)
     :system "You are a professional editor. Output only the rewritten text, no commentary.")))

(defun llm-explain (object)
  "Explain the content of OBJECT (especially useful for code snippets and logs)."
  (let ((text (object-to-llm-text object)))
    (llm-generate
     (format nil "Explain the following clearly and concisely:~%~%~A" text)
     :system "You are a technical explainer. Be clear and concise. If it's code, explain what it does and any notable patterns.")))

(defun llm-suggest-tags (object)
  "Suggest tags for OBJECT based on its content."
  (let ((text (object-to-llm-text object)))
    (llm-generate
     (format nil "Suggest 3-5 relevant tags for the following content. Output only the tags as a comma-separated list, nothing else:~%~%~A" text)
     :system "You are a tagging assistant. Output only comma-separated lowercase tags, no explanation.")))

(defun llm-ask (question &key context)
  "Ask a question, optionally with context from objects."
  (let ((prompt (if context
                    (format nil "Context:~%~%~A~%~%Question: ~A" context question)
                    question)))
    (llm-generate prompt
                  :system "You are Astrolabe's AI assistant. Answer questions based on the provided context. Be concise and helpful. If the context doesn't contain enough information, say so.")))

(defun llm-daily-digest ()
  "Generate a daily digest summarizing recent activity."
  (let* ((today (subseq (local-time:format-timestring nil (local-time:now)
                          :format '((:year 4) #\- (:month 2) #\- (:day 2)))
                        0 10))
         (recent-notes (load-recent-notes 5))
         (open-tasks (load-open-tasks 10))
         (notifs (load-notifications :limit 10))
         (context (with-output-to-string (s)
                    (format s "Date: ~A~%~%" today)
                    (format s "=== Recent Notes ===~%")
                    (dolist (n recent-notes)
                      (format s "- ~A~%" (note-title n)))
                    (format s "~%=== Open Tasks ===~%")
                    (dolist (tk open-tasks)
                      (format s "- [~A] ~A~A~%"
                              (task-priority tk) (task-title tk)
                              (if (task-due-date tk)
                                  (format nil " (due ~A)" (task-due-date tk)) "")))
                    (format s "~%=== Recent Notifications ===~%")
                    (dolist (notif notifs)
                      (format s "- ~A: ~A~%"
                              (notif-type notif) (notif-title notif))))))
    (llm-generate
     (format nil "Generate a brief daily digest based on this activity. Highlight priorities, overdue items, and suggest focus areas for the day:~%~%~A" context)
     :system "You are a personal productivity assistant. Generate a concise, actionable daily briefing. Use bullet points. Keep it under 200 words.")))

;;; ─────────────────────────────────────────────────────────────────────
;;; Auto-tag — parse LLM tag suggestions and apply them
;;; ─────────────────────────────────────────────────────────────────────

(defun llm-auto-tag (object)
  "Ask the LLM for tag suggestions and apply them to OBJECT.
   Returns the list of tags applied."
  (let ((response (llm-suggest-tags object)))
    (when response
      (let* ((cleaned (string-trim '(#\Space #\Newline #\Return) response))
             (tags (mapcar (lambda (s) (string-trim '(#\Space #\Newline #\Return) s))
                           (cl-ppcre:split "\\s*,\\s*" cleaned)))
             (valid-tags (remove-if (lambda (s) (or (zerop (length s))
                                                     (> (length s) 50)))
                                    tags)))
        (dolist (tag valid-tags)
          (tag-object object tag))
        valid-tags))))
