;;;; feeds.lisp — RSS/Atom feed fetching and parsing for Astrolabe
;;;; Uses drakma for HTTP and plump for XML parsing.

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; XML helpers
;;; ─────────────────────────────────────────────────────────────────────

(defun xml-child (node tag-name)
  "Find the first child element of NODE with local name TAG-NAME (case-insensitive)."
  (when (plump:element-p node)
    (loop for child across (plump:children node)
          when (and (plump:element-p child)
                    (string-equal (plump:tag-name child) tag-name))
            return child)))

(defun xml-child-text (node tag-name)
  "Get text content of the first child element named TAG-NAME."
  (let ((child (xml-child node tag-name)))
    (when child (plump:text child))))

(defun xml-children (node tag-name)
  "Find all child elements of NODE with local name TAG-NAME."
  (when (plump:element-p node)
    (loop for child across (plump:children node)
          when (and (plump:element-p child)
                    (string-equal (plump:tag-name child) tag-name))
            collect child)))

(defun xml-attr (node attr-name)
  "Get attribute value from an element."
  (when (plump:element-p node)
    (plump:attribute node attr-name)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Feed type detection and parsing
;;; ─────────────────────────────────────────────────────────────────────

(defun detect-feed-type (root)
  "Detect whether ROOT is an RSS or Atom feed. Returns :rss, :atom, or nil."
  (let ((tag (when (plump:element-p root) (plump:tag-name root))))
    (cond
      ((string-equal tag "rss")  :rss)
      ((string-equal tag "feed") :atom)
      ((string-equal tag "rdf")  :rss)
      (t nil))))

(defun find-root-element (doc)
  "Find the root element of a plump document."
  (loop for child across (plump:children doc)
        when (plump:element-p child)
          return child))

(defun parse-rss-items (channel)
  "Parse RSS <item> elements from a <channel> element. Returns list of plists."
  (mapcar (lambda (item)
            (list :title     (xml-child-text item "title")
                  :url       (xml-child-text item "link")
                  :author    (or (xml-child-text item "author")
                                 (xml-child-text item "dc:creator"))
                  :summary   (or (xml-child-text item "description") "")
                  :content   (or (xml-child-text item "content:encoded") "")
                  :published (or (xml-child-text item "pubDate")
                                 (xml-child-text item "dc:date"))
                  :guid      (or (xml-child-text item "guid")
                                 (xml-child-text item "link"))))
          (xml-children channel "item")))

(defun parse-atom-entries (feed-el)
  "Parse Atom <entry> elements. Returns list of plists."
  (mapcar (lambda (entry)
            (let ((link-el (or (loop for l in (xml-children entry "link")
                                     when (or (null (xml-attr l "rel"))
                                              (string-equal (xml-attr l "rel") "alternate"))
                                       return l)
                               (first (xml-children entry "link")))))
              (list :title     (xml-child-text entry "title")
                    :url       (when link-el (xml-attr link-el "href"))
                    :author    (let ((a (xml-child entry "author")))
                                 (when a (xml-child-text a "name")))
                    :summary   (or (xml-child-text entry "summary") "")
                    :content   (or (xml-child-text entry "content") "")
                    :published (or (xml-child-text entry "published")
                                   (xml-child-text entry "updated"))
                    :guid      (or (xml-child-text entry "id")
                                   (when link-el (xml-attr link-el "href"))))))
          (xml-children feed-el "entry")))

(defun parse-feed-xml (xml-string)
  "Parse XML-STRING as an RSS or Atom feed.
   Returns (values feed-title feed-description site-url feed-type items-plists)."
  (let* ((doc (plump:parse xml-string))
         (root (find-root-element doc))
         (ftype (detect-feed-type root)))
    (case ftype
      (:rss
       (let ((channel (or (xml-child root "channel") root)))
         (values (xml-child-text channel "title")
                 (xml-child-text channel "description")
                 (xml-child-text channel "link")
                 "rss"
                 (parse-rss-items channel))))
      (:atom
       (let ((link-el (loop for l in (xml-children root "link")
                            when (or (null (xml-attr l "rel"))
                                     (string-equal (xml-attr l "rel") "alternate"))
                              return l)))
         (values (xml-child-text root "title")
                 (xml-child-text root "subtitle")
                 (when link-el (xml-attr link-el "href"))
                 "atom"
                 (parse-atom-entries root))))
      (t (error "Unrecognized feed format")))))

;;; ─────────────────────────────────────────────────────────────────────
;;; Fetch and store
;;; ─────────────────────────────────────────────────────────────────────

(defun fetch-feed-url (url)
  "Fetch feed content from URL using drakma. Returns the body as a string."
  (multiple-value-bind (body status)
      (drakma:http-request url
                           :want-stream nil
                           :connection-timeout 15
                           :decode-content t)
    (unless (= status 200)
      (error "HTTP ~D fetching ~A" status url))
    (if (stringp body)
        body
        (flexi-streams:octets-to-string body :external-format :utf-8))))

(defun fetch-and-store-feed (feed)
  "Fetch a feed's URL, parse the XML, update the feed record and store new items.
   Returns the number of new items stored."
  (handler-case
      (let ((xml (fetch-feed-url (feed-url feed))))
        (multiple-value-bind (title description site-url feed-type items)
            (parse-feed-xml xml)
          ;; Update feed metadata
          (when title       (setf (feed-title feed) title))
          (when description (setf (feed-description feed) description))
          (when site-url    (setf (feed-site-url feed) site-url))
          (when feed-type   (setf (feed-feed-type feed) feed-type))
          (setf (feed-last-fetched feed)
                (local-time:format-timestring nil (local-time:now)
                  :format '((:year 4) #\- (:month 2) #\- (:day 2) #\T
                            (:hour 2) #\: (:min 2) #\: (:sec 2))))
          (setf (feed-error-count feed) 0)
          (setf (feed-last-error feed) nil)
          ;; Store items
          (let ((new-count 0))
            (dolist (item items)
              (let ((guid (or (getf item :guid) (getf item :url) (getf item :title))))
                (when guid
                  ;; Check if already exists
                  (let ((existing (db-query-single
                                   "SELECT id FROM feed_items WHERE feed_id=? AND guid=?"
                                   (feed-id feed) guid)))
                    (unless existing
                      (save-feed-item (make-instance 'feed-item
                                                     :feed-id (feed-id feed)
                                                     :title (getf item :title)
                                                     :url (getf item :url)
                                                     :author (getf item :author)
                                                     :summary (getf item :summary)
                                                     :content (getf item :content)
                                                     :published-at (getf item :published)
                                                     :guid guid))
                      (incf new-count))))))
            ;; Update unread count
            (let ((unread (first (db-query-single
                                  "SELECT COUNT(*) FROM feed_items WHERE feed_id=? AND read=0"
                                  (feed-id feed)))))
              (setf (feed-unread-count feed) (or unread 0)))
            (save-feed feed)
            new-count)))
    (error (e)
      ;; Record the error on the feed
      (setf (feed-error-count feed) (1+ (feed-error-count feed)))
      (setf (feed-last-error feed) (format nil "~A" e))
      (save-feed feed)
      (values 0 e))))

