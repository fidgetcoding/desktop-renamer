-- Run with Lua or Hammerspoon: loadfile(path)(absoluteSourcePath).
local sourcePath = ... or "desktop-names.lua"
local file = assert(io.open(sourcePath))
local source = file:read("*a"); file:close()
assert(load(source, "@" .. sourcePath))
local body = assert(source:match('(local function resetSession%(%)\n.-)\n%-%- ── wiring'))
local pid, ready, bar, failAX = 42, true, false, false
local attached, deleted, opened, closed = 0, 0, 0, 0
local mc = { pool = {}, input = {} }
function mc.input:isEnabled() return self.enabled end
function mc.input:start() self.enabled = true end
local state = { custom = { ['1'] = 'Custom' }, auto = { ['1'] = 'Saved' }, colors = { old = true } }
local function timer(fn)
  return { fn = fn, running = function() return true end }
end
local events = { systemWillSleep=1, screensDidLock=2, sessionDidResignActive=3,
  systemDidWake=4, screensDidUnlock=5, sessionDidBecomeActive=6 }
function events.new(fn) return { fn=fn, start=function(self) return self end } end
local M = {}
local env = setmetatable({ mc=mc, state=state, M=M, dlog=function() end,
  hs={ timer={doEvery=function(_, fn) return timer(fn) end}, caffeinate={watcher=events},
    application={get=function() if ready then return {pid=function() return pid end} end end} },
  onClose=function() closed=closed+1; mc.timer=nil; mc.drawn=false end,
  onOpen=function() opened=opened+1; mc.timer=timer(); mc.drawn=true end,
  spacesBar=function() if failAX then error('AX temporarily unavailable') end; return nil, bar and {} or nil end,
  watchDock=function()
    attached=attached+1
    if failAX then error('AX registration failed') end
    mc.dockPid=pid
    mc.observer={stop=function() end,isRunning=function() return true end}
  end,
}, {__index=_G})
assert(load(body,'lifecycle','t',env))()
local check=mc.reconcile.fn
check(); assert(attached==1 and mc.dockPid==42)
for _, pair in ipairs({{1,4},{2,5},{3,6}}) do
  mc.pool[3]={delete=function() deleted=deleted+1 end}
  M.sessionWatcher.fn(pair[1]); assert(mc.suspended and not mc.observer and next(mc.pool)==nil)
  local n=attached; bar=true; check(); assert(attached==n,'locked session must not reattach')
  M.sessionWatcher.fn(pair[2]); check()
  assert(not mc.suspended and attached==n+1 and mc.drawn,'same PID must reconnect after resume')
end
assert(deleted==3 and state.custom['1']=='Custom' and state.auto['1']=='Saved')
assert(next(state.colors)==nil,'native color cache must be refreshed')
bar=false; check(); assert(not mc.timer,'missed close must clean overlays')
pid=43; failAX=true; check(); assert(mc.dockPid==nil and M.status().lastError)
failAX=false; check(); assert(mc.dockPid==43,'failed attachment must retry')
ready=false; check(); assert(mc.dockPid==nil)
ready=true; check(); assert(mc.dockPid==43,'late Dock startup must recover')
bar=true; mc.input.enabled=false; check(); assert(mc.input.enabled and mc.timer)
mc.timer.running=function() return false end
local n=opened; check(); assert(opened==n+1,'stopped drawing timer must restart')
failAX=true; check(); failAX=false; check(); assert(M.status().reconcile)
return 'PASS: sleep/wake, lock/unlock, user switching, same-PID reconnect, canvas disposal, saved names, Dock restart/absence, AX retry, missed close, input restart, stopped timer'
