#!/usr/bin/env bash
# outlook-reminder-center.sh
#
# Watches for Microsoft Outlook reminder popup windows on macOS and
# moves them to the centre of whatever screen they appear on.
#
# Zero dependencies — requires only bash and osascript (built into macOS).
# Works across multiple monitors.
#
# Usage:
#   bash outlook-reminder-center.sh           # run daemon in foreground (Ctrl-C to stop)
#   bash outlook-reminder-center.sh install   # install as macOS LaunchAgent (runs at login)
#   bash outlook-reminder-center.sh uninstall # remove the LaunchAgent

set -euo pipefail
umask 077   # logs may contain meeting titles; keep them private

LABEL="com.core-reminder"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
LOG_DIR="$HOME/Library/Logs/CORE"

# ── install ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "install" ]]; then
    INSTALL_DEBUG=0
    [[ "${2:-}" == "--debug" ]] && INSTALL_DEBUG=1

    chmod +x "$SCRIPT"
    mkdir -p "$LOG_DIR"

    # Stop and clean up any existing instance before (re)installing
    echo "Stopping any existing instance..."
    launchctl unload "$PLIST" 2>/dev/null || true
    pids=$(pgrep -f "$(basename "$SCRIPT")" 2>/dev/null | grep -v "^$$\$" || true)
    if [[ -n "$pids" ]]; then
        echo "Killing running process(es): $pids"
        printf '%s\n' "$pids" | xargs kill 2>/dev/null || true
    fi

    # Conditionally include EnvironmentVariables block for debug mode
    ENV_BLOCK=""
    if [[ "$INSTALL_DEBUG" == "1" ]]; then
        ENV_BLOCK="
    <key>EnvironmentVariables</key>
    <dict>
        <key>OUTLOOK_DEBUG</key>
        <string>1</string>
    </dict>"
    fi

    xml_escape() { local t="$1"; t="${t//&/&amp;}"; t="${t//</&lt;}"; echo "${t//>/&gt;}"; }
    SCRIPT_XML="$(xml_escape "$SCRIPT")"; LOG_DIR_XML="$(xml_escape "$LOG_DIR")"

    cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_XML}</string>
    </array>
${ENV_BLOCK}
    <!-- Start at login -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Restart automatically if it crashes -->
    <key>KeepAlive</key>
    <true/>

    <!-- Throttle restarts to avoid a tight crash loop -->
    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>StandardOutPath</key>
    <string>${LOG_DIR_XML}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR_XML}/stderr.log</string>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
PLIST

    echo "Plist written to $PLIST"
    launchctl load "$PLIST"

    echo ""
    echo "Done. CORE is now running in the background."
    echo "It will restart automatically at every login."
    [[ "$INSTALL_DEBUG" == "1" ]] && echo "  Debug log: tail -f \"$LOG_DIR/debug.log\""
    echo ""
    echo "  Status:    bash \"$SCRIPT\" status"
    echo "  Logs:      $LOG_DIR/"
    echo "  Stop:      launchctl unload \"$PLIST\""
    echo "  Start:     launchctl load   \"$PLIST\""
    echo "  Uninstall: bash \"$SCRIPT\" uninstall"
    exit 0
fi

# ── status ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "status" ]]; then
    echo "=== LaunchAgent ==="
    launchctl list | grep com.core-reminder || echo "  Not registered"

    echo ""
    echo "=== Running processes ==="
    pgrep -fl "$(basename "$SCRIPT")" 2>/dev/null || echo "  None"

    echo ""
    echo "=== Plist ==="
    if [[ -f "$PLIST" ]]; then
        echo "  $PLIST (exists)"
        grep -E 'OUTLOOK_DEBUG|<string>1</string>' "$PLIST" | grep -A1 'OUTLOOK_DEBUG' | tail -1 | grep -q '1' \
            && echo "  Debug logging: ON" || echo "  Debug logging: OFF"
    else
        echo "  Not installed"
    fi

    echo ""
    echo "=== Recent debug log (last 20 lines) ==="
    if [[ -f "$LOG_DIR/debug.log" ]]; then
        tail -20 "$LOG_DIR/debug.log"
    else
        echo "  No debug log (run with --debug to enable)"
    fi

    echo ""
    echo "=== Recent errors ==="
    if [[ -f "$LOG_DIR/stderr.log" ]]; then
        tail -10 "$LOG_DIR/stderr.log"
    else
        echo "  No error log yet"
    fi

    echo ""
    echo "Useful commands:"
    echo "  Watch debug log:  tail -f \"$LOG_DIR/debug.log\""
    echo "  Watch errors:     tail -f \"$LOG_DIR/stderr.log\""
    echo "  Restart:          launchctl kickstart -k gui/\$(id -u)/$LABEL"
    echo "  Stop:             launchctl unload \"$PLIST\""
    echo "  Start:            launchctl load   \"$PLIST\""
    echo "  Reinstall+debug:  bash \"$SCRIPT\" install --debug"
    exit 0
