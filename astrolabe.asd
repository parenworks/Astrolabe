(defsystem #:astrolabe
  :description "Terminal-native personal operations console"
  :author "Glenn Skinner"
  :license "MIT"
  :version "0.1.0"
  :depends-on (#:mcclim
               #:mcclim-charmed
               #:sqlite
               #:local-time
               #:cl-ppcre)
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "config")
                             (:file "db")
                             (:file "model")
                             (:file "app")
                             (:file "presentations")
                             (:file "commands")
                             (:file "views")
                             (:file "main")))))
