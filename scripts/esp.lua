log("VEEX v25")

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
local gp = i2c_ptr("Transform", "get_position", 0)
local w2s = C and i2c_mptr(C, "WorldToScreenPoint", 1)
local gdepth = C and i2c_mptr(C, "get_depth", 0)
local vb = buf(16)
local tp = P and clstype(P)
local tc = C and clstype(C)
local s = sc()
local done = false

function tick()
  clear()
  local by = sh() - 22
  if done then
    text("listo", 10, by, 0.6, 1, 0.6, 1)
    return
  end
  if not (fot and gtr and gp and w2s and tp and tc) then
    text("faltan", 10, by, 1, 1, 1, 1)
    return
  end

  local carr = callv(fot, 0, tc)
  if not carr or carr == 0 then text("sin arr cam", 10, by, 1, 1, 1, 1) return end
  local nc = arrlen(carr)
  log("ncam=" .. nc)
  if nc < 1 then return end

  local cam, bd = nil, -1e9
  for i = 0, math.min(nc, 20) - 1 do
    local e = arrat(carr, i)
    if e and e ~= 0 then
      local d = gdepth and rf(call(gdepth, e)) or 0
      if d > bd then cam, bd = e, d end
    end
  end
  log("cam=" .. tostring(cam) .. " d=" .. tostring(bd))
  if not cam then return end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  log("np=" .. n)
  if n < 1 then return end

  for i = 0, math.min(n, 5) - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local vp = call(gp, tr)
        if vp and vp ~= 0 then
          local x, y, z = rv3(vp)
          log(string.format("p%d %.1f %.1f %.1f", i, x, y, z))
          wv3(vb, x, y + 1.55, z)
          local sp = callv(w2s, cam, vb)
          log("sp" .. i .. "=" .. tostring(sp))
          if sp and sp ~= 0 then
            local sx, sy, sz = rv3(sp)
            log(string.format("sc%d %.0f %.0f %.1f", i, sx, sy, sz))
            rect(sx / s - 40, sy / s - 120, 80, 160, 0, 1, 0, 1)
          end
        end
      end
    end
  end
  done = true
end
