param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$CommandsDir = Join-Path $ClaudeDir "commands"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$ActiveFile = Join-Path $ClaudeDir "smooth-brain-active"
$SkillSrc = Join-Path $RepoRoot "skills\smooth-brain\SKILL.md"
$CmdSrc = Join-Path $RepoRoot ".claude\commands\smooth-brain.md"

function Log($msg)  { Write-Host "[smooth-brain] $msg" }
function Ok($msg)   { Write-Host "[smooth-brain] v $msg" }
function Warn($msg) { Write-Host "[smooth-brain] ! $msg" }

function Add-SmoothBrainHook($path) {
    $data = if (Test-Path $path) {
        try { Get-Content $path -Raw | ConvertFrom-Json }
        catch { [PSCustomObject]@{} }
    } else {
        [PSCustomObject]@{}
    }

    if (-not $data.PSObject.Properties['hooks']) {
        $data | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
    }
    if (-not $data.hooks.PSObject.Properties['UserPromptSubmit']) {
        $data.hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue @()
    }

    $alreadyPresent = $data.hooks.UserPromptSubmit | Where-Object {
        $_.hooks | Where-Object { $_.command -like "*smooth-brain*" }
    }

    if ($alreadyPresent) {
        Log "hook already present, skipping"
        return
    }

    # $HOME expands at hook execution time, not install time
    $hookEntry = [PSCustomObject]@{
        matcher = ""
        hooks = @([PSCustomObject]@{
            type = "command"
            command = 'cat "$HOME/.claude/smooth-brain-active" 2>/dev/null || true'
        })
    }

    $data.hooks.UserPromptSubmit = @($data.hooks.UserPromptSubmit) + $hookEntry

    $tmp = $path + ".tmp"
    $data | ConvertTo-Json -Depth 10 | Set-Content $tmp -Encoding UTF8
    Move-Item $tmp $path -Force
    Ok "hook added to $path"
}

function Remove-SmoothBrainHook($path) {
    if (-not (Test-Path $path)) {
        Log "no settings file found, nothing to remove"
        return
    }
    $data = try { Get-Content $path -Raw | ConvertFrom-Json } catch { return }

    if (-not $data.PSObject.Properties['hooks'] -or -not $data.hooks.PSObject.Properties['UserPromptSubmit']) {
        return
    }

    $filtered = @($data.hooks.UserPromptSubmit | Where-Object {
        -not ($_.hooks | Where-Object { $_.command -like "*smooth-brain*" })
    })
    $data.hooks.UserPromptSubmit = $filtered

    $tmp = $path + ".tmp"
    $data | ConvertTo-Json -Depth 10 | Set-Content $tmp -Encoding UTF8
    Move-Item $tmp $path -Force
    Ok "hook removed from $path"
}

# ── Claude Code ────────────────────────────────────────────────────────────────

Log "smooth-brain installer"
if ($Uninstall) { Log "mode: uninstall" } else { Log "mode: install" }
Write-Host ""

if (-not (Test-Path $ClaudeDir)) {
    Warn "Claude Code not detected (~/.claude missing). Skipping."
} elseif ($Uninstall) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CommandsDir "smooth-brain.md")
    Remove-Item -Force -ErrorAction SilentlyContinue $ActiveFile
    Remove-SmoothBrainHook $SettingsFile
    Ok "Claude Code uninstalled"
} else {
    if (-not (Test-Path $CmdSrc)) { Warn "Missing required file: $CmdSrc"; exit 1 }
    if (-not (Test-Path $SkillSrc)) { Warn "Missing required file: $SkillSrc"; exit 1 }

    New-Item -ItemType Directory -Force $CommandsDir | Out-Null
    Copy-Item $CmdSrc (Join-Path $CommandsDir "smooth-brain.md") -Force
    Ok "Slash command -> $CommandsDir\smooth-brain.md"

    $skillContent = Get-Content $SkillSrc -Raw
    "$skillContent`n`nActive preset: bumpy" | Set-Content $ActiveFile -Encoding UTF8
    Ok "Default preset (bumpy) -> $ActiveFile"

    Add-SmoothBrainHook $SettingsFile
}

Write-Host ""
if ($Uninstall) {
    Log "Uninstall complete."
} else {
    Log "Install complete. Run /smooth-brain in Claude Code to activate."
}
