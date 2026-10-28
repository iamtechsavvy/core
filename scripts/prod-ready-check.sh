#!/usr/bin/env bash
# Deterministic pre-push checks for CORE. Exit 1 if any BLOCKER fails.
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
ok()   { echo "  ✅ $*"; }
warn() { echo "  ⚠️  $*"; }
bad()  { echo "  ❌ $*"; fail=1; }

echo "▶ Working tree"
[[ -z "$(git status --porcelain)" ]] && ok "clean" || warn "uncommitted changes present"

echo "▶ Author emails (must be noreply)"
leak=$(git log --all --format='%ae%n%ce' | sort -u | grep -v 'users.noreply.github.com' | grep -v '^noreply@github.com$' || true)
[[ -z "$leak" ]] && ok "only noreply addresses in history" || bad "personal email in history: $leak"

echo "▶ Secrets / personal data in tracked files and history"
pat='(api[_-]?key|secret|passwd|password|token|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|xox[bp]-|@gmail\.com|/Users/[a-z])'
hits=$(git grep -nEi "$pat" -- . ':!scripts' ':!README.md' ':!SECURITY.md' ':!LICENSE' | grep -v 'Needs admin rights' || true)
[[ -z "$hits" ]] && ok "no matches in tracked files" || { bad "possible secrets/PII:"; echo "$hits" | sed 's/^/     /'; }
h=$(git log --all -p | grep -Eic 'gmail\.com|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}' || true)
[[ "$h" == "0" ]] && ok "history clean" || bad "history contains $h suspicious lines"

echo "▶ Tracked junk"
junk=$(git ls-files | grep -E '(\.DS_Store|\.dmg$|\.app/|\.history/|\.log$|\.workspace$|code-workspace$)' || true)
[[ -z "$junk" ]] && ok "no build artifacts / editor files tracked" || bad "tracked junk: $junk"

echo "▶ Required files"
for f in LICENSE README.md SECURITY.md .gitignore .github/workflows/ci.yml; do
  [[ -f "$f" ]] && ok "$f" || bad "missing $f"
done

echo "▶ Injection patterns"
if grep -nE 'osascript -e ".*\$(\{)?(title|[a-z_]+)' src/macos/outlook-reminder-center.sh >/dev/null; then
  bad "osascript -e with shell-interpolated variable in daemon (use argv)"; else ok "no interpolated osascript in daemon"; fi
if grep -nE 'kill \$[a-z]+' src/macos/*.sh >/dev/null; then bad "unquoted kill \$var"; else ok "kill args quoted"; fi

echo "▶ Build checks"
bash -n src/macos/outlook-reminder-center.sh && bash -n build.sh && ok "bash -n" || bad "bash syntax error"
if command -v shellcheck >/dev/null; then
  shellcheck src/macos/outlook-reminder-center.sh build.sh && ok "shellcheck" || bad "shellcheck findings"
else warn "shellcheck not installed (brew install shellcheck)"; fi
if command -v swiftc >/dev/null; then
  swiftc -typecheck src/shared/*.swift src/macos/*.swift && ok "swift typecheck" || bad "swift typecheck failed"
else warn "swiftc not available"; fi

echo
(( fail )) && { echo "RESULT: ❌ BLOCKERS FOUND"; exit 1; } || { echo "RESULT: ✅ automated checks passed"; }
