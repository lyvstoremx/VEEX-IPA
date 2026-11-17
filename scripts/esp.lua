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
  log("kl="..string.format("%x", kl))
  local f = fields(kl)
  log("campos="..#f)
  for i = 1, math.min(#f, 120) do log("  "..f[i]) end
  local m = meths(kl, 200)
  log("metodos="..#m)
  for i = 1, math.min(#m, 200) do log("  "..m[i]) end
  log("PROBE3 FIN")
end
