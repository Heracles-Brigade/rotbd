local bzindex = require("bzindex")
local bzutils = require("bzutils")

local msetup = require("msetup")
local setup = bzutils.defaultSetup(false, nil, "rotbd")
local serpent = require("serpent")
local core = setup.core
local serviceManager = setup.serviceManager
local ldebug = require("ldebug")


local rbdcomp = require("rbdcomp")

local SpawnOnKillSystem = rbdcomp.SpawnOnKillSystem
local KeepAliveSystem = rbdcomp.KeepAliveSystem

return {core = core, serviceManager = serviceManager, init = function()
  msetup.fullSetup(core)
  -- ldebug(serviceManager)

  local EcsModule = serviceManager:getServiceSync("bzutils.ecs")
  EcsModule:addSystem(SpawnOnKillSystem:processingSystem())
  EcsModule:addSystem(KeepAliveSystem:processingSystem())

end}