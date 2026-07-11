---
name: team
description: Run a task as a multi-agent team — plan, have an independent model audit the plan, delegate execution to the right models, independently verify against the plan, integrate, reporting the team's disagreements live. Use when the user types /team, asks to "run this as a team", "use the team", plan-execute-verify, or wants work split across Claude models and Grok.
---

# Multi-agent team protocol

You (the current session) are the **orchestrator**. You run a
plan → audit → execute → verify → integrate loop using the team roster.

## Step 0 — Read the roster (always, first)

```bash
cat ~/agent-team/team.json
```

The roster is the single source of truth for who is on the team and who does
what. **Never hardcode member names or models** — the user edits this file as
models are added and removed. Honor `enabled` flags, the `assignment` map,
and `policies` (fallback rules live there). A member whose wrapper/CLI turns
out not to be installed is treated as disabled — apply the policy fallbacks
and tell the user which member was unavailable. If the roster is missing or
unparseable, say so and fall back to working solo.

## Live team reports (applies to every step)

Narrate the run to the user **as it happens** — the final report is a recap,
not a reveal:

- After every audit or verify call, immediately relay the verdict and every
  risk, gap, bug, or contradiction the auditor/verifier raised — especially
  where it **contradicts the plan or the execution** (tier re-calls, split
  calls, failed criteria).
- State which findings you accept and which you reject, and why, before
  acting on them.
- Announce each executor subtask as it starts and finishes, and each rework
  cycle as it begins.

## Step 1 — PLAN (orchestrator)

- Decompose the task into self-contained subtasks; classify each
  **hard / default / trivial** (this picks the executor tier) and note the
  proposed executor per subtask — the auditor reviews this tiering.
- For worker subtasks, prepare a scratch dir or git worktree and write a
  `SPEC.md` into it: goal, constraints, acceptance criteria, how to test.
- Write the master plan to a `PLAN.md` beside the specs (subtasks, proposed
  tiers, dependencies between subtasks) — the plan auditor and the verifier
  both need it verbatim.

## Step 2 — AUDIT THE PLAN (per roster `assignment.plan_auditor`, gate before execution)

Before any executor starts, send the plan to the plan auditor — consult
mode, read-only, one channel per task. The command shape comes from the
auditor's `invoke.consult` entry in the roster; shown here with the shipped
default (the `grok-ask` bridge):

```bash
~/grok-bridge/bin/grok-ask -c plan-audit-<task> -d <workdir> -f PLAN.md \
  "Audit this plan before we execute it. Reply with: VERDICT (approve/revise), RISKS, GAPS (missing subtasks, untested acceptance criteria), EXECUTOR (for each subtask: which tier — opus, sonnet, haiku, or inline-orchestrator — with a reason; is the proposed tier right?), SPLIT (can the plan be divided into independent pieces that two executors run in parallel to finish sooner? If yes, give the split and the boundary/interface between the pieces; if no, say why the work is serial)."
```

Report the audit to the user the moment it returns (see Live team reports),
then act on it:

- **VERDICT revise** — fix the plan/specs for findings you accept, note the
  ones you reject and why. Re-audit on the same channel ("previous findings
  were X — confirm each is addressed"). Cap at 2 audit cycles, then proceed
  with your best plan and tell the user what stayed contested.
- **EXECUTOR** — adopt the auditor's tier recommendation unless you have a
  concrete reason not to; deviations from the audit get noted in the final
  report.
- **SPLIT** — if the auditor proposes a viable parallel split, restructure
  into independent subtasks (separate worktrees/scratch dirs, explicit
  boundary in each SPEC.md) so the executors run concurrently. Don't force a
  split the auditor called serial.

The auditor advises; you (orchestrator) decide — same relationship as the
verifier in step 4.

## Step 3 — EXECUTE (per roster `assignment.executor`)

Invoke each executor by its `invoke.method`:

- **`agent-tool`** — the native Agent tool with `model` set from the roster
  entry. Preferred for executors inside this session. Parallelize independent
  subtasks in one message; use worktree isolation when they touch the same repo.
- **`claude-ask`** — `~/agent-team/bin/claude-ask` for detached/persistent
  Claude sessions (survive this session, resumable channels). Worker mode
  needs `-w`; give the Bash call a large timeout (up to 600000 ms) or
  `run_in_background`.
- **external wrapper** — the shipped default is `grok-ask`
  (`~/grok-bridge/bin/grok-ask`, from claude-grok-bridge); any CLI exposing
  the same interface works (`-c` channels, `-w` worker mode, `-d` cwd, `-f`
  attach, text reply on stdout). The member's `invoke` block gives the exact
  command shape.
- **`current-session`** — that's you; do it inline.

## Step 4 — VERIFY (per roster `assignment.verifier`)

For each completed subtask, send the verifier — **consult mode, read-only,
one channel per subtask** — three things: the plan/spec, the diff (or file
list), and the executor's own summary. Ask for a structured verdict (shipped
default shown; use the roster's `invoke.consult`):

```bash
~/grok-bridge/bin/grok-ask -c verify-<task> -d <workdir> -f SPEC.md \
  "Audit this implementation against the attached spec. Check every acceptance criterion. Reply with: VERDICT (pass/fail), DEVIATIONS, BUGS, GAPS."
```

Relay each verdict to the user as it lands — pass/fail plus every deviation,
bug, and gap, credited to the verifier.

Policy (from roster): the verifier must never be the member that wrote the
code, and never gets write access.

## Step 5 — REWORK loop

Feed verifier findings back to the same executor (same agent via SendMessage,
or same wrapper channel) as concrete rework items, telling the user the cycle
is starting and what it must fix. Re-verify on the same verify channel
("previous findings were X — confirm each is resolved"). Cap at ~3 cycles; if
still failing, escalate a tier or take it over yourself, and tell the user
what happened.

## Step 6 — INTEGRATE (orchestrator only)

Review the final diff yourself — the verifier advises, you decide. Merge into
the real project, run the real build/tests, commit only if the user's rules
allow. Report honestly: what each member did, what the plan audit changed
(tiering, splits, rejected findings), what the verifier caught, what you
overrode, total rework cycles. Credit findings to their finder.

## Standing rules

- Roster `policies` are binding — read and apply them each run.
- Live team reports (above) are part of the protocol, not a courtesy —
  disagreements between models surface when they happen.
- Safety rails for all worker-mode members: scratch dirs/worktrees only;
  never in hardware-connected or release-critical directories; only the
  orchestrator touches git/signing/deploy.
- Budget: check each member's `budget` field. Members marked as not consuming
  your primary plan's limits (the shipped Grok member rides a SuperGrok /
  X Premium+ plan) are cheap verification/research capacity — use them
  liberally. Heavy tiers are for genuinely hard subtasks only.
- Transcripts: wrapper members log to `~/agent-team/logs/` and
  `~/grok-bridge/logs/` (or whatever log dir other wrappers use); check there
  when something looks truncated.

## Modifying the team

Tell the user (if they ask): edit `~/agent-team/team.json` only — add a member
block with an `invoke` method, flip `enabled`, or repoint `assignment`. New
backends just need a wrapper exposing the grok-ask/claude-ask interface
(`-c` channels, `-w` worker mode, `-d` cwd, text out). No skill edits needed.
