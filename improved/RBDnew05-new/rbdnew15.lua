--Combination of The Last Stand and Evacuate Venus
--Contributors:
    --Jarle Trollebø(Mario)

local pwers = {};

require("bz_logging");
local orig15setup = require("orig15p");
local core = require("bz_core");
local OOP = require("oop");
local buildAi = require("buildAi");
local bzRoutine = require("bz_routine");


local IsIn = OOP.isIn;
local ConstructorAi = buildAi.ConstructorAi;
local ProducerAi = buildAi.ProducerAi;
local ProductionJob = buildAi.ProductionJob;
local PatrolController = require("patrolc");
local mission = require('cmisnlib');

SetAIControl(2,false);
SetAIControl(3,false);

--[[
TODO:
  * add fail for leaving relic too early
  * might be better to check relics health instead of using GetWhoShotMe
]]

local audio = {
  intro = "rbd0501.wav",
  inspect = "rbd0502.wav",
  destroy_f = "rbd0503.wav",
  done_d = "rbd0504.wav",
  back_to_base = "rbd0505.wav"
}

--First objective, go to base, get unit and investigate relic site
local intro = mission.Objective:define("introObjective"):createTasks(
  "rendezvous","wait_for_units","goto_relic"
):setListeners({
  init = function(self)
    --otfs for each task
    self.otfs = {
      rendezvous = "rbd0521.otf",
      wait_for_units = "rbd0522.otf",
      goto_relic = "rbd0523.otf"
    };
    --next task, for each task
    --objective succeeded after goto_relic is completed
    self.next = {
      rendezvous = "wait_for_units",
      wait_for_units = "goto_relic"
    };
  end,
  start = function(self)
    --Set up patrol paths
    local patrol_rid, patrol_r = bzRoutine.routineManager:startRoutine("PatrolRoutine");
    --what are our `checkpoint` locations?
    patrol_r:registerLocations({"l_command","l_center","l_north","l_front"});
    --l_command connects to l_center via p_command_center path
    patrol_r:defineRouts("l_command",{
      p_command_center = "l_center"
    });
    --l_center connects to both l_front and l_north via p_center_front and p_center_north
    patrol_r:defineRouts("l_center",{
      p_center_front = "l_front",
      p_center_north = "l_north"
    });
    --l_front connects to l_command via either p_front_command or p_front_patrol_command
    patrol_r:defineRouts("l_front",{
      p_front_command = "l_command",
      p_front_patrol_command = "l_command"
    });
    --l_north only connects to l_center via p_north_center, slightly redundant, but there in case more paths are added
    patrol_r:defineRouts("l_north",{
      p_north_center = "l_center"
    });
    --set patrol_id
    self.patrol_id = patrol_rid;
    --Start first task, go to base
    self:startTask("rendezvous");
    self.endWait = 7;
    --Let us queue some production jobs for Shaw to do
    ProducerAi:queueJob(ProductionJob("bvcnst",3));
    ProducerAi:queueJobs(ProductionJob:createMultiple(2,"bvscav",3));
    ProducerAi:queueJob(ProductionJob("bvslf",3));
    ProducerAi:queueJob(ProductionJob("bvmuf",3));
    
    self.relic_camera_id = ProducerAi:queueJobs(ProductionJob("apcamr",3,"relic_site"));
    self:call("_setUpProdListeners",self.relic_camera_id,"_forCamera");
    
    local turretJobs = {};
    --Tell AI to build turrets
    for i,v in pairs(GetPathPoints("make_turrets")) do
      table.insert(turretJobs,ProductionJob("bvturr",3,v,1));
    end
    --Tell AI to build patrol units, 3 tanks and 3 fighters
    local tankJobs = {ProductionJob:createMultiple(3,"bvtank",3)};
    local scoutJobs = {ProductionJob:createMultiple(3,"bvraz",3)};
    
    self.patrolProd = ProducerAi:queueJobs2(tankJobs,scoutJobs);
    --Set up observer for patrol Production
    self:call("_setUpProdListeners",self.patrolProd,"_forEachPatrolUnit","_donePatrolUnit");
    --Tell AI to build some guntowers for defence and a commtower
    for i,v in pairs(GetPathPoints("make_bblpow")) do
      ProducerAi:queueJob(ProductionJob("bblpow",3,v),0);
    end
    for i,v in pairs(GetPathPoints("make_bbtowe")) do
      ProducerAi:queueJob(ProductionJob("bbtowe",3,v),1);
    end
    ProducerAi:queueJob(ProductionJob("bbcomm",3,"make_bbcomm"));
    self.turrProd = ProducerAi:queueJobs2(turretJobs);
    --Set up observer for turrets, when produced _forEachTurret will run
    self:call("_setUpProdListeners",self.turrProd,"_forEachTurret","_doneTurret");

  end,
  --Helper function for connecting production job to observers
  _setUpProdListeners = function(self,id,each,done)
    local bundle = ProducerAi:getBundle(id);
    if(bundle) then
      bundle:forEach():subscribe(function(...)
        self:call(each,...);
      end);
      bundle:onFinish():subscribe(function(...)
        self:call(done,...);
      end);
    end
  end,
  _forEachProduced1 = function(self,job,handle)
    --For each unit produced for the player, set the team number to 1
    SetTeamNum(handle,1);
  end,
  _doneProducing1 = function(self,bundle,handle)
    --When all the player's units have been made, succeed wait_for_units
    self:taskSucceed("wait_for_units");
  end,
  _forEachTurret = function(self,job,handle)
    --Turret was made, tell him to go to the location specified in the job
    Goto(handle,job:getLocation());
  end,
  _forEachPatrolUnit = function(self,job,handle)
    --For each unit produced in order to patrol the base, add them to the patrol routine
    local patrol_r = bzRoutine.routineManager:getRoutine(self.patrol_id);
    patrol_r:addHandle(handle);
  end,
  _forCamera = function(self,job,handle)
    SetObjectiveName(handle,"Relic Site");
    self.camera_handle = handle;
    if(self:isTaskActive("goto_relic")) then
      SetTeamNum(self.camera_handle,1);
    end
  end,
  task_start = function(self,name)
    if(self.otfs[name]) then
      AddObjective(self.otfs[name]);
    end
    if(name == "wait_for_units") then
      --Make producer create units
      --ProductionJob:createMultiple(count,odf,team)
      --Queue Production Jobs for the player
      local tankJobs = {ProductionJob:createMultiple(3,"bvtank",3)};
      local rcktJobs = {ProductionJob:createMultiple(2,"bvrckt",3)};
      local scoutJobs = {ProductionJob:createMultiple(2,"bvraz",3)}; 
      self.prodId = ProducerAi:queueJobs2(tankJobs,rcktJobs,scoutJobs);
      self:call("_setUpProdListeners",self.prodId,"_forEachProduced1","_doneProducing1");
    elseif(name == "goto_relic") then
      SetTeamNum(self.camera_handle,1);
      AudioMessage(audio.intro);
    end
  end,
  task_success = function(self,name)
    if(self.otfs[name]) then
      UpdateObjective(self.otfs[name],"green");
    end
    if(self.next[name]) then
      self:startTask(self.next[name]);
    end
  end,
  update = function(self,dtime)
    if(self:isTaskActive("rendezvous")) then
      if(IsWithin(GetPlayerHandle(),GetRecyclerHandle(3),100)) then
        self:taskSucceed("rendezvous");
      end
    elseif(self:isTaskActive("goto_relic")) then
      if(IsInfo("hbcrys")) then
        self:taskSucceed("goto_relic");
      end
    elseif(not self:isTaskActive("wait_for_units")) then
      self.endWait = self.endWait - dtime;
      if(self.endWait <= 0) then
        self:success();
      end
    end
  end,
  success = function(self)
    ClearObjectives();
    mission.Objective:Start("defendRelic",self.patrol_id);
  end,
  save = function(self)
    --Save a bunch of stuff
    return {
      prodId = self.prodId,
      turrProd = self.turrProd,
      endWait = self.endWait,
      patrol_id = self.patrol_id,
      patrolProd = self.patrolProd,
      relic_camera_id = self.relic_camera_id,
      camera_handle = self.camera_handle
    };
  end,
  load = function(self,data)
    --Load a bunch of stuff
    self.prodId = data.prodId;
    self.turrProd = data.turrProd;
    self.endWait = data.endWait;
    self.patrol_id = data.patrol_id;
    self.patrolProd = data.patrolProd;
    self.relic_camera_id = data.relic_camera_id;
    self.camera_handle = data.camera_handle;
    if(self.turrProd) then
      self:call("_setUpProdListeners",self.turrProd,"_forEachTurret","_doneTurret");
    end
    if(self.patrolProd) then
      self:call("_setUpProdListeners",self.patrolProd,"_forEachPatrolUnit","_donePatrolUnit");
    end
    if(self:isTaskActive("wait_for_units")) then
      self:call("_setUpProdListeners",self.prodId,"_forEachProduced1","_doneProducing1");
    end
    if(self.relic_camera_id) then
      self:call("_setUpProdListeners",self.relic_camera_id,"_forCamera");
    end
  end
});

