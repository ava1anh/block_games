# block_games_v2.ps1
# Blocks games (Roblox, TLauncher) and unknown programs from AppData/Downloads/Temp,
# but allows programs with a VALID digital signature from trusted publishers (Zoom etc).

# ---- SETTINGS ----
$blockedNames = @("roblox", "tlauncher")

$blockedPaths = @(
    "\AppData\",
    "\Downloads\",
    "\Temp\"
)

# Trusted publishers (part of the certificate subject). Add more if needed.
$trustedPublishers = @(
    "Zoom Video Communications",
    "Microsoft Corporation",
    "Google LLC",
    "Discord Inc"
)

# Hard allowlist: these are NEVER killed (checked before everything else).
# Zoom installs into AppData\Roaming\Zoom, so it is allowed by folder + file name.
$allowedFolders = @(
    "\AppData\Roaming\Zoom\",
    "\Program Files\Zoom\",
    "\Program Files (x86)\Zoom\"
)
$allowedNames = @(
    "zoom.exe", "zoomit.exe", "cpthost.exe", "aomhost64.exe", "aomhost32.exe",
    "zoomopener.exe", "zoomlauncher.exe", "zcoutlookplugin.exe", "zoominstaller.exe"
)

$checkIntervalMs = 1500
$logFile = Join-Path $env:ProgramData "block_games.log"
# ------------------

$sigCache = @{}   # path -> $true/$false (is trusted)
$myPid = $PID

function Write-Log($msg) {
    try { Add-Content -Path $logFile -Value ("{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) } catch {}
}

function Test-Trusted($path) {
    if ($sigCache.ContainsKey($path)) { return $sigCache[$path] }
    $ok = $false
    try {
        $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
        if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate) {
            foreach ($pub in $trustedPublishers) {
                if ($sig.SignerCertificate.Subject -like "*$pub*") { $ok = $true; break }
            }
        }
    } catch {}
    $sigCache[$path] = $ok
    return $ok
}

function Stop-Bad($proc, $reason) {
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Log ("KILLED {0} (pid {1}) - {2} - {3}" -f $proc.Name, $proc.ProcessId, $reason, $proc.ExecutablePath)
}

while ($true) {
    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue

    foreach ($proc in $processes) {
        if ($proc.ProcessId -eq $myPid -or $proc.ProcessId -le 4) { continue }

        $name = $proc.Name.ToLower()
        $path = $proc.ExecutablePath
        $cmd  = $proc.CommandLine

# 0) Allowlist: Zoom is never touched
        $isAllowed = $false
        if ($path) {
            foreach ($folder in $allowedFolders) {
                if ($path -like "*$folder*") { $isAllowed = $true; break }
            }
        }
        if (-not $isAllowed -and $allowedNames -contains $name -and $name -ne "") {
            # Zoom installer/updater running from Temp or Downloads
            if ($path -and (Test-Trusted $path)) { $isAllowed = $true }
        }
        if ($isAllowed) { continue }

        # 1) Block by name (always, even if signed)
        $killed = $false
        foreach ($word in $blockedNames) {
            if ($name -match $word) {
                Stop-Bad $proc "name match: $word"
                $killed = $true
                break
            }
        }
        if ($killed) { continue }

        # 2) Block by command line (e.g. java launched by TLauncher)
        if ($cmd -and $name -match "java") {
            foreach ($word in $blockedNames) {
                if ($cmd -match $word) {
                    Stop-Bad $proc "cmdline match: $word"
                    $killed = $true
                    break
                }
            }
        }
        if ($killed) { continue }

        # 3) Block by path, unless signed by a trusted publisher
        if ($path) {
            foreach ($badPath in $blockedPaths) {
                if ($path -like "*$badPath*") {
                    if (-not (Test-Trusted $path)) {
                        Stop-Bad $proc "untrusted program in $badPath"
                    }
                    break
                }
            }
        }
    }

    Start-Sleep -Milliseconds $checkIntervalMs
}
