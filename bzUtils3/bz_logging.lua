local OOP = require("oop");
local json = require("json");

_unpack = unpack;

unpack = function(t)
  if(t.n ~= nil) then
    return _unpack(t,1,t.n)
  end
  return _unpack(t)
end


function table.pack(...)
  return { n = select("#", ...), ... };
end


local Class = OOP.Class;
GetMissionFilename = GetMissionFilename or GetMapTRNFilename;
local missionBase = GetMissionFilename():match("[^%p]+");



local LogFile = Class("logger.LogFile",{
  constructor = function(filename)
    if(CAN_LOG) then
      self.log_file = io.open(("%s.%s.log"):format(filename,missionBase),"a+");
      self:print("New entry");
    else
      self.log_file = nil;
    end
  end,
  methods = {
    print = function(...)
      if(self.log_file == nil) then return; end;
      local args = table.pack(...);
      for i,v in ipairs(args) do
        self.log_file:write(i ~= 1 and "    " or "",tostring(v));
      end
      self.log_file:write("\n");
      self.log_file:flush();
    end
  }
});


local function requireIO()
  require "luaio";
end

_G["CAN_LOG"] = false;



local s,e = pcall(requireIO);
if s then
  _G["CAN_LOG"] = true;
  local old_print = _G["print"];
  local old_display = _G["DisplayMessage"];
  local log_file = LogFile("lua_print");
  local log_send = LogFile("lua_send");
  local log_receive = LogFile("lua_receive");
  local log_save = LogFile("lua_save");
  local log_load = LogFile("lua_load");
  local log_error = LogFile("lua_trace");
  local frame = 0;
  _G["print"] = function(...)
    log_file:print(frame,"P: ",...);
    old_print(...);
  end
  _G["DisplayMessage"] = function(...)
    log_file:print(frame,"D: ",...);
    old_display(...);
  end
  local old_send = _G["Send"];
  function Send(...)
    old_send(...);
    log_send:print(frame,...);
  end


  local subH = {
    Save = _G["Save"],
    Load = _G["Load"],
    AddObject = _G["AddObject"],
    DeleteObject = _G["DeleteObject"],
    CreateObject = _G["CreateObject"],
    Start = _G["Start"],
    Update = _G["Update"]
  };

  local v2str = function(v)
    if(type(v) == "userdata") then
      if(IsValid(v)) then
        return ("Handle: %s, class: %s, label: %s"):format(tostring(v),tostring(GetClassLabel(v)),tostring(GetLabel(v)));
      end
    end
    return ("%s: %s"):format(type(v),tostring(v));
  end

  local function logTrace(...)
    local trace = debug.traceback();
    log_error:print(...);
    log_error:print(("New trace: @ frame %d"):format(frame));
    log_error:print(trace);
  end
  local function ProtectedCall(func,...)
    if(func) then
      local args = table.pack(...);
      local ret = nil;
      local status, message = xpcall(function()
        ret = table.pack(func(unpack(args)));
      end,logTrace);
      if(not status) then
        log_error:print("Status:", status);
        log_error:print("Message: ", message);
        log_error:print("Arguments passed in:");
        for i,v in ipairs(args) do
          log_error:print(("  %d. %s"):format(i,v2str(v)));
        end
        log_error:print("End of Error.\n----------------------------------------------------------\n");
        error(("Error occured and has been logged @ frame %d\nPress <OK> or <CANCEL> to abort."):format(frame));
      end
      return unpack(ret);
    end
  end
  local function Update(dtime)
    frame = frame + 1;
    ProtectedCall(subH.Update,dtime);
  end
  
  local function AddObject(h)
    ProtectedCall(subH.AddObject,h);
  end
  
  local function DeleteObject(h)
    ProtectedCall(subH.DeleteObject,h);
  end
  
  local function CreateObject(h)
    ProtectedCall(subH.CreateObject,h);
  end

  local function Start()
    ProtectedCall(subH.Start);
  end

  local function Save()
    local saveData = table.pack(ProtectedCall(subH.Save));
    log_save:print(frame,"New Save");
    for i,v in ipairs(saveData) do
      log_save:print("-- Save",i);
      log_save:print(json.encode(v));
    end
    return unpack(saveData);
  end

  local function Load(...)
    log_load:print(frame,"New Load");
    for i,v in ipairs(table.pack(...)) do
      log_load:print("-- Load",i);
      log_load:print(json.encode(v));
    end
    return ProtectedCall(subH.Load,...);
  end



  local hooks = {
    Save = Save,
    Load = Load,
    Update = Update,
    AddObject = AddObject,
    CreateObject = CreateObject,
    DeleteObject = DeleteObject,
    Start = Start
  }

  local p = {}; 
  p.old = getmetatable(_G) or {};

  p.__index = function(t,k)
    if(hooks[k]) then
      return hooks[k];
    elseif(p.old.__index) then
      return p.old.__index(t,k);
    else
      return rawget(t,k);
    end
  end

  p.__newindex = function(t,k,v)
    if(hooks[k]) then
      subH[k] = v;
    elseif(p.old.__newindex) then
      p.old.__newindex(t,k,v);
    else
      rawset(t,k,v);
    end
  end

  setmetatable(_G,p);

else
  print("Logging disabled",e);
end


return {
  LogFile = LogFile
};


