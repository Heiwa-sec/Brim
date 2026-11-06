#!/bin/bash
# Looks through EVERY commit for secret-like text and for key, certificate or data files.
# Usage: scripts/scan-secrets.sh [repo-folder]   Exit 0 = clean, 1 = something found, 2 = the scan itself failed.
cd "${1:-$(dirname "$0")/..}" || exit 2
PAT='(AKIA[0-9A-Z]{16}|sk_(live|test)_|api[_-]?key[[:space:]]*[:=]|secret[[:space:]]*[:=]|password[[:space:]]*[:=]|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_)'
LOOK='AKIA|sk_live|sk_test|api[_-]?key|secret|password|BEGIN .*PRIVATE|ghp_|gho_|github_pat_'
# Docs, tests and the vendored adapter are skipped on purpose: they talk ABOUT passwords and keys.
OUT=$(git log --all -p --pretty=format: -G"$PAT" -- . ':!scripts' ':!DEVELOPMENT.md' ':!README.md' ':!BrimTests' ':!Vendor' 2>&1) \
  || { echo "scan failed: $OUT"; exit 2; }
HITS=$(printf '%s\n' "$OUT" | grep -E '^\+' | grep -Ei "$LOOK")
FILES=$(git log --all --name-only --pretty=format: 2>&1 | grep -Ei '(^|/)(exports|backups?)/|\.(p12|p8|cer|pem|key|mobileprovision|provisionprofile|store|store-wal|store-shm|sqlite|ipa|xcarchive)$|(^|/)\.env')
if [ -n "$HITS$FILES" ]; then
  [ -n "$HITS" ] && { echo "Secret-looking text added in a commit:"; printf '%s\n' "$HITS" | cut -c1-120 | head; }
  [ -n "$FILES" ] && { echo "Sensitive file names in history:"; printf '%s\n' "$FILES" | sort -u | head; }
  exit 1
fi
exit 0
