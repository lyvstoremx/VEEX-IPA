local t0 = os.time()
local done = false

function tick()
  if done then return end
  if not i2c_ready() then
    if os.time() - t0 > 20 then done = true log("SIN IL2CPP") end
    return
  end
  done = true
  local pn = i2c_class("COW.GamePlay", "PlayerNetwork")
  if not pn then log("NO PN") return end
  local lst = sget(pn, "OFINKLEDDFE")
  log("lista="..string.format("%x", lst))
  if lst == 0 then log("LISTA NULA, entra a partida") return end
  local n = arrlen(lst)
  log("n="..n)
  for i = 0, math.min(n, 8) - 1 do
    local e = arrat(lst, i)
    local k = kl(e)
    log(i.." e="..string.format("%x", e).." cls="..(k and string.format("%x", k) or "0"))
  end
  local jk = i2c_class("COW.GamePlay", "JDMOMODGGFK")
  if jk then
    local par = parents(jk)
    for i = 1, #par do log("P "..par[i]) end
    local f = fields(jk)
    log("campos="..#f)
    for i = 1, math.min(#f, 70) do log("  "..f[i]) end
  end
  log("PROBE9 FIN")
end
