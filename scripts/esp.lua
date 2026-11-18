local step, last, t0, beat, tot = 0, 0, os.time(), 0, 0
local PLC = nil

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. (PLC and string.format("%x", PLC) or "nil"))
    if not PLC then step = 9 return end
    local m = i2c_mptr(PLC, "UpdateKinematics", 2)
    log("m=" .. (m and string.format("%x", m) or "nil"))
    if not m then step = 9 return end
    hv_clear()
    last = 0
    beat = os.time()
    t0 = os.time()
    log("hookm=" .. hookm(PLC, "UpdateKinematics", 2))
    log("PROBE18 VIVO")
    return
  end

  if step ~= 1 then return end
  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO t=" .. (ahora - t0) .. " n=" .. hv_count() .. " tot=" .. tot)
  end
  local n = hv_count()
  if n == last then return end
  last = n
  log("n=" .. n)
  if n > 0 then
    local o = hv_get(n - 1)
    local k = o and kl(o) or 0
    if k == PLC then tot = tot + 1 end
    log("  cls=" .. string.format("%x", k) .. " acum=" .. tot)
  end
end
