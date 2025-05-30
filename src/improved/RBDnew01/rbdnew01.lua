--- Rise of the Black Dogs
---
--- [1] Operation Recall
--- Original Mission:
--- [1] Grab The Scientists
--- [2] Preparations
---
--- World: Luna (Earth I), Earth (Sol III)
--- Map Data: Ported n64 Original
---
--- Authors:
--- * Rise of the Black Dogs Team
--- * <MISSING CREDITS>
--- * John "Nielk1" Klein
---
--- High Level Objectives
--- * Rescue scientists
--- * Set up base of operations
--- 
--- Events
--- During the events of Total Destruction a group of NSDF researchers on the moon are captured by
--- the CCA. The Liberty and Freedom are already at Titan (Saturn VI) and travel to join them from
--- Europa (Jupiter II) will take the Justice, the Black Dog's carrier, through the inner solar system.
--- The Black Dog platoon under Commander Cameron Shaw deploys on the destroyer Jackson as the Justice
--- approaches Earth.
--- 
--- Shaw's platoon deploy and infiltrate the base, using a CCA command tower to listen in on Soviet
--- communications and determine the scientists' precise location. After locating the base Cobra One
--- is ordered to destroy the solar farms that power it to weaken its defences before the Black Dog
--- wing launches its attack.
--- 
--- Before they can move on the base a wing of American forces arrive and extract both the scientists
--- and the relic they were working on. Telling his men that these forces must be Communist defectors
--- Shaw orders his men to give chase, but the wing escapes despite their efforts. The Black Dogs clear
--- the CCA forces out and capture the outpost.
--- 
--- Following the loss of the original objective due to interference by defectors Shaw declares that the
--- Black Dogs are no longer able to trust the American forces in the area and orders the construction of
--- a new command base so they can investigate the abandoned research building and coordinate their forces
--- without relying on the potentially compromised NSDF infrastructure in the area. A recycler is delivered
--- to Cobra One for deployment at the site of the Soviet research outpost and he is instructed to build
--- a Satellite Tower to facilitate ship-to-shore communications. Shaw also warns of incoming forces from
--- the other Soviet outposts nearby.
--- 
--- This base comes under assault by a CCA platoon which establishes itself to the north-west. When Cobra
--- One moves to attack a nearby CCA base and destroys its gun towers a group of American reinforcements
--- are deployed to stop them but the Black Dogs are able to destroy these as well.
--- 
--- Following the mission Shaw is able to use the connection to CCA communications to listen in on
--- communication between the CCA and the NSDF scientists. He concludes that, having been indoctrinated
--- to the communist cause, the Scientists were working with the CCA voluntarily on weapons research
--- using an ancient Cthonian armory. Evidence found within the research building itself indicate that
--- developments made were being passed to Mars to be put into practice. Cobra One and his forces are
--- deployed to investigate.
---
--- Notes
--- The Command Tower should be mission critical for the duration of the mission.
--- CCA research base uses Blast Cannon equipt Gun Towers.
--- Relic is Hadean, suggest using the hocrys model
---
--- Issues (Remove these are they are fixed and move relevent information into Notes)
--- Relic is currently obdata3 artifact, confirm with Hadley if changes are needed.
--- Should the tapped communications be used to hint during the mission at various infomation?
--- Second part of the mission feels like a tutorial beacuse it guides you through making scavs and other pointless elements
--- Cafeteria in the CCA Research base should be renamed to "Research Facility" and be made unkillable or be a trigger for loss
--- Look into Black Dog recycler's build list to determine if it's correct
--- Look at NSDF reinforcement spawns for correct location and makeup, currently Sasquatches trip over hover-units too in the cutscene
--- There are various ways to crash the mission when losing, such as player death.
--- The current factory build list includes a scav... and its order will give people a stroke due to muscle memory.
--- Killing the recycler before the guntowers will break the mission right now, a nilcheck will fix that, but the logic is still confusing.

require("_printfix");

print("\27[34m----START MISSION----\27[0m");

--- @diagnostic disable-next-line: lowercase-global
debugprint = print;
--traceprint = print;

require("_requirefix").addmod("rotbd");

require("_table_show");
local api = require("_api");
local gameobject = require("_gameobject");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");
local tracker = require("_tracker");
local navmanager = require("_navmanager");
local objective = require("_objective");
local utility = require("_utility");
local bit = require("_bit")
local color = require("_color");
local camera = require("_camera");

