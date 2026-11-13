---
description: Run the Codex CLI built-in code review (codex review) in the background on uncommitted changes, a commit or a branch diff. Use when the user asks for a plain Codex review.
argument-hint: "[name] [--uncommitted | --commit SHA | --base BRANCH] [instructions]"
---

Start Codex's built-in review: $ARGUMENTS

```
<wrapper> review <name> [--uncommitted | --commit SHA | --base BRANCH] ["<instructions>"]
```

- If no name was given, pick one such as `review-1`. If no target was given, use `--uncommitted`.
- The result is free-form text in `.codex-runs/<name>/review.md` (stderr in `review.err`).
- For a review that actively tries to break the change and returns structured findings, use `challenge` instead.
- Verify what the review claims in the code before acting on it.

Wrapper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh"` (native Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1"`, with `-Model` / `-Effort` in place of `-m` / `-e`; if `pwsh` is not installed, `powershell` works the same way).

After it starts, tell the user the run name and carry on with other work; the command returns immediately and the job continues in the background. For the full workflow, output files and pitfalls, see the `cx-sidekick:workflow` skill.
