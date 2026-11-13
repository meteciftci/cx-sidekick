---
description: How to work with the OpenAI Codex CLI as a second agent, with Claude as the lead. Use whenever the user asks, in any wording or language, to give work to Codex, use Codex as a subagent or helper agent, run Codex in the background or in parallel, or get an independent review or second opinion from a different model, and whenever they mention Codex, cx or cx-sidekick.
---

# Lead agent + Codex sidekick

You are the **lead**: you plan, split the work, build, test and verify. The Codex CLI is the **sidekick**: it writes code and audits changes in the background while you keep working. The two tools have separate usage limits, and a different model catches mistakes that a model reviewing its own work misses.

**Core rule: whoever does the work does not verify it.** Even when Codex reports "tests pass", run the build and the tests yourself.

## The wrapper

Invoke the wrapper with the Bash tool (macOS, Linux, WSL):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cx.sh" [-m MODEL] [-e EFFORT] <command> ...
```

On native Windows use the PowerShell version, with `-Model` / `-Effort` instead of `-m` / `-e`. If `pwsh` (PowerShell 7) is not installed, call `powershell` (Windows PowerShell 5.1) with the same arguments:

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cx.ps1" <command> ... [-Model MODEL] [-Effort EFFORT]
```

| Command | Purpose |
| - | - |
| `run <name> write\|read "<task>"` | New Codex session in the background |
| `resume <name> write\|read "<task>"` | Continue that session; Codex keeps its context |
| `audit <name> "<focus>"` | Read-only audit with a free focus, structured findings |
| `challenge <name> [--uncommitted\|--commit SHA\|--base BRANCH] ["<focus>"]` | Read-only review that tries to prove one change wrong |
| `review <name> [--uncommitted\|--commit SHA\|--base BRANCH] ["<instructions>"]` | Codex's built-in `codex review` |
| `status [<name>]` | `running`, or `exit=<code> out=<file>` |

- `<name>` is a short label you choose (letters, digits, `.`, `_`, `-`). Each name is its own Codex session, so several can run in parallel.
- `write` lets Codex edit the project (`workspace-write` sandbox); `read` is read-only.
- Everything lands in `.codex-runs/<name>/` at the project root (git-ignored automatically): `out<n>.md` is the final report, `events<n>.jsonl` the event stream, `err<n>.log` stderr, `session` the session id, `done` appears when the run finishes. `<n>` counts up with each run or resume under the same name.
- For a long task, or one with quotes in it, write the text to a file and pass `@path` instead of the text.
- Every command returns immediately. Do other work, then check `status`; read `out<n>.md` only when `done` exists, and read only as much as you need.

## Typical flow

1. **Split** the work into parts that do not touch each other's files (for example backend to Codex, UI to a Claude subagent).
2. **Delegate** the heavy or clearly bounded part with `run <name> write`.
3. **Keep working** on another part while it runs.
4. **Verify yourself**: build, tests, lint, and a real run where possible.
5. **On failure, `resume`** the same name with the error. Do not re-explain the context, and do not start a new run for a follow-up.
6. **Independent check** after every significant change: `challenge` for one specific change, `audit` for a broader sweep.
7. **Try to refute each finding** in the code before acting on it. Findings are sometimes wrong or overstated. Send the real ones back with `resume`, then rebuild.

## Writing the task

- Bound the scope by file: "Write only A, B and their tests. Do not touch directory X (another agent is working there)."
- Give an acceptance criterion: "Add a unit test for every fix."
- State the sandbox limits so Codex does not waste effort: "You cannot run the build or a server; I will build. End with a short summary."
- Include decisions the user already made and risks they accepted, so they are not reported back as findings.
- For reviews, use neutral wording ("code review", "audit") and ask for a concrete scenario and file:line.

## Model and effort

Without `-m` / `-e` (or the `CX_MODEL` / `CX_EFFORT` environment variables) Codex uses its own configured default. Use the strongest model with `high` or `xhigh` effort for large multi-file work and for `challenge`; use a smaller model or `medium` for small, bounded fixes and `resume` follow-ups. The model can change on `resume` without losing the session. Model names depend on the user's Codex account; if you do not know a valid one, omit `-m`.

## Pitfalls

- **`exit=0` does not mean the work happened.** Codex can exit 0 when its credits or usage limit ran out. Check `err<n>.log` for "credits" or "limit" and confirm with `git status` that files actually changed.
- **Two agents writing the same file overwrite each other.** Keep file sets disjoint, or run them one after the other.
- **Codex's sandbox may not be able to run** builds, devices or servers. Verification stays with you.
- **"Tests pass" may mean a subset ran.** Run the full suite yourself.
- **`resume` needs a finished earlier run** under that name; the session id is recorded when the run ends.
- If `codex` is not found or not logged in, tell the user to run `/cx-sidekick:setup`.

When reporting to the user, keep these apart: built, tested, run for real, and merely claimed by Codex.
