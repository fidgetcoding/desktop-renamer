-- Run from the repo root: lua tests/hide-all.lua
-- Also runnable with Hammerspoon's Lua via loadfile and an explicit source path.
local sourcePath = ... or "desktop-names.lua"
local file = assert(io.open(sourcePath))
local source = file:read("*a")
file:close()
assert(load(source, "@" .. sourcePath))
local body = assert(source:match("local function hideAll%(%)\n(.-)\nend"))
local hidden, logs = {}, {}
local mc = { drawn = true, disp = { d = { drawn = true, chips = { [2] = {} } } }, pool = {} }
for _, index in ipairs({ 2, 5 }) do
  mc.pool[index] = { hide = function() hidden[index] = true end }
end
local env = setmetatable({ mc = mc, dlog = function(msg) logs[#logs + 1] = msg end }, { __index = _G })
local hide = assert(load("return function()\n" .. body .. "\nend", "hideAll", "t", env))()
-- Timer callbacks can tail-call hideAll with no Lua caller frame remaining.
local ok, err = coroutine.resume(coroutine.create(function() return hide() end))
assert(ok, err)
assert(hidden[2] and hidden[5], "sparse canvas pools must all be hidden")
assert(mc.drawn == false and not mc.disp.d.drawn and next(mc.disp.d.chips) == nil, "cleanup must reset draw state")
assert(#logs == 1, "drawn overlays should log their hide")
assert(coroutine.resume(coroutine.create(function() return hide() end)))
assert(#logs == 1, "repeated cleanup should be harmless")
return "PASS: tail-call cleanup, sparse pool, state reset, repeated cleanup; source compiles"
