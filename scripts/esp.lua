local t0 = os.time()
local step = 0

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end
  if step == 0 then
    step = 1
    local pl = i2c_class("COW.GamePlay", "Player")
    local m = pl and i2c_mptr(pl, "ComputePosition", 0)
    if not m then m = pl and i2c_mptr(pl, "OnUpdate", 1) end
    if not m then log("SIN METODO") return end
    log("hook="..hook1(m))
    return
  end
  if step == 1 then
    if os.time() - t0 < 3 then return end
    step = 2
    local n = hv_count()
    log("cosechados="..n)
    for i = 0, math.min(n, 10) - 1 do
      local o = hv_get(i)
      local k = kl(o)
      log(i.." o="..string.format("%x", o).." cls="..(k and string.format("%x", k) or "0"))
    end
    local tr = nil
    if n > 0 then tr = r64(hv_get(0) + 0x58) end
    log("transform="..(tr and string.format("%x", tr) or "0"))
    local tf = i2c_class("UnityEngine", "Transform")
    local gp = tf and i2c_mptr(tf, "get_position", 0)
    log("get_position="..(gp and string.format("%x", gp) or "0"))
    if tr and gp then
      local x, y, z = pos3(gp, tr)
      log("pos="..string.format("%.1f %.1f %.1f", x, y, z))
    end
    log("PROBE10 FIN")
  end
end
