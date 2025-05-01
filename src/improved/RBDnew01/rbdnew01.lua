--Combination of Grab The Scientists and Preparations

local api = require("_api");
local hook = require("_hook");
local funcarray = require("_funcarray");
local statemachine = require("_statemachine");

local minit = require("minit")


local misc = require("misc");

local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();

local areAllDead = mission.areAllDead;



local audio = {
    intro = "rbd0101.wav",
    inspect = "rbd0102.wav",
    power1 = "rbd0103.wav",
    power2 = "rbd0104.wav",
    recycler = "rbd0105.wav",
    attack = "rbd0106.wav",
    nsdf = "rbd0107.wav",
    win = "rbd0108.wav"
}


SetAIControl(2,false);

function RemoveConvoy(...)
    local h = {...};
    for i,v in pairs(h) do
        RemoveObject(v);
    end
end

local function spawnNextNav()
	-- todo can globrals.currentNav be null
    local current = globals.currentNav;
    local nav = BuildObject("apcamr", 1, GetPathPoints("nav_path")[current]);
    SetObjectiveName(nav, ("Navpoint %d"):format(current));
    SetObjectiveOn(nav);
    SetMaxHealth(nav, 0);
    table.insert(globals.navs, nav);
    globals.currentNav = globals.currentNav + 1;
    return nav;
end

local function enemiesInRange(dist,place)
    local enemies_nearby = false;
    for v in ObjectsInRange(dist,place) do
        if(IsCraft(v) and GetTeamNum(v) == 2) then
            enemies_nearby = true;
        end
    end
    return enemies_nearby;
end

local function spawnAtPath(odf,team,path)
    local handles = {};
    local current = GetPosition(path);
    local prev = nil;
    local c = 0;
    while current ~= prev do
        c = c + 1;
        table.insert(handles,BuildObject(odf,team,current));
        prev = current;
        current = GetPosition(path,c);
    end
    return handles;
end

local function createWave(odf,path_list,follow)
    local ret = {};
    print("Spawning:" .. odf);
    for i,v in pairs(path_list) do
        local h = BuildObject(odf,2,v);
        if(follow) then
            Goto(h,follow);
        end
        table.insert(ret,h);
    end
    return unpack(ret);
end

--Define all objectives
local deployRecy = mission.Objective:define("deploy_recycler"):init({
    next = 'make_scavs',
    otf = 'bdmisn2201.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
    end,
    update = function(self)
        if(IsDeployed(GetRecyclerHandle(1))) then
            self:success();
            --mission.Objective:Start(self.next)
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        ClearObjectives();
        mission.Objective:Start(self.next);
		mission.Objective:Start('delayed_spawn');
    end
});

local DelayedSpawn = mission.Objective:define("delayed_spawn"):init({
    wait_timer = 120,
    wait_done = false
}):setListeners({
    update = function(self,dtime)
        if((not self.wait_done) and self.wait_timer <= 0) then
            createWave("svfigh",{"spawn_n1","spawn_n2"},"north_path");
			createWave("svtank",{"spawn_n3"},"north_path"); 
            self.wait_done = true;
            self:success();
        end
        self.wait_timer = self.wait_timer - dtime;
    end,
    save = function(self)
        return self.wait_timer, self.wait_done;
    end,
    load = function(self,...)
        self.wait_timer, self.wait_done = ...;
    end
});

