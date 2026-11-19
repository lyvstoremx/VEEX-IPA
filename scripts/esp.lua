-- PROBE44: identifica la clase devuelta y lee posiciones.
local step, t0, beat = 0, os.time(), 0
local PLC = nil
local hecho = false

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end

function tick()
  if hecho then return end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO44 s=" .. step)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then hecho = true return end
    local tp = call(sym("il2cpp_class_get_type"), PLC)
    local to = call(sym("il2cpp_type_get_object"), tp)
    log("tp=" .. hex(tp) .. " to=" .. hex(to))
    if not to or to == 0 then hecho = true return end
    local OK = i2c_class("UnityEngine", "Object")
    local m = i2c_mptr(OK, "FindObjectsOfType", 1)
    local arr = call(m, to)
    log("arr=" .. hex(arr))
    if not arr or not plaus(arr) then hecho = true return end
    local n = arrlen(arr)
    log("n=" .. tostring(n))
    if not n or n <= 0 then hecho = true return end

    local o = arrat(arr, 0)
    if not o or o == 0 then hecho = true return end
    local kk = kl(o)
    log("o0=" .. hex(o) .. " kk=" .. hex(kk))
    log("kk==pl -> " .. tostring(kk == PLC))

    local pp = parents(kk)
    local s = ""
    for _, p in ipairs(pp) do s = s .. " " .. p end
    log("padres:" .. s)
    local esP = false
    for _, p in ipairs(pp) do
      if string.find(p, "Player") then esP = true end
    end
    log("esPlayer=" .. tostring(esP))

    if not esP then hecho = true return end

    local z = 0
    for _, b in ipairs(fields(kk)) do
      if z < 30 then log("f " .. b) end
      z = z + 1
    end
    log("fn=" .. z)

    local lim = n
    if lim > 5 then lim = 5 end
    for i = 0, lim - 1 do
      local x = arrat(arr, i)
      if x and x ~= 0 then
        log("X" .. i .. "=" .. hex(x))
        log("  v270=" .. tostring(rf(x + 0x270)) .. " v320=" .. tostring(rf(x + 0x320))
            .. " v344=" .. tostring(rf(x + 0x344)) .. " v7e8=" .. tostring(rf(x + 0x7e8)))
        log("  cam=" .. hex(r64(x + 0x3e8)))
      end
    end
    log("FIN44")
    hecho = true
    return
  end
end
