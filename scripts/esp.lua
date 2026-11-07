log("VEEX v6")

local function pickmax(name)
  local best, bn = nil, -1
  for _, c in ipairs(i2c_clsall(name)) do
    local n = #i2c_mnames(c)
    if n > bn then best, bn = c, n end
  end
  return best, bn
end

local P, pn = pickmax("Player")
log("P n=" .. pn)
local G = i2c_cls("GameFacade")
local MG = i2c_cls("MatchGame")
log("GF=" .. (G and "SI" or "no") .. " MG=" .. (MG and "SI" or "no"))

local function dump(c, pat, max)
  if not c then return end
  local n = 0
  for _, mn in ipairs(i2c_mnames(c)) do
    if mn:lower():find(pat) then log("  ." .. mn); n = n + 1; if n >= max then break end end
  end
end

dump(G, "player", 25)
dump(G, "all", 10)
dump(MG, "instance", 10)

local gi = MG and i2c_mptr(MG, "get_Instance", 0)
log("MGinst m=" .. (gi and "SI" or "no"))
if gi then log("MGinst=" .. tostring(call(gi, 0))) end

local ggi = G and i2c_mptr(G, "get_Instance", 0)
if ggi then
  local gf = call(ggi, 0)
  log("GFinst=" .. tostring(gf))
  if gf and gf ~= 0 then
    local clp = i2c_mptr(G, "CurrentLocalPlayer", 0)
    if clp then
      local lp = call(clp, gf)
      log("local=" .. tostring(lp))
      if lp and lp ~= 0 and P then
        local gtr = i2c_mptr(P, "get_transform", 0)
        local gnk = i2c_mptr(P, "get_NickName", 0)
        if gtr then
          local tr = call(gtr, lp)
          log("tr=" .. tostring(tr))
          if tr and tr ~= 0 then
            local gp = i2c_ptr("Transform", "get_position", 0)
            if gp then
              local vp = call(gp, tr)
              if vp and vp ~= 0 then
                local x, y, z = rv3(vp)
                log(string.format("pos %.1f %.1f %.1f", x, y, z))
              end
            end
          end
        end
        if gnk then
          local np = call(gnk, lp)
          if np and np ~= 0 then log("nick=" .. str(np)) end
        end
      end
    end
  end
end

function tick()
  clear()
  text("VEEX v6", 70, 105, 1, 1, 1, 1)
end
