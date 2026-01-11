;;; lean-mode.el --- Yet another Major mode for Lean  -*- lexical-binding: t; -*-

;; Copyright © 2013-2014 Microsoft Corp.
;; Copyright © 2014-2015 Soonho Kong
;; Copyright © 2024 Free Software Foundation, Inc.
;; Copyright © 2025 Mekeor Melire
;; Copyright © 2026 Trevor Murphy

;; Author:
;;   Adam Topaz <topaz@ualberta.ca>
;;   Akira Komamura <akira.komamura@gmail.com>
;;   Bao Zhiyuan <bzy_sustech@foxmail.com>
;;   Daniel Selsam <daniel.selsam@protonmail.com>
;;   Gabriel Ebner <gebner@gebner.org>
;;   Henrik Böving <hargonix@gmail.com>
;;   Hongyu Ouyang  <oyhy0214@163.com>
;;   Jakub Bartczuk <bartczukkuba@gmail.com>
;;   Leonardo de Moura <leonardo@microsoft.com>
;;   Mauricio Collares <mauricio@collares.org>
;;   Mekeor Melire <mekeor@posteo.de>
;;   Philip Kaludercic <philipk@posteo.net>
;;   Richard Copley <buster@buster.me.uk>
;;   Sebastian Ullrich <sebasti@nullri.ch>
;;   Siddharth Bhat <siddu.druid@gmail.com>
;;   Simon Hudon <simon.hudon@gmail.com>
;;   Soonho Kong <soonhok@cs.cmu.edu>
;;   Tomáš Skřivan <skrivantomas@seznam.cz>
;;   Wojciech Nawrocki <wjnawrocki@protonmail.com>
;;   Yael Dillies <yael.dillies@gmail.com>
;;   Yury G. Kudryashov <urkud@urkud.name>
;; Keywords: languages
;; Maintainer: Mekeor Melire <mekeor@posteo.de>
;; Package-Requires: ((emacs "29.1"))
;; SPDX-License-Identifier: Apache-2.0 AND GPL-3.0-only
;; URL: https://codeberg.org/mekeor/nael
;; Version: 0.7.1

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; `lean-mode' is a major mode for Lean.

;; YALM is a combination of my favorite parts of:
;; Lean4-Mode: https://github.com/leanprover-community/lean4-mode
;; nael: https://codeberg.org/mekeor/nael
;; lean-ts-mode: https://github.com/lua-vr/lean-ts-mode

;;; Code:

(require 'jsonrpc)
(require 'project)
(require 'rx)
(require 'seq)
(require 'lean-syntax)

;; forward declarations
(defvar lsp-managed-mode-hook)
(declare-function flymake-goto-next-error "flymake"
                  (&optional n filter interactive))
(declare-function lsp "lsp-mode" (&optional arg))

(defgroup lean nil
  "Major mode for Lean4 programming language and theorem prover."
  :prefix "lean-"
  :group 'languages)

(defcustom lean-use-treesitter nil
  "Whether to use experimental font lock engine.  Requires an installation
of treesitter and the lean grammar.

If you change this setting you will need to restart the major mode."
  :type 'boolean)

;;;; Auxiliary Functions and Commands:

(defun nael-comment-insert ()
  "`comment-insert-comment-function' for `nael-mode'."
  (interactive)
  (if (save-excursion (beginning-of-line)
                      (looking-at-p "[[:blank:]]*$"))
      (progn
        ;; Respect users who set `comment-start' to "--".
        (insert comment-start " ")
        ;; Respect users who set `comment-end' to "".
        (unless (length= comment-end 0)
          (save-excursion
            (insert " " comment-end))))
    (end-of-line)
    (unless (looking-back "[[:blank:]]" (1- (point)))
      (insert " "))
    (insert "-- ")))