local makeScavs = mission.Objective:define("make_scavs"):init({
    next = 'get_scrap',
    otf = 'bdmisn2202.otf'
}):setListeners({
    start = function(self)
        SetObjectiveOff(GetHandle("nav4"));
        AddObjective(self.otf,"white");
    end,
    update = function(self)
        --Check if player has 2 scavengers
        if(tracker:gotOfClass("scavenger",2)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

local getScrap = mission.Objective:define('get_scrap'):init({
    next = 'make_factory',
    otf = 'bdmisn2203.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
		createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
    end,
    update = function(self)
        if(GetScrap(1) >= 20) then
            self:success();
        end
    end,
    success = function(self)
        ClearObjectives();
        mission.Objective:Start(self.next);
    end
});

local makeFactory = mission.Objective:define("make_factory"):init({
    next = 'make_comm',
    otf = 'bdmisn2204.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
    end,
    update = function(self)
        if(tracker:gotOfClass("factory",1)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

local makeOffensive = mission.Objective:define("make_offensive"):init({
    next = 'make_defensive',
    otf = 'bdmisn2205.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        self.tracker = mission.UnitTracker:new();
		createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
    end,
    update = function(self)
        --Check if got 3 more tanks + 1 bomber, since mission start
        if(self.tracker:gotOfOdf("bvtank",3) and self.tracker:gotOfOdf("bvhraz",1)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.tracker:save();
    end,
    load = function(self,tdata)
        self.tracker = mission.UnitTracker:Load(tdata);
    end,
    finish = function(self)
        self.tracker:kill();
    end
});

local makeDefensive = mission.Objective:define("make_defensive"):init({
    next = 'destroy_soviet',
    otf = 'bdmisn2206.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
		createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path"); -- Original Script did nothing with these 2. Possibly sent to guard Scavs instead? -GBD
        createWave("svscav",{"spawn_w2","spawn_w3"});
    end,
    update = function(self)
        if(tracker:gotOfClass("turrettank",3)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

local destorySoviet = mission.Objective:define("destroy_soviet"):init({
    otf = 'bdmisn2207.otf',
    next = 'nsdf_attack',
    wait_timer = 45,
    wait_done = false
}):setListeners({
    start = function()
        createWave("svfigh",{"spawn_e1","spawn_e2"},"east_path");
        createWave("svtank",{"spawn_e3"},"east_path");
        local nav = spawnNextNav();
        SetObjectiveOff(nav);
        SetObjectiveName(nav, "CCA Base");
        AudioMessage(audio.attack);
    end,
    update = function(self,dtime)
        if((not self.wait_done) and self.wait_timer <= 0) then
            AddObjective(self.otf,"white");
            globals.keepGTsAtFullHealth = false;
            SetObjectiveOn(globals.sb_turr_1);
            SetObjectiveOn(globals.sb_turr_2);
            SetObjectiveOn(GetRecyclerHandle(2));
            self.wait_done = true;
            --mission:getObjective("toofarfrom_recy"):success();
        else
            if(not(IsAlive(globals.sb_turr_1) or IsAlive(globals.sb_turr_2))) then
                self:success();
            end
        end
        
        self.wait_timer = self.wait_timer - dtime;
    end,
    success = function(self)
        --UpdateObjective(self.otf,"green");
        SetObjectiveOff(GetRecyclerHandle(2));
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.wait_timer, self.wait_done;
    end,
    load = function(self,...)
        self.wait_timer, self.wait_done = ...;
    end
});

local nsdfAttack = mission.Objective:define("nsdf_attack"):init({
    otf = 'bdmisn2208.otf',
    camOn = false,
    camTime = 10,
    targets = {},
    recycler_target = false
}):setListeners({
    start = function(self)
        AudioMessage(audio.nsdf);
        AddObjective(self.otf,"white");
        local a,b,camTarget = createWave("avwalk",{"spawn_avwalk1","spawn_avwalk2","spawn_avwalk3"},"nsdf_path");
        local c,e,g = createWave("avtank",{"spawn_avtank1","spawn_avtank2","spawn_avtank3"},"nsdf_path");
        local d,h,i = createWave("avtank",{"spawn_w1","spawn_w2","spawn_w3"},"west_path");
        local f,j = createWave("svtank",{"spawn_n4","spawn_n5"},"north_path");
        self.camTarget = camTarget;
        self.camOn = CameraReady();
        self.targets = {a,b,c,d,e,f,g,h,i,camTarget,j};
        for i,v in pairs(self.targets) do
            SetObjectiveOn(v);
        end
        if(not IsAlive(GetRecyclerHandle(2))) then
            UpdateObjective(self.otf,"green");
        end
    end,
    update = function(self,dtime)
        if(self.camOn) then
            CameraPath("camera_nsdf",1000,1500,self.camTarget);
            self.camTime = self.camTime - dtime;
            if(self.camTime <= 0 or CameraCancelled()) then
                self.camOn = not CameraFinish();
            end
        end
        if(self.recycler_target and not IsAlive(GetRecyclerHandle(2))) then
            self:success();
        elseif(not self.recycler_target) then
            if areAllDead(self.targets, 2) then
                self.recycler_target = true;
                SetObjectiveOn(GetRecyclerHandle(2));
                UpdateObjective(self.otf,"green");
            end
        end        
    end,
    delete_object = function(self,handle)
        if(handle == GetRecyclerHandle(2)) then
            UpdateObjective("bdmisn2207.otf","green");
        end
    end,
    success = function(self)
        AudioMessage(audio.win);
        SucceedMission(GetTime() + 10, "bdmisn22wn.des");
    end,
    save = function(self)
        return self.camTarget,self.camOn,self.camTime,self.targets,self.recycler_target;
    end,
    load = function(self,...)
        self.camTarget, self.camOn,self.camTime,self.targets ,self.recycler_target= ...;
    end
});

local makeComm = mission.Objective:define("make_comm"):init({
    otf = 'bdmisn2209.otf',
    next = 'destroy_soviet'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
		createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
    end,
    update = function(self)
        if(tracker:gotOfClass("commtower",1)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

-- Lose conditions by GBD. No idea if i did this right, mission doesn't update otfs, or goto a next thing, it runs throughout the mission. (distance check until ordered to attack CCA base, and recy loss throughout entire mission.)
local loseRecy = mission.Objective:define("lose_recy"):setListeners({
    update = function(self)
        if(not IsAlive(GetRecyclerHandle(1))) then
            self:fail();
        end
    end,
	fail = function(self)
		FailMission(GetTime() + 5, "bdmisn22l2.des");
	end
});
-- If you go too far.
local TooFarFromRecy = mission.Objective:define("toofarfrom_recy"):setListeners({
    update = function(self)
        if not globals.keepGTsAtFullHealth then -- GBD 12/3/16. I thought this used to deactivate on this bool before, can't find it. Now self kill this function when this becomes false. (triggered in Destroy_Soviet)
			self:finish();
            return;
		end
        if(IsAlive(GetPlayerHandle())) then
            if IsAlive(GetRecyclerHandle(1)) and GetDistance(GetPlayerHandle(), GetRecyclerHandle(1)) > 700.0 then
                print(self.alive);
                self:fail();
            end
        end
    end,
    fail = function(self)
        FailMission(GetTime() + 5, "bdmisn22l1.des");
    end,
    finish = function(self)
        globals.keepGTsAtFullHealth = false;
    end
});

local function checkDead(handles)
    for i,v in pairs(handles) do
        if(IsAlive(v)) then
            return false;
        end
    end
    return true;
end

funcarray.Create("cinematic", function(self)
    self.camOn = CameraReady();
    AudioMessage(audio.intro); 
    self.target_time = _funcarray.game_time + 20; -- todo find a way to standardize this
    self:next();
end,
function(self)
    if (self:SecondsHavePassed(20) or CameraPath("opening_cin", 2000, 1000, globals.cafe) or CameraCancelled()) then
        self:SecondsHavePassed(); -- clear timer if we got here without it being cleared
        CameraFinish();
        self:next();
    end
end,
function(self)
    --mission.Objective:Start('checkCommand');
    globals.checkCommand = statemachine.Start("checkCommand", "start", {
        otf = 'bdmisn211.otf'
    });
    self:next(); -- done
end);

statemachine.Create("checkCommand", {
    ["start"] = function(self)
        self.nav = spawnNextNav();
        AddObjective(self.otf,"white");
        self.command = GetHandle("sbhqcp0_i76building");
        print(self.otf,self.command);
        self:switch("check");
    end,
    ["check"] = function(self)
        if(GetDistance(GetPlayerHandle(), self.command) < 50.0) then
            self:success();
        elseif(not IsAlive(self.command)) then
            self:fail();
        end
    end,
    ["success"] = function(self)
        AudioMessage(audio.inspect);
        SetObjectiveOff(self.nav);
        UpdateObjective(self.otf,"green");
        mission.Objective:Start('destorySolar', {
            otf1 = 'bdmisn212.otf',
            otf2 = 'bdmisn213.otf',
            target_l1 = {"sbspow1_powerplant","sbspow2_powerplant","sbspow3_powerplant","sbspow4_powerplant"},
            target_l2 = {"sbspow7_powerplant","sbspow8_powerplant","sbspow5_powerplant","sbspow6_powerplant"},
        });
        self:switch("end");
    end,
    ["fail"] = function(self)
        UpdateObjective(self.otf,"red");
        FailMission(GetTime() + 5,"bdmisn21ls.des");
        self:switch("end");
    end
})

statemachine.Create("destorySolar", {
    ["start"] = function(self)
        self.nav = spawnNextNav();
        SetObjectiveName(self.nav, "Solar Array 1");
        AddObjective(self.otf1,"white");
        self.handles = {};
        for i,v in pairs(self.target_l1) do
            self.handles[i] = GetHandle(v)
        end
        self:switch("check");
    end,
    ["check"] = function(self)
        if(checkDead(self.handles)) then
            self.power1_4_runlatch = true;
            UpdateObjective(self.otf1,"green");
			AudioMessage(audio.power1);
            self:switch("check2");
        end
    end,
    ["check2"] = function(self)
        SetObjectiveOff(self.nav);
        self.nav = spawnNextNav();
        SetObjectiveName(self.nav, "Solar Array 2");
        SetObjectiveOn(self.nav);
        AddObjective(self.otf2,"white");
        self.handles = {};
        for i,v in pairs(self.target_l2) do
            self.handles[i] = GetHandle(v);
        end
        self:switch("check3");
    end,
    ["check3"] = function(self)
        if(checkDead(self.handles)) then
            SetObjectiveOff(self.nav);
            UpdateObjective(self.otf2,"green");
            self:switch("check4");
        end
    end,
    ["check4"] = statemachine.SleepSeconds(3, "success"),
    ["success"] = function(self)
        AudioMessage(audio.power2);
        globals.destroyComm = statemachine.Start("destroyComm", "start", {
            otf = 'bdmisn214.otf',
            otf2 = 'bdmisn215.otf',
            camOn = false,
            gotRelic = false
        });
        self:switch("end");
    end
});

statemachine.Create("destroyComm", {
    ["start"] = function(self)
        self.nav = spawnNextNav();
        SetObjectiveOn(globals.comm);
        SetObjectiveName(self.nav, "Research Facility");
        AddObjective(self.otf,"white");
        AddObjective(self.otf2,"white");
        self.camOn = CameraReady();
        local apc = BuildObject("avapc",2,"spawn_apc");
        local tug = BuildObject("avhaul",2,"spawn_tug");
        SetMaxHealth(tug, 0); -- This is invincible.
        SetMaxHealth(apc, 0); -- This is invincible.
        SetPilotClass(tug, ""); -- This is invincible.
        SetPilotClass(apc, ""); -- This is invincible.
        Follow(apc,tug);
        local tugTasks = mission.TaskManager:sequencer(tug);
        tugTasks:queue2("Pickup",globals.relic);
        tugTasks:queue2("Goto","leave_path");
        tugTasks:queue2("RemoveConvoy",apc,globals.relic);
        Pickup(tug,globals.relic);
        print("Pickup",tug,globals.relic);
        Goto(BuildObject("avtank",2,"spawn_tank1"),globals.comm);
        Goto(BuildObject("avtank",2,"spawn_tank2"),globals.comm);
        Goto(BuildObject("avtank",2,"spawn_tank3"),globals.comm);

        self:switch("camera");
    end,
    ["camera"] = function(self)
        if(self.camOn) then
            if (CameraPath("convoy_cin",2000,2000, globals.cafe) or CameraCancelled()) then
                self.camOn = not CameraFinish();
            end
        else
            self:switch("sentinal");
        end
    end,
    ["sentinal"] = function(self)
        if(not IsAlive(globals.comm)) then

            UpdateObjective(self.otf,"green");
            UpdateObjective(self.otf2,"green");
            --SucceedMission(GetTime()+5,"bdmisn21wn.des");
            --Start 22 - Preparations
            --mission.Objective:Start("intermediate");
            globals.intermediate = funcarray.Start("intermediate", { enemiesAtStart = false });

            self:switch("end");
        end
    end});

funcarray.Create("destoryNSDF", function(state)
    if( checkDead(globals.patrolUnits) ) then
        local reinforcements = {
            BuildObject("svfigh", 2, "spawn_svfigh1"),
            BuildObject("svfigh", 2, "spawn_svfigh2"),
            BuildObject("svrckt", 2, "spawn_svrckt1"),
            BuildObject("svrckt", 2, "spawn_svrckt2"),
            BuildObject("svhraz", 2, "spawn_svhraz")
        };
        -- Send the reinforcements to Nav 4.
        for i,v in pairs(reinforcements) do
            Goto(v, GetPosition(globals.navs[4]));
        end
        print("Spawning reinforcements");
        state:next(); -- move to the next state, which doesn't exist
    end
end);

funcarray.Create("intermediate", function(self)
    self.nav = globals.navs[4];
    state:next();
end,
function (self)
    ClearObjectives();
        
    for i=1, 3 do
        RemoveObject(globals.navs[i])
    end

    local t = GetTransform(globals.navs[4]);
    local nav = BuildObject("apcamr", 1, t);
    SetTransform(nav, t);
    RemoveObject(globals.navs[4]);
    SetMaxHealth(nav, 0);
    globals.navs[4] = nav;
    self.nav = nav;
    --Only show if area is not cleared
    if(enemiesInRange(270,self.nav)) then
        self.enemiesAtStart = true;
        AddObjective("bdmisn311.otf","white");
--      else --Removed due to redundancy
--          AddObjective("bdmisn311b.otf","yellow");
    end
    state:next();
end,
funcarray.SleepSeconds(90, function(self) return not enemiesInRange(270,self.nav) end),
function (self)
    if(self.enemiesAtStart) then
        UpdateObjective("bdmisn311.otf","green");
    end
    AudioMessage(audio.recycler);
    local recy = BuildObject("bvrecy22",1,"recy_spawn");
    local e1 = BuildObject("bvtank",1,GetPositionNear(GetPosition("recy_spawn"),20,100));
    local e2 = BuildObject("bvtank",1,GetPositionNear(GetPosition("recy_spawn"),20,100));
    Defend2(e1,recy,0);
    Defend2(e2,recy,0);
    --Make recycler follow path
    Goto(recy,self.nav,0);
    self.recy = recy;
    
    SetObjectiveOn(recy);
    --self:success();
    self:next();
end,
function (self)
    if(self.recy and IsWithin(self.recy,self.nav,200)) then
        self:next();
    end
end,
function (self) -- success state
    globals.keepGTsAtFullHealth = true;
    --Spawn in recycler
    --Recycler escort

    AddScrap(1,20);
    AddPilot(1,10);
    SetScrap(2,0);
    SetPilot(2,0);
    SetObjectiveOn(self.nav);
    --initial wave
    BuildObject("svrecy",2,"spawn_svrecy");
    BuildObject("svmuf",2,"spawn_svmuf");
    --AudioMessage(audio.attack);
    globals.sb_turr_1 = BuildObject("sbtowe",2,"spawn_sbtowe1");
    globals.sb_turr_2 = BuildObject("sbtowe",2,"spawn_sbtowe2");
    --Not really creating a wave, but spawns sbspow
    createWave("sbspow",{"spawn_sbspow1","spawn_sbspow2"});
    --Start wave after a delay?
    createWave("svfigh",{"spawn_n1","spawn_n2","spawn_n3"},"north_path");
    createWave("svtank",{"spawn_n4","spawn_n5"},"north_path"); 
    local instance = deployRecy:start();
    local instance2 = loseRecy:start();
    --local instance3 = TooFarFromRecy:start();

    self:next(); -- finish
end);

hook.Add("Start", "Mission:Start", function ()
    print("Start");
    globals.navs = {
    };
    globals.currentNav = 1;
    globals.cafe = GetHandle("sbcafe1_i76building");
    globals.comm = GetHandle("sbcomm1_commtower");
    globals.relic = GetHandle("obdata3_artifact");
    SetMaxHealth(globals.relic,0);
    globals.patrolUnits = {
        GetHandle("svfigh4_wingman"),
        GetHandle("svfigh5_wingman")
    };

    globals.cinematic = funcarray.Start("cinematic");
    globals.patrolControl = funcarray.Start("destoryNSDF");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
    mission:Update(dtime);
    globals.patrolControl:run();
    if (globals.intermediate) then
        globals.intermediate:run();
    end
    if (globals.destroyComm) then
        globals.destroyComm:run();
    end
end);

hook.Add("CreateObject", "Mission:CreateObject", function (object)
    mission:CreateObject(object:GetHandle());
end);

hook.Add("AddObject", "Mission:AddObject", function (object)
    mission:AddObject(object:GetHandle());
end);

hook.Add("DeleteObject", "Mission:DeleteObject", function (object)
    mission:DeleteObject(object:GetHandle());
end);

hook.AddSaveLoad("Mission",
function()
    return mission:Save(), globals, tracker:save();
end,
function(misison_date,g,tdata)
    mission:Load(misison_date);
    globals = g;
			-- ensure globals exist properly							  
    tracker = mission.UnitTracker:Load(tdata);
end);


minit.init()