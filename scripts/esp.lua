log("VEEX v2 cargado")
local R, G, B = 1, 0.15, 0.15
local s = sc()
local vb = buf(16)
local M = {}
local ok = false
local frames = 0

local function try(cls, name, argc)
  local c = i2c_cls(cls)
  if not c then log("X clase " .. cls); return nil end
  local p = i2c_ptr(cls, name, argc or 0)
  if not p then log("X met " .. cls .. "." .. name .. "/" .. (argc or 0)) end
  return p
end

local function resolve()
  M.giz = try("TransformGizmo", "get_MyCamera")
  if not M.giz then M.giz = try("Camera", "get_main") end
  M.w2s  = try("Camera", "WorldToScreenPoint", 1)
  M.pw   = try("Camera", "get_pixelWidth")
  M.ph   = try("Camera", "get_pixelHeight")
  M.find = try("Object", "FindObjectsOfType", 1)
  M.player = i2c_cls("Player")
  if not M.player then log("X clase Player") end
  M.tr   = try("Component", "get_transform")
  M.pos  = try("Transform", "get_position")
  M.name = try("Player", "get_NickName")
  ok = (M.giz and M.w2s and M.find and M.player and M.tr and M.pos) and true or false
  log(ok and "RES OK" or "RES INCOMPLETO")
end

resolve()

function tick()
  clear()
  frames = frames + 1
  if not ok then
    if frames % 180 == 0 then resolve() end
    text("VEEX v2", 70, 105, 1, 1, 1, 1)
    return
  end
  if not get("esp") then return end

  local cam = call(M.giz, 0)
  if not cam or cam == 0 then return end
  local cw = call(M.pw, cam)
  local ch = call(M.ph, cam)
  if not cw or cw == 0 then return end

  local arr = callv(M.find, 0, M.player)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 100 then n = 100 end

  for i = 0, n - 1 do
    local p = arrat(arr, i)
    if p and p ~= 0 then
      local tr = call(M.tr, p)
      if tr and tr ~= 0 then
        local vp = call(M.pos, tr)
        if vp and vp ~= 0 then
          local px, py, pz = rv3(vp)
          wv3(vb, px, py + 1.55, pz)
          local sp = callv(M.w2s, cam, vb)
          if sp and sp ~= 0 then
            local sx, sy, sz = rv3(sp)
            if sz > 0 then
              local ax = sx / s
              local ay = sy / s
              local h = math.max(28, 1400 / math.max(sz, 1))
              local w = h * 0.52
              if get("box") then rect(ax - w / 2, ay - h, w, h, R, G, B, 1) end
              if get("line") then line(cw / s / 2, ch / s, ax, ay, R, G, B, 1) end
              if get("name") and M.name then
                local np = call(M.name, p)
                if np and np ~= 0 then text(str(np), ax - w / 2, ay - h - 13, R, G, B, 1) end
              end
              if get("dist") then
                text(string.format("%dm", math.floor(sz)), ax - w / 2, ay + 2, 1, 1, 1, 1)
              end
            end
          end
        end
      end
    end
  end
end
