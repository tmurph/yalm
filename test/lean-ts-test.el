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
      (lean-utils--insert-and-set-point input)
      (call-interactively #'indent-according-to-mode)
      ;; TODO: improve the failure messages here.  because test cases
      ;; typically span multiple lines, it's really tough to read or see
      ;; the differences between expected and actual
      (should (string= (buffer-string) (lean-utils--concatenate-lines expected))))))

(describe "indentation"

  (describe "on a blank line"

    (it "resets after complete command"
      (lean-indent-test '("variable {a : ℝ}" "  |")
                        '("variable {a : ℝ}" "")))

    (it "increases after \"by\""
      (lean-indent-test '("theorem {a : ℝ} : a = a := by" "|")
                        '("theorem {a : ℝ} : a = a := by" "  ")))

    (it "increases after nested \"by\""
      (lean-indent-test '("example : Nat := by"
                          "  have : Type := by"
                          "|")
                        '("example : Nat := by"
                          "  have : Type := by"
                          "    ")))

    (it "increases after focus goal"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · sorry"
                          "|")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · sorry"
                          "    "))))

  (describe "in the middle of an expression"

    (it "resets after complete command"
      (lean-indent-test '("variable {a : ℝ}" "  |variable {b : ℝ}")
                        '("variable {a : ℝ}" "variable {b : ℝ}")))

    (it "increases after \"by\""
      (lean-indent-test '("theorem {a : ℝ} : a = a := by" "|rfl")
                        '("theorem {a : ℝ} : a = a := by" "  rfl")))

    (it "increases more for type signature"
      (lean-indent-test '("theorem {a : ℝ} :" "|a = a := by")
                        '("theorem {a : ℝ} :" "    a = a := by")))

    (it "increases after nested \"by\""
      (lean-indent-test '("example : Nat := by"
                          "  have : Type := by"
                          "|foo")
                        '("example : Nat := by"
                          "  have : Type := by"
                          "    foo")))

    (it "increases after focus goal"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  ·"
                          "|done")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  ·"
                          "    done"))
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · "        ; significant whitespace
                          "|done")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · "
                          "    done")))))

(provide 'lean-ts-test)
;;; lean-ts-test.el ends here
