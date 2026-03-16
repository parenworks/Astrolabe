;;;; main.lisp — Entry point for Astrolabe
;;;; Loaded last, after frame, commands, presentations, and views are defined.

(in-package #:astrolabe)

;;; ─────────────────────────────────────────────────────────────────────
;;; Entry point
;;; ─────────────────────────────────────────────────────────────────────

(defun run ()
  "Start Astrolabe."
  (open-database)
  (unwind-protect
       (let* ((port (make-instance 'clim-charmed::charmed-port
                                   :server-path '(:charmed)))
              (fm (first (slot-value port 'climi::frame-managers))))
         (unwind-protect
              (let ((frame (make-application-frame 'astrolabe
                                                   :frame-manager fm)))
                (run-frame-top-level frame))
           (climi::destroy-port port)))
    (close-database)))
