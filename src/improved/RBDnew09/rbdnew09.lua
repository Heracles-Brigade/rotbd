local core = require("bz_core");
local OOP = require("oop");
local bzRoutine = require("bz_routine");

local misc = require("misc");

local IsIn = OOP.isIn;
local joinTables = OOP.joinTables;
local PatrolController = require("patrolc");
local mission = require('cmisnlib');
local bzObjects = require("bz_objects");
-- Allows us to re-order objectives
local _ = require("bz_objt");

local _ = require("objectCrate");

local pwers = {};
local _ = require("bz_logging");

local audio = {
  intro = "rbd0901.wav",
  found = "rbd0902.wav",
  clear = "rbd0903.wav",
  warn1 = "rbd0901W.wav",
  win = "rbd091wn.wav"
}


local fail_conditions = {
  apc = "rbd09l01.des"
}

local WaveSpawner = require("wavec").WaveSpawner;

function AddToPatrolTask(handle,p_id,sequencer)
  --Look for enemies
  local r = bzRoutine.routineManager:getRoutine(p_id);
  if(r) then
    r:addHandle(handle);
  end
end
--[[
  Notes:
    - Damage base when player arrives
    - MAYBE: let nsdf rebuild destroyed buildings
    - Some furies attack when the player has secured the site
]]

local sideObjectives = mission.Objective:define("sideObjectives"):createTasks(
  "destroy_comm", "capture_supply"
):setListeners({
  init = function(self)
    self.commtower = GetHandle("commtower");
    self.comm_timer = 60*4;
  end,
  start = function(self,patrol_units)
    self.units = patrol_units;
    self:startTask("capture_supply");
  end,
  update = function(self,dtime)
    if(self:isTaskActive("capture_supply")) then
      local secure = true;
      local pp = GetPathPoints("supply_site");
      local l = Length(pp[2]-pp[1])
      if(GetDistance(GetPlayerHandle(),pp[1]) < l) then
        for obj in ObjectsInRange(l,pp[1]) do
          if(IsCraft(obj) and GetTeamNum(obj) == 2) then
            secure = false;
            break;
          end
        end
        if(secure) then
          self:taskSucceed("capture_supply");
        end
      end
    end
    if(not self:hasTaskStarted("destroy_comm") and IsAlive(self.commtower)) then
      if(mission.areAnyDead(self.units)) then
        self:startTask("destroy_comm");
      end
    elseif(self:isTaskActive("destroy_comm")) then
      self.comm_timer = self.comm_timer - dtime;
      if(self.comm_timer <= 0) then
        self:taskFail("destroy_comm");
      elseif(not IsAlive(self.commtower)) then
        self:taskSucceed("destroy_comm");
      end
    end
  end,
  task_start = function(self,name)
    if(name == "destroy_comm") then
      AudioMessage(audio.warn1);
      AddObjective("rbd0905.otf");
      StartCockpitTimer(self.comm_timer,self.comm_timer*0.5,self.comm_timer*0.1);
      SetObjectiveOn(self.commtower);
    end
  end,
  task_success = function(self,name)
    if(name == "capture_supply") then
      local pp = GetPathPoints("supply_site");
      for obj in ObjectsInRange(Length(pp[2]-pp[1]),pp[1]) do
        if(IsBuilding(obj) and GetTeamNum(obj) == 2) then
          SetTeamNum(obj,1);
        end
      end
      AddObjective("rbd0904.otf","green");
    elseif(name == "destroy_comm") then
      UpdateObjective("rbd0905.otf","green");
      StopCockpitTimer();
      HideCockpitTimer();
    end
  end,
  task_fail = function(self,name)
    if(name == "destroy_comm") then
      ReplaceObjective("rbd0905.otf","rbd0906.otf","yellow");
      StopCockpitTimer();
      HideCockpitTimer();
      SetObjectiveOff(self.commtower);
    end
  end,
  _hasBeenDetected = function(self)
    if(self:isTaskActive("destroy_comm")) then
      self:taskFail("destroy_comm");
    else
      self:taskEnd("destroy_comm");
    end
    return self:hasTaskFailed("destroy_comm");
  end,
  save = function(self)
    return self.units, self.comm_timer;
  end,
  load = function(self,...)
    self.units, self.comm_timer = ...;
  end
});


