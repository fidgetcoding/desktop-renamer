# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest (`main`) | Yes |

## Reporting a Vulnerability

If you find a security problem, please report it privately:

1. **Don't open a public GitHub issue.**
2. Email: nate@lorecraft.io
3. Include what you found, how to reproduce it, and what it could affect.
4. You'll hear back within 48 hours.

## What the add-on can see

`desktop-names.lua` runs inside Hammerspoon with the two permissions you grant it:

- **Accessibility**: reads window titles and app names to name each desktop, and reads where Mission Control puts each label. Only while Mission Control is open, it also watches clicks and key presses so it can hide the names; each key is checked against the screenshot shortcuts and then forgotten.
- **Screen Recording**: when Mission Control shows a layout it hasn't seen, it grabs the strip of screen under the top bar, reads one pixel's colour next to each label, and drops the image.

Everything it remembers goes to `~/.hammerspoon/desktop-names.json`: your own names, the titles and app names it last saw on each desktop, the sampled bar colours, and your wallpaper's file path (so the colours reset when the wallpaper changes). That file stays on your Mac. The add-on makes no network requests and runs no shell commands.

## Scope

- `desktop-names.lua`
- The install and uninstall commands in `README.md`
