local OOP = require("oop");
local bzUtils = require("bz_core");
local bzRoutine = require("bz_routine");
local misc = require("misc");

local KeyListener = misc.KeyListener;
local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local KeyListener = misc.KeyListener;
local Class = OOP.Class;
local Routine = bzRoutine.Routine;


local spectateRoutine = Decorate(
  --We need to listne to players
  Implements(KeyListener),
  Routine({
    name = "spectateRoutine",
    delay = 0.0
  }),
  Class("spectateRoutine",{
    constructor = function()
      self.sp_targets = nil;
      self.alive = true;
      self.cam = false;
    end,
    methods = {
      onInit = function(...)
        local ts, key = ...;
        self.sp_targets = ts;
        self.key_list = {};
        self.key_i = 1;
        for i, v in pairs(self.sp_targets) do
          table.insert(self.key_list,i);
          if(i == key) then
            self.key_i = #self.key_list;
          end
        end
        if(#self.key_list > 0) then
          print("Spectating started");
        else
          self:stop();
        end
      end,
      watchNext = function()
        if(#self.key_list <= 0) then
          return false;
        end
        self.key_i = (self.key_i%#self.key_list) + 1;
        return true;
      end,
      update = function(dtime)
        if(self.cam) then
          if(CameraCancelled()) then
            self:stop();
            return;
          end
          local h = self.sp_targets[self.key_list[self.key_i]];
          if(IsValid(h)) then
            --TODO: add smoothing
            CameraObject(h,0,1000,-3000,h);
          else
            self.sp_targets[self.key_list[self.key_i]] = nil;
            table.remove(self.key_list,key_i);
            if not self:watchNext() then
              self:stop();
            end
          end
        elseif(IsValid(GetPlayerHandle())) then
          self.cam = CameraReady();
        end
      end,
      isAlive = function()
        return self.alive;
      end,
      save = function()
      end,
      load = function()
      end,
      stop = function()
        print("STOP!");
        self.alive = false;
      end,
      removeHandle = function(handle)
      
      end,
      onDestroy = function()
        print("Spectating stoped");
        CameraFinish();
      end,
      onGameKey = function(key)
        if(key == "Tab") then
          self:watchNext();
        end
      end
    }
  })
);



bzRoutine.routineManager:registerClass(spectateRoutine);