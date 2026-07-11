# Claude /team skill

A `/team` skill for [Claude Code](https://claude.com/claude-code) that runs a
task as a **multi-model agent team**, powered by **Claude Fable 5** and
**Grok 4.5**: Fable plans and integrates, an independent Grok model audits the
plan before anything executes, tiered Claude executors implement, and Grok
verifies the result against the plan before integration.

The payoff is **Ultracode-like multi-agent performance at a fraction of the
token usage**: the adversarial passes — plan audit, verification, second
opinions, research — ride your Grok plan (SuperGrok / X Premium+), so your
Claude tokens go only to planning and execution.

```
                    ┌──────────────────────────────┐
                    │  your Claude Code session    │
                    │  ORCHESTRATOR · Fable 5      │
                    │  plan · assign · integrate   │
                    └───┬──────────────────────┬───┘
              specs +   │                      │  1. PLAN.md (pre-exec audit:
              worktrees │                      │     tiering + split advice)
             (post-     ▼                      ▼  2. diff (read-only verify)
              audit) ┌──────────────────┐   ┌──────────────────────────┐
                     │ EXECUTORS (tier) │   │ AUDITOR / VERIFIER       │
                     │ opus / sonnet /  │   │ Grok 4.5 via the Grok    │
                     │ haiku — Agent    │   │ Build CLI (consult mode):│
                     │ tool or          │   │ audits the plan, then    │
                     │ claude-ask -w    │   │ pass/fail vs the spec    │
                     └────────┬─────────┘   └────────────┬─────────────┘
                              │        rework loop       │
                              └───────── findings ◄──────┘
```

Everything is **roster-driven**: one JSON file defines the members, who plans,
who audits, who executes at which difficulty tier, who verifies, and the
binding policies. Add or remove models by editing JSON — the skill never
hardcodes a member.

## Why

- **Plans get audited before they burn tokens.** Grok reviews the plan for
  risks and gaps, sanity-checks which executor tier each subtask deserves,
  and calls whether the work splits into independent pieces that two
  executors can run **in parallel** to finish sooner.
- **Independent verification.** The model that checks the work is never the
  model that wrote it — a different model family entirely, with zero shared
  bias.
- **Budget tiering.** Mechanical work goes to cheap models, hard work to
  heavy ones, and audit/verify/research run on the Grok plan without
  consuming your Claude limits at all.
- **Hard safety rails.** Workers only ever touch scratch dirs or git
  worktrees; verifiers are read-only; only the orchestrating session may
  commit, sign, or deploy.

## Live team reports

The skill requires the orchestrator to **narrate the run in real time** — you
watch the models disagree, not just read about it afterwards. During a run
your session streams:

- the Grok **audit verdict** and every risk, gap, and contradiction it raised
  against the Fable plan — including executor tiers it re-called and parallel
  splits it proposed or vetoed;
- which audit findings the orchestrator **accepted vs rejected**, and why;
- each executor **starting and finishing** its subtask;
- each **verify verdict** — pass/fail, deviations, bugs, gaps — the moment
  Grok returns it;
- every **rework cycle**, as it happens.

Disagreements between the models surface live; the final report is a recap,
not a reveal.

## Install

The shipped configuration is the author's reference setup, **model-to-model
and prompt-to-prompt**: Fable 5 orchestrating, opus/sonnet/haiku execution
tiers, and Grok 4.5 enabled as plan auditor, verifier, second opinion, and
researcher.

### 1. Grok Build CLI (the independent auditor/verifier)

Requires a **SuperGrok or X Premium+** subscription (macOS or Linux):

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
grok login          # authenticate with your X account or xAI API key
```

The binary installs to `~/.grok/bin/grok`; verify with
`~/.grok/bin/grok --version`. This is what lets Grok run **headless** under
your subscription — no API keys stored anywhere.

### 2. claude-grok-bridge (the `grok-ask` wrapper the roster invokes)

```bash
git clone https://github.com/BlinkingSun/claude-grok-bridge.git
cd claude-grok-bridge
./install.sh
```

Installs the bridge to `~/grok-bridge/bin/grok-ask` — persistent channels,
consult/worker safety modes, full audit logs.

### 3. This skill

```bash
git clone https://github.com/BlinkingSun/claude-team-skill.git
cd claude-team-skill
./install.sh
```

The installer copies the skill to `~/.claude/skills/team/`, seeds
`~/agent-team/` with the roster and the `claude-ask` bridge, and never
overwrites an existing `team.json`.

Then, inside any Claude Code session:

```
/team refactor the parser and add tests for the edge cases we discussed
```

### Requirements

- Claude Code CLI (`claude`) installed and authenticated.
- `python3` and `perl` on PATH (both ship with macOS; standard on Linux).
- Grok Build CLI + claude-grok-bridge (steps 1–2) for the full reference
  setup. Without them, the skill treats the Grok member as disabled and
  falls back to using a different Claude model than the executor for
  audit/verification.

### Upgrading from claude-agent-team v1.0.0

`./install.sh` never overwrites an existing `~/agent-team/team.json`. To
adopt the new Grok-enabled defaults, diff the shipped template against your
roster (`diff team.json ~/agent-team/team.json`) and merge, or back yours up
and copy the template over.

## How a run works

1. **PLAN** — the orchestrator decomposes the task into subtasks, classifies
   each hard/default/trivial, writes a `SPEC.md` per worker subtask and a
   master `PLAN.md`.
2. **AUDIT** — the roster's `plan_auditor` (Grok, read-only) reviews
   `PLAN.md` and returns: verdict (approve/revise), risks, gaps, an executor
   recommendation per subtask, and a **split call** — whether the plan
   divides into independent pieces for parallel executors. The auditor
   advises; the orchestrator decides, and the whole exchange is reported to
   you live. Capped at 2 audit cycles.
3. **EXECUTE** — subtasks run on the assigned tier (native Agent tool
   in-session, or detached `claude-ask -w` sessions), in parallel when the
   audit approved a split, isolated in scratch dirs/worktrees.
4. **VERIFY** — the verifier (Grok, read-only, never the author) audits each
   result against its spec: pass/fail, deviations, bugs, gaps — relayed to
   you as each verdict lands.
5. **REWORK** — findings go back to the same executor; re-verify on the same
   channel; ~3 cycles max before escalating.
6. **INTEGRATE** — the orchestrator reviews the final diff itself, merges,
   runs the real build/tests, and reports what each member did and what the
   audit/verifier caught.

## The roster (`~/agent-team/team.json`)

| Role | Default | Notes |
|---|---|---|
| `orchestrator` | fable (the current session) | plans, assigns, integrates; owns git/sign/deploy |
| `executor.hard` | opus | subtle/algorithmic work |
| `executor.default` | sonnet | general implementation |
| `executor.trivial` | haiku | mechanical edits, boilerplate |
| `plan_auditor` | grok-build (enabled) | pre-execution plan gate — contradictions reported live |
| `verifier` | grok-build (enabled) | post-execution pass/fail vs the spec |
| `second_opinion` | grok-build (enabled) | fresh-eyes review on demand |
| `researcher` | grok-build (enabled) | web-current research off the Claude budget |

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

## Swap in a different second model

Grok is the shipped default, not a hard requirement. Any backend works if
you wrap its CLI to expose the same interface `grok-ask` does:

- `-c NAME` — persistent conversation channel (follow-ups share context)
- `-w` — worker mode (may edit files/run commands); default is read-only consult
- `-d DIR` — working directory
- `-f PATH` — inline a file into the prompt
- plain-text reply on stdout, non-zero exit on error

Drop the wrapper on PATH (or in `~/agent-team/bin/`), add a `members[]` block
whose `invoke` shows the command shape, set `enabled: true`, and point
`plan_auditor` / `verifier` at it. Nothing else changes.

## Token economics

- opus/sonnet/haiku consume your Claude plan — the skill tiers deliberately:
  haiku for mechanical work, sonnet by default, opus only when genuinely hard.
- Grok handles audit, verification, second opinions, and research on *its*
  plan (SuperGrok / X Premium+), making the adversarial half of every run
  free from the Claude budget's perspective. That's where the
  fraction-of-the-tokens claim comes from: Ultracode-style coverage —
  multi-model, adversarial, independently verified — without an all-Claude
  agent fan-out.
- Headless `claude -p` calls are metered like any session; the JSONL logs
  record per-call cost so overruns are auditable.

## Layout

```
skill/SKILL.md   the /team protocol (installed to ~/.claude/skills/team/)
team.json        roster template     (installed to ~/agent-team/)
bin/claude-ask   headless Claude bridge (installed to ~/agent-team/bin/)
install.sh       installer
CHANGELOG.md     release history
```

## License

MIT — see [LICENSE](LICENSE).
