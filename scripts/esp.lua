log("VEEX v26")

local function pickmax(name)
  local best, bn = nil, -1
  for _, c in ipairs(i2c_clsall(name)) do
    local n = #i2c_mnames(c)
    if n > bn then best, bn = c, n end
  end
  return best
end

local P = pickmax("Player")
local C = pickmax("Camera")
local O = nil
for _, c in ipairs(i2c_clsall("Object")) do
  for _, m in i2c_mnames(c) do
    if m == "FindObjectsOfType" then O = c break end
  end
  if O then break end
end

local fot = O and i2c_mptr(O, "FindObjectsOfType", 1)
local gtr = P and i2c_mptr(P, "get_transform", 0)
local vb = buf(16)
local tp = P and clstype(P)
local tc = C and clstype(C)
local done = false

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end

function tick()
  clear()
  local by = sh() - 22
  if done then text("listo", 10, by, 0.6, 1, 0.6, 1) return end
  if not (fot and gtr and tp and tc) then text("faltan", 10, by, 1, 1, 1, 1) return end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  log("np=" .. n)
  if n < 1 then return end

  local e = arrat(arr, 0)
  log("e=" .. tostring(e))
  if not e or e == 0 then return end
  log("clsE=" .. i2c_cname(kl(e)))

  local tr = call(gtr, e)
  log("tr=" .. tostring(tr))
  if not tr or tr == 0 then return end
  local kt = kl(tr)
  log("clsT=" .. i2c_cname(kt))

  local gpos = i2c_mptr(kt, "get_position", 0)
  log("gpos=" .. tostring(gpos))
  if gpos then
    local vp = call(gpos, tr)
    log("vp=" .. tostring(vp))
    if vp and vp ~= 0 then
      log(string.format("raw %d %d %d", r32(vp), r32(vp + 4), r32(vp + 8)))
      log(string.format("f %f %f %f", rf(vp), rf(vp + 4), rf(vp + 8)))
    end
  end

  local gcp = i2c_ptr("Component", "get_transform", 0)
  log("gcp=" .. tostring(gcp))
  if gcp then
    local tr2 = call(gcp, e)
    log("tr2=" .. tostring(tr2))
    if tr2 and tr2 ~= 0 then log("clsT2=" .. i2c_cname(kl(tr2))) end
  end

  done = true
end
