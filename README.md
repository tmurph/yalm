# YALM — Yet Another Lean Mode

An Emacs major mode for the [Lean 4](https://lean-lang.org) programming
language and theorem prover. YALM combines the best parts of three
existing Lean modes — [Lean4-Mode](https://github.com/leanprover-community/lean4-mode),
[Nael](https://codeberg.org/mekeor/nael), and
[lean-ts-mode](https://github.com/lua-vr/lean-ts-mode) — built as much as
possible on Emacs' own core facilities (Eglot, Quail, `treesit`) rather than
reimplementing them.

## Features

- **Syntax highlighting** for Lean 4 keywords, types, numerals, and
  string/comment faces via `font-lock`.
- **LSP integration** through [Eglot](https://www.gnu.org/software/emacs/manual/html_node/eglot/)
  (the default) or `lsp-mode`, dispatched generically so either backend
  works without changing the rest of the mode.
- **Inline goal state**, shown through ElDoc: the tactic-state
  (`$/lean/plainGoal`) and expected-type (`$/lean/plainTermGoal`) LSP
  responses are fontified and composed into the ElDoc display as you move
  point — repurposing ElDoc the way Nael does, rendered through a
  dedicated infoview buffer the way Lean4-Mode does.
- **Math input method** (`lean-input`, descended from Agda's own Quail
  input method) for typing Lean's Unicode notation — active automatically
  in `lean-mode` buffers; customize via `M-x customize-group lean-input`,
  or list all translations with `lean-input-show-translations`.
- **Comment support** tuned to Lean's `--` line and `/- -/` block comment
  styles: `comment-dwim` (bound to `M-;` by default) cycles through
  comment styles, and continuing a block comment onto a new line indents
  and extends it automatically rather than starting a bare line.
- **Experimental tree-sitter indentation** (`lean-ts.el`, opt-in via
  `lean-use-treesitter`): a `treesit-simple-indent-rules` table driven by
  the [tree-sitter-lean](https://github.com/tmurph/tree-sitter-lean)
  grammar, covering `do`/`by`/`match`/`where` blocks, hanging arguments,
  binders, and more. For constructs where more than one indentation is a
  legitimate style choice (e.g. a `calc` step, or a `match` arm someone
  deliberately indented deeper than usual), pressing TAB again cycles
  through the other plausible columns instead of insisting on one answer.
  Under active development — see `CLAUDE.md` for the rule set's design
  principles and how the test suite is organized if you're extending it.

## Installation

YALM isn't (yet) published on MELPA. Clone it and point Emacs at the
checkout:

```elisp
(add-to-list 'load-path "/path/to/yalm")
(require 'lean-mode)
```

or, on Emacs 30+, install straight from the repository with
`use-package`'s built-in `:vc` keyword:

```elisp
(use-package lean-mode
  :vc (:url "https://github.com/tmurph/yalm.git" :rev :newest))
```

`.lean` files are then associated with `lean-mode` automatically. If
you're wiring this into a source-based package manager yourself, make
sure its recipe includes the `data` directory alongside the `.el` files —
`lean-input.el`'s translation table lives there, not in Lisp source.

### Dependencies

- Emacs 29.1 or later.
- [Eglot](https://www.gnu.org/software/emacs/manual/html_node/eglot/)
  ships with Emacs 29+, so no separate install is needed for the default
  LSP backend. `lsp-mode` is supported as an alternative if you prefer it.
- A working [Lean 4](https://lean-lang.org/lean4/doc/setup.html) toolchain
  (`lake`/`lean`) on your `PATH` — that's what the LSP backend talks to.
- Optional, for tree-sitter indentation: an Emacs build with tree-sitter
  support, and a compiled `tree-sitter-lean` grammar on
  `treesit-extra-load-path`. See
  [tree-sitter-lean](https://github.com/tmurph/tree-sitter-lean).

## Status

Font-lock, Eglot integration, and the input method are stable daily
drivers. Tree-sitter indentation is experimental and off by default; see
the TODO list below for what else is outstanding, and `CLAUDE.md` for
repository conventions (commit style, the Tim/Gary/Erica 
pipeline, running the test suite via `eldev test`).

# TODO
  * [x] comment continue
  * [x] font-lock
  * [x] tree sitter + tests
  * [ ] indentation
  * [ ] maybe paragraph filling?
  * [ ] moving by "defun"
  * [x] eglot
  * [ ] abbrev
  * [x] input method
  * [x] input method reverse lookup

# References
- https://github.com/lua-vr/lean-ts-mode
- https://github.com/leanprover-community/lean4-mode
- https://codeberg.org/mekeor/nael

## License

GPL-3.0-only overall (see `LICENSE`). Several files carry additional
copyright and license headers reflecting their upstream origin
(Lean4-Mode, Nael, and the Agda input method `lean-input.el` is descended
from) — see each file's header for specifics.
