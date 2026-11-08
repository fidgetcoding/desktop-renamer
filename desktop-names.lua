-- desktop-names.lua — real names on the desktops in Mission Control.
-- https://github.com/fidgetcoding/desktop-renamer · MIT · v0.1.1 (external monitors)
--
-- macOS has no API to rename Mission Control's "Desktop N" labels, so while Mission
-- Control is open this draws each desktop's name over its label, filled with the bar's
-- own colour so the old text is covered. Clicks pass through to the real label.
--
-- Name resolution per desktop, first hit wins:
--   1. a custom name, set with the rename hotkey on that desktop (empty = back to automatic)
--   2. the title of the most recently focused titleApps window there, status glyph stripped
--      (Claude Code keeps its terminal's title set to the session's topic, so it renames itself)
--   3. a category, when the apps last seen in front there match one of the rules below
--   4. the apps last seen in front on that desktop, e.g. "Mail · Slack"
--   5. nothing: the native "Desktop N" label shows
-- Hammerspoon only sees windows on desktops visited since it last started, so 2 to 4
-- are cached in desktop-names.json and used until that desktop is visited again.
-- Space ids survive reorders and reboots and die with the desktop, so a name follows
-- its desktop when it is dragged to a new position.

-- ── settings: edit these ────────────────────────────────────────────────────────
-- These are my own rules, shipped as working examples. Change them to fit your desktops.
local SETTINGS = {
  -- press this on any desktop to name it yourself; set to false to turn it off
  renameHotkey = { mods = { "ctrl", "alt", "cmd" }, key = "D" },

  -- apps whose window title names the desktop it sits on. Claude Code keeps the
  -- terminal title set to the session's topic, so those desktops name themselves.
  titleApps = { "Ghostty" },
  -- Lua patterns cut out of those titles (my shell tacks " | BRAIN2" onto mine)
  titleCuts = { "%s*|%s*BRAIN2$" },

  -- desktops without such a window get a category when their apps say what they're
  -- for. First rule that matches wins. any = at least one of these apps is there;
  -- only = these apps and nothing else. Names match loosely ("Telegram Desktop" = Telegram).
  categories = {
    { name = "Messaging", any = { "Messages", "Telegram", "Signal", "WhatsApp" } },
    { name = "Browsing", only = { "Arc", "Google Chrome", "Safari", "Firefox", "Brave Browser", "Microsoft Edge", "Dia", "Comet", "Zen", "Orion" } },
  },

  -- no title and no category: show this many front apps, e.g. "Mail · Slack"
  frontApps = 2,
}

local M = {}
M.version = "0.1.1"
M.settings = SETTINGS

-- load extensions now, not on first use inside Mission Control: a lazy load prints a
-- console line and costs time on the first draw
local _ = hs.axuielement, hs.canvas, hs.drawing, hs.eventtap, hs.styledtext, hs.screen, hs.spaces

local STORE = hs.configdir .. "/desktop-names.json"

-- { custom = {[id] = name}, auto = {[id] = {name=, kind=}} }, ids as strings
local state = (hs.fs.attributes(STORE) and hs.json.read(STORE)) or {}
state.custom, state.auto = state.custom or {}, state.auto or {}

local function save() hs.json.write(state, STORE, true, true) end

-- "◑ Fix the login bug" -> "Fix the login bug": terminals put a status glyph (a
-- spinner, a dot) in front of the title, so any leading run of non-ASCII bytes and
-- whitespace goes, along with trailing whitespace
local function stripGlyph(title)
  return ((title or ""):gsub("^[\128-\255%s]+", ""):gsub("%s+$", ""))
end
M.stripGlyph = stripGlyph

function M.remember(spaceId, name, kind)
  local k, old = tostring(spaceId), state.auto[tostring(spaceId)]
  if name == nil then
    if old then state.auto[k] = nil; save() end
  elseif not (old and old.name == name and old.kind == kind) then
    state.auto[k] = { name = name, kind = kind }; save()
  end
