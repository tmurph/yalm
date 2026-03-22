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
      (expect (buffer-string) :to-equal
              (lean-utils--concatenate-lines expected)))))

(describe "indentation"

  (describe "on a blank line"

    (it "resets after complete command"
      (lean-indent-test '("variable {a : ℝ}" "  |")
                        '("variable {a : ℝ}" "")))

    (it "increases after \"by\""
      (lean-indent-test '("theorem {a : ℝ} : a = a := by" "|")
                        '("theorem {a : ℝ} : a = a := by" "  ")))

    (it "remains the same within a tactics block"
      (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "|")
                        '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "    ")))

    (it "increases after nested \"by\""
      (lean-indent-test '("example : Nat := by"
                          "  have : Type := by"
                          "|")
                        '("example : Nat := by"
                          "  have : Type := by"
                          "    ")))

    (it "increases in a focus block"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · intro x y"
                          "|")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · intro x y"
                          "    ")))

    (it "does not increase after closing a goal"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "|")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "  ")))

    (it "increases in a proof term"
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ "
                          "|")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ "
                          "    "))
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "|")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "    "))))

  (describe "in the middle of an expression"

    (it "resets after complete command"
      (lean-indent-test '("variable {a : ℝ}"
                          "  |variable {b : ℝ}")
                        '("variable {a : ℝ}"
                          "variable {b : ℝ}")))

    (it "increases after \"by\""
      (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                          "|rfl")
                        '("theorem {a : ℝ} : a = a := by"
                          "  rfl")))

    (it "remains the same in a tactics block"
      (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "      |sorry")
                        '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "    sorry")))

    (it "increases for proof body"
      (lean-indent-test '("theorem {a : ℝ} : a = a :="
                          "|by")
                        '("theorem {a : ℝ} : a = a :="
                          "  by"))
      (lean-indent-test '("def Foo :="
                          "|∀ y ∈ s, f (y - x) ≤ 0")
                        '("def Foo :="
                          "  ∀ y ∈ s, f (y - x) ≤ 0")))

    (it "increases more for proof header"
      (lean-indent-test '("theorem {a : ℝ} :"
                          "|a = a := by")
                        '("theorem {a : ℝ} :"
                          "    a = a := by"))
      (lean-indent-test '("theorem {a : ℝ}"
                          "|: a = a := by")
                        '("theorem {a : ℝ}"
                          "    : a = a := by"))
      ;; (lean-indent-test '("lemma Bar : ∃ f,"
      ;;                     "  |∃ p, f p ≠ 0 := by"
      ;;                     "  exact trivial")
      ;;                   '("lemma Bar : ∃ f,"
      ;;                     "    ∃ p, f p ≠ 0 := by"
      ;;                     "  exact trivial"))
      )

    (it "correctly handles proof header and body"
      (lean-indent-test '("theorem {a : ℝ} :"
                          "    a = a :="
                          "|by")
                        '("theorem {a : ℝ} :"
                          "    a = a :="
                          "  by")))

    (it "increases after nested \"by\""
      (lean-indent-test '("example : Nat := by"
                          "  have : Type := by"
                          "|foo")
                        '("example : Nat := by"
                          "  have : Type := by"
                          "    foo")))

    (it "increases in a focus block"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · -- a comment keeps the block open"
                          "  |done")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · -- a comment keeps the block open"
                          "    done")))

    (it "does not increase after closing a goal"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "    |intro x y"
                          "  done")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "  intro x y"
                          "  done")))

    (it "increases inside a function application"
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦"
                          "|g x")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦"
                          "    g x"))
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "|x")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "    x")))))

(provide 'lean-ts-test)
;;; lean-ts-test.el ends here
