-- Battlezone: Rise of the Black Dogs, Black Dog Mission 28 written by General BlackDragon.


require("bz_logging");

local OOP = require("oop");
local mission = require("cmisnlib");
local buildAi = require("buildAi");
local core = require("bz_core");
local misc = require("misc");
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
  save = function(self)
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
      UpdateObjective("rbd0804.otf","yellow");
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
      GetHandle("power1"),
      GetHandle("power2"),
      GetHandle("power3"),
      GetHandle("abtowe3_turret"),
      GetHandle("abtowe2_turret")
    };
  end,
  task_start = function(self,name)
    if(name == "destroyComms") then
      AddObjective("rbd0801.otf");
    elseif(name == "wait") then
      self.wait_1 = 45;
      self.grigg = BuildObject("avtank",1,"spawn_griggs");
      self.grigg_t = false;
      SetObjectiveName(self.grigg, "Pvt. Grigg");
      SetObjectiveOn(self.grigg);
      --Dropoff(self.grigg,GetPosition(self.grigg));
      local s = mission.TaskManager:sequencer(self.grigg);
      local pp = GetPathPoints("grigg_in");
      SetIndependence(self.grigg,0);
      s:queue2("Goto","grigg_in");
      s:queue2("Dropoff",pp[#pp]);
      --Spawn nsdf forces
      for i,v in pairs(mission.spawnInFormation2({"3","2 2 2 2","3 3","1"},"spawn_nsdf",{"avrckt","avtank","avhraz"},2)) do
        local s2 = mission.TaskManager:sequencer(v);
        s2:queue2("Attack",GetPlayerHandle());
        s2:queue2("Attack",self.grigg);
      end
    elseif(name == "evacuate") then
      AddObjective("rbd0803.otf");
    end
  end,
  task_success = function(self,name)
    if(name == "destroyComms") then
      UpdateObjective("rbd0801.otf","green");
      StopCockpitTimer();
      HideCockpitTimer();
      self:startTask("wait");
    elseif(name == "wait") then
      Goto(self.grigg,"grigg_out");
      RemoveObjective("rbd0801i.otf");
      AddObjective("rbd0802i.otf","green");
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
    else
      self:fail("grigg");
    end
  end,
  start = function(self)
    SetObjectiveOn(self.comms[1]);
    for i, v in ipairs(self.comms) do
      if(IsBuilding(v)) then
        SetObjectiveName(v,("Power %d"):format(i));
      else
        SetObjectiveName(v,("Gun Tower"):format(i));
      end
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
      if(not IsAlive(self.grigg)) then
        self:taskFail("wait");
      end
      if(not self.grigg_t) then
        local pp = GetPathPoints("grigg_in");
        local d = Length(GetPosition(self.grigg)-pp[#pp]);
        if(d < 50) then
          self.grigg_t = true;
          AddObjective("rbd0801i.otf");
        end
      end
    end
    if(self:isTaskActive("evacuate")) then
      local d1 = Length(GetPosition(GetPlayerHandle()) - GetPosition("spawn_griggs"));
      local d2 = Length(GetPosition(self.grigg) - GetPosition("spawn_griggs"));
      print(d1,d2);
      if(d1 < 100 and d2 < 100) then
        self:taskSucceed("evacuate");
      end
      if(not IsAlive(self.grigg)) then
        self:taskFail("evacuate");
      end  
    end
  end,
  success = function(self)
    SucceedMission(GetTime()+5.0,"rbd08w01.des");
  end,
  delete_object = function(self,handle)
    local m = nil;
    for i=1, 2 do
      if(self.comms[i] == handle) then
        m = {self.comms[i+1]};
        break;
      end
    end
    if(self.comms[3] ==  handle) then
      m = {self.comms[4],self.comms[5]};
    end
    if(m) then
      for i, v in pairs(m) do
        SetObjectiveOn(v);
      end
    end
  end,
  fail = function(self,what)
    if(what == "grigg") then
      FailMission(GetTime()+5.0,"rbd08l05.des");
    else
      FailMission(GetTime()+5.0,"rbd08l02.des");
    end
  end,
  save = function(self)
    return self.timer, self.wait_1, self.grigg, self.grigg_t;
  end,
  load = function(self,...)
    self.timer, self.wait_1, self.grigg, self.grigg_t = ...;
  end
});


function Start()
  core:onStart();
  introCinematic:start();
  avoidBase:start();
  for i = 1, 6 do
    BuildObject("avartl", 2, ("spawn_artl%d"):format(i));
  end
  SetPathLoop("walker1_path");
  SetPathLoop("walker2_path");
  Goto(GetHandle("avwalk1"),"walker1_path");
  Goto(GetHandle("avwalk2"),"walker2_path");
  for i = 1, 4 do
    local nav = GetHandle("nav" .. i);
    if i == 4 then
      SetObjectiveName(nav, "Pickup Zone");
    else
      SetObjectiveName(nav, "Navpoint " .. i);
    end
    SetMaxHealth(nav, 0);
  end
  for i = 1, 3 do
    local comm = GetHandle("comm" .. i);
    SetMaxHealth(comm, 0); -- These can't be killed.
  end
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