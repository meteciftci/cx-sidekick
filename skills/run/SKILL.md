---
description: Delegate a task to the Codex CLI in the background as a new session. Use when the user asks to hand a coding task to Codex or to run something with Codex.
argument-hint: "[name] [write|read] <task>"
---

Start a new background Codex session for: $ARGUMENTS

```
<wrapper> run <name> write|read "<task>"
```

- If no name was given, pick a short descriptive one (letters, digits, `.`, `_`, `-`). Use `write` when Codex should edit files, `read` for analysis only; default to `write` for implementation tasks.
- Turn the request into a well-bounded task: which files Codex may write, which it must not touch, the acceptance criterion, and that it cannot run the build (you will). Ask it to end with a short summary.
- For a long task, write it to a file and pass `@path`.
- When `status` shows the run finished, read `.codex-runs/<name>/out<n>.md`, then build and test yourself before reporting success. An `exit=0` with no file changes usually means Codex ran out of credits; check `err<n>.log`.

Wrapper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh"` (native Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1"`, with `-Model` / `-Effort` in place of `-m` / `-e`; if `pwsh` is not installed, `powershell` works the same way).

After it starts, tell the user the run name and carry on with other work; the command returns immediately and the job continues in the background. For the full workflow, output files and pitfalls, see the `cx-sidekick:workflow` skill.
