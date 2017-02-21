--Rev_1


local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();


function TugPickup(handle,target,priority,sequencer)
  local t = GetTug(target);
  if(IsValid(t)) then
    --If another tug has the relic, goto the relic
    Goto(handle,target,priority);
    --When reached the relic, do a check again
    sequencer:push2("TugPickup",target,priority);
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
  cca_distress = "rbd0704.otf"
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
      relic_cca = "cca"
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
      cca = {"svfigh","svtank","svrckt","svhaul","svwalk","svhraz"},
      nsdf = {"avfigh","avtank","avltnk","avhaul","avwalk","avhraz"}
    }
    self.waves = {
      relic_nsdf = "wave5",
      relic_cca = "wave4"
    }
    self.tug = GetHandle(tugL);
    self.recy = GetRecyclerHandle();
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

    for i,v in pairs(mission.spawnInFormation2({"5 5"},("cca_attack"),self.vehicles.cca,2,15)) do
      Goto(v,("cca_attack"));
    end

    self:startTask("relic_nsdf");
    self:startTask("relic_cca");
    
    self:startTask("relic_nsdf_pickup");
    self:startTask("relic_cca_pickup");
    --Give the player some time to build units
    --Timer will be set to 60 if the player
    --picks up one of the relics
    self.bufferTime = 500;
    self.spawnedEnemyTugs = false;
    AddObjective(otfs.relics,"white",16);
  end,
  update = function(self,dtime)
    self.bufferTime = self.bufferTime - dtime;
    if((self.bufferTime <= 0) and (not self.spawnedEnemyTugs)) then
      for i,v in pairs(self.relics) do
        local f = self.enemies[i];
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
      self.spawnedEnemyTugs = true;
    end
    for i,v in pairs(self.relics) do
      --Check which base the relics are in if any at all
      local bdog, cca, nsdf = GetDistance(v,"bdog_base") < 100,
                              GetDistance(v,"cca_base") < 100,
                              GetDistance(v,"nsdf_base") < 100;
      local tug = GetTug(v);
      local ptask = i .. "_pickup";
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
    end
    if(not IsValid(self.tug)) then
      self:fail("loseTug");
    elseif(not IsValid(self.recy)) then
      self:fail("loseRecycler");
    end
  end,
  task_start = function(self,name,a1)
    if(name == "distress") then
      self.distress_faction = a1;
      local distress_l = ("%s_distress"):format(a1); 
      local nav = BuildObject("apcamr",1,distress_l);
      SetObjectiveName(nav,"Distress Call");
      AddObjective(otfs[distress_l]);
    end
  end,
  task_success = function(self,name,first,first_s)
    
    if(name == "distress") then
      UpdateObjective(otfs[("%s_distress"):format(self.distress_faction)],"green");
    end

    if(first_s) then
      for i,v in pairs(self.relics) do
        local pickup_task = i .. "_pickup";
        local faction = self.enemies[i];
        local other_faction = self.other[faction];
        local other_task = ("relic_%s"):format(other_faction);
        local other_relic = self.relics[other_task];
        --If we have picked up one of the relics
        if(name == pickup_task) then
          --AI has no time to lose
          self.bufferTime = math.min(self.bufferTime,60);
          --If there hasn't been a distress call yet
          if(not self:hasTaskStarted("distress")) then
            --The other faction should create a distress call
            self:startTask("distress",other_faction);
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
    if(self:hasTasksSucceeded("relic_nsdf","relic_cca")) then
      self:success();
    end
  end,
  task_fail = function(self,name,first,first_f,a1,a2)
    if(name == "relic_nsdf" or name == "relic_cca") then
      self:fail(("%s_loss"):format(name));
    end
    if(name == "relic_nsdf_pickup" or name == "relic_cca_pickup") then
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
    return self.distress_faction, self.bufferTime;
  end,
  load = function(self,...)
    --Vars we need to load
    self.distress_faction,self.bufferTime = ...;
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
  SetScrap(1,16);
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
