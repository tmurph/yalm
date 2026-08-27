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

**Reach for `pcase`-family macros when they're a genuine structural fit** —
destructuring a `(MATCHER . CANDIDATES)`-shaped list, dispatching on a
node-type string, that kind of thing — rather than hand-rolling the
equivalent with `car`/`cdr`/`dolist`. Trevor's own stated preference,
demonstrated in `ec625dd`. Not a mandate to retrofit existing code that
already reads fine without it.

## Tim → Gary → Erica: the find → fix → review pipeline

Bug and feature work on yalm follows the same three-role pattern used in
the sibling `tree-sitter-lean` grammar project, adapted to this repo. It
started out scoped to `lean-ts.el` indentation rules and that's still
where it gets the heaviest use, but the pipeline itself isn't limited to
indentation — Tim can be pointed at font-lock, the Eglot/lsp-mode LSP
layer, the input method, comment handling, or anything else in the
codebase. Agent definitions live in `.claude/agents/{tim,gary,erica}.md`
(untracked, like this whole directory in the sibling project — treat them
as local tooling, not shipped code).

- **Tim** (read-only, works in this checkout): hunts for bugs and gaps
  anywhere in the codebase, exercising whatever's under test against known-
  correct input and looking for drift. Returns a structured report; never
  edits anything.
- **Gary** (`~/code/yalm-gary`, branch `gary/fix`): turns a Tim report (or a
  directly-specified bug/feature) into a fix plus a test, verifies with
  `eldev test`, and commits — one commit per unit of work, GNU changelog
  format, on his own branch. Doesn't wait for Erica between fixes.
- **Erica** (`~/code/yalm-erica`, branch `erica/review`): reviews a specific
  Gary commit for design consistency and simplicity against this file's own
  conventions, may amend and commit on top of it, reports a verdict.

(`gary/fix` was renamed from `gary/fix-indent-rules` once the pipeline's
scope broadened beyond indentation — the old name would otherwise show up
in merge-commit messages implying indentation-specific work that isn't
happening.)

Both worktrees exist so Gary/Erica never touch this checkout directly —
Trevor edits it live in a running Emacs session, and stepping on that is
worse here than the usual worktree-isolation rationale (races on shared
build artifacts) that motivated the same pattern in `tree-sitter-lean`.

Each worktree needs its own `Eldev-local` (untracked, not shared across
worktrees) pointing `treesit-extra-load-path` at the authoritative parser
— needed for any `eldev test` run that touches `lean-ts.el`, whether or not
the fix itself is indentation-related:

```elisp
(setq treesit-extra-load-path
      (list (expand-file-name "tree-sitter" "~/.emacs.d/")))
```

Without it, Eldev's sandboxed `user-emacs-directory` makes `eldev test`
silently fall back to whatever stale `libtree-sitter-lean.so` happens to be
on the system load path instead of `~/.emacs.d/tree-sitter/`, which Trevor
updates by hand — this caused a full session's worth of spurious test
failures once already.

**Branch flow is one-directional: `devel` only ever advances by pulling
Erica's reviewed tip, never the other way around.** Concretely:

1. Gary commits fixes on `gary/fix`.
2. Erica reviews (and may amend) on `erica/review`, built on top of Gary's
   commits.
3. The orchestrating session fast-forwards `devel` from `erica/review` —
   never commits new work directly onto `devel` that Erica hasn't seen,
   and never merges Gary's branch into `devel` directly, skipping her
   review.
4. Before Gary starts his next fix, his worktree pulls from `devel`
   (`git merge devel` from `~/code/yalm-gary`) — which by step 3 is always
   Erica's latest reviewed tip. He never builds on a base older than her
   last review. A clean fast-forward is the expected case; if Erica
   amended something Gary had already built on top of, the merge can
   conflict for real. When it does, her side wins on every conflicting
   hunk — she's the reviewed baseline, not a negotiation — and Gary adapts
   whatever of his own work that resolution invalidates in a follow-up
   commit.

