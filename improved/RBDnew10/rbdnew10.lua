
require("bz_logging");
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

local mission = require("cmisnlib");
local rx = require("rx");
local core = require("bz_core");

local tugStackSpawner = Decorate(
  Routine({
    name = "tugStackSpawner",
    delay = 0
  }),
  Class("tugStackSpawner",{
    constructor = function()
      self.current_size = 0;
      self.completeSubject = rx.Subject.create();
      self.alive = true;
    end,
    methods = {
      isAlive = function()
        return self.alive;
      --  return self.current_size >= self.stack_size;
      end,
      save = function()
        return self.odf, self.location, self.team, self.current_size, self.stack_size, self.c_handle;
      end,
      load = function(...)
        self.odf, self.location, self.team, self.current_size, self.stack_size, self.c_handle = ...;
      end,
      update = function(dtime)
        if(not (IsValid(self.c_handle)) or HasCargo(self.c_handle) ) then
          if(self.current_size < self.stack_size) then
            self.current_size = self.current_size + 1;
            self.c_target = self.c_handle;
            if(not IsValid(self.c_target)) then
              self.c_target = BuildObject(self.odf,self.team,self.location);
            end
            RemovePilot(self.c_target);
            SetPosition(self.c_target,location);
            self.c_handle = BuildObject(self.odf,self.team,self.location);
            Deploy(self.c_handle);
          else
            SetPosition(self.c_handle,self.location);
            self.completeSubject:onNext(self.c_handle);
            self.alive = false;
          end
        end
      end,
      onSpawned = function()
        return self.completeSubject;
      end,
      onInit = function(odf,team,location,stack_size)
        self.odf = odf;
        self.stack_size = stack_size;
        self.location = location;
        self.team = team;
      end,
      onDestroy = function()

      end
    }
  })
);

bzRoutine.routineManager:registerClass(tugStackSpawner);


--[[
TODO:
- Land, fight some enemies
- Take command of base, build defenses
- Order Cons to  nav, he starts building
- Attack wavs get stronger
- Factory shows up, builds Mammoths
- Attack waves vanish
- Launch Pad finishes, Factory builds transports
- Furies show up
- Shaw abandoned us, we surrender

]]

local audio = {
  intro = "rbd1001.wav",
  furies = "rbd1002.wav",
  evacuate = "rbd1003.wav",
  shaw = "rbd1004.wav"
};


local getToBase = mission.Objective:define("getToBase"):setListeners({
  start = function(self)
    --Spawn two fighters attacking each silo in sequence
    for i, v in ipairs(mission.spawnInFormation2({"1 1"},"east_wave",{"avfigh"},2)) do
      local s = mission.TaskManager:sequencer(v);
      for i2=1, 3 do
        s:queue2("Attack",GetHandle(("silo%d"):format(i2)));
      end
    end
  end,
  update = function(self)
    local pp = GetPathPoints("bdog_base");
    pp[1].y = 0;
    pp[2].y = 0;
    if(GetDistance(GetPlayerHandle(),pp[1]) < Length(pp[2]-pp[1])) then
      self:success();
    end
  end,
  success = function(self)
    local mission_obj = mission.Objective:Start("mission");
  end
});

local mission_obj = mission.Objective:define("mission"):createTasks(
  "order_to_build", "build_lpad", "waves1", "waves2"
):setListeners({
  init = function(self)
  end,
  start = function(self)
    AudioMessage(audio.intro);
    AddObjective("rbd1001.otf");
    self:startTask("order_to_build");
    self:startTask("waves1");
    self.building = false;
  end,
  task_start = function(self,name)
    if(name == "build_lpad") then
      AddObjective("rbd1002.otf");
      local btime = misc.odfFile("ablpadx"):getFloat("GameObjectClass","buildTime");
      StartCockpitTimer(btime);
    end
  end,
  task_success = function(self,name)
    if(name == "order_to_build") then
      self:startTask("waves2");
      self:startTask("build_lpad");
      RemoveObjective("rbd1001.otf");
    end
    if(self:hasTasksSucceeded("build_lpad","waves2","waves1","order_to_build")) then
      self:success();
    end
  end,
  task_fail = function(self,name)
    self:fail();
  end,
  update = function(self,dtime)
    local const = GetConstructorHandle();
    
    if(self:isTaskActive("order_to_build")) then
      local d1 = GetPosition("launchpad");
      local ctask = GetCurrentCommand(const);
      if(GetDistance(const,"launchpad") < 100 and ctask == AiCommand["NONE"]) then
        local pp = GetPathPoints("launchpad");
        local t = BuildDirectionalMatrix(pp[1],pp[2]-pp[1]);
        self.building = true;
        self.const = const;
        BuildAt(self.const,"ablpadx",t);
      end
      if(self.building and IsDeployed(self.const)) then
        self:taskSucceed("order_to_build");
      elseif(self.building and (not IsAlive(self.const))) then
        self:taskFail("order_to_build");
      end
    end
    if(self:isTaskActive("build_lpad")) then
      if(not IsValid(const)) then
        self:taskFail("build_lpad");
      end
    end
  end,
  save = function(self)
    return self.building, self.const;
  end,
  load = function(self,...)
    self.building, self.const = ...;
  end
});

function Start()
  core:onStart();
  getToBase:start();
  local n1 = GetHandle("nav1");
  local n2 = GetHandle("nav2");
  SetObjectiveName(n1, "Black Dog Outpost");
  SetObjectiveName(n2, "Launchpad build site");
end

function Update(dtime)
  core:update(dtime);
  mission:Update(dtime);
end

function CreateObject(handle)
  core:onCreateObject(handle);
  mission:CreateObject(handle);
end

function AddObject(handle)
  core:onAddObject(handle);
  mission:AddObject(handle);
end

function DeleteObject(handle)
  core:onDeleteObject(handle);
  mission:DeleteObject(handle);
end

function Save()
  return mission:Save(),{core:save()};
end

function Load(missison_date,cdata)
  core:load(unpack(cdata));
  mission:Load(missison_date);
end

--[[ Lets find a good target?
function FindAITarget()
  -- Pick a target. Attack silos or base.
  if math.random(1, 2) == 1 then
    if IsAlive(M.Silo1) then
      return M.Silo1;
    elseif IsAlive(Silo2) then
      return M.Silo2;
    elseif IsAlive(M.Silo3) then
      return M.Silo3;
    end
  else
    if IsAlive(M.CommTower) then
      return M.CommTower;
    elseif IsAlive(M.Recycler) then
      return M.Recycler;
    elseif IsAlive(M.Constructor) then
      return M.Constructor;
    end
  end
end
]]