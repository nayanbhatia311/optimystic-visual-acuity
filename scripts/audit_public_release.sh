#!/bin/sh
set -eu

fail() {
  printf 'PUBLIC RELEASE AUDIT FAILED: %s\n' "$1" >&2
  exit 1
}

if ! git diff --quiet || ! git diff --cached --quiet; then
  fail 'working tree or index is not clean; commit the intended public state first'
fi

git ls-files | while IFS= read -r path; do
  case "$path" in
    */xcuserdata/*|*.xcuserstate|DerivedData/*|*/DerivedData/*|build/*|*/build/*|AppStore/*|*/AppStore/*|.codex-derived/*|*/.codex-derived/*|.venv*/*|*/.venv*/*)
      fail "generated or user-specific path is tracked: $path"
      ;;
    *.p12|*.mobileprovision|*.cer|*.pem|*.key|AuthKey_*.p8|.env|.env.*|*.pdf|*.mp4|*.mov)
      fail "private, signing, environment, or export file is tracked: $path"
      ;;
  esac

  size="$(git cat-file -s "HEAD:$path")"
  if [ "$size" -gt 5242880 ]; then
    fail "tracked file exceeds 5 MiB: $path"
  fi
done

if git grep -n -I -E \
  '(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' \
  -- . ':(exclude)scripts/audit_public_release.sh'; then
  fail 'a common credential or private-key pattern was found'
fi

if git grep -n -I -E '(/Users/[^/]+/|/home/[^/]+/)' -- . ':(exclude)scripts/audit_public_release.sh'; then
  fail 'an absolute local user path was found'
fi

if git grep -n -I -E 'DEVELOPMENT_TEAM = [A-Z0-9]{10};' -- . ':(exclude)scripts/audit_public_release.sh'; then
  fail 'an Apple developer team identifier was found'
fi

printf 'Public release audit passed (%s tracked files).\n' "$(git ls-files | wc -l | tr -d ' ')"
