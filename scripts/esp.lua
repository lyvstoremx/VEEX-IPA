log("VEEX v48")

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

local ghp = P and (i2c_mptr(P, "get_HP", 0) or i2c_mptr(P, "get_Hp", 0)
  or i2c_mptr(P, "get_CurHP", 0) or i2c_mptr(P, "get_Health", 0))
log("hp=" .. tostring(ghp))

local cam, cw, ch, frames, hplog = nil, 0, 0, 0, 0
local boxes = {}

local MAXD  = 250
local NAMED = 60
local ME    = 2.0

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
      return
    end
  end
end

local function camPos()
  if not (gtr and cam) then return nil end
  local ctr = call(gtr, cam)
  if not ctr or ctr == 0 then return nil end
  local gp = i2c_mptr(kl(ctr), "get_position", 0)
  if not gp then return nil end
  return pos3(gp, ctr)
end

local function update()
  boxes = {}
  if not (fot and gtr and w2s and tp and tc) then return end
  if not cam then pickCam() end
  if not cam then return end

  local mx, my, mz = camPos()

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 40 then n = 40 end

  local fx = sw() / math.max(cw, 1)
  local fy = sh() / math.max(ch, 1)
  local W, H = sw(), sh()
  local count = 0

  for i = 0, n - 1 do
    if count >= 25 then break end
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local x, y, z = worldPos(e)
      if x then
        local skip = false
        if mx then
          local dx, dy, dz = x - mx, y - my, z - mz
          if dx * dx + dy * dy + dz * dz < ME * ME then skip = true end
        end
        if not skip then
          local hx, hy, hz = w2s3(w2s, cam, x, y + 1.7, z)
          if hz and hz > 2 and hz < MAXD then
            local fxx, fyy = w2s3(w2s, cam, x, y + 0.1, z)
            local cx = ((hx + fxx) / 2) * fx
            local ay1 = H - hy * fy
            local ay2 = H - fyy * fy
            local h = ay2 - ay1
            if h > 8 and cx > 0 and cx < W and ay1 > 0 and ay1 < H then
              local nm, hp = nil, nil
              if gnk and hz < NAMED then
                local np = call(gnk, e)
                if np and np ~= 0 then nm = str(np) end
              end
              if ghp then
                hp = callf(ghp, e)
                if hp and hplog < 3 then
                  log("hp0=" .. tostring(hp))
                  hplog = hplog + 1
                end
                if hp and hp > 100 then hp = 100 end
                if hp and hp < 0 then hp = 0 end
              end
              boxes[#boxes + 1] = { cx = cx, y1 = ay1, h = h, d = hz, nm = nm, hp = hp }
              count = count + 1
            end
          end
        end
      end
    end
  end
end

function tick()
  clear()
  local by = sh() - 22
  if not get("esp") then return end

  frames = frames + 1
  if frames % 2 == 1 then update() end

  local W = sw()
  for _, b in ipairs(boxes) do
    local w = b.h * 0.45
    if get("line") then line(W / 2, 0, b.cx, b.y1, 1, 1, 1, 0.5) end
    if get("box") then rect(b.cx - w / 2, b.y1, w, b.h, 1, 0.2, 0.2, 1) end
    if b.hp and get("hp") then
      local hh = b.h * (b.hp / 100)
      if hh < 2 then hh = 2 end
      fill(b.cx - w / 2 - 6, b.y1, 3, b.h, 0, 0, 0, 0.6)
      fill(b.cx - w / 2 - 6, b.y1 + (b.h - hh), 3, hh, 0.2, 1, 0.3, 1)
    end
    if b.nm and get("name") and b.y1 > 18 then
      text(b.nm, b.cx - w / 2, b.y1 - 13, 1, 0.2, 0.2, 1)
    end
    if get("dist") then
      text(string.format("%dm", math.floor(b.d)), b.cx - 8, b.y1 + b.h + 2, 1, 1, 1, 1)
    end
  end
  text("n=" .. #boxes, 10, by, 0.6, 1, 0.6, 1)
end
