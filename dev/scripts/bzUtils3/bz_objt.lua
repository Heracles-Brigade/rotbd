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

local ObjectiveInterface = Interface("ObjectiveInterface",{"isAlive","succeed","fail","finish"});

local TOP = -math.huge;
local BOTTOM = math.huge;

local allObjectives = {};
local nextId = 1;
local oldG = {
  AddObjective = _G["AddObjective"],
  RemoveObjective = _G["RemoveObjective"],
  UpdateObjective = _G["UpdateObjective"],
  ClearObjectives = _G["ClearObjectives"]
}

local cmpObj = function(a,b)
  return a.pos < b.pos;
end

local addObj = function(v)
  oldG.AddObjective(v.name,v.color,v.duration,v.optText);
end

local reorderObjectives = function()
  oldG.ClearObjectives();
  local stable = {};
  for i, v in pairs(allObjectives) do
    table.insert(stable,v);
  end
  table.sort(stable,cmpObj);
  for i, v in ipairs(stable) do
    addObj(v);
  end
end

_G["UpdateObjective"] = function(name,color,dur,opt,pos,persistant)
  if(allObjectives[name]) then
    local o = allObjectives[name];
    allObjectives[name] = {
      id = o.id,
      name = o.name,
      color = color,
      duration = dur,
      pos = pos ~= nil and pos or o.pos,
      optText = opt,
      persistant = persistant ~= nil and persistant or o.persistant
    }
    oldG.UpdateObjective(name,color,dur,opt);
    reorderObjectives();
  end
end

_G["ClearObjectives"] = function()
  nextId = 1;
  local p = {};
  for i,v in pairs(allObjectives) do
    if(v.persistant) then
      table.insert(p,v);
    end
  end
  allObjectives = p;
  reorderObjectives();
end

_G["AddObjective"] = function(name,color,dur,opt,pos,persistant)
  --Resort all objectives
  if(not allObjectives[name]) then
    allObjectives[name] = {
      id = nextId,
      name = name,
      color = color,
      duration = dur,
      pos = pos~=nil and pos or nextId,
      optText = opt,
      persistant = persistant
    };
    nextId = nextId + 1;
    reorderObjectives();
  end
end

_G["RemoveObjective"] = function(name)
  allObjectives[name] = nil;
  oldG.RemoveObjective(name);
end

_G["SetObjectivePosition"] = function(name,pos)
  if(allObjectives[name]) then
    allObjectives[name].pos = pos;
    reorderObjectives();
  end
end

_G["GetObjectivePosition"] = function(name)
  if(allObjectives[name]) then
    return allObjectives[name].pos;
  end
end

_G["ReplaceObjective"] = function(name,name2,...)
  local obj = allObjectives[name];
  RemoveObjective(name);
  local add_args = table.pack(...);
  if(obj) then
    obj_args = table.pack(
      obj.color,
      obj.duration,
      obj.optText,
      obj.pos,
      obj.persistant
    );
    AddObjective(name2,unpack(obj_args));
    UpdateObjective(name2,unpack(add_args));
  else
    AddObjective(name2,unpack(add_args));
  end
end

