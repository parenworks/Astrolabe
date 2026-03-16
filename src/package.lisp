;;;; package.lisp — Package definition for Astrolabe

(defpackage #:astrolabe
  (:use #:clim #:clim-lisp)
  (:export #:run
           #:*db-path*
           #:*data-dir*))