-- Fill navlist gaps with important navs
navmanager.SetCompactionStrategy(navmanager.CompactionStrategy.ImportantFirstToGap);

-- constrain tracker so it does less work, otherwise when it's required it watches everything
tracker.setFilterTeam(1); -- track team 1 objects
tracker.setFilterClass("scavenger"); -- track scavengers
tracker.setFilterClass("factory"); -- track factories
tracker.setFilterClass("commtower"); -- track comm towers
tracker.setFilterOdf("bvtank"); -- track bvtanks
tracker.setFilterOdf("bvhraz"); -- track bvhraz
tracker.setFilterClass("turrettank"); -- track turrettanks


--- @class RBD01_MissionData_KeyObjects
--- @field nav1 GameObject? -- Nav: Navpoint 1
--- @field nav_solar1 GameObject? -- Nav: Solar Array 1
--- @field nav_solar2 GameObject? -- Nav: Solar Array 2
--- @field nav_research GameObject? -- Nav: Research Facility
--- @field command_tower GameObject? -- Command Tower to tap for communications
--- @field commtower GameObject? -- Comm Tower in research base
--- @field relic GameObject? -- Relic (Hadean Armory)
--- @field cafe GameObject? -- research facility (CCA cafeteria)
--- @field patrol_units GameObject[] -- research base patrol units
--- @field solarfarm1 GameObject[] -- Solar Array 1
--- @field solarfarm2 GameObject[] -- Solar Array 2

--- @class RBD01_MissionData
--- @field key_objects RBD01_MissionData_KeyObjects
local mission_data = {
    key_objects = {
        nav1 = nil, -- Navpoint 1
        nav_solar1 = nil, -- Solar Array 1
        nav_solar2 = nil, -- Solar Array 2
        nav_research = nil, -- Research Facility
        command_tower = nil, -- Command Tower
        commtower = nil, -- Comm Tower
        relic = nil, -- Relic
        cafe = nil, -- Cafeteria (used for camera paths)
        patrol_units = {}, -- Patrol units, used for camera paths
        
        solarfarm1 = {}, -- Solar Array 1
        solarfarm2 = {}, -- Solar Array 2

        sb_turr_1 = nil, -- SB Tower 1
        sb_turr_2 = nil, -- SB Tower 2
    },
};

--- Returns true of all of the handles given are dead
--- areAnyAlive = not areAllDead
--- @param handles GameObject[]
--- @param team integer
--- @return boolean
local function areAllDead(handles, team)
    for i,v in pairs(handles) do
        if v:IsAlive() and (team==nil or team == v:GetTeamNum()) then
            return false;
        end
    end
    return true;
end

--- @class RBD01_Constants_Audio
--- @field intro string
--- @field inspect string
--- @field power1 string
--- @field power2 string
--- @field recycler string
--- @field attack string
--- @field nsdf string
--- @field win string

--- @class RBD01_Constants_Labels
--- @field solarfarm1 string[]
--- @field solarfarm2 string[]
--- @field command_tower string
--- @field patrol_units string[] -- Patrol units in the research base
--- @field relic string -- Relic in the research base
--- @field commtower string -- Comm tower in the research base
--- @field cafe string -- Cafeteria in the research base

--- @class RotBD01_Constants_Names
--- @field cafe string -- Name of the research facility
--- @field nav_research string -- Name of the research facility nav
--- @field nav_solar1 string -- Name of the solar array 1 nav
--- @field nav_solar2 string -- Name of the solar array 2 nav
--- @field nav1 string -- Name of the navpoint 1

--- @class RotBD01_Constants_Objectives
--- @field bdmisn211 string
--- @field bdmisn212 string
--- @field bdmisn213 string
--- @field bdmisn214 string
--- @field bdmisn215 string
--- @field bdmisn311 string
--- @field bdmisn2201 string
--- @field bdmisn2202 string
--- @field bdmisn2204 string
--- @field bdmisn2205 string
--- @field bdmisn2206 string
--- @field bdmisn2207 string
--- @field bdmisn2208 string
--- @field bdmisn2209 string

