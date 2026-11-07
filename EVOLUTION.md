# desktop-renamer: how it got here

My words are quoted as I typed them, typos fixed, nothing else. Commit hashes are from this repo. "Private note" means a dated record I keep offline. Times are Abu Dhabi time (UTC+4), where I was when I built it.

## 1. The short version

I built the whole thing on 2026-11-05, in a few hours of back and forth with Claude Code. My first two tries put the names in the wrong place: a popup and then a menu bar item. The third painted them straight onto Mission Control, and every round after that came from watching it on my own screen. It was slow, then fast. Names hung around after closing, so now they hide the instant the bar starts to leave. Screenshots kept showing plain "Desktop N", so screenshot keys now leave the names alone. The same afternoon I checked what already existed, pulled my personal rules into a settings table, and published it.

That evening it got a banner, a security policy, and a fix for a bug that could have wiped every saved name at login.

## 2. Origin, in my words

The ask, with a screenshot of Mission Control: "is there a way to have desktop name themselves properly based on what is going on in the cli windows or other windows inside of them? or a way to make it so i can change the names and shit. it would help me stay organized"

Once it worked, about three hours later: "this should also be launched as a public repo on github"

## 3. Timeline

All on 2026-11-05.

| Time | What happened | Evidence |
|---|---|---|
| 11:07 | The ask | Private note |
| 11:11 | v1: name in the menu bar, popup on every switch | Private note |
| 11:20 | Popup removed: "i hate this popup thing" | Private note |
| 11:28 | Menu bar dropped: wrong place | Private note |
| 11:33 | Names drawn on Mission Control's collapsed bar | Private note |
| 11:36 | Re-attaches after a Dock restart | Private note |
| 11:46 | Names in the expanded hover view too | Private note |
| 12:05 | Names show ~100ms after opening, down from ~470ms | Private note |
| 12:12 | Names hide the moment a swipe starts closing it | Private note |
| 12:15 | Messaging and Browsing categories | Private note |
| 14:07 | Screenshot keys leave the names on screen | Private note |
| 14:09 to 14:24 | Prior-art check, standalone version, public repo | `061552d`, `19be2a1` |
| 19:07 | Banner: 53 options across 9 ideas, shortlist of three, "Color Code" picked | `800159a` |
| 19:26 | Safety pass: security policy, Accessibility note corrected, more ignore rules | `bacc881`, `4531298` |
| 19:27 | Saved names survive a login where macOS briefly reports no desktops | `862278e` |
| 19:49 | No live screenshot after all; private vulnerability reporting on | `b4d78b8` |

## 4. Round by round

**Round 1: the wrong two places (11:07 to 11:28).**
Built: a Hammerspoon add-on that named each desktop from its Claude Code session (the terminal title) or its front apps, shown in the menu bar plus a popup on every desktop switch. Names were cached by space id so they'd survive restarts.
Tested: on my screen.
Broke: me. "i hate this popup thing, i wanted to see the name changes in the actual mission control." Then about the menu bar: "it doesn't solve the main problem which is in this view."
Fixed: both removed.
Wanted next: putting names where I actually look.

**Round 2: painting on Mission Control (11:23 to 11:36).**
Built: the Dock describes Mission Control's top bar through accessibility, one button per desktop. So the add-on listens for Mission Control opening and draws a chip over each "Desktop N" label, filled with the bar colour sampled from the screen.
Broke: the first chips landed above the screen, because the collapsed bar reports its labels exactly one bar height (72 points) too high. A scripted open-and-close got Mission Control stuck open on my screen, so live testing on it stopped. Then "i dont see anything happening": the Dock had restarted at 11:33:34, 17 seconds after the add-on loaded, and the add-on was still listening to the old one.
Fixed: the 72-point offset, plus a check every 5 seconds that re-attaches to a new Dock.
Wanted next: the other view.

**Round 3: the hover view (11:43 to 11:46).**
Tested: "sick." Then, from my screenshots: "i get it here which is great, but not the other one". The other one is the expanded view you get by hovering the top bar.
Measured: the expanded bar is 164 points tall, and its buttons are the 139×90 thumbnails at y=46, with each label centred just under its thumbnail.
Built: names in that view, one line, trimmed with "…" when long.
Wanted next: speed.

**Round 4: speed (11:48 to 12:05).**
Tested: "is it possible to make it all happen faster. its kinda slow", and a screen recording of names lingering after a switch.
Measured: eight small screen grabs for colour sampling took 342ms; one strip grab takes 23ms. Creating the chips took about 9ms each.
Fixed: one grab, a reused pool of chips, and a colour cache that resets when the wallpaper changes, so a layout seen before draws on the first tick. Any click or key hides the names on the spot for half a second. Result on my Mac: names 92 to 106ms after Mission Control opens, down from about 470ms.
Broke along the way: my own testing. Reloading Hammerspoon through its command-line tool crashed it, and cutting off a stuck test command left it unable to print, which quietly stopped the drawing. The fix there was a gentler way to restart it while testing.
Wanted next: names that leave when I leave.

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
Wanted next: other people using it.

