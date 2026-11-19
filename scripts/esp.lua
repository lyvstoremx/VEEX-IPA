-- PROBE42: enumeración por FindObjectsOfType, con conversión de tipo.
local step, t0, beat = 0, os.time(), 0
local PLC, jug = nil, {}

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO42 t=" .. (ahora - t0) .. " s=" .. step .. " n=" .. #jug)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end
    local OK = i2c_class("UnityEngine", "Object")
    log("objcls=" .. hex(OK))
    if not OK then step = 9 return end
    local m = i2c_mptr(OK, "FindObjectsOfType", 1)
    log("m=" .. hex(m))
    if not m or m == 0 then step = 9 return end
    return
  end

  if step == 1 then
    step = 2
    local ftype = sym("il2cpp_class_get_type")
    local fobj = sym("il2cpp_type_get_object")
    log("symT=" .. hex(ftype) .. " symO=" .. hex(fobj))
    if not ftype or not fobj then step = 9 return end
    local tp = call(ftype, PLC)
    log("tp=" .. hex(tp))
    if not tp or tp == 0 then step = 9 return end
    local to = call(fobj, tp)
    log("to=" .. hex(to))
    if not to or to == 0 then step = 9 return end
    return
  end

  if step == 2 then
    step = 3
    local OK = i2c_class("UnityEngine", "Object")
    local m = i2c_mptr(OK, "FindObjectsOfType", 1)
    local to = call(sym("il2cpp_type_get_object"), call(sym("il2cpp_class_get_type"), PLC))
    log("call to=" .. hex(to))
    local arr = call(m, to)
    log("arr=" .. hex(arr))
    if not arr or arr == 0 or not plaus(arr) then step = 9 return end
    local n = arrlen(arr)
    log("n=" .. tostring(n))
    if not n or n <= 0 or n > 300 then step = 9 return end

    local k = 0
    for i = 0, n - 1 do
      local o = arrat(arr, i)
      if o and o ~= 0 and kl(o) == PLC then
        k = k + 1
        jug[k] = o
        if k <= 8 then
          log("P" .. k .. "=" .. hex(o))
          log("  v270=" .. tostring(rf(o + 0x270)) .. " v320=" .. tostring(rf(o + 0x320))
              .. " v344=" .. tostring(rf(o + 0x344)) .. " v7e8=" .. tostring(rf(o + 0x7e8)))
          log("  cam=" .. hex(r64(o + 0x3e8)))
        end
      end
    end
    log("jugadores=" .. k)
    return
  end
end
