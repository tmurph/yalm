;;; lean-ts.el --- Treesitter setup for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This library defines settings for experimental treesitter support.

;;; Code:

(require 'treesit)

(defconst lean-ts-font-lock-settings
  (treesit-font-lock-rules
   :default-language 'lean

   :feature 'comment
   `([(comment) (line_comment)]
     @font-lock-comment-face
     [(cmd_module_doc) (documentation)]
     @font-lock-doc-face))
  "The tree-sitter font lock settings for lean.")

;;;###autoload
(defun lean-ts-setup ()
  (setq-local treesit-font-lock-settings lean-ts-font-lock-settings)
  (setq-local treesit-font-lock-feature-list '((comment)))

  (setq-local treesit-primary-parser (treesit-parser-create 'lean))
  (treesit-major-mode-setup))

(provide 'lean-ts)
;;; lean-ts.el ends here
