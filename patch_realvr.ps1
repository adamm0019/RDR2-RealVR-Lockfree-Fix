<#
    RDR2 R.E.A.L. VR - "lockfree_table capacity exceeded" popup fix
    ----------------------------------------------------------------
    Patches YOUR OWN copy of RealVR64.dll to stop the modal
    "lockfree_table capacity exceeded" dialog from freezing the game.

    It does NOT contain or distribute any RealVR file. It edits the DLL you
    already have installed, after making a backup.

    HOW IT WORKS
      The mod tracks Vulkan images in fixed-size tables. When one fills up it
      pops a blocking MessageBox and then continues anyway (returning a default).
      This tool finds those exact "capacity exceeded" MessageBox calls by their
      machine-code signature and replaces each CALL with NOPs, so the table
      silently continues instead of freezing the game behind a dialog.

    USAGE
      Apply:   powershell -ExecutionPolicy Bypass -File patch_realvr.ps1
      Revert:  powershell -ExecutionPolicy Bypass -File patch_realvr.ps1 -Revert
      Custom:  ... -DllPath "D:\Games\...\RealVR64.dll"

    The .bat files in this folder do the above for you (just double-click).
#>
param(
    [string]$DllPath = "",
    [switch]$Revert
)

$ErrorActionPreference = "Stop"
$BackupSuffix = ".orig_backup"

function Write-Head($t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan }
function Fail($t) { Write-Host ""; Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }
function Ok($t)   { Write-Host $t -ForegroundColor Green }

# ---- locate RealVR64.dll -------------------------------------------------
function Find-Dll {
    $candidates = New-Object System.Collections.Generic.List[string]

    # 1) same folder as this script (user dropped the fix into the game folder)
    $candidates.Add((Join-Path $PSScriptRoot "RealVR64.dll"))

    # 2) Steam library folders (parse libraryfolders.vdf)
    $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -Name SteamPath -EA Stop).SteamPath } catch {}
    if (-not $steam) { try { $steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name InstallPath -EA Stop).InstallPath } catch {} }
    if ($steam) {
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in ([regex]'"path"\s*"([^"]+)"').Matches((Get-Content $vdf -Raw))) {
                $lib = $m.Groups[1].Value -replace '\\\\','\'
                $candidates.Add((Join-Path $lib "steamapps\common\Red Dead Redemption 2\RealVR64.dll"))
            }
        }
        $candidates.Add((Join-Path $steam "steamapps\common\Red Dead Redemption 2\RealVR64.dll"))
    }

    # 3) common non-Steam install locations
    foreach ($p in @(
        "C:\Program Files\Rockstar Games\Red Dead Redemption 2\RealVR64.dll",
        "C:\Program Files (x86)\Steam\steamapps\common\Red Dead Redemption 2\RealVR64.dll",
        "C:\Program Files\Epic Games\RedDeadRedemption2\RealVR64.dll"
    )) { $candidates.Add($p) }

    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path } }
    return $null
}

if (-not $DllPath) { $DllPath = Find-Dll }
if (-not $DllPath) {
    Write-Host "Could not auto-locate RealVR64.dll." -ForegroundColor Yellow
    $DllPath = Read-Host "Paste the full path to RealVR64.dll (in your RDR2 game folder)"
    $DllPath = $DllPath.Trim('"')
}
if (-not (Test-Path $DllPath)) { Fail "RealVR64.dll not found at: $DllPath" }
$DllPath = (Resolve-Path $DllPath).Path
$backup  = $DllPath + $BackupSuffix
Write-Host "Target: $DllPath"

# ---- revert --------------------------------------------------------------
if ($Revert) {
    Write-Head "Reverting..."
    if (-not (Test-Path $backup)) { Fail "No backup found ($backup). Nothing to revert, or re-verify your install." }
    Copy-Item $backup $DllPath -Force
    Ok "Restored original RealVR64.dll from backup."
    exit 0
}

# ---- scan ----------------------------------------------------------------
# Signature of the "capacity exceeded" handler (displacements wildcarded):
#   45 33 C9            xor  r9d, r9d           (MessageBox uType = 0)
#   4C 8D 05 ?? ?? ?? ? lea  r8, [caption]      ("lockfree_table capacity exceeded")
#   48 8B D0            mov  rdx, rax           (text)
#   33 C9               xor  ecx, ecx           (hWnd = 0)
#   FF 15 ?? ?? ?? ??   call [MessageBoxA]      <-- this 6-byte CALL is NOP'd
$bytes = [System.IO.File]::ReadAllBytes($DllPath)
$enc   = [System.Text.Encoding]::GetEncoding(28591)   # Latin1: byte <-> char 1:1
$text  = $enc.GetString($bytes)

$reUnpatched = [regex]'\x45\x33\xC9\x4C\x8D\x05[\s\S]{4}\x48\x8B\xD0\x33\xC9\xFF\x15[\s\S]{4}'
$rePatched   = [regex]'\x45\x33\xC9\x4C\x8D\x05[\s\S]{4}\x48\x8B\xD0\x33\xC9\x90\x90\x90\x90\x90\x90'

$todo    = $reUnpatched.Matches($text)
$already = $rePatched.Matches($text)

Write-Head "Scan results"
Write-Host ("  handlers already patched : {0}" -f $already.Count)
Write-Host ("  handlers to patch        : {0}" -f $todo.Count)

if ($todo.Count -eq 0) {
    if ($already.Count -gt 0) { Ok "Already fully patched - nothing to do."; exit 0 }
    Fail "No 'lockfree_table capacity exceeded' handlers found. This may be a different/newer RealVR build; the fix was not applied and your file is unchanged."
}
$total = $todo.Count + $already.Count
if ($total -gt 64) { Fail "Unexpected match count ($total). Aborting to avoid touching unrelated code; your file is unchanged." }

# ---- backup + patch ------------------------------------------------------
if (-not (Test-Path $backup)) {
    Copy-Item $DllPath $backup -Force
    Ok "Backup created: $backup"
} else {
    Write-Host "Backup already exists (kept): $backup"
}

$patched = 0
foreach ($m in $todo) {
    $call = $m.Index + 15          # offset of the FF 15 call within the match
    for ($k = 0; $k -lt 6; $k++) { $bytes[$call + $k] = 0x90 }
    $patched++
}
[System.IO.File]::WriteAllBytes($DllPath, $bytes)

# ---- verify --------------------------------------------------------------
$verify = $rePatched.Matches($enc.GetString([System.IO.File]::ReadAllBytes($DllPath))).Count
Write-Head "Done"
Ok ("Patched {0} handler(s). Total suppressed now: {1}." -f $patched, $verify)
Write-Host "Launch RDR2 in VR as usual - the popup should be gone."
Write-Host "To undo: run Revert Fix.bat (restores the backup)."
