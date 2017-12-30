
local OOP = require("oop");
local misc = require("misc");
local bzObjects = require("bz_objects");

local GameObject = bzObjects.GameObject;

local KeyListener = misc.KeyListener;
local MpSyncable = misc.MpSyncable;

local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local KeyListener = misc.KeyListener;
local BzDestroy = misc.BzDestroy;
local Class = OOP.Class;


--TODO: mp not currently working 
local ExtraWeapons = Decorate(
  --BzDestroy requires: 'onDestroy' to be present in methods
  --GameObject requires: 'onInit', 'update', 'save' and 'load' load to be present
  Implements(BzDestroy),
  --[[
  GameObject adds metadata to our class, is required for objectManager to know
  what objects this class will be attached to
  possible properties:
  'customClass': string (name of ONE customClass this class will be attached to)
  'odfs': table of strings (name of all odfs this class will be attached to)
  'classLabels': table of strings (name of all classLabels this class will be attached to)
  ]]
  GameObject({
   --only one custom class permited
    customClass = "assaultWeapons"
  }),
  Class("AssaultWeapons", {
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.mask = self.handle:getProperty("GameObjectClass","mask")
      self.pweps = {};
      for i=0,4 do
        self.pweps[i] = self.handle:getWeaponClass(i);
      end
    end,
    methods = {
      update = function(dtime)
        for i=0,4 do
          local n = self.handle:getWeaponClass(i);
          if(n ~= self.pweps[i]) then
            self:onWeaponChange(i,self.pweps[i],n);
          end
          self.pweps[i] = n;
        end
      end,
      onWeaponChange = function(slot,old,new)
      end,
      onInit = function()
      end,
      onDestroy = function()
      end,
      save = function()
      end,
      load = function(...)
      end
    }
  })
);
--Add our class to the objectManager, class must be decorated
--with GameObject: Decorate(GameObject(...), class) for this to work
bzObjects.objectManager:declearClass(AssaultWeapons);
