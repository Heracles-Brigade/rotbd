--Combination of Grab The Scientists and Preparations

require("_printfix");

debugprint = print;
--traceprint = print;

require("_requirefix").addmod("rotbd");

require("_table_show");
require("_gameobject");
local api = require("_api");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");

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
statemachine.Create("delayed_spawn",
    statemachine.SleepSeconds(120),
    function(self)
        createWave("svfigh",{"spawn_n1","spawn_n2"},"north_path");
        createWave("svtank",{"spawn_n3"},"north_path"); 
        self.wait_done = true;
        self:next();
    end);

local function checkDead(handles)
    for i,v in pairs(handles) do
        if(IsAlive(v)) then
            return false;
        end
    end
    return true;
end


statemachine.Create("main_objectives", {
    { "start", function(self)
        CameraReady();
        AudioMessage(audio.intro);
        self:next();
    end },
    { "opening_cin", function(self)
        if (self:SecondsHavePassed(20) or CameraPath("opening_cin", 2000, 1000, globals.cafe) or CameraCancelled()) then
            self:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            CameraFinish();
            self:next();
        end
    end },
    { "check_command_obj", function(self)
        self.nav = spawnNextNav();
        AddObjective('bdmisn211.otf',"white");
        self.command = GetHandle("sbhqcp0_i76building");
        print('bdmisn211.otf',self.command);
        self:next();
    end },
    { "check_command_passfail", function(self)
        if(GetDistance(GetPlayerHandle(), self.command) < 50.0) then
            AudioMessage(audio.inspect);
            SetObjectiveOff(self.nav);
            UpdateObjective('bdmisn211.otf',"green");
            self:next();
        elseif(not IsAlive(self.command)) then
            UpdateObjective('bdmisn211.otf',"red");
            FailMission(GetTime() + 5,"bdmisn21ls.des");
            self:switch("end");
        end
    end },
    { "destory_solar1_obj", function(self)
        -- move this to configuration
        self.target_l1 = {"sbspow1_powerplant","sbspow2_powerplant","sbspow3_powerplant","sbspow4_powerplant"};
        self.target_l2 = {"sbspow7_powerplant","sbspow8_powerplant","sbspow5_powerplant","sbspow6_powerplant"};

        self.nav = spawnNextNav();
        SetObjectiveName(self.nav, "Solar Array 1");
        AddObjective('bdmisn212.otf',"white");
        self.handles = {};
        for i,v in pairs(self.target_l1) do
            self.handles[i] = GetHandle(v)
        end
        self:next();
    end },
   { "destory_solar1_pass", function(self)
        if(checkDead(self.handles)) then
            self.power1_4_runlatch = true;
            UpdateObjective('bdmisn212.otf',"green");
			AudioMessage(audio.power1);
            self:next();
        end
    end },
    { "destory_solar2_obj", function(self)
        SetObjectiveOff(self.nav);
        self.nav = spawnNextNav();
        SetObjectiveName(self.nav, "Solar Array 2");
        SetObjectiveOn(self.nav);
        AddObjective('bdmisn213.otf',"white");
        self.handles = {};
        for i,v in pairs(self.target_l2) do
            self.handles[i] = GetHandle(v);
        end
        self:next();
    end },
    { "destory_solar2_pass", function(self)
        if(checkDead(self.handles)) then
            SetObjectiveOff(self.nav);
            UpdateObjective('bdmisn213.otf',"green");
            self:next();
        end
    end },
    { "destroy_solar_postgap", statemachine.SleepSeconds(3, "destroy_solar_success") },
    { "destroy_solar_success", function(self)
        AudioMessage(audio.power2);
        self:next();
    end },
    { "destroy_comm_start", function(self)

        -- temp var creation
        self.camOn = false;
        self.gotRelic = false;

        self.nav = spawnNextNav();
        SetObjectiveOn(globals.comm);
        SetObjectiveName(self.nav, "Research Facility");
        AddObjective('bdmisn214.otf',"white");
        AddObjective('bdmisn215.otf',"white");
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

        self:next();
    end },
    { "convoy_cin", function(self)
        if(self.camOn) then
            if (CameraPath("convoy_cin",2000,2000, globals.cafe) or CameraCancelled()) then
                self.camOn = not CameraFinish();
            end
        else
            self:next();
        end
    end },
    { "destroy_obj", function(self)
        if not IsAlive(globals.comm) then

            UpdateObjective('bdmisn214.otf',"green");
            UpdateObjective('bdmisn215.otf',"green");
            --SucceedMission(GetTime()+5,"bdmisn21wn.des");
            --Start 22 - Preparations
            --mission.Objective:Start("intermediate");
            --globals.intermediate = statemachine.Start("intermediate", { enemiesAtStart = false });
            

            self:next();
        end
    end },
    function(self)
        self.enemiesAtStart = false;
        self.nav = globals.navs[4];
        self:next();
    end ,
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
        self:next();
    end,
    statemachine.SleepSeconds(90, nil, function(self) return not enemiesInRange(270,self.nav) end),
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
        
        --local instance = deployRecy:start();
        next();
        
        --local instance2 = loseRecy:start();
        globals.mission_states:on("lose_recy");
        
        --local instance3 = TooFarFromRecy:start();
        --global.mission_states:on("toofarfrom_recy");

        self:next(); -- finish
    end,
    { "deploy_recycler", function (self)
        AddObjective('bdmisn2201.otf',"white");
        self:next();
    end },
    function(self)
        if(IsDeployed(GetRecyclerHandle(1))) then
            self:next();
            --mission.Objective:Start(self.next)
        end
    end,
    function(self)
        UpdateObjective('bdmisn2201.otf',"green");
        ClearObjectives();
        
        --mission.Objective:Start('make_scavs');
        next();
        
        --mission.Objective:Start('delayed_spawn');
        globals.mission_states:on("delayed_spawn");
    end,
    { "make_scavs", function(self)
        SetObjectiveOff(GetHandle("nav4"));
        AddObjective('bdmisn2202.otf',"white");
        self:next();
    end },
    function(self)
        --Check if player has 2 scavengers
        if(tracker:gotOfClass("scavenger",2)) then
            self:next();
        end
    end,
    function(self)
        UpdateObjective('bdmisn2202.otf',"green");
        
        --mission.Objective:Start('get_scrap');
        self:next();
    end,
    { "get_scrap", function(self)
        AddObjective('bdmisn2203.otf',"white");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
        self:next();
    end },
    function(self)
        if(GetScrap(1) >= 20) then
            self:next();
        end
    end,
    function(self)
        ClearObjectives();

        --mission.Objective:Start('make_factory');
        self:next();
    end,
    { "make_factory", function(self)
        AddObjective('bdmisn2204.otf',"white");
        self:next();
    end },
    function(self)
        if(tracker:gotOfClass("factory",1)) then
            self:next();
        end
    end,
    function(self)
        UpdateObjective('bdmisn2204.otf',"green");

        --mission.Objective:Start('make_comm');
        self:next();
    end,
    { "make_comm", function(self)
        AddObjective('bdmisn2209.otf',"white");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
        self:next();
    end },
    function(self)
        if(tracker:gotOfClass("commtower",1)) then
            self:nextz();
        end
    end,
    function(self)
        UpdateObjective('bdmisn2209.otf',"green");
        
        --mission.Objective:Start('destroy_soviet');
        self:switch("destroy_soviet");
    end,
    
    -- SKIPPED STATES?
    { "make_offensive", function(self)
        AddObjective('bdmisn2205.otf',"white");
        self.tracker = mission.UnitTracker:new();
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
        self:next()
    end },
    function(self)
        --Check if got 3 more tanks + 1 bomber, since mission start
        if(self.tracker:gotOfOdf("bvtank",3) and self.tracker:gotOfOdf("bvhraz",1)) then
            self:next();
        end
    end,
    function(self)
        UpdateObjective('bdmisn2205.otf',"green");
        
        --mission.Objective:Start('make_defensive');
        self:next();
    end,
    { "make_defensive", function(self)
        AddObjective('bdmisn2206.otf',"white");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path"); -- Original Script did nothing with these 2. Possibly sent to guard Scavs instead? -GBD
        createWave("svscav",{"spawn_w2","spawn_w3"});
        self:next();
    end },
    function(self)
        if(tracker:gotOfClass("turrettank",3)) then
            self:next();
        end
    end,
    function(self)
        UpdateObjective('bdmisn2206.otf',"green");
        
        --mission.Objective:Start('destroy_soviet');
        self:next();
    end,
    -- /SKIPPED STATES?

    {"destroy_soviet", function(self)
        createWave("svfigh",{"spawn_e1","spawn_e2"},"east_path");
        createWave("svtank",{"spawn_e3"},"east_path");
        local nav = spawnNextNav();
        SetObjectiveOff(nav);
        SetObjectiveName(nav, "CCA Base");
        AudioMessage(audio.attack);
        self:next();
    end },
    statemachine.SleepSeconds(45),
    function(self) -- this one might have been broken before
        if(not(IsAlive(globals.sb_turr_1) or IsAlive(globals.sb_turr_2))) then
            self:next();
        end
    end,
    function(self)
        --UpdateObjective('bdmisn2207.otf',"green");
        SetObjectiveOff(GetRecyclerHandle(2));

        --mission.Objective:Start('nsdf_attack');
        self:next();
    end,
    {"nsdf_attack", function(self)
        AudioMessage(audio.nsdf);
        AddObjective('bdmisn2208.otf',"white");
        local a,b,camTarget = createWave("avwalk",{"spawn_avwalk1","spawn_avwalk2","spawn_avwalk3"},"nsdf_path");
        local c,e,g = createWave("avtank",{"spawn_avtank1","spawn_avtank2","spawn_avtank3"},"nsdf_path");
        local d,h,i = createWave("avtank",{"spawn_w1","spawn_w2","spawn_w3"},"west_path");
        local f,j = createWave("svtank",{"spawn_n4","spawn_n5"},"north_path");
        self.camTarget = camTarget;
        CameraReady();
        self.targets = {a,b,c,d,e,f,g,h,i,camTarget,j};
        for i,v in pairs(self.targets) do
            SetObjectiveOn(v);
        end
        if(not IsAlive(GetRecyclerHandle(2))) then
            UpdateObjective('bdmisn2208.otf',"green"); -- this is odd, this code isn't running anymore right?
        end
        self:next();
    end },
    function(self)
        if (self:SecondsHavePassed(10) or CameraPath("camera_nsdf",1000,1500,self.camTarget) or CameraCancelled()) then
            self:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            CameraFinish();
            self:next();
        end
    end,
    function(self)
        SetObjectiveOn(GetRecyclerHandle(2));
        UpdateObjective('bdmisn2208.otf',"green");
        self:next();
    end,
    function(self)
        if areAllDead(self.targets, 2) then
            self.recycler_target = true;
            SetObjectiveOn(GetRecyclerHandle(2));
            UpdateObjective(self.otf,"green");
            self:next();
        end
    end,
    function(self)
        if not IsAlive(GetRecyclerHandle(2)) then
            UpdateObjective("bdmisn2207.otf","green");
            self:next();
        end
    end,
    function(self)
        AudioMessage(audio.win);
        SucceedMission(GetTime() + 10, "bdmisn22wn.des");
        self:next();
    end
});

