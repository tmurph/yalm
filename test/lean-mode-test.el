;;; lean-mode-test.el --- Unit tests for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

(require 'lean-mode)

(require 'buttercup)

(defun insert-and-set-point (&rest lines)
  "Insert LINES separated by newlines.  Leave point after the insert.

If LINES contains a \"|\" then it will be removed and point will be
positioned where it was."
  (let ((limit (save-excursion
                 (insert (mapconcat #'identity lines "\n"))
                 (point))))
    (when (re-search-forward "|" limit 'move)
      (delete-char -1))))

(defun lean-comment-dwim-test (input expected)
  (with-temp-buffer
    (let ((indent-tabs-mode nil)
          (comment-column 20))
      (lean-mode)
      (apply #'insert-and-set-point
             (if (listp input) input (list input)))
      (call-interactively #'lean-comment-dwim)
      (should (string= (buffer-string)
                       (if (listp expected)
                           (mapconcat #'identity expected "\n")
                         expected))))))

(defun insert-and-mark-region (&rest lines)
  "Insert LINES separated by newlines.  Mark inserted lines.

If LINES contains a balanced pair of \"|\" characters then they will be
removed and the region between them will be marked."
  (let ((limit (save-excursion
                 (insert (mapconcat #'identity lines "\n"))
                 (point)))
        beg end)
    (if (null (re-search-forward "|" limit t))
        (setq beg (point) end limit)
      (delete-char -1)
      (setq beg (point))
      (re-search-forward "|" limit)
      (delete-char -1)
      (setq end (point)))
    (push-mark end 'nomsg)
    (goto-char beg)
    (setq mark-active t)))

(defun lean-comment-dwim-region-test (input expected)
  (with-temp-buffer
    (let ((indent-tabs-mode nil)
          (comment-column 20)
          (transient-mark-mode t))
      (lean-mode)
      (apply #'insert-and-mark-region
             (if (listp input) input (list input)))
      (call-interactively #'lean-comment-dwim)
      (should (string= (buffer-string)
                       (if (listp expected)
                           (mapconcat #'identity expected "\n")
                         expected))))))

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
