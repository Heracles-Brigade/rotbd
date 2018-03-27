
local _ = require("bz_logging");

local OOP = require("oop");
local mission = require("cmisnlib");
local buildAi = require("buildAi");
local core = require("bz_core");
local misc = require("misc");
local ProducerAi = buildAi.ProducerAi;
local ProductionJob = buildAi.ProductionJob;
local IsIn = OOP.isIn;



local audio = {
  intro = "rbd0801.wav",
  -- after tower 1 is down
  tower1 = "rbd0802.wav",
  --(Grigg’s updates, interspersed throughout)
  grigg_updates = {"rbdnew0820.wav", "rbdnew0821.wav", "rbdnew0822.wav"},

  -- after tower 2 is down
  tower2 = "rbd0803.wav",
  --going_in = "rbd0804.wav", replaced by rbd0802.wav
  evacuate = "rbd0805.wav",
  timer_out = "rbd0806.wav",
  timer_out_loss = "rbd0802L.wav",
  one_minute = "rbd0807.wav",
  too_close_loss = "rbd0801L.wav",

}

function GriggAtGt(handle,sequencer)
  sequencer:push2("Goto", "grigg_out");
  -- Make all base units hunt grigg
  local l = Length(GetPosition("base_warning",1) - GetPosition("base_warning",0));
  for obj in ObjectsInRange(l, "base_warning") do
    if(GetTeamNum(obj) == 2 and IsCraft(obj) and not (CanBuild(obj))) then
      Attack(obj, handle);
    end
  end
end

-- Objectives
local introCinematic;
local avoidBase;
local destroyComms;
local evac;


