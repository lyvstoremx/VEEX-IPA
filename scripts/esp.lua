local clsPlayer = i2c_cls("Player")
local clsCam = i2c_cls("Camera")
local fot = i2c_ptr("Object", "FindObjectsOfType", 1)
local gtr = i2c_ptr("Component", "get_transform", 0)
local gpos = i2c_ptr("Transform", "get_position", 0)
local w2s = i2c_ptr("Camera", "WorldToScreenPoint", 1)
local gnk = i2c_ptr("Player", "get_NickName", 0)

log("clsPlayer " .. tostring(clsPlayer) .. " cam " .. tostring(clsCam))
log("fot " .. tostring(fot) .. " gtr " .. tostring(gtr) .. " gpos " .. tostring(gpos) .. " w2s " .. tostring(w2s))

local SW, SH = 896, 414
local W = 60

local function frame()
  clear()
  if not (clsPlayer and clsCam and fot and gtr and gpos and w2s) then return 0 end

  local carr = call(fot, clsCam)
  local cam = arrat(carr, 0)
  if cam == 0 then return -1 end

  local arr = call(fot, clsPlayer)
  local n = arrlen(arr)
  local drawn = 0
  for i = 0, math.min(n - 1, 40) do
    if drawn >= 20 then break end
    local p = arrat(arr, i)
    if p and p ~= 0 then
      local tr = call(gtr, p)
      if tr and tr ~= 0 then
        local px, py, pz = callv(gpos, tr)
        local hx, hy, hz = callv3(w2s, cam, px, py, pz + 1.6)
        local fx, fy, fz = callv3(w2s, cam, px, py, pz)
        if fz > 0 and hz > 0 then
          local sx, sy = hx, hy
          local bx, by = fx, fy
          if bx > 0 and by > 0 and bx < SW and by < SH then
            local h = by - sy
            if h > 6 and h < 400 then
              local w = h * 0.42
              text(sx - w / 2, sy, "________", 0x00FF00FF, 12)
              text(sx - w / 2, by, "________", 0x00FF00FF, 12)
              local nm = "bot"
              if gnk then
                local s = call(gnk, p)
                if s and s ~= 0 then nm = "jugador" end
              end
              text(sx - w / 2, sy - 16, nm, 0x00FF00FF, 11)
              drawn = drawn + 1
            end
          end
        end
      end
    end
  end
  return drawn
end

local f = 0
while true do
  local d = frame()
  text(40, 380, "VEEX esp d=" .. tostring(d), 0xFFFFFFFF, 11)
  f = f + 1
  msleep(120)
end
