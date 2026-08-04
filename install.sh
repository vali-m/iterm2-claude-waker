#!/usr/bin/env bash
#
# claude-waker installer.
#
#   curl -fsSL https://raw.githubusercontent.com/vali-m/iterm2-claude-waker/main/install.sh | bash
#
# Environment:
#   CW_PREFIX   install prefix (default: /usr/local, or ~/.local if not writable)
#   CW_REF      git ref to install from (default: main)

set -euo pipefail

REPO="vali-m/iterm2-claude-waker"
REF="${CW_REF:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$REF"

red()   { printf '\033[31m%s\033[0m\n' "$*" >&2; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || { red "claude-waker is macOS only (iTerm2)."; exit 1; }

if [ -n "${CW_PREFIX:-}" ]; then
  PREFIX="$CW_PREFIX"
elif [ -w /usr/local/bin ] 2>/dev/null; then
  PREFIX="/usr/local"
else
  PREFIX="$HOME/.local"
fi

BINDIR="$PREFIX/bin"
MANDIR="$PREFIX/share/man/man1"

mkdir -p "$BINDIR" "$MANDIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

dim "Fetching claude-waker ($REF)..."
curl -fsSL "$RAW/bin/claude-waker" -o "$TMP/claude-waker"

# Refuse to install something that isn't the script we expect.
head -1 "$TMP/claude-waker" | grep -q '^#!/usr/bin/env bash' \
  || { red "Downloaded file does not look like claude-waker. Aborting."; exit 1; }
bash -n "$TMP/claude-waker" \
  || { red "Downloaded script failed a syntax check. Aborting."; exit 1; }

chmod +x "$TMP/claude-waker"
mv "$TMP/claude-waker" "$BINDIR/claude-waker"

if curl -fsSL "$RAW/man/claude-waker.1" -o "$TMP/claude-waker.1" 2>/dev/null; then
  mv "$TMP/claude-waker.1" "$MANDIR/claude-waker.1"
fi

green "Installed $BINDIR/claude-waker"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    printf '\n'
    red "$BINDIR is not on your PATH."
    dim "Add this to your shell profile:"
    # $PATH must stay literal — it is instructions for the user to paste.
    # shellcheck disable=SC2016
    printf '\n    export PATH="%s:$PATH"\n\n' "$BINDIR"
    ;;
esac

printf '\n'
dim "Try:  claude-waker list"
dim "Or:   claude-waker            (interactive menu)"
printf '\n'
dim "Prefer Homebrew?  brew install vali-m/tap/claude-waker"
