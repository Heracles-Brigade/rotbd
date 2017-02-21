
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


local otfs = {
  escort = "rbd0701.otf",
  relics = "rbd07ob1.otf",
  nsdf_distress = "rbd0704.otf",
  cca_distress = "rbd0703.otf"
}
local des = {
  loseRecycler = "rbd07los.des",
  relic_nsdf_loss = "rbd07l02.des",
  relic_cca_loss = "rbd07l02.des",
  win = "rbd07win.des",
  relic_destroyed = "rbd07l03.des"
}

local tugL = "relic_tug";




local escortRecycler = mission.Objective:define("escortRecycler"):createTasks(
  "escort","attack_wait1","attack_wait2","attack_wait3","kill_attackers"
):setListeners({
  init = function(self)

  end,
  start = function(self)
    self.wave_wait = {2,25,1};
    self:startTask("attack_wait1");
    self:startTask("attack_wait2");
    self:startTask("attack_wait3");
    self:startTask("escort");
    self.attackers = {};
    AddObjective(otfs.escort,"white");
  end,
  task_success = function(self,name,first,a1,a2)
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
  task_fail = function()
    self:fail();
  end,
  success = function(self)
    RemoveObjective(otfs.escort);
    mission.Objective:Start("reteriveRelics");
  end,
  fail = function(self,c)
    UpdateObjective(otfs.escort,"red");
    FailMission(GetTime() + 5,des[c]);
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
  end,
  save = function(self)
    return self.wave1_wait,self.attackers;
  end,
  load = function(self,...)
    self.wave1_wait,self.attackers = ...;
  end
})

--setUpBase is not used
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
    self.tug = GetHandle(tugL);
    self.recy = GetRecyclerHandle();
  end,
  start = function(self)
    --Spawn attack @ nsdf_attack
    for i,v in pairs(mission.spawnInFormation2({"1 3"},("nsdf_attack"),self.vehicles.nsdf,2,15)) do
      Goto(v,"nsdf_attack");
    end
    
    --Spawn attack @ cca_base
    for i,v in pairs(mission.spawnInFormation2({" 1 ","2 3", "6 6"},"cca_path",self.vehicles.cca,2,15)) do
      local def_seq = mission.TaskManager:sequencer(v);
      --Goto relic site
      def_seq:queue2("Goto",("cca_path"):format(f));
      --Attack players base
      def_seq:queue2("Goto",("cca_attack"):format(f));
    end

    for i,v in pairs(mission.spawnInFormation2({"5 5"},("cca_attack"),self.vehicles.cca,2,15)) do
      Goto(v,("cca_attack"));
    end

    self:startTask("relic_nsdf");
    self:startTask("relic_cca");
    
    self:startTask("relic_nsdf_pickup");
    self:startTask("relic_cca_pickup");
    --Give the player some time to build units
    --Timer will be set to 0 if the player
    --picks up one of the relics
    self.bufferTime = 600;
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
        tug_sequencer:queue2("TugPickup",v,1);
        tug_sequencer:queue2("Goto",("%s_return"):format(f));
        tug_sequencer:queue2("Dropoff",("%s_base"):format(f));

        --Create escort
        for i,v in pairs(mission.spawnInFormation2({" 2 2 ","3 3 3"},s,self.vehicles[f],2,15)) do
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
      print(apath,d_att);
      if(GetDistance(GetPlayerHandle(),dpath) < 100) then
        --It is a trap, spawn ambush
        for i,v in pairs(mission.spawnInFormation2({"1 3 2 3 1"},apath,d_att,2,15)) do
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
      print(otfs[("%s_distress"):format(a1)]);
      AddObjective(otfs[("%s_distress"):format(a1)]);
    end
  end,
  task_success = function(self,name,first)
    --If you pick up relic1 then make cca try to take relic2?
    --also send attack forces after tug, try to take relic if tug is lost?
    --Vise versa
    print("Task succeeded",name,first);
    if(first) then
      for i,v in pairs(self.relics) do
        local pickup_task = i .. "_pickup";
        local faction = self.enemies[i];
        local other_faction = self.other[faction];
        local other_task = ("relic_%s"):format(other_faction);
        local other_relic = self.relics[other_task];
        --If we have picked up one of the relics
        if(name == pickup_task) then
          --AI has no time to lose
          self.bufferTime = 0;
          --If there hasn't been a distress call yet
          if(not self:hasTaskStarted("distress")) then
            --The other faction should create a distress call
            self:startTask("distress",other_faction);
          end
        end
      end
    end
    --If we have both relics this objective succeeds
    if(self:hasTasksSucceeded("relic1","relic2")) then
      self:success();
    end
  end,
  task_fail = function(self,name,first)
    if(name == "relic_nsdf" or name == "relic_cca") then
      self:fail(("%s_loss"):format(name));
    end
  end,
  task_reset = function(self,name,a1,a2)
    if(name == "relic_nsdf_pickup" or name == "relic_cca_pickup") then
      SetObjectiveOff(a1);
      SetObjectiveOn(a2);
    end
  end,
  save = function(self)
    return self.distress_faction, self.bufferTime;
  end,
  load = function(self,...)
    self.distress_faction,self.bufferTime = ...;
  end,
  fail = function(self,kind)
    FailMission(GetTime() + 5,des[kind]);
  end,
  success = function(self)
    SucceedMission(GetTime() + 5, des.win);
  end
});