fi

# ── uninstall ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "uninstall" ]]; then
    echo "Uninstalling LaunchAgent..."
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"

    # Kill any lingering processes running this script
    pids=$(pgrep -f "$(basename "$SCRIPT")" 2>/dev/null | grep -v "^$$\$" || true)
    if [[ -n "$pids" ]]; then
        echo "Stopping running process(es): $pids"
        printf '%s\n' "$pids" | xargs kill 2>/dev/null || true
    fi

    echo "Done. The agent has been stopped and will no longer start at login."
    exit 0
fi

# ── run (daemon) ───────────────────────────────────────────────────────────────
# ── Configuration ─────────────────────────────────────────────────────────────
# How often (seconds) to check reminder windows for imminent meetings.
# Lower = faster detection, higher = less CPU. 10s is a good default.
CHECK_INTERVAL=${OUTLOOK_CHECK_INTERVAL:-10}

# Minutes before start to treat reminders as imminent.
# 0 = "Now" only. Default 2.
IMMINENT_MINUTES=${OUTLOOK_IMMINENT_MINUTES:-2}

# How many consecutive osascript errors before the daemon exits.
MAX_ERRORS=${OUTLOOK_MAX_ERRORS:-10}

# Set to 1 to enable debug logging, 0 to disable.
DEBUG=${OUTLOOK_DEBUG:-0}