end

-- every desktop on every display, in Mission Control order
local function orderedSpaces()
  local out = {}
  for _, scr in ipairs(hs.screen.allScreens()) do
    for i, sp in ipairs(hs.spaces.spacesForScreen(scr) or {}) do
      table.insert(out, { id = sp, n = i, screen = scr })
    end
  end
  return out
end

local titleWindows = hs.window.filter.new(SETTINGS.titleApps)

local function windowTitle(spaceId)
  for _, w in ipairs(titleWindows:getWindows(hs.window.filter.sortByFocusedLast)) do
    for _, s in ipairs(hs.spaces.windowSpaces(w) or {}) do
      if s == spaceId then
        local t = stripGlyph(w:title())
        for _, cut in ipairs(SETTINGS.titleCuts) do t = t:gsub(cut, "") end
        if t ~= "" then return t end
      end
    end
  end
end

-- app names match loosely: WhatsApp's name starts with an invisible U+200E mark, and
-- Telegram calls itself "Telegram Desktop"
local function appKey(name)
  return ((name:gsub("[^%w ]", "")):lower():gsub("%s+desktop$", ""):gsub("^%s+", ""))
end

local function keySet(names)
  if not names then return nil end
  local set = {}
  for _, n in ipairs(names) do set[appKey(n)] = true end
  return set
end

local RULES = {}
for i, rule in ipairs(SETTINGS.categories) do
  RULES[i] = { name = rule.name, any = keySet(rule.any), only = keySet(rule.only) }
end

local function category(apps)
  for _, rule in ipairs(RULES) do
    if rule.any then
      for _, a in ipairs(apps) do if rule.any[appKey(a)] then return rule.name end end
    end
    if rule.only and #apps > 0 then
      local all = true
      for _, a in ipairs(apps) do if not rule.only[appKey(a)] then all = false; break end end
      if all then return rule.name end
    end
  end
end

-- each display's front desktop has its windows visible, so this is where the cache gets
-- corrected. Windows count only toward the desktop of the screen they sit on, or a second
-- monitor's apps would rename the laptop's desktop.
local function learnFrontDesktop()
  local windows = hs.window.orderedWindows()
  for _, scr in ipairs(hs.screen.allScreens()) do
    local sp = hs.spaces.activeSpaceOnScreen(scr)
    if sp and not windowTitle(sp) then   -- a titled desktop: M.nameOf caches it
      local apps, have = {}, {}
      for _, w in ipairs(windows) do
        local app = w:application() and w:application():name()
        if app and not have[app] and w:isStandard() and w:screen() == scr then
          have[app] = true
          table.insert(apps, app)
        end
      end
      if #apps == 0 then
        M.remember(sp, nil)
      else
        M.remember(sp, category(apps) or table.concat({ table.unpack(apps, 1, SETTINGS.frontApps) }, " · "), "apps")
      end
    end
  end
end

function M.nameOf(spaceId, n)
  local k = tostring(spaceId)
  if state.custom[k] then return state.custom[k], "custom" end
  local g = windowTitle(spaceId)
  if g then M.remember(spaceId, g, "session"); return g, "session" end
  local a = state.auto[k]
  -- a cached session title whose window now sits on another desktop is stale: the
  -- window moved, so this desktop must not keep its name
  if a and a.kind == "session" then
    for _, w in ipairs(titleWindows:getWindows()) do
      local t = stripGlyph(w:title())
      for _, cut in ipairs(SETTINGS.titleCuts) do t = t:gsub(cut, "") end
      if t == a.name then
        M.remember(spaceId, nil)
        a = nil
        break
      end
    end
  end
  if a then return a.name, a.kind end
  return "Desktop " .. (n or "?"), "default"
end

