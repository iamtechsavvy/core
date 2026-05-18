# CORE — Center Outlook Reminders

Automatically snaps Microsoft Outlook reminder popups to the centre of your screen when they appear with 2 minutes or less until a meeting. Works across multiple monitors. Zero dependencies — requires only bash and osascript (built into macOS).

Windows runtime support is available via scripts under `src/windows/`.

---

## Windows (Preview)

### Requirements

- Windows 10 or newer
- Microsoft Outlook installed
- PowerShell 5.1+ (or PowerShell 7)

### Setup

```powershell
cd src\windows
powershell -ExecutionPolicy Bypass -File .\set-config.ps1 -Interval 10 -LeadTimeMinutes 2
powershell -ExecutionPolicy Bypass -File .\install-startup.ps1
```

### Run / Status

```powershell
powershell -ExecutionPolicy Bypass -File .\outlook-reminder-center.ps1
powershell -ExecutionPolicy Bypass -File .\status.ps1
```

### Logs

- `%APPDATA%\CORE\logs\debug.log`
- `%APPDATA%\CORE\logs\error.log`

---

## Requirements

- macOS (any recent version)
- Microsoft Outlook installed
- **Accessibility permission** granted to Terminal (or whichever app runs the script)
  - System Settings → Privacy & Security → Accessibility → enable Terminal (or your terminal app)
- **Notifications permission** for `osascript`
  - System Settings → Notifications → Script Editor / osascript → Allow Notifications

---

## Setup

### 1. Download

Save `outlook-reminder-center.sh` to a permanent folder on your Mac. It must stay there — the LaunchAgent plist points to it directly.

```
~/scripts/outlook-reminder-center.sh   ← recommended location
```

### 2. Install

```bash
cd ~/scripts   # or wherever you saved the file
bash outlook-reminder-center.sh install
```

The script will:
- Make itself executable
- Write a LaunchAgent plist to `~/Library/LaunchAgents/com.outlook-reminder-center.plist`
- Load the agent — it starts immediately and restarts automatically at every login

### 3. Verify it is running

```bash
launchctl list | grep outlook-reminder-center
```

A PID in the first column means it is actively running. A `-` means it is registered but not running.

---

## Commands

| Command | Description |
|---|---|
| `bash outlook-reminder-center.sh install` | Install as a macOS LaunchAgent (debug logging off) |
| `bash outlook-reminder-center.sh install --debug` | Install with debug logging enabled |
| `bash outlook-reminder-center.sh uninstall` | Stop the agent, remove the plist, kill any running processes |
| `bash outlook-reminder-center.sh status` | Show agent status, running processes, recent logs |
| `bash outlook-reminder-center.sh` | Run in the foreground (Ctrl-C to stop) |

> **Re-installing** automatically stops and kills any existing instance first, so there is no need to uninstall before reinstalling.

### Manual start / stop without reinstalling

```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.outlook-reminder-center.plist

# Start
launchctl load ~/Library/LaunchAgents/com.outlook-reminder-center.plist

# Restart (pick up code changes without reinstalling)
launchctl kickstart -k gui/$(id -u)/com.outlook-reminder-center
```

### Check what is running

```bash
# Full status summary (recommended)
bash outlook-reminder-center.sh status

# Just the LaunchAgent registration
launchctl list | grep outlook-reminder-center

# All your user LaunchAgents
launchctl list | grep -v com.apple

# Running processes
pgrep -fl outlook-reminder-center.sh

# View the installed plist
cat ~/Library/LaunchAgents/com.outlook-reminder-center.plist
```

### Watch logs live

```bash
# Debug events (only written when installed with --debug)
tail -f ~/Library/Logs/OutlookReminderCenter/debug.log

# Errors
tail -f ~/Library/Logs/OutlookReminderCenter/stderr.log

# Standard output
tail -f ~/Library/Logs/OutlookReminderCenter/stdout.log
```

---

## How it works

Every `CHECK_INTERVAL` seconds (default: 10s) the daemon reads the text inside each Outlook "Reminder" window using the macOS Accessibility API. If any entry shows `Now` or `0–2 min`, it:

