local t0 = os.time()
local step = 0
local cands = { "ComputePosition", "UpdateKinematics", "UpdateBehavior", "OnUpdate",
                "get_position", "get_Transform", "ComputeBonePosition", "UpdatePosition" }

local function tryClass(ns, name)
  if ns and ns ~= "-" and ns ~= "" then return i2c_class(ns, name) end
  return i2c_class(name)
end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  if step == 0 then
    step = 1
    t0 = os.time()

    local pl = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. (pl and string.format("%x", pl) or "nil"))
    if not pl then
      local alt = i2c_class("Player")
      log("pl_alt=" .. (alt and string.format("%x", alt) or "nil"))
      pl = alt
    end
    if not pl then log("SIN CLASE"); step = 9; return end

    local f = fields(pl)
    log("campos=" .. #f)
    local ms = meths(pl, 400)
    log("metodos=" .. #ms)
    local hits = 0
    for i = 1, #ms do
      local n = ms[i]
      if n:find("osition") or n:find("Update") or n:find("Kinematic")
         or n:find("Behavior") or n:find("ransform") or n:find("Dead")
         or n:find("Alive") or n:find("Visible") then
        log("m " .. n)
        hits = hits + 1
        if hits >= 40 then break end
      end
    end

    local kls = { pl }
    local par = parents(pl)
    log("padres=" .. #par)
    for i = 1, #par do
      local s = par[i]
      local ns, nm = s:match("^(.-)::(.+)$")
      local k = tryClass(ns, nm or s)
      log("padre " .. s .. " -> " .. (k and string.format("%x", k) or "nil"))
      if k then kls[#kls + 1] = k end
    end

    local best = nil
    for c = 1, #kls do
      for i = 1, #cands do
        for argc = 0, 3 do
          local p = i2c_mptr(kls[c], cands[i], argc)
          if p then
            log("OK c" .. c .. " " .. cands[i] .. "/" .. argc .. " = " .. string.format("%x", p))
            if not best then best = p end
          end
        end
      end
    end

    if best then
      hv_clear()
      log("hook=" .. hook1(best))
      step = 2
      t0 = os.time()
    else
      log("SIN NINGUN PUNTERO")
      step = 9
    end
    return
  end

  if step == 2 then
    if os.time() - t0 < 3 then return end
    step = 3
    local n = hv_count()
    log("cosechados=" .. n)
    for i = 0, math.min(n, 10) - 1 do
      local o = hv_get(i)
      local k = kl(o)
      log(i .. " o=" .. string.format("%x", o) .. " cls=" .. (k and string.format("%x", k) or "0"))
    end
    local tr = nil
    if n > 0 then tr = r64(hv_get(0) + 0x58) end
    log("transform=" .. (tr and string.format("%x", tr) or "0"))
    local tf = i2c_class("UnityEngine", "Transform")
    local gp = tf and i2c_mptr(tf, "get_position", 0)
    log("get_position=" .. (gp and string.format("%x", gp) or "0"))
    if tr and gp then
      local x, y, z = pos3(gp, tr)
      log("pos=" .. string.format("%.1f %.1f %.1f", x, y, z))
    end
    log("PROBE11 FIN")
  end
end
