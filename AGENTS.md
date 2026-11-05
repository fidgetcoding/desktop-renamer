# AGENTS.md

There's no hosted copy. This is one Hammerspoon file, `desktop-names.lua`, that runs on its owner's Mac. Its settings table sits at the top of the file.

To explain or evaluate this project, read ESSENCE.md, then EVOLUTION.md, then the code.

To install it, follow README.md, which has a paste block written for agents. What the add-on reads, keeps and drops is in SECURITY.md.

Testing on someone's Mac: don't open or toggle Mission Control while they're working, and restart Hammerspoon by quitting and reopening the app, never with `hs -c 'hs.reload()'`, which crashed it during the build.