--- @class RotBD01_Constants
--- @field labels RBD01_Constants_Labels
--- @field names RotBD01_Constants_Names
--- @field objectives RotBD01_Constants_Objectives
local constants = {
    audio = {
        intro = "rbd0101.wav",
        inspect = "rbd0102.wav",
        power1 = "rbd0103.wav",
        power2 = "rbd0104.wav",
        recycler = "rbd0105.wav",
        attack = "rbd0106.wav",
        nsdf = "rbd0107.wav",
        win = "rbd0108.wav"
    },
    labels = {
        solarfarm1 = { "sbspow1_powerplant", "sbspow2_powerplant", "sbspow3_powerplant", "sbspow4_powerplant" },
        solarfarm2 = { "sbspow7_powerplant", "sbspow8_powerplant", "sbspow5_powerplant", "sbspow6_powerplant" },
        command_tower = "sbhqcp0_i76building",
        commtower = "sbcomm1_commtower",
        patrol_units = { "svfigh4_wingman", "svfigh5_wingman" },
        relic = "obdata3_artifact",
        cafe = "sbcafe1_i76building",
    },
    names = {
        cafe = "Research Facility",
        nav_research = "Research Facility",
        nav_solar1 = "Solar Array 1",
        nav_solar2 = "Solar Array 2",
        nav1 = "Navpoint 1",
    },
    objectives = {
        bdmisn211 = "bdmisn211.otf", -- Investigate Command Tower
        bdmisn212 = "bdmisn212.otf", -- Destroy Solar Array 1
        bdmisn213 = "bdmisn213.otf", -- Destroy Solar Array 2
        bdmisn214 = "bdmisn214.otf", -- Destroy American units
        bdmisn215 = "bdmisn215.otf", -- Destroy Research Facility (but we don't it's unkillable)
        bdmisn311 = "bdmisn311.otf", -- Clear area of enemies, recycler is coming
        bdmisn2201 = "bdmisn2201.otf", -- Establish a base at Nav 4
        bdmisn2202 = "bdmisn2202.otf", -- Build 2 Scavengers
        --bdmisn2203 = "bdmisn2203.otf", -- Harvest at least 20 scrap
        bdmisn2204 = "bdmisn2204.otf", -- Build a Factory.
        bdmisn2205 = "bdmisn2205.otf", -- Build an attack force of at least 3 tanks and a bomber
        bdmisn2206 = "bdmisn2206.otf", -- build a base defense of at least 3 turrets
        bdmisn2207 = "bdmisn2207.otf", -- Destroy the soviet base at Nav 1
        bdmisn2208 = "bdmisn2208.otf", -- Destroy incoming attackers
        bdmisn2209 = "bdmisn2209.otf", -- Build a Comm Tower
    }
};

local C = color.ColorLabel;

SetAIControl(2,false);

local function enemiesInRange(dist,place)
    local enemies_nearby = false;
    for v in gameobject.ObjectsInRange(dist,gameobject.isgameobject(place) and place:GetHandle() or place) do
        if(v:IsCraft() and v:GetTeamNum() == 2) then
            enemies_nearby = true;
        end
    end
    return enemies_nearby;
end

local function createWave(odf, path_list, follow)
    local ret = {};
    print("Spawning:" .. odf);
    for i,v in pairs(path_list) do
        local h = gameobject.BuildObject(odf, 2, v);
        if h and follow then
            h:Goto(follow);
        end
        table.insert(ret,h);
    end
    return unpack(ret);
end

-- Define all objectives

--- @class TugRelicConvoy_state : StateMachineIter
--- @field tug GameObject
--- @field apc GameObject
--- @field relic GameObject

-- does this work properly if the tug gets sniped? Oh, it's not snipable
statemachine.Create("tug_relic_convoy",
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand["NONE"] then
            state.tug:Pickup(state.relic);
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand["NONE"] then
            state.tug:Goto("leave_path");
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand["NONE"] then
            state.apc:RemoveObject();
            state.relic:RemoveObject();
            state:next();
        end
    end);

statemachine.Create("delayed_spawn",
    statemachine.SleepSeconds(120),
    function (state)
        createWave("svfigh", {"spawn_n1","spawn_n2"}, "north_path");
        createWave("svtank", {"spawn_n3"},            "north_path");
        state:next();
    end);

local function checkDead(objects)
    for i,v in ipairs(objects) do
        if(v:IsAlive()) then
            return false;
        end
    end
    return true;
end


