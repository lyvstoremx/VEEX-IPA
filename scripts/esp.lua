local step = 0

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end
  if step ~= 0 then return end
  step = 1

  local g = sym("getpid")
  log("getpid=" .. (g and string.format("%x", g) or "nil"))
  if not g then log("SIN GETPID"); return end

  hv_clear()
  log("h1=" .. hook1(g))
  log("r1=" .. callv(g))
  log("r2=" .. callv(g))
  log("r3=" .. callv(g))
  log("hv=" .. hv_count())

  local s = sym("strlen")
  log("strlen=" .. (s and string.format("%x", s) or "nil"))
  if s then
    hv_clear()
    log("h2=" .. hook1(s))
    log("len=" .. call(s, sptr("holamundo")))
    log("len2=" .. call(s, sptr("abc")))
  end
  log("PROBE13 FIN")
end
