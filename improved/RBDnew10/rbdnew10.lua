
local _ = require("bz_logging");
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

local buildAi = require("buildAi");

local ProducerAi = buildAi.ProducerAi;
local ProductionJob = buildAi.ProductionJob;

local isIn = OOP.isIn;
local joinTables = OOP.joinTables;

local fail_des = {
  lpad = "rbd10l01.des",
  const = "rbd10l02.des",
  transports = "rbd10l04.des",
  recycler = "rbd10l03.des",
  factory = "rbd10l04.des"
};


local units = {
  nsdf = {"avfigh","avtank","avrckt","avhraz","avapc","avwalk", "avltnk"},
  cca = {"svfigh","svtank","svrckt","svhraz","svapc","svwalk", "svltnk"},
  fury = {"hvsat","hvsav"}
};


local fury_waves = {
  {item = {"2 2", "2 2"}, chance = 1},
}

local light_waves = {
  {item = {" 2 ", "1 1"}, chance = 7},
  {item = {" 2 ", "7 7"}, chance = 7},
}

local heavy_waves = {
  {item = {" 2 ", "7 1"}, chance = 7}, --LIGHT
  {item = {"2 7 2", "3 1 1"}, chance = 7}, --ASSAULT
  {item = {"3 2", "4 4"}, chance = 5}, --BOMBER
  {item = {" 5 ", "5 7 7"}, chance = 4}, --APC
  {item = {" 6 ", "3 2"}, chance = 2} --WALKER
}

function FindTarget(handle,alt,sequencer)
  local ne = GetNearestEnemy(handle);
  if(IsValid(ne)) then
    sequencer:queue2("Attack",GetNearestEnemy(handle));
    sequencer:queue3("FindTarget",alt);
  elseif(GetDistance(handle,alt) > 50) then
    sequencer:queue2("Goto",alt);
    sequencer:queue3("FindTarget",alt);
  else
    sequencer:queue(AiCommand["Hunt"]);
  end
end

local function choose(...)
  local t = {...};
  local rn = math.random(#t);
  return t[rn];
end

local function chooseA(...)
  local t = {...};
  local m = 0;
  for i, v in pairs(t) do
    m = m + v.chance; 
  end
  local rn = math.random()*m;
  local n = 0;
  for i, v in ipairs(t) do
    if (v.chance+n) > rn then
      return v.item;
    end
    n = n + v.chance;
  end
end

local function spawnWave(wave_table,faction,location)
  print("Spawn Wave",wave_table,faction,location,units[faction]);
  local units, lead = mission.spawnInFormation2(wave_table,("%s_wave"):format(location),units[faction],2);
  for i, v in pairs(units) do
    local s = mission.TaskManager:sequencer(v);
    if(v == lead) then
      s:queue2("Goto",("%s_path"):format(location));
    else
      s:queue2("Follow",lead);
    end
    s:queue3("FindTarget","bdog_base");
  end
  return units;
end


local waveSpawner = Decorate(
  Routine({
    name = "waveSpawner",
    delay = 2
  }),
  Class("waveSpawnerClass",{
    constructor = function()
      self.waves_left = 0;
      self.wave_frequency = 0;
      self.timer = 0;
      self.variance = 0;
      self.c_variance = 0;
      self.wave_subject = rx.Subject.create();
    end,
    methods = {
      isAlive = function()
        return self.waves_left > 0;
      end,
      save = function()
        return self.wave_frequency, 
          self.waves_left, 
          self.timer, 
          self.variance, 
          self.c_variance, 
          self.wave_types,
          self.factions,
          self.locations;
      end,
      load = function(...)
        self.wave_frequency, 
          self.waves_left, 
          self.timer, 
          self.variance, 
          self.c_variance, 
          self.wave_types,
          self.factions,
          self.locations = ...;
      end,
      onWaveSpawn = function()
        return self.wave_subject;
      end,
      onInit = function(...)
        self.factions,
          self.locations,
          self.wave_frequency, 
          self.waves_left, 
          self.variance, 
          self.wave_types = ...;

        local f = self.wave_frequency*self.variance;
        self.c_variance =  f + 2*f*math.random();
      end,
      onDestroy = function()
      end,
      update = function(dtime)
        self.timer = self.timer + dtime;
        local freq = self.wave_frequency + self.c_variance;
        if(self.timer * freq >= 1) then
          self.timer = self.timer - 1/freq;
          local f = self.wave_frequency*self.variance;
          self.c_variance =  f + 2*f*math.random();
          self.waves_left = self.waves_left - 1;
          local fac = choose(unpack(self.factions));
          local locations = {};
          for i, v in pairs(self.locations) do
            if (not isIn(v,self.factions)) or (isIn(v,self.factions) and fac==v) then
              table.insert(locations,v);
            end
          end
          local location = choose(unpack(locations));
          local w_type = chooseA(unpack(self.wave_types));
          self.wave_subject:onNext(spawnWave(w_type,fac,location));
        end
      end
    }
  })
);

bzRoutine.routineManager:registerClass(waveSpawner);

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


local protectRecycler = mission.Objective:define("protectRecycler"):setListeners({
  delete_object = function(self,handle)
    if(handle == GetRecyclerHandle() or not IsAlive(GetRecyclerHandle())) then
      self:fail();
    end
  end,
  fail = function(self)
    FailMission(GetTime()+5.0,fail_des.recycler);
  end
});

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
    local mission_obj = mission.Objective:Start("build_launchpad");
  end
});