statemachine.Create("main_objectives", {
    { "start", function (state)
		ColorFade(1.1, 0.4, 0, 0, 0);
        camera.CameraReady();
        AudioMessage(constants.audio.intro);
        state:next();
        return statemachine.FastResult();
    end },
    { "opening_cin", function (state)
        if state:SecondsHavePassed(20) or camera.CameraCancelled() or camera.CameraPath("opening_cin", 2000, 1000, mission_data.key_objects.cafe) then
            state:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            camera.CameraFinish();
            state:next();
        end
    end },
    { "check_command_obj", function (state)
        --- @cast state RotBD01_MissionState
        mission_data.key_objects.nav1 = navmanager.BuildImportantNav(nil, 1, "nav_path", 0);
        mission_data.key_objects.nav1:SetMaxHealth(0);
        mission_data.key_objects.nav1:SetObjectiveName(constants.names.nav1);
        mission_data.key_objects.nav1:SetObjectiveOn();
        objective.AddObjective(constants.objectives.bdmisn211, C.White);
        state:next();
    end },
    { "check_command_passfail", function (state)
        --- @cast state RotBD01_MissionState
        if gameobject.GetPlayer():GetDistance(mission_data.key_objects.command_tower) < 50.0 then
            AudioMessage(constants.audio.inspect);
            mission_data.key_objects.nav1:SetObjectiveOff();
            objective.UpdateObjective(constants.objectives.bdmisn211, C.Green);
            state:next();
        --elseif(not IsAlive(mission_data.key_objects.command)) then
        --    objective.UpdateObjective(constants.objectives.bdmisn211, C.Red);
        --    FailMission(GetTime() + 5,"bdmisn21ls.des");
        --    state:switch("end");
        end
    end },
    { "destory_solar1_obj", function (state)
        --- @cast state RotBD01_MissionState
        mission_data.key_objects.nav_solar1 = navmanager.BuildImportantNav(nil, 1, "nav_path", 1);
        mission_data.key_objects.nav_solar1:SetMaxHealth(0);
        mission_data.key_objects.nav_solar1:SetObjectiveName(constants.names.nav_solar1);
        mission_data.key_objects.nav_solar1:SetObjectiveOn();
        objective.AddObjective(constants.objectives.bdmisn212, C.White);
        state:next();
    end },
   { "destory_solar1_pass", function (state)
        --- @cast state RotBD01_MissionState
        if(checkDead(mission_data.key_objects.solarfarm1)) then
            objective.UpdateObjective(constants.objectives.bdmisn212, color.Green);
			AudioMessage(constants.audio.power1);
            state:next();
        end
    end },
    { "destory_solar2_obj", function (state)
        --- @cast state RotBD01_MissionState
        mission_data.key_objects.nav_solar1:SetObjectiveOff();
        mission_data.key_objects.nav_solar2 = navmanager.BuildImportantNav(nil, 1, "nav_path", 2);
        mission_data.key_objects.nav_solar2:SetMaxHealth(0);
        mission_data.key_objects.nav_solar2:SetObjectiveName("Solar Array 2");
        mission_data.key_objects.nav_solar2:SetObjectiveOn();
        objective.AddObjective(constants.objectives.bdmisn213, color.White);
        state:next();
    end },
    { "destory_solar2_pass", function (state)
        --- @cast state RotBD01_MissionState
        if(checkDead(mission_data.key_objects.solarfarm2)) then
            mission_data.key_objects.nav_solar2:SetObjectiveOff();
            objective.UpdateObjective(constants.objectives.bdmisn213, color.Green);
            state:next();
        end
    end },
    { "destroy_solar_postgap", statemachine.SleepSeconds(3, "destroy_solar_success") },
    { "destroy_solar_success", function (state)
        AudioMessage(constants.audio.power2);
        state:next();
    end },
    { "destroy_comm_start", function (state)
        mission_data.nav_research = navmanager.BuildImportantNav(nil, 1, "nav_path", 3);
        mission_data.nav_research:SetMaxHealth(0);
        mission_data.nav_research:SetObjectiveName("Research Facility");
        mission_data.nav_research:SetObjectiveOn();

        mission_data.key_objects.commtower:SetObjectiveOn();
        
        objective.AddObjective(constants.objectives.bdmisn214, C.White);
        objective.AddObjective(constants.objectives.bdmisn215, C.White);
        camera.CameraReady();

        local tug = gameobject.BuildObject("avhaul", 2, "spawn_tug");
        if not tug then error("Failed to create Tug."); end
        tug:SetMaxHealth(0); -- This is invincible.
        tug:SetPilotClass(""); -- This is invincible.

        local apc = gameobject.BuildObject("avapc", 2, "spawn_apc");
        if not apc then error("Failed to create APC."); end
        apc:SetMaxHealth(0); -- This is invincible.
        apc:SetPilotClass(""); -- This is invincible.

        apc:Follow(tug);

        -- attach values to the StateMachineIter so it can use them
        if not mission_data.mission_states.StateMachines.tug_relic_convoy then
            -- this table will be converted into a StateMachineIter when it first runs
            mission_data.mission_states.StateMachines.tug_relic_convoy = {};
        end
        mission_data.mission_states.StateMachines.tug_relic_convoy.tug = tug;
        mission_data.mission_states.StateMachines.tug_relic_convoy.apc = apc;
        mission_data.mission_states.StateMachines.tug_relic_convoy.relic = mission_data.key_objects.relic;
        mission_data.mission_states:on("tug_relic_convoy");

        --Pickup(tug,globals.relic); -- this seems redundant

        gameobject.BuildObject("avtank", 2, "spawn_tank1"):Goto(mission_data.key_objects.commtower);
        gameobject.BuildObject("avtank", 2, "spawn_tank2"):Goto(mission_data.key_objects.commtower);
        gameobject.BuildObject("avtank", 2, "spawn_tank3"):Goto(mission_data.key_objects.commtower);

        state:next();
    end },
    { "convoy_cin", function (state)
        if camera.CameraCancelled() or camera.CameraPath("convoy_cin", 2000, 2000, mission_data.key_objects.cafe) then
            camera.CameraFinish();
            state:next();
        end
    end },
    { "destroy_obj", function (state)
        if not mission_data.key_objects.commtower:IsAlive() then

            objective.UpdateObjective(constants.objectives.bdmisn214, C.Green);
            objective.UpdateObjective(constants.objectives.bdmisn215, C.Green);
            --SucceedMission(GetTime()+5,"bdmisn21wn.des");
            --Start 22 - Preparations
            --mission.Objective:Start("intermediate");
            --globals.intermediate = statemachine.Start("intermediate", { enemiesAtStart = false });
            

            state:next();
        end
    end },
    function (state)
        --- @cast state RotBD01_MissionState
        objective.ClearObjectives();
        
        mission_data.key_objects.nav1:RemoveObject();
        mission_data.key_objects.nav_solar1:RemoveObject();
        mission_data.key_objects.nav_solar2:RemoveObject();

        -- @todo We might want to re-order the navs here, but we might not, need to talk thorugh it
        -- @todo If we do, moving the nav is hard unless we have SetTeamSlot access.
        -- @todo Consider remaking the nav here to ensure it's at the top?

        --Only show if area is not cleared
        if enemiesInRange(270, mission_data.nav_research) then
            state.research_enemies_still_exist = true;
            objective.AddObjective(constants.objectives.bdmisn311, C.White);
    --      else --Removed due to redundancy
    --          objective.AddObjective("bdmisn311b.otf","yellow"); -- this alternate text says the recycler is coming without warning about extra stuff
        end
        state:next();
    end,
    statemachine.SleepSeconds(90, nil, function (state) return not enemiesInRange(270,mission_data.nav_research) end),
    function (state)
        --- @cast state RotBD01_MissionState
        if state.research_enemies_still_exist then
            objective.UpdateObjective("bdmisn311.otf", C.Green);
            -- if we use the alternate text we have to turn it green here
        end
        AudioMessage(constants.audio.recycler);
        local recy = gameobject.BuildObject("bvrecy22",1,"recy_spawn");
        if not recy then error("Failed to create recycler."); end
        local e1 = gameobject.BuildObject("bvtank",1,GetPositionNear(GetPosition("recy_spawn") or SetVector(),20,100));
        if not e1 then error("Failed to create escort tank 1."); end
        local e2 = gameobject.BuildObject("bvtank",1,GetPositionNear(GetPosition("recy_spawn") or SetVector(),20,100));
        if not e2 then error("Failed to create escort tank 2."); end
        e1:Defend2(recy, 0);
        e2:Defend2(recy, 0);
        --Make recycler follow path
        recy:Goto(mission_data.nav_research, 0);
        state.recy = recy;
        
        recy:SetObjectiveOn();
        --state:success();
        state:next();
    end,
    function (state)
        --- @cast state RotBD01_MissionState
        if state.recy and state.recy:IsWithin(mission_data.nav_research,200) then
            state:next();
        end
    end,
    function (state) -- success state
        --Spawn in recycler
        --Recycler escort

        AddScrap(1,20);
        AddPilot(1,10);
        SetScrap(2,0);
        SetPilot(2,0);
        mission_data.nav_research:SetObjectiveOn();
        --initial wave
        gameobject.BuildObject("svrecy",2,"spawn_svrecy");
        gameobject.BuildObject("svmuf",2,"spawn_svmuf");
        --AudioMessage(constants.audio.attack);
        mission_data.sb_turr_1 = gameobject.BuildObject("sbtowe",2,"spawn_sbtowe1");
        mission_data.sb_turr_2 = gameobject.BuildObject("sbtowe",2,"spawn_sbtowe2");
        --Not really creating a wave, but spawns sbspow
        createWave("sbspow",{"spawn_sbspow1","spawn_sbspow2"});
        --Start wave after a delay?
        createWave("svfigh",{"spawn_n1","spawn_n2","spawn_n3"},"north_path");
        createWave("svtank",{"spawn_n4","spawn_n5"},"north_path"); 
        
        --local instance = deployRecy:start();
        
        --local instance2 = loseRecy:start();
        mission_data.mission_states:on("lose_recy");
        state:next();
        
        --local instance3 = TooFarFromRecy:start();
        --global.mission_states:on("toofarfrom_recy");
    end,
    { "deploy_recycler", function (state)
        objective.AddObjective('bdmisn2201.otf',"WHITE");
        state:next();
    end },
    function (state)
        if gameobject.GetRecycler(1):IsDeployed() then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective(constants.objectives.bdmisn2201, C.Green);
        objective.ClearObjectives();
        
        state:next();
        mission_data.mission_states:on("delayed_spawn");
    end,
    { "make_scavs", function (state)
        mission_data.nav_research:SetObjectiveOff();
        objective.AddObjective('bdmisn2202.otf',"WHITE");
        state:next();
    end },
    function (state)
        --Check if player has 2 scavengers
        if tracker.countByClassName("scavenger", 1) >= 2 then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective(constants.objectives.bdmisn2202, C.Green);
        state:next();
    end,
    { "get_scrap", function (state)
        objective.AddObjective('bdmisn2203.otf',"WHITE");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
        state:next();
    end },
    function (state)
        if GetScrap(1) >= 20 then
            state:next();
        end
    end,
    function (state)
        objective.ClearObjectives();
        state:next();
    end,
    { "make_factory", function (state)
        objective.AddObjective('bdmisn2204.otf',"WHITE");
        state:next();
    end },
    function (state)
        if tracker.countByClassName("factory", 1) >= 1 then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective(constants.objectives.bdmisn2204, C.Green);
        state:next();
    end,
    { "make_comm", function (state)
        objective.AddObjective('bdmisn2209.otf',"WHITE");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
        state:next();
    end },
    function (state)
        if tracker.countByClassName("commtower", 1) >= 1 then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective(constants.objectives.bdmisn2209, C.Green);
        state:switch("destroy_soviet");
    end,
    
    -- SKIPPED STATES?
    { "make_offensive", function (state)
        objective.AddObjective('bdmisn2205.otf',"WHITE");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
        state:next()
    end },
    function (state)
        --Check if got 3 more tanks + 1 bomber, since mission start
        if tracker.countByOdf("bvtank", 1) >= 3 and tracker.countByOdf("bvhraz", 1) >= 1 then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective(constants.objectives.bdmisn2205, C.Green);
        state:next();
    end,
    { "make_defensive", function (state)
        objective.AddObjective('bdmisn2206.otf',"WHITE");
        createWave("svtank",{"spawn_w1"},"west_path"); 
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path"); -- Original Script did nothing with these 2. Possibly sent to guard Scavs instead? -GBD
        createWave("svscav",{"spawn_w2","spawn_w3"});
        state:next();
    end },
    function (state)
        if tracker.countByClassName("turrettank", 1) >= 3 then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective(constants.objectives.bdmisn2206, C.Green);
        state:next();
    end,
    -- /SKIPPED STATES?

    { "destroy_soviet", function (state)
        createWave("svfigh",{"spawn_e1","spawn_e2"},"east_path");
        createWave("svtank",{"spawn_e3"},"east_path");
        -- we never care about this nav again so we don't bother tracking it
        local nav = navmanager.BuildImportantNav(nil, 1, "nav_path", 4);
        if not nav then error("Failed to create nav for CCA base attack."); end
        nav:SetMaxHealth(0);
        nav:SetObjectiveName("CCA Base");
        AudioMessage(constants.audio.attack);
        state:next();
        -- @todo seems objective text is missing here, though maybe the audio handles it?
    end },
    statemachine.SleepSeconds(45),
    function (state) -- this one might have been broken before
        if not (mission_data.sb_turr_1:IsAlive() or mission_data.sb_turr_2:IsAlive()) then
            state:next();
        end
    end,
    function (state)
        --UpdateObjective('bdmisn2207.otf', C.Green);
        gameobject.GetRecycler(2):SetObjectiveOff(); --- @todo had a nil error here

        --mission.Objective:Start('nsdf_attack');
        state:next();
    end,
    { "nsdf_attack", function (state)
        --- @cast state RotBD01_MissionState
        -- @todo the cutscene shows walkers acting like pingpong balls and tanks acting like paddles, might need an adjustment to spawn location
        AudioMessage(constants.audio.nsdf);
        objective.AddObjective('bdmisn2208.otf',"WHITE");
        local a,b,camTarget = createWave("avwalk",{"spawn_avwalk1","spawn_avwalk2","spawn_avwalk3"},"nsdf_path");
        local c,e,g = createWave("avtank",{"spawn_avtank1","spawn_avtank2","spawn_avtank3"},"nsdf_path");
        local d,h,i = createWave("avtank",{"spawn_w1","spawn_w2","spawn_w3"},"west_path");
        local f,j = createWave("svtank",{"spawn_n4","spawn_n5"},"north_path");
        state.camTarget = camTarget;
        state.targets = {a,b,c,d,e,f,g,h,i,camTarget,j};
        camera.CameraReady();
        for i,v in pairs(state.targets) do
            v:SetObjectiveOn();
        end
        if not gameobject.GetRecycler(2):IsAlive() then
            objective.UpdateObjective(constants.objectives.bdmisn2208, C.Green); -- this is odd, this code isn't running anymore right?
        end
        state:next();
        return statemachine.FastResult();
    end },
    function (state)
        --- @cast state RotBD01_MissionState
        if state:SecondsHavePassed(10) or camera.CameraCancelled() or camera.CameraPath("camera_nsdf", 1000, 1500, state.camTarget) then
            state:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            camera.CameraFinish();
            state:next();
        end
    end,
    function (state)
        gameobject.GetRecycler(2):SetObjectiveOn();
        objective.UpdateObjective(constants.objectives.bdmisn2208, C.Green);
        state:next();
    end,
    function (state)
        --- @cast state RotBD01_MissionState
        if areAllDead(state.targets, 2) then
            gameobject.GetRecycler(2):SetObjectiveOn(); --- @todo failed here
            objective.UpdateObjective(constants.objectives.bdmisn2208, C.Green);
            state:next();
        end
    end,
    function (state)
        if not gameobject.GetRecycler(2):IsAlive() then
            objective.UpdateObjective(constants.objectives.bdmisn2207, C.Green);
            state:next();
        end
    end,
    function (state)
        AudioMessage(constants.audio.win);
        SucceedMission(GetTime() + 10, "bdmisn22wn.des");
        state:next();
    end
});

stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))

    :Add("destoryNSDF", function (state)
        if( checkDead(mission_data.key_objects.patrol_units) ) then
            local reinforcements = {
                gameobject.BuildObject("svfigh", 2, "spawn_svfigh1"),
                gameobject.BuildObject("svfigh", 2, "spawn_svfigh2"),
                gameobject.BuildObject("svrckt", 2, "spawn_svrckt1"),
                gameobject.BuildObject("svrckt", 2, "spawn_svrckt2"),
                gameobject.BuildObject("svhraz", 2, "spawn_svhraz")
            };
            -- Send the reinforcements to Nav 4.
            local nav4Pos = mission_data.nav_research:GetPosition();
            if not nav4Pos then error("Failed to get position of nav4."); end
            for i,v in pairs(reinforcements) do
                v:Goto(nav4Pos);
            end
            print("Spawning reinforcements");
            state:off("destoryNSDF");
        end
    end)

    -- this state never runs?
    --:Add("toofarfrom_recy", function (state)
    --    if(gameobject.GetPlayer():IsAlive()) then
    --        if gameobject.GetRecycler(1):IsAlive() and gameobject.GetPlayer():GetDistance(gameobject.GetRecycler(1) or SetVector()) > 700.0 then
    --            print(state.alive);
    --            FailMission(GetTime() + 5, "bdmisn22l1.des");
    --            state:off("toofarfrom_recy");
    --        end
    --    end
    --end)
    
    -- Lose conditions by GBD. No idea if i did this right, mission doesn't update otfs, or goto a next thing, it runs throughout the mission. (distance check until ordered to attack CCA base, and recy loss throughout entire mission.)
    :Add("lose_recy", function (state)
        if not gameobject.GetRecycler(1):IsAlive() then
            FailMission(GetTime() + 5, "bdmisn22l2.des");
            state:off("lose_recy");
        end
	end)

    :Add("delayed_spawn", stateset.WrapStateMachine("delayed_spawn"))
    
    :Add("tug_relic_convoy", stateset.WrapStateMachine("tug_relic_convoy"));

