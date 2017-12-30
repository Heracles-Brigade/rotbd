
local OOP = require("oop");
local misc = require("misc");
local bzObjects = require("bz_objects");

local GameObject = bzObjects.GameObject;

local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local KeyListener = misc.KeyListener;
local BzDestroy = misc.BzDestroy;
local Class = OOP.Class;

local bzRoutine = require("bz_routine");
local Routine = bzRoutine.Routine;


local InfHPRoutine = Decorate(
  Routine({
    name = "InfHPRoutine",
    delay = 0.1
  }),
  Class("InfHPRoutineClass",{
    constructor = function()
      self.life = 0;
    end,
    methods = {
      isAlive = function()
        return self.life > 0;
      end,
      save = function()
        return self.handle, self.life, self.origMHP, self.origHP
      end,
      load = function(...)
        self.handle, self.life, self.origMHP, self.origHP = ...;
      end,
      onInit = function(...)
        self.handle, self.life = ...;
        self.origMHP = GetMaxHealth(self.handle);
        self.origHP = GetCurHealth(self.handle);
        SetMaxHealth(self.handle,0);
      end,
      onDestroy = function()
        SetMaxHealth(self.handle,self.origMHP);
        SetCurHealth(self.handle,self.origHP);
      end,
      update = function(dtime)
        self.life = self.life - dtime;
        if(not IsValid(self.handle)) then
          self.life = 0;
        end
      end
    }
  })
);

bzRoutine.routineManager:registerClass(InfHPRoutine);

local ObjectCrate = Decorate(
  Implements(BzDestroy),
  GameObject({
    customClass = "objectCrate"
  }),
  Class("ObjectCrate", {
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.spawnObject = self.handle:getProperty("ObjectCrateClass","object","apammo");
      self.transform = self.handle:getTransform();
    end,
    methods = {
      update = function(dtime)
        local newT = self.handle:getTransform();
        if(newT ~= nil) then
          self.transform = newT;
        end
      end,
      onInit = function()
      end,
      onDestroy = function()
        self.h = BuildObject(self.spawnObject,self.handle:getTeamNum(),self.transform);
        bzRoutine.routineManager:startRoutine("InfHPRoutine",self.h,6);
      end,
      save = function()
      end,
      load = function(...)
      end
    }
  })
);

bzObjects.objectManager:declearClass(ObjectCrate);
