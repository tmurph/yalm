;;; lean-mode-test.el --- Unit tests for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

(require 'lean-mode)

(require 'buttercup)

(defun lean-comment-dwim-test (input expected)
  (with-temp-buffer
    (let ((indent-tabs-mode nil)
          (comment-column 20))
      (lean-mode)
      (insert-and-set-point input)
      (call-interactively #'lean-comment-dwim)
      (should (string= (buffer-string) (concatenate-lines expected))))))

(defun lean-comment-dwim-region-test (input expected)
  (with-temp-buffer
    (let ((indent-tabs-mode nil)
          (comment-column 20)
          (transient-mark-mode t))
      (lean-mode)
      (insert-and-mark-region input)
      (call-interactively #'lean-comment-dwim)
      (should (string= (buffer-string) (concatenate-lines expected))))))

(describe "`lean-comment-dwim'"

  (it "inserts a plain comment"
    (lean-comment-dwim-test "#check 2 + 2"
                            "#check 2 + 2        -- "))

  (it "inserts a plain comment at the comment column"
    (with-temp-buffer
      (let ((indent-tabs-mode nil)
            (comment-column 35))
        (lean-mode)
        (insert-and-set-point "#check 2 + 2")
        (call-interactively #'lean-comment-dwim)
        (should (string= (buffer-string) "#check 2 + 2                       -- ")))))

  (it "inserts a plain comment from within text"
    (lean-comment-dwim-test "#check| 2 + 2"
                            "#check 2 + 2        -- "))

  (it "inserts a module comment"
    (lean-comment-dwim-test '("|"
                              "import Mathlib")
                            '("/-!"
                              ""
                              "-/"
                              "import Mathlib")))

  (it "inserts a declaration comment"
    (lean-comment-dwim-test '("variable {E : Type*}"
                              "|"
                              "def cone (s : Set E) (x : E) :=")
                            '("variable {E : Type*}"
                              "/--  -/"
                              "def cone (s : Set E) (x : E) :=")))

  (it "comments a region"
    (lean-comment-dwim-region-test "#check 2 + 2"
                                   "-- #check 2 + 2"))

  (it "uncomments a region"
    (lean-comment-dwim-region-test "-- #check 2 + 2"
                                   "#check 2 + 2"))

  (it "comments out a marked region"
    (lean-comment-dwim-region-test '("let C₁ := 3"
                                     "|have hC₁ := sorry"
                                     "have hC₁' := sorry|"
                                     "let C₂ := 4")
                                   '("let C₁ := 3"
                                     "-- have hC₁ := sorry"
                                     "-- have hC₁' := sorry"
                                     "let C₂ := 4"))))

(provide 'lean-mode-test)
;;; lean-mode-test.el ends here
