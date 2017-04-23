--Combination of The Last Stand and Evacuate Venus
--Contributors:
    --Jarle Trollebø(Mario)

local pwers = {};

require("bz_logging");
local core = require("bz_core");
local bzObjects = require("bz_objects");
local buildAi = require("buildAi");
local bzRoutine = require("bz_routine");

local ConstructorAi = buildAi.ConstructorAi;
local ProducerAi = buildAi.ProducerAi;
local ProductionJob = buildAi.ProductionJob;
local PatrolController = require("patrolc");
local mission = require('cmisnlib');

SetAIControl(2,false);
SetAIControl(3,false);


--First objective, go to base, get unit, etc
local intro = mission.Objective:define("introObjective"):createTasks(
  "rendezvous","wait_for_units","goto_relic"
):setListeners({
  init = function(self)
    self.otfs = {
      rendezvous = "rbd0521.otf",
      wait_for_units = "rbd0522.otf",
      goto_relic = "rbd0523.otf"
    };
    self.next = {
      rendezvous = "wait_for_units",
      wait_for_units = "goto_relic"
    };
  end,
  start = function(self)
    local patrol_rid, patrol_r = bzRoutine.routineManager:startRoutine("PatrolRoutine");
    patrol_r:registerLocations({"l_command","l_center","l_north","l_front"});
    patrol_r:defineRouts("l_command",{
      p_command_center = "l_center"
    });
    patrol_r:defineRouts("l_center",{
      p_center_front = "l_front",
      p_center_north = "l_north"
    });
    patrol_r:defineRouts("l_front",{
      p_front_command = "l_command",
      p_front_patrol_command = "l_command"
    });
    patrol_r:defineRouts("l_north",{
      p_north_center = "l_center"
    });
    self.patrol_id = patrol_rid;
    self:startTask("rendezvous");
    self.endWait = 7;
    ProducerAi:queueJob(ProductionJob("bvcnst",3));
    ProducerAi:queueJobs(ProductionJob:createMultiple(2,"bvscav",3));
    ProducerAi:queueJob(ProductionJob("bvslf",3));
    ProducerAi:queueJob(ProductionJob("bvmuf",3));
    local turretJobs = {};
    --Tell AI to build turrets
    for i,v in pairs(GetPathPoints("make_turrets")) do
      table.insert(turretJobs,ProductionJob("bvturr",3,v,1));
    end
    --Tell AI to build patrol units
    local tankJobs = {ProductionJob:createMultiple(3,"bvtank",3)};
    local scoutJobs = {ProductionJob:createMultiple(3,"bvraz",3)};

    self.patrolProd = ProducerAi:queueJobs2(tankJobs,scoutJobs);
    self:call("_setUpProdListeners",self.patrolProd,"_forEachPatrolUnit","_donePatrolUnit");

    for i,v in pairs(GetPathPoints("make_bblpow")) do
      ProducerAi:queueJob(ProductionJob("bblpow",3,v),0);
    end
    for i,v in pairs(GetPathPoints("make_bbtowe")) do
      ProducerAi:queueJob(ProductionJob("bbtowe",3,v),1);
    end
    ProducerAi:queueJob(ProductionJob("bbcomm",3,"make_bbcomm"));
    
    self.turrProd = ProducerAi:queueJobs2(turretJobs);
    --Set up observing for turrets, when produced _forEachTurret will run
    self:call("_setUpProdListeners",self.turrProd,"_forEachTurret","_doneTurret");
    --Set up tasks for constructor
  end,
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
    SetTeamNum(handle,1);
  end,
  _doneProducing1 = function(self,bundle,handle)
    self:taskSucceed("wait_for_units");
  end,
  _forEachTurret = function(self,job,handle)
    --Turret was made, tell him to go to the location specified in the job
    Goto(handle,job:getLocation());
  end,
  _forEachPatrolUnit = function(self,job,handle)
    local patrol_r = bzRoutine.routineManager:getRoutine(self.patrol_id);
    patrol_r:addHandle(handle);
  end,
  task_start = function(self,name)
    if(self.otfs[name]) then
      AddObjective(self.otfs[name]);
    end
    if(name == "wait_for_units") then
      --Make producer create units
      --               ProductionJob:createMultiple(count,odf,team)
      local tankJobs = {ProductionJob:createMultiple(3,"bvtank",3)};
      local rcktJobs = {ProductionJob:createMultiple(2,"bvrckt",3)};
      local scoutJobs = {ProductionJob:createMultiple(2,"bvraz",3)}; 
      self.prodId = ProducerAi:queueJobs2(tankJobs,rcktJobs,scoutJobs);
      self:call("_setUpProdListeners",self.prodId,"_forEachProduced1","_doneProducing1");
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
    return {
      prodId = self.prodId,
      turrProd = self.turrProd,
      endWait = self.endWait,
      patrol_id = self.patrol_id,
      patrolProd = self.patrolProd
    };
  end,
  load = function(self,data)
    self.prodId = data.prodId;
    self.turrProd = data.turrProd;
    self.endWait = data.endWait;
    self.patrol_id = data.patrol_id;
    self.patrolProd = data.patrolProd;
    if(self.turrProd) then
      self:call("_setUpProdListeners",self.turrProd,"_forEachTurret","_doneTurret");
    end
    if(self.patrolProd) then
    self:call("_setUpProdListeners",self.patrolProd,"_forEachPatrolUnit","_donePatrolUnit");
    end
    if(self:isTaskActive("wait_for_units")) then
      self:call("_setUpProdListeners",self.prodId,"_forEachProduced1","_doneProducing1");
    end
  end
});

