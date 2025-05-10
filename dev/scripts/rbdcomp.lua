local _ = require("bzindex")


local utils = require("utils")
local bztiny = require("bztiny")
local bzsystems = require("bzsystems")
local bzcomponents = require("bzcomp") 
local Component = bztiny.Component
local namespace = utils.namespace
local createClass = utils.createClass
local loadFromFile = bztiny.loadFromFile
local System = bzsystems.System
local bzext = require("bzext")
local serpent = require("serpent")


local BzHandleComponent = bzcomponents.BzHandleComponent
local PositionComponent = bzcomponents.PositionComponent

local SpawnComponent = createClass("SpawnComponent", {
  new = function(self)
    self.odf = nil
    self.entityRef = nil
    self.team = 0
  end
}, Component)

local KeepAliveComponent = createClass("KeepAliveComponent", {
  new = function(self)
    self.keepAliveAcc = 4
    self.phealth = 0
  end
}, Component)

local KeepAliveSystem  = createClass("KeepAliveSystem", {
  filter = bztiny.requireAll(BzHandleComponent, KeepAliveComponent),
  onAdd = function(self, entity)
    local keepAliveComponent = KeepAliveComponent:getComponent(entity)
    local handle = BzHandleComponent:getComponent(entity).handle
    keepAliveComponent.phealth = GetMaxHealth(handle)
    SetMaxHealth(handle, 0)
  end,
  process = function(self, entity, dtime)
    local keepAliveComponent = KeepAliveComponent:getComponent(entity)
    local handle = BzHandleComponent:getComponent(entity).handle
    keepAliveComponent.keepAliveAcc = keepAliveComponent.keepAliveAcc - dtime
    if(keepAliveComponent.keepAliveAcc <= 0) then
      SetMaxHealth(handle, keepAliveComponent.phealth)
      KeepAliveComponent:removeEntity(entity)
      self.bzworld:updateTinyEntity(entity)
    end
  end
}, System)

local SpawnOnKillSystem = createClass("SpawnOnKillSystem", {
  filter = bztiny.requireAll(BzHandleComponent, PositionComponent, SpawnComponent),
  process = function(self, entity, dtime)
    local handleComponent = BzHandleComponent:getComponent(entity)
    local spawnComponent = SpawnComponent:getComponent(entity)
    local positionComponent = PositionComponent:getComponent(entity)
    if IsValid(handleComponent.handle) then
      spawnComponent.team = GetTeamNum(handleComponent.handle)
    end
    if not IsAlive(handleComponent.handle)  then
      local spawned = BuildObject(spawnComponent.odf, spawnComponent.team, positionComponent.position)
      self.registerHandle(spawned)
      local spawnedEntity = self.getEntityByHandle(spawned)
      
      KeepAliveComponent:addEntity(spawnedEntity)
      SpawnComponent:removeEntity(entity)
      self.bzworld:updateTinyEntity(entity)
    end
  end
}, System)



namespace("rotbd.ecs", SpawnComponent, SpawnOnKillSystem, KeepAliveComponent, KeepAliveSystem)

loadFromFile(SpawnComponent, "SpawnComponentClass", {
  odf = "string"
})




return {
  SpawnComponent = SpawnComponent,
  SpawnOnKillSystem = SpawnOnKillSystem,
  KeepAliveComponent = KeepAliveComponent,
  KeepAliveSystem = KeepAliveSystem,
}