(defun nael-fill-paragraph (&optional justify)
  "Fill comment paragraph at point.  Maybe JUSTIFY."
  (interactive)
  (when (save-excursion (nth 4 (syntax-ppss (point))))
    (let* ((com-beg (save-excursion
                      (re-search-backward "[/-]-" nil t)
                      (match-beginning 0)))
           (multi (eq (char-after com-beg) ?/)))
      (if multi
          (let* ((par-beg (save-excursion
                            (re-search-backward paragraph-start nil t)
                            (match-beginning 0)))
                 (beg (max com-beg par-beg))
                 (com-end (if multi "-/" "$"))
                 (com-end (save-excursion
                            ;; If cursor is at -|/, then move to |-/,
                            ;; so that `re-search-forward' can locate
                            ;; comment ending.
                            (and (eq (char-before) ?-)
                                 (eq (char-after) ?/)
                                 (backward-char))
                            (re-search-forward com-end nil t)
                            (match-end 0)))
                 (par-end (save-excursion
                            (search-forward paragraph-separate nil t)
                            (match-end 0)))
                 (end (min com-end par-end)))
            (fill-region beg end justify))
        ;; `fill-comment-paragraph' fills prefixed comments well, when
        ;; configured correctly.
        (let ((comment-start "--") (comment-end ""))
          ;; For some reason, "" is used as fill-prefix by
          ;; `fill-comment-paragraph' when point is at --|.  Avoid
          ;; this misbehavior by moving point forward one char.
          (and (not (eolp))
               (looking-back "--" (max (- (point) 2) (point-min)))
               (forward-char))
          (fill-comment-paragraph justify))))))

;; TODO: Both `nael-navigation-defun-beginning' and
;; `nael-navigation-defun-name' currently lack support for `mutual'
;; blocks, i.e. mutually recursive definitions.

(defun nael-navigation-defun-end ()
  "`end-of-defun-function' for `nael-mode'."
  (interactive)
  (when (re-search-forward nael-syntax-definition nil t)
    (goto-char (match-beginning 0))))

(defun nael-navigation-defun-beginning ()
  "`beginning-of-defun-function' for `nael-mode'."
  (interactive)
  (re-search-backward nael-syntax-definition nil t))

(defun nael-navigation-defun-name ()
  "`add-log-current-defun-function' for `nael-mode'."
  (save-excursion
    (when (nael-navigation-defun-beginning)
      (forward-symbol 1)
      (forward-whitespace 1)
      (symbol-at-point))))

(defvar nael-imenu-generic-expression
  (list (list nil nael-syntax-definition 4))
  "`imenu-generic-expression' for `nael-mode'.")

;;;; Preparation:

;; Our goal is to avoid loading `nael-abbrev' / `abbrev', `nael-eglot'
;; / `eglot' and `nael-lsp' / `lsp', until the user calls one of their
;; autoloaded commands.  We are lucky that `post-self-insert-hook' is
;; strictly loaded and that `eglot-server-initialized-hook',
;; `eglot-managed-mode-hook' as well as `lsp-managed-mode-hook' are
;; all initialized to nil, in usual Emacs manner.  Thus, it's fine to
;; call `add-hook' on them, even if they have not been defined as
;; variables yet.

;; We could introduce a hook, with all of
;; `nael-prepare-{abbrev,eglot,lsp}' being default members of it,
;; which we could run in the beginning of the definition-body of
;; `nael-mode'.  As mentioned, though, it's uncommon in Emacs to have
;; hooks initialized with non-nil values and some common functions
;; like `add-hook' rely on this practice.  Thus, we use boolean flags
;; instead.

(defcustom nael-prepare-abbrev t
  "Whether `abbrev-mode' should be prepared for `nael-mode'."
  :type 'boolean
  :group 'nael)

(defun nael-prepare-abbrev ()
  "Prepare `abbrev-mode' for `nael-mode'.

Expand symbol-including abbreviations when adequate character inserted."
  (interactive)
  (when nael-prepare-abbrev
    (add-hook 'abbrev-mode-hook
              #'nael-abbrev-configure nil 'local)))

(defcustom nael-prepare-eglot t
  "Whether `eglot' should be prepared for `nael-mode'."
  :type 'boolean
  :group 'nael)

(defun nael-prepare-eglot ()
  "Prepare `eglot' for `nael-mode'."
  (interactive)
  (when nael-prepare-eglot
    ;; We want to add an entry to `eglot-server-programs' but we want
    ;; to avoid stricly loading `eglot' here.  Unfortunately, Eglot
    ;; doesn't offer any hook that'd be run before it accesses
    ;; `eglot-server-programs'.  We have no choice but
    ;; `with-eval-after-load'.
    (with-eval-after-load 'eglot
      (require 'nael-eglot))
    (add-hook 'eglot-server-initialized-hook
              #'nael-eglot-configure-when-initialized nil 'local)
    (add-hook 'eglot-managed-mode-hook
              #'nael-eglot-configure-when-managed nil 'local)))

(defcustom nael-prepare-lsp t
  "Whether `lsp-mode' should be prepared for `nael-mode'."
  :type 'boolean
  :group 'nael)

(defun nael-prepare-lsp ()
  "Prepare `lsp-mode' for `nael-mode'.

Note that if you call `lsp-mode' inside a buffer majored by `nael-mode',
it is unguardedly assumed that you have `nael-lsp' package installed and
that either you have `nael-lsp' loaded, or `nael-lsp-autoloads', or at
least evaluated an autoload statement for
`nael-lsp-configure-when-managed'."
  (interactive)
  (when nael-prepare-lsp
    ;; The `lsp-language-id-configuration' variable needs to be
    ;; modified so early, that hooks don't work.  We have no choice
    ;; but `with-eval-after-load'.
    (with-eval-after-load 'lsp-mode
      (require 'nael-lsp))
    (add-hook 'lsp-managed-mode-hook
              #'nael-lsp-configure-when-managed nil 'local)))

;; Let's use the same interface (a configure-function, a
;; prepare-option and -function) for Flymake too because we don't load
;; or invoke it in `nael-mode' itself.

(defun nael-flymake-configure ()
  "Use Flymake to jump to errors."
  (interactive)
  (setq-local next-error-function
              #'flymake-goto-next-error))

(defcustom nael-prepare-flymake t
  "Whether `flymake-mode' should be prepared for `nael-mode'."
  :type 'boolean
  :group 'nael)

(defun nael-prepare-flymake ()
  "Prepare `flymake-mode' for `nael-mode'."
  (interactive)
  (when nael-prepare-flymake
    (add-hook 'flymake-mode-hook
              #'nael-flymake-configure nil 'local)))

;;;; Mode:

(defcustom nael-mode-hook nil
  "Hook run when entering `nael-mode'."
  :options '(abbrev-mode eglot-ensure imenu-add-menubar-index lsp)
  :type 'hook
  :group 'nael)

(defvar-keymap nael-mode-map
  "<remap> <display-local-help>" #'eldoc-doc-buffer
  "C-c C-a" #'abbrev-mode
  "C-c C-c" #'project-compile
  "C-c C-e" #'eglot
  "C-c C-k" #'nael-abbrev-help)

;;;###autoload
(define-derived-mode nael-mode prog-mode "Nael"
  "Major mode for Lean.

\\{nael-mode-map}"
  ;; Preparations:
  (nael-prepare-abbrev)
  (nael-prepare-eglot)
  (nael-prepare-lsp)
  ;; Navigation:
  (setq-local add-log-current-defun-function
              #'nael-navigation-defun-name)
  (setq-local beginning-of-defun-function
              #'nael-navigation-defun-beginning)
  (setq-local end-of-defun-function
              #'nael-navigation-defun-end)
  ;; Paragraphs and filling:
  (setq-local paragraph-start
              "[[:blank:]]*$")
  (setq-local paragraph-separate
              "[[:blank:]]*$")
  (setq-local fill-paragraph-function
              #'nael-fill-paragraph)
  ;; Comments:
  (setq-local comment-end
              "-/")
  (setq-local comment-end-skip
              "[[:space:]]*-/")
  (setq-local comment-insert-comment-function
              #'nael-comment-insert)
  (setq-local comment-padding
              1)
  (setq-local comment-quote-nested ;; Comments may be nested.
              nil)
  (setq-local comment-start
              "/-")
  (setq-local comment-start-skip
              "/-[[:space:]]*")
  (setq-local comment-style
              'multi-line)
  (setq-local comment-use-syntax
              t)
  (setq-local parse-sexp-ignore-comments
              t)
  ;; Font-lock:
  (setq-local font-lock-defaults
              nael-font-lock-defaults)
  ;; Compile:
  (setq-local compilation-mode-font-lock-keywords
              nil)
  (setq-local compile-command
              "lake build ")
  ;; Imenu:
  (setq-local imenu-generic-expression
              nael-imenu-generic-expression)
  ;; Flymake:
  (nael-flymake-configure))

;; Lean language specification requires UTF-8 encoding.
(modify-coding-system-alist 'file "\\.lean\\'" 'utf-8)

;;;; Association:

;;;###autoload
(add-to-list 'auto-mode-alist
             (cons "\\.lean\\'" 'nael-mode))

(with-eval-after-load 'org-src
  (add-to-list 'org-src-lang-modes
               (cons "lean" 'nael)))

;; If the code that requires `markdown-mode' grows, we will extract it
;; into a new package that depends on it.  But a single expression is
;; not worth a package.
(with-eval-after-load 'markdown-mode
  (add-to-list 'markdown-code-lang-modes
               (cons "lean" 'nael-mode)))

(provide 'nael)

;;; nael.el ends here