Reconciling branches, and deciding when a batch is ready to fast-forward
into `main` (and for Trevor's attention), is the orchestrating session's
job, not something either agent does itself.

**Landing on `devel` does not imply landing on `main`.** Fast-forward
`devel` from `erica/review` as each unit of work clears review — that part
is routine and doesn't need to wait for Trevor. Fast-forwarding `main` from
`devel` and pushing to `origin/main` is a separate, later step that only
happens when Trevor explicitly asks for it, not automatically every time
`devel` advances. `devel` is where finished, reviewed work accumulates in
the meantime.

Two historical notes on the branch this pipeline lands on, neither of
which should recur:
- The initial round of indentation gaps 1–5 plus this pipeline's own
  infrastructure was done directly on `feature-indent` by the
  orchestrating session itself, before the worktree split existed — Gary
  and Erica were fast-forwarded to match afterward.
- `feature-indent`, not `devel`, was the pipeline's landing branch through
  the point where that initial indentation work shipped to `origin/main`.
  `main` and `devel` were fast-forwarded from `feature-indent`'s tip as
  part of that push, and `devel` — not `feature-indent` — is the landing
  branch for everything from that point on. `feature-indent` has since
  been deleted (its history is fully contained in `devel`/`main`); treat
  `devel` as the actual leading edge, with direct/ad hoc work committing
  straight onto it. Start a new feature branch only if some future unit of
  work genuinely needs the isolation — it's not the default anymore.

### Feature branches for larger units of work

Some units of work are big enough — multiple Gary commits, spanning more
than one Tim/Gary/Erica round-trip — to want the same isolation
`feature-indent` originally provided, without making every small bug fix
pay for it. When that's the case (the orchestrating session's judgment
call, same as everything else in this section):

1. Create a new branch off the current `devel` tip: `git branch
   feature-<slug> devel`. It doesn't need its own worktree — Gary and
   Erica keep using their existing worktrees, just pointed at a different
   landing branch for the duration.
2. Point Gary and Erica at `feature-<slug>` instead of `devel` for
   everything branch-flow-related: Gary syncs from it
   (`git merge feature-<slug>`) before each new commit, Erica's reviewed
   tip fast-forwards it, exactly the same one-directional flow and
   conflict policy as the normal `devel` case — just with `feature-<slug>`
   standing in for `devel` as the intermediate landing point. Say so
   explicitly in each dispatch; don't assume the agent infers it.
3. Fast-forwarding `feature-<slug>` itself as each commit clears review is
   routine, same as `devel` normally is. Fast-forwarding `devel` *from*
   `feature-<slug>` once the whole unit of work is done is not — that's
   the feature-branch equivalent of the `devel` → `main` decision above,
   and needs Trevor's go-ahead the same way.
4. Delete `feature-<slug>` once it's merged into `devel`, the same way
   `feature-indent` was.

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
   `devel`. Closing right after Gary's commit, before Erica has weighed
   in, is the single most common mistake here — don't.

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

**Not retroactive.** The 22 commits that landed on `feature-indent` (now
merged into `devel`/`main`) from before this convention was adopted have no
issues behind them, and that's fine — backfilling issues for already-
reviewed, already-stable history is exactly the kind of busywork the
template's own "fallback" procedure warns against manufacturing unless the
lack of a paper trail is actually causing a problem. This applies going
forward, starting with the next Tim report.

### Feature requests

Same paper trail, adapted for work that starts from a design rather than a
discovered bug — the lifecycle and roles run in a different order:

1. **The orchestrating session** creates the issue (`enhancement` label),
   using whatever design already exists — usually a design discussion had
   directly with Trevor — as the body. Unlike a bug report, Tim isn't the
   source of the initial write-up here.
2. **Tim** is dispatched to dive into implementation feasibility against
   the real codebase before Gary starts: verifying assumptions the design
   made (does the treesit API it relies on actually exist and behave as
   assumed? what are the concrete node types/candidate lists for the
   specific constructs in scope?), the same investigative rigor as a bug
   report. This becomes a **comment** on the issue, not the body — the
   body's already written.
3. **Gary** implements from the issue plus Tim's comment. Features are
   usually more than one commit — prioritize "one idea per commit" over
   cramming a whole feature into one, the same instinct as "one commit per
   bug" just acknowledging multiple commits is normal here. It's fine to
   implement part of a feature, commit what's solid, and post a comment
   describing what's done and what open question remains rather than
   guessing past a genuine ambiguity — that hands control back to the
   orchestrator to re-dispatch Tim for guidance on the open question,
   mirroring "if you can't find a fix that doesn't regress the suite, say
   so" from the bug-fix flow.
4. **Erica** reviews each of Gary's commits exactly the way she reviews
   bug fixes — same criteria, same per-commit cadence, nothing different.
