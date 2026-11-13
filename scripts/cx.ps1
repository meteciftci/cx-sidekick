# cx-sidekick: background wrapper around the Codex CLI (Windows; PowerShell 7 or Windows PowerShell 5.1). Outputs stay in <project>\.codex-runs\<name>\.
#   cx.ps1 run       <name> write|read "<task>"   new session in the background; .codex-runs\<name>\done appears when finished
#   cx.ps1 resume    <name> write|read "<task>"   continue the same session (Codex keeps its context)
#   cx.ps1 audit     <name> "<focus>"             read-only audit, structured findings (findings.schema.json)
#   cx.ps1 challenge <name> [--uncommitted|--commit SHA|--base BRANCH] ["<focus>"]   review that tries to refute a change
#   cx.ps1 review    <name> [--uncommitted|--commit SHA|--base BRANCH]
#   cx.ps1 status [<name>]                        running / finished runs
#   Optional on any command: -Model <model> -Effort low|medium|high|xhigh (defaults: CX_MODEL / CX_EFFORT, else Codex's own)
#   A task or focus given as @path is read from that file.
param(
  [Parameter(Position = 0)][string]$Cmd,
  [Parameter(Position = 1)][string]$Name,
  [string]$Model = $env:CX_MODEL,
  [string]$Effort = $env:CX_EFFORT,
  [Parameter(Position = 2, ValueFromRemainingArguments = $true)][string[]]$Rest
)
$ErrorActionPreference = 'Stop'
$Root = $env:CX_ROOT
if (-not $Root) { try { $Root = (& git rev-parse --show-toplevel 2>$null) } catch { $Root = $null } }
if (-not $Root) { $Root = (Get-Location).Path }
$Root = (Resolve-Path $Root).Path
$Runs = Join-Path $Root '.codex-runs'
$Worker = Join-Path $PSScriptRoot 'cx-worker.ps1'
$Schema = Join-Path $PSScriptRoot 'findings.schema.json'
$Utf8 = New-Object System.Text.UTF8Encoding $false
# Start the worker with the same PowerShell that runs this script (pwsh.exe or powershell.exe).
$Shell = (Get-Process -Id $PID).Path
$Hidden = @{}; if ($env:OS -eq 'Windows_NT') { $Hidden = @{ WindowStyle = 'Hidden' } }
$ModelArgs = @()
if ($Model) { $ModelArgs += @('-m', $Model) }
# -c values carry no embedded quotes: Windows PowerShell 5.1 drops them when calling a native command, and Codex reads a bare value as a string.
if ($Effort) { $ModelArgs += @('-c', "model_reasoning_effort=$Effort") }
$Label = "model=$(if ($Model) { $Model } else { 'default' }) effort=$(if ($Effort) { $Effort } else { 'default' })"

function Sandbox([string]$m) {
  switch ($m) { 'write' { 'workspace-write' } 'read' { 'read-only' } default { throw "expected write|read, got '$m'" } }
}

# Literal text, or the contents of a file when given as @path.
function Text([string]$s) {
  if ($s -and $s.StartsWith('@')) { return [System.IO.File]::ReadAllText((Resolve-Path $s.Substring(1)).Path) }
  return $s
}

# Validates the run name, prepares its directory, returns the path.
function RunDir([string]$n) {
  if (-not $n -or $n.StartsWith('.') -or $n -notmatch '^[A-Za-z0-9._-]+$') { throw "invalid run name '$n' (letters, digits, . _ - only)" }
  $d = Join-Path $Runs $n
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  $ignore = Join-Path $Runs '.gitignore'   # keeps run output out of git
  if (-not (Test-Path $ignore)) { [System.IO.File]::WriteAllText($ignore, "*`n", $Utf8) }
  Remove-Item (Join-Path $d 'done') -ErrorAction SilentlyContinue
  return $d
}

function Start-CodexJob([string]$Dir, [string[]]$CodexArgs, [string]$Prompt) {
  $n = @(Get-ChildItem -Path $Dir -Filter 'events*.jsonl' -ErrorAction SilentlyContinue).Count
  # Task and arguments go through files: no quoting or non-ASCII problems.
  [System.IO.File]::WriteAllText((Join-Path $Dir "prompt$n.txt"), $Prompt, $Utf8)
  [System.IO.File]::WriteAllText((Join-Path $Dir "args$n.json"), (ConvertTo-Json -InputObject @($CodexArgs)), $Utf8)
  # Separate hidden process: the job survives the calling shell.
  Start-Process -FilePath $Shell @Hidden -WorkingDirectory $Root -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Worker`"", '-Dir', "`"$Dir`"", '-N', $n
  ) | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $Dir "model$n"), $Label, $Utf8)
  Write-Output "started: $Dir ($Label, output $(Join-Path $Dir "out$n.md"))"
}