local build_launchpad = mission.Objective:define("build_launchpad"):createTasks(
  "order_to_build", "build_lpad", "factory_spawn"
):setListeners({
  init = function(self)
    self.subscriptions = {};
  end,
  start = function(self)
    AudioMessage(audio.intro);
    AddObjective("rbd1001.otf");
    self:startTask("order_to_build");
    self.building = false;
    self.wave_timer = 0;
    self.factory_timer = 60*15;
    self.wave_controllers = {};
    self.enemy_units = {};
    self.waves = {
      [("%d"):format(0)] = {
        --{frequency,wave_count,variance,wave_type}
        {1/120,8,0.5,heavy_waves},
        {1/60,11,0.1,light_waves}
      },
      [("%d"):format(16*60)] = {
        {1/60,15,0.1,heavy_waves},
        {1/60,3,0.1,light_waves}
      },
      [("%d"):format(15*60)] = {
        {1/100,10,0.2,heavy_waves},
        {1/80,10,0.2,heavy_waves}
      }
    }
  end,
  task_start = function(self,name)
    if(name == "order_to_build") then
      bzRoutine.routineManager:startRoutine("waveSpawner",{"cca","nsdf"},{"east","west","cca","nsdf"},1/70,8,0.05,light_waves);
    elseif(name == "build_lpad") then
      AddObjective("rbd1002.otf");
      local btime = misc.odfFile("ablpadx"):getFloat("GameObjectClass","buildTime");
      self.factory_timer = math.min(self.factory_timer,btime);
      StartCockpitTimer(btime);
    end
  end,
  task_success = function(self,name)
    if(name == "order_to_build") then
      self:startTask("build_lpad");
      self:startTask("factory_spawn");
      RemoveObjective("rbd1001.otf");
    end
    if(self:hasTasksSucceeded("build_lpad","order_to_build","factory_spawn")) then
      UpdateObjective("rbd1002.otf","green");
      self:success();
    end
  end,
  task_fail = function(self,name)
    if(name == "build_lpad") then
      UpdateObjective("rbd1002.otf","red");
    end
    
    self:fail("const");
  end,
  _hook_controller = function(self,id)
    local p = bzRoutine.routineManager:getRoutine(id);
    if(p) then
      table.insert(self.subscriptions,
        p:onWaveSpawn():subscribe(function(handles)
          local n = {};
          for i, v in pairs(self.enemy_units) do
            if(IsAlive(v)) then
              table.insert(n,v);
            end
          end
          self.enemy_units = joinTables(n,handles);
        end)
      );
    end
  end,
  update = function(self,dtime)
    local const = GetConstructorHandle();
    
    if(self:isTaskActive("order_to_build")) then
      local d1 = GetPosition("launchpad");
      local ctask = GetCurrentCommand(const);
      if((not self.building) and GetDistance(const,"launchpad") < 100 and ctask == AiCommand["NONE"]) then
        local pp = GetPathPoints("launchpad");
        local t = BuildDirectionalMatrix(pp[1],pp[2]-pp[1]);
        self.building = true;
        self.const = const;
        self.lpad_bid = ProducerAi:queueJob(ProductionJob("ablpadx",1,t));
        self:call("_setUpProdListener",self.lpad_bid,"_lpad_done");
        --BuildAt(self.const,"ablpadx",t);
      end
      if(self.building and IsDeployed(self.const)) then
        self:taskSucceed("order_to_build");
      elseif(self.building and (not IsAlive(self.const))) then
        self:taskFail("order_to_build");
      end
    elseif(self:isTaskActive("build_lpad")) then
      self.wave_timer = self.wave_timer + dtime;
      for i, v in pairs(self.waves) do
        if(self.wave_timer > tonumber(i)) then
          for i2, wave_args in ipairs(v) do
            local r_id, r = bzRoutine.routineManager:startRoutine("waveSpawner",{"cca","nsdf"},{"east","west","cca","nsdf"},unpack(wave_args));
            table.insert(self.wave_controllers,r_id);
            self:call("_hook_controller",r_id);
          end
          self.wave_timer = 0;
          self.waves[i] = nil;
          break;
        end
      end
    end
    if(self:isTaskActive("factory_spawn")) then
      self.factory_timer = self.factory_timer - dtime;
      if(self.factory_timer <= 0) then
        local f = BuildObject("bvmuf30",1,"spawn_factory");
        local s = mission.TaskManager:sequencer(f);
        s:queue2("Goto","factory_path");
        s:queue(AiCommand["GO_TO_GEYSER"]);
        ProducerAi:queueJobs(ProductionJob:createMultiple(3,"svmtnk30",1));
        self:taskSucceed("factory_spawn");
      end
    elseif(self:hasTasksSucceeded("factory_spawn") and not IsAlive(GetFactoryHandle())) then
      self:fail("factory");
    end
  end,
  delete_object = function(self,handle)
    if(self:isTaskActive("build_lpad")) then
      if(handle == self.const) then
        self:taskFail("build_lpad");
      end
    elseif(self.lpad == handle) then
      self:fail("lpad");
    end
  end,
  save = function(self)
    return self.building, 
      self.const, 
      self.lpad_bid, 
      self.lpad, 
      self.waves, 
      self.wave_timer, 
      self.factory_timer,
      self.wave_controllers,
      self.enemy_units;
  end,
  load = function(self,...)
    self.building, 
      self.const, 
      self.lpad_bid, 
      self.lpad, 
      self.waves, 
      self.wave_timer, 
      self.factory_timer,
      self.wave_controllers,
      self.enemy_units = ...;

    for i, v in pairs(self.wave_controllers) do
      self:call("_hook_controller",v);
    end

    if(self.lpad_bid) then
      self:call("_setUpProdListener",self.lpad_bid,"_lpad_done");
    end
  end,
  finish = function(self)
    for i, v in pairs(self.subscriptions) do
      v:unsubscribe();
    end
  end,
  fail = function(self,what)
    FailMission(GetTime()+5.0,fail_des[what]);
  end,
  success = function(self)
    mission.Objective:Start("defend_and_escort",self.lpad,OOP.copyTable(self.enemy_units),self.wave_controllers);
  end,
  _lpad_done = function(self,job,handle)
    self.lpad = handle;
    Stop(GetConstructorHandle(),0);
    HideCockpitTimer();
    self:taskSucceed("build_lpad");
  end,
  _setUpProdListener = function(self,id,done)
    local job = ProducerAi:getJob(id);
    if(job) then
      job:onFinish():subscribe(function(...)
        self:call(done,...);
      end);
    end
  end
});

