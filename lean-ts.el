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

(defun lean-ts--node-is-cdot (node &rest _)
  (let ((type (treesit-node-type node)))
    (or (string-match-p "cdot" type)
        (and (string-match-p "apply" type)
             (thread-last
               (treesit-node-child-by-field-name node "name")
               (treesit-node-type)
               (string-match-p "cdot"))))))

(defconst lean-ts-after-indent-rules
  '(
    ((node-is "declaration") no-indent lean-ts-basic-offset)
    ((node-is "variable") no-indent 0)
    (lean-ts--node-is-cdot no-indent lean-ts-basic-offset)
    ((and (node-is "have")
          (lambda (node parent &rest _)
            (when-let* ((body (or (treesit-node-child-by-field-name node "body")
                                  (treesit-node-child-by-field-name parent "body"))))
              (thread-last body
                           (treesit-node-type)
                           (string-match-p "tactics")))))
     no-indent lean-ts-basic-offset)
    ((parent-is "tactics") no-indent 0))
  "Rules for `lean-mode' indentation of an empty line.

Assumes (NODE PARENT BOL) are calculated for the previous non-blank line.")

(defconst lean-ts-indent-rules
  '(
    (no-node column-0 lean-ts--empty-line-offset)
    ((field-is "type") parent lean-ts--double-offset)
    ((match nil "tactics" nil 1 1) grand-parent lean-ts-basic-offset)
    ;; malformed cdot_tactic
    ;; TODO: double check this against (cdot + 2) expressions
    ((and (parent-is "apply\\|tactics") (lambda (node &rest _)
                                          (thread-last
                                            (treesit-node-prev-sibling node)
                                            (treesit-node-type)
                                            (string-match-p "cdot"))))
     prev-sibling lean-ts-basic-offset)
    ((parent-is "tactics") prev-sibling 0)
    ((parent-is "module") column-0 0))
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
