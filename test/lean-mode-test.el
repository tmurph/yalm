;;; lean-mode-test.el --- Unit tests for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

(require 'lean-mode)

(require 'ert-x)

(require 'assess)
(require 'buttercup)

(defun insert-and-set-point (&rest lines)
  "Insert LINES separated by newlines.  Leave point after the insert.

If LINES contains a \"|\" then it will be removed and point will be
positioned where it was."
  (let ((limit (save-excursion
                 (insert (mapconcat #'identity lines "\n"))
                 (point))))
    (when (re-search-forward "|" limit 'move)
      (backward-delete-char))))

(describe "`lean-comment-dwim'"
  :var (initial expected)

  (it "inserts a plain comment"
    (ert-with-test-buffer (:name "foo")
      (lean-mode)
      (insert-and-set-point "#check 2 + 2")
      (call-interactively #'lean-comment-dwim)
      (should (string= (buffer-string) "#check 2 + 2			-- ")))))


(provide 'lean-mode-test)
;;; lean-mode-test.el ends here
