log("VEEX v22")

local function pickmax(name)
  local best, bn = nil, -1
  for _, c in ipairs(i2c_clsall(name)) do
    local n = #i2c_mnames(c)
    if n > bn then best, bn = c, n end
  end
  return best
end

local P = pickmax("Player")
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
local w2s = i2c_ptr("Camera", "WorldToScreenPoint", 1)
local gm = i2c_ptr("Camera", "get_main", 0)
local vb = buf(16)
local t = P and clstype(P)
local done = false

function tick()
  clear()
  rect(120, 60, 120, 200, 0, 1, 0, 1)
  if done then return end
  if not (fot and gtr and gp and w2s and gm and t) then
    text("faltan", 120, 50, 1, 1, 1, 1)
    return
  end
  local cam = call(gm, 0)
  log("cam=" .. tostring(cam))
  if not cam or cam == 0 then return end
  local arr = callv(fot, 0, t)
  log("arr=" .. tostring(arr))
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  log("n=" .. n)
  if n < 1 then return end
  for i = 0, math.min(n, 4) - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local vp = call(gp, tr)
        if vp and vp ~= 0 then
          local x, y, z = rv3(vp)
          log(string.format("pos%d %.1f %.1f %.1f", i, x, y, z))
          wv3(vb, x, y + 1.55, z)
          local sp = callv(w2s, cam, vb)
          log("sp" .. i .. "=" .. tostring(sp))
          if sp and sp ~= 0 then
            local sx, sy, sz = rv3(sp)
            log(string.format("scr%d %.0f %.0f %.1f", i, sx, sy, sz))
          end
        end
      end
    end
  end
  done = true
end
