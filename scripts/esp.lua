local t0 = os.time()
local done = false
local keys = {"Mgr","Manager","Network","Battle","Room","World","Entity"}

function tick()
  if done then return end
  if not i2c_ready() then
    if os.time() - t0 > 20 then done = true log("SIN IL2CPP") end
    return
  end
  done = true
  local kl = i2c_class("COW.GamePlay", "Player")
  if kl then
    local s = statics(kl)
    log("statics="..#s)
    for i = 1, math.min(#s, 120) do log("  "..s[i]) end
  end
  for _, k in ipairs(keys) do
    local t = dump(k, 6000)
    local n = 0
    for i = 1, #t do
      if string.find(t[i].s, "COW.GamePlay") and n < 18 then
        n = n + 1
        log("K "..k.." ["..t[i].s.."] "..t[i].n)
      end
    end
  end
  log("PROBE6 FIN")
end
