# Cross-Platform Validation Matrix

## macOS Non-Regression

- [x] `bash build.sh` succeeds after platform folder split and adapter wiring
- [x] Existing menu bar app packaging still produces `CORE.app` and `CORE.dmg`

## Windows Parity (Script-Level)

- [x] Interval validation enforces 1-300 (`src/windows/CoreConfig.ps1`)
- [x] Lead-time validation enforces 0-30 (`src/windows/CoreConfig.ps1`)
- [x] Startup integration uses user-level shortcut (`src/windows/install-startup.ps1`)
- [x] Status output includes running state + key config (`src/windows/status.ps1`)
- [x] Runtime emits structured event-key logs (`src/windows/outlook-reminder-center.ps1`)
- [x] Lead-time parity checks scripted (`src/windows/tests/verify-parity.ps1`)

## Remaining Manual Validation on Windows Host

- [ ] Reminder window detection reliability across Outlook builds
- [ ] Centering behavior on multi-monitor setups
- [ ] Toast notification behavior with and without BurntToast installed
- [ ] Startup behavior under enterprise policy constraints
