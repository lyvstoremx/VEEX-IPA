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
  local par = parents(kl)
  log("padres="..#par)
  for i = 1, #par do
    local ns, nm = string.match(par[i], "^(.+)::(.+)$")
    log("P "..par[i])
    if nm then
      if ns == "-" then ns = "" end
      local c = i2c_class(ns, nm)
      if c then
        local f = fields(c)
        log("  campos="..#f)
        for j = 1, math.min(#f, 50) do log("    "..f[j]) end
      end
    end
  end
  log("PROBE4 FIN")
end
