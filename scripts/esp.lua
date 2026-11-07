log("VEEX v27")

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
local vb = buf(16)
local tp = P and clstype(P)
local tc = C and clstype(C)
local s = sc()
local logged = false

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end

local function u3(p)
  local b = p + 16
  return rf(b), rf(b + 4), rf(b + 8)
end

local function bestCam()
  local arr = callv(fot, 0, tc)
  if not arr or arr == 0 then return nil end
  local n = arrlen(arr)
  local best, bd = nil, -1e9
  for i = 0, math.min(n, 20) - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local d = rf(call(gdepth, e) + 16)
      if d > bd then best, bd = e, d end
    end
  end
  return best
end

local cam, ct = nil, 0

function tick()
  clear()
  local by = sh() - 22
  if not (fot and gtr and w2s and tp and tc) then
    text("faltan", 10, by, 1, 1, 1, 1)
    return
  end

  ct = ct + 1
  if ct % 60 == 0 or not cam then cam = bestCam() end
  if not cam then text("sin camara", 10, by, 1, 1, 1, 1) return end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 60 then n = 60 end

  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local kt = kl(tr)
        local gpos = i2c_mptr(kt, "get_position", 0)
        if gpos then
          local vp = call(gpos, tr)
          if vp and vp ~= 0 then
            local x, y, z = u3(vp)
            if not logged then
              logged = true
              log(string.format("pos %.1f %.1f %.1f", x, y, z))
            end
            if x ~= 0 or y ~= 0 or z ~= 0 then
              wv3(vb, x, y + 1.55, z)
              local sp = callv(w2s, cam, vb)
              if sp and sp ~= 0 then
                local sx, sy, sz = u3(sp)
                if sz > 0 then
                  local ax = sx / s
                  local ay = sy / s
                  local h = math.max(26, 1400 / math.max(sz, 1))
                  local w = h * 0.52
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
    end
  end

  text("n=" .. n, 10, by, 0.6, 1, 0.6, 1)
end
