log("VEEX v3 diag")

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

for a = 0, 3 do
  local p = i2c_ptr("Object", "FindObjectsOfType", a)
  log("F " .. a .. "=" .. (p and "SI" or "no"))
end

dump("Object", "find")
dump("Player", "nick")
dump("Player", "name")
dump("MatchGame", "entity")
dump("MatchGame", "player")

function tick()
  clear()
  text("VEEX v3", 70, 105, 1, 1, 1, 1)
end