**Round 8: going public (14:09 to 14:24).**
Checked first: what already exists. Plenty, it turns out. [DeskStag](https://deskstag.com) is a paid app that draws hand-typed names on Mission Control. [SpaceNamer](https://github.com/AlexanderCollins/spacenamer) is a free Swift app that puts names in Mission Control's bar and even pulls Claude Code session titles through its own plugin. [SpaceNames](https://github.com/jrp-git/SpaceNames) hangs name flags under the thumbnails. [Spaces Renamer](https://github.com/dado3212/spaces-renamer) patches the real labels from inside macOS. [Spaceman](https://github.com/Jaysce/Spaceman) and [WhichSpace](https://github.com/gechr/WhichSpace) stick to the menu bar. I'd have found all of that before building if I'd looked first. The README says so up front and points people at them.
What's mine here: one Lua file for people who already run Hammerspoon. Desktops name themselves from what's on them through rules you edit, with nothing to build.
Built: the standalone file. It used to borrow a helper from another script of mine, and that helper now lives inside it. My personal rules (the Ghostty title source, the Messaging and Browsing categories, the hotkey) moved into one settings table at the top and ship as examples. I checked the new rule engine against the old hard-coded one on all 512 combinations of nine apps, and they named every one the same.
Kept private: the name cache, which holds my session titles, stays out of the repo.
Wanted next: "u know the drill", meaning a banner lab.

**Round 9: the banner (14:12 to 19:07).**
Built: a banner lab, 9 ideas with several versions each. Every option uses made-up desktop names and carries the fidgetcoding name. Each one was screenshot-checked by the agent that made it before I saw it.
Broke: the scope. "why tf is banner design taking an hour", so the lab got cut to one option per idea. Then I looked at what was left: "all desktop renames suck... pull up the ones you deleted... i want all options". All 53 came back.
Picked: three stars (Color Code, Droste, Night shift), then "going with D3". Color Code draws every label on the bar as printed tape, coloured by where its name came from. It shipped at 2880×960 in `800159a`.
Wanted next: proof the thing was safe and tidy before anyone else read it.

**Round 10: the safety pass (19:20 to 19:49).**
The ask: "ur sure the hammerspoon works and the git is up to date and pushed and /safetycheck and /gitfix and all that shit"
Checked: secrets in the files and in every commit (none), personal data (none, banner included), risky calls (no network requests, no shell commands, nothing that runs other code), the ignore list, and every README claim against the code. The file compiles under Lua 5.4, checked without running it. Every link checked out, and the raw install URL matched the repo file byte for byte.
Built: [SECURITY.md](SECURITY.md), which says how to report a problem and exactly what the add-on reads, keeps and drops. Ignore rules for editor folders and cert files (`bacc881`, `4531298`).
Fixed: the README credited Accessibility with the hotkey, which needs no permission, and left out window titles, which do.
Broke: nothing on screen, but the review found a trap. On startup the add-on forgets names for desktops that no longer exist. Right after login, macOS can briefly report no desktops at all, and that cleanup would have erased every saved name and saved the empty result. Now it skips the cleanup when the list comes back empty (`862278e`). The same commit added a Known limits line about session titles that start in non-Latin letters, and softened a line about grey chips that nobody had checked.
Tested: Hammerspoon restarted at 19:27 with the fix and came back attached to the Dock, saved names intact.
Decided (19:49): no live Mission Control screenshot in the README. The banner already shows the idea on a Mission Control bar, and a real screenshot would publish my real desktop names. GitHub's private vulnerability reporting got switched on, and SECURITY.md points to it (`b4d78b8`).

## 5. Feature family tree

```
"Desktop N" on every desktop, most of them terminals
└─ v1: name from the terminal title, else the front apps
   ├─ popup on every switch → hated it, removed
   ├─ menu bar name → wrong place, removed
   └─ draw on Mission Control's own bar
      ├─ collapsed strip → 72-point offset → re-attach after a Dock restart
      ├─ expanded hover view → 164-point bar, thumbnails
      ├─ speed: one screen grab, chip pool, colour cache → ~100ms
      │  └─ hide on any click or key → hide on swipe out
      │     └─ screenshots showed "Desktop N" → screenshot mode
      ├─ Messaging and Browsing → a settings table with your own rules
      └─ prior-art check → standalone file → public repo
         ├─ banner lab → Color Code
         └─ safety pass → SECURITY.md → login-wipe guard
            └─ screenshot dropped: it would show real desktop names
```

## 6. Test log

| When (Nov 5) | What | Result | Where |
|---|---|---|---|
| 11:33 | First chips on the collapsed bar | 72 points too high, offset fixed | Private note |
| 11:43 | Collapsed bar, by eye | Names showing: "sick" | Private note |
| 12:05 | Colour sampling | 8 small grabs 342ms, one strip grab 23ms, about 9ms per new chip | Private note |
| 12:05 | Mission Control open to names drawn | 92 to 106ms, down from about 470ms | Private note |
| 12:12 | Scripted close | Names gone 11ms after it closed | Private note |
| 14:20 | Settings-table rules vs the old hard-coded rules | Same name on all 512 combinations of nine apps | Private note |
| 19:26 | Safety check, files and full history | No secrets, no personal data, no network or shell calls | Private note |
| 19:26 | Compile check, Lua 5.4 | Compiles (loaded, not run) | Private note |
| 19:26 | README links and install URL | All 200, raw file identical to the repo | Private note |
| 19:27 | Restart with the login fix | Back up, attached to the Dock, saved names intact | Private note |

Trap to remember: before 14:07, any screenshot of Mission Control showed plain "Desktop N" even when everything worked. If a screenshot says it's broken, check by eye first.

## 7. Roads not taken

- **A popup on every desktop switch.** That was v1. "i hate this popup thing."
- **A name in the menu bar.** Wrong place. The view I actually use to find a desktop is Mission Control.
- **Truly renaming the labels.** macOS has no setting or API for it, and the tools that do it load code into a system app. Drawing on top needs no patching.
- **Scripted testing on my live screen.** It got Mission Control stuck open while I was working. After that, checks read the add-on's state in the background instead.
- **Stripping only symbols from session titles.** The glyph cut still trims every leading non-ASCII character. For now it's written down as a known limit instead.
- **A generic default for `titleCuts`.** It ships with the cut my own shell needs. My Hammerspoon runs this exact file, so changing it would change my own names.

## 8. What's next

- Swipe exits timed with a real finger on a trackpad, not a scripted close.
- More than one display.
- A design pass on the chip look, on real Mission Control backgrounds.

## 9. Sources

- Commits: `git log` of `fidgetcoding/desktop-renamer`.
- [README.md](README.md) (Known limits, How it compares) and [SECURITY.md](SECURITY.md).
- Private, kept by me: the build session notes and the launch session notes, both dated November 5, 2026.


## 2026-11-06: recovery across lock and wake

Reported: labels failed again after the Mac was left open overnight and unlocked.
Hammerspoon was still running from the previous evening, its Dock observer reported
active, and its timers were present. There was no session lifecycle watcher. Prior
repairs handled missing Mission Control events and Dock PID changes, but retained
native canvases and AX registrations across lock/unlock with the same Dock PID.
This is a recovery gap; the live state alone does not establish which native object
failed overnight.

Changed: sleep/lock/session departure stops drawing and disposes of native overlays;
wake/unlock/session return reconnects through a retry loop. Cached names are preserved,
colors are sampled again, and failed AX attachments are retried. The loop catches
callback errors so Hammerspoon cannot permanently stop it after a transient failure.
It also handles missed closes and restarts disabled input taps while Mission Control
is open. `status()` exposes observer/recovery health and the last recovery error.

Validation: lifecycle regression checks cover sleep/wake, lock/unlock, user switching,
same-PID reconnection, canvas disposal, saved-name preservation, Dock absence/restart,
AX retry, missed close, disabled input, and stopped drawing timers. Existing cleanup
regression checks also pass under Hammerspoon's Lua. An actual overnight cycle has
not been reproduced in this session.


## 2026-11-07: v0.1.1, external monitors

Reported: names had worked for days, then broke the moment an external monitor was
plugged in. The monitor's desktops got no names, and the laptop's desktops lost theirs.

Cause, two bugs. Mission Control shows one row of desktop labels per display, but the
overlay read only the first row and placed and coloured every name as if it sat on the
laptop screen, pairing one display's label positions with the other's desktops. Name
learning took the front windows from every display and filed them under the one
focused desktop, so apps on the monitor renamed the laptop's desktop.

Changed: every display's row is read, matched to its screen by position, and laid
out, colour-sampled and drawn on its own (overlay state and colour cache are per
screen; any screen's wallpaper change or a screen coming or going resets colours).
Each display's front desktop learns its name only from windows on that display.

Validation: both regression tests updated and passing under Hammerspoon's Lua; the
module loads with no errors after a restart. Not yet seen live in Mission Control with
the monitor attached.
