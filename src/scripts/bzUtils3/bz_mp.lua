local bzCore = require("bz_core");
local misc = require("misc");
local OOP = require("oop");
local bzObjects = require("bz_objects");
local Rx = require("rx");


local Class = OOP.Class;
local Decorate = OOP.Decorate;
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
local StatTracker = bzObjects.StatTracker;
local MultiTracker = bzObjects.MultiTracker;

local BzModule = misc.BzModule




local CommandManager = Decorate(
  BzModule("CommandManagerModule"),
  Class("CommandManager",{
    constructor = function()
      self.commands = {};
    end,
    methods = {
      onCommand = function(command,...)
        if(self.commands[command]) then
          return self.commands[command](...);
        end
      end,
      registerCommand = function(prefix,handler)
        self.commands[prefix] = handler;--self.commands[prefix] or {};
      --  self.commands[prefix][pattern] = handler;
      end,
      getCommands = function()
        return self.commands;
      end,
      update = function(...)
      end,
      onStart = function(...)
      end,
      save = function()
      end,
      load = function()
      end,
      afterSave = function()
      end,
      afterLoad = function() 
      end,
      onGameKey = function(...)
      end,
      onAddPlayer = function(...)
      end,
      onDeletePlayer = function(...)
      end,
      onCreatePlayer = function(...)
      end,
      onCreateObject = function(handle,...)
      end,
      onAddObject = function(handle,...)
      end,
      onDeleteObject = function(...)
      end,
      onReceive = function(...)
      end,
      declearClass = function(class)
      end
    }
  })
);

local MpManager = Decorate(
  BzModule("MpManagerModule"),
  Class("MpManager",{
    constructor = function()
      self.sockets = {};
    end,
    methods = {
      onCommand = function(command,...)
      end,
      update = function(...)
      end,
      onStart = function(...)
      end,
      save = function()
      end,
      load = function()
      end,
      afterSave = function()
      end,
      afterLoad = function() 
      end,
      onGameKey = function(...)
      end,
      onAddPlayer = function(...)
      end,
      onDeletePlayer = function(...)
      end,
      onCreatePlayer = function(...)
      end,
      onCreateObject = function(handle,...)
      end,
      onAddObject = function(handle,...)
      end,
      onDeleteObject = function(...)
      end,
      onReceive = function(...)
        --Socket logic
      end
    }
  })
);



local commandManager = bzCore:addModule(CommandManager);


return {
  commandManager = commandManager,
};