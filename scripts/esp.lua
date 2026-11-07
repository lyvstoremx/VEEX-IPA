log("VEEX v19")

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
local gnk = P and i2c_mptr(P, "get_NickName", 0)
local gp = i2c_ptr("Transform", "get_position", 0)
local w2s = i2c_ptr("Camera", "WorldToScreenPoint", 1)
local gm = i2c_ptr("Camera", "get_main", 0)
local vb = buf(16)
local t = P and clstype(P)
log("fot=" .. tostring(fot) .. " gtr=" .. tostring(gtr) .. " w2s=" .. tostring(w2s))

local s = sc()

function tick()
  clear()
  if not (fot and gtr and gp and w2s and gm and t) then
    text("faltan metodos", 70, 105, 1, 1, 1, 1)
    return
  end
  local cam = call(gm, 0)
  if not cam or cam == 0 then
    text("sin camara", 70, 105, 1, 1, 1, 1)
    return
  end
  local arr = callv(fot, 0, t)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 60 then n = 60 end
  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local vp = call(gp, tr)
        if vp and vp ~= 0 then
          local x, y, z = rv3(vp)
          wv3(vb, x, y + 1.55, z)
          local sp = callv(w2s, cam, vb)
          if sp and sp ~= 0 then
            local sx, sy, sz = rv3(sp)
            if sz > 0 then
              local ax = sx / s
              local ay = sy / s
              local h = math.max(28, 1400 / math.max(sz, 1))
              local w = h * 0.52
              rect(ax - w / 2, ay - h, w, h, 1, 0.2, 0.2, 1)
              if gnk then
                local np = call(gnk, e)
                if np and np ~= 0 then
                  text(str(np), ax - w / 2, ay - h - 13, 1, 0.2, 0.2, 1)
                end
              end
            end
          end
        end
      end
    end
  end
  text("n=" .. n, 70, 105, 1, 1, 1, 1)
end
