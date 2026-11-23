# Kids PC Game Blocker (PowerShell)

A PowerShell script for a child's Windows PC. It runs in the background and closes games (Roblox, TLauncher) and unknown programs started from the AppData, Downloads and Temp folders. Zoom and other trusted programs keep working.

## Files

| File | Purpose |
|------|---------|
| `block_games_v2.ps1` | The game blocker (runs in the background, loops forever) |
| `install_block_games.ps1` | Installs the blocker as a hidden scheduled task that starts with Windows |
| `README.md` | This file |

Log file (created automatically): `C:\ProgramData\block_games.log` - every process the blocker closed, with time, name, PID, reason and path.

Requirements: Windows 10/11 with Windows PowerShell 5.1 (built in). No extra software needed.

---

## How it works

Every 1.5 seconds the script scans all running processes and checks each one in this order:

| Step | Check | Result |
|------|-------|--------|
| 0 | The process runs from a Zoom folder (`AppData\Roaming\Zoom\`, `Program Files\Zoom\`, `Program Files (x86)\Zoom\`) | Allowed, no further checks |
| 0 | The file name is on the Zoom allowlist (`zoom.exe`, `cpthost.exe`, `aomhost64.exe`, etc.) and has a valid signature | Allowed |
| 1 | The process name contains `roblox` or `tlauncher` | Always closed, even if signed |
| 2 | The process is `java` / `javaw` and its command line contains `roblox` or `tlauncher` | Closed (Minecraft started through TLauncher) |
| 3 | The path contains `\AppData\`, `\Downloads\` or `\Temp\`, and the file has no valid signature from a trusted publisher | Closed |

Signature check results are cached, so the load on the computer is small.

## Install (recommended)

1. Put `install_block_games.ps1` and `block_games_v2.ps1` in the same folder.
2. Open PowerShell **as administrator**.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\path\to\install_block_games.ps1"
   ```

The installer copies the script to `C:\Scripts`, registers a hidden scheduled task named `BlockGames` (starts with Windows, runs as SYSTEM, restarts on failure) and starts it immediately. No reboot is needed.

To remove it:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\install_block_games.ps1" -Uninstall
```

The task is deleted; the folder `C:\Scripts` is left in place.

## Run manually (for testing)

Visible window, stop with `Ctrl+C`:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\block_games_v2.ps1"
```

Hidden background window, console stays free:

```powershell
Start-Process powershell -WindowStyle Hidden -ArgumentList '-ExecutionPolicy Bypass -File "C:\path\to\block_games_v2.ps1"'
```

The script prints nothing, so an empty console with a blinking cursor is normal while it is running. Check that it is running:

```powershell
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Select-Object ProcessId, CommandLine
```

Stop a manually started copy with `Stop-Process -Id <ProcessId> -Force`.

## Test that it works

```powershell
Copy-Item C:\Windows\System32\notepad.exe $env:USERPROFILE\Desktop\roblox.exe
Start-Process $env:USERPROFILE\Desktop\roblox.exe
Start-Sleep 3
Get-Content C:\ProgramData\block_games.log -Tail 5
Remove-Item $env:USERPROFILE\Desktop\roblox.exe
```

Notepad should close within a second or two and the log should contain a `KILLED roblox.exe` line. Also open Zoom and make sure it stays open.

## Settings

All settings are at the top of `block_games_v2.ps1`.

| Variable | Purpose |
|----------|---------|
| `$blockedNames` | Words in a process name that are always blocked (`roblox`, `tlauncher`) |
| `$blockedPaths` | Folders from which unsigned programs are not allowed to run |
| `$trustedPublishers` | Publishers whose signed programs are allowed (Zoom, Microsoft, Google, Discord) |
| `$allowedFolders` | Folders from which programs run without any checks (Zoom) |
| `$allowedNames` | Zoom file names that are allowed |
| `$checkIntervalMs` | How often to check processes, in milliseconds (default 1500) |
| `$logFile` | Path to the log file |

Allow another signed program: add its publisher to `$trustedPublishers`. To look up the publisher name:

```powershell
(Get-AuthenticodeSignature "C:\path\to\program.exe").SignerCertificate.Subject
```

Block another game: add a word to `$blockedNames`, for example `"minecraft"` or `"fortnite"`.

After changing settings, run the installer again to copy the new version and restart the task.

## If the wrong program gets blocked

1. Open `C:\ProgramData\block_games.log`. The last lines show the name, path and reason.
2. Signed program: add its publisher to `$trustedPublishers`. Unsigned program: add its folder to `$allowedFolders` and its file name to `$allowedNames`.
3. Re-run the installer (or `Stop-ScheduledTask BlockGames; Start-ScheduledTask BlockGames` if you edited `C:\Scripts\block_games_v2.ps1` directly).

If Zoom is still closed, make sure an old copy of the script is not still running (see the process check above).

## Limitations

- The script works only by process name, command line and path. A game with a different name installed in `Program Files` or another arbitrary folder will not be detected.
- A program placed in the Zoom folder (`AppData\Roaming\Zoom\`) is allowed through. Use a standard (non-administrator) account for the child.
- Only processes are blocked. Websites such as roblox.com are not affected; block them separately with the `hosts` file or a DNS filter.
- The script does not limit playing time, only launching.
- The scheduled task runs as SYSTEM, so a standard user cannot close it in Task Manager. A child with administrator rights can stop or delete it.
- The scripts were not tested on a real Windows machine by their author. Test them on the child's PC before relying on them.
