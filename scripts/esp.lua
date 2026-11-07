log("VEEX v35")

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
local tp = P and clstype(P)
local tc = C and clstype(C)
local cam, cw, ch, ct = nil, 0, 0, 0

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end
local function worldPos(e)
  local tr = call(gtr, e)
  if not tr or tr == 0 then return nil end
  local gp = i2c_mptr(kl(tr), "get_position", 0)
  if not gp then return nil end
  return pos3(gp, tr)
end
local function pickCam()
  if not (fot and tc) then return end
  local arr = callv(fot, 0, tc)
  if not arr or arr == 0 then return end
  for i = 0, math.min(arrlen(arr), 8) - 1 do
    local c = arrat(arr, i)
    if c and c ~= 0 and callf(gdepth, c) == -1 then
      cam, cw, ch = c, calli(gpw, c), calli(gph, c)
      log("cam " .. cw .. "x" .. ch)
      return
    end
  end
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
  local W, H = sw(), sh()

  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local x, y, z = worldPos(e)
      if x then
        local hx, hy, hz = w2s3(w2s, cam, x, y + 1.7, z)
        local fxx, fyy, fz = w2s3(w2s, cam, x, y + 0.1, z)
        if hz > 0.8 and fz > 0.8 and hz < 400 then
          local ax1, ay1 = hx * fx, hy * fy
          local ax2, ay2 = fxx * fx, fyy * fy
          local h = ay2 - ay1
          if h > 6 then
            local w = h * 0.45
            local cx = (ax1 + ax2) / 2
            if cx > -100 and cx < W + 100 and ay1 > -100 and ay1 < H + 100 then
              rect(cx - w / 2, ay1, w, h, 1, 0.2, 0.2, 1)
              if gnk then
                local np = call(gnk, e)
                if np and np ~= 0 then
                  text(str(np), cx - w / 2, ay1 - 13, 1, 0.2, 0.2, 1)
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
