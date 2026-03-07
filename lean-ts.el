;;; lean-ts.el --- Treesitter setup for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This library defines settings for experimental treesitter support.

;;; Code:

(require 'treesit)

;;;; Indentation

(defcustom lean-ts-basic-offset 2
  "Offset used by tree-sitter for indentation in `lean-mode' buffers."
  :type 'integer
  :group 'lean)

(defun lean-ts--double-offset (&rest _)
  (* 2 lean-ts-basic-offset))

(defconst lean-ts-after-indent-rules
  '(
    ((node-is "declaration") no-indent lean-ts-basic-offset)
    ((node-is "variable") no-indent 0)
    ((and (node-is "apply")
          (lambda (node &rest _)
            (thread-last "name"
                         (treesit-node-child-by-field-name node)
                         (treesit-node-type)
                         (string-match-p "cdot"))))
     no-indent lean-ts-basic-offset)
    ((and (node-is "have")
          (lambda (_ parent &rest _)
            (thread-last "body"
                         (treesit-node-child-by-field-name parent)
                         (treesit-node-type)
                         (string-match-p "tactics"))))
     no-indent lean-ts-basic-offset)
    ((parent-is "tactics") no-indent lean-ts-basic-offset))
  "Rules for `lean-mode' indentation of a subsequent empty line.")

(defconst lean-ts-indent-rules
  '(
    ((field-is "type") parent lean-ts--double-offset)
    ((parent-is "tactics") grand-parent lean-ts-basic-offset)
    (no-node column-0 lean-ts--empty-line-offset))
  "Rules for `lean-mode' indentation.")

(defun lean-ts--empty-line-offset (_node _parent bol &rest _)
  (let ((treesit-simple-indent-rules (list (cons 'lean lean-ts-after-indent-rules))))
    (save-excursion
      (goto-char bol)
      (skip-chars-backward " \t\n")
      (pcase-let ((`(,anchor . ,offset) (treesit--indent-1)))
        (when (and anchor offset)
          (+ (save-excursion (goto-char anchor) (current-column))
             offset))))))

;;;###autoload
(defun lean-ts-setup ()
  (when (treesit-ready-p 'lean)
    (setq-local treesit-simple-indent-rules (list (cons 'lean lean-ts-indent-rules)))
    (setq-local treesit-primary-parser (treesit-parser-create 'lean))
    (treesit-major-mode-setup)))

(provide 'lean-ts)
;;; lean-ts.el ends here
