param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$ScriptPath = $MyInvocation.MyCommand.Path
$RepoRoot = if ([string]::IsNullOrWhiteSpace($ScriptPath)) { "" } else { Split-Path -Parent $ScriptPath }
$SmoothBrainRef = if ($env:SMOOTH_BRAIN_REF) { $env:SMOOTH_BRAIN_REF } else { "main" }
$RawBase = if ($env:SMOOTH_BRAIN_RAW_BASE) {
    $env:SMOOTH_BRAIN_RAW_BASE.TrimEnd("/")
} else {
    "https://raw.githubusercontent.com/ApolloEagle/smooth-brain/$SmoothBrainRef"
}
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$CommandsDir = Join-Path $ClaudeDir "commands"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$ActiveFile = Join-Path $ClaudeDir "smooth-brain-active"
$SkillSrc = if ($RepoRoot) { Join-Path $RepoRoot "skills\smooth-brain\SKILL.md" } else { "" }
$CmdSrc = if ($RepoRoot) { Join-Path $RepoRoot "commands\smooth-brain.md" } else { "" }

function Log($msg)  { Write-Host "[smooth-brain] $msg" }
function Ok($msg)   { Write-Host "[smooth-brain] v $msg" }
function Warn($msg) { Write-Host "[smooth-brain] ! $msg" }

function Copy-PluginFile($localPath, $rawPath, $destination) {
    if ($localPath -and (Test-Path $localPath)) {
        Copy-Item $localPath $destination -Force
        return
    }

    Invoke-WebRequest -Uri "$RawBase/$rawPath" -OutFile $destination
}

function Get-PluginContent($localPath, $rawPath) {
    if ($localPath -and (Test-Path $localPath)) {
        return Get-Content $localPath -Raw
    }

    return Invoke-RestMethod -Uri "$RawBase/$rawPath"
}

function Add-SmoothBrainHook($path) {
    $data = if (Test-Path $path) {
        try { Get-Content $path -Raw | ConvertFrom-Json }
        catch {
            throw "[smooth-brain] invalid JSON in $path. Fix the file before installing so existing settings are not overwritten."
        }
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
            command = 'if (Test-Path "$env:USERPROFILE\.claude\smooth-brain-active") { Get-Content "$env:USERPROFILE\.claude\smooth-brain-active" }'
        })
    }

    $data.hooks.UserPromptSubmit = @($data.hooks.UserPromptSubmit) + $hookEntry

    $tmp = $path + ".tmp"
    try {
        if (Test-Path $path) { Copy-Item $path ($path + ".smooth-brain.bak") -Force }
        $data | ConvertTo-Json -Depth 10 | Set-Content $tmp -Encoding UTF8
        Move-Item $tmp $path -Force
    } catch {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        throw
    }
    Ok "hook added to $path"
}

function Remove-SmoothBrainHook($path) {
    if (-not (Test-Path $path)) {
        Log "no settings file found, nothing to remove"
        return
    }
    $data = try {
        Get-Content $path -Raw | ConvertFrom-Json
    } catch {
        throw "[smooth-brain] invalid JSON in $path. Fix the file before uninstalling so existing settings are not overwritten."
    }

    if (-not $data.PSObject.Properties['hooks'] -or -not $data.hooks.PSObject.Properties['UserPromptSubmit']) {
        return
    }

    $filtered = @($data.hooks.UserPromptSubmit | Where-Object {
        -not ($_.hooks | Where-Object { $_.command -like "*smooth-brain*" })
    })
    $data.hooks.UserPromptSubmit = $filtered

    if ($filtered.Count -eq 0) {
        $data.hooks.PSObject.Properties.Remove('UserPromptSubmit')
    }
    if ($data.hooks.PSObject.Properties.Count -eq 0) {
        $data.PSObject.Properties.Remove('hooks')
    }

    $tmp = $path + ".tmp"
    try {
        if (Test-Path $path) { Copy-Item $path ($path + ".smooth-brain.bak") -Force }
        $data | ConvertTo-Json -Depth 10 | Set-Content $tmp -Encoding UTF8
        Move-Item $tmp $path -Force
    } catch {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        throw
    }
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
    New-Item -ItemType Directory -Force $CommandsDir | Out-Null
    Copy-PluginFile $CmdSrc "commands/smooth-brain.md" (Join-Path $CommandsDir "smooth-brain.md")
    Ok "Slash command -> $CommandsDir\smooth-brain.md"

    $skillContent = (Get-PluginContent $SkillSrc "skills/smooth-brain/SKILL.md") -replace "`r`n", "`n"
    ($skillContent.TrimEnd() + "`n`nActive preset: bumpy`n") | Set-Content $ActiveFile -Encoding UTF8 -NoNewline
    Ok "Default preset (bumpy) -> $ActiveFile"

    Add-SmoothBrainHook $SettingsFile
}

Write-Host ""
if ($Uninstall) {
    Log "Uninstall complete."
} else {
    Log "Install complete. Run /smooth-brain in Claude Code to activate."
}
