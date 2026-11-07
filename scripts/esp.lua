log("VEEX v7")

local G = i2c_cls("GameFacade")
local MG = i2c_cls("MatchGame")
log("GF=" .. (G and "SI" or "no") .. " MG=" .. (MG and "SI" or "no"))

local function dump(c, pat, max)
  if not c then return end
  local n = 0
  for _, mn in ipairs(i2c_mnames(c)) do
    if mn:lower():find(pat) then log("  ." .. mn); n = n + 1; if n >= max then break end end
  end
  log("D " .. pat .. "=" .. n)
end

dump(G, "instance", 10)
dump(G, "singleton", 10)
dump(G, "current", 15)
dump(G, "get_", 45)
dump(G, "list", 10)
dump(MG, "get_", 45)
dump(MG, "match", 10)

function tick()
  clear()
  text("VEEX v7", 70, 105, 1, 1, 1, 1)
end