local FormatedObjective = Class("FormatedObjective",{
  constructor = function(name,color,text,speed,dummy)
    self.dummy = dummy;
    self.name = name;
    self.text = text or UseItem(name);
    self.dispText = self.text:gsub("%[%d+%]","");
    self.breakpoints = {};
    self.totalTime = 60 * self.dispText:len()/speed;
    local ctext = self.text;
    local s,e = ctext:find("%[%d+%]");
    while s~=nil do
      local t = ctext:match("%[(%d+)%]");
      table.insert(self.breakpoints,{
        index = s,
        delay = t
      });
      self.totalTime = self.totalTime + t/10;
      ctext = ctext:sub(1,s-1) .. ctext:sub(e+1,#ctext);
      s,e = ctext:find("%[%d+%]");
    end    
    print("Display text:",self.dispText);
    self.color = color;
    self.nextBreakpoint = 1;
    self.currentCooldown = 0;
    self.cooldown = false;
    self.speed = speed;
    self.started = false;
    self.alive = true;
    self.timer = 0;
    self.ctext = "";
  end,
  methods = {
    onInit = function()
      if(not self.dummy) then
        AddObjective(self.name,self.color,8,"");
      end
      self.started = true;
    end,
    update = function(dtime)
      if(self.started and self.alive) then
        local pindex = self:getIndex();
        local b = self.breakpoints[self.nextBreakpoint];
        if(not self.cooldown) then
          self.timer = self.timer + dtime;
          if(b and (pindex >= b.index)) then
            self.cooldown = true;
            self.currentCooldown = b.delay/10;
          end
        else
          if(b) then
            pindex = b.index - 1;
          end
          self.currentCooldown = self.currentCooldown - dtime;
          if(self.currentCooldown <= 0) then
            self.currentCooldown = 0;
            self.cooldown = false;
            self.nextBreakpoint = self.nextBreakpoint + 1;
          end
        end
        if(not self:isDone()) then
          if(not self.dummy) then
            UpdateObjective(self.name,self.color,1,self.dispText:sub(1,pindex));  
          end
          self.ctext = self.dispText:sub(1,pindex);
        end
      end
    end,
    save = function()
      return self.timer,self.alive,self.cooldown,self.currentCooldown,self.nextBreakpoint,self.started;
    end,
    getIndex = function()
      return (self.timer*self.speed)/60; --i = x*s/60 <=> x = i*60/s
    end,
    getText = function()
      return self.ctext;
    end,
    isDone = function()
      return self.timer >= self.totalTime;--(self:getIndex() > #self.dispText) and (not self.cooldown);
    end,
    load = function(...)
      self.timer,self.alive,self.cooldown,self.currentCooldown,self.nextBreakpoint,self.started = ...;
    end,
    remove = function()
      self.alive = false;
      RemoveObjective(self.name);
    end
  }
});



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
    constructor = function(otf)
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
      onInit = function(...)
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
      super(self.store);
    end,
    methods = {
      registerClass = function(class)
        assert(Meta(class).objective,"Class is not an objective");
        self.store.classes[Meta(class).objective.name] = class;
      end,
      startObjective = function(objectiveName,...)
        assert(self.store.classes[objectiveName],"No objective named " .. tostring(objectiveName));
        local i = self.store.classes[objectiveName]:new();
        self:registerInstance(i,objectiveName);
        i:onInit(...);
      end,
      registerInstance = function(i,objectiveName)
        self.store.imap[objectiveName] = self.store.imap[objectiveName] or {};
        table.insert(self.store.imap[objectiveName],i);
        super:registerInstance(i);
      end,
      save = function()
        return super:save(), allObjectives, nextId;
      end,
      load = function(saveData,fobjdata, nid)
        nextId = nid;
        allObjectives = fobjdata;
        local objdata = saveData.objects;
        for i,v in pairs(objdata) do
          local c = getClass(v.class);
          local i = c:new();
          i:load(unpack(v.data));
          self:registerInstance(i,Meta(c).objective.name);
        end
      end,
      terminateObjective = function(name)
        for i, v in pairs(self.store.imap[name]) do
          v:finish();
        end
        self.store.imap[name] = {};
      end,
      getInstnaces = function(name)
        return self.store.imap[name];
      end
    }
  },DefaultRuntimeModule)
);

local objectiveManager = bzCore:addModule(ObjectiveManager);

return {
  ObjectiveDecorator = ObjectiveDecorator,
  ObjectiveInterface = ObjectiveInterface,
  objectiveManager = objectiveManager,
  BaseObjective = BaseObjective,
  TOP = TOP,
  FormatedObjective = FormatedObjective,
  BOTTOM = BOTTOM
};