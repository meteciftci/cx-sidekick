---
description: Run a read-only Codex audit of the codebase with a free focus and structured JSON findings. Use for a broad independent sweep, such as security, error handling or a module the user names.
argument-hint: "[name] <focus>"
---

Start a read-only Codex audit: $ARGUMENTS

```
<wrapper> audit <name> "<focus>"
```

- If no name was given, pick one such as `audit-auth`. Put the area and the kind of problem to look for in the focus, plus any decisions or accepted risks Codex should not report.
- The final report, `.codex-runs/<name>/out<n>.md`, is JSON: `summary` and `findings[]` with `severity` (P1 to P3), `title`, `file`, `line`, `scenario`, `confidence` (`certain` or `possible`).
- Check each finding against the code and try to refute it before acting. Present the ones that hold, most severe first, and say which you discarded and why.

Wrapper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh"` (native Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1"`, with `-Model` / `-Effort` in place of `-m` / `-e`; if `pwsh` is not installed, `powershell` works the same way).

After it starts, tell the user the run name and carry on with other work; the command returns immediately and the job continues in the background. For the full workflow, output files and pitfalls, see the `cx-sidekick:workflow` skill.
