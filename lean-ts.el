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

(defconst lean-ts-block-openers '("by" "do" "where" "match" "fun" "then" "else")
  "Keywords that open a layout block.

When these keywords appear at the end of a line, the next line will be
indented enough to start a new block.")

(defconst lean-ts-hanging-nodes
  '("anonymous_constructor" "application" "array" "list" "parenthesized"
    "structure_instance" "subtype" "tactic_config" "tuple")
  "Node types whose children continue a line rather than open a block.

Everything after the first child of one of these is an argument or an
element, so it follows the Emacs convention: line up under the first one
if that one shares a line with what it hangs from, and otherwise indent
a single step from the line the construct starts on.")

(defconst lean-ts-closing-delimiters '(")" "]" "}" "⟩" "⌉" "⌋")
  "Tokens that close a `lean-ts-hanging-nodes' construct.")

(defconst lean-ts-binding-nodes
  '("let" "let_mut" "let_bind" "have" "show" "suffices" "do_let")
  "Node types that bind a name and then continue with a body.

The grammar nests the body of one of these inside the previous one, so
a run of them is arbitrarily deep in the tree while Lean style keeps
every one of them at the same column.")

(defconst lean-ts-arm-nodes '("match_arm" "cases_arm")
  "Node types for one alternative of a pattern match.

`match' and the `cases' tactic share this shape: a flat run of arms
under the keyword that introduced them.  Keying the arm rules off this
list rather than \"match_arm\" alone keeps `cases_arm' in sync with
whatever indentation convention is eventually settled on for arms,
instead of drifting if only one of the two is ever updated.")

(defun lean-ts--regexp (types)
  "Regexp matching exactly the node types in TYPES."
  (rx-to-string `(: bos (or ,@types) eos) t))

(defun lean-ts--block-openers ()
  "Regexp matching the keywords that open a layout block."
  (lean-ts--regexp lean-ts-block-openers))

(defconst lean-ts-after-closing-tactic-query
  "(tactic_focus (_closing_tactic) . (_) @this)"
  "Query matching a tactic that directly follows a goal-closing one.

The `.' anchors the two as adjacent named siblings, so this says
\"@this is the tactic right after the goal was closed\" without the
rule having to inspect siblings itself.")

(defconst lean-ts-closed-focus-block-query
  "(tactic_focus (_closing_tactic) .) @this"
  "Query matching a focus block whose last tactic closes the goal.

The trailing `.' anchors `_closing_tactic' as the last named child.")

(defun lean-ts--token-before-matches-p (pos type)
  "Non-nil if the last token before POS has a node type matching TYPE.
Whitespace and newlines before POS are skipped."
  (save-excursion
    (goto-char pos)
    (skip-chars-backward " \t\n")
    (and (> (point) (point-min))
         (string-match-p
          type (thread-first (point)
                             (1-)
                             (treesit-node-at)
                             (treesit-node-type)
                             (or ""))))))

(defun lean-ts--decoration-line-p (_node _parent bol &rest _)
  "Non-nil when the line at BOL only decorates the declaration below it.

An attribute list or doc comment written above a declaration parses as
an ERROR until that declaration has been typed, so the node at BOL
cannot say what it is and the opening token has to answer instead."
  (string-match-p (rx bos (or "@[" "/--" "/-!") eos)
                  (or (treesit-node-type (treesit-node-at bol)) "")))

(defun lean-ts--same-line-p (a b)
  "Non-nil if nodes A and B both exist and start on the same line."
  (and a b (= (line-number-at-pos (treesit-node-start a))
              (line-number-at-pos (treesit-node-start b)))))

(defun lean-ts--innermost-application (node)
  "Return the innermost `application' on the callee spine of NODE.

Application is left-nested, so `f a b' is `((f a) b)' and the callee of
the outermost node is another application.  Only the innermost one holds
the head of the call and the argument that may share its line."
  (let ((name (treesit-node-child-by-field-name node "name")))
    (if (equal (treesit-node-type name) "application")
        (lean-ts--innermost-application name)
      node)))

(defun lean-ts--hanging-parts (parent)
  "Return a cons (HEAD . ITEM) describing how PARENT hangs.

HEAD is what the construct hangs from and ITEM is the first thing that
follows it: for an `application' the callee and its first argument, and
for a bracketed node the opening delimiter and the first element."
  (if (equal (treesit-node-type parent) "application")
      (let ((inner (lean-ts--innermost-application parent)))
        (cons (treesit-node-child-by-field-name inner "name")
              (treesit-node-child-by-field-name inner "arguments")))
    (cons (treesit-node-child parent 0)
          (treesit-node-child parent 1))))

(defconst lean-ts--statement-parents
  (rx-to-string `(: bos (or "by" "do" (: "tactic_" (+ nonl))
                            ,@lean-ts-binding-nodes)
                    eos)
                t)
  "Regexp matching node types whose children are statements.")

(defun lean-ts--statement-continuation-p (_node parent &rest _)
  "Non-nil when PARENT is an application continuing a block statement.

In a `by' block, a `do' block or the value of a binding, the layout rule
swallows an over-indented line into the arguments of the statement above
it.  Such a line is nearly always a statement the user has not lined up
yet rather than a real argument, so it belongs at the column of the
statement that swallowed it.  Elsewhere the same shape really is a
continuation, and the hanging rules handle it instead."
  (let ((outer parent))
    (while (equal (treesit-node-type (treesit-node-parent outer)) "application")
      (setq outer (treesit-node-parent outer)))
    (string-match-p lean-ts--statement-parents
                    (or (treesit-node-type (treesit-node-parent outer)) ""))))

(defun lean-ts--hanging-item-p (_node parent &rest _)
  "Non-nil when PARENT already has an item on the line it hangs from."
  (pcase-let ((`(,head . ,item) (lean-ts--hanging-parts parent)))
    (lean-ts--same-line-p head item)))

(defun lean-ts--hanging-item-anchor (_node parent &rest _)
  "Anchor on the first item of PARENT, for lining the rest up under it."
  (treesit-node-start (cdr (lean-ts--hanging-parts parent))))

(defun lean-ts--first-binder-anchor (_node parent &rest _)
  "Anchor on PARENT's first binder, for lining the rest up under it.

Unlike the hanging nodes above, a `binders' node has no separate opener
to check for -- the first binder itself always plays that role, on
whatever line it happens to start."
  (treesit-node-start (treesit-node-child parent 0)))

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
        ;; The counterpart to `node-is', looking backwards instead of at
        ;; BOL.  Indentation is really the question "given what came
        ;; before, where does the next thing go", and the node at BOL
        ;; cannot answer it: a finished declaration and one ending in a
        ;; bare `by' are both `decorated_declaration' there, while the
        ;; token before point tells them apart immediately.
        (cons 'prev-token-is
              (lambda (type)
                (lambda (_node _parent bol &rest _)
                  (lean-ts--token-before-matches-p bol type))))
        ;; Same question asked from the other end.
        ;; `lean-ts-empty-line-indent-rules' runs with BOL on the previous
        ;; non-blank line, so "what precedes the line being indented" is
        ;; that line's last token, not the one before its start.
        (cons 'eol-token-is
              (lambda (type)
                (lambda (_node _parent bol &rest _)
                  (lean-ts--token-before-matches-p
                   (save-excursion (goto-char bol) (line-end-position))
                   type))))
        ;; Matches when NODE sits in a field of the given name in its
        ;; parent.  `treesit's own `match' preset can test the field of
        ;; NODE but not of PARENT.
        (cons 'parent-field-is
              (lambda (name)
                (lambda (_node parent &rest _)
                  (string-match-p
                   name (or (treesit-node-field-name parent) "")))))
        ;; Sibling and child relations are left to treesit's own `query'
        ;; preset: tree-sitter query anchors already say "immediately
        ;; after" and "last child", and a query can name a supertype like
        ;; `_closing_tactic' so the grammar keeps owning the member list.
        )
  "A list of indent rule presets.

These will be appended to `treesit-simple-indent-rules' during
indentation of Lean code.")

(defconst lean-ts-empty-line-indent-rules
  `(
    ;; The previous line ended on the block-opening keyword itself, so
    ;; nothing has been written in the block yet.  This is the normal state
    ;; while a proof is being typed.
    ((eol-token-is ,(lean-ts--block-openers)) no-indent lean-ts-basic-offset)
    ;; Likewise for a delimiter left open at the end of a line.
    ((eol-token-is ,(lean-ts--regexp '("(" "[" "{" "⟨")))
     no-indent lean-ts-basic-offset)
    ;; A line beginning with one of these begins a sibling of it, so the
    ;; next line starts at the same column: another field, another arm,
    ;; another binding, or the declaration an attribute was written for.
    ;;
    ;; This comes before the ERROR rules because half-finished input is
    ;; exactly when it is needed -- an unclosed `{' leaves the whole
    ;; declaration an ERROR, but the field above still says where the
    ;; next one goes.
    ((node-is ,(lean-ts--regexp
                (append '("attributes" "constructor" "field_assignment"
                          "match" "cases" "structure_field")
                        lean-ts-arm-nodes
                        lean-ts-binding-nodes)))
     no-indent 0)
    ;; Likewise, but for decoration the parser cannot place yet.
    (lean-ts--decoration-line-p no-indent 0)
    ;; Input the parser could not make sense of at all.  Anchor on the
    ;; previous line's own indentation with `no-indent' rather than on the
    ;; tree, since an ERROR node starts at column 0 however deeply nested
    ;; the real context is.
    ((node-is "ERROR") no-indent lean-ts-basic-offset)
    ((parent-is "ERROR") no-indent lean-ts-basic-offset)
    ;; `fun x =>' opens a body even when the declaration itself parses.
    ((node-is "fun") no-indent lean-ts-basic-offset)
    ;; A focus block that has closed its goal is finished; anything else
    ;; in one is still open and the next tactic belongs inside it.
    ((query ,lean-ts-closed-focus-block-query) no-indent 0)
    ((node-is "tactic_focus") no-indent lean-ts-basic-offset)
    ;; Another tactic in the same sequence.
    ((parent-is "by") no-indent 0)
    (catch-all no-indent 0))
  "Rules for `lean-mode' indentation of an empty line.

Assumes (NODE PARENT BOL) are calculated for the previous non-blank line.")

(defconst lean-ts-indent-rules
  `(
    ;; On a blank line treesit hands us NODE nil and PARENT the root, no
    ;; matter what encloses point, so there is nothing in the tree to key
    ;; on.  `lean-ts--empty-line-offset' re-asks the question about the
    ;; previous non-blank line instead.
    (no-node column-0 lean-ts--empty-line-offset)
    ;; Incomplete input.  The ERROR node starts at column 0 however deeply
    ;; nested the real context is, so measure from the previous line.
    ((node-is "ERROR") prev-line lean-ts-basic-offset)
    ((parent-is "ERROR") prev-line lean-ts-basic-offset)
    ;; Commands sit at the left margin, and attributes or a doc comment
    ;; written above one must not push the declaration itself off it.
    ((parent-is "module") column-0 0)
    ((parent-is "decorated_declaration") standalone-parent 0)
    ;; Focus blocks: align with the `·' after a closing tactic, otherwise
    ;; indent into the block.
    ((query ,lean-ts-after-closing-tactic-query) parent 0)
    ((parent-is "tactic_focus") parent lean-ts-basic-offset)
    ;; Tactic sequences hang directly off `by', with the keyword as child
    ;; 0, so the first tactic indents from whatever line `by' ends.
    ;; The parent type is matched as a regexp, so these are anchored:
    ;; a bare "do" would also claim `do_if' and every other do element.
    ((match nil ,(lean-ts--regexp '("by")) nil 1 1)
     standalone-parent lean-ts-basic-offset)
    ((parent-is ,(lean-ts--regexp '("by"))) prev-sibling 0)
    ((match nil ,(lean-ts--regexp '("do")) nil 1 1)
     standalone-parent lean-ts-basic-offset)
    ((parent-is ,(lean-ts--regexp '("do"))) prev-sibling 0)
    ;; Alternation.  `match', a pattern-matching `fun', and the `cases'
    ;; tactic all hold their arms as flat children, so every arm lines up
    ;; with the keyword and only an arm's own body indents past it.
    ((node-is ,(lean-ts--regexp lean-ts-arm-nodes)) standalone-parent 0)
    ((parent-is ,(lean-ts--regexp lean-ts-arm-nodes)) standalone-parent lean-ts-basic-offset)
    ;; The body of a `fun' that is not pattern matching.
    ((parent-is ,(lean-ts--regexp '("fun"))) standalone-parent lean-ts-basic-offset)
    ;; Fields and constructors are in the `fields' and `constructors'
    ;; fields rather than `body', so they would otherwise fall through to
    ;; the signature-continuation rule below and indent twice.
    ((node-is "structure_field") standalone-parent lean-ts-basic-offset)
    ((node-is "constructor") standalone-parent lean-ts-basic-offset)
    ;; `else' closes the branch above it, so it belongs to the `if'.
    ((node-is "else") standalone-parent 0)
    ((parent-is ,(lean-ts--regexp '("if" "if_let" "do_if" "do_if_let")))
     standalone-parent lean-ts-basic-offset)
    ;; A run of bindings reads as a flat sequence even though the grammar
    ;; nests each one inside the last, so only the body stays put; the
    ;; value being bound is a continuation and indents.
    ((and (parent-is ,(lean-ts--regexp lean-ts-binding-nodes))
          (match nil nil "body"))
     standalone-parent 0)
    ((parent-is ,(lean-ts--regexp lean-ts-binding-nodes))
     standalone-parent lean-ts-basic-offset)
    ;; A closer belongs to the line that opened it.
    ((node-is ,(lean-ts--regexp lean-ts-closing-delimiters)) standalone-parent 0)
    ;; A line swallowed into the arguments of the statement above it goes
    ;; back to that statement's column rather than hanging off it.
    ((and (parent-is ,(lean-ts--regexp '("application")))
          lean-ts--statement-continuation-p)
     standalone-parent 0)
    ;; Arguments and elements line up under the first one when that one
    ;; shares a line with the callee or the opening delimiter, and
    ;; otherwise indent a step from the line the construct starts on.
    ((and (parent-is ,(lean-ts--regexp lean-ts-hanging-nodes))
          lean-ts--hanging-item-p)
     lean-ts--hanging-item-anchor 0)
    ((parent-is ,(lean-ts--regexp lean-ts-hanging-nodes))
     standalone-parent lean-ts-basic-offset)
    ;; A second (or later) binder that spills onto its own line aligns
    ;; under the first one, the same Emacs convention as the hanging
    ;; nodes above.  Excluding index 0 leaves the first binder itself to
    ;; the declaration-continuation rule below, in the rare case that one
    ;; starts its own line instead of following the declaration name.
    ((match nil ,(lean-ts--regexp '("binders")) nil 1 nil)
     lean-ts--first-binder-anchor 0)
    ;; Declaration bodies indent one step; anything else still inside the
    ;; declaration is a continuation of its signature, which Lean style
    ;; indents twice so it stays visually distinct from the body.
    ;;
    ;; A declaration is whatever fills the `declaration' field of a
    ;; `decorated_declaration', which is the grammar's own list and covers
    ;; `example' and `notation' as well as the `_declaration' supertype.
    ((and (parent-field-is "declaration") (match nil nil "body"))
     standalone-parent lean-ts-basic-offset)
    ((parent-field-is "declaration") standalone-parent lean-ts--double-offset)
    ((parent-is "where_decl") standalone-parent lean-ts-basic-offset)
    ;; Nothing in the tree claims this line.  Holding the previous line's
    ;; column leaves hand-written layout alone, where measuring from the
    ;; tree would stack a fresh offset onto every line in a run of them.
    (catch-all prev-line 0))
  "Rules for `lean-mode' indentation.")

(defun lean-ts--empty-line-offset (_node _parent bol &rest _)
  (let ((treesit-simple-indent-rules
         `((lean ,@lean-ts-empty-line-indent-rules))))
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
    (setq-local treesit-simple-indent-rules `((lean ,@lean-ts-indent-rules)))
    (setq-local treesit-primary-parser (treesit-parser-create 'lean))
    (setq-local treesit-simple-indent-presets
                (append (default-value 'treesit-simple-indent-presets)
                        lean-ts-indent-presets))
    (treesit-major-mode-setup)))

;;;; Live reload

;;;###autoload
(defun lean-ts-reload ()
  "Reload `lean-ts' from disk and refresh tree-sitter setup in live buffers.

Reloading alone does not retroactively affect a buffer that already ran
`lean-ts-setup': the buffer-local `treesit-simple-indent-rules' is a
snapshot taken at that time, not a live reference to the defconst it was
built from.  Re-run `lean-ts-setup' in every buffer already using it so
the new rules take effect immediately.

Meant to be run from the command line once a reviewed change lands, e.g.
\"emacsclient -e \\='(lean-ts-reload)\\='\"."
  (interactive)
  (load "lean-ts")
  (let ((n 0))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (and (bound-and-true-p lean-use-treesitter)
                   (derived-mode-p 'lean-mode)
                   treesit-primary-parser
                   (eq (treesit-parser-language treesit-primary-parser) 'lean))
          (lean-ts-setup)
          (setq n (1+ n)))))
    (message "lean-ts: reloaded (%d buffer%s refreshed)" n (if (= n 1) "" "s"))))

(provide 'lean-ts)
;;; lean-ts.el ends here
