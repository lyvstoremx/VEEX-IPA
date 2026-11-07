log("VEEX v33")

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
local tp = P and clstype(P)
local done = false

local function kl(p)
  if not p or p == 0 then return 0 end
  return r32(p + 4) * 4294967296 + r32(p)
end

function tick()
  clear()
  local by = sh() - 22
  if done then text("listo", 10, by, 0.6, 1, 0.6, 1) return end
  if not (fot and gtr and tp) then text("faltan", 10, by, 1, 1, 1, 1) return end

  local arr = callv(fot, 0, tp)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n < 2 then return end

  for i = 0, 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(gtr, e)
      if tr and tr ~= 0 then
        local gp = i2c_mptr(kl(tr), "get_position", 0)
        if gp then
          local vp = call(gp, tr)
          log("== p" .. i .. " vp=" .. tostring(vp))
          if vp and vp ~= 0 then
            local o = {}
            for k = 0, 9 do
              local off = k * 4
              o[#o + 1] = string.format("%d:u=%d f=%.2f", off, r32(vp + off), rf(vp + off))
            end
            log(table.concat(o, " | "))
          end
        end
      end
    end
  end
  done = true
end