switch ($Cmd) {
  'run' {
    $sb = Sandbox $Rest[0]; $task = Text $Rest[1]; $d = RunDir $Name
    Start-CodexJob $d (@('exec', '-C', $Root) + $ModelArgs + @('-s', $sb, '--json')) $task
  }
  'resume' {
    $sb = Sandbox $Rest[0]; $task = Text $Rest[1]
    $sessionFile = Join-Path (Join-Path $Runs $Name) 'session'
    if (-not (Test-Path $sessionFile)) { throw "no session recorded for '$Name' (still running, or it never started; see: cx.ps1 status $Name)" }
    $sid = [System.IO.File]::ReadAllText($sessionFile).Trim(); $d = RunDir $Name
    Start-CodexJob $d (@('exec', 'resume', $sid) + $ModelArgs + @('-c', "sandbox_mode=$sb", '--json')) $task
  }
  'audit' {
    $focus = Text $Rest[0]; $d = RunDir $Name
    $p = "Code review (read-only). $focus`nReport each finding with a concrete scenario and file:line. Mark anything you are not sure of as confidence=possible."
    Start-CodexJob $d (@('exec', '-C', $Root) + $ModelArgs + @('-s', 'read-only', '--json', '--output-schema', $Schema)) $p
  }
  'challenge' {
    $d = RunDir $Name
    $r = @($Rest | Where-Object { $_ })
    $tgt = 'the uncommitted changes shown by `git diff HEAD` and `git status` (including untracked new files)'
    if ($r.Count -ge 2 -and $r[0] -eq '--commit') { $tgt = "the commit shown by ``git show $($r[1])``"; $r = @($r | Select-Object -Skip 2) }
    elseif ($r.Count -ge 2 -and $r[0] -eq '--base') { $tgt = "the branch diff shown by ``git diff $($r[1])...HEAD``"; $r = @($r | Select-Object -Skip 2) }
    elseif ($r.Count -ge 1 -and $r[0] -eq '--uncommitted') { $r = @($r | Select-Object -Skip 1) }
    $focus = if ($r.Count -ge 1) { "Priority focus: $(Text $r[0]). Weight this, but still report any other significant problem you can defend." } else { '' }
    $p = @"
Adversarial code review (read-only). Under review: $tgt. Read the surrounding code where needed.
The goal is not to approve the change but to try to show it is wrong: broken invariants, missing guards, unhandled error paths,
and assumptions that stop holding under retries, concurrent operations, partially completed operations and bad input.
Question the chosen approach itself too: was there a simpler or safer way?
$focus
Report only findings that matter; no style, naming or unsupported suspicion. Prefer one strong finding over several weak ones.
In each finding's scenario field give, in order: what breaks, why this code path is reachable, the likely impact, and a concrete change that reduces the risk.
Do not invent files, lines or behavior; mark a finding that rests on inference as confidence=possible. If the change is sound, say so
plainly in summary and leave findings empty. Write summary as a short ship / do-not-ship assessment.
"@
    Start-CodexJob $d (@('exec', '-C', $Root) + $ModelArgs + @('-s', 'read-only', '--json', '--output-schema', $Schema)) $p
  }
  'review' {
    $d = RunDir $Name
    $reviewArgs = @('review')
    if ($Model) { $reviewArgs += @('-c', "model=$Model") }
    if ($Effort) { $reviewArgs += @('-c', "model_reasoning_effort=$Effort") }
    $reviewArgs += @($Rest | Where-Object { $_ })
    [System.IO.File]::WriteAllText((Join-Path $d 'review-args.json'), (ConvertTo-Json -InputObject @($reviewArgs)), $Utf8)
    Start-Process -FilePath $Shell @Hidden -WorkingDirectory $Root -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Worker`"", '-Dir', "`"$d`"", '-Review'
    ) | Out-Null
    Write-Output "started: $d ($Label, output $(Join-Path $d 'review.md'))"
  }
  'status' {
    $pattern = if ($Name) { $Name } else { '*' }
    Get-ChildItem -Path $Runs -Directory -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
      $done = Join-Path $_.FullName 'done'
      $state = if (Test-Path $done) { [System.IO.File]::ReadAllText($done).Trim() } else { 'running' }
      '{0,-28} {1}' -f $_.Name, $state
    }
  }
  default { Get-Content $PSCommandPath -TotalCount 9 }
}
