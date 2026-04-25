# Ghostty CRT Shader

A custom CRT-style shader for [Ghostty](https://ghostty.org/).

## Installation

1. Clone this repository or download `crt.glsl`.

2. Put `crt.glsl` somewhere stable on your machine. For example:

   ```sh
   ~/.config/ghostty/shaders/crt.glsl
   ```

3. Open your Ghostty config file.

   Shortcuts and config locations:

   - macOS: open settings with `Cmd + ,`; config is usually in `~/Library/Application Support/com.mitchellh.ghostty/` or `~/.config/ghostty/`.
   - Linux: config is usually in `$XDG_CONFIG_HOME/ghostty/`, or `~/.config/ghostty/` when `XDG_CONFIG_HOME` is not set.
   - Windows: Ghostty does not currently list an official native Windows install in its docs. If you are running Ghostty through Linux or WSL, use the Linux paths.

   Common config files are:

   ```sh
   $XDG_CONFIG_HOME/ghostty/config.ghostty
   $XDG_CONFIG_HOME/ghostty/config
   ~/.config/ghostty/config.ghostty
   ~/.config/ghostty/config
   ~/Library/Application Support/com.mitchellh.ghostty/config.ghostty
   ~/Library/Application Support/com.mitchellh.ghostty/config
   ```

4. Add the shader path to the config:

   ```ini
   custom-shader = ~/.config/ghostty/shaders/crt.glsl
   ```

5. Restart Ghostty, or reload the config with `Cmd + Shift + ,` on macOS or `Ctrl + Shift + ,` on Linux.

## Notes

- Use an absolute path if `~` expansion does not work in your setup.
- Adjust `EDGE_PADDING` in `crt.glsl` to change the visible inset around the terminal content.
- To disable the effect, remove or comment out the `custom-shader` line from your Ghostty config.
