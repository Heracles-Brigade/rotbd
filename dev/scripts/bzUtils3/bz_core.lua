local OOP = require("oop");
local misc = require("misc");

local Class = OOP.Class;
local D = OOP.Decorate;
local Meta = OOP.Meta;
local Implements = OOP.Implements;
local BzModule = misc.BzModule;

local Serializable = misc.Serializable;
local Updateable = misc.Updateable;
local ObjectListener = misc.ObjectListener;
local PlayerListener = misc.PlayerListener;
local CommandListener = misc.CommandListener;
local NetworkListener = misc.NetworkListener;



local BzCoreModule = D(BzModule("BzCoreModule"),
  Class("BzCore", {
    constructor = function()
      self.modules = {};
    end,
    methods = {
      update = function(...)
        for i, v in pairs(self.modules) do
          v:update(...);
        end
      end,
      onStart = function(...)
        if(IsBzr()) then
          for v in AllCraft() do
            AddObject(v);
          end
        end
        for i, v in pairs(self.modules) do
          print(i, v);
          v:onStart(...);
        end
      end,
      save = function()
        local saveData = {modules = {}};
        for i, v in pairs(self.modules) do
          local data = {v:save()};
          local class = v:class();
          saveData.modules[i] = {
            data = data,
            classref = OOP.getClassRef(v)
          };
        end
        return saveData;
      end,
      load = function(saveData)
        local modules = saveData.modules;
        for i, v in pairs(modules) do
          local class = OOP.getClass(v.classref);
          self.modules[Meta(class).BzModule.name]:load(unpack(v.data));
        end
      end,
      afterSave = function()
        for i, v in pairs(self.modules) do
          v:afterSave();
        end
      end,
      afterLoad = function()
        for i, v in pairs(self.modules) do
          v:afterLoad();
        end
      end,
      onGameKey = function(...)
        for i, v in pairs(self.modules) do
          v:onGameKey(...);
        end
      end,
      onCommand = function(...)
        local r = false;
        for i, v in pairs(self.modules) do
          r = v:onCommand(...) or r;
        end
        return r;
      end,
      onAddPlayer = function(...)
        for i, v in pairs(self.modules) do
          v:onAddPlayer(...);
        end
      end,
      onDeletePlayer = function(...)
        for i, v in pairs(self.modules) do
          v:onDeletePlayer(...);
        end
      end,
      onCreatePlayer = function(...)
        for i, v in pairs(self.modules) do
          v:onCreatePlayer(...);
        end
      end,
      onCreateObject = function(...)
        for i, v in pairs(self.modules) do
          v:onCreateObject(...);
        end
      end,
      onAddObject = function(...)
        for i, v in pairs(self.modules) do
          v:onAddObject(...);
        end
      end,
      onDeleteObject = function(...)
        for i, v in pairs(self.modules) do
          v:onDeleteObject(...);
        end
      end,
      onReceive = function(...)
        for i, v in pairs(self.modules) do
          v:onReceive(...);
        end
      end,
      addModule = function(m)
        assert(Meta(m).BzModule, "Argument passed does not seem to be a module!");
        local i = m:new();
        self.modules[Meta(m).BzModule.name] = i;
        return i;
      end
    }
  })
);

local bzCore = BzCoreModule();
--[[
local bzCore = {
modules = core
};
]]
return bzCore;
