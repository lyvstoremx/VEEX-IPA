log("VEEX v5")

local function dump(c, pat, max)
  local ms = i2c_mnames(c)
  local n = 0
  for _, mn in ipairs(ms) do
    if mn:lower():find(pat) then
      log("  ." .. mn)
      n = n + 1
      if n >= (max or 10) then break end
    end
  end
  return n
end

local ps = i2c_clsall("Player")
log("nPlayer=" .. #ps)
for i, c in ipairs(ps) do
  local ms = i2c_mnames(c)
  log("P" .. i .. " " .. i2c_cname(c) .. " n=" .. #ms)
  if #ms > 0 then dump(c, "name", 6); dump(c, "pos", 6); dump(c, "transform", 4) end
end

local mg = i2c_clsall("MatchGame")
log("nMG=" .. #mg)
for i, c in ipairs(mg) do
  local ms = i2c_mnames(c)
  log("MG" .. i .. " n=" .. #ms)
  dump(c, "instance", 8)
  dump(c, "get_", 15)
end

function tick()
  clear()
  text("VEEX v5", 70, 105, 1, 1, 1, 1)
end
