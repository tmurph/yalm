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

(defvar lean-ts-indent-presets
  (list (cons 'first-child-is
              (lambda (type &optional named)
                (lambda (node &rest _)
                  (string-match-p
                   type (thread-first node
                                      (treesit-node-child 0 named)
                                      (treesit-node-type)
                                      (or ""))))))
        (cons 'nth-child-is
              (lambda (type n &optional named)
                (lambda (node &rest _)
                  (string-match-p
                   type (thread-first node
                                      (treesit-node-child n named)
                                      (treesit-node-type)
                                      (or ""))))))
        (cons 'prev-sibling-is
              (lambda (type &optional named)
                (lambda (node &rest _)
                  (string-match-p
                   type (thread-first node
                                      (treesit-node-prev-sibling named)
                                      (treesit-node-type)
                                      (or ""))))))
        ;; TODO: probably take this out, it's too complicated to ship.
        ;; you can just add it through your dotemacs
        ;; (cons 'ancestor-match
        ;;       (lambda
        ;;         (&optional node-type parent-type node-field
        ;;                    node-index-min node-index-max)
        ;;         (lambda (n &rest _)
        ;;           (treesit-parent-until
        ;;            n
        ;;            (lambda (node)
        ;;              (when-let* ((parent (treesit-node-parent node)))
        ;;                (and (pcase node-type
        ;;                       ('nil t)
        ;;                       ('null (null node))
        ;;                       (_ (string-match-p
        ;;                           node-type (or (treesit-node-type node) ""))))
        ;;                     (or (null parent-type)
        ;;                         (string-match-p
        ;;                          parent-type (treesit-node-type parent)))
        ;;                     (or (null node-field)
        ;;                         (string-match-p
        ;;                          node-field
        ;;                          (or (treesit-node-field-name node) "")))
        ;;                     (or (null node-index-min)
        ;;                         (>= (treesit-node-index node)
        ;;                             node-index-min))
        ;;                     (or (null node-index-max)
        ;;                         (<= (treesit-node-index node)
        ;;                             node-index-max)))))))))
        )
  "A list of indent rule presets.

These will be appended to `treesit-simple-indent-rules' during
indentation of Lean code.")

(defconst lean-ts-after-indent-rules
  '(
    ((or (node-is "declaration")
         (parent-is "declaration"))
     no-indent lean-ts-basic-offset)
    ;; TODO: should these non-declaration commands get bundled into a
    ;; generic "command" name?  like how tactics are now
    ((node-is "variable") no-indent 0)
    ((and (node-is "tactic")
          (first-child-is "have"))
     no-indent lean-ts-basic-offset)
    ((node-is "tactic") no-indent 0)
    ((and (node-is "focus_block")
          (first-child-is "close\\|sorry" t))
     no-indent 0)
    ((node-is "focus_block") no-indent lean-ts-basic-offset))
  "Rules for `lean-mode' indentation of an empty line.

Assumes (NODE PARENT BOL) are calculated for the previous non-blank line.")

(defconst lean-ts-indent-rules
  '(
    (no-node column-0 lean-ts--empty-line-offset)
    ((node-is "ERROR") column-0 lean-ts--empty-line-offset)
    ((parent-is "module") column-0 0)
    ((match nil "tactics" nil 1 1)      ; first tactic line
     grand-parent lean-ts-basic-offset)
    ((parent-is "tactics") prev-sibling 0)
    ((match nil "declaration" "body\\|proof") parent lean-ts-basic-offset)
    ((parent-is "declaration") parent lean-ts--double-offset)
    ;; TODO: probably take this out, it's too complicated to ship.  you
    ;; can just add it through your dotemacs
    ;; ((ancestor-match nil "declaration" "term") standalone-parent lean-ts--double-offset)
    ((and (parent-is "focus_block")
          (prev-sibling-is "close\\|sorry" t))
     parent 0)
    ((parent-is "focus_block") parent lean-ts-basic-offset)
    ((or (node-is "apply")
         (parent-is "apply"))
     prev-line lean-ts-basic-offset))
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

(defun treesit-indent-debug ()
  (print (buffer-string))
  (let* ((smallest-node (save-excursion
                          (forward-line 0)
                          (skip-chars-forward " \t")
                          (treesit-node-at (point)))))
    (print (treesit-node-parent smallest-node)))
  (let ((treesit-indent-function (lambda (&rest args) args)))
    (print (treesit--indent-1))))

;;;###autoload
(defun lean-ts-setup ()
  ;; (advice-add 'treesit-indent :before #'treesit-indent-debug)

  (when (treesit-ready-p 'lean)
    (setq-local treesit-simple-indent-rules (list (cons 'lean lean-ts-indent-rules)))
    (setq-local treesit-primary-parser (treesit-parser-create 'lean))
    (setq-local treesit-simple-indent-presets
                (append (default-value 'treesit-simple-indent-presets)
                        lean-ts-indent-presets))
    (treesit-major-mode-setup)))

(provide 'lean-ts)
;;; lean-ts.el ends here