function M.rename()
  local cur, n = hs.spaces.focusedSpace(), "?"
  for _, e in ipairs(orderedSpaces()) do if e.id == cur then n = e.n end end
  local k = tostring(cur)
  hs.focus()
  local btn, text = hs.dialog.textPrompt("Name this desktop",
    "Leave empty to go back to the automatic name.", state.custom[k] or M.nameOf(cur, n), "Save", "Cancel")
  if btn ~= "Save" then return end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  state.custom[k] = text ~= "" and text or nil
  save()
end

-- ── Mission Control overlay ──────────────────────────────────────────────────────
-- The Dock posts AXExposeShowAllWindows / AXExposeExit when Mission Control opens and
-- closes, and exposes one button per desktop under mc > mc.display > mc.spaces >
-- mc.spaces.list. Measured on macOS 26 (2026-11-05):
--   collapsed bar (72pt): the buttons are the "Desktop N" labels, reported one bar
--     height too high
--   expanded bar (164pt, cursor at the top): the buttons are the 139×90 thumbnails,
--     reported where they are; each label sits centred just under its thumbnail
-- The frames update while the bar slides, so the names move with it every tick.
--
-- Speed: each name is filled with the bar colour behind it, and that colour can only be
-- sampled while no name is showing. Samples are cached by bar mode, position and
-- highlight (reset when the wallpaper changes), so a layout seen before draws on the
-- first tick. A new layout waits SETTLE for the bar to land, samples once, then draws.
-- AXExposeExit arrives late, so closing is caught earlier: a click or key hides the
-- names on the spot for QUIET, and so does the bar starting to slide up (a swipe or
-- hot-corner exit sends no click or key). The bar vanishing from AX hides them too.

local TICK = 0.04
local SETTLE = 0.2
local QUIET = 0.5
local COLLAPSED_H = 72
local FONT = hs.styledtext.defaultFonts.system.name

local SHOT_KEYS = { hs.keycodes.map["3"], hs.keycodes.map["4"], hs.keycodes.map["5"], hs.keycodes.map["6"] }
local mc = { pool = {}, disp = {} }
M.mc = mc
-- debug trace, off unless ~/.hammerspoon/desktop-names.debug exists (read at load)
local DEBUG = hs.fs.attributes(os.getenv("HOME") .. "/.hammerspoon/desktop-names.debug") ~= nil
local function dlog(msg)
  if not DEBUG then return end
  local o = io.open("/tmp/desktop-names-debug.log", "a")
  if o then o:write(string.format("%.2f %s\n", hs.timer.secondsSinceEpoch(), msg)); o:close() end
end
M.dlog = dlog
state.colors = state.colors or {}

local function child(e, id)
  for _, c in ipairs((e and e:attributeValue("AXChildren")) or {}) do
    if c:attributeValue("AXIdentifier") == id then return c end
  end
end

-- with more than one display, mc holds one mc.display per screen, each with its own bar
local function spacesBars()
  local dock = hs.application.get("com.apple.dock")
  if not dock then return {} end
  local root = child(hs.axuielement.applicationElement(dock), "mc")
  local out = {}
  for _, d in ipairs((root and root:attributeValue("AXChildren")) or {}) do
    if d:attributeValue("AXIdentifier") == "mc.display" then
      local bar = child(d, "mc.spaces")
      local list = child(bar, "mc.spaces.list")
      if list then table.insert(out, { bar = bar, list = list }) end
    end
  end
  return out
end

-- the screen a bar sits on: the one containing its centre
local function screenAt(f)
  local cx, cy = f.x + f.w / 2, f.y + f.h / 2
  for _, scr in ipairs(hs.screen.allScreens()) do
    local s = scr:fullFrame()
    if cx >= s.x and cx < s.x + s.w and cy >= s.y and cy < s.y + s.h then return scr end
  end
end