# Settings come from the environment (the LaunchAgent plist): validate them.
clamp() {  # clamp <value> <min> <max> <default>
    local v="$1"
    [[ "$v" =~ ^[0-9]{1,6}$ ]] || { echo "$4"; return; }
    v=$((10#$v))
    (( v < $2 )) && v=$2
    (( v > $3 )) && v=$3
    echo "$v"
}
CHECK_INTERVAL=$(clamp "$CHECK_INTERVAL" 1 300 10)
IMMINENT_MINUTES=$(clamp "$IMMINENT_MINUTES" 0 30 2)
MAX_ERRORS=$(clamp "$MAX_ERRORS" 1 100 10)
[[ "$DEBUG" == "1" ]] || DEBUG=0
# ──────────────────────────────────────────────────────────────────────────────
consecutive_errors=0
DEBUG_LOG="$LOG_DIR/debug.log"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR" 2>/dev/null || true

log() { [[ "$DEBUG" == "1" ]] || return 0; echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$DEBUG_LOG"; }

# Centers and notifies for any reminder window showing "Now" or within configured minutes.
# Runs in a subshell so failures never affect the main loop.
# Private per-user directory (not world-writable /tmp) to avoid tampering.
CENTER_DIR="$HOME/Library/Caches/CORE/centered"
mkdir -p "$CENTER_DIR"
chmod 700 "$CENTER_DIR" "$(dirname "$CENTER_DIR")" 2>/dev/null || true

check_imminent() {
    local now; now=$(date +%s)
    local result

    result=$(osascript -l JavaScript 2>/dev/null <<'NOTIFY_JS'
ObjC.import("AppKit");
ObjC.import("Foundation");

var imminentMinutes = 2;
try {
    var envVal = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey("OUTLOOK_IMMINENT_MINUTES"));
    var parsed = parseInt(envVal, 10);
    if (!isNaN(parsed) && parsed >= 0 && parsed <= 30) imminentMinutes = parsed;
} catch (e) {}

var mainH = $.NSScreen.mainScreen.frame.size.height;
var nsScreens = $.NSScreen.screens;
var screens = [];
for (var i = 0; i < nsScreens.count; i++) {
    var f = nsScreens.objectAtIndex(i).frame;
    screens.push({
        x: f.origin.x,
        y: mainH - (f.origin.y + f.size.height),
        w: f.size.width,
        h: f.size.height
    });
}

function screenFor(wx, wy, ww, wh) {
    var best = screens[0], bestArea = -1;
    for (var i = 0; i < screens.length; i++) {
        var s = screens[i];
        var ix = Math.max(wx, s.x), iy = Math.max(wy, s.y);
        var ir = Math.min(wx + ww, s.x + s.w), ib = Math.min(wy + wh, s.y + s.h);
        var area = (ir > ix && ib > iy) ? (ir - ix) * (ib - iy) : 0;
        if (area > bestArea) { bestArea = area; best = s; }
    }
    return best;
}

var se = Application("System Events");
var procs = se.processes.whose({ name: "Microsoft Outlook" });
if (procs.length === 0) { "none"; }
else {
    var wins = procs[0].windows.whose({ name: { _contains: "Reminder" } });
    if (wins.length === 0) { "clear-locks"; }
    else {
    var hits = [];
    for (var i = 0; i < wins.length; i++) {
        try {
            var w = wins[i];
            var winId;
            try { winId = String(w.id()); } catch(e) { winId = "idx:" + i; }

            // Recursively collect all visible text from the UI tree.
            // "Now" is nested inside rows/groups, not a direct child staticText.
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
            var body = collectText(w, 0);
            var t = body.toLowerCase();
            var imminent = /\bnow\b/.test(t);
            if (!imminent && imminentMinutes > 0) {
                var m = t.match(/\b(\d+)\s*min/);
                if (m && parseInt(m[1], 10) <= imminentMinutes) imminent = true;
            }
            if (!imminent) { hits.push("debug:|" + t.substring(0, 80)); continue; }

            // Center the window
            var pos = w.position(), sz = w.size();
            var wx = pos[0], wy = pos[1], ww = sz[0], wh = sz[1];
            if (ww > 10 && wh > 10) {
                var s = screenFor(wx, wy, ww, wh);
                var tgtX = Math.round(s.x + (s.w - ww) / 2);
                var tgtY = Math.round(s.y + (s.h - wh) / 2);
                w.position = [tgtX, tgtY];
            }

            var title = "";
            try { title = w.name(); } catch(e) { title = "Outlook Reminder"; }
            hits.push(winId + "|" + title);
        } catch(e) {}
    }
    hits.length > 0 ? hits.join("\n") : "none";
    }
}
NOTIFY_JS
    ) || { consecutive_errors=$(( consecutive_errors + 1 )); echo "[warn] osascript error ($consecutive_errors/$MAX_ERRORS)" >&2; return; }
    consecutive_errors=0

    # No reminder windows — clear locks so next appearance is treated as fresh
    if [[ "$result" == "clear-locks" ]]; then
        rm -f "$CENTER_DIR"/*  2>/dev/null || true
        return
    fi

    [[ -z "$result" || "$result" == "none" ]] && return

    while IFS='|' read -r winId title; do
        [[ -z "$winId" ]] && continue
        # Debug line — log what text was read from non-imminent windows
        if [[ "$winId" == "debug:" ]]; then
            log "[debug] window text (no match): $title"
            continue
        fi
        # winId comes from outside this script: allow only safe filename characters.
        [[ "$winId" =~ ^[A-Za-z0-9:_-]+$ ]] || continue
        local lock="$CENTER_DIR/$winId"
        local last=0; [[ -f "$lock" ]] && last=$(cat "$lock")
        [[ "$last" =~ ^[0-9]+$ ]] || last=0
        # Notify once per window per 5 minutes
        if (( now - last >= 300 )); then
            log "[alert] IMMINENT — centered: $title (win $winId)"
            echo "$now" > "$lock"
            local body="Meeting starting now"
            (( IMMINENT_MINUTES == 0 )) || body="Meeting starting in ${IMMINENT_MINUTES} minutes or less"
            # Title is attacker-controlled (meeting subject): pass it as an argv
            # item, never interpolate it into AppleScript source.
            osascript - "$body" "$title" <<'NOTIFY_AS' || true
on run argv
    display notification (item 1 of argv) with title "CORE" subtitle (item 2 of argv)
end run
NOTIFY_AS
        fi
    done <<< "$result"
}

log "daemon started — debug log: $DEBUG_LOG"
echo "CORE: watching for Outlook reminder popups..."
echo "Press Ctrl-C to stop."
echo "Debug log: tail -f \"$DEBUG_LOG\""

while true; do

    check_imminent || true

    if (( consecutive_errors >= MAX_ERRORS )); then
        echo "[error] Too many consecutive errors - exiting." >&2
        exit 1
    fi

    sleep "$CHECK_INTERVAL"
done
