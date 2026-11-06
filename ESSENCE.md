# desktop-renamer: the essence

**What it is.** A small Hammerspoon add-on that puts real names on your Mac's desktops in Mission Control. While Mission Control is open, it draws each desktop's name right over its "Desktop N" label, in the slim top bar and in the big hover view with thumbnails. Most desktops name themselves from what's running on them.

**Who it's for.** Anyone who runs a pile of desktops and loses track of which is which. It's a particularly good fit if most of them have a Claude Code session going, because those desktops take the session's topic as their name. You need Hammerspoon, or a willingness to install it.

**Why it exists.** I run eight or nine desktops, most of them with a Claude Code session, and Mission Control calls every one of them "Desktop N". Finding the right one meant squinting at thumbnails of terminal windows that all look the same. macOS has no setting to rename desktops and no API for it. So I built something that paints the names on.

**What's different.**

- The names go where you actually look: on Mission Control's own bar, over the real label, in a chip filled with the bar's own colour. Clicks pass straight through to the label underneath.
- Most desktops name themselves. A desktop with a Claude Code session takes the session's topic from the terminal title and renames itself when the topic changes. A desktop full of chat apps reads "Messaging", one with only the browser reads "Browsing", and anything else shows its two front apps.
- You write the rules. They're a short settings table at the top of the file, and my own rules ship in it as working examples.
- Your own name beats everything. Press ⌃⌥⌘D on a desktop and type it.
- It's one Lua file and one line in your Hammerspoon config. There's nothing to build or sign.
- It gets out of the way. Names hide the moment you click, press a key or swipe out of Mission Control, and screenshot shortcuts leave them on screen so your screenshots show what you see.
- It stays on your Mac. It makes no network requests and runs no shell commands. Names live in one file in `~/.hammerspoon/`.

**How to try it.** You need macOS 26 and [Hammerspoon](https://www.hammerspoon.org). Install Hammerspoon, give it Accessibility and Screen Recording, drop `desktop-names.lua` into `~/.hammerspoon/`, add `require("desktop-names")` to your `init.lua`, reload, and open Mission Control. The [README](README.md) has every step, plus a block you can paste to your own agent so it does the setup for you. [SECURITY.md](SECURITY.md) lists exactly what the add-on reads and keeps.

**What works today.** Every number here came from my own Mac (macOS 26, one display), and [EVOLUTION.md](EVOLUTION.md) says where each one came from.

- It runs on my Mac straight from this repo: my Hammerspoon file is a link to `desktop-names.lua`.
- Names draw 92 to 106 ms after Mission Control opens, down from about 470 ms in the first version.
- Sampling the bar's colour takes one 23 ms screen grab, down from 342 ms for eight small grabs.
- On a scripted close, the names were gone 11 ms after Mission Control closed. A real trackpad swipe hasn't been timed yet.
- When my rules moved into the settings table, the new rule engine gave the same name as the old hard-coded one on all 512 combinations of nine apps.
- A safety check on November 5 found no secrets or personal data in the files or the history, and no network or shell calls in the code. The file compiles under Lua 5.4.
- Lua regression checks cover overlay cleanup and simulated sleep/unlock recovery. Rendering checks still require a real macOS screen; there is no CI.
