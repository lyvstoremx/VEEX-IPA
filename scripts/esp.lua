local t0 = os.time()
local done = false

function tick()
  if done then return end
  if not i2c_ready() then
    if os.time() - t0 > 20 then done = true log("SIN IL2CPP") end
    return
  end
  done = true
  local kl = i2c_class("COW.GamePlay", "Player")
  if not kl then log("NO PLAYER") return end
  local f = fields(kl)
  log("cont="..#f)
  for i = 1, math.min(#f, 80) do log("  "..f[i]) end
  local t = dump("Manager", 4000)
  local n = 0
  for i = 1, #t do
    if string.find(t[i].s, "COW.GamePlay") and n < 40 then
      n = n + 1
      log("M ["..t[i].s.."] "..t[i].n)
    end
  end
  log("PROBE5 FIN")
end
