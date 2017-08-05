local core = require("bz_core");
local OOP = require("oop");
local bzRoutine = require("bz_routine");

local misc = require("misc");

local IsIn = OOP.isIn;
local joinTables = OOP.joinTables;
local PatrolController = require("patrolc");
local mission = require('cmisnlib');

local pwers = {};
require("bz_logging");


local captureRelic = mission.Objective:define("captureRelic"):createTasks(
  "findRelic", "secureSite"
):setListeners({
  init = function(self)
    self.relic = GetHandle("armory");
    self.check_interval = 50;
    self.cframe = 0;
    self.otfs = {
      findRelic = "rbd0901.otf",
      secureSite = "rbd0902.otf"
    }
  end,
  start = function(self,patrol_id)
    self.patrol_id = patrol_id;
    self:startTask("findRelic");
  end,
  task_start = function(self,name)
    AddObjective(self.otfs[name]);
  end,
  task_fail = function(self,name)
    UpdateObjective(self.otfs[name],"red");
    self:fail();
  end,
  task_success = function(self,name)
    UpdateObjective(self.otfs[name],"green");
    if(name == "findRelic") then
      self:startTask("secureSite");
    elseif(name == "secureSite") then
      self:success();
    end  
  end,
  update = function(self,dtime)
    local ph = GetPlayerHandle();
    if(self:isTaskActive("findRelic")) then
      if(IsWithin(ph,self.relic,400)) then
        self:taskSucceed("findRelic");
      end
    end
    if(self:isTaskActive("secureSite")) then
      self.cframe = self.cframe + 1; 
      if(self.cframe > 50) then
        self.cframe = 0;
        local secure = true;
        for obj in ObjectsInRange(400,self.relic) do
          if(IsCraft(obj) and GetTeamNum(obj) == 2) then
            secure = false;
            break;
          end
        end
        if(secure) then
          self:taskSucceed("secureSite");
        end
      end
    end
  end,
  save = function(self)
    return self.p_id;
  end,
  load = function(self,...)
    self.p_id = ...;
  end,
  success = function(self)
    print("success");
    mission.Objective:Start("defendSite");
  end
});

local defendSite = mission.Objective:define("defendSite"):createTasks(
  "waves", "kill_all"
):setListeners({
  init = function(self)
    self.wave_count = 4;
  end,
  start = function(self)
    local p = GetPosition("nsdf_outpost");
    p.y = GetTerrainHeightAndNormal(p) + 500;
    self.recy = BuildObject("bvrecy",1,p);
    SetPosition(self.recy,p);
    self.fury_units = {};
    self.wave = 0;
    self:startTask("waves");
  end,
  task_start = function(self,task)
    if(task == "waves") then
      self:call("_setTimer",60*5);
    end
  end,
  task_success = function(self,task)
    if(task == "waves") then
      self:startTask("kill_all");
    else
      self:success();
    end
  end,
  _setTimer = function(self,limit)
    self.timer = misc.Timer(limit,false);
    self:call("_subToTimer");
    self.timer:start();
  end,
  _subToTimer = function(self)
    if(self.sub) then
      self.sub:unsubscribe();
    end
    self.sub = self.timer:onAlarm():subscribe(function()
      if(self:isTaskActive("waves")) then
        self:call("_nextWave");
      else
      end
    end);
  end,
  _nextWave = function(self)
    self.wave = self.wave + 1;
    self.fury_units = joinTables(self.fury_units,mission.spawnInFormation2({"1 2 1 2", "2 1 2 1"},"fury_spawn_1",{"hvsat","hvsav"},3));
    for i, v in pairs(self.fury_units) do
      Goto(v,"nsdf_outpost");
    end
    if(self.wave < self.wave_count) then
      self:call("_setTimer",60);
    else
      self:taskSucceed("waves");
    end
  end,
  update = function(self,dtime)
    if(self.timer) then
      self.timer:update(dtime);
    end
    if(self:isTaskActive("kill_all") and mission.areAllDead(self.fury_units)) then
      self:taskSucceed("kill_all");
    end
  end,
  save = function(self)
    return {
      recy = self.recy,
      timer = self.timer:save(),
      wave = self.wave,
      fury_units = self.fury_units
    }
  end,
  load = function(self,data)
    self.recy = data.recy;
    self.timer = misc.Timer(0,false):load(data.timer);
    self.wave = data.wave;
    self.fury_units = data.fury_units;
    self:call("_subToTimer");
  end,
  success = function(self)
    SucceedMission(GetTime() + 5,"rbdmisn29wn.des");
  end
});



local function setUpPatrols(handles)
  local patrol_rid, patrol_r = bzRoutine.routineManager:startRoutine("PatrolRoutine");
  --what are our `checkpoint` locations?
  patrol_r:registerLocations({"l_comm","l_center1","l_north","l_west","l_obase","l_sw","l_center2"});

  patrol_r:defineRouts("l_obase",{
    p_obase_center1 = "l_center1",
    p_obase_r1 = "l_obase",
    p_obase_r2 = "l_obase"
  });
  
  patrol_r:defineRouts("l_center1",{
    p_center1_center2 = "l_center2",
    p_center1_obase = "l_obase",
    p_center1_sw = "l_sw"
  });

  patrol_r:defineRouts("l_comm",{
    p_comm_north_1 = "l_north",
    p_comm_north_2 = "l_north"
  });
  
  patrol_r:defineRouts("l_center2",{
    --p_center2_west = "l_west",    
    p_center2_comm = "l_comm",
    p_center2_center1 = "l_center1",
    p_center2_sw = "l_sw"
  });

  patrol_r:defineRouts("l_north",{
    p_north_west = "l_west",
    p_north_center2 = "l_center2"
  });
  
  patrol_r:defineRouts("l_sw",{
    p_sw_center2 = "l_center2",
    p_sw_center1 = "l_center1"
  });

  patrol_r:defineRouts("l_west",{
    p_west_center2_1 = "l_center2",
    p_west_center2_2 = "l_center2"
  });
  return patrol_id, patrol_r;
end

function Start()
  local p_id, p = setUpPatrols(handles);
  for v in AllCraft() do
    if((GetTeamNum(v) == 2) and (GetClassLabel(v) ~= "turrettank") and GetNation(v) == "s") then
      p:addHandle(v);
    end
  end
  core:onStart();
  captureRelic:start(p_id);
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