local defendRelic = mission.Objective:define("defendRelic"):createTasks(
  "destroy_relic","nuke","return_to_base"
):setListeners({
  init = function(self)
    self.next = {
      destroy_relic = "nuke",
      nuke = "return_to_base"
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
    self:startTask("destroy_relic");
    self.wait_while_shooting = 2;
    self.patrol_id = patrol_id;
    self.t = 0;
  end,
  task_start = function(self,name)
    if(name == "destroy_relic") then
      AddObjective("rbd0524.otf");
    elseif(name == "nuke") then
      AddObjective("rbd0525.otf");
      self.dayId = ProducerAi:queueJob(ProductionJob("apwrckz",3,self.relic));
      self:call("_setUpProdListeners",self.dayId,"_setDayWrecker");
      local units, lead = mission.spawnInFormation2({"   1   "," 22222 ", "3333333"},"cca_relic_attack",{"svtank","svrckt","svfigh"},2,15);
      for i, v in pairs(units) do
        if(v ~= lead) then
          Defend2(v,lead);
        end
        local s = mission.TaskManager:sequencer(v);
        s:queue2("Goto","cca_relic_attack");
        s:queue2("Defend");
      end
    end
  end,
  _setDayWrecker = function(self,job,handle)
    SetMaxHealth(handle,0);
    self.daywrecker = handle;
  end,
  task_fail = function(self,name)
    self:fail();
  end,
  task_success = function(self,name)
    if(name == "destroy_relic") then
      UpdateObjective("rbd0524.otf","red");
    end
    if(self.next[name]) then
      self:startTask(self.next[name]);
    end
  end,
  update = function(self,dtime)
    self.t = self.t + dtime;
    if(self:isTaskActive("destroy_relic")) then
      if(GetWhoShotMe(self.relic) == GetPlayerHandle()) then
        self.wait_while_shooting = self.wait_while_shooting - dtime;
      end
      if(self.wait_while_shooting <= 0) then
        self:taskSucceed("destroy_relic");
      end
    elseif(self:isTaskActive("nuke")) then
      if(not IsValid(self.daywrecker) and self.daywrecker) then
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
      patrol_id = self.patrol_id
    };
  end,
  load = function(self,data)
    self.wait_while_shooting = data.wait1;
    self.daywrecker = data.daywrecker;
    self.patrol_id = data.patrol_id;
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
  intro:start();

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
  if(l == "ammopack" or l == "repairkit" or l == "daywrecker" or l == "wpnpower") then
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