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
;; URL: https://github.com/tmurph/yalm
;; Version: 0.0.7

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

(require 'align)
(require 'eglot)
(require 'newcomment)
(require 'quail)

(require 'lean-lsp)

;;;; Autoloads and Forward Declarations

(autoload 'lean-ts-setup "lean-ts")
(defvar org-src-lang-modes)
(defvar markdown-code-lang-modes)

;;; Internal Variables

;;;; Customize Interface

(defcustom align-lean-rules-list
  '((lean-arrow
     (regexp . "\\(\\s-*\\)=>\\(\\s-*\\)")
     (group  . (1 2))))
  "Alignment rules for `lean-mode'.  See `align-rules-list' for more info."
  :type align-rules-list-type
  :group 'align
  :risky t)

(defgroup lean nil
  "Major mode for Lean4 programming language and theorem prover."
  :prefix "lean-"
  :group 'languages)

(defcustom lean-use-treesitter nil
  "Whether to use experimental treesitter support.  Requires an installation
of treesitter and the lean grammar.

Currently only supports (partial) font locking.

If you change this setting you will need to restart the major mode."
  :type 'boolean
  :set (lambda (sym val)
         (set-default sym val)
         (if val
             (add-hook 'lean-mode-hook #'lean-ts-setup)
           (remove-hook 'lean-mode-hook #'lean-ts-setup))))

(defcustom lean-use-lsp-mode nil
  "Whether to use experimental lsp-mode support.

Currently so experimental that we don't support anything."
  :type 'boolean)

;;;; Syntax:

(defconst lean-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; Matching parens
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\] ")[" st)
    (modify-syntax-entry ?\{ "(}" st)
    (modify-syntax-entry ?\} "){" st)

    ;; comment
    (modify-syntax-entry ?/ ". 14nb" st)
    (modify-syntax-entry ?- ". 123" st)
    (modify-syntax-entry ?\n ">" st)
    (modify-syntax-entry ?« "<" st)
    (modify-syntax-entry ?» ">" st)

    ;; Word constituent
    (dolist (it (list ?a ?b ?c ?d ?e ?f ?g ?h ?i ?j ?k ?l ?m ?n ?o ?p
                      ?q ?r ?s ?t ?u ?v ?w ?x ?y ?z ?A ?B ?C ?D ?E ?F
                      ?G ?H ?I ?J ?K ?L ?M ?N ?O ?P ?Q ?R ?S ?T ?U ?V
                      ?W ?X ?Y ?Z

                      ?0 ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9

                      ?α ?β ?γ ?δ ?ε ?ζ ?η ?θ ?ι ?κ ;;?λ ?μ ?ν ?ξ ?ο
                      ?π ?ρ ?ς ?σ ?τ ?υ ?φ ?χ ?ψ ?ω

                      ?ϊ ?ϋ ?ό ?ύ ?ώ ?Ϗ ?ϐ ?ϑ ?ϒ ?ϓ ?ϔ ?ϕ ?ϖ ?ϗ ?Ϙ ?ϙ
                      ?Ϛ ?ϛ ?Ϝ ?ϝ ?Ϟ ?ϟ ?Ϡ ?ϡ ?Ϣ ?ϣ ?Ϥ ?ϥ ?Ϧ ?ϧ ?Ϩ ?ϩ
                      ?Ϫ ?ϫ ?Ϭ ?ϭ ?Ϯ ?ϯ ?ϰ ?ϱ ?ϲ ?ϳ ?ϴ ?ϵ ?϶ ?Ϸ ?ϸ ?Ϲ
                      ?Ϻ ?ϻ

                      ?ἀ ?ἁ ?ἂ ?ἃ ?ἄ ?ἅ ?ἆ ?ἇ ?Ἀ ?Ἁ ?Ἂ ?Ἃ ?Ἄ ?Ἅ ?Ἆ ?Ἇ
                      ?ἐ ?ἑ ?ἒ ?ἓ ?ἔ ?ἕ ?἖ ?἗ ?Ἐ ?Ἑ ?Ἒ ?Ἓ ?Ἔ ?Ἕ ?἞ ?἟
                      ?ἠ ?ἡ ?ἢ ?ἣ ?ἤ ?ἥ ?ἦ ?ἧ ?Ἠ ?Ἡ ?Ἢ ?Ἣ ?Ἤ ?Ἥ ?Ἦ ?Ἧ
                      ?ἰ ?ἱ ?ἲ ?ἳ ?ἴ ?ἵ ?ἶ ?ἷ ?Ἰ ?Ἱ ?Ἲ ?Ἳ ?Ἴ ?Ἵ ?Ἶ ?Ἷ
                      ?ὀ ?ὁ ?ὂ ?ὃ ?ὄ ?ὅ ?὆ ?὇ ?Ὀ ?Ὁ ?Ὂ ?Ὃ ?Ὄ ?Ὅ ?὎ ?὏
                      ?ὐ ?ὑ ?ὒ ?ὓ ?ὔ ?ὕ ?ὖ ?ὗ ?὘ ?Ὑ ?὚ ?Ὓ ?὜ ?Ὕ ?὞ ?Ὗ
                      ?ὠ ?ὡ ?ὢ ?ὣ ?ὤ ?ὥ ?ὦ ?ὧ ?Ὠ ?Ὡ ?Ὢ ?Ὣ ?Ὤ ?Ὥ ?Ὦ ?Ὧ
                      ?ὰ ?ά ?ὲ ?έ ?ὴ ?ή ?ὶ ?ί ?ὸ ?ό ?ὺ ?ύ ?ὼ ?ώ ?὾ ?὿
                      ?ᾀ ?ᾁ ?ᾂ ?ᾃ ?ᾄ ?ᾅ ?ᾆ ?ᾇ ?ᾈ ?ᾉ ?ᾊ ?ᾋ ?ᾌ ?ᾍ ?ᾎ ?ᾏ
                      ?ᾐ ?ᾑ ?ᾒ ?ᾓ ?ᾔ ?ᾕ ?ᾖ ?ᾗ ?ᾘ ?ᾙ ?ᾚ ?ᾛ ?ᾜ ?ᾝ ?ᾞ ?ᾟ
                      ?ᾠ ?ᾡ ?ᾢ ?ᾣ ?ᾤ ?ᾥ ?ᾦ ?ᾧ ?ᾨ ?ᾩ ?ᾪ ?ᾫ ?ᾬ ?ᾭ ?ᾮ ?ᾯ
                      ?ᾰ ?ᾱ ?ᾲ ?ᾳ ?ᾴ ?᾵ ?ᾶ ?ᾷ ?Ᾰ ?Ᾱ ?Ὰ ?Ά ?ᾼ ?᾽ ?ι ?᾿
                      ?῀ ?῁ ?ῂ ?ῃ ?ῄ ?῅ ?ῆ ?ῇ ?Ὲ ?Έ ?Ὴ ?Ή ?ῌ ?῍ ?῎ ?῏
                      ?ῐ ?ῑ ?ῒ ?ΐ ?῔ ?῕ ?ῖ ?ῗ ?Ῐ ?Ῑ ?Ὶ ?Ί ?῜ ?῝ ?῞ ?῟
                      ?ῠ ?ῡ ?ῢ ?ΰ ?ῤ ?ῥ ?ῦ ?ῧ ?Ῠ ?Ῡ ?Ὺ ?Ύ ?Ῥ ?῭ ?΅ ?`
                      ?῰ ?῱ ?ῲ ?ῳ ?ῴ ?῵ ?ῶ ?ῷ ?Ὸ ?Ό ?Ὼ ?Ώ ?ῼ ?´ ?῾

                      ?℀ ?℁ ?ℂ ?℃ ?℄ ?℅ ?℆ ?ℇ ?℈ ?℉ ?ℊ ?ℋ ?ℌ ?ℍ ?ℎ ?ℏ
                      ?ℐ ?ℑ ?ℒ ?ℓ ?℔ ?ℕ ?№ ?℗ ?℘ ?ℙ ?ℚ ?ℛ ?ℜ ?ℝ ?℞ ?℟
                      ?℠ ?℡ ?™ ?℣ ?ℤ ?℥ ?Ω ?℧ ?ℨ ?℩ ?K ?Å ?ℬ ?ℭ ?℮ ?ℯ
                      ?ℰ ?ℱ ?Ⅎ ?ℳ ?ℴ ?ℵ ?ℶ ?ℷ ?ℸ ?ℹ ?℺ ?℻ ?ℼ ?ℽ ?ℾ ?ℿ
                      ?⅀ ?⅁ ?⅂ ?⅃ ?⅄ ?ⅅ ?ⅆ ?ⅇ ?ⅈ ?ⅉ ?⅊ ?⅋ ?⅌ ?⅍ ?ⅎ ?⅏

                      ?₁ ?₂ ?₃ ?₄ ?₅ ?₆ ?₇ ?₈ ?₉ ?₀ ?ₐ ?ₑ ?ₒ ?ₓ ?ₔ ?ₕ
                      ?ₖ ?ₗ ?ₘ ?ₙ ?ₚ ?ₛ ?ₜ ?' ?_ ?! ??))
      (modify-syntax-entry it "w" st))

    ;; Lean operator chars
    (dolist (it (string-to-list "#$%&*+<=>@^|~:"))
      (modify-syntax-entry it "." st))

    ;; Whitespace is whitespace
    (modify-syntax-entry ?\  " " st)
    (modify-syntax-entry ?\t " " st)

    ;; Strings
    (modify-syntax-entry ?\" "\"" st)
    (modify-syntax-entry ?\\ "/" st)

    st))

;;;; Font Locking:

(eval-and-compile
  (defconst lean--declarations
    '("instance" "structure" "class" "theorem" "axiom" "lemma" "definition" "def" "constant")
    "Lean declarations."))
(defconst lean--declarations-regexp
  (rx word-start
      (group (eval (append '(or "inductive"
                                (group "class" (zero-or-more whitespace) "inductive"))
                           lean--declarations)))
      word-end (zero-or-more whitespace)
      (group (zero-or-more "{" (zero-or-more (not (any "}"))) "}" (zero-or-more whitespace)))
      (zero-or-more whitespace)
      (group (zero-or-more (not (any " \t\n\r{(["))))))

(eval-and-compile
  (defconst lean--keywords
    '("import" "prelude" "protected" "private" "noncomputable"
      "unsafe" "partial" "renaming" "hiding" "begin" "constant"
      "variable" "variables" "theorem" "example" "abbrev"
      "open" "export" "axiom" "inductive" "with"
      "structure" "universe" "universes" "hide"
      "precedence" "match_syntax" "match" "nomatch" "infix" "infixl" "infixr" "notation" "postfix" "prefix" "instance"
      "end" "this" "using" "using_well_founded" "namespace" "section"
      "attribute" "local" "set_option" "extends" "include" "class"
      "attributes" "raw" "have" "show" "suffices" "by" "in" "at" "do" "let" "for" "unless" "break" "continue"
      "try" "catch" "finally" "where" "rec" "mut" "forall" "fun"
      "exists" "if" "then" "else" "from" "init_quot" "return"
      "mutual" "def" "run_cmd" "declare_syntax_cat" "syntax" "macro_rules" "macro" "scoped" "elab"
      "initialize" "builtin_initialize" "register_builtin_option" "induction" "cases" "generalizing" "unif_hint" "deriving")
    "Lean keywords ending with `word' (not symbol)."))
(defconst lean--keywords-regexp
  (rx word-start (eval (cons 'or lean--keywords)) word-end))

(eval-and-compile
  (defconst lean--constants
    '("#" "@" "!" "$" "->" "∼" "↔" "/" "==" "=" ":=" "<->" "/\\" "\\/" "∧" "∨"
      "≠" "<" ">" "≤" "≥" "¬" "<=" ">=" "⁻¹" "⬝" "▸" "+" "*" "-" "/" "λ"
      "→" "∃" "∀" "∘" "×" "Σ" "Π" "~" "||" "&&" "≃" "≡" "≅"
      "ℕ" "ℤ" "ℚ" "ℝ" "ℂ" "𝔸"
      "⬝e" "⬝i" "⬝o" "⬝op" "⬝po" "⬝h" "⬝v" "⬝hp" "⬝vp" "⬝ph" "⬝pv" "⬝r" "◾" "◾o"
      "∘n" "∘f" "∘fi" "∘nf" "∘fn" "∘n1f" "∘1nf" "∘f1n" "∘fn1"
      "^c" "≃c" "≅c" "×c" "×f" "×n" "+c" "+f" "+n" "ℕ₋₂")
    "Lean constants."))
(defconst lean--constants-regexp (regexp-opt lean--constants))

(defconst lean--numerals-regexp
  (rx word-start
      (one-or-more digit) (optional (and "." (zero-or-more digit)))
      word-end))

(eval-and-compile
  (defconst lean--warnings '("sorry") "Lean warnings."))
(defconst lean--warnings-regexp
  (rx word-start (eval (cons 'or lean--warnings)) word-end))

(eval-and-compile
  (defconst lean--debugging '("unreachable!" "panic!" "assert!" "dbg_trace") "Lean debugging."))
(defconst lean--debugging-regexp
  (rx word-start (eval (cons 'or lean--debugging)) word-end))

(defconst lean-font-lock-defaults
  `((;; attributes
     (,(rx word-start "attribute" word-end (zero-or-more whitespace)
           (group (one-or-more "[" (zero-or-more (not (any "]"))) "]"
                               (zero-or-more whitespace))))
      (1 'font-lock-preprocessor-face))
     (,(rx (group "@[" (zero-or-more (not (any "]"))) "]"))
      (1 'font-lock-preprocessor-face))
     (,(rx (group "#" (or "eval" "print" "reduce" "help" "check" "lang" "check_failure" "synth")))
      (1 'font-lock-keyword-face))
     ;; mutual definitions "names"
     (,(rx word-start
           "mutual"
           word-end
           (zero-or-more whitespace)
           word-start
           (or "inductive" "definition" "def")
           word-end
           (group (zero-or-more (not (any " \t\n\r{([,")))
                  (zero-or-more (zero-or-more whitespace) "," (zero-or-more whitespace)
                                (not (any " \t\n\r{([,")))))
      (1 'font-lock-function-name-face))
     ;; declarations
     (,lean--declarations-regexp
      (1 'font-lock-keyword-face)
      (4 'font-lock-function-name-face))
     ;; Constants which have a keyword as subterm
     (,(rx (or "∘if")) . 'font-lock-constant-face)
     ;; Keywords
     ("\\(set_option\\)[ \t]*\\([^ \t\n]*\\)" (2 'font-lock-constant-face))
     (,lean--keywords-regexp . 'font-lock-keyword-face)
     (,(rx word-start (group "example") ".") (1 'font-lock-keyword-face))
     (,(rx (or "∎")) . 'font-lock-keyword-face)
     ;; Types
     (,(rx word-start (or "Prop" "Type" "Type*" "Sort" "Sort*") symbol-end) . 'font-lock-type-face)
     (,(rx word-start (group (or "Prop" "Type" "Sort")) ".") (1 'font-lock-type-face))
     ;; String
     ("\"[^\"]*\"" . 'font-lock-string-face)
     ;; Debugging builtins
     (,lean--debugging-regexp . 'font-lock-warning-face)
     ;; ;; Constants
     (,lean--constants-regexp . 'font-lock-constant-face)
     (,lean--numerals-regexp . 'font-lock-constant-face)
     ;; place holder
     (,(rx symbol-start "_" symbol-end) . 'font-lock-preprocessor-face)
     ;; warnings
     (,lean--warnings-regexp . 'font-lock-warning-face)
     ;; escaped identifiers
     (,(rx (and (group "«") (group (one-or-more (not (any "»")))) (group "»")))
      (1 font-lock-comment-face t)
      (2 nil t)
      (3 font-lock-comment-face t)))))

(defconst lean-infoview-font-lock-defaults
  `((;; Please add more after this:
     (,(rx (group (+ symbol-start (+ (or word (char ?₁ ?₂ ?₃ ?₄ ?₅ ?₆ ?₇ ?₈ ?₉ ?₀)))
                     symbol-end (* white)))
           ":")
      (1 'font-lock-variable-name-face))
     (,(rx white ":" white)
      . 'font-lock-keyword-face)
     (,(rx "⊢" white)
      . 'font-lock-keyword-face)
     (,(rx "[" (group "stale") "]")
      (1 'font-lock-warning-face))
     (,(rx line-start "No Goal" line-end)
      . 'font-lock-constant-face)
     ,@(car lean-font-lock-defaults))))

;;;; Comments:

;;; TODO: check which of these need a `comment-continue'
(defconst lean--line-comment-region-alist
  '((comment-start . "-- ") (comment-end . "") (comment-style . indent))
  "Make `comment-region' wrap a region with line comments.")

(defconst lean--block-comment-region-alist
  '((comment-start . "/- ") (comment-end . " -/") (comment-style . multi-line))
  "Make `comment-region' wrap a region with a block comment.")

(defconst lean--section-comment-region-alist
  '((comment-start . "/-!") (comment-end . "-/") (comment-style . extra-line)
    (comment-continue . ""))
  "Make `comment-region' wrap a region with a module / section block comment.")

(defconst lean--declaration-comment-region-alist
  '((comment-start . "/--") (comment-end . "-/") (comment-style . extra-line))
  "Make `comment-region' wrap a region with a declaration block comment.")

;;; why isn't there a builtin for this already?
;;; for now just reuse evil, but need a better long term solution
(defun lean--in-comment-p (&optional pos)
  "Check if POS is within a comment according to current syntax.
If POS is nil, (point) is used. The return value is the beginning
position of the comment."
  (setq pos (or pos (point)))
  (let ((chkpos
         (cond
          ((eobp) pos)
          ((= (char-syntax (char-after)) ?<) (1+ pos))
          ((and (not (zerop (logand (car (syntax-after (point)))
                                    (ash 1 16))))
                (not (zerop (logand (or (car (syntax-after (1+ (point)))) 0)
                                    (ash 1 17)))))
           (+ pos 2))
          ((and (not (zerop (logand (car (syntax-after (point)))
                                    (ash 1 17))))
                (not (zerop (logand (or (car (syntax-after (1- (point)))) 0)
                                    (ash 1 16)))))
           (1+ pos))
          (t pos))))
    (let ((syn (save-excursion (syntax-ppss chkpos))))
      (and (nth 4 syn) (nth 8 syn)))))

(defun lean--comment-region (beg end &optional arg)
  "Like `comment-region-default' except we don't try to balance the width
of `comment-start' and `comment-end'."
  (cl-letf (((symbol-function 'comment-make-bol-ws)
             (lambda (_len) "")))
    (comment-region-default beg end arg)))

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
                  (if (looking-at-p lean--declarations-regexp)
                      lean--declaration-comment-region-alist
                    lean--section-comment-region-alist))))))))

(defun lean--comment-insert-alist ()
  "Settings to use when inserting an empty comment."
  (or (and (save-excursion (skip-chars-backward " \t\n")
                           (bobp))
           ;; top level
           lean--section-comment-region-alist)
      (and (save-excursion (forward-line 1)
                           (looking-at-p (rx (or "namespace" "section"))))
           lean--section-comment-region-alist)
      (and (save-excursion (forward-line 1)
                           (looking-at-p lean--declarations-regexp))
           lean--declaration-comment-region-alist)
      lean--line-comment-region-alist))

(defun lean--comment-dwim-with-alist (extra-alist &optional arg)
  (let-alist extra-alist
    (let ((comment-start (or .comment-start comment-start))
          (comment-end (or .comment-end comment-end))
          (comment-style (or .comment-style comment-style))
          (comment-continue (or .comment-continue comment-continue))
          (comment-padding (or .comment-padding comment-padding)))
      (comment-dwim arg))))

(defun lean-comment-dwim (arg)
  "Call the comment command you want (Do What I Mean).

This is like `comment-dwim', except this command will also rotate
through various block comment styles if called repeatedly."
  (interactive "*P")
  (cond
   ((use-region-p)
    ;; punt on region-specific logic for now
    (lean--comment-dwim-with-alist lean--section-comment-region-alist arg))
   ((not (lean--in-comment-p))
    (lean--comment-dwim-with-alist (lean--comment-insert-alist) arg))
   ((lean--comment-replace-alist)       ; cond-let when available
    (let ((alist (lean--comment-replace-alist)))
      (comment-beginning)
      (comment-kill nil)
      (lean--comment-dwim-with-alist alist arg)))
   (t
    (lean--comment-dwim-with-alist (lean--comment-current-alist) arg))))

;;; NOTE: this is erroneously called from `comment-indent' when we're
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
    (delete-trailing-whitespace (line-beginning-position) (line-end-position))
    (end-of-line)
    (save-excursion (insert "-- "))
    (comment-indent)
    (end-of-line))))

;;;; Indentation

(defun lean--set-indent-variables ()
  (setq-local tab-width 2
              standard-indent 2
              indent-tabs-mode nil))

;; (defun nael-fill-paragraph (&optional justify)
;;   "Fill comment paragraph at point.  Maybe JUSTIFY."
;;   (interactive)
;;   (when (save-excursion (nth 4 (syntax-ppss (point))))
;;     (let* ((com-beg (save-excursion
;;                       (re-search-backward "[/-]-" nil t)
;;                       (match-beginning 0)))
;;            (multi (eq (char-after com-beg) ?/)))
;;       (if multi
;;           (let* ((par-beg (save-excursion
;;                             (re-search-backward paragraph-start nil t)
;;                             (match-beginning 0)))
;;                  (beg (max com-beg par-beg))
;;                  (com-end (if multi "-/" "$"))
;;                  (com-end (save-excursion
;;                             ;; If cursor is at -|/, then move to |-/,
;;                             ;; so that `re-search-forward' can locate
;;                             ;; comment ending.
;;                             (and (eq (char-before) ?-)
;;                                  (eq (char-after) ?/)
;;                                  (backward-char))
;;                             (re-search-forward com-end nil t)
;;                             (match-end 0)))
;;                  (par-end (save-excursion
;;                             (search-forward paragraph-separate nil t)
;;                             (match-end 0)))
;;                  (end (min com-end par-end)))
;;             (fill-region beg end justify))
;;         ;; `fill-comment-paragraph' fills prefixed comments well, when
;;         ;; configured correctly.
;;         (let ((comment-start "--") (comment-end ""))
;;           ;; For some reason, "" is used as fill-prefix by
;;           ;; `fill-comment-paragraph' when point is at --|.  Avoid
;;           ;; this misbehavior by moving point forward one char.
;;           (and (not (eolp))
;;                (looking-back "--" (max (- (point) 2) (point-min)))
;;                (forward-char))
;;           (fill-comment-paragraph justify))))))

;;;; Navigation

;; TODO: Both `nael-navigation-defun-beginning' and
;; `nael-navigation-defun-name' currently lack support for `mutual'
;; blocks, i.e. mutually recursive definitions.

;; (defun nael-navigation-defun-end ()
;;   "`end-of-defun-function' for `nael-mode'."
;;   (interactive)
;;   (when (re-search-forward nael-syntax-definition nil t)
;;     (goto-char (match-beginning 0))))

;; (defun nael-navigation-defun-beginning ()
;;   "`beginning-of-defun-function' for `nael-mode'."
;;   (interactive)
;;   (re-search-backward nael-syntax-definition nil t))

;; (defun nael-navigation-defun-name ()
;;   "`add-log-current-defun-function' for `nael-mode'."
;;   (save-excursion
;;     (when (nael-navigation-defun-beginning)
;;       (forward-symbol 1)
;;       (forward-whitespace 1)
;;       (symbol-at-point))))

;; (defvar nael-imenu-generic-expression
;;   (list (list nil nael-syntax-definition 4))
;;   "`imenu-generic-expression' for `nael-mode'.")

;;;; Infoview:

;;; Inspired by nael, we hook into the eldoc mechanisms.  Inspired by
;;; lean4-mode, we use a dedicated buffer for fontification etc.  From
;;; my own work, seems best to use generics so we can swap backends
;;; (eglot / lsp) as the user prefers.

(defgroup lean-infoview nil
  "Repurpose `eldoc' to publish Lean LSP server responses."
  :group 'lean
  :prefix "lean-infoview-")

(defface lean-infoview-section-face
  '((t (:inherit font-lock-function-name-face :weight bold)))
  "Face for section-headers of Lean infoview buffer."
  :group 'lean-infoview)

(define-derived-mode lean-infoview-mode prog-mode "LeanI"
  "Major mode for the Lean Infoview buffer."
  (setq-local font-lock-defaults lean-infoview-font-lock-defaults))

(defvar lean-infoview--buffer-name "*Lean Infoview*"
  "Name of buffer that is used to fontify responses from the LSP server.")

(defun lean-infoview--goals (callback goals)
  (seq-let (g &rest gs) goals
    (if (null g)
        ;; TODO: print the "goals accomplished" to an infoview buffer
        (funcall callback nil)
      (with-temp-buffer
        (with-demoted-errors "Error during fontlock: %s"
          (insert (replace-regexp-in-string "^" "  " g))
          (seq-doseq (gg gs)
            (insert "\n\n" (replace-regexp-in-string "^" "  " gg)))
          (delay-mode-hooks (funcall 'lean-infoview-mode))
          (ignore-errors (font-lock-ensure))
          (goto-char (point-min))
          (insert (propertize "Tactic state:\n"
                              'face 'lean-infoview-section-face)
                  "\n"))
        (funcall callback (buffer-string)
                 (list :echo g))))))

(defun lean-infoview--term-goal (callback goal)
  (if (or (null goal) (string= "" goal))
      (funcall callback nil)
    (with-temp-buffer
      (with-demoted-errors "Error during fontlock: %s"
        (insert (replace-regexp-in-string "^" "  " (eglot--format-markup goal)))
        (delay-mode-hooks (funcall 'lean-infoview-mode))
        (ignore-errors (font-lock-ensure))
        (goto-char (point-min))
        (insert (propertize "Expected type:\n"
                            'face 'lean-infoview-section-face)
                "\n"))
      (funcall callback (buffer-string)
               (list :echo 'skip)))))

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
  "ElDoc documentation function for the expected type of the term at point.

ElDoc will provide CALLBACK.  See `eldoc-documentation-functions' for
instructions on using CALLBACK to provide documentation info.

The request target path is `$/lean/plainTermGoal' as documented here:
https://leanprover-community.github.io/mathlib4_docs/Lean/Data/Lsp/Extra.html#Lean.Lsp.PlainTermGoal"
  (lean-lsp--ensure-backend)
  (lean-lsp--request-async lean-lsp--backend :$/lean/plainTermGoal
                           #'lean-infoview--term-goal callback))

;;;; Mode:

(defvar-keymap lean-mode-map
  "<remap> <display-local-help>" #'eldoc-doc-buffer
  "<remap> <comment-dwim>" #'lean-comment-dwim
  "C-c C-k" #'quail-show-key)

;;;###autoload
(define-derived-mode lean-mode prog-mode "Lean"
  "Major mode for Lean.

\\{lean-mode-map}"
  :syntax-table lean-mode-syntax-table

  (activate-input-method "Lean")

  ;; Align:
  (setq align-mode-rules-list align-lean-rules-list)

  ;; Comments:
  (setq-local comment-start "-- ")
  (setq-local comment-start-skip "\\(?:--\\|/-!?\\)[[:space:]]*")
  (setq-local comment-end "")
  (setq-local comment-end-skip "[[:space:]]*\\(?:-/\\|\\s>\\)")
  (setq-local comment-style 'indent)
  (setq-local comment-padding 1)
  (setq-local comment-insert-comment-function #'lean-insert-comment)
  (setq-local comment-quote-nested nil)
  (setq-local comment-use-syntax t)
  (setq-local parse-sexp-ignore-comments t)
  (setq-local comment-region-function 'lean--comment-region)

  ;; Navigation:

  ;; Paragraphs and filling:

  ;; Font Locking:
  (setq-local font-lock-defaults lean-font-lock-defaults)

  ;; Compile:

  ;; Imenu:

  ;; Flymake:

  ;; LSP:
  ;; unlike most LSP servers, lake does not output anything on startup,
  ;; so Eglot will by default wait around
  (setq-local eglot-sync-connect nil)
  (setq-local eldoc-documentation-strategy #'eldoc-documentation-compose)
  (add-hook 'eldoc-documentation-functions #'lean-infoview-goals -90 'local)
  (add-hook 'eldoc-documentation-functions #'lean-infoview-term-goal -80 'local))

;;;; Association:

;; Lean language specification requires UTF-8 encoding.
(modify-coding-system-alist 'file "\\.lean\\'" 'utf-8)

;;;###autoload
(add-to-list 'auto-mode-alist
             (cons "\\.lean\\'" 'lean-mode))

(register-input-method
 "Lean" "UTF-8" 'quail-use-package
 "∏" "Lean input method."
 "lean-input")

(add-to-list 'eglot-server-programs '(lean-mode "lake" "serve"))

(with-eval-after-load 'org-src
  (add-to-list 'org-src-lang-modes
               (cons "lean" 'lean)))

;; If the code that requires `markdown-mode' grows, we will extract it
;; into a new package that depends on it.  But a single expression is
;; not worth a package.
(with-eval-after-load 'markdown-mode
  (add-to-list 'markdown-code-lang-modes
               (cons "lean" 'lean-mode)))

(provide 'lean-mode)
;;; lean-mode.el ends here