5. **The orchestrating session** closes the issue once the feature (all
   its commits) has cleared Erica's review and landed, same timing rule as
   a bug fix.

Large features normally live on their own branch — see "Feature branches
for larger units of work" above; Gary/Erica sync with whatever branch
they're told for the current unit of work, not always `devel`.

Distinct issue templates for features vs. bugs aren't set up yet — not
needed for Tim to work effectively so far. Revisit if that changes; don't
build it speculatively ahead of an actual need.

## Design principle: trust the parse tree, not assumed intent

This applies to indentation/parser-dependent work on `lean-ts.el`
specifically — other corners of the codebase Tim/Gary/Erica now cover
don't have an equivalent parse tree to defer to, so this doesn't
generalize verbatim. The underlying instinct does, though: resolve a
design question by checking what the code/artifact actually does, not by
guessing at intent.

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

## Design principle: prefer a library's public extension points over its internals

Applies whenever a feature needs to hook into an Emacs subsystem
(`treesit`, but not only `treesit`) rather than just add rules to our own
tables. The bar for "this works" isn't just correct output — it's whether
there's a supported, public hook that does the job more directly, checked
*before* falling back to reimplementing or depending on a private (`--`)
function.

Concrete case this principle came from: the tab-stop-cycling feature
(issue #5) needed to plug custom logic into indentation-on-TAB. The first
implementation overrode `indent-line-function` wholesale and hand-copied
`treesit--indent-1`'s internal NODE/PARENT-finding logic
(`treesit--indent-largest-node-at`, private) to work around a real bug in
a naive `treesit-node-at` approach — Erica flagged the private-API
dependency as a review risk, correctly, but the fix under review was still
the best fix anyone had found at the time. Trevor's own rewrite found and
used `treesit-indent-function` instead — a real, public hook that lets you
supply just the ANCHOR/OFFSET decision while treesit's own `treesit-indent`
keeps doing the NODE/PARENT-finding, blank-line detection, and point
preservation itself. That didn't just avoid the private-API dependency, it
eliminated the entire class of bug Tim had found, at the root, instead of
working around it.

**How to apply:** when Tim does a feasibility check involving a library's
internals, explicitly search for the intended public hook first — don't
stop at "I found a way to make this work." When reviewing (Erica) or
implementing (Gary), treat "this duplicates or depends on private
internals" as a real design smell worth escalating, not a minor risk note
to mention in passing.

## Testing philosophy: interactive behavior only, not contrived interactive/non-interactive mixtures

Write a test for interactive-only behavior (anything keyed on
`last-command`/`this-command`, point position across commands, or other
state that only makes sense in a real editing session) only when the
scenario is reachable through an actual sequence of real commands — not
just through directly manipulating the variables a command happens to
read.

Concrete case: an early tab-stop-cycling test simulated pressing TAB,
jumping to a different line via a non-interactive `goto-char`, then
pressing TAB again while manually forcing `last-command`/`this-command`
equality — a sequence no real user interaction can produce. In genuine
interactive use, `(eq this-command last-command)` holding across two TAB
presses already implies nothing else ran in between, which already implies
point never left the line — so there was nothing left for the test to
guard against once traced through. The test passed by forcing a state
real interaction can't reach, not by validating real behavior.

**How to apply:** if a problem is likely to arise in normal interactive
use, write a test that demonstrates it through a real command sequence. If
an issue only arises by mixing interactive and non-interactive invocation
to force a state, don't write a preemptive guard for it — implement the
simplest correct thing and wait for an actual bug report if it turns out
to matter. Applies to Tim (don't manufacture this class of finding), Gary
(don't add defensive code for it), and Erica (don't ask for a test of it
in review) alike.

## Reporting `tree-sitter-lean` grammar gaps upstream

Applies specifically when Tim's work touches `lean-ts.el`/the
tree-sitter-lean grammar — not relevant to other domains the pipeline now
covers. Indentation rules can only be as correct as the parse tree they key
off of. When a gap turns out to be a missing or wrong grammar node rather
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

At the end of a work session, if Erica signed off clean on everything (a
plain `LGTM` on every commit, nothing amended, no concerns raised), it's
fine to run this without checking with Trevor first — he sees the
`lean-ts-reload` confirmation message in his echo area. If Erica raised any
concern or amended anything, or the picture is mixed, ask first as usual.
