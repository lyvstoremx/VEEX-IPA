log("VEEX v28")

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
local gph = C and i2c_mptr(C, "get_pixelHeight", 0)
local vb = buf(16)
local tp = P and clstype(P)
local tc = C and clstype(C)
local s = sc()
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

  local carr = callv(fot, 0, tc)
  if not carr or carr == 0 then return end
  local nc = arrlen(carr)
  log("ncam=" .. nc)

  local parr = callv(fot, 0, tp)
  if not parr or parr == 0 then return end
  local np = arrlen(parr)
  if np < 1 then return end

  local e = arrat(parr, 0)
  local tr = e and e ~= 0 and call(gtr, e) or nil
  local vp = nil
  if tr and tr ~= 0 then
    local gp = i2c_mptr(kl(tr), "get_position", 0)
    if gp then vp = call(gp, tr) end
  end
  if not vp or vp == 0 then return end
  local x, y, z = u3(vp)
  log(string.format("pos %.1f %.1f %.1f", x, y, z))
  wv3(vb, x, y + 1.2, z)

  for i = 0, math.min(nc, 6) - 1 do
    local c = arrat(carr, i)
    if c and c ~= 0 then
      local d = gdepth and rf(call(gdepth, c) + 16) or 0
      local w = gpw and r32(call(gpw, c) + 16) or 0
      local h = gph and r32(call(gph, c) + 16) or 0
      log(string.format("cam%d d=%.2f w=%d h=%d", i, d, w, h))
      local sp = callv(w2s, c, vb)
      if sp and sp ~= 0 then
        local sx, sy, sz = u3(sp)
        log(string.format("  sc %.0f %.0f %.1f", sx, sy, sz))
        if sz > 0 then
          local ax, ay = sx / s, sy / s
          if ax > 0 and ay > 0 and ax < sw() and ay < sh() then
            rect(ax - 30, ay - 60, 60, 120, 0, 1, 0, 1)
            text("c" .. i, ax - 8, ay - 74, 0, 1, 0, 1)
          end
        end
      end
    end
  end

  done = true
end
