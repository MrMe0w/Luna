-- TODO
-- TODO
-- TODO

local classes = {}

-- No base class
local class_base = [[
do
  local _class = {
    new = function(o, ...)
      local nobj = {}
      setmetatable(nobj, o)
      table.safe_merge(nobj, o)
      if o["#1"] then
        o["#1"](nobj, ...)
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = nil
  }
  _G["#1"] = _class
#3
end
]]

-- with base class
local class_base_extend = [[
do
  local _class = {
    new = function(o, ...)
      local nobj = {}
      setmetatable(nobj, o)
      table.safe_merge(nobj, o)
      local bc = o.base_class
      local has_bc = true
      while istable(bc) and has_bc do
        if isfunction(bc[bc.class_name]) then
          local s, v = pcall(bc[bc.class_name], nobj, ...)
          if !s then
            ErrorNoHalt("Base class constructor has failed to run!\n"..tostring(v).."\n")
          end
        end
        if bc.base_class and (bc.class_name != bc.base_class.class_name) then
          bc = bc.base_class
        else
          has_bc = false
        end
      end
      if o["#1"] then
        o["#1"](nobj, ...)
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = _G["#2"]
  }
  local _base = _G["#2"]
  if istable(_base) then
    local copy = table.Copy(_base)
    table.safe_merge(copy, _class)
    if isfunction(_base.extended) then
      local s, v = pcall(_base.extended, _base, copy)
      if !s then
        ErrorNoHalt("'extended' class hook has failed to run!\n"..tostring(v).."\n")
      end
    end
    _class = copy
  else
    ErrorNoHalt("#2 is not a valid class!\n")
  end
  _G["#1"] = _class
#3
end
]]

-- with base class, reverse init
local class_base_extend_reverse = [[
do
  local _class = {
    new = function(o, ...)
      local nobj = {}
      setmetatable(nobj, o)
      table.safe_merge(nobj, o)
      if o["#1"] then
        o["#1"](nobj, ...)
      end
      local bc = o.base_class
      local has_bc = true
      while istable(bc) and has_bc do
        if isfunction(bc[bc.class_name]) then
          local s, v = pcall(bc[bc.class_name], nobj, ...)
          if !s then
            ErrorNoHalt("Base class constructor has failed to run!\n"..tostring(v).."\n")
          end
        end
        if bc.base_class and (bc.class_name != bc.base_class.class_name) then
          bc = bc.base_class
        else
          has_bc = false
        end
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = _G["#2"]
  }
  local _base = _G["#2"]
  if istable(_base) then
    local copy = table.Copy(_base)
    table.safe_merge(_class, copy)
    if isfunction(_class.extended) then
      local s, v = pcall(_class.extended, _class, copy)
      if !s then
        ErrorNoHalt("'extended' class hook has failed to run!\n"..tostring(v).."\n")
      end
    end
  else
    ErrorNoHalt("#2 is not a valid class!\n")
  end
  _G["#1"] = _class
#3
end
]]

local function process_definition(code)
  local s, e, classname = code:find("class%s+([%w_]+)")

  while (s) do
    if (s - 1 == 0 or code:sub(s - 1, s - 1):match("[%s\n]")) then
      line = code:sub(e + 1, code:find("\n", e + 1)):trim():trim("\n")

      if (#line <= 0) then line = classname end

      if (line and #line > 0) then
        local class_end, real_end = luna.util.FindLogicClosure(code, e, 1)

        if (!real_end) then
          parser_error("'end' not found for class", s, ERROR_CRITICAL)

          return code
        end

        local code_block = code:sub(code:find("\n", e + 1) + 1, class_end - 1)

        -- class extended
        if (line:find("<") or line:find(">")) then
          local extend_regular = line:find("<")
          local extend_char = extend_regular and "<" or ">"
          local class_name = classname
          local base_class_name = line:sub(line:find(extend_char) + 1, #line):trim()
          local class_code = extend_regular and class_base_extend or class_base_extend_reverse

          code_block = code_block:gsub("function%s+([%w_]+)", "function "..class_name..":%1")
          class_code = class_code:gsub("#1", class_name):gsub("#2", base_class_name):gsub("#3", code_block)

          code = luna.pp:PatchStr(code, s, real_end, class_code)

          e = s + class_code:len()
        else -- regular class
          local class_name = line:trim():gsub("\n", "")
          local class_code = class_base

          code_block = code_block:gsub("function%s+([%w_]+)", "function "..class_name..":%1")
          class_code = class_code:gsub("#1", class_name):gsub("#3", code_block)

          code = luna.pp:PatchStr(code, s, real_end, class_code)

          e = s + class_code:len()
        end
      end
    end

    s, e, classname = code:find("class%s+([%w_]+)", e)
  end

  return code
end

local function process_instantiation(code)
  return code:gsub("new%s+([%w_]+)", "%1:new")
end

luna.pp:AddProcessor("oop", function(code)
  code = save_strings(code, true)
  code = code:gsub("this%.", "self."):gsub("this:", "self:"):gsub("([%s\n]?)this([%s\n]?)", "%1self%2")
  code = process_definition(code)
  code = process_instantiation(code)
  code = restore_strings(code)

  return code
end)