-- per bar: screen, bar height, button frames, and a signature that changes whenever
-- any of them does
local function readBars()
  local out = {}
  for _, b in ipairs(spacesBars()) do
    -- Dock AX elements can disappear between reads during a transition.
    local barFrame = b.bar:attributeValue("AXFrame")
    local scr = barFrame and screenAt(barFrame)
    if scr then
      local frames, sig = {}, { string.format("%.0f", barFrame.h) }
      for i, e in ipairs(b.list:attributeValue("AXChildren") or {}) do
        local f = e:attributeValue("AXFrame")
        if f then
          frames[i] = f
          sig[#sig + 1] = string.format("%.0f,%.0f,%.0f", f.x, f.y, f.w)
        end
      end
      table.insert(out, { scr = scr, id = scr:getUUID(), barH = barFrame.h, frames = frames,
        sig = table.concat(sig, " ") })
    end
  end
  return out
end

-- per-display overlay state, keyed by screen UUID: sig, stillSince, expanded, count,
-- topY, drawn, chips
local function disp(id)
  mc.disp[id] = mc.disp[id] or { chips = {} }
  return mc.disp[id]
end

local function hideDisplay(id)
  local d = disp(id)
  for i in pairs(d.chips) do if mc.pool[id .. ":" .. i] then mc.pool[id .. ":" .. i]:hide() end end
  d.chips, d.drawn = {}, false
end

local function hideAll()
  if mc.drawn then dlog("hide") end
  for _, c in pairs(mc.pool) do c:hide() end
  for _, d in pairs(mc.disp) do d.chips, d.drawn, d.sig = {}, false, nil end
  mc.drawn = false
end

local function measure(text, size) return hs.drawing.getTextDrawingSize(text, { font = FONT, size = size }) end

local function trimTo(name, size, maxW)
  local base, text = name, name
  while measure(text, size).w > maxW and #base > 1 do
    base = base:sub(1, utf8.offset(base, -1) - 1):gsub("[%s%p]+$", "")
    text = base .. "…"
  end
  return text
end

-- one line at the largest size that fits; past that, collapsed labels wrap to two
-- lines at 10.5pt and expanded ones (no room under the thumbnails) trim to one line
local function fit(name, maxW, expanded)
  for _, size in ipairs(expanded and { 14, 13 } or { 13, 12, 11 }) do
    local sz = measure(name, size)
    if sz.w <= maxW then return name, size, 1, sz end
  end
  if expanded then
    local text = trimTo(name, 13, maxW)
    return text, 13, 1, measure(text, 13)
  end
  local text = trimTo(name, 10.5, maxW * 1.8)
  return text, 10.5, 2, measure(text, 10.5)
end

-- where each native label sits; expanded labels are measured at their larger size
local function labelRects(barH, frames)
  local expanded, rects = barH > COLLAPSED_H + 8, {}
  for i, f in ipairs(frames) do
    if expanded then
      local w = measure("Desktop " .. i, 15).w + 8
      rects[i] = { x = f.x + f.w / 2 - w / 2, y = f.y + f.h + 2, w = w, h = 21 }
    else
      rects[i] = { x = f.x, y = f.y + barH, w = f.w, h = f.h }
    end
  end
  return rects, expanded
end

-- rects plus the colour-cache key per label (the current desktop's label sits on a highlight)
local function layout(B)
  local scr = B.scr
  local spaces = hs.spaces.spacesForScreen(scr) or {}
  local cur = hs.spaces.activeSpaceOnScreen(scr)
  local rects, expanded = labelRects(B.barH, B.frames)
  local origin = scr:fullFrame()
  local keys = {}
  for i, r in ipairs(rects) do
    keys[i] = string.format("%s%s%d%s", B.id:sub(1, 8), expanded and "e" or "c",
      math.floor((r.x - origin.x + r.w / 2) / 8), (not expanded and spaces[i] == cur) and "h" or "")
  end
  return { scr = scr, id = B.id, origin = origin, spaces = spaces, rects = rects, expanded = expanded, keys = keys }
end

local function allCached(L)
  for _, k in ipairs(L.keys) do if not state.colors[k] then return false end end
  return true
end

-- just left of the label text is the bar, or the highlight pill; only while nothing of ours
-- shows. Snapshot rects are relative to the screen, label rects are global.
local function sampleColors(L, barH)
  local w = L.origin.w
  local img = L.scr:snapshot({ x = 0, y = 0, w = w, h = barH })
  if not img then return end
  local k = img:size().w / w
  for i, r in ipairs(L.rects) do
    local c = img:colorAt({ x = math.floor((r.x - L.origin.x - (L.expanded and 8 or 5)) * k),
      y = math.floor((r.y - L.origin.y + r.h / 2) * k) })
    if c then state.colors[L.keys[i]] = { red = c.red, green = c.green, blue = c.blue } end
  end
  save()
end

local function canvasAt(key)
  local c = mc.pool[key]
  if not c then
    c = hs.canvas.new({ x = 0, y = 0, w = 10, h = 10 })
    c:level(hs.canvas.windowLevels.screenSaver):behavior({ "canJoinAllSpaces", "stationary" })
    mc.pool[key] = c
  end
  return c
end

local function chipFrame(r, chip)
  return { x = r.x + r.w / 2 - chip.w / 2, y = r.y + r.h / 2 - chip.h / 2, w = chip.w, h = chip.h }
end

local function draw(L)
  hideDisplay(L.id)
  local d = disp(L.id)
  -- room per name = distance between neighbouring centres
  local pitch = L.expanded and 180 or 110
  for i = 2, #L.rects do
    pitch = math.min(pitch, (L.rects[i].x + L.rects[i].w / 2) - (L.rects[i - 1].x + L.rects[i - 1].w / 2))
  end
  local maxW = pitch - 8
  for i, r in ipairs(L.rects) do
    local name, kind = M.nameOf(L.spaces[i] or 0, i)
    if L.spaces[i] and kind ~= "default" then
      local text, size, lines, sz = fit(name, maxW - 16, L.expanded)
      local chip = { w = math.min(maxW, math.max(r.w + 16, sz.w + 16)), h = lines == 1 and r.h or 30 }
      local c = canvasAt(L.id .. ":" .. i)
      c:frame(chipFrame(r, chip))
      c:replaceElements(
        { type = "rectangle", action = "fill", fillColor = state.colors[L.keys[i]] or { white = 0.35 },
          roundedRectRadii = { xRadius = 7, yRadius = 7 } },
        { type = "text", frame = { x = 4, y = lines == 1 and (chip.h - sz.h) / 2 or 1, w = chip.w - 8, h = chip.h },
          text = hs.styledtext.new(text, { font = { name = FONT, size = size }, color = { white = 1 },
            paragraphStyle = { alignment = "center", lineBreak = "wordWrap" } }) })
      -- Interrupted canvas fades can leave alpha at zero on later shows.
      c:alpha(1):show()
      d.chips[i] = chip
    end
  end
  d.drawn, mc.drawn, mc.drewAt = true, true, hs.timer.secondsSinceEpoch()
  dlog(string.format("draw %s names expanded=%s", L.id:sub(1, 8), tostring(L.expanded)))
end

local function follow(B)
  local d, rects = disp(B.id), labelRects(B.barH, B.frames)
  for i, chip in pairs(d.chips) do
    if rects[i] then mc.pool[B.id .. ":" .. i]:frame(chipFrame(rects[i], chip)) end
  end
end

local onClose

local function tickDisplay(B, now)
  local d = disp(B.id)
  local expanded = B.barH > COLLAPSED_H + 8
  local topY = math.huge
  for _, f in ipairs(B.frames) do topY = math.min(topY, f.y) end
  local rising = d.topY and expanded == d.expanded and topY < d.topY - 1
  d.topY = topY
  if rising then                                -- the bar is sliding away: Mission Control is closing
    dlog(string.format("rising %s topY=%.1f", B.id:sub(1, 8), topY))
    -- Hide during movement, but retry once the bar settles. AX movement
    -- also happens when expanding/collapsing, not just when exiting.
    d.sig, d.stillSince = nil, now
    return hideDisplay(B.id)
  end
  if B.sig ~= d.sig then
    d.sig, d.stillSince = B.sig, now
    if d.drawn and expanded == d.expanded and #B.frames == d.count then
      follow(B)                                 -- same layout, sliding in or shifting
    else
      hideDisplay(B.id)
      d.expanded, d.count = expanded, #B.frames
      local L = layout(B)
      if allCached(L) then draw(L) end         -- seen before: no wait
    end
  elseif not d.drawn and now - (d.stillSince or now) >= SETTLE then
    local L = layout(B)                        -- new layout, bar has landed
    sampleColors(L, B.barH)
    draw(L)
  end
end

local function tick()
  mc.ticks = mc.ticks + 1
  local bars = readBars()
  if #bars == 0 then
    -- gone after being seen means closed; before that, give the Dock a moment
    if mc.seenBar or mc.ticks % 10 == 0 then return onClose() end
    return
  end
  mc.seenBar = true
  local now = hs.timer.secondsSinceEpoch()
  if mc.mouseDown or now < mc.quietUntil or mc.leaving then return end
  for _, B in ipairs(bars) do tickDisplay(B, now) end
end

mc.input = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.leftMouseUp,
  hs.eventtap.event.types.rightMouseDown, hs.eventtap.event.types.keyDown }, function(e)
  local t, now = e:getType(), hs.timer.secondsSinceEpoch()
  -- a screenshot must not hide the names, or every screenshot of Mission Control shows
  -- none: ⌘⇧3/4/5/6 starts shot mode, and the drag-select clicks of ⌘⇧4/5 pass
  -- through until the capture is done
  if t == hs.eventtap.event.types.keyDown then
    local f, k = e:getFlags(), e:getKeyCode()
    if f.cmd and f.shift and (k == SHOT_KEYS[1] or k == SHOT_KEYS[2] or k == SHOT_KEYS[3] or k == SHOT_KEYS[4]) then
      mc.shotUntil = now + 15
      return false
    end
  end
  if now < (mc.shotUntil or 0) then
    if t == hs.eventtap.event.types.leftMouseUp then mc.shotUntil = now + 0.8 end
    return false
  end
  dlog("input type=" .. t .. " key=" .. tostring(t == hs.eventtap.event.types.keyDown and e:getKeyCode() or "-"))
  mc.mouseDown = t == hs.eventtap.event.types.leftMouseDown
  mc.quietUntil = now + QUIET
  hideAll()
  return false
end)

