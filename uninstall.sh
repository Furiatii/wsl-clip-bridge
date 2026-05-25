#!/usr/bin/env bash
# uninstall.sh — remove o clip-bridge e seus symlinks.
set -uo pipefail

BINDIR="${CLIPBRIDGE_BINDIR:-$HOME/.local/bin}"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

echo
echo "wsl-clip-bridge :: remoção"
echo

target="$(readlink -f "$BINDIR/clip-bridge" 2>/dev/null || true)"

for name in wl-paste xclip; do
  link="$BINDIR/$name"
  if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$target" ]; then
    rm -f "$link"; ok "removido symlink $name"
  elif [ -e "$link" ]; then
    warn "$link existe mas não é nosso symlink — deixando como está"
  fi
done

if [ -f "$BINDIR/clip-bridge" ]; then
  rm -f "$BINDIR/clip-bridge"; ok "removido $BINDIR/clip-bridge"
fi

echo
warn "O atalho do Windows Terminal NÃO foi removido automaticamente."
echo "  Para reverter: restaure um backup *.clipbridge-bak-* do settings.json,"
echo "  ou apague o bloco de keybinding que contém \"sendInput\" com \"input\": \"\\u0016\"."
echo
