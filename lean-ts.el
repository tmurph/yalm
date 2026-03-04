;;; lean-ts.el --- Treesitter setup for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This library defines settings for experimental treesitter support.

;;; Code:

(require 'treesit)

(defcustom lean-ts-basic-offset 2
  "Offset used by tree-sitter for indentation in `lean-mode' buffers."
  :type 'integer
  :group 'lean)

(defconst lean-ts-indent-rules
  '((lean
     (no-node parent lean-ts-basic-offset))))

;;;###autoload
(defun lean-ts-setup ()
  (when (treesit-ready-p 'lean)
    (setq-local treesit-simple-indent-rules lean-ts-indent-rules)
    (setq-local treesit-primary-parser (treesit-parser-create 'lean))
    (treesit-major-mode-setup)))

(provide 'lean-ts)
;;; lean-ts.el ends here
