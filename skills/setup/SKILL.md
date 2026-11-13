---
description: Check that the Codex CLI is installed and logged in for cx-sidekick, and optionally add lead-agent notes to the project's CLAUDE.md.
disable-model-invocation: true
---

Set up cx-sidekick for this machine and project. Report what you find at each step; do not install anything without the user's go-ahead.

1. **Codex CLI.** Run `codex --version`. If it is missing, tell the user to install it with `npm install -g @openai/codex` (Node.js required), then run `codex` once in their own terminal to sign in. Signing in is interactive, so the user has to do it.
2. **Flags.** Run `codex exec --help` and confirm it lists `--json`, `-o`/`--output-last-message`, `--output-schema`, `-s`/`--sandbox` and the `resume` subcommand. Flag names have changed between Codex versions; if one is missing, say which and suggest updating Codex.
3. **Windows only.** Check `pwsh --version`. The wrapper runs on PowerShell 7 and on the built-in Windows PowerShell 5.1 (`powershell`); PowerShell 7 is recommended (`winget install Microsoft.PowerShell`) but not required. Under WSL, use the bash wrapper and keep the project on the WSL filesystem, not under `/mnt/c`.
4. **Run directory.** Nothing to do: the wrapper creates `.codex-runs/` at the project root with its own `.gitignore` on first use.
5. **CLAUDE.md (ask first).** Offer to append this section to the project's `CLAUDE.md` so every session uses Codex without being told:

   ```markdown
   ## Lead agent notes
   - Use Codex actively through the cx-sidekick plugin (run / resume / audit / challenge / review / status); output is in `.codex-runs/`.
     Pick model and effort to fit the job. For follow-ups use `resume`; do not re-explain context.
   - Hand independent parts out in parallel (Codex + Claude subagents); never let two agents write the same files at once.
   - Build, test and real-run verification stay with the lead. Keep "built / tested / run for real / claimed" apart when reporting.
   - After every significant change, run a `challenge` review and try to refute its findings before acting on them.
   ```

Finish with a one-line summary of what is ready and what the user still has to do.