hook.Add("Start", "Mission:Start", function ()
    -- Command tower to tap for communications
    mission_data.key_objects.command_tower = gameobject.GetGameObject(constants.labels.command_tower);

    for _, label in pairs(constants.labels.solarfarm1) do
        local obj = gameobject.GetGameObject(label);
        if obj then
            table.insert(mission_data.key_objects.solarfarm1, obj);
        else
            print("Warning: Solar farm 1 object " .. label .. " not found.");
        end
    end
    
    for _, label in pairs(constants.labels.solarfarm2) do
        local obj = gameobject.GetGameObject(label);
        if obj then
            table.insert(mission_data.key_objects.solarfarm2, obj);
        else
            print("Warning: Solar farm 2 object " .. label .. " not found.");
        end
    end

    -- Research Facility in Research Base
    mission_data.key_objects.cafe = gameobject.GetGameObject(constants.labels.cafe);
    mission_data.key_objects.cafe:SetMaxHealth(0);
    mission_data.key_objects.cafe:SetObjectiveName(constants.names.cafe);

    --- Communication Tower in Research Base
    mission_data.key_objects.commtower = gameobject.GetGameObject(constants.labels.commtower);

    --- Relic in Research Base
    mission_data.key_objects.relic = gameobject.GetGameObject(constants.labels.relic);
    mission_data.key_objects.relic:SetMaxHealth(0);

    --- Patrol Units in Research Base
    for _, label in pairs(constants.labels.patrol_units) do
        local obj = gameobject.GetGameObject(label);
        if obj then
            table.insert(mission_data.key_objects.patrol_units, obj);
        else
            print("Warning: Patrol unit " .. label .. " not found.");
        end
    end

    mission_data.mission_states = stateset.Start("mission"):on("main_objectives");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
    mission_data.mission_states:run();
end);

