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

local RoutineInterface = Interface("RoutineInterface",{"isAlive"});


local function Routine(data)
  return function(class)
    Meta(class, {
      routine = {
        name = data.name,
        delay = 0 or data.delay
      }
    });
    D(Implements(Serializable, Updateable, BzInit,RoutineInterface), class);
  end
end



local RoutineManager = D(
  BzModule("RoutineManagerModule"),
  Class("RoutineManager",{
    constructor = function()
      self.store = {
        all = setmetatable({},{__mode="v"}),
        afterSaveListeners = setmetatable({},{__mode="v"}),
        afterLoadListeners = setmetatable({},{__mode="v"}),
        netListeners = setmetatable({},{__mode="v"}),
        objectListeners = setmetatable({},{__mode="v"}),
        playerListeners = setmetatable({},{__mode="v"}),
        commandListeners = setmetatable({},{__mode="v"}),
        keyListeners = setmetatable({},{__mode="v"}),
        startListeners = setmetatable({},{__mode="v"}),
        classes = setmetatable({},{__mode="v"}),
        imap = {}
      };
      self.nextId = 1;
      super(self.store);
    end,
    methods = {
      update = function(dtime)
        for i,v in pairs(self.store.all) do
          local m = Meta(v).routine
          if(m.running and v:isAlive()) then
            m.acc = m.acc + dtime;
            if(m.acc >= m.delay) then
              v:update(m.acc);
              m.acc = 0;
            end
          elseif(not v:isAlive()) then
            self:killRoutine(v);
          end
        end
      end,
      registerClass = function(class)
        assert(Meta(class).routine,"Class is not a routine");
        self.store.classes[Meta(class).routine.name] = class;
      end,
      registerInstance = function(i,id)
        self.store.imap[id] = i;
        super:registerInstance(i);
        return id;
      end,
      startRoutine = function(name,...)
        --Return routine ID      ¨
        assert(self.store.classes[name],"No routine named " .. tostring(name));
        local i = self.store.classes[name]:new();
        local id = ("%s_%d"):format(name,self.nextId);
        self.nextId = self.nextId + 1;
        
        self:registerInstance(i,id);
        
        Meta(i,{
          routine={
            id=id,
            acc=0,
            delay=Meta(self.store.classes[name]).routine.delay,
            running = true
          }
        });
        i:onInit(...);
        return id, i;
      end,
      getRoutine = function(routineId)
        return self.store.imap[routineId];
      end,
      pauseRoutine = function(routineId)
        Meta(self:getRoutine(routineId)).routine.running = false;
        --return self:getRoutine(routineId):stop();
      end,
      resumeRoutine = function(routineId)
        Meta(self:getRoutine(routineId)).routine.running = true;
      end,
      killRoutine = function(routineId)
        self.store.imap[routineId] = nil;
      end,
      save = function()
        local objdata = {};
        for i,v in pairs(self.store.all) do
          table.insert(objdata,{
            data = {v:save()},
            class = getClassRef(v),
            meta = Meta(v).routine
          });
        end
        return {objects = objdata, nextId = self.nextId};
      end,
      load = function(saveData)
        self.nextId = saveData.nextId;
        local objdata = saveData.objects;
        for i,v in pairs(objdata) do
          local c = getClass(v.class);
          local i = c:new();
          i:load(unpack(v.data));
          local m = v.meta;
          Meta(i,{
            routine={
              id=m.id,
              acc=m.acc,
              delay=Meta(c).routine.delay,
              running = m.running
            }
          });
          self:registerInstance(i,m.id);
        end
      end
    }
  },DefaultRuntimeModule)
);

local routineManager = bzCore:addModule(RoutineManager);

return {
  Routine = Routine,
  routineManager = routineManager
};