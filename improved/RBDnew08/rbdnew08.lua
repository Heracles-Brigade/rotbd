-- Battlezone: Rise of the Black Dogs, Black Dog Mission 28 written by General BlackDragon.


require("bz_logging");

local OOP = require("oop");
local mission = require("cmisnlib");
local buildAi = require("buildAi");
local core = require("bz_core");
local ProducerAi = buildAi.ProducerAi;
local ProductionJob = buildAi.ProductionJob;
local IsIn = OOP.isIn;


local introCinematic = mission.Objective:define("intoCinematic"):createTasks(
  "focus_comm1","focus_comm2","focus_comm3","focus_base","build_howiz"
):setListeners({
  init = function(self)
    self.next_tasks = {
      focus_comm1 = "focus_comm2",
      focus_comm2 = "focus_comm3",
      focus_comm3 = "focus_base"
    };
    self.comms = {
      GetHandle("comm1"),
      GetHandle("comm2"),
      GetHandle("comm3")
    };
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
  start = function(self)
    SetPilot(2,4);
    self.cam = CameraReady();
    self:startTask("focus_comm1");
    self:startTask("build_howiz");
  end,
  _forEachHowie = function(self,job,handle)
    Goto(handle,job:getLocation());
  end,
  _doneHowiz = function(self)
    self:taskSucceed("build_howiz");
  end,
  update = function(self,dtime)
    if(self.cam and CameraCancelled()) then
      self.cam = not CameraFinish();
    end
    for i=1, 3 do
      if(self:isTaskActive(("focus_comm%d"):format(i))) then
        if((not self.cam) or CameraPath(("pan_%d"):format(i),1500,1000,self.comms[i])) then
          self:taskSucceed(("focus_comm%d"):format(i));
        end
      end
    end
    if(self:isTaskActive("focus_base")) then
      if((not self.cam) or CameraPath("pan_4",1500,2000,GetHandle("ubtart0_i76building"))) then
        self:taskSucceed("focus_base");
      end
    end
  end,
  save = function()
    return {
      howizJobs = self.howizJobs,
      cam = self.cam
    };
  end,
  load = function(self,data)
    self.howizJobs = data.howizJobs;
    self.cam = data.cam;
    if(self.howizJobs) then
      self:call("_setUpProdListeners",self.howizJobs,"_forEachHowie","_doneHowiz");
    end
  end,
  task_start = function(self,name)
    if(name == "build_howiz") then
      self.howizJobs = ProducerAi:queueJobs2({
        ProductionJob("avartlf",2,GetPosition("base_artillery",0),1),
        ProductionJob("svartlf",2,GetPosition("base_artillery",1),1),
        ProductionJob("avartlf",2,GetPosition("base_artillery",2),1),
        ProductionJob("svartlf",2,GetPosition("base_artillery",3),1)
      });
      self:call("_setUpProdListeners",self.howizJobs,"_forEachHowie","_doneHowiz");
    end
  end,
  task_success = function(self,name)
    if(name == "focus_base") then
      if(self.cam) then
        self.cam = not CameraFinish();
      end
      mission.Objective:Start("misison");
    else
      self:startTask(self.next_tasks[name]);
    end
    if(self:hasTasksSucceeded("focus_base","build_howiz")) then
      self:success();
    end
  end,
  success = function(self)
  end
});

local avoidBase = mission.Objective:define("avoidBase"):createTasks(
  "warning", "wayTooClose"
):setListeners({
  start = function(self)
    AddObjective("rbd0804.otf");
    self:startTask("warning");
    self:startTask("wayTooClose");
  end,
  fail = function(self)
    UpdateObjective("rbd0804.otf","red");
    FailMission(GetTime() + 5.0, "rbd08l01.des");
  end,
  task_reset = function(self,name)
    if(name == "warning") then
      UpdateObjective("rbd0804.otf","white");
    end
  end,
  task_fail = function(self,name,first)
    if(name == "wayTooClose") then
      self:fail();
    elseif(name == "warning") then
      if(first) then
        --Warning audio
      end
      UpdateObjective("rbd0804.otf","dkyellow");
    end
  end,
  update = function(self)
    local d = GetDistance(GetPlayerHandle(),"base_warning");
    local l = Length(GetPosition("base_warning",1) - GetPosition("base_warning",0));
    if(self:isTaskActive("warning") and (d < l)) then
      self:taskFail("warning");
    elseif((d > l) and (not self:isTaskActive("warning"))) then
      self:taskReset("warning");
    end
    if(self:isTaskActive("wayTooClose")) then
      local d = GetDistance(GetPlayerHandle(),"base");
      local l = Length(GetPosition("base",1) - GetPosition("base",0));
      if d < l then
        self:taskFail("wayTooClose");
      end
    end
  end
});

