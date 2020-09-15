--[[
  Author: Miqueas Martinez (miqueas2020@yahoo.com)
  Date: 2020/09/12
  License: MIT (see it in the repository)
  Git Repository: https://github.com/M1que4s/Logger
]]

local Logger = {}
local unp = table.unpack or unpack
local esc = string.char(27) -- 0x1b: see the Wikipedia link below

-- Helper function for create color escape codes. Read this for more info:
-- https://en.wikipedia.org/wiki/ANSI_escape_code
local function e(...) return esc.."["..table.concat({...}, ";").."m" end
-- String templates
local Fmt = {
  Out = {
    Console  = e(2).."%s ["..e(0,1).."%s %s%s"..e(0,2).."] %s@%s:"..e(0).." %s",
    LogFile  = "%s [%s %s] %s@%s: %s"
  },
  FName = "%s_%s.log",
  Time = "%H:%M:%S"
}

local function DirExists(path)
  local f = io.open(path)
  if f then
    f:close()
    return true
  end
end

-- Appends a / or a \ (depending on the OS) at the end of a path string
local function DirNormalize(str)
  local str = tostring(str or "")
  local os_check = os.getenv("HOME")

  if jit then os_check = not (jit.os == "Windows") end -- More effective in LuaJIT

  if os_check then
    if not str:find("%/+", -1) then str = str .. "/" end -- POSIX
  else
    if not str:find("%\\+", -1) then str = str .. "\\" end -- Windows
  end

  return str
end

Logger.Path       = "./" -- Path where log files are saved
Logger.Namespace  = "Logger"
Logger.Console    = false -- By default, Logger don't write logs to the terminal
Logger.LogLvl     = 2 -- The default log level
Logger.Header     = "\n"..e(2).."%s ["..e(0,1).."%s"..e(0,2).."]"..e(0).."\n"
Logger.FileSuffix = "%Y-%m-%d"

Logger.Type = {
  [0] = { Name = "OTHER", Color = "30" },
  [1] = { Name = "TRACE", Color = "32" },
  [2] = { Name = "DEBUG", Color = "36" },
  [3] = { Name = "INFO.", Color = "34" },
  [4] = { Name = "WARN.", Color = "33" },
  [5] = { Name = "ERROR", Color = "31" },
  [6] = { Name = "FATAL", Color = "35" }
}

local function IsLogLevel(str)
  if type(str) == "string" then
    for i = 0, #Logger.Type do
      if str:upper() == Logger.Type[i].Name:gsub("%.", "") then
        return i
      end
    end
    return false
  else return false end
end

function Logger:new(name, dir, console, suffix, header, ...)
  -- Prevents wrong arguments type
  local err = "Bad argument #%s to 'new()', '%s' expected, got %s"
  assert(type(name)    == "string"  or type(name)    == "nil", err:format(1, "string",  type(name)))
  assert(type(dir)     == "string"  or type(dir)     == "nil", err:format(2, "string",  type(dir)))
  assert(type(console) == "boolean" or type(console) == "nil", err:format(3, "boolean", type(console)))
  assert(type(suffix)  == "string"  or type(suffix)  == "nil", err:format(4, "string",  type(suffix)))
  assert(type(header)  == "string"  or type(header)  == "nil", err:format(5, "string",  type(header)))

  local o = setmetatable({}, { __call = Logger.log, __index = self })
  o.Namespace  = name or "Logger"
  o.Console    = console
  o.FileSuffix = suffix or "%Y-%m-%d"

  if not dir or  #dir == 0 then o.Path = "./"
  elseif dir and DirExists(dir) then o.Path = DirNormalize(dir)
  elseif dir and not DirExists(dir) then
    error("Path '"..dir.."' doesn't exists or you don't have permissions to use it.")
  else -- Idk... And unexpected error can be happend!
    error("Unknown error while checking (and/or loading) '"..dir.."'... (argument #2 in 'new()')")
  end

  -- Writes a header at begin of all logs
  local header = header and header:format(...) or "AUTOGENERATED BY LOGGER"
  local time = os.date(Fmt.Time)
  local file = io.open(self.Path..Fmt.FName:format(self.Namespace, os.date(self.FileSuffix)), "a+")
  local fout = self.Header:format(time, header):gsub(esc.."%[(.-)m", "")
  file:write(fout)
  file:close()

  return o
end

function Logger:log(msg, lvl, ...)
  -- 'lvl' is optional and if isn't a log level ("error", "warn", etc...), assumes that is
  -- part of '...' (for push it in 'msg' using string.format)
  local lvl = IsLogLevel(lvl) or self.LogLvl
  local va = IsLogLevel(lvl) and {...} or { lvl, ... }
  local msg = tostring(msg) -- 'log()' assumes that 'msg' is an string

  -- This prevents that 'Logger.lua' appeared in the log message when 'expect()' is called.
  -- Basically is like the ternary operator in C: (exp) ? TRUE : FALSE
  local info = (debug.getinfo(2, "Sl").short_src:find("(Logger.lua)"))
    and debug.getinfo(3, "Sl") or debug.getinfo(2, "Sl")

  -- The log file
  local file = io.open(self.Path .. Fmt.FName:format(self.Namespace, os.date(self.FileSuffix)), "a+")
  local time = os.date(Fmt.Time) -- Prevents put different times in the file and the standard output
  local fout = Fmt.Out.LogFile:format(
    time,
    self.Namespace,
    self.Type[lvl].Name, -- Name of the type of log
    info.short_src, -- Source file from 'log()' is called
    info.currentline, -- Line where is called
    msg:format(unp(va))
      :gsub("("..esc.."%[(.-)m)", "") -- Removes ANSI SGR codes
  )

  file:write(fout.."\n") -- The '\n' makes stacking logs
  file:close()

  if self.Console then
    local cout = Fmt.Out.Console:format(
      time,
      self.Namespace,
      e(self.Type[lvl].Color), -- Uses the correct color for differents logs
      self.Type[lvl].Name,
      info.short_src,
      info.currentline,
      -- Here we don't remove ANSI codes because we want a colored output
      msg:format(unp(va))
    )
    print(cout)
  end

  if lvl >= 5 then
    -- A log level major to 5 causes the program stops
    self:header(e(31).."SOMETHING BAD HAPPEND")
    if love then love.event.quit() end -- For Love2D compatibility
    os.exit(1)
  end
end

function Logger:expect(exp, msg, lvl, ...)
  if not exp then self:log(msg, lvl, ...)
  else return exp end
end

-- Write a header log. May util if you want to separate some logs or  create "break points", etc...
function Logger:header(msg, ...)
  if type(msg) == "string" and #msg > 0 then
    local msg = msg:format({...})
    local time = os.date(Fmt.Time)
    local file = io.open(self.Path..Fmt.FName:format(self.Namespace, os.date(self.FileSuffix)), "a+")
    local fout = self.Header:format(time, msg):gsub(esc.."%[(.-)m", "")
    file:write(fout.."\n")
    file:close()

    if self.Console then print(self.Header:format(time, msg)) end
  else return end
end

function Logger:setLogLvl(lvl)
  local lvl   = (type(lvl) == "number" or type(lvl) == "string") and lvl
  self.LogLvl = IsLogLevel(lvl) or 2
end

function Logger:setFileSuffix(str)
  local str = (type(str) == "string" and #str > 0) and str or "%Y-%m-%d"
  self.FileSuffix = str
end

return setmetatable(Logger, { __call = Logger.new, __index = Logger })