local captureRelic = mission.Objective:define("captureRelic"):createTasks(
  "findRelic", "secureSite", "captureRecycler"
):setListeners({
  init = function(self)
    self.apc = GetHandle("apc");
    self.recy = GetHandle("recycler");
    self.check_interval = 50;
    self.cframe = 0;
    self.otfs = {
      findRelic = "rbd0901.otf",
      secureSite = "rbd0902.otf",
      captureRecycler = "rbd0902b.otf"
    }
  end,
  start = function(self,patrol_id,patrol_units)
    self.patrol_id = patrol_id;
    self.patrol_units = patrol_units;
    self:startTask("findRelic");
    AudioMessage(audio.intro);
  end,
  task_start = function(self,name)
    if(name == "captureRecycler") then
      ClearObjectives();
    end
    if(self.otfs[name] ~= nil) then
      AddObjective(self.otfs[name]);
    end
  end,
  task_fail = function(self,name)
    UpdateObjective(self.otfs[name],"red");
    self:fail();
  end,
  fail = function(self,what)
    FailMission(GetTime()+5.0,what ~= nil and fail_conditions[what]);
  end,
  task_success = function(self,name)
    UpdateObjective(self.otfs[name],"green");
    if(name == "findRelic") then
      AudioMessage(audio.found);
      SetTeamNum(self.recy,0);
      self:startTask("secureSite");
    elseif(name == "secureSite") then
      AudioMessage(audio.clear);
      local pp = GetPathPoints("relic_site");
      for obj in ObjectsInRange(Length(pp[2]-pp[1]),pp[1]) do
        if((GetClassLabel(obj) == "turret" or IsBuilding(obj)) and GetTeamNum(obj) == 2) then
          SetTeamNum(obj,1);
          Stop(obj);
          Defend(obj);
        end
      end
      self:startTask("captureRecycler");
    elseif(name == "captureRecycler") then
      SetTeamNum(self.recy,1);
      SetScrap(1,30);
      bzObjects.copyObject(self.apc,"bvapc");
      RemoveObject(self.apc);
      self:success();
    end  
  end,
  update = function(self,dtime)
    local ph = GetPlayerHandle();
    if(not IsAlive(self.apc)) then
      self:fail("apc");
    end
    if(self:isTaskActive("findRelic")) then
      if(GetDistance(ph,"relic_site") < 400) then
        self:taskSucceed("findRelic");
      end
    end
    if(self:isTaskActive("secureSite")) then
      self.cframe = self.cframe + 1; 
      if(self.cframe > 50) then
        self.cframe = 0;
        local secure = true;
        local tMap = {};
        local pp = GetPathPoints("relic_site");
        for obj in ObjectsInRange(Length(pp[2]-pp[1]),pp[1]) do
          local cp = GetClassLabel(obj);
          if(GetTeamNum(obj) == 2 and IsAlive(obj)) then
            tMap[cp] = true;
            other = ({turret="powerplant",powerplant="turret"})[cp];
            if other~=nil and tMap[other] then
              secure = false;
              break;
            elseif(other==nil and IsCraft(obj)) then
              secure = false;
              break;
            end
          end
        end
        if(secure) then
          self:taskSucceed("secureSite");
        end
      end
    end
    if(self:isTaskActive("captureRecycler")) then
      if(IsWithin(self.apc,self.recy,40)) then
        Stop(self.apc,0);
        self:taskSucceed("captureRecycler");
      end
    end
  end,
  save = function(self)
    return self.patrol_id, self.patrol_units;
  end,
  load = function(self,...)
    self.patrol_id, self.patrol_units = ...;
  end,
  success = function(self)
    mission.Objective:Start("defendSite",self.patrol_id,self.patrol_units);
  end
});

