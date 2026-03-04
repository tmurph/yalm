;;; utils.el --- Utilities for unit tests            -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Trevor Murphy

;; Author: Trevor Murphy <trevor.m.murphy@gmail.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Don't include a provide in this "library", because we want to
;; discourage loading it into running instances (because the names are
;; not sanitized).  Instead, the test runner should load it
;; automatically, or with a direct "-l utils" invocation at the CLI.

;;; Code:

(defun concatenate-lines (lines)
  (mapconcat #'identity (if (listp lines) lines (list lines)) "\n"))

(defun insert-and-set-point (lines)
  "Insert LINES separated by newlines.  Leave point after the insert.

If LINES contains a \"|\" then it will be removed and point will be
positioned where it was."
  (let ((limit (save-excursion
                 (insert (concatenate-lines lines))
                 (point))))
    (when (re-search-forward "|" limit 'move)
      (delete-char -1))))

(defun insert-and-mark-region (lines)
  "Insert LINES separated by newlines.  Mark inserted lines.

If LINES contains a balanced pair of \"|\" characters then they will be
removed and the region between them will be marked."
  (let ((limit (save-excursion
                 (insert (concatenate-lines lines))
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

;;; utils.el ends here
