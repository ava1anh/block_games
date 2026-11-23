# install_block_games.ps1
# Installs block_games_v2.ps1 as a hidden scheduled task that starts with Windows.
# Run as administrator, with block_games_v2.ps1 in the same folder as this file:
#   powershell -ExecutionPolicy Bypass -File install_block_games.ps1
# To remove:
#   powershell -ExecutionPolicy Bypass -File install_block_games.ps1 -Uninstall

param([switch]$Uninstall)

$taskName   = "BlockGames"
$installDir = "C:\Scripts"
$scriptName = "block_games_v2.ps1"
$target     = Join-Path $installDir $scriptName

# --- must be administrator ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Run this script as administrator (right click PowerShell -> Run as administrator)."
    exit 1
}

function Stop-RunningCopies {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -match "block_games" -and $_.ProcessId -ne $PID } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped running copy (PID $($_.ProcessId))"
        }
}

# --- uninstall ---
if ($Uninstall) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Stop-RunningCopies
    Write-Host "Task '$taskName' removed. The folder $installDir was left in place."
    exit 0
}

# --- install ---
$source = Join-Path $PSScriptRoot $scriptName
if (-not (Test-Path $source)) {
    Write-Host "Not found: $source"
    Write-Host "Put $scriptName in the same folder as this installer and run it again."
    exit 1
}

Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Stop-RunningCopies

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item -Path $source -Destination $target -Force
Write-Host "Copied script to $target"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument ('-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $target)
$trigger  = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
    -User "SYSTEM" -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host ""
Write-Host "Done. Task '$taskName' is installed and running; it will start automatically with Windows."
Write-Host "Log file: C:\ProgramData\block_games.log"
