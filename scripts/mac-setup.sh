#!/usr/bin/env bash
# Attach /Users/ekky/Desktop/Wifi Crack to the GitHub repo.
# Safe to re-run. Never touches GitHub.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/tarnatphon/localAi-wifi-crack.git}"
DEST="${HOME}/Desktop/Wifi Crack"
ADOPT=0

for arg in "$@"; do
  case "$arg" in
    --adopt)    ADOPT=1 ;;
    -h|--help)
      cat <<EOF
usage: mac-setup.sh [--adopt] ["<destination folder>"]

  --adopt    destination has files but is not a git repo: back it up to a
             tarball on your Desktop, then force it onto origin/main.
EOF
      exit 0 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  DEST="$arg" ;;
  esac
done

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# --- iCloud Desktop warning -------------------------------------------------
if [ -d "${HOME}/Library/Mobile Documents/com~apple~CloudDocs" ] && \
   [ -d "${HOME}/Desktop" ] && \
   [ "$(readlink "${HOME}/Desktop" 2>/dev/null || echo)" = "" ]; then :; fi
case "$DEST" in
  "${HOME}/Desktop/"*)
    if [ -d "${HOME}/Library/Mobile Documents/com~apple~CloudDocs" ]; then
      echo "note: Desktop may be iCloud-synced (Desktop & Documents Folders)."
      echo "      Cloud sync racing .git is a known corruption source; ~/dev is safer."
    fi ;;
esac

mkdir -p "$DEST"
cd "$DEST"

# --- case 1: already a repo ------------------------------------------------
if git rev-parse --git-dir >/dev/null 2>&1; then
  say "already a git repository — refreshing"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REPO_URL"
  else
    git remote add origin "$REPO_URL"
  fi
  git fetch origin --prune
  echo "current branch: $(git rev-parse --abbrev-ref HEAD)"
  echo "origin set to : $(git remote get-url origin)"
  echo
  echo "next: git switch main && git pull --ff-only"
  exit 0
fi

# --- case 2: empty folder --------------------------------------------------
if [ -z "$(ls -A .)" ]; then
  say "empty folder — cloning origin/main"
  git clone "$REPO_URL" .
  echo
  echo "done. you are on: $(git rev-parse --abbrev-ref HEAD)"
  exit 0
fi

# --- case 3: has files, not a repo ----------------------------------------
if [ "$ADOPT" -ne 1 ]; then
  say "REFUSING: $DEST has files but is not a git repository"
  echo "Contents:"
  ls -A | sed 's/^/  /'
  echo
  echo "Two safe options:"
  echo "  1) inspect, move anything you want to keep, then re-run this script:"
  echo "       mv \"$DEST\" \"$DEST.old\" && bash \"$0\" \"$DEST\""
  echo "  2) back the folder up automatically and overwrite with origin/main:"
  echo "       bash \"$0\" --adopt \"$DEST\""
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${HOME}/Desktop/Wifi-Crack-backup-${STAMP}.tar.gz"
mkdir -p "$(dirname "$BACKUP")"
say "--adopt: backing up to $BACKUP"
if ! tar -czf "$BACKUP" -C "$DEST" . ; then
  echo "ERROR: backup failed; aborting without touching anything." >&2
  exit 1
fi
echo "backup size: $(du -h "$BACKUP" | cut -f1)"

git init -q
git remote add origin "$REPO_URL"
git fetch origin --prune
git reset --hard origin/main

say "done — folder is now a clone of origin/main"
echo "backup kept at: $BACKUP"
