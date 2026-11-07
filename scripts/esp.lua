log("VEEX v32")

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
  for _, m in ipairs(i2c_mnames(c)) do
    if m == "FindObjectsOfType" then O = c break end
  end
  if O then break end
end

local fot = O and i2c_mptr(O, "FindObjectsOfType", 1)
local gtr = P and i2c_mptr(P, "get_transform", 0)
local w2s = C and i2c_mptr(C, "WorldToScreenPoint", 1)
local gdepth = C and i2c_mptr(C, "get_depth", 0)
local gpw = C and i2c_mptr(C, "get_pixelWidth", 0)
local vb = buf(16)
local tp = P and clstype(P)
local tc = C and clstype(C)
local done = false

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end
local function u3(p)
  local b = p + 16
  return rf(b), rf(b + 4), rf(b + 8)
end

function tick()
  clear()
  local by = sh() - 22
  if done then text("listo", 10, by, 0.6, 1, 0.6, 1) return end
  if not (fot and gtr and w2s and tp and tc) then text("faltan", 10, by, 1, 1, 1, 1) return end

  local parr = callv(fot, 0, tp)
  if not parr or parr == 0 then return end
  local np = arrlen(parr)
  if np < 4 then return end

  local pts = {}
  for i = 0, 3 do
    local e = arrat(parr, i)
    local tr = e and e ~= 0 and call(gtr, e) or nil
    if tr and tr ~= 0 then
      local gp = i2c_mptr(kl(tr), "get_position", 0)
      if gp then
        local vp = call(gp, tr)
        if vp and vp ~= 0 then pts[i] = { u3(vp) } end
      end
    end
  end

  local carr = callv(fot, 0, tc)
  if not carr or carr == 0 then return end
  local nc = arrlen(carr)
  for c = 0, math.min(nc, 4) - 1 do
    local cam = arrat(carr, c)
    if cam and cam ~= 0 then
      local d = gdepth and rf(call(gdepth, cam) + 16) or 0
      local pw = gpw and r32(call(gpw, cam) + 16) or 0
      log(string.format("== cam%d d=%.0f pw=%d", c, d, pw))
      for i = 0, 3 do
        if pts[i] then
          wv3(vb, pts[i][1], pts[i][2] + 1.5, pts[i][3])
          local sp = callv(w2s, cam, vb)
          if sp and sp ~= 0 then
            local sx, sy, sz = u3(sp)
            log(string.format("   p%d %.0f %.0f %.1f", i, sx, sy, sz))
          end
        end
      end
    end
  end
  done = true
end
