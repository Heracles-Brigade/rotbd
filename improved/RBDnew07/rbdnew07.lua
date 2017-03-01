--Rev_2
local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();


--"Warming" up the RNG
for i=1, math.random(100,1000) do
  math.random();
end

--1.5 polyfill
Formation = Formation or function(me,him,priority)
  if(priority == nil) then
    priority = 1;
  end
  SetCommand(me,AiCommand["FORMATION"],priority,him);
end


function TugPickup(handle,target,priority,sequencer)
  local t = GetTug(target);
  if(IsValid(t)) then
    --If another tug has the relic, goto the relic
    Goto(handle,target,priority);
    --When reached the relic, do a check again
    sequencer:push3("TugPickup",target,priority);
  else
    --Else try to pickup the relic
    Pickup(handle,target,priority);
  end
end

--All the otfs we use
local otfs = {
  escort = "rbd0701.otf",
  relics = "rbd07ob1.otf",
  nsdf_distress = "rbd0703.otf",
  cca_distress = "rbd0704.otf",
  nsdf_tug = "rbd0705.otf",
  cca_tug = "rbd0706.otf"
}

--All the description files we use
local des = {
  loseRecycler = "rbd07los.des",
  loseTug = "rbd07l04.des",
  relic_nsdf_loss = "rbd07l02.des",
  relic_cca_loss = "rbd07l02.des",
  win = "rbd07win.des",
  relic_destroyed = "rbd07l03.des"
}

--the tug's label
local tugL = "relic_tug";

--[[
  TODO:
    -Get feedback
    -Adjust difficulty (wave size, timers, etc)
    -Create cinematic for tugs
]]


--Objective for escorting recycler
local escortRecycler = mission.Objective:define("escortRecycler"):createTasks(
  "escort","attack_wait1","attack_wait2","attack_wait3","kill_attackers"
):setListeners({
  init = function(self)
    self.recy = GetRecyclerHandle();
    self.tug = GetHandle(tugL);
  end,
  start = function(self)
    --How long do we wait before we spawn each wave?
    self.wave_wait = {2,25,1};
    --Start all "tasks"
    self:startTask("attack_wait1");
    self:startTask("attack_wait2");
    self:startTask("attack_wait3");
    self:startTask("escort");
    --List of attackers, will be populated as
    --waves start
    self.attackers = {};
    AddObjective(otfs.escort,"white");
  end,
  task_success = function(self,name,first,first_s,a1,a2)
    if(a1 == "attack_wait") then
      --Spawn attack waves
        local fac = {{"svfigh","avltnk"},{"avfigh","avltnk"},{"svfigh","svltnk"}};
        for i,v in pairs(mission.spawnInFormation2({" 2 ","1 1"},("wave%d"):format(a2),fac[a2],2,15)) do
          Goto(v,("wave%d_path"):format(a2));
          table.insert(self.attackers,v);
        end
        if(self:hasTasksSucceeded("attack_wait1","attack_wait2","attack_wait3")) then
          self:startTask("kill_attackers");
        end
    elseif(self:hasTasksSucceeded("kill_attackers","escort")) then
      self:success();
    end
  end,
  success = function(self)
    RemoveObjective(otfs.escort);
    mission.Objective:Start("reteriveRelics");
  end,
  fail = function(self,reason)
    UpdateObjective(otfs.escort,"red");
    FailMission(GetTime() + 5,des[reason]);
  end,
  delete_object = function(self,h)
    if(self:isTaskActive("kill_attackers") and mission.areAllDead(self.attackers)) then
      self:taskSucceed("kill_attackers");
    end
  end,
  update = function(self,dtime)
    for i=1, 3 do
      local t = ("attack_wait%d"):format(i);
      if(self:isTaskActive(t)) then
        self.wave_wait[i] = self.wave_wait[i] - dtime;
        if(self.wave_wait[i] <= 0) then
          self:taskSucceed(t,"attack_wait",i);
        end
      end
    end
    if(self:isTaskActive("escort")) then
      if(GetDistance(GetRecyclerHandle(),"bdog_base") < 50) then
        self:taskSucceed("escort");
      end
    end
    if(mission.areAnyDead({self.tug,self.recy})) then
      self:fail();
    end
    if(not IsAlive(self.tug)) then
      self:fail("loseTug");
    elseif(not IsAlive(self.recy)) then
      self:fail("loseRecycler");
    end
  end,
  save = function(self)
    return self.wave1_wait,self.attackers;
  end,
  load = function(self,...)
    self.wave1_wait,self.attackers = ...;
  end
})

