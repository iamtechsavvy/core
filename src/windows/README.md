# Windows Runtime

Windows-specific runtime implementation for CORE.

## Scripts

- `outlook-reminder-center.ps1`: Background runtime loop (discovery, centering, notifications)
- `set-config.ps1`: Persist validated config values
- `status.ps1`: Show runtime state and recent errors
- `install-startup.ps1`: Install per-user startup shortcut
- `uninstall-startup.ps1`: Remove per-user startup shortcut
- `tests/verify-parity.ps1`: Lead-time parity checks

## Configuration

Config is stored at `%APPDATA%\CORE\config.json`.

- `Interval` range: 1 to 300 seconds
- `LeadTimeMinutes` range: 0 to 30 minutes (`0` = Now only)
- `Debug` range: 0 or 1

## Quick Start (Windows)

```powershell
cd src\windows
powershell -ExecutionPolicy Bypass -File .\set-config.ps1 -Interval 10 -LeadTimeMinutes 2
powershell -ExecutionPolicy Bypass -File .\install-startup.ps1
powershell -ExecutionPolicy Bypass -File .\outlook-reminder-center.ps1
```

## Logs

- `%APPDATA%\CORE\logs\debug.log`
- `%APPDATA%\CORE\logs\error.log`

Keep cross-platform logic in shared code paths outside this folder.
