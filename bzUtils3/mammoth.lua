
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
  --KeyListener requires: 'onGameKey' to be present in methods
  --BzDestroy requires: 'onDestroy' to be present in methods
  --GameObject requires: 'onInit', 'update', 'save' and 'load' load to be present
  Implements(KeyListener, BzDestroy, MpSyncable),
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
    customClass = "extraWeapons"
  }),
  --The class definition
  --Class takes three arguments: (class name, class definition, [super class])
  Class("EW", {
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.wepPages = {};
      self.page = 1;
      self.dead = false;
      self.lastPosition = self.handle:getPosition();
      local nextPage = self.handle:getTable("GameObjectClass", "weaponName");
      local page = 0;
      local pleft = self.handle:getInt("GameObjectClass","extraPages",10);
      while (#nextPage > 0 and pleft >= 0) do
        local p = {};
        for i, v in ipairs(nextPage) do
          table.insert(p, {
            s = i - 1,
            w = v
          });
        end
        table.insert(self.wepPages, p);
        page = page + 1;
        nextPage = self.handle:getTable("ExtraWeapons_" .. page, "weaponName");
        pleft = pleft - 1;
      end
    end,
    methods = {
      update = function(dtime)
        if (self.handle:getPosition().x ~= 0) then
          self.lastPosition = self.handle:getPosition();
        end
      end,
      onInit = function()
      --Called when object is added to the world
      end,
      onDestroy = function()
      --Spawn a nuke for some reason,
      --Called ONCE when HP > 0
      --Does not mean the object is removed from the world
      --BuildObject("apwrck",self.handle:getTeamNum(),self.lastPosition + SetVector(0,50,0));
      end,
      save = function()
        --Return data you want to save for the object
        return self.page, self.wepPages;
      end,
      load = function(...)
        --Assign variables from save data
        self.page, self.wepPages = ...;
      end,
      setWeaponPage = function(page, w)
        if (not w) then
          local ppage = self.wepPages[self.page];
          for i, v in pairs(ppage) do
            ppage[i] = {
              w = self.handle:getWeaponClass(v.s),
              s = v.s
            };
          end
        end
        self.page = page;
        local cpage = self.wepPages[self.page];
        for i, v in pairs(cpage) do
          self.handle:giveWeapon(v.w, v.s);
        end
      end,
      onGameKey = function(key)
        print(key);
        --Called when a key is pressed
        if (key == "K" and self.handle:getHandle() == GetPlayerHandle()) then
          self:setWeaponPage(((self.page) % #self.wepPages) + 1);
        end
      end,
      --MP code, maybe pass some info about new owner?
      onMachineChange = function()
        print("No longer on this machine!");
        print("Instance should be dead after this");
      end,
      mpSyncSend = function()
        local d = {self.page,#self.wepPages,unpack(self.wepPages)};
        local l = #d;
        local weps = {};
        for i=0,4 do
          d[i+l+1] = self.handle:getWeaponClass(i);
        end
        --return {self:save()}, unpack(weps);]]
        
        return unpack(d);
      end,
      mpSyncReceive = function(...)
        local data = {...};
        print("Data received",...);
        self.page = data[0];
        local pcount = data[1];
        local di = 2;
        for i=1,pcount do
          self.wepPages[i] = data[di];
          di = di + 1;
        end
        for i=0, 4 do
          self.handle:giveWeapon(data[di],i);
          di = di + 1;
        end
      end
    }
  })
);
--Add our class to the objectManager, class must be decorated
--with GameObject: Decorate(GameObject(...), class) for this to work
bzObjects.objectManager:declearClass(ExtraWeapons);
