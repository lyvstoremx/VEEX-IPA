local path = DOC .. "/ref.dylib"
local len = flen and flen(path) or 0
log("ref " .. len)

local keys = {
  "csops", "SecCode", "CodeResources", "cryptid", "jailbreak", "frida",
  "dyld_image", "_dyld", "mobileprovision", "TeamIdentifier", "Signature",
  "codesign", "sysctl", "proc_pidinfo", "stat", "syscall", "dlopen",
  "ptrace", "gettaskallow", "embedded", "info.plist"
}

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

for _, k in ipairs(keys) do
  log(k .. " = " .. tostring(found[k] or 0))
end
log("FIN3")

while true do
  clear()
  text(40, 250, "VEEX cadenas", 0x00FF00FF, 20)
  text(40, 280, "ref " .. len, 0xFFFFFFFF, 12)
  msleep(300)
end
