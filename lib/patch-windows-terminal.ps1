# patch-windows-terminal.ps1
# Adiciona um atalho no Windows Terminal que envia o caractere Ctrl+V (0x16)
# direto para a aplicação, em vez de o terminal interceptar como "colar texto".
# Isso permite que o Claude Code (e afins) recebam a tecla e leiam a imagem do
# clipboard via clip-bridge.
#
# A tecla é injetada pelo install.sh substituindo o marcador __CLIPBRIDGE_KEYS__.
# Saídas possíveis (stdout): PATCHED:<path> | ALREADY_INSTALLED | WT_NOT_FOUND | ERROR:<msg>

$ErrorActionPreference = "Stop"
$keys = "__CLIPBRIDGE_KEYS__"

$candidates = @(
  (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
  (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
  (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
)
$path = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $path) { Write-Output "WT_NOT_FOUND"; exit 0 }

try {
  $raw = Get-Content -Raw -Path $path

  # idempotente: se já existe um binding que envia , não faz nada
  if ($raw -match '\\u0016') { Write-Output "ALREADY_INSTALLED"; exit 0 }

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  Copy-Item -Path $path -Destination "$path.clipbridge-bak-$stamp"

  $cfg = $raw | ConvertFrom-Json
  if (-not ($cfg.PSObject.Properties.Name -contains "keybindings")) {
    $cfg | Add-Member -NotePropertyName keybindings -NotePropertyValue @()
  }

  $cmd = [PSCustomObject]@{ action = "sendInput"; input = [string][char]0x16 }
  $binding = [PSCustomObject]@{ command = $cmd; keys = $keys }
  $cfg.keybindings = @($cfg.keybindings) + $binding

  $cfg | ConvertTo-Json -Depth 32 | Set-Content -Path $path -Encoding UTF8
  Write-Output "PATCHED:$path"
}
catch {
  Write-Output ("ERROR:" + $_.Exception.Message)
  exit 1
}
