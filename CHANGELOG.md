# Changelog

## [Unreleased]

### Changed
- New binding standing rule: **no autonomous destructive enforcement.** Members
  must never arm automated guards/watchdogs that kill processes or revert state;
  guards observe and alert only, with destructive responses requiring the
  orchestrator's fresh explicit go-ahead. Born from a real incident: a
  supervisor's stale-context build guard killed three legitimate integration
  builds whose authorization it hadn't seen.

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [1.1.0] — 2026-07-11

### Changed
- **Repository renamed** `claude-agent-team` → `claude-team-skill` — the
  "Claude /team skill" (GitHub does not allow `/` in repo slugs; old clone
  URLs redirect).
- Repo description now credits the engine pair: **powered by Claude Fable 5
  and Grok 4.5**, with Ultracode-like results at a fraction of the token
  usage.
- The shipped roster (`team.json`) now mirrors the author's reference setup
  **model-to-model**: `fable` (the orchestrating session) +
  `opus`/`sonnet`/`haiku` execution tiers + `grok-build` **enabled** as plan
  auditor, verifier, second opinion, and researcher (previously a disabled
  generic `second-provider` example).
- README install is now the full reference stack: **Grok Build CLI**
  (headless `grok`, SuperGrok / X Premium+ subscription) →
  **claude-grok-bridge** (`grok-ask` wrapper) → this installer.
- `skill/SKILL.md` audit/verify examples now show the shipped default
  (`~/grok-bridge/bin/grok-ask`) with the reference prompts,
  **prompt-to-prompt** — executor vocabulary extended to
  opus | sonnet | haiku | inline-orchestrator.

### Added
- **Live team reports** — the protocol now requires the orchestrator to
  narrate the run in real time: the Grok audit verdict and every
  contradiction of the Fable plan (risks, gaps, tier re-calls, split calls),
  accepted vs rejected findings, executor start/finish, verify verdicts, and
  rework cycles — as they happen, not only in the final summary.
- Runtime fallback rule (roster policy + skill): a member whose wrapper/CLI
  is not installed is treated as disabled; audit/verify falls back to a
  different Claude model and the user is told.
- `install.sh` detects a missing `grok-ask` and prints the Grok Build CLI +
  bridge setup steps (non-fatal).
- This changelog.

### Migration (existing installs)
- `./install.sh` never overwrites an existing `~/agent-team/team.json`. To
  adopt the new Grok-enabled defaults, diff the shipped template against
  your roster and merge, or back yours up and copy the template over.

## [1.0.0] — 2026-07-08

### Added
- Initial release as `claude-agent-team`: roster-driven `/team` skill
  (plan → independent plan audit → tiered execution → independent
  verification → integrate), `claude-ask` headless bridge, roster template
  with a disabled generic second-provider example.