hook.Add("NavManager:NavSwap", "Mission:NavManager_NavSwap", function (old, new)
    if mission_data.mission_states.StateMachines.main_objectives.nav1 == old then
        mission_data.mission_states.StateMachines.main_objectives.nav1 = new;
    end
    if mission_data.mission_states.StateMachines.main_objectives.nav_solar1 == old then
        mission_data.mission_states.StateMachines.main_objectives.nav_solar1 = new;
    end
    if mission_data.mission_states.StateMachines.main_objectives.nav_solar2 == old then
        mission_data.mission_states.StateMachines.main_objectives.nav_solar2 = new;
    end
    if mission_data.nav_research == old then
        mission_data.nav_research = new;
    end
end);

--hook.Add("CreateObject", "Mission:CreateObject", function (object) end);

--hook.Add("AddObject", "Mission:AddObject", function (object) end);

--hook.Add("DeleteObject", "Mission:DeleteObject", function (object) end);

hook.AddSaveLoad("Mission",
function()
    return mission_data;
end,
function(g)
    mission_data = g;
end);

require("_audio_dev");
require("_cheat_bzrave")
require("_cheat_bzskip");
hook.Add("Cheat", "Mission:Cheat", function (cheat)
    if cheat == "BZSKIP" then
        local machine_state = mission_data.mission_states.StateMachines.main_objectives;
        --- @cast machine_state StateMachineIter
        machine_state:SecondsHavePassed(); -- clear timer in case we were in one
        --CameraFinish(); -- clearing a camera when there is none will crash
        machine_state:next(); -- move to the next state
    end
end);



--- @class RotBD01_MissionState : StateMachineIter
--- \@field recy GameObject?
--- \@field nav1 GameObject?
--- \@field command GameObject?
--- \@field nav_solar1 GameObject?
--- \@field nav_solar2 GameObject?
--- \@field handles GameObject[]?
--- \@field target_l1 string[]
--- \@field target_l2 string[]
--- @field research_enemies_still_exist boolean?
--- @field targets GameObject[]?
--- @field camTarget GameObject?