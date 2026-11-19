-- PROBE52: proyección por matrices
local prep = false
local camObj, TR, Cam, PLC = nil, nil, nil, nil
local mW, mP, mGT, mGC = nil, nil, nil, nil
local SW, SH = 0, 0

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end

local function mul(m, x, y, z, w)
  local r = {}
  for row = 0, 3 do
    r[row] = m[row] * x + m[4 + row] * y + m[8 + row] * z + m[12 + row] * w
  end
  return r
end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end
  if prep then return end
  prep = true

  SW, SH = sw(), sh()
  log("V52 sw=" .. tostring(SW) .. " sh=" .. tostring(SH))
  local fgt = sym("il2cpp_class_get_type")
  local fob = sym("il2cpp_type_get_object")
  local OK = i2c_class("UnityEngine", "Object")
  Cam = i2c_class("UnityEngine", "Camera")
  TR = i2c_class("UnityEngine", "Transform")
  local Comp = i2c_class("UnityEngine", "Component")
  PLC = i2c_class("COW.GamePlay", "Player")
  if not OK or not Cam or not TR or not Comp or not PLC then log("clases mal") return end

  mGT = i2c_mptr(Comp, "get_transform", 0)
  mGC = i2c_mptr(Comp, "GetComponent", 1)
  mW = i2c_mptr(Cam, "get_worldToCameraMatrix", 0)
  mP = i2c_mptr(Cam, "get_projectionMatrix", 0)
  log("mGT=" .. hex(mGT) .. " mGC=" .. hex(mGC) .. " mW=" .. hex(mW) .. " mP=" .. hex(mP))
  if not mGT or not mGC or not mW or not mP then return end

  local to = call(fob, call(fgt, PLC))
  local pa = call(i2c_mptr(OK, "FindObjectsOfType", 1), to)
  if not pa or not plaus(pa) then log("sin array") return end
  local n = arrlen(pa)
  log("n=" .. tostring(n))
  if not n or n <= 0 then return end

  local alvo = nil
  for i = 0, math.min(n, 60) - 1 do
    local o = arrat(pa, i)
    if o and o ~= 0 then
      for _, p in ipairs(parents(kl(o))) do
        if string.find(p, "Player") then alvo = o break end
      end
    end
    if alvo then break end
  end
  if not alvo then log("sin alvo") return end

  local trc = r64(alvo + 0x3e8)
  if not trc or not plaus(trc) or kl(trc) ~= TR then log("sin trc") return end
  camObj = call(mGC, trc, call(fob, call(fgt, Cam)))
  if not camObj or not plaus(camObj) or kl(camObj) ~= Cam then log("sin cam") return end

  local vw = { mat(mW, camObj) }
  local pm = { mat(mP, camObj) }
  log("vw1=" .. tostring(vw[1]) .. " pm1=" .. tostring(pm[1]))
  if not vw[1] or not pm[1] then return end

  local tr = call(mGT, alvo)
  if not tr or not plaus(tr) then log("sin tr") return end
  local gm = i2c_mptr(TR, "get_position", 0)
  if not gm then return end
  local x, y, z = pos3(gm, tr)
  log("pos=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
  if not x then return end

  local v = mul(vw, x, y, z, 1)
  local c = mul(pm, v[0], v[1], v[2], v[3])
  log("cw=" .. tostring(c[3]))
  if not c[3] or c[3] <= 0 then log("detras") return end

  local ndx = c[0] / c[3]
  local ndy = c[1] / c[3]
  local sx = (ndx * 0.5 + 0.5) * SW
  local sy = (1 - (ndy * 0.5 + 0.5)) * SH
  log("S=" .. tostring(sx) .. "," .. tostring(sy))

  clear()
  rect(sx - 20, sy - 80, 40, 80, 0, 1, 0.4, 1)
  text("X", sx - 4, sy + 2, 1, 1, 1, 1)
  log("DIBUJADO")
  log("FIN52")
end
