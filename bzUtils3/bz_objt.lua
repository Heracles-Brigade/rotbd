local bzCore = require("bz_core");
local misc = require("misc");
local OOP = require("oop");

local Class = OOP.Class;
local D = OOP.Decorate;
local Meta = OOP.Meta;
local getClassRef = OOP.getClassRef;
local getClass = OOP.getClass;
local copyTable = OOP.copyTable;
local assignObject = OOP.assignObject;
local isIn = OOP.isIn;
local SetLabel = SetLabel;
local Implements = OOP.Implements;
local Interface = OOP.Interface;
local odfFile = misc.odfFile;

local Serializable = misc.Serializable;
local Updateable = misc.Updateable;
local ObjectListener = misc.ObjectListener;
local PlayerListener = misc.PlayerListener;
local CommandListener = misc.CommandListener;
local NetworkListener = misc.NetworkListener;
local StartListener = misc.StartListener;
local KeyListener = misc.KeyListener;
local BzInit = misc.BzInit;
local BzDestroy = misc.BzDestroy;
local BzRemove = misc.BzRemove;
local MpSyncable = misc.MpSyncable;
local BzAlive = misc.BzAlive;
local DefaultRuntimeModule = misc.DefaultRuntimeModule;

local BzModule = misc.BzModule

local ObjectiveInterface = Interface("ObjectiveInterface",{"succeed","fail"});

local ObjectiveDecorator = function(d)
  return function(class)
    Meta(class,{
      objective = {
        name = d.name
      }
    });
    D(Implements(ObjectiveInterface,BzInit,Updateable,Serializable),class);
  end
end

local BaseObjective = D(
  Implements(ObjectiveInterface,BzInit,Updateable,Serializable),
  Class("BaseObjective",{
    constructor = function()
      self.alive = true;
      self.started = false;
    end,
    methods = {
      save = function()
        return self.alive,self.started;
      end,
      load = function(...)
        self.alive,self.started = ...;
      end,
      update = function(dtime)
      end,
      isAlive = function()
        return self.alive;
      end,
      onInit = function()
        self.started = true;
      end,
      finish = function()
        self.alive = false;
      end,
      succeed = function()
        self:finish();
      end,
      fail = function()
        self:finish();
      end
    }
  })
);

local ObjectiveManager = D(
  BzModule("ObjectiveManagerModule"),
  Class("ObjectiveManager",{
    constructor = function()
      self.store = {
        all = {},
        afterSaveListeners = {},
        afterLoadListeners = {},
        netListeners = {},
        objectListeners = {},
        playerListeners = {},
        commandListeners = {},
        keyListeners = {},
        startListeners = {},
        classes = {}
      };
      super(self.store);
    end,
    methods = {
      registerClass = function(class)
        assert(Meta(class).objective,"Class is not an objective");
        self.store.classes[Meta(class).objective.name] = class;
      end,
      startObjective = function(objectiveName)
        assert(self.store.classes[objectiveName],"No objective named " .. tostring(objectiveName));
        local i = self.store.classes[objectiveName]:new();
        super:registerInstance(i);
        i:onInit();
      end
    }
  },DefaultRuntimeModule)
);

local objectiveManager = bzCore:addModule(ObjectiveManager);

return {
    ObjectiveDecorator = ObjectiveDecorator,
    ObjectiveInterface = ObjectiveInterface,
    objectiveManager = objectiveManager,
    BaseObjective = BaseObjective
};