stateset.Create("mission")
    :Add("main_objectives", statemachine.Start("main_objectives", "start"))

    :Add("destoryNSDF", function(state)
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
            --state:next(); -- move to the next state, which doesn't exist
            state:off("destoryNSDF");
        end
    end)

    -- this state never runs?
    :Add("toofarfrom_recy", function(state)
        if(IsAlive(GetPlayerHandle())) then
            if IsAlive(GetRecyclerHandle(1)) and GetDistance(GetPlayerHandle(), GetRecyclerHandle(1)) > 700.0 then
                print(self.alive);
                FailMission(GetTime() + 5, "bdmisn22l1.des");
                state:off("toofarfrom_recy");
            end
        end
    end)
    
    -- Lose conditions by GBD. No idea if i did this right, mission doesn't update otfs, or goto a next thing, it runs throughout the mission. (distance check until ordered to attack CCA base, and recy loss throughout entire mission.)
    :Add("lose_recy", function(state)
        if(not IsAlive(GetRecyclerHandle(1))) then
            FailMission(GetTime() + 5, "bdmisn22l2.des");
            state:off("lose_recy");
        end
	end)

    :Add("delayed_spawn", statemachine.Start("delayed_spawn"));

hook.Add("Start", "Mission:Start", function ()
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

    globals.mission_states = stateset.Start("mission"):on("main_objectives");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
    mission:Update(dtime);
    globals.mission_states:run();

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