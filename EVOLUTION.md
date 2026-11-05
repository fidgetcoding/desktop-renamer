# desktop-renamer: how it got here

## Short version

I built the whole thing on 2026-11-05, in a few hours of back and forth with Claude Code. My first two tries put the names in the wrong place: a popup and then a menu bar item. The third drew them straight onto Mission Control, and every round after that came from watching it on my own screen. It was slow, then fast. Names hung around after closing, so now they hide the instant the bar starts to leave. Screenshots kept showing plain "Desktop N", so screenshot keys now leave the names alone. The same afternoon I checked what already existed, pulled my personal rules into a settings table, and published it.

## Origin, in my words

The ask, with a screenshot of Mission Control: "is there a way to have desktop name themselves properly based on what is going on in the cli windows or other windows inside of them? or a way to make it so i can change the names and shit. it would help me stay organized"

## Timeline

All on 2026-11-05.

| Time | What happened |
|---|---|
| 11:07 | The ask |
| 11:11 | v1: name in the menu bar, popup on every switch |
| 11:20 | Popup removed: "i hate this popup thing" |
| 11:28 | Menu bar dropped: wrong place |
| 11:33 | Names drawn on Mission Control's collapsed bar |
| 11:36 | Re-attaches after a Dock restart |
| 11:46 | Names in the expanded hover view too |
| 12:05 | Names show ~100ms after opening, down from ~470ms |
| 12:12 | Names hide the moment a swipe starts closing it |
| 12:15 | Messaging and Browsing categories |
| 14:07 | Screenshot keys leave the names on screen |
| later that day | Prior-art check, standalone version, public repo |
| same evening | Banner: 53 options across 9 ideas, shortlist of three, "Color Code" picked |

## Round by round

**Round 1: the wrong two places (11:07 to 11:28).**
Built: a Hammerspoon add-on that named each desktop from its Claude Code session (the terminal title) or its front apps, shown in the menu bar plus a popup on every desktop switch. Names were cached by space id so they'd survive restarts.
Tested: on my screen.
Broke: me. "i hate this popup thing, i wanted to see the name changes in the actual mission control." Then about the menu bar: "it doesn't solve the main problem which is in this view."
Fixed: both removed.
What came next: putting names where I actually look.

**Round 2: painting on Mission Control (11:23 to 11:36).**
Built: the Dock describes Mission Control's top bar through accessibility, one button per desktop. So the add-on listens for Mission Control opening and draws a chip over each "Desktop N" label, filled with the bar colour sampled from the screen.
Broke: the first chips landed above the screen, because the collapsed bar reports its labels exactly one bar height (72 points) too high. A scripted open-and-close got Mission Control stuck open on my screen, so live testing on it stopped. Then "i dont see anything happening": the Dock had restarted at 11:33:34, 17 seconds after the add-on loaded, and the add-on was still listening to the old one.
Fixed: the 72-point offset, plus a check every 5 seconds that re-attaches to a new Dock.

**Round 3: the hover view (11:43 to 11:46).**
Tested: "sick." Then, from my screenshots: "i get it here which is great, but not hte other one". The other one is the expanded view you get by hovering the top bar.
Measured: the expanded bar is 164 points tall, and its buttons are the 139×90 thumbnails at y=46, with each label centred just under its thumbnail.
Built: names in that view, one line, trimmed with "…" when long.

**Round 4: speed (11:48 to 12:05).**
Tested: "is it possible to make it all happen faster. its kinda slow", and a screen recording of names lingering after a switch.
Measured: eight small screen grabs for colour sampling took 342ms; one strip grab takes 23ms. Creating the chips took about 9ms each.
Fixed: one grab, a reused pool of chips, and a colour cache that resets when the wallpaper changes, so a layout seen before draws on the first tick. Any click or key hides the names on the spot for half a second. Result on my Mac: names 92 to 106ms after Mission Control opens, down from about 470ms.
Broke along the way: my own testing. Reloading Hammerspoon through its command-line tool crashed it, and cutting off a stuck test command left it unable to print, which quietly stopped the drawing. The fix there was a gentler way to restart it while testing.

**Round 5: the swipe out (12:07 to 12:12).**
Tested: a phone video of me swiping out of Mission Control with the names still hanging on.
Broke: a swipe sends no click or key, so the names waited for the Dock's "closed" signal, which only arrives after the animation.
Fixed: the Dock reports the bar moving up the instant it starts leaving, so the names hide on that first upward move, and right away if the bar disappears. Measured on a scripted close: gone 11ms after it closed.

**Round 6: categories (12:14).**
My rule: "if the desktop just shows ARC thats like my main browsing desktop so just call it browsing. if it shows telegram, signal, imessage, whatsapp call it messaging"
Built: Messaging wins over Browsing when both apply, and names already cached get relabelled on load.

**Round 7: screenshots (14:07).**
Broke: every screenshot I took of Mission Control showed plain "Desktop N", and I read that as the whole thing being broken. The cause was Round 4's fix. Pressing ⌘⇧3 counts as a key, so the names hid for half a second, exactly while the screenshot was taken.
Fixed: ⌘⇧3, ⌘⇧4, ⌘⇧5 and ⌘⇧6 start a screenshot mode that leaves the names alone, including the drag clicks of a ⌘⇧4 selection.

**Round 8: going public (later on 11-05).**
Checked first: what already exists. Plenty, it turns out. [DeskStag](https://deskstag.com) is a paid app that draws hand-typed names on Mission Control. [SpaceNamer](https://github.com/AlexanderCollins/spacenamer) is a free Swift app that puts names in Mission Control's bar and even pulls Claude Code session titles through its own plugin. [SpaceNames](https://github.com/jrp-git/SpaceNames) hangs name flags under the thumbnails. [Spaces Renamer](https://github.com/dado3212/spaces-renamer) patches the real labels from inside macOS. [Spaceman](https://github.com/Jaysce/Spaceman) and [WhichSpace](https://github.com/gechr/WhichSpace) stick to the menu bar. I'd have found all of that before building if I'd looked first. The README says so up front and points people at them.
What's mine here: one Lua file for people who already run Hammerspoon. Desktops name themselves from what's on them through rules you edit, with nothing to build.
Built: the standalone file. It used to borrow a helper from another script of mine, and that helper now lives inside it. My personal rules (the Ghostty title source, the Messaging and Browsing categories, the hotkey) moved into one settings table at the top and ship as examples. I checked the new rule engine against the old hard-coded one on all 512 combinations of nine apps, and they named every one the same.
Kept private: the name cache, which holds my session titles, stays out of the repo.

## Still open

- Swipe exits have only been checked with a scripted close, not a real finger on a trackpad.
- One display only.
- The chip look is getting its own design pass, on real Mission Control backgrounds.
