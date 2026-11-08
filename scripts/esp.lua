-- VEEX v64
local function on(k) return (cfg(k) or 0) ~= 0 end
local function P(cls, mth, argc)
  local c = i2c_class(cls)
  if not c then log("X cls " .. cls) return nil end
  local p = i2c_mptr(c, mth, argc or 0)
  if not p then log("X mth " .. cls .. "." .. mth) end
  return p
end

local camC    = i2c_class("Camera")
local tp      = i2c_class("Player")
local fot     = P("GameObject", "FindObjectsOfType", 1)
local w2s     = camC and i2c_mptr(camC, "WorldToScreenPoint", 1)
local getmain = camC and i2c_mptr(camC, "get_main", 0)
local gtr     = P("Component", "get_transform", 0)
local gpos    = P("Transform", "get_position", 0)
local gfwd    = P("Transform", "get_forward", 0)
local geteu   = P("Transform", "get_eulerAngles", 0)
local seteu   = P("Transform", "set_eulerAngles", 1)
local gnk     = P("Player", "get_nickname", 0)
log("v64 fot=" .. tostring(fot) .. " w2s=" .. tostring(w2s) .. " tp=" .. tostring(tp))

local PAL = {
  {1, 0.22, 0.22}, {0.25, 1, 0.35}, {0.25, 0.72, 1}, {1, 1, 0.25},
  {1, 0.32, 1}, {1, 0.62, 0.15}, {1, 1, 1}
}
local ci, cam, frames, dlog = 1, nil, 0, 0
local boxes = {}
local cx, cy, cz = 0, 0, 0

local function pickCam()
  if not getmain then return nil end
  local c = call(getmain, 0)
  if c and c ~= 0 then cam = c end
  return cam
end

local function update()
  if not cam then pickCam() end
  if not cam then return end
  local ct = call(gtr, cam)
  if not ct or ct == 0 then cam = nil return end
  cx, cy, cz = pos3(gpos, ct)
  local fx, fy, fz = 0, 0, 0
  if gfwd then fx, fy, fz = pos3(gfwd, ct) end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 60 then n = 60 end

  local list, bp, lp = {}, 99, nil
  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local x, y, z = pos3(gpos, tr)
        if x and x ~= 0 then
          local dx, dy, dz = x - cx, y - cy, z - cz
          local dep = dx * fx + dy * fy + dz * fz
          local qx, qy, qz = dx - dep * fx, dy - dep * fy, dz - dep * fz
          local perp = math.sqrt(qx * qx + qy * qy + qz * qz)
          if dep > 0.2 and dep < 14 and perp < bp then bp = perp lp = e end
          if dep > 0.4 and dep < 300 then
            list[#list + 1] = { e = e, x = x, y = y, z = z, d = dep }
          end
        end
      end
    end
  end
  if dlog == 0 then dlog = 1 log("U n=" .. #list .. " perp=" .. string.format("%.2f", bp)) end

  local W, H = sw(), sh()
  local out = {}
  for _, o in ipairs(list) do
    if o.e ~= lp then
      local hy = o.y + 1.42
      local sx, sy, dep = w2s(cam, o.x, hy, o.z)
      local _, fy2 = w2s(cam, o.x, o.y, o.z)
      if sx and sx > 0 and sx < W and sy and sy > 0 and fy2 and fy2 > sy then
        local h = fy2 - sy
        if h > 4 and dep and dep > 0 then
          local nm = nil
          if gnk and dep < 90 then
            local np = call(gnk, o.e)
            if np and np ~= 0 then nm = str(np) end
          end
          out[#out + 1] = { x = sx, y = sy, h = h, d = dep, nm = nm, tx = o.x, ty = hy, tz = o.z }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.d < b.d end)
  boxes = out
  frames = frames + 1
end

local function aim()
  if not on("aim.on") or not seteu or #boxes == 0 or not cam then return end
  local ct = call(gtr, cam)
  if not ct or ct == 0 then return end
  local W, H = sw(), sh()
  local fov = on("aim.awm") and 0.42 or 0.16
  local best, bd = nil, 1e9
  for _, b in ipairs(boxes) do
    local dx, dy = b.x - W / 2, b.y + b.h * 0.18 - H / 2
    local d = dx * dx + dy * dy
    if math.abs(dx) < W * fov and math.abs(dy) < H * fov and d < bd then bd = d best = b end
  end
  if not best then return end
  local dx, dy, dz = best.tx - cx, best.ty - cy, best.tz - cz
  local hd = math.sqrt(dx * dx + dz * dz)
  local yaw = math.deg(math.atan2(dx, dz))
  local pitch = -math.deg(math.atan2(dy, hd))
  if on("aim.human") and not on("aim.awm") then
    local ex, ey = gete(geteu, ct)
    if ex then
      pitch = ex + (pitch - ex) * 0.55
      yaw = ey + (yaw - ey) * 0.55
    end
  end
  sete(seteu, ct, pitch, yaw, 0)
end

function tick()
  clear()
  if not on("esp.on") and not on("aim.on") then return end
  if frames % 2 == 0 then update() end
  if on("esp.color") then ci = (math.floor(os.clock() * 0.7) % #PAL) + 1 end
  local c = PAL[ci]
  if on("esp.on") then
    for _, b in ipairs(boxes) do
      local w = b.h * 0.42
      rect(b.x - w / 2, b.y, w, b.h, c[1], c[2], c[3], 1)
      if on("esp.name") and b.nm then text(b.nm, b.x - w / 2, b.y - 14, 1, 1, 1, 1) end
      if on("esp.dist") then
        text(string.format("%dm", math.floor(b.d)), b.x - w / 2, b.y + b.h + 2, c[1], c[2], c[3], 1)
      end
    end
  end
  aim()
  text("n=" .. #boxes, 12, sh() - 24, 0.6, 1, 0.6, 1)
end