--setUpBase objective that isn't currently used
local setUpBase = mission.Objective:define("setUpBase"):setListeners({
  start = function()
    AddObjective(otfs.createBase);
  end,
  update = function(self)
    if(tracker:gotOfClass("wingman",5,1) and tracker:gotOfClass("turrettank",2)) then
      self:success();
    elseif(not IsAlive(GetRecyclerHandle())) then
      self:fail();
    end
  end,
  success = function(self)
    UpdateObjective(otfs.createBase,"green");
  end,
  fail = function(self)
    UpdateObjective(otfs.createBase,"red");
    FailMission(GetTime()+5,des.loseRecycler);
  end
});


--Objective for getting relic
local getRelics = mission.Objective:define("reteriveRelics"):createTasks(
  "relic_nsdf","relic_cca","relic_nsdf_pickup","relic_cca_pickup","distress"
):setListeners({
  init = function(self)
    self.enemies = {
      relic_nsdf = "nsdf",
      relic_cca = "cca",
      relic_nsdf_pickup = "nsdf",
      relic_cca_pickup = "cca"
    }
    self.other = {
      nsdf = "cca",
      cca = "nsdf"
    }
    self.relics = {
      relic_nsdf = GetHandle("relic_nsdf"),
      relic_cca = GetHandle("relic_cca")
    }
    self.vehicles = {
      cca = {"svfigh","svtank","svrckt","svhaul","svltnk","svhraz"},
      nsdf = {"avfigh","avtank","avltnk","avhaul","avrckt","avhraz"}
    }
    self.waves = {
      relic_nsdf = "wave5",
      relic_cca = "wave4"
    }
    self.tug = GetHandle(tugL);
    self.recy = GetRecyclerHandle();
    self.waveInterval = 140;
  end,
  start = function(self)
    --Spawn attack @ nsdf_attack
    for i,v in pairs(mission.spawnInFormation2({"1 3"},("nsdf_attack"),self.vehicles.nsdf,2,15)) do
      Goto(v,"nsdf_attack");
    end
    
    --Spawn attack @ nsdf_base
    for i,v in pairs(mission.spawnInFormation2({"1 1","6 6"},"nsdf_path",self.vehicles.nsdf,2,15)) do
      local def_seq = mission.TaskManager:sequencer(v);
      --Goto relic site
      def_seq:queue2("Goto",("nsdf_path"):format(f));
      --Attack players base
      def_seq:queue2("Goto",("nsdf_attack"):format(f));
    end

    for i,v in pairs(mission.spawnInFormation2({" 1 ","5 5"},("cca_attack"),self.vehicles.cca,2,15)) do
      Goto(v,("cca_attack"));
    end

    self:startTask("relic_nsdf");
    self:startTask("relic_cca");
    
    self:startTask("relic_nsdf_pickup");
    self:startTask("relic_cca_pickup");
    --Give the player some time to build units
    --Timer will be set to 30 if the player
    --picks up one of the relics
    local ranC = math.random(0,1);
    self.bufferTime = {
      cca = ranC*500 + 500,
      nsdf = math.abs(ranC-1)*500 + 500
    };
    self.spawnedEnemyTugs = {
      cca = false,
      nsdf = false
    };
    self.waveTimer = {
      cca = ranC*self.waveInterval + self.waveInterval,
      nsdf = math.abs(ranC-1)*self.waveInterval + self.waveInterval
    };
    self.distressCountdown = 5;
    AddObjective(otfs.relics,"white",16);
  end,
  update = function(self,dtime)

    for i,v in pairs(self.relics) do
      local f = self.enemies[i];
      local ptask = i .. "_pickup";
      --Wave timer
      self.waveTimer[f] = self.waveTimer[f] - dtime;
      if(self.waveTimer[f] <= 0) then
        self.waveTimer[f] = self.waveInterval;
        local possibleWaves = {{" 2 ","1 1"},{" 2 ","6 6"}};
        local wave = possibleWaves[math.random(1,2)];
        local lead;
        for i,v in pairs(mission.spawnInFormation2(wave,("%s_path"):format(f),self.vehicles[f],2,15)) do
          local def_seq = mission.TaskManager:sequencer(v);
          if(i~=1) then
            def_seq:queue2("Formation",lead);
            def_seq:queue2("Goto",("%s_attack"):format(f));
          else
            lead = v;
            --Goto relic site
            def_seq:queue2("Goto",("%s_path"):format(f));
            --Attack players base
            def_seq:queue2("Goto",("%s_attack"):format(f));
          end

        end
      end
      --Tug timer
      self.bufferTime[f] = self.bufferTime[f] - dtime;
      if((self.bufferTime[f] <= 0) and (not self.spawnedEnemyTugs[f])) then
        if(not (self:hasTaskSucceeded(i) or self:hasTaskSucceeded(ptask)) ) then
          AddObjective(otfs[("%s_tug"):format(f)],color);
        end
        self.spawnedEnemyTugs[f]= true;
        local s = ("%s_spawn"):format(f);
        local tug = BuildObject(self.vehicles[f][4],2,s);
        --Create a sequence with all the tugs actions from creation to end
        local tug_sequencer = mission.TaskManager:sequencer(tug);
        tug_sequencer:queue2("Goto",("%s_path"):format(f));
        tug_sequencer:queue3("TugPickup",v,1);
        tug_sequencer:queue2("Goto",("%s_return"):format(f));
        tug_sequencer:queue2("Dropoff",("%s_base"):format(f));

        --Create escort
        for i,v in pairs(mission.spawnInFormation2({"2 3","1 1"},s,self.vehicles[f],2,15)) do
          local def_seq = mission.TaskManager:sequencer(v);
          def_seq:queue2("Defend2",tug);
          --If tug dies, attack the players base
          def_seq:queue2("Goto",("%s_attack"):format(f));
        end
        
        --Create Attack
        for i,v in pairs(mission.spawnInFormation2({"1 1"},("%s_path"):format(f),self.vehicles[f],2,15)) do
          local def_seq = mission.TaskManager:sequencer(v);
          --Goto relic site
          def_seq:queue2("Goto",("%s_path"):format(f));
          --Attack players base
          def_seq:queue2("Goto",("%s_attack"):format(f));
        end
      end
      
      --Check which base the relics are in if any at all
      local bdog, cca, nsdf = GetDistance(v,"bdog_base") < 100,
                              GetDistance(v,"cca_base") < 100,
                              GetDistance(v,"nsdf_base") < 100;
      local tug = GetTug(v);
      --If no one has capture the relic yet
      if(self:isTaskActive(i)) then
      --If bdog has it, set state to succeeded
        if(bdog) then
          if(not IsValid(tug)) then
            self:taskSucceed(i);
          end
        --Else if cca or nsdf has it, set state to failed
        elseif(cca or nsdf) then
          self:taskFail(i);
        end
      --If someone had it, but no longer has reset the state
      elseif(self:hasTaskStarted(i) and (not (bdog or cca or nsdf) )) then
        self:taskReset(i);
      end
      if(self:isTaskActive(ptask) ) then
        if(GetTeamNum(tug) == 1) then
          self:taskSucceed(ptask);
        elseif(GetTeamNum(tug) == 2) then
          self:taskFail(ptask,tug,v);
          --Fail task, reset if player manages to retake it
        end
      elseif(not self:isTaskActive(ptask) and not IsValid(tug)) then
        self:taskReset(ptask,tug,v);
      end
    end
    if(self:isTaskActive("distress")) then
      local dpath = ("%s_distress"):format(self.distress_faction);
      local apath = ("%s_ambush"):format(self.distress_faction);
      local d_att = self.vehicles[self.distress_faction];
      if(GetDistance(GetPlayerHandle(),dpath) < 100) then
        --It is a trap, spawn ambush
        for i,v in pairs(mission.spawnInFormation2({"1 2 3 1"},apath,d_att,2,15)) do
          local tm = mission.TaskManager:sequencer(v);
          --Everyone attack the player
          tm:queue2("Attack",GetPlayerHandle());
          --Then attack the base!
          tm:queue2("Goto",("%s_attack"):format(self.distress_faction));
        end
        self:taskSucceed("distress");
      end
    elseif(self.distress_faction and (not self:hasTaskStarted("distress")) ) then
      self.distressCountdown = self.distressCountdown - dtime;
      if(self.distressCountdown <= 0) then
        self:startTask("distress",self.distress_faction);
      end
    end
    if(not IsValid(self.tug)) then
      self:fail("loseTug");
    elseif(not IsValid(self.recy)) then
      self:fail("loseRecycler");
    end
    if(mission.areAnyDead(self.relics)) then
      self:fail("relic_destroyed");
    end
  end,
  task_start = function(self,name,a1)
    if(name == "distress") then
      local distress_l = ("%s_distress"):format(a1); 
      local nav = BuildObject("apcamr",1,distress_l);
      SetObjectiveName(nav,"Distress Call");
      AddObjective(otfs[distress_l]);
    end
  end,
  task_success = function(self,name,first,first_s)
    local fac = self.enemies[name];
    if(name == "relic_cca" or name == "relic_nsdf") then
      UpdateObjective(otfs[("%s_tug"):format(fac)],"green");
    end
    if(name == "distress") then
      UpdateObjective(otfs[("%s_distress"):format(self.distress_faction)],"green");
    end

    if(first_s) then
      for i,v in pairs(self.relics) do
        local pickup_task = i .. "_pickup";
        local faction = self.enemies[i];
        local other_faction = self.other[faction];
        local other_task = ("relic_%s"):format(other_faction);
        local other_pickup_task = other_task .. "_pickup";
        local other_relic = self.relics[other_task];
        --If we have picked up one of the relics
        if(name == pickup_task) then
          --AI has no time to lose
          self.bufferTime[faction] = math.min(self.bufferTime[faction],30);
          self.bufferTime[other_faction] = math.min(self.bufferTime[other_faction],180);
          --If there hasn't been a distress call yet
          if(self:hasTaskSucccededBefore(other_pickup_task) and (not self:hasTaskStarted("distress"))) then
            --The same faction should create a distress call
            self.distress_faction = faction;
          end
        end

        if(name == i) then
          --Spawn wave4 or wave5
          local p = self.waves[i];
          --Spawn two bombers
          for i,v in pairs(mission.spawnInFormation2({"6 6"},p,self.vehicles[faction],2,15)) do
            Goto(v,("%s_path"):format(p));
          end
        end
      end
    end
    --If we have both relics this objective succeeds
    if(self:hasTasksSucceeded("relic_nsdf","relic_cca","distress")) then
      self:success();
    end
  end,
  task_fail = function(self,name,first,first_f,a1,a2)
    local fac = self.enemies[name];
    if(name == "relic_nsdf" or name == "relic_cca") then
      UpdateObjective(otfs[("%s_tug"):format(fac)],"red");
      self:fail(("%s_loss"):format(name));
    end
    if(name == "relic_nsdf_pickup" or name == "relic_cca_pickup") then
      --UpdateObjective(otfs[("%s_tug"):format(fac)],"yellow");
      --Paint the enemy tug carrying the relic
      SetObjectiveOn(a1);
      --Unpaint the relic
      SetObjectiveOff(a2);
      --Set relic's team to 2, so that the AI can attack
      --the tug carrying it, might want to do this when the
      --players tug also captures the relic
      SetTeamNum(a2,2);
    end
  end,
  task_reset = function(self,name,a1,a2)
    local fac = self.enemies[name];
    if(name == "relic_nsdf" or name == "relic_cca") then
      UpdateObjective(otfs[("%s_tug"):format(fac)],"white");
    end
    if(name == "relic_nsdf_pickup" or name == "relic_cca_pickup") then
      --Unpain the tug carrying the relic
      SetObjectiveOff(a1);
      --Pain the relic
      SetObjectiveOn(a2);
      --Reset team of the relic to 0
      SetTeamNum(a2,0);
    end
  end,
  save = function(self)
    --Vars we need to save
    return self.distress_faction, self.bufferTime,self.spawnedEnemyTugs,self.waveTimer,self.distressCountdown;
  end,
  load = function(self,...)
    --Vars we need to load
    self.distress_faction,self.bufferTime,self.spawnedEnemyTugs,self.waveTimer,self.distressCountdown = ...;
  end,
  fail = function(self,kind)
    FailMission(GetTime() + 5,des[kind]);
  end,
  success = function(self)
    UpdateObjective(otfs.relics,"green");
    SucceedMission(GetTime() + 5, des.win);
  end
});



function Start()
  SetScrap(1,10);
  SetPilot(1,25)
  --Start objective to escort recycler
  escortRecycler:start();
end

function Update(dtime)
  mission:Update(dtime);
end

function CreateObject(handle)
  mission:CreateObject(handle);
end

function AddObject(handle)
  mission:AddObject(handle);
end

function DeleteObject(handle)
  mission:DeleteObject(handle);
end

function Save()
  return mission:Save(), globals, tracker:save();
end

function Load(misison_date,g,t)
  mission:Load(misison_date);
  globals = g;
  tracker:load(t);
end
