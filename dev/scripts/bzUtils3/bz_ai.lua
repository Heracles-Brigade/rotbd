local bzCore = require("bz_core");
local misc = require("misc");
local OOP = require("oop");

local bzObjects = require("bz_objects");

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
local DefaultRuntimeModule = misc.DefaultRuntimeModule;

local BzModule = misc.BzModule

local AiInterface = Interface("AiInterface",{--[["onReset","onNextCommand","onNextWho","onNextTarget","onMessage"]]});

--TODO: make MP safe
local AiDecorator = function(data)
  return function(class)
    Meta(class,{
      AI = assignObject({
        name = "NONE",
        aiNames = {}, --WEEK  
        cName = {}, --WEEK
        classLabels = {}, --WEEK
        factions = {}, --STRONG: AI will only be active for given faction
        --interface = {}, --List of methods that can be called by the AI planner
        playerTeam = false --STRONG --Player will not have AI activated by default
      },data)
    });
    Decorate(Implements(AiInterface,BzInit,Updateable,Serializable),class);
  end
end

local AiManager = Decorate(
  BzModule("AiManagerModule"),
  Class("AiManagerModule",{
    constructor = function()
      self.all = {};
      self.byClass = {};
      self.classes = {};
    end,
    methods = {
      update = function(...)
        for i,v in pairs(self.all) do
          for i2, v2 in pairs(v) do
            v2:update(...);
          end
        end
      end,
      onStart = function(...)
      end,
      save = function()
        local objdata = {};
        local cdata = {};
        for i, v in pairs(self.classes) do
          if(v.save) then
            cdata[v:getName()] = table.pack(v:save());
          end
        end
        for i, v in pairs(self.all) do
          objdata[i] = {};
          for i2, v2 in pairs(v) do
            objdata[i][getClassRef(v2)] = table.pack(v2:save());
          end
        end
        return {objects = objdata,cdata=cdata};
      end,
      load = function(saveData)
        local objdata = saveData.objects;
        local cdata = saveData.cdata;
        for i, v in pairs(cdata) do
          for i2, v2 in pairs(self.classes) do
            if(v2.load) then
              if(v2:getName() == i) then
                v2:load(unpack(v or {}));
              end
            end
          end
        end
        --Use register handle?
        for h, v in pairs(objdata) do
          local objs = self:checkHandle(h);
          for i2, v2 in pairs(v) do
            if(objs[i2]) then
              objs[i2]:load(unpack(v2));
            end
          end
        end
        for h in AllObjects() do
          self:checkHandle(h);
        end
      end,
      getUnitsByClass = function(cls)
        return self.byClass[cls:getName()];
      end,
      afterSave = function()
      end,
      afterLoad = function() 
      end,
      onGameKey = function(...)
      end,
      onCommand = function(...)
      end,
      onAddPlayer = function(...)
      end,
      onDeletePlayer = function(...)
      end,
      onCreatePlayer = function(...)
      end,
      onCreateObject = function(handle,...)
        if(not IsRemote(handle)) then
          self:checkHandle(handle);
        end
        for i, v in pairs(self.all) do
          for i2, v2 in pairs(v) do
            --if((not Meta(v2).suspended) and v2.onCreateObject) then
            v2:onCreateObject(handle)
            --end
          end
        end
      end,
      onAddObject = function(handle,...)
        self:checkHandle(handle);
        for i, v in pairs(self.all) do
          for i2, v2 in pairs(v) do
            --if((not Meta(v2).suspended) and v2.onAddObject) then
            v2:onAddObject(handle)
            --end
          end
        end
      end,
      onDeleteObject = function(handle,...)
        if(self.all[handle]) then
          for i,v in pairs(self.all[handle]) do
            v:onReset();
          end
        end
        self.all[handle] = nil;
        for i, v in pairs(self.all) do
          for i2, v2 in pairs(v) do
            --if((not Meta(v2).suspended) and v2.onDeleteObject) then
            v2:onDeleteObject(handle)
            --end
          end
        end
      end,
      onReceive = function(...)
      end,
      checkHandle = function(handle)
        local t = GetTeamNum(handle);
        local pt = GetTeamNum(GetPlayerHandle());
        local objs = {};
        if(self.all[handle]) then
          for i, v in pairs(self.all[handle]) do
            if(Meta(v).suspended and (pt ~= t) ) then
              Meta(v,{
                suspended = false
              });
              v:onInit();
            elseif((not Meta(v).suspended) and (pt == t)) then
              if(not Meta(v).playerTeam) then
                Meta(v,{
                  suspended = true
                });
                v:onReset();
              end
            end
          end
        else
          local h = bzObjects.Handle(handle);
          local odf = h:getOdf();
          local classLabel = h:getClassLabel(handle);
          local faction = h:getNation(handle);
          local ais = h:getProperty("GameObjectClass","aiName");
          for i, v in pairs(self.classes) do
            local objectMeta = Meta(v).AI;
            local m = isIn(classLabel, objectMeta.classLabels or {})
              or isIn(faction, objectMeta.factions or {})
              or isIn(ais, objectMeta.aiNames or {});
            
            if (m) then
              local aiC = v:new(handle);
              self.all[handle] = self.all[handle] or {};
              self.byClass[v:getName()][handle] = aiC;
              table.insert(self.all[handle],aiC);
              local s = not (objectMeta.playerTeam or t~=pt);
              Meta(aiC,{
                suspended = s,
                playerTeam = objectMeta.playerTeam
              });
              if(not s) then
                aiC:onInit();
              end
              objs[getClassRef(aiC)] = aiC;
            end
          end
          return objs;
        end
      end,
      declearClass = function(obj)
        table.insert(self.classes, obj);
        self.byClass[obj:getName()] = setmetatable({},{__mode="v"});
      end
    }
  })
);
local aiManager = bzCore:addModule(AiManager);

return {
  aiManager = aiManager,
  AiDecorator = AiDecorator
};