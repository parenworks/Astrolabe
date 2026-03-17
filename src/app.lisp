;;;; app.lisp — Application frame definition for Astrolabe
;;;; This file MUST load before commands.lisp and presentations.lisp
;;;; because define-application-frame creates the command table they reference.

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Application frame
;;; ─────────────────────────────────────────────────────────────────────

(define-application-frame astrolabe ()
  ()
  (:panes
   (nav-pane :application
             :display-function 'display-navigation
             :scroll-bars nil)
   (detail-pane :application
                :display-function 'display-detail
                :scroll-bars nil)
   (status-pane :application
                :display-function 'display-status-bar
                :scroll-bars nil
                :max-height 1
                :min-height 1)
   (interactor :interactor
               :scroll-bars nil))
  (:layouts
   (default
    (vertically ()
      (5/6 (horizontally ()
             (1/3 nav-pane)
             (2/3 detail-pane)))
      status-pane
      (1/6 interactor))))
  (:top-level (clim-charmed:charmed-frame-top-level)))
