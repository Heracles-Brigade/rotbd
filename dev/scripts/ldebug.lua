local bzindex = require("bzindex")
local bztt = require("bztt")
local uuid = require("uuid")
local bzext = require("bzext")

local BZTTClient = bztt.BZTTClient

local function createTraceFunction(bzttClient, debugTopic)
  return function(...)
    local trace = debug.traceback();
    local args = {...}
    for i=1, #args do
      args[i] = tostring(args[i])
    end
    bzttClient:publishTbl(debugTopic, {
      trace = trace,
      err = args,
      type = "error"
    })
    local oldtimeout = bzttClient.socket:gettimeout()
    bzttClient.socket:settimeout(2)
    bzttClient.socket:_update()
    bzttClient.socket:settimeout(oldtimeout)
    return table.concat(args, "\n") .. trace
  end
end

local function voidHandler()
end

local function initLogging(serviceManager)
  _Start = _G["Start"]
  _Update = _G["Update"]
  _AddObject = _G["AddObject"]
  _CreateObject = _G["CreateObject"]
  _DeleteObject  = _G["DeleteObject"]
  _Save = _G["Save"]
  _Load = _G["Load"]

  local socketm = serviceManager:getServiceSync("bzutils.socket")

  local bzttClient = BZTTClient:create("dock1.spaceway.network")
  local clientId = bzext.readString("client_id")
  if(clientId == nil) then
    clientId = uuid()
    bzext.writeString("client_id", clientId)
  end
  bzext.getAppInfo("301650")
  local steamId = bzext.getUserId()
  if steamId == nil then
    steamId = "S_UNKNOWN"
  end
  
  local mapName = "TRN_" .. GetMapTRNFilename()
  if GetMissionFilename then
    mapName = "BZN_" .. GetMissionFilename()
  end
  local debugTopic = ("/rotbd-dev/%s/debug"):format(mapName)
  
  if IsBz15() then
    debugTopic = ("/rotbd-dev1.5/%s/debug"):format(mapName)
  end
  
  local ready = false

  bzttClient:connect({
    clientId = clientId,
    userId = 1,
    username = steamId,
    team = 1
  }):subscribe(function(...)
    print("Connected to debug server, joining topic...")
    bzttClient:joinTopic(debugTopic):subscribe(function(...)
      print("Joined topic", ...)
      ready = true
    end)
  end)

  local exceptionHandler = createTraceFunction(bzttClient, debugTopic)

  local error_counter = {
    Update = 0,
    AddObject = 0,
    CreateObject = 0,
    DeleteObject = 0
  }

  socketm:handleSocket(bzttClient.socket)
  
  local oldtimeout = bzttClient.socket:gettimeout()
  bzttClient.socket:settimeout(1)
  bzttClient.socket:_update()
  bzttClient.socket:_update()
  bzttClient.socket:settimeout(oldtimeout)
  
  _G["Start"] = function()
    bzttClient:publishTbl(debugTopic, {
      type = "CALL",
      func = "Start"
    })
    local success, err = xpcall(_Start, exceptionHandler)
    
    assert(success, err)
  end
  _G["Update"] = function(dtime)
    if error_counter.Update > 10 then
      xpcall(function() _Update(dtime) end, voidHandler)
      return
    end

    local success, err = xpcall(function() _Update(dtime) end, exceptionHandler)
    if not success then
      error_counter.Update = error_counter.Update + 1
      print(err)
    else
      error_counter.Update = 0
    end
    if (error_counter.Update > 10) then
      assert(success, "More than 10 errors have occured in Update!\nWill ignore all future errors!\nThe errors have been reported,\n but the mission will probably not work from here on out.")
    end
  end
  _G["AddObject"] = function(handle)
    bzttClient:publishTbl(debugTopic, {
      type = "CALL",
      func = "AddObject",
      handle = tostring(handle),
      odf = GetOdf(handle),
      label = GetLabel(handle),
      team = GetTeamNum(handle)
    })
    if error_counter.AddObject > 10 then
      xpcall(function() _AddObject(handle) end, voidHandler)
      return
    end
    
    local success, err = xpcall(function() _AddObject(handle) end, exceptionHandler)
    if not success then
      error_counter.AddObject = error_counter.AddObject + 1
    else
      error_counter.AddObject = 0
    end
    
    
    assert(success, err)
  end
  _G["CreateObject"] = function(handle)
    bzttClient:publishTbl(debugTopic, {
      type = "CALL",
      func = "CreateObject",
      handle = tostring(handle)
    })
    if error_counter.CreateObject > 10 then
      xpcall(function() _CreateObject(handle) end, voidHandler)
      return
    end

    local success, err = xpcall(function() _CreateObject(handle) end, exceptionHandler)
    
    if not success then
      error_counter.CreateObject = error_counter.CreateObject + 1
    else
      error_counter.CreateObject = 0
    end
    assert(success, err)
  end
  _G["DeleteObject"] = function(handle)
    bzttClient:publishTbl(debugTopic,{
      type = "CALL",
      func = "DeleteObject",
      handle = tostring(handle)
    })
    
    if error_counter.DeleteObject > 10 then
      xpcall(function() _DeleteObject(handle) end, voidHandler)
      return
    end
    local success, err = xpcall(function() _DeleteObject(handle) end, exceptionHandler)
    if not success then
      error_counter.DeleteObject = error_counter.DeleteObject + 1
    else
      error_counter.DeleteObject = 0
    end
    assert(success, err)
  end
  _G["Save"] = function(...)
    local args = table.pack(...)
    local ret = nil
    
    bzttClient:publishTbl(debugTopic, {
      type = "CALL",
      func = "Save"
    })
    
    local success, err = xpcall(function() ret = table.pack(_Save(unpack(args))) end, exceptionHandler)
    assert(success, err)
    return unpack(ret)
  end
  _G["Load"] = function(...)
    local args = table.pack(...)
    local ret = nil

    
    bzttClient:publishTbl(debugTopic, {
      type = "CALL",
      func = "Load"
    })
    local success, err = xpcall(function() ret = table.pack(_Load(unpack(args))) end, exceptionHandler)
    assert(success, err)
    return unpack(ret)
  end  

end

return initLogging