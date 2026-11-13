---
description: Continue an existing Codex session by run name, keeping its context. Use for follow-ups such as fixing a build error or review findings in work Codex already did.
argument-hint: "<name> [write|read] <follow-up>"
---

Continue an existing Codex session: $ARGUMENTS

```
<wrapper> resume <name> write|read "<follow-up>"
```

- Use the same run name as the original `run`; run `status` first if you are unsure of the name or whether it has finished. A session can only be resumed after its previous run ended.
- Codex remembers the earlier conversation, so send only what is new: the failing test output, the findings to fix. Do not re-explain the task.
- A smaller model or lower effort (`-m`, `-e`) is usually enough for a small follow-up.
- When it finishes, build and test again yourself.

Wrapper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh"` (native Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1"`, with `-Model` / `-Effort` in place of `-m` / `-e`; if `pwsh` is not installed, `powershell` works the same way).

After it starts, tell the user the run name and carry on with other work; the command returns immediately and the job continues in the background. For the full workflow, output files and pitfalls, see the `cx-sidekick:workflow` skill.
