-- PROBE41: enumeración por FindObjectsOfType. Solo lectura.
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
    log("VIVO41 t=" .. (ahora - t0) .. " s=" .. step .. " n=" .. #jug)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end

    local ftype = sym("il2cpp_class_get_type")
    log("sym type=" .. hex(ftype))
    if not ftype then step = 9 return end

    local tp = call(ftype, PLC)
    log("tp=" .. hex(tp))
    if not tp or tp == 0 then step = 9 return end

    local OK = i2c_class("UnityEngine", "Object")
    log("objcls=" .. hex(OK))
    if not OK then step = 9 return end

    local m = i2c_mptr(OK, "FindObjectsOfType", 1)
    log("m=" .. hex(m))
    if not m or m == 0 then step = 9 return end

    local arr = call(m, tp)
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
    step = 2
    return
  end
end