local defendSite = mission.Objective:define("defendSite"):createTasks(
  "spawn_waves", "kill_waves"
):setListeners({
  start = function(self,patrol_id,patrol_units)
    self.patrol_id = patrol_id;
    bzRoutine.routineManager:killRoutine(patrol_id);
    local sideObjectives = mission.Objective:getObjective("sideObjectives"):getInstance();
    self.extraUnits = sideObjectives:call("_hasBeenDetected");
    self.units_to_kill = patrol_units;
    self.default_waves = {
      [("%d"):format(3*60)] = {"2 2 4","1 4 1"},
      [("%d"):format(3*60 + 60)] = {"2 3","1 1"},
      [("%d"):format( self.extraUnits and (3*60 + 60*7) or 4*60 )] = {"5", "5"},
      [("%d"):format( (self.extraUnits and (3*60 + 60*7) or 4*60) + 60 )] = {"5 5", "5 5"}
    };
    self.extra_waves = {
      [("%d"):format(3*60 + 60*2+15)] = {"4 1 1"},
      [("%d"):format(3*60 + 60*3)] = {"2 4 4","4 1 1"},
      [("%d"):format(3*60 + 60*3+30)] = {"2 2 4 4","3 1 1 1"},
      [("%d"):format(3*60 + 60*5)] = {"2 2 2 4","3 4 1 1"}
    };
    for i, v in pairs(self.units_to_kill) do
      local s = mission.TaskManager:sequencer(v);
      s:clear();
      Stop(v,0);
      --Looks for target, if not found goto relic site
      s:queue3("FindTarget","relic_site");
    end
    AddObjective("rbd0903.otf");
    self.wave_timer = 0;
    self:startTask("spawn_waves");
    
  end,
  task_success = function(self,name)
    if(name == "spawn_waves") then
      self:startTask("kill_waves");
    elseif("kill_waves") then
      UpdateObjective("rbd0903.otf","green");
      self:success();
    end
  end,
  update = function(self,dtime)
    if(self:isTaskActive("spawn_waves")) then
      self.wave_timer = self.wave_timer + dtime;
      done = true;
      for i, v in pairs(self.default_waves) do
        done = false;
        local d = tonumber(i);
        if(self.wave_timer >= d) then
          local wave, lead = mission.spawnInFormation2(v,"nsdf_attack",{"avfigh","avtank","avrckt","avltnk","hvngrd"},2);
          Goto(lead,"nsdf_attack");
          for i2, v2 in pairs(wave) do
            local s = mission.TaskManager:sequencer(v2);
            if(v2~=lead) then
              Follow(v2,lead);
            end
            s:queue3("FindTarget","relic_site");
            table.insert(self.units_to_kill,v2);
          end
          self.default_waves[i] = nil;
        end
      end
      if(self.extraUnits) then
        for i, v in pairs(self.extra_waves) do
          done = false;
          local d = tonumber(i);
          if(self.wave_timer >= d) then
            local wave, lead = mission.spawnInFormation2(v,"nsdf_attack",{"avfigh","avtank","avrckt","avltnk","hvngrd"},2);
            Goto(lead,"nsdf_attack");
            for i2, v2 in pairs(wave) do
              local s = mission.TaskManager:sequencer(v2);
              if(v2~=lead) then
                Follow(v2,lead);
              end
              s:queue3("FindTarget","relic_site");
              table.insert(self.units_to_kill,v2);
            end
            self.extra_waves[i] = nil;
          end
        end
      end
      if(done) then
        self:taskSucceed("spawn_waves");
      end
    end
    if(self:isTaskActive("kill_waves")) then
      if(mission.areAllDead(self.units_to_kill, 2)) then
        self:taskSucceed("kill_waves");
      end
    end
  end,
  success = function(self)
    AudioMessage(audio.win);
    SucceedMission(GetTime() + 15,"rbd09wn.des");
  end,
  save = function(self)
    return self.default_waves, self.extra_waves, self.extraUnits, self.wave_timer, self.patrol_id;
  end,
  load = function(self,...)
    self.default_waves, self.extra_waves, self.extraUnits, self.wave_timer, self.patrol_id = ...;
  end
});

--]]

local function setUpPatrols()

  local patrol_rid, patrol_r = bzRoutine.routineManager:startRoutine("PatrolRoutine");
  --what are our `checkpoint` locations?
  patrol_r:registerLocations({"l_comm","l_c1","l_c2","l_c3","l_solar","l_north","l_west","l_sw"});

  patrol_r:defineRouts("l_comm",{
    p_comm_c3 = "l_c3"
  });
  
  patrol_r:defineRouts("l_c1",{
    p_c1_c2 = "l_c2",
    p_c1_sw = "l_sw"
  });

  patrol_r:defineRouts("l_c2",{
    p_c2_c3 = "l_c3",
    p_c2_north = "l_north"
  });
  
  patrol_r:defineRouts("l_c3",{
    p_c3_comm = "l_comm",
    p_c3_c1 = "l_c1"
  });

  patrol_r:defineRouts("l_solar",{
    p_solar_c3 = "l_c3"
  });

  patrol_r:defineRouts("l_north",{
    p_north_west = "l_west",
    p_north_solar = "l_solar",
    p_north_comm = "l_comm"
  });

  patrol_r:defineRouts("l_west",{
    p_west_c2 = "l_c2"
  });

  patrol_r:defineRouts("l_sw",{
    p_sw_c1 = "l_c1"
  });
  return patrol_rid, patrol_r;
end

function Start()
  --Set up patrolling units
  local patrol_form = {
    p_comm_c3 = {" 2 ", "3 3"},
    p_west_c2 = {" 2 ", "1 1"},
    p_north_solar = {" 2 ", "3 3"},
    p_c2_c3 = {" 2 ", "3 3"},
    p_sw_c1 = {" 2 ", "1 1"}
  }

  local p_id, p = setUpPatrols();
  local patrol_units = {};
  for i, v in pairs(patrol_form) do
    local units, lead = mission.spawnInFormation2(v,i,{"svfigh", "svtank", "svltnk"},2);
    for i2, v2 in pairs(units) do
      table.insert(patrol_units,v2);
      if(v2 ~= lead) then
        local s = mission.TaskManager:sequencer(v2);
        Follow(v2,lead);
        s:queue3("AddToPatrolTask",p_id);
      end
    end
    p:addHandle(lead);
  end
  local i = 1;
  local h;
  repeat
    h = GetHandle(("patrol%d"):format(i));
    i = i + 1;
  until not IsValid(h)

  local player_units, apc = mission.spawnInFormation2({" 1 ", "2 2 2", "4  2  4"},"player_units",{"bvapc09","bvtank","bvraz","bvltnk"},1,7);
  SetLabel(apc,"apc");
  captureRelic:start(p_id,patrol_units);
  sideObjectives:start(patrol_units);
  core:onStart();
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