local defend_and_escort = mission.Objective:define("defend_and_escort"):createTasks(
  "build_transports", "escort_transports"
):setListeners({
  start = function(self,launchpad,enemy_units,wave_controllers)
    self.transports = {};
    self.launchpad = launchpad;
    self.enemy_units = enemy_units;
    for i, v in pairs(self.enemy_units) do
      local s = mission.TaskManager:sequencer(v);
      s:clear();
      Retreat(v,"enemy_base");
    end
    self.wave_controllers = wave_controllers;
    for i, v in pairs(self.wave_controllers) do
      self:call("_hook_controller",v);
    end
    self.furies = {};
    self:startTask("build_transports");
    AudioMessage(audio.evacuate);
  end,
  _setUpProdListeners = function(self,id,done,each)
    local job = ProducerAi:getBundle(id);
    if(job) then
      job:onFinish():subscribe(function(...)
        self:call(done,...);
      end);
      job:forEach():subscribe(function(...)
        self:call(each,...);
      end);
    end
  end,
  _each_transport = function(self,job,handle)
    table.insert(self.transports,handle);
    SetObjectiveName(handle,("Transport %d"):format(#self.transports));
    SetObjectiveOn(handle);
  end,
  _transports_done = function(self,bundle,handles)
    self:taskSucceed("build_transports");
  end,
  task_start = function(self,name)
    if(name == "build_transports") then
      self.fury_id = bzRoutine.routineManager:startRoutine("waveSpawner",{"fury"},{"fury"},1/30,5,0.05,fury_waves);
      bzRoutine.routineManager:getRoutine(self.fury_id):onWaveSpawn():subscribe(function(...)
        self:call("_fury_spawn",...);
      end);
      self.transport_job = ProducerAi:queueJobs(ProductionJob:createMultiple(3,"bvhaul30",1));
      self:call("_setUpProdListeners",self.transport_job,"_transports_done","_each_transport");
    elseif(name == "escort_transports") then
      --Make furies target transports
      for i, v in pairs(self.furies) do
        Attack(v,choose(unpack(self.transports)));
      end
      AddObjective("rbd1003.otf");
      for i, v in ipairs(self.transports) do
        Goto(v,self.launchpad);
      end
    end
  end,
  task_success = function(self,name)
    if(name == "build_transports") then
      self:startTask("escort_transports");
    elseif(name == "escort_transports") then
      UpdateObjective("rbd1003.otf","green");
      self:success();
    end
  end,
  task_fail = function(self,name,_,_,what)
    self:fail(what);
  end,
  fail = function(self,what)
    UpdateObjective("rbd1003.otf","red");
    FailMission(GetTime()+5.0,fail_des[what]);
  end,
  _fury_spawn = function(self,units)
    self.furies = joinTables(self.furies,units);
  end,
  _hook_controller = function(self,id)
    local p = bzRoutine.routineManager:getRoutine(id);
    if(p) then
      p:onWaveSpawn():subscribe(function(handles)
        self:call("_enemy_spawn",handles);
      end);
    end
  end,
  _enemy_spawn = function(self,units)
    for i, v in pairs(units) do
      local s = mission.TaskManager:sequencer(v);
      s:clear();
      Retreat(v,"enemy_base");
      table.insert(self.enemy_units,v);
    end
  end,
  success = function(self)
    AudioMessage(audio.shaw);
    SucceedMission(GetTime()+10.0,"rbd10w01.des");
  end,
  save = function(self)
    return self.transports, self.launchpad, self.furies, self.fury_id, self.enemy_units, self.wave_controllers;
  end,
  load = function(self,...)
    self.transports, self.launchpad, self.furies, self.fury_id, self.enemy_units, self.wave_controllers = ...;
    for i, v in pairs(self.wave_controllers) do
      self:call("_hook_controller",v);
    end
    if(self.fury_id) then
      bzRoutine.routineManager:getRoutine(self.fury_id):onWaveSpawn():subscribe(function(...)
        self:call("_fury_spawn",...);
      end);
    end
  end,
  update = function(self,dtime)
    if(not IsAlive(self.launchpad)) then
      self:fail("lpad");
    end
    if(self:isTaskActive("fury_attack")) then
    end
    if(self:isTaskActive("escort_transports")) then
      for i, v in ipairs(self.transports) do
        if(GetDistance(v,self.launchpad) < 60) then
          table.remove(self.transports,i);
          RemoveObject(v);
        end
      end
      if(mission.areAnyDead(self.transports)) then
        self:taskFail("escort_transports","transports");
      elseif(#self.transports <= 0) then
        self:taskSucceed("escort_transports");
      end
    elseif(self:isTaskActive("build_transports") and not IsAlive(GetFactoryHandle())) then
      self:taskFail("build_transports","factory"); 
    end
  end
});


function Start()
  core:onStart();
  getToBase:start();
  protectRecycler:start();
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