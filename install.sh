#!/usr/bin/env bash
# install.sh — instala o clip-bridge e (opcionalmente) configura o atalho do
# Windows Terminal. Seguro para rodar de novo (idempotente).
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BINDIR="${CLIPBRIDGE_BINDIR:-$HOME/.local/bin}"
KEYS="${CLIPBRIDGE_KEYS:-ctrl+shift+v}"
PATCH_WT="ask"   # ask | yes | no
FORCE=0

usage() {
  cat <<EOF
Uso: ./install.sh [opções]

  --patch-wt        configura o atalho do Windows Terminal sem perguntar
  --no-patch-wt     não mexe no Windows Terminal
  --keys=KEYS       tecla para colar imagem (padrão: ctrl+shift+v)
  --bindir=DIR      onde instalar (padrão: ~/.local/bin)
  --force           sobrescreve symlinks/arquivos existentes
  -h, --help        esta ajuda
EOF
}

for a in "$@"; do
  case "$a" in
    --patch-wt) PATCH_WT="yes" ;;
    --no-patch-wt) PATCH_WT="no" ;;
    --keys=*) KEYS="${a#*=}" ;;
    --bindir=*) BINDIR="${a#*=}" ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "opção desconhecida: $a" >&2; usage; exit 1 ;;
  esac
done

info()  { printf '  \033[36m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()   { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

echo
echo "wsl-clip-bridge :: instalação"
echo

# --- pré-checagens ---
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  warn "Isto não parece ser o WSL. O clip-bridge depende do Windows + PowerShell."
  [ "$FORCE" = 1 ] || { err "Abortando. Use --force se souber o que está fazendo."; exit 1; }
fi

for tool in iconv base64 wslpath; do
  command -v "$tool" >/dev/null 2>&1 || { err "comando ausente: $tool"; exit 1; }
done
ok "ferramentas básicas presentes (iconv, base64, wslpath)"

PS=""
for c in powershell.exe pwsh.exe; do
  command -v "$c" >/dev/null 2>&1 && { PS="$c"; break; }
done
[ -z "$PS" ] && [ -x "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ] \
  && PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
if [ -z "$PS" ]; then err "PowerShell não encontrado no PATH nem no caminho padrão."; exit 1; fi
ok "PowerShell encontrado: $PS"

# --- instala o script ---
mkdir -p "$BINDIR"
install -m 0755 "$SCRIPT_DIR/bin/clip-bridge" "$BINDIR/clip-bridge"
ok "clip-bridge instalado em $BINDIR/clip-bridge"

for name in wl-paste xclip; do
  link="$BINDIR/$name"
  if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$BINDIR/clip-bridge")" ]; then
    ok "symlink $name já aponta para o clip-bridge"
  elif [ -e "$link" ] && [ "$FORCE" != 1 ]; then
    warn "$link já existe e não é nosso — pulando (use --force para sobrescrever)"
  else
    ln -sf "clip-bridge" "$link"
    ok "symlink criado: $name -> clip-bridge"
  fi
  # avisa se há um binário real antes do nosso no PATH
  real="$(command -v "$name" 2>/dev/null || true)"
  if [ -n "$real" ] && [ "$real" != "$link" ]; then
    warn "atenção: '$name' real também existe em $real — confira a ordem do PATH"
  fi
done

# --- PATH ---
case ":$PATH:" in
  *":$BINDIR:"*) ok "$BINDIR está no PATH" ;;
  *) warn "$BINDIR NÃO está no PATH. Adicione ao seu shell:"
     info "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc" ;;
esac

# --- Windows Terminal ---
do_patch() {
  local tmpl enc out
  tmpl=$(sed "s/__CLIPBRIDGE_KEYS__/$KEYS/g" "$SCRIPT_DIR/lib/patch-windows-terminal.ps1")
  enc=$(printf '%s' "$tmpl" | iconv -t UTF-16LE | base64 -w0)
  out=$("$PS" -NoProfile -NonInteractive -EncodedCommand "$enc" 2>/dev/null | tr -d '\r')
  case "$out" in
    PATCHED:*)        ok "Windows Terminal configurado (backup .clipbridge-bak-* criado)"
                      info "arquivo: ${out#PATCHED:}" ;;
    ALREADY_INSTALLED) ok "Windows Terminal já estava configurado" ;;
    WT_NOT_FOUND)     warn "settings.json do Windows Terminal não encontrado — configure manualmente (veja o README)" ;;
    ERROR:*)          err "falha ao configurar o Windows Terminal: ${out#ERROR:}" ;;
    *)                warn "resposta inesperada ao configurar o Windows Terminal: $out" ;;
  esac
}

echo
if [ "$PATCH_WT" = "ask" ]; then
  if [ -t 0 ]; then
    printf "Configurar o atalho '%s' no Windows Terminal? [S/n] " "$KEYS"
    read -r resp
    case "$resp" in [Nn]*) PATCH_WT="no" ;; *) PATCH_WT="yes" ;; esac
  else
    PATCH_WT="no"
    warn "Sem terminal interativo — pulando o Windows Terminal. Rode com --patch-wt para configurar."
  fi
fi
[ "$PATCH_WT" = "yes" ] && do_patch

echo
echo "Pronto. Copie uma imagem e cole no Claude Code com:  $KEYS"
echo "(Ctrl+V continua colando texto normalmente.)"
echo
