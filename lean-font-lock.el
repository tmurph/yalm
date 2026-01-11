;;; lean-font-lock.el --- Font lock definitions for lean-mode -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This library defines font lock keywords for `lean-mode'.  This is
;; incompatible with `lean-treesitter'.

;;; Code:

(defconst lean-keywords1
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
  "Lean keywords ending with `word' (not symbol).")
(defconst lean-keywords1-regexp
  (rx-to-string `(: word-start (or ,@lean-keywords1) word-end) t))

(defconst lean-constants
  '("#" "@" "!" "$" "->" "∼" "↔" "/" "==" "=" ":=" "<->" "/\\" "\\/" "∧" "∨"
    "≠" "<" ">" "≤" "≥" "¬" "<=" ">=" "⁻¹" "⬝" "▸" "+" "*" "-" "/" "λ"
    "→" "∃" "∀" "∘" "×" "Σ" "Π" "~" "||" "&&" "≃" "≡" "≅"
    "ℕ" "ℤ" "ℚ" "ℝ" "ℂ" "𝔸"
    "⬝e" "⬝i" "⬝o" "⬝op" "⬝po" "⬝h" "⬝v" "⬝hp" "⬝vp" "⬝ph" "⬝pv" "⬝r" "◾" "◾o"
    "∘n" "∘f" "∘fi" "∘nf" "∘fn" "∘n1f" "∘1nf" "∘f1n" "∘fn1"
    "^c" "≃c" "≅c" "×c" "×f" "×n" "+c" "+f" "+n" "ℕ₋₂")
  "Lean constants.")
(defconst lean-constants-regexp (regexp-opt lean-constants))

(defconst lean-numerals-regexp
  (rx word-start
      (one-or-more digit) (optional (and "." (zero-or-more digit)))
      word-end))

(defconst lean-warnings '("sorry") "Lean warnings.")
(defconst lean-warnings-regexp
  (rx-to-string `(: word-start (or ,@lean-warnings) word-end) t))

(defconst lean-debugging '("unreachable!" "panic!" "assert!" "dbg_trace") "Lean debugging.")
(defconst lean-debugging-regexp
  (rx-to-string `(: word-start (or ,@lean-debugging) word-end) t))

(defconst lean4-font-lock-defaults
  `((;; attributes
     (,(rx word-start "attribute" word-end (zero-or-more whitespace) (group (one-or-more "[" (zero-or-more (not (any "]"))) "]" (zero-or-more whitespace))))
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
           (group (zero-or-more (not (any " \t\n\r{([,"))) (zero-or-more (zero-or-more whitespace) "," (zero-or-more whitespace) (not (any " \t\n\r{([,")))))
      (1 'font-lock-function-name-face))
     ;; declarations
     (,(rx word-start
           (group (or "inductive" (group "class" (zero-or-more whitespace) "inductive") "instance" "structure" "class" "theorem" "axiom" "lemma" "definition" "def" "constant"))
           word-end (zero-or-more whitespace)
           (group (zero-or-more "{" (zero-or-more (not (any "}"))) "}" (zero-or-more whitespace)))
           (zero-or-more whitespace)
           (group (zero-or-more (not (any " \t\n\r{([")))))
      (4 'font-lock-function-name-face))
     ;; Constants which have a keyword as subterm
     (,(rx (or "∘if")) . 'font-lock-constant-face)
     ;; Keywords
     ("\\(set_option\\)[ \t]*\\([^ \t\n]*\\)" (2 'font-lock-constant-face))
     (,lean-keywords1-regexp . 'font-lock-keyword-face)
     (,(rx word-start (group "example") ".") (1 'font-lock-keyword-face))
     (,(rx (or "∎")) . 'font-lock-keyword-face)
     ;; Types
     (,(rx word-start (or "Prop" "Type" "Type*" "Sort" "Sort*") symbol-end) . 'font-lock-type-face)
     (,(rx word-start (group (or "Prop" "Type" "Sort")) ".") (1 'font-lock-type-face))
     ;; String
     ("\"[^\"]*\"" . 'font-lock-string-face)
     ;; Debugging builtins
     (,lean-debugging-regexp . 'font-lock-warning-face)
     ;; ;; Constants
     (,lean-constants-regexp . 'font-lock-constant-face)
     (,lean-numerals-regexp . 'font-lock-constant-face)
     ;; place holder
     (,(rx symbol-start "_" symbol-end) . 'font-lock-preprocessor-face)
     ;; warnings
     (,lean-warnings-regexp . 'font-lock-warning-face)
     ;; escaped identifiers
     (,(rx (and (group "«") (group (one-or-more (not (any "»")))) (group "»")))
      (1 font-lock-comment-face t)
      (2 nil t)
      (3 font-lock-comment-face t)))))

(provide 'lean-font-lock)
;;; lean-font-lock.el ends here