local defendRelic = mission.Objective:define("defendRelic"):createTasks(
  "destroy_relic","cca_attack_base","nuke"
):setListeners({
  init = function(self)
    self.next = {
      destroy_relic = "nuke"
    };
    self.otfs = {
      destroy_relic = "rbd0524.otf",
      nuke = "rbd0525.otf"
    };
    self.failCauses = {

    };
    self.relic = GetHandle("relic_1");
  end,
  _setUpProdListeners = function(self,id,done)
    local job = ProducerAi:getJob(id);
    if(job) then
      job:onFinish():subscribe(function(...)
        self:call(done,...);
      end);
    end
  end,
  start = function(self,patrol_id)
    self.patrol_id = patrol_id;
    self.wait_while_shooting = 2;
    self.nuke_wait_t1 = 5;
    self.nuke_wait_t2 = 2;
    self.nuke_state = 0;
    self.t = 0;
    self:startTask("destroy_relic");
    AudioMessage(audio.inspect);
  end,
  task_start = function(self,name)
    if(self.otfs[name]) then
      AddObjective(self.otfs[name]);
    end
    if(name == "nuke") then
      self.day_id = ProducerAi:queueJob(ProductionJob("apwrckz",3,self.relic));
      self:call("_setUpProdListeners",self.day_id,"_setDayWrecker");
      local units, lead = mission.spawnInFormation2({"   1   "," 22222 ", "3333333"},"cca_relic_attack",{"svtank","svrckt","svfigh"},2,15);
      for i, v in pairs(units) do
        if(v ~= lead) then
          Defend2(v,lead);
        end
        local s = mission.TaskManager:sequencer(v);
        s:queue2("Goto","cca_relic_attack");
        s:queue2("Defend");
      end
    elseif(name == "cca_attack_base") then
      local patrol = bzRoutine.routineManager:getRoutine(self.patrol_id);
      for i,v in pairs(patrol:getHandles()) do
        Defend(v);
      end
      bzRoutine.routineManager:killRoutine(self.patrol_id);
      self.attack_timers = {30,15,5};
      self.attack_waves = {
        {loc = "base_attack2",formation={"4 4 4","1 1 1"}},
        {loc = "base_attack2",formation={"2 2 3","1 5 1"}},
        {loc = "base_attack1",formation={"4 4 4","1 1 1"}}
      };
      self.attack_timer = nil;
    end
  end,
  _setDayWrecker = function(self,job,handle)
    SetMaxHealth(handle,0);
    SetObjectiveOn(handle);
    self.daywrecker = handle;
  end,
  task_fail = function(self,name)
    if(name == "nuke") then
      UpdateObjective(self.otfs[name],"red");
    end
    self:fail();
  end,
  task_success = function(self,name)
    if(name == "destroy_relic") then
      UpdateObjective("rbd0524.otf","red");
    elseif(name == "nuke") then
      ClearObjectives();
      self:success();
    end
    if(self.next[name]) then
      self:startTask(self.next[name]);
    end
  end,
  fail = function(self,cause)
    FailMission(GetTime()+5.0,self.failCauses[cause or "NONE"]);
  end,
  success = function(self)
    mission.Objective:Start("rtbAssumeControl");
  end,
  update = function(self,dtime)
    if(self:isTaskActive("cca_attack_base")) then
      if(self.attack_timer == nil) then
        if(#self.attack_timers <= 0) then
          self:taskSucceed("cca_attack_base");
        else
          self.attack_timer = table.remove(self.attack_timers,1);
        end
      end
      if(self.attack_timer ~= nil) then
        self.attack_timer = self.attack_timer - dtime;
        if(self.attack_timer <= 0) then
          --spawn an attack wave
          local wave = table.remove(self.attack_waves,1);
          for i,v in pairs(mission.spawnInFormation2(wave.formation,wave.loc,{"svfigh","svtank","svrckt","svhraz","svltnk"},2,15)) do
            Goto(v,wave.loc);
          end
          self.attack_timer = nil;
        end
      end
    end
    if(self:isTaskActive("destroy_relic")) then
      if((GetMaxHealth(self.relic) - GetCurHealth(self.relic) >= 1000) and (not self:hasTaskStarted("cca_attack_base"))) then
        self:startTask("cca_attack_base");
        self.destroy_audio = AudioMessage(audio.destroy_f);
      elseif(self:hasTaskStarted("cca_attack_base") and ((not self.destroy_audio) or IsAudioMessageDone(self.destroy_audio))) then
        self:taskSucceed("destroy_relic");
      end
    elseif(self:isTaskActive("nuke")) then
      if(IsAlive(GetPlayerHandle()) and (self.nuke_state < 4) and (GetDistance(GetPlayerHandle(),"relic_site") > 200)) then
        RemoveObjective(self.nuke_state < 2 and "rbd0530.otf" or "rbd0531.otf");
        AddObjective("rbd0533.otf","red");
        self:taskFail("nuke");
        self.nuke_state = 4;
      else
        if(self.nuke_state == 0) then
          self.nuke_wait_t1 = self.nuke_wait_t1 - dtime;
          if(self.nuke_wait_t1 <= 0) then
            AddObjective("rbd0530.otf");
            self.nuke_state = 1;
          end
        elseif(self.nuke_state == 1) then
          self.nuke_wait_t2 = self.nuke_wait_t2 - dtime;
          if(self.nuke_wait_t2 <= 0) then
            RemoveObjective("rbd0530.otf");
            AddObjective("rbd0531.otf");
            self.nuke_state = 3;
          end
        elseif(self.nuke_state == 3) then
          if(Length(GetPosition(self.daywrecker) - GetPosition(self.relic)) < 50) then
            RemoveObjective(self.nuke_state < 2 and "rbd0530.otf" or "rbd0531.otf");
            AddObjective("rbd0534.otf","green");
            AudioMessage(audio.done_d);
            self.nuke_state = 5;
          end
        end
      end
      if(not IsValid(self.daywrecker) and self.daywrecker) then
        print(IsValid(self.relic));
        if(not IsValid(self.relic)) then
          self:taskSucceed("nuke");
        else
          self:taskFail("nuke");
        end
      end
    end
  end,
  save = function(self)
    return {
      wait1 = self.wait_while_shooting,
      daywrecker = self.daywrecker,
      patrol_id = self.patrol_id,
      attack_waves = self.attack_waves,
      attack_timer = self.attack_timer,
      attack_timers = self.attack_timers,
      day_id = self.day_id,
      nuke_wait_t1 = 5,
      nuke_wait_t2 = 2,
      nuke_state = self.nuke_state,
      destroy_audio = self.destroy_audio
    };
  end,
  load = function(self,data)
    self.wait_while_shooting = data.wait1;
    self.daywrecker = data.daywrecker;
    self.patrol_id = data.patrol_id;
    self.attack_waves = data.attack_waves;
    self.attack_timer = data.attack_timer;
    self.attack_timers = data.attack_timers;
    self.day_id = data.day_id;
    self.nuke_wait_t1 = data.nuke_wait_t1;
    self.nuke_wait_t2 = data.nuke_wait_t2;
    self.nuke_state = data.nuke_state;
    self.destroy_audio = data.destroy_audio;
    self:call("_setUpProdListeners",self.day_id,"_setDayWrecker");
  end
});

local RtbAssumeControl = mission.Objective:define("rtbAssumeControl"):createTasks(
  "fix_base", "reclaim"
):setListeners({
  init = function(self)
  end,
  start = function(self)
    AddObjective("rbd0532.otf");
    self:startTask("fix_base");
    self.waitToSuccess = 5;
  end,
  success = function(self)
    AudioMessage(audio.back_to_base);
    ClearObjectives();
    orig15setup();
  end,
  update = function(self,dtime)
    if(self:isTaskActive("reclaim")) then
      self.waitToSuccess = self.waitToSuccess - dtime;
      if(self.waitToSuccess <= 0) then
        self:taskSucceed("reclaim");
        self:success();
      end 
    end
    if((not self:hasTaskStarted("reclaim")) and GetDistance(GetPlayerHandle(),"bdog_base") < 200) then 
      self:startTask("reclaim");
    end
    if(self:isTaskActive("fix_base") and GetDistance(GetPlayerHandle(),"bdog_base") < 700) then 
      --wait a bit, success
      local hasComm = false;
      for v in ObjectsInRange(400,"bdog_base") do
        if((GetTeamNum(v) == 2) or (GetTeamNum(v) == 3 and (not IsBuilding(v) ))) then
          Damage(v,100000);
        elseif(GetTeamNum(v) == 3) then
          SetTeamNum(v,1);
        end
      end
      self:taskSucceed("fix_base");
    end
  end,
  save = function(self)
    return self.waitToSuccess;
  end,
  load = function(self,...)
    self.waitToSuccess = ...;
  end
});



function Start()
  core:onStart();
  SetPilot(1,5);
  SetScrap(1,8);
  Ally(1,3);
  SetMaxHealth(GetHandle("abbarr2_barracks"),0);
  SetMaxHealth(GetHandle("abbarr3_barracks"),0);
  SetMaxHealth(GetHandle("abcafe3_i76building"),0);
  SetMaxScrap(3,5000);
  SetScrap(3,2000);
  SetMaxPilot(3,5000);
  SetPilot(3,1000);
  local h = GetHandle("relic_1");
  SetMaxHealth(h,900000);
  SetCurHealth(h,900000); 
  intro:start();
  for i = 1, 13 do
    Patrol(GetHandle("patrol_" .. i), "patrol_path");
  end
  --ConstructorAi:addFromPath("make_bblpow",3,"bblpow");
end

function Update(dtime)
  core:update(dtime);
  mission:Update(dtime);
  for i,v in pairs(pwers) do
    if GetCurrentCommand(v.h) == AiCommand["GO"] then
      SetTeamNum(v.h,v.t);
      pwers[i] = nil;
    end
  end
end

function CreateObject(handle)
  core:onCreateObject(handle);
  mission:CreateObject(handle);
  local l = GetClassLabel(handle);
  if(IsIn(l,{"ammopack","repairkit","daywrecker","wpnpower","camerapod"})) then
    table.insert(pwers,{h=handle,t=GetTeamNum(handle)});
    SetTeamNum(handle,1);
  end
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