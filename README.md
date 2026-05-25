# wsl-clip-bridge

**Paste images from the Windows clipboard into Claude Code (and other CLI tools) running under WSL.**

On WSL, pasting a screenshot into Claude Code with <kbd>Ctrl</kbd>+<kbd>V</kbd> usually does nothing. Two separate problems cause this — `wsl-clip-bridge` fixes both:

1. **Format mismatch.** Windows puts images on the clipboard as **BMP**. Claude Code reads the clipboard through `xclip`/`wl-paste` and only accepts `png/jpeg/gif/webp`, so the image is silently ignored (and those tools often aren't even installed). See [anthropics/claude-code#50552](https://github.com/anthropics/claude-code/issues/50552), [#25935](https://github.com/anthropics/claude-code/issues/25935), [#13738](https://github.com/anthropics/claude-code/issues/13738).
2. **Key interception.** Windows Terminal binds <kbd>Ctrl</kbd>+<kbd>V</kbd> to its own *paste text* action, so the keystroke never reaches Claude Code — it never even tries to read the image.

## How it works

- A small shell script, `clip-bridge`, masquerades as both `xclip` and `wl-paste` (via symlinks on your `PATH`). When Claude Code asks for the clipboard image, it uses **PowerShell** to grab the Windows clipboard image and hand it back **converted to PNG** on the fly. No ImageMagick or extra packages needed.
- An optional **Windows Terminal keybinding** sends the real <kbd>Ctrl</kbd>+<kbd>V</kbd> character to the app on <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd>, so the keystroke reaches Claude Code. Plain <kbd>Ctrl</kbd>+<kbd>V</kbd> keeps pasting text as usual.

```
copy image (Win+Shift+S)  ──►  Ctrl+Shift+V  ──►  Windows Terminal sends 0x16
   ──►  Claude Code reads clipboard  ──►  xclip/wl-paste shim  ──►  PowerShell BMP→PNG  ──►  image attached
```

## Requirements

- WSL2 on Windows 10/11
- `powershell.exe` (built into Windows) — or PowerShell 7 (`pwsh.exe`)
- `iconv`, `base64`, `wslpath` (present on default Ubuntu WSL)
- Windows Terminal (only for the keybinding step; other terminals — see below)

## Install

```bash
git clone https://github.com/Furiatii/wsl-clip-bridge.git
cd wsl-clip-bridge
./install.sh
```

The installer copies `clip-bridge` to `~/.local/bin`, creates the `wl-paste`/`xclip` symlinks, and asks before touching your Windows Terminal `settings.json` (it makes a timestamped backup first).

Useful flags:

```bash
./install.sh --patch-wt          # configure Windows Terminal without asking
./install.sh --no-patch-wt       # skip Windows Terminal entirely
./install.sh --keys=ctrl+alt+v   # use a different key for image paste
./install.sh --bindir=~/bin      # install somewhere else
```

> **Restart Claude Code** after installing so it picks up the new `wl-paste`/`xclip` on `PATH`.

## Usage

| Key | Action |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd> | Paste **image** into Claude Code |
| <kbd>Ctrl</kbd>+<kbd>V</kbd> | Paste **text** (unchanged) |

1. Copy an image — `Win+Shift+S`, or <kbd>Ctrl</kbd>+<kbd>C</kbd> on any image.
2. Press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd> in Claude Code.

## Other terminals

The keybinding step is **only** needed where the terminal eats <kbd>Ctrl</kbd>+<kbd>V</kbd>.

- **VS Code integrated terminal** — passes <kbd>Ctrl</kbd>+<kbd>V</kbd> through in many configs; the `clip-bridge` shim alone may be enough. If not, bind a key to send ``.
- **WezTerm / Alacritty** — add a keybinding that sends the byte `0x16` (Ctrl-V / `SYN`); the shim does the rest.

Run `./install.sh --no-patch-wt` and configure the keybinding yourself.

### Manual Windows Terminal keybinding

If auto-config didn't run, open Windows Terminal → Settings → *Open JSON file* and add to `keybindings`:

```json
{ "command": { "action": "sendInput", "input": "" }, "keys": "ctrl+shift+v" }
```

## Uninstall

```bash
./uninstall.sh
```

Removes the script and symlinks. The Windows Terminal keybinding is left in place — revert it from a `*.clipbridge-bak-*` backup or delete the `sendInput` block manually.

## Troubleshooting

- **Nothing happens on Ctrl+Shift+V.** Confirm the keybinding exists in `settings.json` and that you restarted Claude Code. To check whether Claude even calls the shim, add a logging line at the top of `~/.local/bin/clip-bridge`:
  ```bash
  printf '%s args: %s\n' "$(date)" "$*" >> /tmp/clip-bridge.log
  ```
  Copy an image, press the key, then `cat /tmp/clip-bridge.log`.
- **Empty/garbled image.** Make sure an *image* (not a file) is on the clipboard. Test directly: copy an image, then run `wl-paste -t image/png > /tmp/t.png && file /tmp/t.png`.
- **`powershell.exe` not found.** Ensure `/mnt/c` interop is enabled in WSL.

## Security note

`clip-bridge` shells out to `powershell.exe` to read your clipboard on demand. It only reads — it never writes the clipboard or sends data anywhere. Read [`bin/clip-bridge`](bin/clip-bridge); it's ~60 lines.

## License

MIT — see [LICENSE](LICENSE).
