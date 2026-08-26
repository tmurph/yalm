# yalm — working conventions

Yet Another Lean Mode: an Emacs Lisp package for Lean 4, with an
experimental tree-sitter indentation mode (`lean-ts.el`) under active
development.

## Commit messages: GNU-style changelog

Every commit follows the GNU ChangeLog-in-commit-message convention (the
same one Emacs core itself uses):

1. One-line summary, active/imperative voice, no trailing period.
2. Blank line.
3. A short prose paragraph: what changed and *why* — the motivation, not a
   restatement of the diff.
4. Blank line.
5. ChangeLog-style entries, one `* file (form): change.` line per top-level
   form touched, grouped by file. A few words per entry, not a paragraph —
   if an entry needs several sentences to justify itself, that belongs in
   the prose paragraph above, not repeated per form.

Worked example:

```
Add rules for match arms and structure fields

Both previously fell through to the generic continuation offset, so
every arm after the first, or every field after the first,
over-indented by one step per line.  Key the new rules off the
grammar's own match_arm/structure_field/constructor node types
rather than reasoning about siblings by hand.

* lean-ts.el (lean-ts-indent-rules): Add rules for match_arm,
structure_field, constructor.
* test/lean-ts-test.el (lean-indent-test): Add specs for match arms
and structure fields, blank-line and mid-expression cases.
```

Only create commits when explicitly asked, one topic per commit — this
applies to Claude sessions working here directly; the `gary`/`erica` agents
below commit autonomously within their own scope, by design (see below).

## `lean-ts.el` indentation work: Tim → Gary → Erica

Indentation-rule work on `lean-ts.el` follows the same three-role pattern
used in the sibling `tree-sitter-lean` grammar project, adapted to this
repo. Agent definitions live in `.claude/agents/{tim,gary,erica}.md`
(untracked, like this whole directory in the sibling project — treat them
as local tooling, not shipped code).

- **Tim** (read-only, works in this checkout): hunts for indentation gaps by
  re-indenting known-correct Lean snippets and looking for drift. Returns a
  structured report; never edits `lean-ts.el` or the tests.
- **Gary** (`~/code/yalm-gary`, branch `gary/fix-indent-rules`): turns a
  Tim report into a rule fix plus a buttercup spec, verifies with `eldev
  test`, and commits — one commit per fix, GNU changelog format, on his own
  branch. Doesn't wait for Erica between fixes.
- **Erica** (`~/code/yalm-erica`, branch `erica/review`): reviews a specific
  Gary commit for design consistency and simplicity against this file's own
  conventions, may amend and commit on top of it, reports a verdict.

Both worktrees exist so Gary/Erica never touch this checkout directly —
Trevor edits it live in a running Emacs session, and stepping on that is
worse here than the usual worktree-isolation rationale (races on shared
build artifacts) that motivated the same pattern in `tree-sitter-lean`.

Each worktree needs its own `Eldev-local` (untracked, not shared across
worktrees) pointing `treesit-extra-load-path` at the authoritative parser:

```elisp
(setq treesit-extra-load-path
      (list (expand-file-name "tree-sitter" "~/.emacs.d/")))
```

Without it, Eldev's sandboxed `user-emacs-directory` makes `eldev test`
silently fall back to whatever stale `libtree-sitter-lean.so` happens to be
on the system load path instead of `~/.emacs.d/tree-sitter/`, which Trevor
updates by hand — this caused a full session's worth of spurious test
failures once already.

**Branch flow is one-directional: `feature-indent` only ever advances by
pulling Erica's reviewed tip, never the other way around.** Concretely:

1. Gary commits fixes on `gary/fix-indent-rules`.
2. Erica reviews (and may amend) on `erica/review`, built on top of Gary's
   commits.
3. The orchestrating session fast-forwards `feature-indent` from
   `erica/review` — never commits new indentation-rule work directly onto
   `feature-indent` that Erica hasn't seen, and never merges Gary's branch
   into `feature-indent` directly, skipping her review.
4. Before Gary starts his next fix, his worktree pulls from `feature-indent`
   (`git merge feature-indent` from `~/code/yalm-gary`) — which by step 3 is
   always Erica's latest reviewed tip. He never builds on a base older than
   her last review. A clean fast-forward is the expected case; if Erica
   amended something Gary had already built on top of, the merge can
   conflict for real. When it does, her side wins on every conflicting
   hunk — she's the reviewed baseline, not a negotiation — and Gary adapts
   whatever of his own work that resolution invalidates in a follow-up
   commit.

Reconciling branches and deciding when a batch is ready for Trevor's
attention is the orchestrating session's job, not something either agent
does itself. (One-off exception: the initial round of gaps 1–5 plus this
infrastructure was done directly on `feature-indent` by the orchestrating
session itself, before this worktree split existed — Gary and Erica were
fast-forwarded to match afterward. That shouldn't recur; going forward, all
lean-ts.el indentation-rule changes go through the Gary → Erica →
`feature-indent` flow above.)

## Hot-reloading `lean-ts.el` into a running Emacs

`lean-ts-reload` (defined in `lean-ts.el`) picks up a landed change without
restarting Emacs:

```
emacsclient -e '(lean-ts-reload)'
```

A plain `(load 'lean-ts)` is not enough on its own: a buffer that already
ran `lean-ts-setup` holds a buffer-local snapshot of
`treesit-simple-indent-rules`, not a live reference, so reloading the file
alone doesn't affect buffers already open. `lean-ts-reload` reloads the
file and then re-runs `lean-ts-setup` in every `lean-mode` buffer already
using tree-sitter, and reports how many it refreshed.

Only run this after a change has actually landed and been reviewed — it
takes effect in Trevor's live editing session immediately.
