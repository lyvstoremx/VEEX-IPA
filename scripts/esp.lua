-- VEEX esp
local R, G, B = 1, 0.15, 0.15
local s = sc()
local vb = buf(16)
local ready, err = false, nil

local m = {}
local function res(cls, name, argc)
  local c = i2c_cls(cls)
  if not c then return nil end
  return i2c_ptr(cls, name, argc or 0)
end

local function init()
  m.giz     = res("TransformGizmo", "get_MyCamera")
  m.w2s     = res("Camera", "WorldToScreenPoint", 1)
  m.pw      = res("Camera", "get_pixelWidth")
  m.ph      = res("Camera", "get_pixelHeight")
  m.find    = res("Object", "FindObjectsOfType", 1)
  m.player  = i2c_cls("Player")
  m.transform = res("Component", "get_transform")
  m.pos     = res("Transform", "get_position")
  m.name    = res("Player", "get_NickName")
  m.campos  = res("Transform", "get_position")
  if not (m.giz and m.w2s and m.find and m.player and m.pos) then
    err = "faltan metodos"
    return false
  end
  return true
end

function tick()
  clear()
  if not ready then
    if not init() then
      text("VEEX: " .. (err or "init"), 20, 120, 1, 0.3, 0.3, 1)
      return
    end
    ready = true
    log("esp listo")
  end
  if not get("esp") then return end

  local cam = call(m.giz, 0)
  if not cam or cam == 0 then return end
  local cw = call(m.pw, cam)
  local ch = call(m.ph, cam)
  if not cw or cw == 0 then return end

  local arr = callv(m.find, 0, m.player)
  if not arr or arr == 0 then return end
  local n = arrlen(arr)
  if n > 100 then n = 100 end

  for i = 0, n - 1 do
    local p = arrat(arr, i)
    if p and p ~= 0 then
      local tr = call(m.transform, p)
      if tr and tr ~= 0 then
        local vp = call(m.pos, tr)
        if vp and vp ~= 0 then
          local x = rv3(vp)
          local y = rv3 and 0
          local px, py, pz = rv3(vp)
          wv3(vb, px, py + 1.55, pz)
          local sp = callv(m.w2s, cam, vb)
          if sp and sp ~= 0 then
            local sx, sy, sz = rv3(sp)
            if sz > 0 then
              local ax = sx / s
              local ay = sy / s
              local h = math.max(28, 1400 / math.max(sz, 1))
              local w = h * 0.52
              if get("box") then
                rect(ax - w / 2, ay - h, w, h, R, G, B, 1)
              end
              if get("line") then
                line(cw / s / 2, ch / s, ax, ay, R, G, B, 1)
              end
              if get("name") and m.name then
                local np = call(m.name, p)
                local nm = np and np ~= 0 and str(np) or "?"
                text(nm, ax - w / 2, ay - h - 13, R, G, B, 1)
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