- Centers the window on whichever screen it is on
- Fires a macOS native notification ("Meeting starting in 2 minutes or less")
- Applies a per-window 5-minute cooldown to prevent repeated alerts for the same event

Multi-monitor support: the script calculates which screen has the most overlap with the window and centers it on that screen.

The window is only touched when a meeting is imminent — if nothing is urgent, no action is taken.

---

## Configuration

| Variable | Default | Description |
|---|---|---|
| `OUTLOOK_CHECK_INTERVAL` | `10` | Seconds between each check. Lower = faster detection, higher = less CPU. |
| `OUTLOOK_MAX_ERRORS` | `10` | Consecutive failures before the daemon exits. |
| `OUTLOOK_DEBUG` | `0` | Set to `1` to enable debug logging. |

**Change the check interval** — edit the default in the script:

```bash
CHECK_INTERVAL=${OUTLOOK_CHECK_INTERVAL:-10}  # ← change 10 to your preference
```

Or override at runtime without editing the file:

```bash
OUTLOOK_CHECK_INTERVAL=5 bash outlook-reminder-center.sh
```

---

## Logs

Debug logging is **off by default**. Enable it by installing with `--debug` or setting `OUTLOOK_DEBUG=1`.

| File | Contents | When written |
|---|---|---|
| `~/Library/Logs/OutlookReminderCenter/debug.log` | Centering events and imminent alerts | Only when debug is enabled |
| `~/Library/Logs/OutlookReminderCenter/stdout.log` | Standard output | LaunchAgent mode only |
| `~/Library/Logs/OutlookReminderCenter/stderr.log` | Errors | LaunchAgent mode only |

### Enable debug logging

```bash
# Reinstall with debug on
bash outlook-reminder-center.sh install --debug

# Watch live
tail -f ~/Library/Logs/OutlookReminderCenter/debug.log
```

### Disable debug logging

```bash
# Reinstall without --debug
bash outlook-reminder-center.sh install
```

Expected debug output when a meeting is imminent:
```
[2026-05-15 09:58:02] daemon started — debug log: ...
[2026-05-15 09:58:10] [alert] IMMINENT — centered: Dev Call (win 12345)
[2026-05-15 09:58:10] [debug] window text (no match): new event snooze...
```

---

## Debugging & making changes

### Check bash syntax after any edit

```bash
bash -n outlook-reminder-center.sh && echo "OK"
```

No output = no syntax errors. Errors include the line number.

### Deeper static analysis (recommended)

```bash
brew install shellcheck
shellcheck outlook-reminder-center.sh
```

### Reload after a code change (no reinstall needed)

```bash
launchctl kickstart -k gui/$(id -u)/com.outlook-reminder-center
```

### Run in the foreground for interactive testing

```bash
bash outlook-reminder-center.sh
```

This prints all log output directly to the terminal. Use Ctrl-C to stop.

### Test the imminent-detection logic manually

Run this in Terminal while a reminder window is open to see exactly what text the script reads:

```bash
osascript -l JavaScript -e '
ObjC.import("AppKit");
function collectText(el, depth) {
    if (depth > 6) return "";
    var text = "";
    try {
        var kids = el.uiElements();
        for (var k = 0; k < kids.length; k++) {
            try {
                var role = kids[k].role();
                if (role === "AXStaticText" || role === "AXTextField") {
                    try { text += " " + kids[k].value(); } catch(ex) {}
                } else {
                    text += collectText(kids[k], depth + 1);
                }
            } catch(ex) {}
        }
    } catch(ex) {}
    return text;
}
var se = Application("System Events");
var wins = se.processes.whose({name:"Microsoft Outlook"})[0]
            .windows.whose({name:{_contains:"Reminder"}});
collectText(wins[0], 0);
'
```

The imminence check triggers if the output contains the word `now` or a number ≤ 2 followed by `min`.

### State files (centering cooldown)

Per-window lock files are stored in `/tmp/outlook-reminder-centered/`. Delete them to force a re-center on the next check:

```bash
rm -rf /tmp/outlook-reminder-centered/
```

### View the installed plist

```bash
cat ~/Library/LaunchAgents/com.outlook-reminder-center.plist
```

### Check all user LaunchAgents

```bash
launchctl list | grep -v com.apple
```