introCinematic = mission.Objective:define("intoCinematic"):createTasks(
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
    AudioMessage(audio.intro);
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
      if((not self.cam) or CameraPath("pan_4",500,2000,GetHandle("ubtart0_i76building"))) then
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

avoidBase = mission.Objective:define("avoidBase"):createTasks(
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





destroyComms = mission.Objective:define("misison"):createTasks(
  "destroyComms", "startEvac"
):setListeners({
  init = function(self)
    self.comms = {
      GetHandle("power1"),
      GetHandle("power2"),
      GetHandle("power3")
    };
    self.audio = {
      audio.tower1,
      audio.tower2
    };
    self.grigg_audio = audio.grigg_updates;
  end,
  _spawnGrigg = function(self)
    self.grigg = BuildObject("avtank",1,"spawn_griggs");
    SetObjectiveName(self.grigg, "Pvt. Grigg");
    SetObjectiveOn(self.grigg);
    local s = mission.TaskManager:sequencer(self.grigg);
    local pp = GetPathPoints("grigg_in");
    SetIndependence(self.grigg,0);
    SetPerceivedTeam(self.grigg,2);
    s:queue2("Goto","grigg_in");
    s:queue2("Dropoff",pp[#pp]);
    self.grigg_spawned = true;
    self.grigg_next = 55 + math.random(10);
  end,
  _nextGriggAudio = function(self)
    self.curr_grigg = self.curr_grigg + 1;
    AudioMessage(self.grigg_audio[self.curr_grigg]);
    self.grigg_next = (self.curr_grigg < #self.grigg_audio) and 20 + math.random(20) or math.huge;
    print(("Grigg audio playing #%d"):format(self.curr_grigg), self.grigg_next);
  end,
  task_start = function(self,name)
    if(name == "destroyComms") then
      self.timerOut = false;
      AddObjective("rbd0801.otf");
    elseif(name == "wait") then

    elseif(name == "startEvac") then
      evac:start(self.grigg, self.timerOut, self.comms[3]);
    end
  end,
  task_success = function(self, name)
    if(name == "destroyComms") then
      UpdateObjective("rbd0801.otf","green");
      StopCockpitTimer();
      HideCockpitTimer();
      if(not self:isTaskActive("startEvac")) then
        self:startTask("startEvac");
      end
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
    self.curr_grigg = 0;
    self.grigg_next = 0;
    self.grigg_spawned = false;
    SetObjectiveOn(self.comms[1]);
    for i, v in ipairs(self.comms) do
      SetObjectiveName(v,("Power %d"):format(i));
    end
    self:startTask("destroyComms");
    self.timer = 20;--60*8;
    self.nextAudio = 0;
    StartCockpitTimer(self.timer,self.timer*0.5,self.timer*0.1);
  end,
  update = function(self,dtime)
    if(self:isTaskActive("destroyComms")) then
      local dead = mission.countDead(self.comms);
      self.timer = self.timer - dtime;
      if(not self.grigg_spawned and dead >= 1) then
        self:call("_spawnGrigg");
      end
      if(dead >= #self.comms) then
        self:taskSucceed("destroyComms");
      end
      
      if(self.timer <= 0) then
        if(not self.timerOut) then
          self.timerOut = true;
          if(mission.countAlive(self.comms) > 1) then
            self:taskFail("destroyComms");
          else -- One tower left when time runs out, player does not fail
            HideCockpitTimer();
            -- Play audio message
            AudioMessage(audio.timer_out);
            if(not self:isTaskActive("startEvac")) then
              self:startTask("startEvac");
            end
          end
        end
      end
    end

    if(self.grigg_spawned and not IsAlive(self.grigg)) then
      self:fail("grigg");
    elseif(self.grigg_spawned) then
      self.grigg_next = self.grigg_next - dtime;
      if(self.grigg_next <= 0) then
        self:call("_nextGriggAudio");
      end
    end
  end,
  success = function(self)
    --SucceedMission(GetTime()+5.0,"rbd08w01.des");
    
  end,
  delete_object = function(self,handle)
    local m = nil;
    if(IsIn(handle,self.comms)) then
      print("next audio");
      self.nextAudio = self.nextAudio + 1;
      if(self.audio[self.nextAudio]) then
        AudioMessage(self.audio[self.nextAudio]);
      end
    end
    for i, v in ipairs(self.comms) do
      print(i, v, IsAlive(v));
      if(IsAlive(v)) then
        SetObjectiveOn(v);
        break;
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
    return self.timer, self.wait_1, self.grigg, self.timerOut, self.grigg_spawned, self.curr_grigg, self.grigg_next, self.nextAudio;
  end,
  load = function(self,...)
    self.timer, self.wait_1, self.grigg, self.timerOut, self.grigg_spawned, self.curr_grigg, self.grigg_next, self.nextAudio = ...;
    if(not self.timerOut) then
      StartCockpitTimer(self.timer,self.timer*0.5,self.timer*0.1);
    end
  end
});


evac = mission.Objective:define("evac"):createTasks(
  "wait", "evacuate"
):setListeners({
  init = function(self)

  end,
  start = function(self, grigg, slowEvac, lastComm)
    print("Evac started");
    self.slowEvac = slowEvac;
    self.grigg = grigg;
    self.wait_timer = 5;
    self:startTask("wait");
    self.lastComm = lastComm;
  end,
  task_start = function(self, name)
    if(name == "wait") then
      --AddObjective("rbd0801i.otf");
    elseif(name == "evacuate") then
      AudioMessage(audio.evacuate);
      AddObjective("rbd0803.otf");

      local s = mission.TaskManager:sequencer(self.grigg);
      s:clear();
      Goto(self.grigg,"grigg_to_gt");
      s:queue3("GriggAtGt");
    end
  end,
  task_success = function(self, name)
    if(name == "wait") then
      --RemoveObjective("rbd0801i.otf");
      --AddObjective("rbd0802i.otf","green");
      self:startTask("evacuate");
    elseif(name == "evacuate") then
      UpdateObjective("rbd0803.otf","green");
      self:success();
    end
  end,
  update = function(self, dtime)
    if(self:isTaskActive("evacuate")) then
      local d1 = Length(GetPosition(GetPlayerHandle()) - GetPosition("spawn_griggs"));
      local d2 = Length(GetPosition(self.grigg) - GetPosition("spawn_griggs"));
      if(d1 < 100 and d2 < 100) and (not IsAlive(self.lastComm)) then
        self:taskSucceed("evacuate");
      end
      if(not IsAlive(self.grigg)) then
        self:taskFail("evacuate");
      end
    elseif(self:isTaskActive("wait")) then
      self.wait_timer = self.wait_timer - dtime;
      if(self.wait_timer <= 0) then
        self:taskSucceed("wait");
      end
    end
  end,
  save = function(self)
    return self.slowEvac, self.wait_timer, self.grigg, self.lastComm;
  end,
  load = function(self, ...)
    self.slowEvac, self.wait_timer, self.grigg, self.lastComm = ...;
  end,
  fail = function(self)
    FailMission(GetTime()+5.0,"rbd08l05.des");
  end,
  success = function(self)
    if(self.slowEvac) then
      SucceedMission(GetTime() + 5.0, "rbd08w02.des");
    else
      SucceedMission(GetTime() + 5.0, "rbd08w01.des");
    end
  end
});

function Start()
  print("pack test")
  print(#(table.pack(1, 2, nil, 3, 4)));
  print(#({1, 2, nil, 3, 4}));

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