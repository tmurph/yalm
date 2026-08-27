;;; lean-ts-test.el --- Unit tests for lean-ts -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;; `lean-mode' must be loaded before the `lean-use-treesitter' binding
;; below is compiled, or the `defcustom' fires inside a `let' that has
;; already bound the name lexically and errors out.
(require 'lean-mode)
(require 'lean-ts)

(require 'buttercup)

(defconst lean-indent-test-marker "‸"
  "String marking where point goes in an indentation test input.

Not \"|\", which `lean-utils--insert-and-set-point' defaults to: Lean
spells alternation with that character, so a test whose input pattern
matches would have its own source eaten as the marker.")

(defun lean-indent--reindent (input)
  "Indent the line point sits on in INPUT and return the whole buffer."
  (with-temp-buffer
    (let ((lean-use-treesitter t)
          (indent-tabs-mode nil))
      (lean-mode)
      (lean-utils--insert-and-set-point input lean-indent-test-marker)
      (call-interactively #'indent-according-to-mode)
      (buffer-string))))

(defun lean-indent--render (lines differing)
  "Render LINES numbered, flagging the indices in DIFFERING."
  (mapconcat (lambda (n)
               (format "%s %2d | %s"
                       (if (memq n differing) ">" " ")
                       (1+ n)
                       (or (nth n lines) "")))
             (number-sequence 0 (1- (length lines)))
             "\n"))

(defun lean-indent--report (want got)
  "Describe how the indentation in GOT differs from WANT.

Test cases run to several lines and differ only in leading whitespace,
so the two are printed one above the other with the lines that differ
called out, rather than left for the reader to line up by eye."
  (let* ((want-lines (split-string (string-trim-right want "\n") "\n"))
         (got-lines (split-string (string-trim-right got "\n") "\n"))
         (differing (seq-filter
                     (lambda (n) (not (equal (nth n want-lines) (nth n got-lines))))
                     (number-sequence
                      0 (1- (max (length want-lines) (length got-lines)))))))
    (concat "Indentation does not match.\nExpected:\n"
            (lean-indent--render want-lines differing)
            "\nActual:\n"
            (lean-indent--render got-lines differing))))

(buttercup-define-matcher :to-indent-as (input expected)
  (let* ((got (lean-indent--reindent (funcall input)))
         (want (lean-utils--concatenate-lines (funcall expected))))
    (if (equal got want)
        (cons t "Expected the indentation not to match, but it did")
      (cons nil (lean-indent--report want got)))))

(defun lean-indent-test (input expected)
  (expect input :to-indent-as expected))

(defun lean-indent--tab-stop-columns (input n)
  "Press TAB N times at the marker in INPUT, collecting the column after each.

`call-interactively' alone does not update `last-command'/`this-command'
-- only the top-level command loop does that -- so a repeated press has
to be simulated by hand here to exercise cycling at all."
  (with-temp-buffer
    (let ((lean-use-treesitter t)
          (indent-tabs-mode nil)
          last-command this-command)
      (lean-mode)
      (lean-utils--insert-and-set-point input lean-indent-test-marker)
      (mapcar (lambda (_)
                (setq this-command #'indent-according-to-mode)
                (call-interactively #'indent-according-to-mode)
                (setq last-command this-command)
                (current-indentation))
              (number-sequence 1 n)))))

(defun lean-indent-tab-stop-test (input columns)
  (expect (lean-indent--tab-stop-columns input (length columns)) :to-equal columns))

(describe "indentation"

  (describe "on a blank line"

    (it "resets after complete command"
      (lean-indent-test '("variable {a : ℝ}" "  ‸")
                        '("variable {a : ℝ}" "")))

    (it "increases after \"by\""
      (lean-indent-test '("theorem {a : ℝ} : a = a := by" "‸")
                        '("theorem {a : ℝ} : a = a := by" "  ")))

    (it "remains the same within a tactics block"
      (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "‸")
                        '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "    ")))

    (it "increases after nested \"by\""
      (lean-indent-test '("example : Nat := by"
                          "  have : Type := by"
                          "‸")
                        '("example : Nat := by"
                          "  have : Type := by"
                          "    ")))

    (it "increases in a focus block"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · intro x y"
                          "‸")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · intro x y"
                          "    ")))

    (it "does not increase after closing a goal"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "‸")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "  ")))

    (it "increases in a proof term"
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ "
                          "‸")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ "
                          "    "))
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "‸")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "    ")))

    (it "increases after \"do\""
      (lean-indent-test '("def main : IO Unit := do"
                          "‸")
                        '("def main : IO Unit := do"
                          "  ")))

    (it "remains the same within a do block"
      (lean-indent-test '("def main : IO Unit := do"
                          "  IO.println 1"
                          "‸")
                        '("def main : IO Unit := do"
                          "  IO.println 1"
                          "  ")))

    (it "increases after \"where\""
      (lean-indent-test '("instance : Foo Bar where"
                          "‸")
                        '("instance : Foo Bar where"
                          "  ")))

    (it "remains the same within a where block"
      (lean-indent-test '("instance : Foo Bar where"
                          "  f := 1"
                          "‸")
                        '("instance : Foo Bar where"
                          "  f := 1"
                          "  ")))

    (it "remains the same within a structure instance"
      (lean-indent-test '("def p : Point := {"
                          "  x := 1"
                          "‸")
                        '("def p : Point := {"
                          "  x := 1"
                          "  ")))

    (it "remains the same within a match"
      (lean-indent-test '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "‸")
                        '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "  "))
      (lean-indent-test '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "  | 0 => 1"
                          "‸")
                        '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "  | 0 => 1"
                          "  ")))

    (it "remains the same within a \"cases\" tactic"
      (lean-indent-test '("example : True := by"
                          "  cases i with"
                          "‸")
                        '("example : True := by"
                          "  cases i with"
                          "  "))
      (lean-indent-test '("example : True := by"
                          "  cases i with"
                          "  | original i => trivial"
                          "‸")
                        '("example : True := by"
                          "  cases i with"
                          "  | original i => trivial"
                          "  ")))

    ;; The tactic-position `match' keyword parses to the same "match"
    ;; token as the term-level construct, so it already falls under the
    ;; bare "match" entry above without any change there.
    (it "remains the same within a tactic-position \"match\""
      (lean-indent-test '("example (n : Nat) : True := by"
                          "  match n with"
                          "‸")
                        '("example (n : Nat) : True := by"
                          "  match n with"
                          "  "))
      (lean-indent-test '("example (n : Nat) : True := by"
                          "  match n with"
                          "  | 0 => trivial"
                          "‸")
                        '("example (n : Nat) : True := by"
                          "  match n with"
                          "  | 0 => trivial"
                          "  ")))

    (it "remains the same within a run of bindings"
      (lean-indent-test '("def f : Nat :="
                          "  let x := 1"
                          "‸")
                        '("def f : Nat :="
                          "  let x := 1"
                          "  ")))

    (it "remains the same within a structure body"
      (lean-indent-test '("structure Point where"
                          "  x : Nat"
                          "‸")
                        '("structure Point where"
                          "  x : Nat"
                          "  ")))

    (it "remains the same within an inductive body"
      (lean-indent-test '("inductive Tree where"
                          "  | leaf : Tree"
                          "‸")
                        '("inductive Tree where"
                          "  | leaf : Tree"
                          "  ")))

    (it "returns to the margin after decoration"
      (lean-indent-test '("@[simp]"
                          "‸")
                        '("@[simp]"
                          ""))
      (lean-indent-test '("/-- Doc. -/"
                          "‸")
                        '("/-- Doc. -/"
                          "")))

    (it "increases after an open delimiter"
      (lean-indent-test '("def xs : List Nat := ["
                          "‸")
                        '("def xs : List Nat := ["
                          "  ")))

    (it "aligns under the first element"
      (lean-indent-test '("def xs : List Nat :="
                          "  [ 1,"
                          "‸")
                        '("def xs : List Nat :="
                          "  [ 1,"
                          "    "))))

  (describe "in the middle of an expression"

    (it "resets after complete command"
      (lean-indent-test '("variable {a : ℝ}"
                          "  ‸variable {b : ℝ}")
                        '("variable {a : ℝ}"
                          "variable {b : ℝ}")))

    (it "increases after \"by\""
      (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                          "‸rfl")
                        '("theorem {a : ℝ} : a = a := by"
                          "  rfl")))

    ;; Same shape as the do-block and bare-tactic cases below: `sorry'
    ;; over-indented past `intro x y' is just a third bare argument of
    ;; `intro', with no "new tactic" parse on offer, so it hangs
    ;; aligned under the first argument instead of pulling back to
    ;; `intro''s own column.
    (it "hangs an over-indented statement in a tactics block"
      (lean-indent-test '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "      ‸sorry")
                        '("theorem {a : ℝ} : a = a := by"
                          "    intro x y"
                          "            sorry")))

    (it "increases for proof body"
      (lean-indent-test '("theorem {a : ℝ} : a = a :="
                          "‸by")
                        '("theorem {a : ℝ} : a = a :="
                          "  by"))
      (lean-indent-test '("def Foo :="
                          "‸∀ y ∈ s, f (y - x) ≤ 0")
                        '("def Foo :="
                          "  ∀ y ∈ s, f (y - x) ≤ 0")))

    (it "increases more for proof header"
      (lean-indent-test '("theorem {a : ℝ} :"
                          "‸a = a := by")
                        '("theorem {a : ℝ} :"
                          "    a = a := by"))
      (lean-indent-test '("theorem {a : ℝ}"
                          "‸: a = a := by")
                        '("theorem {a : ℝ}"
                          "    : a = a := by"))
      ;; (lean-indent-test '("lemma Bar : ∃ f,"
      ;;                     "  ‸∃ p, f p ≠ 0 := by"
      ;;                     "  exact trivial")
      ;;                   '("lemma Bar : ∃ f,"
      ;;                     "    ∃ p, f p ≠ 0 := by"
      ;;                     "  exact trivial"))
      )

    (it "aligns a wrapped binder under the first one"
      (lean-indent-test '("theorem foo (a : Nat)"
                          "    ‸(b : Nat) :"
                          "    a = a := by"
                          "  rfl")
                        '("theorem foo (a : Nat)"
                          "            (b : Nat) :"
                          "    a = a := by"
                          "  rfl"))
      (lean-indent-test '("theorem foo (a : Nat) (b : Nat)"
                          "    ‸(c : Nat) :"
                          "    a = a := by"
                          "  rfl")
                        '("theorem foo (a : Nat) (b : Nat)"
                          "            (c : Nat) :"
                          "    a = a := by"
                          "  rfl")))

    (it "increases like any other header line when the first binder itself wraps"
      (lean-indent-test '("theorem foo"
                          "‸(a : Nat) :"
                          "    a = a := by"
                          "  rfl")
                        '("theorem foo"
                          "    (a : Nat) :"
                          "    a = a := by"
                          "  rfl")))

    (it "correctly handles proof header and body"
      (lean-indent-test '("theorem {a : ℝ} :"
                          "    a = a :="
                          "‸by")
                        '("theorem {a : ℝ} :"
                          "    a = a :="
                          "  by")))

    (it "increases after nested \"by\""
      (lean-indent-test '("example : Nat := by"
                          "  have : Type := by"
                          "‸foo")
                        '("example : Nat := by"
                          "  have : Type := by"
                          "    foo")))

    (it "increases in a focus block"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · -- a comment keeps the block open"
                          "  ‸done")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · -- a comment keeps the block open"
                          "    done")))

    (it "does not increase after closing a goal"
      (lean-indent-test '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "    ‸intro x y"
                          "  done")
                        '("example : true ↔ true := by"
                          "  constructor"
                          "  · done"
                          "  intro x y"
                          "  done")))

    (it "increases inside a function application"
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦"
                          "‸g x")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦"
                          "    g x"))
      (lean-indent-test '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "‸x")
                        '("def Foo : ℝ → ℝ :="
                          "  fun x ↦ g"
                          "    x")))

    (it "increases after \"do\""
      (lean-indent-test '("def main : IO Unit := do"
                          "‸IO.println 1")
                        '("def main : IO Unit := do"
                          "  IO.println 1")))

    ;; As with the tactic case below, `IO.println 1' followed by an
    ;; over-indented `IO.println 2' has no "new statement" parse
    ;; available at all -- it is `IO.println' applied to three bare
    ;; arguments (`1', `IO.println', `2') -- so this hangs as a
    ;; continued argument, aligned under the first one, rather than
    ;; pulling back to `IO.println''s own column.
    (it "hangs an over-indented statement in a do block"
      (lean-indent-test '("def main : IO Unit := do"
                          "  IO.println 1"
                          "      ‸IO.println 2")
                        '("def main : IO Unit := do"
                          "  IO.println 1"
                          "             IO.println 2")))

    ;; TODO: column 0 closes the layout block, so the parser sees a
    ;; top-level fragment rather than an under-indented do element.
    ;; (it "raises an under-indented do element"
    ;;   (lean-indent-test '("def main : IO Unit := do"
    ;;                       "  IO.println 1"
    ;;                       "‸IO.println 2")
    ;;                     '("def main : IO Unit := do"
    ;;                       "  IO.println 1"
    ;;                       "  IO.println 2")))

    (it "increases after \"where\""
      (lean-indent-test '("instance : Foo Bar where"
                          "‸f := 1")
                        '("instance : Foo Bar where"
                          "  f := 1")))

    (it "remains the same in a where block"
      (lean-indent-test '("instance : Foo Bar where"
                          "  f := 1"
                          "      ‸g := 2")
                        '("instance : Foo Bar where"
                          "  f := 1"
                          "  g := 2")))

    (it "remains the same in a structure instance"
      (lean-indent-test '("def p : Point := {"
                          "‸x := 1"
                          "}")
                        '("def p : Point := {"
                          "  x := 1"
                          "}"))
      (lean-indent-test '("def p : Point := {"
                          "  x := 1"
                          "      ‸y := 2"
                          "}")
                        '("def p : Point := {"
                          "  x := 1"
                          "  y := 2"
                          "}")))

    (it "aligns a closing brace with its opener"
      (lean-indent-test '("def p : Point := {"
                          "  x := 1"
                          "  ‸}")
                        '("def p : Point := {"
                          "  x := 1"
                          "}")))

    (it "aligns match arms with the match"
      (lean-indent-test '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "      ‸| 0 => 1")
                        '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "  | 0 => 1"))
      (lean-indent-test '("def f : Nat → Nat :="
                          "  fun"
                          "‸| 0 => 1")
                        '("def f : Nat → Nat :="
                          "  fun"
                          "  | 0 => 1")))

    (it "increases in the body of a match arm"
      (lean-indent-test '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "  | 0 =>"
                          "‸someExpression")
                        '("def f (n : Nat) : Nat :="
                          "  match n with"
                          "  | 0 =>"
                          "    someExpression")))

    (it "aligns cases arms with the \"cases\" tactic"
      (lean-indent-test '("example : True := by"
                          "  cases i with"
                          "      ‸| extra => trivial")
                        '("example : True := by"
                          "  cases i with"
                          "  | extra => trivial")))

    (it "increases in the body of a cases arm"
      (lean-indent-test '("example : True := by"
                          "  cases i with"
                          "  | original i =>"
                          "‸exact foo")
                        '("example : True := by"
                          "  cases i with"
                          "  | original i =>"
                          "    exact foo")))

    ;; `tactic_match_arm' is the tactic-position counterpart of
    ;; `match_arm', new since the grammar picked up real tactic-position
    ;; `match' support -- same flat-run-of-arms shape as `match_arm' and
    ;; `cases_arm', so it belongs in the same `lean-ts-arm-nodes' list.
    (it "aligns tactic-position match arms with the \"match\""
      (lean-indent-test '("example (n : Nat) : True := by"
                          "  match n with"
                          "      ‸| 0 => trivial")
                        '("example (n : Nat) : True := by"
                          "  match n with"
                          "  | 0 => trivial")))

    (it "increases in the body of a tactic-position match arm"
      (lean-indent-test '("example (n : Nat) : True := by"
                          "  match n with"
                          "  | 0 =>"
                          "‸exact foo")
                        '("example (n : Nat) : True := by"
                          "  match n with"
                          "  | 0 =>"
                          "    exact foo")))

    (it "increases once for a structure field"
      (lean-indent-test '("structure Point where"
                          "‸x : Nat")
                        '("structure Point where"
                          "  x : Nat")))

    (it "increases once for an inductive constructor"
      (lean-indent-test '("inductive Tree where"
                          "‸| leaf : Tree")
                        '("inductive Tree where"
                          "  | leaf : Tree")))

    (it "keeps a decorated declaration at the margin"
      (lean-indent-test '("@[simp]"
                          "  ‸theorem foo : True := by"
                          "  trivial")
                        '("@[simp]"
                          "theorem foo : True := by"
                          "  trivial"))
      (lean-indent-test '("/-- Doc. -/"
                          "  ‸theorem foo : True := by"
                          "  trivial")
                        '("/-- Doc. -/"
                          "theorem foo : True := by"
                          "  trivial")))

    (it "remains the same in a run of bindings"
      (lean-indent-test '("def f : Nat :="
                          "  let x := 1"
                          "    ‸let y := 2"
                          "  x + y")
                        '("def f : Nat :="
                          "  let x := 1"
                          "  let y := 2"
                          "  x + y")))

    (it "increases in the value of a tactic-position \"have\""
      (lean-indent-test '("example : True := by"
                          "  have hBig : a b :="
                          "‸someFunction c")
                        '("example : True := by"
                          "  have hBig : a b :="
                          "    someFunction c")))

    (it "aligns \"else\" with its \"if\""
      (lean-indent-test '("def f (n : Nat) : Nat :="
                          "  if n = 0 then"
                          "    1"
                          "      ‸else"
                          "    2")
                        '("def f (n : Nat) : Nat :="
                          "  if n = 0 then"
                          "    1"
                          "  else"
                          "    2")))

    (it "aligns an argument under the first one"
      (lean-indent-test '("def f : Nat :="
                          "  someFunction firstArg"
                          "    ‸secondArg")
                        '("def f : Nat :="
                          "  someFunction firstArg"
                          "               secondArg")))

    (it "increases once when the callee stands alone"
      (lean-indent-test '("def f : Nat :="
                          "  someFunction"
                          "‸firstArg")
                        '("def f : Nat :="
                          "  someFunction"
                          "    firstArg")))

    (it "increases once when a tactic's argument stands alone"
      ;; Lean's own layout rule needs the argument indented past "exact"
      ;; to parse as the tactic's `arg' at all, rather than a sibling
      ;; tactic or a token outside the `by' block entirely -- unlike the
      ;; other "increases once" cases above, so this starts from an
      ;; under-indented but still-valid column rather than column 0.
      (lean-indent-test '("example : True := by"
                          "  exact"
                          "   ‸someFunction c")
                        '("example : True := by"
                          "  exact"
                          "    someFunction c")))

    (it "aligns a list element under the first one"
      (lean-indent-test '("def xs : List Nat :="
                          "  [ 1,"
                          "‸2 ]")
                        '("def xs : List Nat :="
                          "  [ 1,"
                          "    2 ]")))

    (it "increases when an open delimiter ends the line"
      (lean-indent-test '("def p : Foo := ⟨"
                          "‸1,"
                          "  2⟩")
                        '("def p : Foo := ⟨"
                          "  1,"
                          "  2⟩")))

    ;; `exact bar' followed by an over-indented `exact baz' parses as
    ;; `exact' with three bare-identifier arguments (`bar', `exact',
    ;; `baz') -- there is no "new tactic" reading available at all, so
    ;; the line hangs as a continued argument rather than pulling back
    ;; to `exact''s own column.
    (it "hangs an over-indented tactic argument rather than pulling it back"
      (lean-indent-test '("theorem foo : True := by"
                          "  exact bar"
                          "      ‸exact baz")
                        '("theorem foo : True := by"
                          "  exact bar"
                          "    exact baz")))

    (it "hangs a wrapped tactic argument under the first one"
      (lean-indent-test '("example : True := by"
                          "  exact Set.disjoint_left.mp foo"
                          "    ‸bar baz")
                        '("example : True := by"
                          "  exact Set.disjoint_left.mp foo"
                          "                             bar baz")))

    (it "increases for the right operand of a trailing infix operator"
      (lean-indent-test '("example : Nat :="
                          "  1 +"
                          "‸2")
                        '("example : Nat :="
                          "  1 +"
                          "    2")))

    (it "aligns calc steps with \"calc\""
      (lean-indent-test '("example : Nat :="
                          "  calc 1"
                          "      ‸_ = 1 := rfl")
                        '("example : Nat :="
                          "  calc 1"
                          "  _ = 1 := rfl")))

    (it "increases from a bare \"calc\" when the first step starts its own line"
      (lean-indent-test '("example : Nat :="
                          "  calc"
                          "‸1 = 1 := rfl")
                        '("example : Nat :="
                          "  calc"
                          "    1 = 1 := rfl")))

    ;; Each step's own `by' proof used to leave the tactic block's
    ;; deeper column as the previous line, so the next step -- itself
    ;; already correctly aligned -- fell to the catch-all and inherited
    ;; that column instead of staying with its sibling steps.
    (it "remains aligned with \"calc\" after a multi-line step"
      (lean-indent-test '("example : True := by"
                          "  have h : True :="
                          "    calc True"
                          "    _ = True := by"
                          "      sorry"
                          "    ‸_ = True := by"
                          "      sorry")
                        '("example : True := by"
                          "  have h : True :="
                          "    calc True"
                          "    _ = True := by"
                          "      sorry"
                          "    _ = True := by"
                          "      sorry"))))

  (describe "in a malformed expression"

    (it "pins to the left column"
      (lean-indent-test '("variable {a : ℝ}"
                          "  var"
                          "‸def Foo : ℝ → ℝ := fun x ↦ g x")
                        '("variable {a : ℝ}"
                          "  var"
                          "def Foo : ℝ → ℝ := fun x ↦ g x")))))

