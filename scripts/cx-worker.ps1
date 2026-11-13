# Background worker for cx.ps1. Do not call directly. Works on PowerShell 7 and Windows PowerShell 5.1.
param([string]$Dir, [int]$N = 0, [switch]$Review)
$Utf8 = New-Object System.Text.UTF8Encoding $false
# Keep non-ASCII text intact through pipes to and from codex.
$OutputEncoding = $Utf8
try { [Console]::InputEncoding = $Utf8; [Console]::OutputEncoding = $Utf8 } catch { }

# Files are read and written through .NET so both PowerShell versions use UTF-8 without a BOM.
function ReadText([string]$p) { [System.IO.File]::ReadAllText($p, $Utf8) }
function WriteText([string]$p, [string]$t) { [System.IO.File]::WriteAllText($p, $t, $Utf8) }
function ReadArgs([string]$p) { $j = ReadText $p | ConvertFrom-Json; @($j | ForEach-Object { [string]$_ }) }

if ($Review) {
  $codexArgs = ReadArgs (Join-Path $Dir 'review-args.json')
  $out = Join-Path $Dir 'review.md'
  $lines = & codex @codexArgs 2> (Join-Path $Dir 'review.err')
  $code = $LASTEXITCODE
  WriteText $out (@($lines) -join "`n")
  WriteText (Join-Path $Dir 'done') "exit=$code out=$out`n"
  return
}

$codexArgs = ReadArgs (Join-Path $Dir "args$N.json")
$out = Join-Path $Dir "out$N.md"
$ev = Join-Path $Dir "events$N.jsonl"
$err = Join-Path $Dir "err$N.log"
$lines = ReadText (Join-Path $Dir "prompt$N.txt") | & codex @codexArgs -o $out - 2> $err
$code = $LASTEXITCODE
WriteText $ev (@($lines) -join "`n")
WriteText (Join-Path $Dir 'done') "exit=$code out=$out`n"

$m = [regex]::Match((ReadText $ev), '"thread_id":"([^"]+)"')
if ($m.Success) { WriteText (Join-Path $Dir 'session') $m.Groups[1].Value }
