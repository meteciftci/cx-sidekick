# cx-sidekick

Use the OpenAI Codex CLI as a background sidekick from Claude Code. Claude stays the lead agent: it plans, splits the work, builds and verifies. Codex writes code and reviews changes in the background, in as many named sessions as you need.

[Türkçe](README.tr.md)

## Why

- **Separate limits.** The two tools have their own usage limits; when one runs low, work continues on the other.
- **A different model is a different pair of eyes.** A review by another model catches mistakes that a model reviewing its own work misses.
- **Parallel work.** Codex writes code in the background while Claude builds, tests and checks the result.

The rule the plugin teaches Claude: whoever does the work does not verify it. Claude builds and tests Codex's output itself, and tries to refute review findings before acting on them.

## Requirements

- [Codex CLI](https://github.com/openai/codex) installed and signed in: `npm install -g @openai/codex`, then run `codex` once.
- macOS, Linux or WSL: bash and git.
- Native Windows: Git for Windows, and PowerShell 7 or the built-in Windows PowerShell 5.1.

Run `/cx-sidekick:setup` after installing to check all of this.

## Install

cx-sidekick is installed straight from this GitHub repository. It is not listed in Anthropic's plugin directory: the directory accepts plugins that contain scripts only from verified organizations, and cx-sidekick ships its wrapper as scripts.

**1. Install the Codex CLI** (skip if `codex --version` already works):

```
npm install -g @openai/codex
codex
```

The first `codex` run signs you in.

**2. Add the plugin.** Inside Claude Code:

```
/plugin marketplace add meteciftci/cx-sidekick
/plugin install cx-sidekick@cx-sidekick
```

Or from your terminal:

```
claude plugin marketplace add meteciftci/cx-sidekick
claude plugin install cx-sidekick@cx-sidekick
```

**3. Check the setup.** Start a new Claude Code session (or run `/reload-plugins`) in your project and run:

```
/cx-sidekick:setup
```

It verifies the Codex install and offers to add a section to the project's `CLAUDE.md` so Claude uses Codex without being asked each time.

### Update and remove

```
claude plugin marketplace update cx-sidekick
claude plugin update cx-sidekick@cx-sidekick
claude plugin uninstall cx-sidekick@cx-sidekick
```

## Commands

You can type these, or just ask ("have Codex implement the parser while you write the tests", "get a second opinion on this diff") and Claude picks the right one.

| Command | What it does |
| - | - |
| `/cx-sidekick:run [name] [write\|read] <task>` | Starts a new Codex session in the background |
| `/cx-sidekick:resume <name> <follow-up>` | Continues that session; Codex keeps its context |
| `/cx-sidekick:audit [name] <focus>` | Read-only audit with a free focus, structured findings |
| `/cx-sidekick:challenge [name] [--uncommitted \| --commit SHA \| --base BRANCH] [focus]` | Adversarial review that tries to prove one change wrong |
| `/cx-sidekick:review [name] [target]` | Codex's built-in `codex review` |
| `/cx-sidekick:status [name]` | Shows running and finished runs |
| `/cx-sidekick:setup` | Checks the Codex install; offers a `CLAUDE.md` section |

### You do not have to use the commands

The slash commands are shortcuts. In a normal conversation, sentences like "give this task to Codex", "use Codex as a subagent for the backend" or "ask Codex for a second opinion on this change" are enough, in any language: Claude loads the matching skill and runs the wrapper itself. Only `/cx-sidekick:setup` has to be typed as a command.

By default Claude reaches for Codex when you mention it. If you want Claude to hand work to Codex on its own in every session of a project, without being asked each time, the project's `CLAUDE.md` needs the "Lead agent notes" section. `/cx-sidekick:setup` offers to add it for you.

## How it works

The plugin ships a small wrapper, `scripts/cx.sh` (bash) and `scripts/cx.ps1` (PowerShell 7 or 5.1), around `codex exec`, `codex exec resume` and `codex review`. Each run has a name and its own directory, `.codex-runs/<name>/`, at the project root:

| File | Content |
| - | - |
| `out<n>.md` | Codex's final report (JSON for `audit` and `challenge`) |
| `events<n>.jsonl` | Codex's event stream |
| `err<n>.log` | stderr |
| `session` | Codex session id, used by `resume` |
| `model<n>` | Model and effort used |
| `done` | Written when the run finishes, with the exit code |

Runs are detached, so they survive the shell that started them, and the reports stay on disk: Claude reads only what it needs instead of having the whole output pushed into the conversation. `.codex-runs/` ignores itself in git.

`audit` and `challenge` return findings in a fixed JSON shape (`scripts/findings.schema.json`): severity P1 to P3, title, file, line, scenario and confidence.

### Model and effort

By default Codex uses the model from its own configuration. Override per call with `-m <model> -e low|medium|high|xhigh` (`-Model` / `-Effort` on Windows), or set `CX_MODEL` / `CX_EFFORT` in the environment. Claude is told to use the strongest model for large tasks and adversarial reviews, and a smaller one for short follow-ups.

## What the plugin runs and sends

- The plugin has no hooks, no MCP server and no network code of its own. It only runs when Claude calls the wrapper script.
- The wrapper runs your locally installed `codex` command in your project directory. Codex sends your task text and the code it reads to OpenAI under your own Codex account, as it does when you run it yourself.
- `write` runs use Codex's `workspace-write` sandbox and can edit files in the project. `audit`, `challenge` and `read` runs use the `read-only` sandbox.
- The only files the plugin writes are under `.codex-runs/` in your project.

## Compared with the official Codex plugin

OpenAI publishes its own Codex plugin for Claude Code, [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc), which is maintained by OpenAI and offers more polished job control. cx-sidekick is a lighter alternative built for a lead agent that hands out several jobs at once: every run has a name and can be resumed on its own, results stay in files, and findings follow a schema you can edit. The `challenge` command was inspired by that plugin's adversarial review. The two can be installed side by side.

## Limitations

- Codex CLI flags change between versions. The wrapper was written against `codex exec --json -o --output-schema` and `codex exec resume`; `/cx-sidekick:setup` checks that your version has them.
- Codex can exit with code 0 when its credits or limit ran out. Claude is told to check the error log and `git status`.
- There is no cancel command yet; stop a run by ending its `codex` process.

## License

MIT. cx-sidekick is an independent project and is not affiliated with or endorsed by OpenAI or Anthropic. Codex is a product of OpenAI.