local getRelicsOld = mission.Objective:define("reteriveRelics_old"):createTasks(
  --task names we will be using
  "relic1","relic2", "relic1_pickup", "relic2_pickup"
):setListeners({
  init = function(self)
    --[task] = otf
    self.otfs = {
      relic1 = "rbd0701.otf",
      relic2 = "rbd0702.otf"
    };
    --[task] = handle
    self.relics = {
      relic1 = GetHandle("relic_nsdf"),
      relic2 = GetHandle("relic_cca")
    };
    --[task] = path
    self.capture = {
      relic2 = "cca_base",
      relic1 = "nsdf_base"
    };
    self.fconditions = {
      "rbd07l1.des",
      "rbd07l2.des"
    };
    self.tug = GetHandle("tug");
  end,
  start = function(self)
    AddObjective(self.otfs["relic1"],"white");
    AddObjective(self.otfs["relic2"],"white");
    for i,v in pairs(self.relics) do
      SetObjectiveOn(v);
    end
    self:startTask("relic1");
    self:startTask("relic2");
    self:startTask("relic1_pickup");
    self:startTask("relic2_pickup");
  end,
  update = function(self)
    for i,v in pairs(self.relics) do
      --Check which base the relics are in if any at all
      local bdog, cca, nsdf = GetDistance(v,"bdog_base") < 100,
                              GetDistance(v,"cca_base") < 100,
                              GetDistance(v,"nsdf_base") < 100
      local tug = GetTug(v);
      local ptask = i .. "_pickup";
      if(IsValid(tug)) then
        SetTeamNum(v,GetTeamNum(tug));
      end
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
          self:taskFail(ptask);
          --Fail task, reset if player manages to retake it
        end
      end
    end
    if(not IsValid(self.tug)) then
      self:fail(2);
    end
  end,
  task_reset = function(self,name)
    UpdateObjective(self.otfs[name],"white");
  end,
  task_success = function(self,name,first)
    if(self.otfs[name]) then
      UpdateObjective(self.otfs[name],"green");
    end
    --If you pick up relic1 then make cca try to take relic2?
    --also send attack forces after tug, try to take relic if tug is lost?
    --Vise versa
    if(first) then
      for i,v in pairs(self.relics) do
        local ptask = i .. "_pickup";
        local mindex = i:gmatch("%d")();
        local oindex = mindex % 2 + 1;
        local otask = ("relic%d"):format(oindex);
        local orelic = self.relics[otask];
        if(name == i) then
          --Spawn force to retake relic
          --Important this will not happen if CCA/NSDF captured it first
          --Might want to look into a way of changing this
          print("Spawning forces to retake relic!");

          local rtug = BuildObject("svhaul",2,("attack%d"):format(mindex));
          local sequencer = mission.TaskManager:sequencer(rtug);
          Pickup(rtug,v);
          sequencer:queue2("Dropoff",self.capture[i]);
          local recy = GetRecyclerHandle(1);
          for i,v in pairs(mission.spawnInFormation2({"3 1 1 3","2 2 2 2"},("attack%d"):format(mindex),{"svtank","svfigh","svhraz"},2,15)) do
            if(math.floor((i-1)/4) == 0) then
              Attack(v,IsValid(recy) and recy);
            else
              Defend2(v,rtug)
            end
          end
        end
        if(name == ptask) then
          for i,v in pairs(mission.spawnInFormation2({"1 1 1 1 1"},("spawn_tug%d"):format(mindex),{"svfigh"},2,15)) do
            Goto(v,self.tug);
          end
          if(not self:hasTasksSucceeded(otask .. "_pickup") ) then
            local etug = BuildObject("svhaul",2,("spawn_tug%d"):format(oindex));
            Pickup(etug,orelic);
            local sequencer = mission.TaskManager:sequencer(etug);
            sequencer:queue2("Dropoff",self.capture[otask]);
            --local function spawnInFormation2(formation,location,units,team,seperation)
            for i,v in pairs(mission.spawnInFormation2({"1 1 1 1 1"},("spawn_tug%d"):format(oindex),{"svfigh"},2,15)) do
              Defend2(v,orelic);
            end
          end
        end
      end
    end
    --If we have both relics this objective succeeds
    if(self:hasTasksSucceeded("relic1","relic2")) then
      self:success();
    end
  end,
  task_fail = function(self,name,first,a1,a2)
    if(self.otfs[name]) then
      UpdateObjective(self.otfs[name],"red");
    end
    if(name == "relic_nsdf_pickup" or name == "relic_cca_pickup") then
      --Enemy tug has relic, paint them
      SetObjectiveOn(a1);
      --Temporarly unpain the relic
      SetObjectiveOff(a2);
    end
    --Fail if both or either are captured?
    if(self:hasTasksFailed("relic1","relic2")) then
      self:fail(1);
    end
  end,
  save = function(self)
  end,
  load = function(self,...)
  end,
  success = function(self)
    SucceedMission(GetTime()+5);
  end,
  fail = function(self,condition)
    FailMission(GetTime()+5,self.fconditions[condition]);
  end
});

--Relic objective manager
--local relicManager = mission.Objective:define("reteriveRelic"):setListeners


function Start()
  SetScrap(1,8);
  --miss25setup();
  SetMaxHealth(GetHandle("abbarr2_barracks"),0);
  SetMaxHealth(GetHandle("abbarr3_barracks"),0);
  SetMaxHealth(GetHandle("abcafe3_i76building"),0);
  for h in AllCraft() do
    if (GetTeamNum(h) == 2) then
      Defend(h, 1);
    end
  end
  escortRecycler:start();
  --fetch = getRelics:start();

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