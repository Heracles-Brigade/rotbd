--Combination of The Last Stand and Evacuate Venus
--Contributors:
    --Jarle Trollebø(Mario)


require("bz_logging");
local core = require("bz_core");
local bzObjects = require("bz_objects");
local buildAi = require("buildAi");

local ConstructorAi = buildAi.ConstructorAi;
local ProducerAi = buildAi.ProducerAi;
local ProductionJob = buildAi.ProductionJob;

local mission = require('cmisnlib');

SetAIControl(2,false);
SetAIControl(3,false);


--First objective, go to base

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
    self:startTask("rendezvous");
    ProducerAi:queueJob(ProductionJob("bvcnst",3));
    ProducerAi:queueJobs(ProductionJob:createMultiple(2,"bvscav",3));
    ProducerAi:queueJob(ProductionJob("bvmuf",3));
    ProducerAi:queueJob(ProductionJob("bvslf",3));
    local turretJobs = {};
    --Tell AI to build turrets
    for i,v in pairs(GetPathPoints("make_turrets")) do
      table.insert(turretJobs,ProductionJob("bvturr",3,v,1));
    end
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
    bundle:forEach():subscribe(function(...)
      self:call(each,...);
    end);
    bundle:onFinish():subscribe(function(...)
      self:call(done,...);
    end);
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
    else
      self:success();
    end
  end,
  update = function(self,dtime)
    if(self:isTaskActive("rendezvous")) then
      if(IsWithin(GetPlayerHandle(),GetRecyclerHandle(3),100)) then
        self:taskSucceed("rendezvous");
      end
    end
  end,
  success = function(self)
    ClearObjectives();
  end,
  save = function(self)
    return {
      prodId = self.prodId,
      turrProd = self.turrProd
    };
  end,
  load = function(self,data)
    self.prodId = data.prodId;
    self.turrProd = data.turrProd;
    if(self.turrProd) then
      self:call("_setUpProdListeners",self.turrProd,"_forEachTurret","_doneTurret");
    end
    if(self:isTaskActive("wait_for_units")) then
      self:call("_setUpProdListeners",self.prodId,"_forEachProduced1","_doneProducing1");
    end
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