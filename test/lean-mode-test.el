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

(describe "`lean-comment-dwim'"

  (it "inserts a plain comment"
    (with-temp-buffer
      (let ((indent-tabs-mode nil))
        (lean-mode)
        (insert-and-set-point "#check 2 + 2")
        (call-interactively #'lean-comment-dwim)
        (should (string= (buffer-string) "#check 2 + 2                    -- ")))))

  (it "inserts a plain comment at the comment column"
    (with-temp-buffer
      (let ((indent-tabs-mode nil)
            (comment-column 20))
        (lean-mode)
        (insert-and-set-point "#check 2 + 2")
        (call-interactively #'lean-comment-dwim)
        (should (string= (buffer-string) "#check 2 + 2        -- ")))))

  (it "inserts a plain comment from within text"
    (with-temp-buffer
      (let ((indent-tabs-mode nil)
            (comment-column 20))
        (lean-mode)
        (insert-and-set-point "#check| 2 + 2")
        (call-interactively #'lean-comment-dwim)
        (should (string= (buffer-string) "#check 2 + 2        -- "))))))


(provide 'lean-mode-test)
;;; lean-mode-test.el ends here
