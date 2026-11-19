-- PROBE43: enumeración en partida, con segundo intento.
local step, t0, beat = 0, os.time(), 0
local PLC, jug, arr = nil, {}, nil

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end

local function leer(a, et)
  if not a or a == 0 or not plaus(a) then log(et .. " arr malo") return end
  local n = arrlen(a)
  log(et .. " n=" .. tostring(n))
  if not n or n <= 0 then return end
  local lim = n
  if lim > 3000 then lim = 3000 end
  local k = 0
  for i = 0, lim - 1 do
    local o = arrat(a, i)
    if o and o ~= 0 then
      local kk = kl(o)
      if kk == PLC then
        k = k + 1
        jug[k] = o
        if k <= 8 then
          log("P" .. k .. "=" .. hex(o))
          log("  v270=" .. tostring(rf(o + 0x270)) .. " v320=" .. tostring(rf(o + 0x320))
              .. " v344=" .. tostring(rf(o + 0x344)) .. " v7e8=" .. tostring(rf(o + 0x7e8)))
          log("  cam=" .. hex(r64(o + 0x3e8)))
        end
      elseif i < 10 then
        log("  otra k=" .. hex(kk))
      end
    end
  end
  log(et .. " jugadores=" .. k)
end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO43 t=" .. (ahora - t0) .. " s=" .. step .. " n=" .. #jug)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end
    local ftype = sym("il2cpp_class_get_type")
    local fobj = sym("il2cpp_type_get_object")
    log("symT=" .. hex(ftype) .. " symO=" .. hex(fobj))
    if not ftype or not fobj then step = 9 return end
    local tp = call(ftype, PLC)
    if not tp or tp == 0 then log("tp malo") step = 9 return end
    local to = call(fobj, tp)
    log("to=" .. hex(to))
    if not to or to == 0 then step = 9 return end
    return
  end

  if step == 1 then
    step = 2
    local OK = i2c_class("UnityEngine", "Object")
    if not OK then step = 9 return end
    local to = call(sym("il2cpp_type_get_object"), call(sym("il2cpp_class_get_type"), PLC))
    local m = i2c_mptr(OK, "FindObjectsOfType", 1)
    log("m=" .. hex(m))
    if m and m ~= 0 then
      arr = call(m, to)
      log("arr=" .. hex(arr))
      leer(arr, "A")
    end
    return
  end

  if step == 2 then
    step = 3
    local OK = i2c_class("UnityEngine", "Object")
    if not OK then step = 9 return end
    local to = call(sym("il2cpp_type_get_object"), call(sym("il2cpp_class_get_type"), PLC))
    local m2 = i2c_mptr(OK, "FindObjectsOfTypeAll", 1)
    log("m2=" .. hex(m2))
    if m2 and m2 ~= 0 then leer(call(m2, to), "B") end
    log("FIN43")
    step = 9
    return
  end
end
