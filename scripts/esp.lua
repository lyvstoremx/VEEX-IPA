log("VEEX v29")

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
local gnk = P and i2c_mptr(P, "get_NickName", 0)
local w2s = C and i2c_mptr(C, "WorldToScreenPoint", 1)
local gdepth = C and i2c_mptr(C, "get_depth", 0)
local gpw = C and i2c_mptr(C, "get_pixelWidth", 0)
local gph = C and i2c_mptr(C, "get_pixelHeight", 0)
local vb = buf(16)
local tp = P and clstype(P)
local tc = C and clstype(C)
local cam, cw, ch, ct = nil, 0, 0, 0

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end
local function u3(p)
  local b = p + 16
  return rf(b), rf(b + 4), rf(b + 8)
end

local function worldPos(e)
  local tr = call(gtr, e)
  if not tr or tr == 0 then return nil end
  local gp = i2c_mptr(kl(tr), "get_position", 0)
  if not gp then return nil end
  local vp = call(gp, tr)
  if not vp or vp == 0 then return nil end
  return u3(vp)
end

local function pickCam()
  if not (fot and w2s and tc) then return end
  local arr = callv(fot, 0, tc)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  local best, bw, bh, bs = nil, 0, 0, -1e9
  for i = 0, math.min(n, 8) - 1 do
    local c = arrat(arr, i)
    if c and c ~= 0 then
      local d = gdepth and rf(call(gdepth, c) + 16) or 0
      local w = gpw and r32(call(gpw, c) + 16) or 0
      local h = gph and r32(call(gph, c) + 16) or 0
      if d == -1 then best, bw, bh = c, w, h break end
      if d > bs and w > 100 then best, bw, bh, bs = c, w, h, d end
    end
  end
  cam, cw, ch = best, bw, bh
  if cam then log("cam d ok w=" .. cw) end
end

function tick()
  clear()
  local by = sh() - 22
  if not (fot and gtr and w2s and tp and tc) then
    text("faltan", 10, by, 1, 1, 1, 1)
    return
  end

  ct = ct + 1
  if ct % 120 == 0 or not cam then pickCam() end
  if not cam then text("sin camara", 10, by, 1, 1, 1, 1) return end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 60 then n = 60 end

  local fx = sw() / math.max(cw, 1)
  local fy = sh() / math.max(ch, 1)

  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local x, y, z = worldPos(e)
      if x then
        wv3(vb, x, y + 1.5, z)
        local sp = callv(w2s, cam, vb)
        if sp and sp ~= 0 then
          local sx, sy, sz = u3(sp)
          if sz > 0.5 then
            local ax, ay = sx * fx, sy * fy
            if ax > -200 and ay > -200 and ax < sw() + 200 and ay < sh() + 200 then
              local h = math.max(24, 900 / sz)
              local w = h * 0.5
              rect(ax - w / 2, ay - h, w, h, 1, 0.2, 0.2, 1)
              if gnk then
                local np = call(gnk, e)
                if np and np ~= 0 then
                  text(str(np), ax - w / 2, ay - h - 12, 1, 0.2, 0.2, 1)
                end
              end
            end
          end
        end
      end
    end
  end

  text("n=" .. n, 10, by, 0.6, 1, 0.6, 1)
end
