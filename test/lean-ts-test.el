;;; lean-ts-test.el --- Unit tests for lean-ts -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

(require 'lean-ts)

(require 'buttercup)

(defun lean-indent-test (input expected)
  (with-temp-buffer
    (let ((lean-use-treesitter t)
          (indent-tabs-mode nil))
      (lean-mode)
      (insert-and-set-point input)
      (call-interactively #'indent-according-to-mode)
      ;; TODO: improve the failure messages here.  because test cases
      ;; typically span multiple lines, it's really tough to read or see
      ;; the differences between expected and actual
      (should (string= (buffer-string) (concatenate-lines expected))))))

(describe "indentation"

  (it "increases for declaration body"
    (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                        "|")
                      '("theorem {a : ℝ} : a = a := by"
                        "  ")))

  (it "increases more for type signature"
    (lean-indent-test '("theorem {a : ℝ} "
                        "|: a = a := by")
                      '("theorem {a : ℝ}"
                        "    : a = a := by"))))

(provide 'lean-ts-test)
;;; lean-ts-test.el ends here
