local OOP = require("oop");
local bzObjects = require("bz_objects");
local Class = OOP.Class;
local GameObject = bzObjects.GameObject;
local Handle = bzObjects.Handle;
local D = OOP.Decorate;


local RaceWasp = D(GameObject(
  {
    customClass = "rcwasp"
  }),
  Class("RaceWasp",{
    constructor = function(handle)
      self.handle = Handle(handle);
    end,
    methods = {
      update = function(dtime)
        self.handle:setTarget(self.handle:getNearestEnemy());
      end,
      save = function()
      end,
      load = function()
      end,
      onInit = function()
      end,
      onMessage = function()
      end
    }
  })
);

return function()
  bzObjects.objectManager:declearClass(RaceWasp);
end