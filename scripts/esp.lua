local path = DOC .. "/ref.dylib"
local len = flen and flen(path) or 0
local keys = {"csops", "SecCode", "CodeResources", "cryptid", "jailbreak",
              "frida", "dyld_image", "_dyld", "mobileprovision", "TeamIdentifier",
              "Signature", "codesign", "sysctl", "proc_pidinfo", "ptrace", "dlopen"}
local found = {}
local off = 0
while off < len do
  local chunk = fread(path, off, 65536)
  if not chunk or #chunk == 0 then break end
  for _, k in ipairs(keys) do
    local c = 0
    local i = 1
    while true do
      local a, b = chunk:find(k, i, true)
      if not a then break end
      c = c + 1
      i = b + 1
    end
    if c > 0 then found[k] = (found[k] or 0) + c end
  end
  off = off + 65536
end
for _, k in ipairs(keys) do log(k .. " = " .. tostring(found[k] or 0)) end
log("FIN3")

local clsPlayer = i2c_cls("Player")
local clsCam = i2c_cls("Camera")
local fot = i2c_ptr("Object", "FindObjectsOfType", 1)
local gtr = i2c_ptr("Component", "get_transform", 0)
local gpos = i2c_ptr("Transform", "get_position", 0)
local w2s = i2c_ptr("Camera", "WorldToScreenPoint", 1)
log("esp clsP " .. tostring(clsPlayer) .. " cam " .. tostring(clsCam) ..
    " fot " .. tostring(fot) .. " gtr " .. tostring(gtr) ..
    " gpos " .. tostring(gpos) .. " w2s " .. tostring(w2s))

local SW, SH = 896, 414

local function frame()
  clear()
  if not (clsPlayer and clsCam and fot and gtr and gpos and w2s) then return -1 end
  local carr = call(fot, clsCam)
  local cam = arrat(carr, 0)
  if cam == 0 then return -2 end
  local arr = call(fot, clsPlayer)
  local n = arrlen(arr)
  local d = 0
  for i = 0, math.min(n - 1, 40) do
    if d >= 18 then break end
    local p = arrat(arr, i)
    if p and p ~= 0 then
      local tr = call(gtr, p)
      if tr and tr ~= 0 then
        local px, py, pz = callv(gpos, tr)
        local hx, hy, hz = callv3(w2s, cam, px, py, pz + 1.6)
        local fx, fy, fz = callv3(w2s, cam, px, py, pz)
        if fz > 0 and hz > 0 and fx > 0 and fy > 0 and fx < SW and fy < SH then
          local h = fy - hy
          if h > 6 and h < 420 then
            local w = h * 0.42
            text(hx - w / 2, hy, "________", 0x00FF00FF, 12)
            text(hx - w / 2, fy, "________", 0x00FF00FF, 12)
            d = d + 1
          end
        end
      end
    end
  end
  return d
end

while true do
  local d = frame()
  text(40, 384, "d=" .. tostring(d), 0xFFFFFFFF, 11)
  msleep(120)
end
