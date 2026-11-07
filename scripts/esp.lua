log("VEEX v31")

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
local cam, cw, ch = nil, 0, 0
local done = false

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end
local function u3(p)
  local b = p + 16
  return rf(b), rf(b + 4), rf(b + 8)
end

local function pickCam()
  local arr = callv(fot, 0, tc)
  if not arr or arr == 0 then return end
  for i = 0, math.min(arrlen(arr), 8) - 1 do
    local c = arrat(arr, i)
    if c and c ~= 0 and rf(call(gdepth, c) + 16) == -1 then
      cam = c
      cw = r32(call(gpw, c) + 16)
      ch = r32(call(gph, c) + 16)
      return
    end
  end
end

function tick()
  clear()
  local by = sh() - 22
  text("sw=" .. sw() .. " sh=" .. sh() .. " sc=" .. sc(), 10, by - 14, 1, 1, 0, 1)
  if done then return end
  if not (fot and gtr and w2s and tp and tc) then return end
  pickCam()
  if not cam then text("sin camara", 10, by, 1, 1, 1, 1) return end
  log("sw=" .. sw() .. " sh=" .. sh() .. " sc=" .. sc() .. " cw=" .. cw .. " ch=" .. ch)

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  log("np=" .. n)
  for i = 0, math.min(n, 6) - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local gp = i2c_mptr(kl(tr), "get_position", 0)
        if gp then
          local vp = call(gp, tr)
          if vp and vp ~= 0 then
            local x, y, z = u3(vp)
            wv3(vb, x, y + 1.5, z)
            local sp = callv(w2s, cam, vb)
            if sp and sp ~= 0 then
              local sx, sy, sz = u3(sp)
              log(string.format("p%d w %.1f %.1f %.1f  s %.0f %.0f %.1f", i, x, y, z, sx, sy, sz))
            end
          end
        end
      end
    end
  end
  done = true
end
