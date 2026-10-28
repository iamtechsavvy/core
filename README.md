# CORE — Center Outlook Reminders

CORE is a small macOS menu-bar app that watches for Microsoft Outlook meeting reminders and moves the popup to the centre of your screen when a meeting is starting (or about to), so it can't hide behind other windows. It works across multiple monitors and has no dependencies.

> **Windows is not a target.** Windows already has this behaviour built in. The scripts under `src/windows/` are an unsupported, experimental preview and are not part of the release.

---

## ⚠️ Unsigned app — you must approve it to open it

CORE is **not signed or notarized by Apple**, because that requires a paid Apple Developer account. macOS Gatekeeper will therefore warn you the first time you open it. This is expected. Only install CORE if you got it from this repository, and you can read the full source here before running it.

To open it:

1. Download `CORE.dmg`, open it, and drag **CORE** into **Applications**.
2. In Applications, **right-click (or Control-click) CORE → Open**, then click **Open** in the dialog.
3. If macOS still blocks it: **System Settings → Privacy & Security**, scroll to the message about CORE and click **Open Anyway**.
4. If the app is reported as "damaged" after download, clear the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine /Applications/CORE.app
   ```

Prefer to avoid unsigned binaries entirely? Build it yourself from source (see below).

---

## Requirements

- macOS 12 or newer
- Microsoft Outlook for Mac
- **Accessibility permission** for CORE: System Settings → Privacy & Security → Accessibility
- **Notifications permission**: System Settings → Notifications

## Using CORE

Launch CORE; a **CORE** item appears in the menu bar. From the menu you can:

- install / start / stop / uninstall the background service (a per-user LaunchAgent that starts at login)
- **Change Check Interval** — how often reminders are checked (1–300 s, default 10)
- **Change Reminder Lead Time** — 0 = "Now" only, up to 30 minutes (default 2)
- open the log folder

## How it works

Every check interval the service reads the text of each Outlook "Reminder" window through the macOS Accessibility API. If a reminder shows "Now" or a time within your lead time, CORE centres that window on the screen it is on, sends a notification, and applies a 5-minute per-window cooldown. Nothing is touched when no meeting is imminent.

## Privacy and security

- CORE makes no network connections and collects no data.
- It only reads Outlook reminder window text locally, to decide whether to centre it.
- With **debug logging** enabled, reminder window text (including meeting titles) is written to `~/Library/Logs/CORE/debug.log`. Leave it off unless troubleshooting.
- Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).

## Files CORE creates

| Path | Purpose |
|---|---|
| `~/Library/LaunchAgents/com.core-reminder.plist` | LaunchAgent (start at login) |
| `~/Library/Logs/CORE/` | `stdout.log`, `stderr.log`, `debug.log` |
| `~/Library/Caches/CORE/centered/` | Per-window cooldown markers |

## Uninstall

Use **Uninstall** from the CORE menu, then delete `/Applications/CORE.app`. To remove leftovers manually:

```bash
launchctl bootout gui/$(id -u)/com.core-reminder 2>/dev/null
rm -f ~/Library/LaunchAgents/com.core-reminder.plist
rm -rf ~/Library/Logs/CORE ~/Library/Caches/CORE
```

## Build from source

Requires Xcode command-line tools (`xcode-select --install`).

```bash
bash build.sh
```

This compiles the app, **replaces `/Applications/CORE.app`** (it may ask for your admin password if needed), and creates `CORE.dmg`.

## Troubleshooting

- **Nothing is centred:** check Accessibility permission for CORE, and that the Outlook reminder window title contains "Reminder".
- **Check the service:** `launchctl list | grep com.core-reminder`
- **Errors:** `tail -f ~/Library/Logs/CORE/stderr.log`
- **Restart the service:** `launchctl kickstart -k gui/$(id -u)/com.core-reminder`

## Configuration (advanced)

The service reads these environment variables (set by the app in the LaunchAgent):

| Variable | Default | Description |
|---|---|---|
| `OUTLOOK_CHECK_INTERVAL` | `10` | Seconds between checks |
| `OUTLOOK_IMMINENT_MINUTES` | `2` | Lead time in minutes (0–30) |
| `OUTLOOK_MAX_ERRORS` | `10` | Consecutive failures before the service exits |
| `OUTLOOK_DEBUG` | `0` | `1` enables debug logging |

## License

Free for personal, non-commercial use. Copying, forking, redistribution, modification and commercial use are not permitted without written permission. See [LICENSE](LICENSE).

Created by Naresh Vasikarla.