(describe "tab-stop cycling"

  (it "cycles calc's first step through one-in, calc's own column, and the original column"
    (lean-indent-tab-stop-test
     '("example : Nat :="
       "  calc"
       "      ‸1 = 1 := rfl")
     '(4 2 6)))

  (it "wraps back around to the default on a fourth press"
    (lean-indent-tab-stop-test
     '("example : Nat :="
       "  calc"
       "      ‸1 = 1 := rfl")
     '(4 2 6 4)))

  (it "resets the cycle when point moves to a different line"
    (with-temp-buffer
      (let ((lean-use-treesitter t)
            (indent-tabs-mode nil)
            last-command this-command)
        (lean-mode)
        (lean-utils--insert-and-set-point
         '("example : Nat :="
           "  calc"
           "      ‸1 = 1 := rfl")
         lean-indent-test-marker)
        (setq this-command #'indent-according-to-mode)
        (call-interactively #'indent-according-to-mode)
        (setq last-command this-command)
        (forward-line -1)
        (end-of-line)
        (setq this-command #'indent-according-to-mode)
        (call-interactively #'indent-according-to-mode)
        (setq last-command this-command)
        (forward-line 1)
        (setq this-command #'indent-according-to-mode)
        (call-interactively #'indent-according-to-mode)
        (expect (current-indentation) :to-equal 4))))

  (it "cycles a first-of-kind match arm between the keyword's column and the original column"
    (lean-indent-tab-stop-test
     '("def f (n : Nat) : Nat :="
       "  match n with"
       "      ‸| 0 => 1")
     '(2 6 2 6)))

  (it "does not cycle a later arm, which has no deliberate-style reading to offer"
    (lean-indent-tab-stop-test
     '("def f (n : Nat) : Nat :="
       "  match n with"
       "  | 0 => 1"
       "      ‸| _ => 2")
     '(2 2))))

(provide 'lean-ts-test)
;;; lean-ts-test.el ends here
