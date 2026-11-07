log("VEEX v4")

local function dump(cls, pat, max)
  local t = i2c_methods(cls)
  if not t then log("X dump " .. cls); return end
  local n = 0
  for _, m in ipairs(t) do
    if m:lower():find(pat) then
      log("M " .. cls .. "." .. m)
      n = n + 1
      if n >= (max or 20) then break end
    end
  end
  log("D " .. cls .. "/" .. pat .. "=" .. n)
end

local all = i2c_classes()
local n = 0
for _, cn in ipairs(all) do
  if cn:find("RepEntity") then
    log("CL " .. cn)
    n = n + 1
    if n >= 15 then break end
  end
end
log("DCL=" .. n)

for _, k in ipairs({ "Player", "RepEntity", "LocalPlayer" }) do
  local c = i2c_cls(k)
  log("C " .. k .. "=" .. (c and "SI" or "no"))
end

for a = 0, 3 do
  local p = i2c_ptr("MatchGame", "GetRepEntity", a)
  log("GRE " .. a .. "=" .. (p and "SI" or "no"))
end

dump("Player", "get_", 40)
dump("Player", "transform", 10)
dump("RepEntity", "get_", 30)
dump("MatchGame", "local", 15)

function tick()
  clear()
  text("VEEX v4", 70, 105, 1, 1, 1, 1)
end
