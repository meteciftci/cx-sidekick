---
description: Run an adversarial read-only Codex review that tries to prove a specific change wrong, with structured JSON findings. Use after a significant change, before committing or merging, or when the user wants a second opinion on a diff.
argument-hint: "[name] [--uncommitted | --commit SHA | --base BRANCH] [focus]"
---

Start an adversarial Codex review of one change: $ARGUMENTS

```
<wrapper> challenge <name> [--uncommitted | --commit SHA | --base BRANCH] ["<focus>"]
```

- With no target, the uncommitted changes are reviewed. If no name was given, pick one such as `challenge-<topic>`.
- The optional focus weights the review (for example "retries and data loss"); Codex still reports other serious problems.
- Codex looks for broken invariants, missing guards, unhandled error and retry paths, concurrency and half-finished operations, and questions the approach itself.
- The final report, `.codex-runs/<name>/out<n>.md`, is JSON: `summary` (a ship / do-not-ship assessment) and `findings[]` with `severity`, `title`, `file`, `line`, `scenario`, `confidence`. An empty `findings` means Codex found the change sound.
- Try to refute each finding in the code before acting on it. Fix the real ones (or send them to the session that wrote the code with `resume`), then rebuild and retest.

Wrapper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh"` (native Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1"`, with `-Model` / `-Effort` in place of `-m` / `-e`; if `pwsh` is not installed, `powershell` works the same way).

After it starts, tell the user the run name and carry on with other work; the command returns immediately and the job continues in the background. For the full workflow, output files and pitfalls, see the `cx-sidekick:workflow` skill.
