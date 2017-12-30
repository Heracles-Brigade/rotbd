
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
  Implements(KeyListener, MpSyncable),
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
  Class("ExtraWeapons", {
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.wepPages = {};
      self.page = 1;
      self.key = "K";
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
        --Called when a key is pressed
        if ( (key == self.key) and (self.handle:getHandle() == GetPlayerHandle()) ) then
          self:setWeaponPage(((self.page) % #self.wepPages) + 1);
        end
      end,
      --MP code, maybe pass some info about new owner?
      --Called for the machine losing the object
      mpLoseObject = function(socket)
        local p1 = socket:packet();
        self:setWeaponPage(self.page);
        --Queue the objects 'save' data in a packet
        p1:queue(self:save());
        --Send packet
        socket:flush(p1);
      end,
      --Method for handling syncing
      sync_recieve = function(from,...)
        self:load(...);
        self:setWeaponPage(self.page,true);
      end,
      --Called for the machine gaining the object
      mpGainObject = function(socket)
        --Subscribe to packets coming from the socket
        socket:getPackets():subscribe(function(...)
          --Call sync handler
          self:sync_recieve(...);
        end);
      end
    }
  })
);
--Add our class to the objectManager, class must be decorated
--with GameObject: Decorate(GameObject(...), class) for this to work
bzObjects.objectManager:declearClass(ExtraWeapons);
