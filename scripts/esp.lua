local t0 = os.time()
local done = false

function tick()
  if done then return end
  if not i2c_ready() then
    if os.time() - t0 > 20 then done = true log("SIN IL2CPP") end
    return
  end
  done = true
  local kl = i2c_class("COW.GamePlay", "PlayerNetwork")
  if not kl then log("NO PN") return end
  local f = fields(kl)
  log("campos="..#f)
  for i = 1, math.min(#f, 100) do log("  "..f[i]) end
  local s = statics(kl)
  log("statics="..#s)
  for i = 1, math.min(#s, 60) do log("  S "..s[i]) end
  local m = meths(kl, 250)
  log("metodos="..#m)
  for i = 1, math.min(#m, 200) do log("  M "..m[i]) end
  log("PROBE7 FIN")
end