-- switching desktops inside Mission Control moves the highlight
function M.desktopChanged()
  if mc.timer then hideAll() end
end

onClose = function()
  dlog("close ticks=" .. tostring(mc.ticks))
  mc.input:stop()
  if mc.timer then mc.timer:stop(); mc.timer = nil end
  mc.mouseDown = false
  hideAll()
end

local function onOpen()
  if mc.suspended then return end
  if mc.timer then mc.timer:stop() end
  -- colours are cached per screen, so any screen's wallpaper (or a screen coming or
  -- going) resets them
  local walls = {}
  for _, scr in ipairs(hs.screen.allScreens()) do walls[#walls + 1] = scr:getUUID() .. "=" .. tostring(scr:desktopImageURL()) end
  table.sort(walls)
  local wall = table.concat(walls, ";")
  if state.colors.wallpaper ~= wall then state.colors = { wallpaper = wall } end
  mc.ticks, mc.mouseDown, mc.quietUntil, mc.disp = 0, false, 0, {}
  mc.seenBar, mc.leaving = false, false
  mc.openedAt = hs.timer.secondsSinceEpoch()
  dlog("open")
  hideAll()
  mc.input:start()
  mc.timer = hs.timer.doEvery(TICK, tick)
  tick()                                        -- first look now, not one tick from now
end

local function watchDock()
  if mc.observer then mc.observer:stop(); mc.observer = nil end
  mc.dockPid = nil
  local dock = hs.application.get("com.apple.dock")
  if not dock then return end
  local app = hs.axuielement.applicationElement(dock)
  mc.observer = hs.axuielement.observer.new(dock:pid())
    :callback(function(_, _, note)
      if note == "AXExposeShowAllWindows" then onOpen() else onClose() end
    end)
    :addWatcher(app, "AXExposeShowAllWindows")
    :addWatcher(app, "AXExposeExit")
    :start()
  mc.dockPid = dock:pid() -- only mark attached after all registrations succeed
end

-- Sleep/unlock can invalidate native overlay windows and AX registrations even
-- when Dock keeps its PID. Discard those objects, not the saved desktop names.
local function resetSession()
  onClose()
  if mc.observer then mc.observer:stop(); mc.observer = nil end
  mc.dockPid, mc.shotUntil = nil, nil
  for _, c in pairs(mc.pool) do c:delete() end
  mc.pool = {}
  state.colors = {}
  mc.recoveries = (mc.recoveries or 0) + 1
end

-- Hammerspoon stops ordinary timers after a callback error. Keep the recovery
-- loop alive through transient Dock/AX failures, and expose the error for diagnosis.
local function guarded(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      mc.lastError = tostring(err)
      dlog("error: " .. mc.lastError)
    end
  end
end

local function reconcile()
  if mc.suspended then return end
  local dock = hs.application.get("com.apple.dock")
  if not dock then
    if mc.dockPid then resetSession() end
    return
  end
  if dock:pid() ~= mc.dockPid or not mc.observer or not mc.observer:isRunning() then
    resetSession()
    watchDock()
  end
  if #spacesBars() > 0 then
    if not mc.timer or not mc.timer:running() then onOpen() end
    if not mc.input:isEnabled() then mc.input:start() end
  elseif mc.timer then
    onClose()
  end
end
mc.reconcile = hs.timer.doEvery(0.3, guarded(reconcile))

local events = hs.caffeinate.watcher
M.sessionWatcher = events.new(guarded(function(event)
  if event == events.systemWillSleep or event == events.screensDidLock
      or event == events.sessionDidResignActive then
    mc.suspended = true
    resetSession()
  elseif event == events.systemDidWake or event == events.screensDidUnlock
      or event == events.sessionDidBecomeActive then
    resetSession()
    mc.suspended = false
    -- The reconciliation loop retries until Dock is ready; no fixed login delay.
  end
end)):start()

function M.status()
  return {
    suspended = mc.suspended == true, recoveries = mc.recoveries or 0,
    observer = mc.observer ~= nil and mc.observer:isRunning(),
    reconcile = mc.reconcile:running(), drawing = mc.drawn == true,
    lastError = mc.lastError,
  }
end

-- ── wiring ──────────────────────────────────────────────────────────────────────

M.spaceWatcher = hs.spaces.watcher.new(function()
  M.desktopChanged()
  hs.timer.doAfter(0.3, learnFrontDesktop)   -- the window list lags the switch slightly
end):start()

if SETTINGS.renameHotkey then
  M.hotkey = hs.hotkey.bind(SETTINGS.renameHotkey.mods, SETTINGS.renameHotkey.key, M.rename)
end

-- re-apply the category rules to cached app names, so a new rule relabels desktops
-- seen before ("Messages · Telegram" → "Messaging") without visiting each one
for _, a in pairs(state.auto) do
  if a.kind == "apps" then
    local apps = {}
    for app in (a.name .. " · "):gmatch("(.-) · ") do table.insert(apps, app) end
    a.name = category(apps) or a.name
  end
end

-- forget desktops that no longer exist. Only when macOS actually reports some: right
-- after login the list can come back empty, and pruning then would erase every name.
local live, pruned = {}, false
for _, e in ipairs(orderedSpaces()) do live[tostring(e.id)] = true end
if next(live) then
  for _, t in ipairs({ state.custom, state.auto }) do
    for k in pairs(t) do if not live[k] then t[k] = nil; pruned = true end end
  end
end
if pruned then save() end

guarded(reconcile)()
guarded(learnFrontDesktop)()
return M