local destroyComms = mission.Objective:define("misison"):createTasks(
  "destroyComms","wait","evacuate"
):setListeners({
  init = function(self)
    self.comms = {
      GetHandle("comm1"),
      GetHandle("comm2"),
      GetHandle("comm3")
    };
  end,
  task_start = function(self,name)
    if(name == "destroyComms") then
      AddObjective("rbd0801.otf");
    elseif(name == "wait") then
      self.wait_1 = 10;
      self.grigg = BuildObject("avtank",1,"spawn_griggs");
      SetObjectiveName(self.grigg, "Pvt. Grigg");
      Dropoff(self.grigg,GetPosition(self.grigg));
      --Spawn nsdf forces
      for i,v in pairs(mission.spawnInFormation2({"3","2 2 2 2","3 3","1"},"spawn_nsdf",{"avrckt","avtank","avhraz"},2)) do
        Attack(v,GetPlayerHandle());
      end
    elseif(name == "evacuate") then
      AddObjective("rbd0803.otf");
    end
  end,
  task_success = function(self,name)
    if(name == "destroyComms") then
      UpdateObjective("rbd0801.otf","green");
      self:startTask("wait");
    elseif(name == "wait") then
      self:startTask("evacuate");
    elseif(name == "evacuate") then
      UpdateObjective("rbd0803.otf","green");
      self:success();
    end
  end,
  task_fail = function(self,name)
    if(name == "destroyComms") then
      UpdateObjective("rbd0801.otf","red");
      self:fail();
    end
  end,
  start = function(self)
    for i, v in ipairs(self.comms) do
      SetObjectiveOn(v);
      SetObjectiveName(v,("Tower %d"):format(i));
    end
    self:startTask("destroyComms");
    self.timer = 60*8;
    StartCockpitTimer(self.timer,self.timer*0.5,self.timer*0.1);
  end,
  update = function(self,dtime)
    if(self:isTaskActive("destroyComms")) then
      if(mission.areAllDead(self.comms)) then
        self:taskSucceed("destroyComms");
      end
      self.timer = self.timer - dtime;
      if(self.timer < 0) then
        self:taskFail();
      end
    end
    if(self:isTaskActive("wait")) then
      self.wait_1 = self.wait_1 - dtime;
      if(self.wait_1 < 0) then
        self:taskSucceed("wait");
      end
    end
    if(self:isTaskActive("evacuate")) then
      if(IsWithin(GetPlayerHandle(),self.grigg,200)) then
        self:taskSucceed("evacuate");
      end
    end
  end,
  success = function(self)
    SucceedMission(GetTime()+5.0,"rbd08w01.des");
  end,
  fail = function(self)
    FailMission(GetTime()+5.0,"rbd08l02.des");
  end,
  save = function(self)
    return self.timer, self.wait_1, self.grigg;
  end,
  load = function(self,...)
    self.timer, self.wait_1, self.grigg = ...;
  end
});


function Start()
  introCinematic:start();
  avoidBase:start();
  for i = 1, 6 do
    BuildObject("avartl", 2, ("spawn_artl%d"):format(i));
  end
  SetPathLoop("walker1_path");
  SetPathLoop("walker2_path");
  Goto(GetHandle("avwalk1"),"walker1_path");
  Goto(GetHandle("avwalk2"),"walker2_path");
end
local pwers = {};
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