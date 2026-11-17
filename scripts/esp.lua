local step, last, t0 = 0, 0, os.time()
local PLC = nil
local tot = 0
local beat = 0

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  if step == 0 then
    step = 1
    t0 = os.time()
    beat = os.time()
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. (PLC and string.format("%x", PLC) or "nil"))
    if not PLC then log("SIN CLASE"); step = 9; return end
    local m = i2c_mptr(PLC, "UpdateKinematics", 2)
    if not m then m = i2c_mptr(PLC, "UpdateBehavior", 2) end
    if not m then m = i2c_mptr(PLC, "OnUpdate", 2) end
    if not m then log("SIN PUNTERO"); step = 9; return end
    log("m=" .. string.format("%x", m))
    hv_clear()
    last = 0
    log("hook=" .. hook1(m))
    log("PROBE14 VIVO")
    return
  end

  if step ~= 1 then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("PROBE14 VIVO t=" .. (ahora - t0) .. " n=" .. hv_count() .. " tot=" .. tot)
  end

  local n = hv_count()
  if n == last then return end
  local nuevos = n - last
  last = n
  log("n=" .. n .. " +" .. nuevos)

  local ok = 0
  for i = math.max(0, n - nuevos), n - 1 do
    local o = hv_get(i)
    local k = o and kl(o) or 0
    if k == PLC then ok = ok + 1 end
    if i >= n - 3 then log("  " .. i .. " cls=" .. string.format("%x", k)) end
  end
  tot = tot + ok
  log("  players=" .. ok .. " acum=" .. tot)

  if n > 0 then
    local tr = r64(hv_get(0) + 0x58)
    log("  tr=" .. string.format("%x", tr))
    local tf = i2c_class("UnityEngine", "Transform")
    local gp = tf and i2c_mptr(tf, "get_position", 0)
    if tr and gp then
      local x, y, z = pos3(gp, tr)
      log("  pos=" .. string.format("%.1f %.1f %.1f", x, y, z))
    end
  end
end
