---
name: prod-ready-check
description: Pre-push production-readiness check for CORE. Use before pushing or releasing, or when the user says "ready to push", "check before push", "is this production ready", or "release check". Runs automated checks (secrets, personal email, tracked junk, injection patterns, shellcheck, Swift typecheck) then a manual review checklist.
---

# CORE pre-push production check

Run this before every `git push` / release. Report results as a short checklist and a final verdict: **READY**, **READY WITH WARNINGS**, or **NOT READY**. Do not push; leave pushing to the user unless they ask.

## 1. Automated checks

Run `bash scripts/prod-ready-check.sh` from the repo root and show any ❌/⚠️ lines. It covers: clean tree, only `noreply` author emails in history, secrets/PII in files and history, tracked build artifacts, required files (LICENSE, README, SECURITY, CI workflow), shell/AppleScript injection patterns, `bash -n`, `shellcheck`, `swiftc -typecheck`. Any ❌ is a blocker: fix it (or tell the user why you can't) before continuing.

## 2. Manual review of the diff

Look at `git diff origin/main...HEAD` (or `git log -p -n 5`) and check:

- **Untrusted input:** Outlook reminder text and meeting titles are attacker-controlled (calendar invites). They must never be interpolated into `osascript -e`, `sh -c`, or filenames. Pass as argv; validate with a strict regex.
- **Environment/plist settings** are validated and clamped before use in `(( ))`, `sleep`, etc.
- **Paths:** nothing writes to world-writable locations like `/tmp`; no hardcoded personal paths; no fallbacks to unbundled scripts.
- **Privacy:** no network calls added; debug logging still opt-in; logs not world-readable.
- **Privilege:** no new `sudo` / `with administrator privileges`; any user-supplied path goes through `quoted form of`.
- **Docs match code:** README paths, labels (`com.core-reminder`), ranges (interval 1–300, lead time 0–30), and the unsigned-app / Gatekeeper notice are still accurate. Windows stays labelled unsupported.
- **License:** `LICENSE` is still the non-commercial freeware license, and README links to it.
- **Version:** if this is a release, version bumped in `build.sh` (CFBundleVersion / ShortVersionString) and a tag/changelog entry planned.

## 3. What cannot be checked automatically

Tell the user to verify by hand when relevant: `bash build.sh` runs and the DMG opens; install / change interval / change lead time / uninstall from the menu bar; a real Outlook reminder gets centred on each monitor; CI is green on GitHub after the push.

## 4. Report format

```
Automated: <pass/fail counts>
Blockers:  <list or none>
Warnings:  <list or none>
Manual checks still needed: <list>
Verdict:   READY | READY WITH WARNINGS | NOT READY
```
