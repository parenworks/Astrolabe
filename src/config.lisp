;;;; config.lisp — Configuration and paths for Astrolabe

(in-package #:astrolabe)

(defvar *data-dir*
  (merge-pathnames ".astrolabe/" (user-homedir-pathname))
  "Directory for Astrolabe data files.")

(defvar *db-path*
  (merge-pathnames "astrolabe.db" *data-dir*)
  "Path to the SQLite database file.")

(defun ensure-data-dir ()
  "Create the data directory if it does not exist."
  (ensure-directories-exist *data-dir*))
