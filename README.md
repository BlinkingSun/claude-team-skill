# claude-agent-team

A `/team` skill for [Claude Code](https://claude.com/claude-code) that runs a
task as a **multi-model agent team**: the session plans, an independent model
audits the plan before anything executes, tiered executor models implement,
and the independent model verifies the result against the plan before
integration.

```
                    ┌──────────────────────────────┐
                    │  your Claude Code session    │
                    │  ORCHESTRATOR                │
                    │  plan · assign · integrate   │
                    └───┬──────────────────────┬───┘
              specs +   │                      │  1. PLAN.md (pre-exec audit:
              worktrees │                      │     tiering + split advice)
             (post-     ▼                      ▼  2. diff (read-only verify)
              audit) ┌──────────────────┐   ┌──────────────────────────┐
                     │ EXECUTORS (tier) │   │ AUDITOR / VERIFIER       │
                     │ opus / sonnet /  │   │ a different model family │
                     │ haiku — Agent    │   │ (consult mode): audits   │
                     │ tool or          │   │ the plan, then pass/fail │
                     │ claude-ask -w    │   │ vs the spec              │
                     └────────┬─────────┘   └────────────┬─────────────┘
                              │        rework loop       │
                              └───────── findings ◄──────┘
```

Everything is **roster-driven**: one JSON file defines the members, who plans,
who audits, who executes at which difficulty tier, who verifies, and the
binding policies. Add or remove models by editing JSON — the skill never
hardcodes a member.

## Why

- **Plans get audited before they burn tokens.** A second model reviews the
  plan for risks and gaps, sanity-checks which executor tier each subtask
  deserves, and calls whether the work splits into independent pieces that
  two executors can run **in parallel** to finish sooner.
- **Independent verification.** The model that checks the work is never the
  model that wrote it — ideally a different model family entirely, with zero
  shared bias.
- **Budget tiering.** Mechanical work goes to cheap models, hard work to
  heavy ones, and (if you bring a second provider) audit/verify/research can
  run without consuming your Claude limits at all.
- **Hard safety rails.** Workers only ever touch scratch dirs or git
  worktrees; verifiers are read-only; only the orchestrating session may
  commit, sign, or deploy.

## Install

```bash
git clone https://github.com/BlinkingSun/claude-agent-team.git
cd claude-agent-team
./install.sh
```

The installer copies the skill to `~/.claude/skills/team/`, seeds
`~/agent-team/` with the roster template and the `claude-ask` bridge, and
never overwrites an existing `team.json`.

Then, inside any Claude Code session:

```
/team refactor the parser and add tests for the edge cases we discussed
```

### Requirements

- Claude Code CLI (`claude`) installed and authenticated.
- `python3` and `perl` on PATH (both ship with macOS; standard on Linux).
- Optional but recommended: a second-provider CLI wrapped per the
  [wrapper contract](#bring-your-own-second-model) for independent
  audit/verification. Without one, the skill falls back to using a different
  Claude model than the executor.

## How a run works

1. **PLAN** — the orchestrator decomposes the task into subtasks, classifies
   each hard/default/trivial, writes a `SPEC.md` per worker subtask and a
   master `PLAN.md`.
2. **AUDIT** — the roster's `plan_auditor` (read-only) reviews `PLAN.md` and
   returns: verdict (approve/revise), risks, gaps, an executor
   recommendation per subtask, and a **split call** — whether the plan
   divides into independent pieces for parallel executors. The auditor
   advises; the orchestrator decides, and deviations are reported. Capped at
   2 audit cycles.
3. **EXECUTE** — subtasks run on the assigned tier (native Agent tool
   in-session, or detached `claude-ask -w` sessions), in parallel when the
   audit approved a split, isolated in scratch dirs/worktrees.
4. **VERIFY** — the verifier (read-only, never the author) audits each
   result against its spec: pass/fail, deviations, bugs, gaps.
5. **REWORK** — findings go back to the same executor; re-verify on the same
   channel; ~3 cycles max before escalating.
6. **INTEGRATE** — the orchestrator reviews the final diff itself, merges,
   runs the real build/tests, and reports what each member did and what the
   audit/verifier caught.

## The roster (`~/agent-team/team.json`)

| Role | Default | Notes |
|---|---|---|
| `orchestrator` | the current session | plans, assigns, integrates; owns git/sign/deploy |
| `executor.hard` | opus | subtle/algorithmic work |
| `executor.default` | sonnet | general implementation |
| `executor.trivial` | haiku | mechanical edits, boilerplate |
| `plan_auditor` | second-provider (example, disabled) | pre-execution plan gate |
| `verifier` | second-provider (example, disabled) | post-execution pass/fail |

Editing the layout:

- **Add a model** — add a `members[]` block: `name`, `provider`, `model`,
  `invoke.method` (`agent-tool` | `claude-ask` | `current-session` | your own
  wrapper), `strengths`, `budget`, `enabled: true`.
- **Remove/bench a model** — set `enabled: false`. Fallbacks are defined in
  `policies`.
- **Rewire roles** — repoint `assignment` (orchestrator / executor tiers
  hard·default·trivial / plan_auditor / verifier / second_opinion /
  researcher).

Design invariants the skill enforces regardless of layout: every plan is
audited before execution starts (auditor advises, orchestrator decides);
verifier ≠ executor and read-only; workers only in scratch dirs/worktrees;
only the orchestrator commits/signs/deploys.

## claude-ask (the bundled bridge)

`bin/claude-ask` is a headless `claude -p` wrapper with persistent
per-channel sessions — for teammates that must outlive the session, run
detached, or be driven by scripts:

```bash
claude-ask -m opus  -w -c task-a -d ~/scratch/task-a "Implement per SPEC.md; run tests"
claude-ask -m sonnet   -c review  -d ~/proj "Any races in src/foo.c?"
claude-ask -c task-a "Test 3 fails — fix it"        # follow-up, same context
claude-ask --status -c task-a ; claude-ask --channels
```

`-n` new session · `-j` raw JSON · `-t` timeout secs · `-f` attach file.
Consult mode denies Bash/Edit/Write; worker mode (`-w`) runs with
`bypassPermissions` — **point it only at disposable directories**. Every call
is logged to `~/agent-team/logs/<channel>.jsonl` including per-call
`costUSD`, so spend is auditable.

Inside a live session, executors are normally spawned with the native Agent
tool (cheaper, results return inline); `claude-ask` is for detached work.

## Bring your own second model

The audit and verification roles work best with a **different model family**.
Any backend works if you wrap its CLI to expose the claude-ask interface:

- `-c NAME` — persistent conversation channel (follow-ups share context)
- `-w` — worker mode (may edit files/run commands); default is read-only consult
- `-d DIR` — working directory
- `-f PATH` — inline a file into the prompt
- plain-text reply on stdout, non-zero exit on error

Drop the wrapper on PATH (or in `~/agent-team/bin/`), add a `members[]` block
whose `invoke` shows the command shape, set `enabled: true`, and point
`plan_auditor` / `verifier` at it. Nothing else changes.

## Budget notes

- opus/sonnet/haiku consume your Claude plan — the skill tiers deliberately:
  haiku for mechanical work, sonnet by default, opus only when genuinely hard.
- A second-provider auditor/verifier consumes *its* plan, making audit,
  verification, and research free from the Claude budget's perspective.
- Headless `claude -p` calls are metered like any session; the JSONL logs
  record per-call cost so overruns are auditable.

## Layout

```
skill/SKILL.md   the /team protocol (installed to ~/.claude/skills/team/)
team.json        roster template     (installed to ~/agent-team/)
bin/claude-ask   headless Claude bridge (installed to ~/agent-team/bin/)
install.sh       installer
```

## License

MIT — see [LICENSE](LICENSE).
