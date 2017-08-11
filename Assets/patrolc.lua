local OOP = require("oop");
local misc = require("misc");
local bzRoutine = require("bz_routine");

local Routine = bzRoutine.Routine;

local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local Class = OOP.Class;
local Serializable = misc.Serializable;
local Updateable = misc.Serializable;
local StartListener = misc.StartListener;
local ObjectListener = misc.ObjectListener;
local BzInit = misc.BzInit;


local PatrolController = Decorate(
  Implements(ObjectListener),
  Routine({
    name = "PatrolRoutine",
    delay = 1
  }),
  Class("PatrolController",{
    constructor = function()
      self.path_map = {};
      self.patrol_units = {};
      self.locations = {};
    end,
    methods = {
      onDeleteObject = function(handle)
        self:removeHandle(handle);
      end,
      isAlive = function()
        return true;
      end,
      registerLocation = function(locationName)
        self.path_map[locationName] = {};
        table.insert(self.locations,locationName);
      end,
      registerLocations = function(locations)
        for i,v in pairs(locations) do
          self:registerLocation(v);
        end
      end,
      _connectPaths = function(startpoint,path,endpoint)
        table.insert(self.path_map[startpoint],{path=path,location=endpoint});
      end,
      defineRouts = function(location,routs)
        for i,v in pairs(routs) do
          self:_connectPaths(location,i,v);
        end
      end,
      getRandomRoute = function(location)
        if(#self.path_map[location] < 2) then
          return self.path_map[location][1];
        end
        local random = math.random(1,#self.path_map[location]);
        return self.path_map[location][random];
      end,
      giveRoute = function(handle)
        local o = self.patrol_units[handle];
        local pair = self:getRandomRoute(o.location);
        local c = 0;
        while( (pair~=nil) and ((pair.location == o.oldLocation) and #self.path_map[o.location] > 1)) do
          pair = self:getRandomRoute(o.location);
          c = c + 1;
          if(c > 10) then
            break;
          end
        end
        if(pair) then
          o.oldLocation = o.location;
          o.location = pair.location;
          o.timeout = 5;
          Goto(handle,pair.path);
        end
      end,
      addHandle = function(handle)
        local nearestLocation = nil;
        local location = nil;
        local pos = GetPosition(handle);
        for i,v in pairs(self.locations) do
          local p = GetPosition(v);
          if( (nearestLocation == nil) or (Length(p - pos) < Length(pos - nearestLocation) )) then
            nearestLocation = p;
            location = v;
          end
        end
        self.patrol_units[handle] = {
          handle = handle,
          location = location,
          oldLocation = nil,
          timeout = 1
        };
        self:giveRoute(handle);
      end,
      getHandles = function()
        return self.patrol_units;
      end,
      removeHandle = function(handle)
        self.patrol_units[handle] = nil;
      end,
      save = function()
        return self.patrol_units, self.locations, self.path_map;
      end,
      load = function(...)
        self.patrol_units, self.location, self.path_map = ...;
      end,
      update = function(dtime)
        --Check all units, if they are not doing anything check their location,
        --and give them a path to follow
        for i,v in pairs(self.patrol_units) do
          v.timeout = v.timeout - dtime;
          if(v.timeout <= 0) then
            if(GetCurrentCommand(i) == AiCommand["NONE"]) then
              self:giveRoute(i);
            end
          end
        end
      end,
      onInit = function(handles)
        for i,v in pairs(handles or {}) do
          self:addHandle(v);
        end
      end,
      onAddObject = function()
        --Do nothing
      end,
      onCreateObject = function()
        --Do nothing
      end,
      onDestroy = function()

      end
    }
  })
);

bzRoutine.routineManager:registerClass(PatrolController);

return PatrolController;