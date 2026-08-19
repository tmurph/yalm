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

(defconst lean-ts-block-openers '("by" "do")
  "Keywords that open a layout block.

When these keywords appear at the end of a line, the next line will be
indented enough to start a new block.")

(defun lean-ts--block-openers ()
  "Regexp matching the keywords that open a layout block."
  (rx-to-string `(: bos (or ,@lean-ts-block-openers) eos) t))

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
    ;; Commands sit at the left margin.
    ((parent-is "module") column-0 0)
    ;; Focus blocks: align with the `·' after a closing tactic, otherwise
    ;; indent into the block.
    ((query ,lean-ts-after-closing-tactic-query) parent 0)
    ((parent-is "tactic_focus") parent lean-ts-basic-offset)
    ;; Tactic sequences hang directly off `by', with the keyword as child
    ;; 0, so the first tactic indents from whatever line `by' ends.
    ((match nil "by" nil 1 1) standalone-parent lean-ts-basic-offset)
    ((parent-is "by") prev-sibling 0)
    ;; A line swallowed into a tactic's arguments aligns with the tactic.
    ((n-p-gp nil "application" "tactic_apply") standalone-parent 0)
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
    (catch-all prev-line lean-ts-basic-offset))
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

(provide 'lean-ts)
;;; lean-ts.el ends here
