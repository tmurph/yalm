;;; lean-treesitter.el --- Treesitter font lockinkg for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This library defines settings for treesitter.  This is incompatible
;; with `lean-font-lock'.

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

(provide 'lean-treesitter)
;;; lean-treesitter.el ends here
