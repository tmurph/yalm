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
   restatement of the diff. When the commit is backed by a GitHub issue
   (see "GitHub issue paper trail" below), keep this paragraph short —
   `See #N.` plus a sentence or two of context is enough; the comprehensive
   rationale (full reasoning, before/after examples, rejected alternatives)
   belongs in the issue reply, not the commit body, so a reader who wants
   that depth can opt into it there.
4. Blank line.
5. ChangeLog-style entries, one `* file (form): change.` line per top-level
   form touched, grouped by file. A few words per entry, not a paragraph —
   if an entry needs several sentences to justify itself, that belongs in
   the prose paragraph above (or the issue reply), not repeated per form.

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

**In-code comments assume a hurried reader.** Trim any explanation of a fix
down to a single-line pointer — `;; <short phrase> — see #N` — rather than
leaving paragraph-length rationale in the source. If a comment needs several
lines of prose to justify itself, first ask whether the rule could be
restructured so the need for that explanation goes away (a better-named
predicate, a narrower node-type list, reuse of an existing anchor function);
keep only a comment that survives that question. This is Erica's own
standard for judging Gary's work, and Gary should hold himself to it on the
first draft rather than leaving it for review to catch.

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

## GitHub issue paper trail

Adopted from the `~/code/agent-templates/tim-gary-erica` template (refined
on `tree-sitter-lean` across dozens of real bugs): every Tim → Gary → Erica
unit of work gets a real GitHub issue on `tmurph/yalm`, not just a commit
message. Commit messages stay terse (see above); the issue thread is where
comprehensive detail — full reasoning, before/after examples, rejected
alternatives — actually lives, for a reader who opts into that depth.

1. **Tim** reports a bug (or a swept-and-clean result). His final response
   IS the report — he has no GitHub write access.
2. **The orchestrating session** (not Tim, not Gary) opens the issue: `gh
   issue create --repo tmurph/yalm`, using Tim's own write-up as the body
   (or close to it — his report is already written as GitHub-flavored
   Markdown for exactly this). For infra/maintenance work with no Tim
   report behind it, a plain unpersonified issue is fine — don't manufacture
   a voice for it.
3. **Gary** is dispatched with the bug report and the issue number. He
   patches, verifies, commits (one commit per bug, referencing `See #N.` in
   the commit's prose paragraph), then posts the fuller rationale as a
   reply on the issue — `gh issue comment N --repo tmurph/yalm`. He does
   **not** close the issue; Erica's turn hasn't happened yet.
4. **Erica** reviews the specific commit she's pointed at and posts a reply
   either way: a plain `LGTM` (no commit, nothing to add) or a description
   of what she amended and why (if she committed on top). She does not
   close the issue either.
5. **The orchestrating session** closes the issue only after Erica's turn
   is fully done, once the branch-flow steps above land the work on
   `feature-indent`. Closing right after Gary's commit, before Erica has
   weighed in, is the single most common mistake here — don't.

Only the orchestrating session calls `gh issue create` / `gh issue close`.
Gary and Erica only ever `gh issue comment`.

**Never backslash-escape a backtick inside a `gh issue create`/`comment`
body.** Use `--body "$(cat <<'EOF' ... EOF)"` — a *quoted* heredoc
delimiter does zero shell escape processing, so a literal `` \` `` typed
into the body passes straight through and GitHub renders it as plain text
instead of a code span (and mangles identifier-heavy text into distracting
italics on top of that). Write backticks bare: `` `like_this` ``. The only
place a backtick genuinely needs escaping is a plain double-quoted shell
argument (`--title "...`), where bash would otherwise attempt command
substitution — don't over-apply that habit to a quoted heredoc body. If
ever unsure what actually got stored, check with `gh api
repos/tmurph/yalm/issues/N --jq '.body'`.

**Not retroactive.** The 22 commits already on `feature-indent` from before
this convention was adopted have no issues behind them, and that's fine —
backfilling issues for already-reviewed, already-stable history is exactly
the kind of busywork the template's own "fallback" procedure warns against
manufacturing unless the lack of a paper trail is actually causing a
problem. This applies going forward, starting with the next Tim report.

## Design principle: trust the parse tree, not assumed intent

When an indent rule's correctness depends on what the user "meant" rather
than what the grammar actually produced, resolve it by checking the real
parse tree (`treesit-node-string` / `treesit-explore-mode`), not by
guessing. Concretely: if the tree shows a shape has only one legitimate
reading, indent for that reading, even if some other input the user might
have intended would want different treatment — a parser that can't
distinguish the two is a grammar gap to report upstream (see below) or
defer, not something an indent rule should paper over with a heuristic.
This resolved a real case: whether an over-indented tactic continuation
should snap back to a sibling statement's column or hang as an argument
turned out to have a definitive answer once the tree was actually
inspected — Lean's layout rule never gives an over-indented line a
"new statement" reading in tactic position, so pulling back to one was
fixing indentation for a parse shape that can't occur (see `b2ea3fb`).

This only applies once real content exists to parse. A blank line (the
user just pressed RET) has no tree yet for what they're about to type —
`lean-ts-empty-line-indent-rules` is necessarily predictive, not
tree-driven, and deliberately defaults to "you're starting a new
statement" for a blank line after a tactic, independent of whatever the
non-blank-line rules would do once real content lands there. Don't try to
unify these two rule sets' handling of the same shape; they're answering
different questions.

## Reporting `tree-sitter-lean` grammar gaps upstream

Indentation rules can only be as correct as the parse tree they key off
of. When a gap turns out to be a missing or wrong grammar node rather
than a missing indent rule, it belongs upstream in the `tree-sitter-lean`
grammar project (`~/code/tree-sitter-lean`), not worked around here.

That project runs its own long-lived orchestrating session as a separate
peer Claude Code session on this machine — find it with `ListAgents` (its
name changes across restarts, e.g. `tree-sitter-lean-c6`; look for
whatever's currently named `tree-sitter-lean-*`) and send a report with
`SendMessage`: a minimal repro, the actual (wrong) tree, and what a
correct tree should look like. That session has confirmed this is its
preferred inbox — prefer it over writing into
`tree-sitter-lean/.claude/agent-notes/tim.md`, which is that project's
own Tim's personal scratch file, not meant as an external inbox.

The authoritative parser Eldev builds against
(`~/.emacs.d/tree-sitter/libtree-sitter-lean.so`) is Trevor's to update by
hand — a grammar fix landing upstream doesn't reach this repo's tests
until he refreshes it (or explicitly says it's fine for a session to do
so; don't assume).

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
