;;; lean-input-test.el --- Unit tests for lean-input -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

(load "lean-input")

(require 'buttercup)

(describe "`lean-input--user-translations'"

  (it "handles the expected format"
    (let ((lean-input-user-translations
           '(("key" "trans1" "trans2" "trans3"))))
      (expect (lean-input--user-translations) :to-equal
              '(("key" . ["trans1" "trans2" "trans3"]))))))

(provide 'lean-input-test)
;;; lean-input-test.el ends here
