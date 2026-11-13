---
description: Show which background Codex runs are still running or finished, and read their results. Use when the user asks about the state or result of a Codex task.
argument-hint: "[name]"
---

Check the background Codex runs: $ARGUMENTS

```
<wrapper> status [<name>]
```

Wrapper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh"` (native Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1"`, with `-Model` / `-Effort` in place of `-m` / `-e`; if `pwsh` is not installed, `powershell` works the same way).

Each line is a run name followed by `running` or `exit=<code> out=<file>`.

- For a finished run the user asked about, read the `out` file and summarize it. For `audit` and `challenge` runs it is JSON with `summary` and `findings`.
- A non-zero exit, or `exit=0` with an empty or missing report, means something went wrong: read `err<n>.log` (or `review.err`) in `.codex-runs/<name>/` and look for "credits" or "limit".
- A run that stays `running` far longer than expected may have died without writing `done`; check whether `events<n>.jsonl` is still growing.
