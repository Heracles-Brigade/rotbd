


local _ = require("bz_logging");

local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();

--Objective definitions
--Generic get relic Objective
local getRelics = mission.Objective:define("reteriveRelic"):createTasks(
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
      relic1 = GetHandle("relic1"),
      relic2 = GetHandle("relic2")
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
    self.baseLocation = nil;
    self.ccaLocation = nil;
    self.nsdfLocation = nil;
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
    --If you pick up relic1 then make cca take try to take relic2?
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
  task_fail = function(self,name,first)
    if(self.otfs[name]) then
      UpdateObjective(self.otfs[name],"red");
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
  SetPilot(1,5);
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
  fetch = getRelics:start();

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
  return mission:Save(), globals;
end

function Load(misison_date,g)
  mission:Load(misison_date);
  globals = g;
end