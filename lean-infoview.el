;;; lean-infoview.el --- Infoview-like functionality for lean-mode  -*- lexical-binding: t; -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This file repurposes the eldoc API to publish infoview data from the
;; Lean server to a dedicated doc buffer.  We also define generic
;; methods for LSP backends to hook into.

;;; Code:

(require 'lean-mode)
(require 'lean-lsp)

(defgroup lean-infoview nil
  "Repurpose `eldoc' to publish Lean LSP server responses."
  :group 'lean
  :prefix "lean-infoview-")

(defface lean-infoview-section-face
  '((t (:inherit font-lock-function-name-face :weight bold)))
  "Face for section-headers of Lean infoview buffer."
  :group 'lean-infoview)

;;; from lean4-syntax.el
(defconst lean-infoview-font-lock-defaults
  (let ((new-entries
         `(;; Please add more after this:
           (,(rx (group (+ symbol-start (+ (or word (char ?₁ ?₂ ?₃ ?₄ ?₅ ?₆ ?₇ ?₈ ?₉ ?₀))) symbol-end (* white))) ":")
            (1 'font-lock-variable-name-face))
           (,(rx white ":" white)
            . 'font-lock-keyword-face)
           (,(rx "⊢" white)
            . 'font-lock-keyword-face)
           (,(rx "[" (group "stale") "]")
            (1 'font-lock-warning-face))
           (,(rx line-start "No Goal" line-end)
            . 'font-lock-constant-face)))
        (inherited-entries (car lean-font-lock-defaults)))
    `(,(-concat new-entries inherited-entries))))

(define-derived-mode lean-infoview-mode prog-mode "LeanI"
  "Major mode for the Lean Infoview buffer."
  (setq-local font-lock-defaults lean-infoview-font-lock-defaults))

(defvar lean-infoview--buffer-name "*Lean Infoview*"
  "Name of buffer that is used to fontify responses from the LSP server.")

(defun lean-infoview--goals (callback goals)
  (if (= (length goals) 0)
      ;; TODO: print the "goals accomplished" to an infoview buffer
      (funcall callback nil)
    (with-temp-buffer
      (let (goal start end)
        (with-demoted-errors "Error during fontlock: %s"
          (insert (propertize "Tactic state:\n" 'face
                              'lean-infoview-section-face)
                  "\n")
          (while goals
            (setq goal (pop goals))
            (insert "  ")
            (unless start (setq start (point-marker)))
            (insert goal)
            (unless end (setq end (point-marker)))
            (insert "\n\n"))
          (delay-mode-hooks (funcall 'lean-infoview-mode))
          (ignore-errors (font-lock-ensure)))
        (funcall callback (buffer-string)
                 :echo (buffer-substring start end))))))

(defun lean-infoview--term-goal (callback goal)
  (if (= (length goal) 0)
      (funcall callback nil)
    (with-temp-buffer
      (with-demoted-errors "Error during fontlock: %s"
        (insert (propertize "Expected type:\n" 'face
                            'lean-infoview-section-face)
                "\n")
        (insert "  " (eglot--format-markup goal))
        (delay-mode-hooks (funcall 'lean-infoview-mode))
        (ignore-errors (font-lock-ensure)))
      (funcall callback (buffer-string)
               :echo 'skip))))

(defun lean-infoview-goals (callback &rest _)
  "ElDoc documentation function for the plain goals.

ElDoc will provide CALLBACK.  See `eldoc-documentation-functions' for
instructions on using CALLBACK to provide documentation info.

The request target path is `$/lean/plainGoal' as documented here:
https://leanprover-community.github.io/mathlib4_docs/Lean/Data/Lsp/Extra.html#Lean.Lsp.PlainGoal"
  (lean-lsp--ensure-backend)
  (lean-lsp--request-async lean-lsp--backend :$/lean/plainGoal
                           #'lean-infoview--goals callback))

(defun lean-infoview-term-goal (callback &rest _)
  "ElDoc documentation function for the type of the term at point.

ElDoc will provide CALLBACK.  See `eldoc-documentation-functions' for
instructions on using CALLBACK to provide documentation info.

The request target path is `$/lean/plainTermGoal' as documented here:
https://leanprover-community.github.io/mathlib4_docs/Lean/Data/Lsp/Extra.html#Lean.Lsp.PlainTermGoal"
  (lean-lsp--ensure-backend)
  (lean-lsp--request-async lean-lsp--backend :$/lean/plainTermGoal
                           #'lean-infoview--term-goal callback))

(provide 'lean-infoview)
;;; lean-infoview.el ends here
