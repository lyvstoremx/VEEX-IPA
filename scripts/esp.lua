-- VEEX v77
local function on(k) return (cfg(k) or 0) ~= 0 end
local function P(cls, mth, argc)
  local c = i2c_class(cls)
  if not c then log("X cls " .. cls) return nil end
  local p = i2c_mptr(c, mth, argc or 0)
  if not p then log("X mth " .. cls .. "." .. mth) end
  return p
end

local camC    = i2c_class("Camera")
local tpp     = i2c_class("Player")
local fotp    = P("GameObject", "FindObjectsOfType", 1)
local w2sp    = camC and i2c_mptr(camC, "WorldToScreenPoint", 1)
local getmainp = camC and i2c_mptr(camC, "get_main", 0)
local gtrp    = P("Component", "get_transform", 0)
local gposp   = P("Transform", "get_position", 0)
local gfwdp   = P("Transform", "get_forward", 0)
local geteup  = P("Transform", "get_eulerAngles", 0)
local seteup  = P("Transform", "set_eulerAngles", 1)
local gnkp    = P("Player", "get_nickname", 0)
log("v77 fot=" .. tostring(fotp) .. " w2s=" .. tostring(w2sp) .. " tp=" .. tostring(tpp)
    .. " gm=" .. tostring(getmainp) .. " gtr=" .. tostring(gtrp)
    .. " gpos=" .. tostring(gposp) .. " fwd=" .. tostring(gfwdp) .. " camC=" .. tostring(camC))

local PAL = {
  {1, 0.22, 0.22}, {0.25, 1, 0.35}, {0.25, 0.72, 1}, {1, 1, 0.25},
  {1, 0.32, 1}, {1, 0.62, 0.15}, {1, 1, 1}
}
local ci, cam, frames, dlog = 1, nil, 0, 0
local camNul, hb = 0, 0
local boxes = {}
local cx, cy, cz = 0, 0, 0
local lastScan = 0
local SCAN_MS = 500

local function pickCam()
  if not getmainp then return nil end
  local c = call(getmainp, 0)
  if c and c ~= 0 then cam = c end
  return cam
end

local function update()
  if not cam then pickCam() end
  if not cam then
    camNul = camNul + 1
    if camNul <= 3 then log("sin camara (intento " .. camNul .. ")") end
    return
  end
  local ct = call(gtrp, cam)
  if not ct or ct == 0 then cam = nil return end
  cx, cy, cz = pos3(gposp, ct)
  local fx, fy, fz = 0, 0, 0
  if gfwdp then fx, fy, fz = pos3(gfwdp, ct) end

  local arr = callv(fotp, 0, tpp)
  if not arr or arr == 0 then
    if dlog < 3 then dlog = dlog + 1 log("fot devuelve 0") end
    return
  end
  local n = arrlen(arr)
  log("scan n=" .. n)

  local list, bp, lp = {}, 99, nil
  for i = 0, math.min(n, 60) - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtrp, e)
      if tr and tr ~= 0 then
        local x, y, z = pos3(gposp, tr)
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
  log("filtrados=" .. #list)

  local W, H = sw(), sh()
  local out = {}
  for _, o in ipairs(list) do
    if o.e ~= lp then
      local hy = o.y + 1.42
      local sx, sy, dep = w2s(w2sp, cam, o.x, hy, o.z)
      local _, fy2 = w2s(w2sp, cam, o.x, o.y, o.z)
      if sx and sx > 0 and sx < W and sy and sy > 0 and fy2 and fy2 > sy then
        local h = fy2 - sy
        if h > 4 and dep and dep > 0 then
          local nm = nil
          if gnkp and dep < 90 then
            local np = call(gnkp, o.e)
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
  log("proyectados=" .. #boxes)
end

local function aim()
  if not on("aim.on") or not seteup or #boxes == 0 or not cam then return end
  local ct = call(gtrp, cam)
  if not ct or ct == 0 then return end
  local W, H = sw(), sh()
  local fov = on("aim.awm") and 0.18 or 0.06
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
    local ex, ey = gete(geteup, ct)
    if ex then
      pitch = ex + (pitch - ex) * 0.22
      yaw = ey + (yaw - ey) * 0.22
    end
  end
  sete(seteup, ct, pitch, yaw, 0)
end

local function debugTab()
  if on("set.reset") then setcfg("set.reset", 0) reset() end
  if on("set.reload") then setcfg("set.reload", 0) reload() end
  if on("dbg.all") then setcfg("dbg.all", 0) dumpall() end
  if on("dbg.meta") then setcfg("dbg.meta", 0) meta() end
  if on("dbg.player") then
    setcfg("dbg.player", 0)
    for _, c in ipairs(dump("Player", 80)) do log("CLS " .. c.s .. "::" .. c.n) end
    log("-- fin player --")
  end
  if on("dbg.avatar") then
    setcfg("dbg.avatar", 0)
    for _, c in ipairs(dump("Avatar", 80)) do log("CLS " .. c.s .. "::" .. c.n) end
    log("-- fin avatar --")
  end
  if on("dbg.camera") then
    setcfg("dbg.camera", 0)
    for _, c in ipairs(dump("Camera", 80)) do log("CLS " .. c.s .. "::" .. c.n) end
    log("-- fin camera --")
  end
end

function tick()
  clear()
  debugTab()

  hb = hb + 1
  if hb % 20 == 0 then
    log("hb esp=" .. tostring(cfg("esp.on")) .. " cam=" .. tostring(cam) .. " n=" .. #boxes)
  end

  if not on("esp.on") and not on("aim.on") then return end

  local now = math.floor(os.clock() * 1000)
  if now - lastScan >= SCAN_MS then
    lastScan = now
    update()
  end

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
