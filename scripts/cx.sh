#!/usr/bin/env bash
# cx-sidekick: background wrapper around the Codex CLI. Outputs stay in <project>/.codex-runs/<name>/.
#   cx.sh [-m MODEL] [-e EFFORT] <command> ...   (per-call model/effort; defaults: CX_MODEL / CX_EFFORT, else Codex's own)
#   cx.sh run       <name> write|read "<task>"   new session in the background; .codex-runs/<name>/done appears when finished
#   cx.sh resume    <name> write|read "<task>"   continue the same session (Codex keeps its context)
#   cx.sh audit     <name> "<focus>"             read-only audit, structured findings (findings.schema.json)
#   cx.sh challenge <name> [--uncommitted|--commit SHA|--base BRANCH] ["<focus>"]   review that tries to refute a change
#   cx.sh review    <name> [--uncommitted|--commit SHA|--base BRANCH] ["<instructions>"]   codex review
#   cx.sh status [<name>]                        running / finished runs
# A task, focus or instruction given as @path is read from that file.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCHEMA="$HERE/findings.schema.json"
ROOT="${CX_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"; cd "$ROOT"
MODEL="${CX_MODEL:-}"; EFFORT="${CX_EFFORT:-}"; RUNS="$ROOT/.codex-runs"
usage() { sed -n 2,10p "$0" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model)  [ $# -ge 2 ] || usage; MODEL="$2"; shift 2;;
    -e|--effort) [ $# -ge 2 ] || usage; EFFORT="$2"; shift 2;;
    *) break;;
  esac
done
OPTS=(); RC=()   # exec takes -m, review takes -c model=...
[ -n "$MODEL" ] && { OPTS+=(-m "$MODEL"); RC+=(-c "model=\"$MODEL\""); }
[ -n "$EFFORT" ] && { OPTS+=(-c "model_reasoning_effort=\"$EFFORT\""); RC+=(-c "model_reasoning_effort=\"$EFFORT\""); }
LABEL="model=${MODEL:-default} effort=${EFFORT:-default}"
sandbox() { case "$1" in write) echo workspace-write;; read) echo read-only;; *) echo "expected write|read, got '$1'" >&2; exit 2;; esac; }
text() { case "$1" in @*) cat "${1#@}";; *) printf '%s' "$1";; esac; }   # literal text or @file
rundir() { # validates the run name, prepares its directory, prints the path
  case "$1" in ''|.*|*[!A-Za-z0-9._-]*) echo "invalid run name '$1' (letters, digits, . _ - only)" >&2; exit 2;; esac
  mkdir -p "$RUNS/$1"; [ -f "$RUNS/.gitignore" ] || echo '*' >"$RUNS/.gitignore"   # keeps run output out of git
  rm -f "$RUNS/$1/done"; echo "$RUNS/$1"
}
start() { # $1=dir, rest=codex command; runs it in the background and records the session id
  local d="$1"; shift; local n; n=$(find "$d" -maxdepth 1 -name 'events*.jsonl' | wc -l | tr -d ' ')
  local ev="$d/events$n.jsonl" out="$d/out$n.md"
  echo "$LABEL" >"$d/model$n"
  # Double fork + nohup: the job survives the calling shell. stdin from /dev/null so Codex never waits for input.
  ( ( set +e; nohup "$@" -o "$out" </dev/null >"$ev" 2>"$d/err$n.log"; echo "exit=$? out=$out" >"$d/done"
      sid=$(grep -m1 -o '"thread_id":"[^"]*"' "$ev" | cut -d'"' -f4); [ -n "$sid" ] && echo "$sid" >"$d/session" ) >/dev/null 2>&1 & )
  echo "started: $d ($LABEL, output $out)"
}
target() { # turns the challenge target into the git command Codex should run itself
  case "${1:-}" in
    --commit) echo "the commit shown by \`git show $2\`";;
    --base)   echo "the branch diff shown by \`git diff $2...HEAD\`";;
    *)        echo "the uncommitted changes shown by \`git diff HEAD\` and \`git status\` (including untracked new files)";;
  esac
}
cmd="${1:-}"; shift || true
case "$cmd" in
  run)    [ $# -ge 3 ] || usage; sb=$(sandbox "$2"); task=$(text "$3"); d=$(rundir "$1")
          start "$d" codex exec -C "$ROOT" ${OPTS[@]+"${OPTS[@]}"} -s "$sb" --json "$task";;
  resume) [ $# -ge 3 ] || usage; sb=$(sandbox "$2"); task=$(text "$3")
          [ -s "$RUNS/$1/session" ] || { echo "no session recorded for '$1' (still running, or it never started; see: cx.sh status $1)" >&2; exit 1; }
          sid=$(cat "$RUNS/$1/session"); d=$(rundir "$1")
          start "$d" codex exec resume "$sid" ${OPTS[@]+"${OPTS[@]}"} -c "sandbox_mode=\"$sb\"" --json "$task";;
  audit)  [ $# -ge 2 ] || usage; focus=$(text "$2"); d=$(rundir "$1")
          start "$d" codex exec -C "$ROOT" ${OPTS[@]+"${OPTS[@]}"} -s read-only --json --output-schema "$SCHEMA" \
"Code review (read-only). $focus
Report each finding with a concrete scenario and file:line. Mark anything you are not sure of as confidence=possible.";;
  challenge)
          [ $# -ge 1 ] || usage; d=$(rundir "$1"); shift; tgt=$(target "$@")
          case "${1:-}" in --commit|--base) [ $# -ge 2 ] || usage; shift 2;; --uncommitted) shift;; esac
          focus=""; [ $# -ge 1 ] && focus=$(text "$1")
          start "$d" codex exec -C "$ROOT" ${OPTS[@]+"${OPTS[@]}"} -s read-only --json --output-schema "$SCHEMA" \
"Adversarial code review (read-only). Under review: $tgt. Read the surrounding code where needed.
The goal is not to approve the change but to try to show it is wrong: broken invariants, missing guards, unhandled error paths,
and assumptions that stop holding under retries, concurrent operations, partially completed operations and bad input.
Question the chosen approach itself too: was there a simpler or safer way?
${focus:+Priority focus: $focus. Weight this, but still report any other significant problem you can defend.}
Report only findings that matter; no style, naming or unsupported suspicion. Prefer one strong finding over several weak ones.
In each finding's scenario field give, in order: what breaks, why this code path is reachable, the likely impact, and a concrete change that reduces the risk.
Do not invent files, lines or behavior; mark a finding that rests on inference as confidence=possible. If the change is sound, say so
plainly in summary and leave findings empty. Write summary as a short ship / do-not-ship assessment.";;
  review) [ $# -ge 1 ] || usage; d=$(rundir "$1"); shift
          args=(); for a in "$@"; do case "$a" in @*) args+=("$(text "$a")");; *) args+=("$a");; esac; done
          echo "$LABEL" >"$d/model-review"
          ( ( set +e; nohup codex review ${RC[@]+"${RC[@]}"} ${args[@]+"${args[@]}"} </dev/null >"$d/review.md" 2>"$d/review.err"; echo "exit=$? out=$d/review.md" >"$d/done" ) >/dev/null 2>&1 & )
          echo "started: $d ($LABEL, output $d/review.md)";;
  status) for d in "$RUNS"/${1:-*}/; do [ -d "$d" ] || continue; printf '%-28s %s\n' "$(basename "$d")" "$(cat "$d/done" 2>/dev/null || echo running)"; done;;
  *) usage;;
esac
