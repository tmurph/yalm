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
(require 'lean-font-lock)
(require 'lean-treesitter)

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

;;;; Utility Functions

;;;; Comments

(defconst lean--line-comment-region-alist
  '((comment-start . "-- ") (comment-end . "") (comment-style . indent))
  "Make `comment-region' wrap a region with line comments.")

(defconst lean--section-comment-region-alist
  '((comment-start . "/-!") (comment-end . "-/") (comment-style . extra-line))
  "Make `comment-region' wrap a region with a module / section block comment.")

(defconst lean--declaration-comment-region-alist
  '((comment-start . "/--") (comment-end . "-/") (comment-style . extra-line))
  "Make `comment-region' wrap a region with a declaration block comment.")

(defun lean--set-comment-variables ()
  (setq-local comment-start "-- ")
  (setq-local comment-start-skip "\\(?:--\\|/-!?\\)[[:space:]]*")
  (setq-local comment-end "")
  (setq-local comment-end-skip "[[:space:]]*\\(?:-/\\|\\s>\\)")
  (setq-local comment-padding 1)
  (setq-local comment-insert-comment-function #'lean-insert-comment)
  (setq-local comment-quote-nested nil)
  (setq-local comment-style 'indent)
  (setq-local comment-use-syntax t)
  (setq-local parse-sexp-ignore-comments t))

;;; why isn't there a builtin for this already?
;;; for now just reuse evil, but need a better long term solution
(defalias 'lean--in-comment-p #'evil-in-comment-p)

;;; TODO: unit test for this
(defun lean--comment-current-alist ()
  "Detect settings for comment at point.  Nil if no comment."
  (save-excursion
    ;; want to use `comment-beginning' here, but it returns nil if point
    ;; is actually on the comment starter.  boo.  I'm currently
    ;; leveraging `evil-in-comment-p' for my in-comment-p, and evil's
    ;; just so happens to work in this case + returns the start position.
    ;;
    ;; so that's neat for now, but you're gonna need to do something
    ;; about that eventually.
    (when-let ((pos (lean--in-comment-p)))
      (goto-char pos)
      (catch :found
        (dolist (alist (list lean--line-comment-region-alist
                             lean--block-comment-region-alist
                             lean--section-comment-region-alist
                             lean--declaration-comment-region-alist))
          (when (looking-at-p (alist-get 'comment-start alist))
            (throw :found alist)))))))

;;; TODO: unit test for this
;;; NOTE: just use `comment-beginning' to work out what's there?
;;; TODO: get important strings from the variable alists?
(defun lean--comment-replace-alist ()
  "Settings to use when replacing an empty comment.  Nil for no replace."
  (or (and (save-excursion
             (beginning-of-line)
             (looking-at-p (rx (zero-or-more space)
                               "--"
                               (zero-or-more space)
                               eol)))
           ;; empty line comment -> empty block comment
           lean--block-comment-region-alist)
      (and (save-excursion
             (skip-chars-forward " \t\n")
             (looking-at-p "-/"))
           (save-excursion
             (skip-chars-backward " \t\n")
             ;; unsure why, but when looking- functions fail to match
             ;; they don't set (match-string 0) to nil.  so gotta use
             ;; this construct to decide match vs no-match.  am I doing
             ;; something wrong?
             (when (looking-back "/-\\(.\\)?" (line-beginning-position))
               (pcase (match-string 1)
                 ;; module / section comment -> empty line comment
                 ("!" lean--line-comment-region-alist)
                 ;; declaration comment -> empty line comment
                 ("-" lean--line-comment-region-alist)
                 ;; block comment -> section or declaration comment
                 ((pred null)
                  ;; is the following line a declaration?
                  (skip-chars-forward " \t\n")
                  (forward-line 1)
                  (if (looking-at-p lean-declarations-regexp)
                      lean--declaration-comment-region-alist
                    lean--section-comment-region-alist))))))))

(defun lean--comment-insert-alist ()
  "Settings to use when inserting an empty comment."
  (or (and (save-excursion (skip-chars-backward " \t\n")
                           (bobp))
           ;; top level
           lean--section-comment-region-alist)
      (and (save-excursion (forward-line 1)
                           (looking-at-p lean-declarations-regexp))
           lean--declaration-comment-region-alist)
      lean--line-comment-region-alist))

(defun lean--comment-dwim-with-alist (extra-alist)
  (let-alist extra-alist
    (let ((comment-start (or .comment-start comment-start))
          (comment-end (or .comment-end comment-end))
          (comment-style (or .comment-style comment-style)))
      (call-interactively #'comment-dwim))))

;;; TODO: unit test this
(defun lean-comment-dwim (arg)
  "Call the comment command you want (Do What I Mean).

This is like `comment-dwim', except this command will also rotate
through various block comment styles if called repeatedly."
  (interactive "*P")
  (cond
   ((use-region-p)
    ;; punt on region-specific logic for now
    (call-interactively #'comment-dwim))
   ((not (lean--in-comment-p))
    (lean--comment-dwim-with-alist (lean--comment-insert-alist)))
   ((lean--comment-replace-alist)       ; cond-let when available
    (let ((alist (lean--comment-replace-alist)))
      (comment-beginning)
      (comment-kill nil)
      (lean--comment-dwim-with-alist alist)))
   (t
    (lean--comment-dwim-with-alist (lean--comment-current-alist)))))

;;; NOTE: this is erroneously called from `commend-indent' when we're
;;; inside a block comment, so be ready for that case.
(defun lean-insert-comment ()
  "`comment-insert-comment-function' for `lean-mode'."
  (interactive)
  (cond
   ((save-excursion (beginning-of-line)
                    (looking-at-p "[[:blank:]]*$"))
    (pcase comment-style
      ('extra-line
       (insert comment-start "\n")
       (save-excursion (insert "\n" comment-end)))
      (_
       ;; Respect users who set `comment-start' to "--"
       (insert comment-start)
       (when (string-match-p "[^[:space:]]\\'" comment-start)
         (insert " "))
       (save-excursion
         (when (string-match-p "\\`[^[:space:]]" comment-end)
           (insert " "))
         (insert comment-end)))))
   ((save-excursion (beginning-of-line)
                    (lean--in-comment-p))
    ;; `comment-indent' called because it can't recognize block comments
    nil)
   (t
    (end-of-line)
    (unless (looking-back "[[:blank:]]" (1- (point)))
      (insert " "))
    (insert "-- "))))

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

;;;; Indentation

(defun lean--set-indent-variables ()
  (setq-local tab-width 2
              standard-indent 2
              indent-tabs-mode nil))

;;;; Navigation

;;;; Auxiliary Functions and Commands:

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
