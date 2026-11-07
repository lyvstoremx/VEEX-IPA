log("VEEX v58")

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
local gfwd = i2c_ptr("Transform", "get_forward", 0)
local lookat = i2c_ptr("Transform", "LookAt", 1)

local ghp = P and (i2c_mptr(P, "get_HP", 0) or i2c_mptr(P, "get_Hp", 0)
  or i2c_mptr(P, "get_CurHP", 0) or i2c_mptr(P, "get_Health", 0))
log("hp=" .. tostring(ghp) .. " look=" .. tostring(lookat))

local cam, cw, ch, frames, dclog = nil, 0, 0, 0, 0
local boxes = {}
local aimT = nil

local MAXHP = 200
local MAXD  = 300
local NAMED = 15
local NCAP  = 60
local BCAP  = 30
local AIMPX = 150

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end

local function u3(p)
  local b = p + 16
  return rf(b), rf(b + 4), rf(b + 8)
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
  aimT = nil
  if not (fot and gtr and w2s and tp and tc) then return end
  if not cam then pickCam() end
  if not cam then return end
  if cw == 0 or ch == 0 then
    cam = nil
    pickCam()
    if not cam or cw == 0 or ch == 0 then return end
  end

  local wantname = get("name")
  local wanthp = get("hp")

  local mx, my, mz = camPos()
  local fx3, fy3, fz3 = nil, nil, nil
  if gfwd then
    local ctr = call(gtr, cam)
    if ctr and ctr ~= 0 then
      local fp = callv(gfwd, ctr)
      if fp and fp ~= 0 then fx3, fy3, fz3 = u3(fp) end
    end
  end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > NCAP then n = NCAP end

  local list = {}
  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local gp = i2c_mptr(kl(tr), "get_position", 0)
        if gp then
          local x, y, z = pos3(gp, tr)
          if x then list[#list + 1] = { e = e, t = tr, x = x, y = y, z = z } end
        end
      end
    end
  end

  local sk1, sk2 = 0, 0
  if mx and fx3 then
    local cand = {}
    for i, it in ipairs(list) do
      local dx, dy, dz = it.x - mx, it.y - my, it.z - mz
      local dep = dx * fx3 + dy * fy3 + dz * fz3
      if dep > 0.2 and dep < 9 then
        local px, py, pz = dx - dep * fx3, dy - dep * fy3, dz - dep * fz3
        local perp = math.sqrt(px * px + py * py + pz * pz)
        if perp < 1.6 then cand[#cand + 1] = { i = i, dep = dep } end
      end
    end
    table.sort(cand, function(a, b) return a.dep < b.dep end)
    if cand[1] then sk1 = cand[1].i end
    if cand[2] then sk2 = cand[2].i end
  end
  if sk1 == 0 and mx then
    local best, bi = 1e9, 0
    for i, it in ipairs(list) do
      local dx, dy, dz = it.x - mx, it.y - my, it.z - mz
      local d2 = dx * dx + dy * dy + dz * dz
      if d2 < best and d2 < 196 then
        best = d2
        bi = i
      end
    end
    sk1 = bi
  end

  local fx = sw() / math.max(cw, 1)
  local fy = sh() / math.max(ch, 1)
  local W, H = sw(), sh()
  local count = 0

  for i, it in ipairs(list) do
    if count >= BCAP then break end
    if i ~= sk1 and i ~= sk2 then
      local hx, hy, hz = w2s3(w2s, cam, it.x, it.y + 1.7, it.z)
      if hz and hz > 1 and hz < MAXD then
        local fxx, fyy = w2s3(w2s, cam, it.x, it.y + 0.1, it.z)
        local cx = ((hx + fxx) / 2) * fx
        local ay1 = H - hy * fy
        local ay2 = H - fyy * fy
        local h = ay2 - ay1
        if h > 4 and cx > 0 and cx < W and ay1 > 0 and ay1 < H then
          local nm, hp = nil, nil
          if wantname and gnk and hz < NAMED then
            local np = call(gnk, it.e)
            if np and np ~= 0 then nm = str(np) end
          end
          if wanthp and ghp then
            hp = calli(ghp, it.e)
            if hp and hp > MAXHP then hp = MAXHP end
            if hp and hp < 0 then hp = 0 end
          end
          boxes[#boxes + 1] = { cx = cx, y1 = ay1, h = h, d = hz, nm = nm, hp = hp, t = it.t }
          count = count + 1
        end
      end
    end
  end

  if get("aim") then
    local cx0, cy0 = W / 2, H * 0.35
    local best, bt = 1e9, nil
    for _, b in ipairs(boxes) do
      if b.d < 150 then
        local dx, dy = b.cx - cx0, (b.y1 + b.h * 0.12) - cy0
        local d2 = dx * dx + dy * dy
        if d2 < AIMPX * AIMPX and d2 < best then
          best = d2
          bt = b
        end
      end
    end
    if bt then aimT = bt end
  end

  dclog = dclog + 1
  table.sort(boxes, function(a, b) return a.d > b.d end)
end

function tick()
  clear()
  local by = sh() - 22
  if not get("esp") then return end

  frames = frames + 1
  if frames % 3 == 1 then update() end

  local W, H = sw(), sh()
  local n = #boxes

  if not cam then
    text("sin camara", 10, by, 1, 1, 0, 1)
  end

  for i, b in ipairs(boxes) do
    local w = b.h * 0.45
    local near = i > n - 3
    local cr, cg, cb = 1, 0.2, 0.2
    if b.d < 20 then
      cr, cg, cb = 0.3, 1, 0.35
    elseif b.d < 60 then
      cr, cg, cb = 1, 0.9, 0.2
    end
    if get("line") and b.d < 25 then line(W / 2, 0, b.cx, b.y1, 1, 1, 1, 0.35) end
    if get("box") then rect(b.cx - w / 2, b.y1, w, b.h, cr, cg, cb, 1) end
    if b.hp and get("hp") then
      local hh = b.h * (b.hp / MAXHP)
      if hh < 2 then hh = 2 end
      fill(b.cx - w / 2 - 6, b.y1, 3, b.h, 0, 0, 0, 0.6)
      fill(b.cx - w / 2 - 6, b.y1 + (b.h - hh), 3, hh, 0.2, 1, 0.3, 1)
    end
    if b.nm and get("name") and near and b.y1 > 26 and b.y1 < H - 6 then
      text(b.nm, b.cx - w / 2, b.y1 - 13, cr, cg, cb, 1)
    end
    if get("dist") and b.d < 60 then
      text(string.format("%dm", math.floor(b.d)), b.cx - 8, b.y1 + b.h + 2, cr, cg, cb, 1)
    end
  end

  if get("aim") then
    local cx0, cy0 = W / 2, H * 0.35
    local px, py = nil, nil
    for k = 0, 23 do
      local a = k / 24 * 6.28318
      local x, y = cx0 + math.cos(a) * AIMPX, cy0 + math.sin(a) * AIMPX
      if px then line(px, py, x, y, 1, 1, 1, 0.22) end
      px, py = x, y
    end
    if aimT then
      local tx, ty = aimT.cx, aimT.y1 + aimT.h * 0.12
      line(tx - 6, ty, tx + 6, ty, 0.3, 1, 0.35, 1)
      line(tx, ty - 6, tx, ty + 6, 0.3, 1, 0.35, 1)
      if lookat and cam then
        local ctr = call(gtr, cam)
        if ctr and ctr ~= 0 then callv(lookat, ctr, aimT.t) end
      end
    end
  end

  text("n=" .. n, 10, 120, 0.6, 1, 0.6, 1)
end
