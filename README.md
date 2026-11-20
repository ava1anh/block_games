# block_games_v2.ps1

A parental-control script for Windows. It runs in the background and closes games (Roblox, TLauncher) and unknown programs launched from the AppData, Downloads and Temp folders. Zoom and other trusted programs are not blocked.

## What the script does

Every 1.5 seconds the script scans all running processes and checks each one in this order:

| Step | Check | Result |
|------|-------|--------|
| 0 | The process runs from a Zoom folder (`AppData\Roaming\Zoom\`, `Program Files\Zoom\`, `Program Files (x86)\Zoom\`) | Allowed, no further checks |
| 0 | The file name is on the Zoom allowlist (`zoom.exe`, `cpthost.exe`, `aomhost64.exe`, etc.) and has a valid signature | Allowed |
| 1 | The process name contains `roblox` or `tlauncher` | Always closed, even if the file is signed |
| 2 | The process is `java` / `javaw` and its command line contains `roblox` or `tlauncher` | Closed (Minecraft started through TLauncher) |
| 3 | The path contains `\AppData\`, `\Downloads\` or `\Temp\`, and the file has no valid signature from a trusted publisher | Closed |

Signature check results are cached, so the script puts very little load on the computer.

## Files

- `block_games_v2.ps1` - the script itself.
- `C:\ProgramData\block_games.log` - the log. Every closed process is recorded with time, name, PID, reason and file path.

## Installation

1. Create a folder the child cannot write to, for example `C:\Scripts`, and put `block_games_v2.ps1` there. Only administrators should have write access:

   ```powershell
   icacls C:\Scripts /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-545:(OI)(CI)RX"
   ```

2. Create a scheduled task (PowerShell as administrator). The script will start with Windows, run as SYSTEM and stay hidden:

   ```powershell
   $action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\block_games_v2.ps1"'
   $trigger = New-ScheduledTaskTrigger -AtStartup
   Register-ScheduledTask -TaskName "BlockGames" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest
   Start-ScheduledTask -TaskName "BlockGames"
   ```

3. Make the child's account a standard user (no administrator rights). Otherwise they can stop the task or edit the script.

For a quick test you can simply run the script by hand: `powershell -ExecutionPolicy Bypass -File block_games_v2.ps1`.

## Settings

All settings are at the top of the file.

| Variable | Purpose |
|----------|---------|
| `$blockedNames` | Words in a process name that are always blocked (`roblox`, `tlauncher`) |
| `$blockedPaths` | Folders from which unsigned programs are not allowed to run |
| `$trustedPublishers` | Publishers whose signed programs are allowed (Zoom, Microsoft, Google, Discord) |
| `$allowedFolders` | Folders from which programs run without any checks (Zoom) |
| `$allowedNames` | Zoom file names that are allowed |
| `$checkIntervalMs` | How often to check processes, in milliseconds (default 1500) |
| `$logFile` | Path to the log file |

To allow another signed program, add its publisher to `$trustedPublishers`. You can look up the publisher name like this:

```powershell
(Get-AuthenticodeSignature "C:\path\to\program.exe").SignerCertificate.Subject
```

To block another game, add a word to `$blockedNames`, for example `"minecraft"` or `"fortnite"`.

## If the wrong program gets blocked

1. Open `C:\ProgramData\block_games.log`. The last lines show the name, path and reason for the block.
2. If it is a signed program you need, add its publisher to `$trustedPublishers`. If it is unsigned, add its folder to `$allowedFolders` and its file name to `$allowedNames`.
3. Restart the task: `Stop-ScheduledTask BlockGames; Start-ScheduledTask BlockGames`.

If Zoom is still being closed, check whether the old version of the script (`block_games.ps1`) is still running. You can stop it in Task Manager (the `powershell.exe` process).

## Stopping and removing

```powershell
Stop-ScheduledTask -TaskName "BlockGames"
Unregister-ScheduledTask -TaskName "BlockGames" -Confirm:$false
```

## Limitations

- The script blocks only by name, command line and path. A game with a different name, installed in `Program Files` or in a folder with an arbitrary name, will not be detected.
- If the child puts a game in the Zoom folder (`AppData\Roaming\Zoom\`), the script will let it run. The protection against this is a standard account without administrator rights.
- Only processes are blocked. Websites such as roblox.com are not affected. They can be blocked separately through the `hosts` file or a DNS filter.
- The script does not limit playing time, only launching.
