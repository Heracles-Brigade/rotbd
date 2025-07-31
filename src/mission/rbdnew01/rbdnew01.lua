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
--- During the events of Total Destruction a group of NSDF researchers on the moon are captured by the CCA. The Liberty and Freedom are already at Titan (Saturn VI) and travel to join them from Europa (Jupiter II) will take the Justice, the Black Dog's carrier, through the inner solar system. The Black Dog platoon under Commander Cameron Shaw deploys on the destroyer Jackson as the Justice approaches Earth.
--- 
--- Shaw's platoon deploy and infiltrate the base, using a CCA command tower to listen in on Soviet communications and determine the scientists' precise location. After locating the base Cobra One is ordered to destroy the solar farms that power it to weaken its defences before the Black Dog wing launches its attack.
--- 
--- Before they can move on the base a wing of American forces arrive and extract both the scientists and the relic they were working on. Telling his men that these forces must be Communist defectors Shaw orders his men to give chase, but the wing escapes despite their efforts. The Black Dogs clear the CCA forces out and capture the outpost.
--- 
--- Following the loss of the original objective due to interference by defectors Shaw declares that the Black Dogs are no longer able to trust the American forces in the area and orders the construction of a new command base so they can investigate the abandoned research building and coordinate their forces without relying on the potentially compromised NSDF infrastructure in the area. A recycler is delivered to Cobra One for deployment at the site of the Soviet research outpost and he is instructed to build a Satellite Tower to facilitate ship-to-shore communications. Shaw also warns of incoming forces from the other Soviet outposts nearby.
--- 
--- This base comes under assault by a CCA platoon which establishes itself to the north-west. When Cobra One moves to attack a nearby CCA base and destroys its gun towers a group of American reinforcements are deployed to stop them but the Black Dogs are able to destroy these as well.
--- 
--- Following the mission Shaw is able to use the connection to CCA communications to listen in on communication between the CCA and the NSDF scientists. He concludes that, having been indoctrinated to the communist cause, the Scientists were working with the CCA voluntarily on weapons research using an ancient Cthonian armory. Evidence found within the research building itself indicate that developments made were being passed to Mars to be put into practice. Cobra One and his forces are deployed to investigate.
---
--- Issues (Remove these are they are fixed and move relevent information into Notes)
--- Should the tapped communications be used to hint during the mission at various infomation?
--- Establish a base at Nav 4 is an odd objective, since the nav, while in slot 4 if you didn't make other navs, is not called "Nav 4".

local logger = require("_logger");

logger.print(logger.LogLevel.DEBUG, nil, "\27[34m----START MISSION----\27[0m");

require("_requirefix").addmod("rotbd");
--require("_requirefix").addmod("3362534335");

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

--- @class RBD01_Constants_Audio
--- @field intro string -- "need to tap comms to find scientists"
--- @field lost_command_tower string -- "we lost soviet communications, what the hell? (failure)"
--- @field early_base_approach string -- "those guntowers will kill you, take out power first"
--- @field inspect string -- "found them, destroy solars to cripple facility"
--- @field power1 string -- "power fluctuations, take out the rest"
--- @field power2 string -- "power down, oh no the NSDF are helping the CCA!"
--- @field recycler string -- "sending you a recycler"
--- @field lost_recycler string -- "soviets destroyed recycler (failure)"
--- @field attack string -- "CCA trying to create forward base at command tower"
--- @field nsdf string -- "major attack force incoming! destroy defactors!"
--- @field win string -- "good job"

--- @class RBD01_Constants_Labels
--- @field solarfarm1 string[]
--- @field solarfarm2 string[]
--- @field command_tower string
--- @field patrol_units string[] -- Patrol units in the research base
--- @field relic string -- Relic in the research base
--- @field commtower string -- Comm tower in the research base
--- @field cafe string -- Cafeteria in the research base
--- @field sb_towers string[] -- Soviet Blast Towers in the research base

--- @class RBD01_Constants_Names
--- @field cafe string -- Name of the research facility
--- @field nav_research string -- Name of the research facility nav
--- @field nav_solar1 string -- Name of the solar array 1 nav
--- @field nav_solar2 string -- Name of the solar array 2 nav
--- @field nav1 string -- Name of the navpoint 1

--- @class RBD01_Constants_Objectives
--- @field bdmisn211 string -- Investigate Command Tower
--- @field bdmisn212 string -- Destroy Solar Array 1
--- @field bdmisn213 string -- Destroy Solar Array 2
--- @field bdmisn214 string -- Destroy American units
--- @field bdmisn215 string -- Destroy Research Facility (but we don't it's unkillable)
--- @field bdmisn311 string -- Clear area of enemies, recycler is coming
--- @field bdmisn2201 string -- Establish a base at Nav 4
--- @field bdmisn2202 string -- Build 2 Scavengers
--- @field bdmisn2203 string -- Harvest at least 20 scrap
--- @field bdmisn2204 string -- Build a Factory.
--- @field bdmisn2205 string -- Build an attack force of at least 3 tanks and a bomber
--- @field bdmisn2206 string -- build a base defense of at least 3 turrets
--- @field bdmisn2207 string -- Destroy the soviet base at Nav 1
--- @field bdmisn2208 string -- Destroy incoming attackers
--- @field bdmisn2209 string -- Build a Comm Tower

--- @class RBD01_Constants_Debriefing
--- @field loss_killed_command_tower string -- Command Tower destroyed (by player)
--- @field loss_command_tower_died string -- Command Tower destroyed (player didn't defend)
--- @field loss_recycler_destroyed string -- You allowed your recycler to be destroyed.
--- @field win string -- We have a foothold on the moon now

--- @class RBD01_Constants
--- @field audio RBD01_Constants_Audio
--- @field labels RBD01_Constants_Labels
--- @field names RBD01_Constants_Names
--- @field objectives RBD01_Constants_Objectives
--- @field debriefing RBD01_Constants_Debriefing
--- @field blast_tower_warn_distance number
local constants = {
    audio = {
        intro = "rbd0101.wav",
        lost_command_tower = "rbd0101l.wav",
        early_base_approach = "rbd0101w.wav",
        inspect = "rbd0102.wav",
        power1 = "rbd0103.wav",
        power2 = "rbd0104.wav",
        recycler = "rbd0105.wav",
        lost_recycler = "rbd0102l.wav",
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
        sb_towers = { "sbtowerb1", "sbtowerb2", "sbtowerb3", "sbtowerb4", "sbtowerb5", "sbtowerb6" },
    },
    names = {
        cafe = "Research Facility",
        nav_research = "Research Facility",
        nav_solar1 = "Solar Array 1",
        nav_solar2 = "Solar Array 2",
        nav1 = "Navpoint 1",
    },
    objectives = {
        bdmisn211 = "bdmisn211.otf",
        bdmisn212 = "bdmisn212.otf",
        bdmisn213 = "bdmisn213.otf",
        bdmisn214 = "bdmisn214.otf",
        bdmisn215 = "bdmisn215.otf",
        bdmisn311 = "bdmisn311.otf",
        bdmisn2201 = "bdmisn2201.otf",
        bdmisn2202 = "bdmisn2202.otf",
        bdmisn2203 = "bdmisn2203.otf",
        bdmisn2204 = "bdmisn2204.otf",
        bdmisn2205 = "bdmisn2205.otf",
        bdmisn2206 = "bdmisn2206.otf",
        bdmisn2207 = "bdmisn2207.otf",
        bdmisn2208 = "bdmisn2208.otf",
        bdmisn2209 = "bdmisn2209.otf",
    },
    debriefing = {
        loss_killed_command_tower = "bdmisn21ls.des",
        loss_command_tower_died = "rbdnew01l1.des",
        loss_recycler_destroyed = "rbdnew01l2.des",
        win = "rbdnew01w.des",
    },
    blast_tower_warn_distance = 300,
};

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
--- @field sb_turr_1 GameObject? -- SB Tower 1
--- @field sb_turr_2 GameObject? -- SB Tower 2
--- @field sb_towers GameObject[] -- Soviet Blast Towers of base

--- @class RBD01_MissionData
--- @field key_objects RBD01_MissionData_KeyObjects
--- @field protect_command_tower boolean -- do "failed to protect" instead of "why did you kill?"
--- @field forward_rec_already_dead boolean -- Forward Recycler already dead so focus user on GTs
local mission_data = {
    key_objects = {
        nav1 = nil,
        nav_solar1 = nil,
        nav_solar2 = nil,
        nav_research = nil,
        command_tower = nil,
        commtower = nil,
        relic = nil,
        cafe = nil,
        patrol_units = {},
 
        solarfarm1 = {},
        solarfarm2 = {},

        sb_turr_1 = nil,
        sb_turr_2 = nil,

        sb_towers = {},
    },
    protect_command_tower = false,
    forward_rec_already_dead = false,
};

--- Dummy function that, if it somehow returned true, would cause the tutorial like build sequence
--- @return boolean
local function IsEasyDifficulty()
    return false;
end

-- Terse Aliases
local C = color.ColorLabel;

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
    local followStart = GetPosition(follow);
    followStart.y = 0;
    for _,v in pairs(path_list) do
        --local h = gameobject.BuildObject(odf, 2, v);

        -- spawn looking toward the follow point
        local spawnPoint = GetPosition(v);
        spawnPoint.y = 0;
        local direction = followStart - spawnPoint;
        local h = gameobject.BuildObject(odf, 2, BuildDirectionalMatrix(spawnPoint, direction));

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
        if state.tug:GetCurrentCommand() == AiCommand.NONE then
            state.tug:Pickup(state.relic);
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand.NONE then
            state.tug:Goto("leave_path");
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand.NONE then
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

--- @class message_delayed_event_state : StateMachineIter
--- @field message AudioMessage
--- @
statemachine.Create("lose_recy",
    function (state)
        --- @cast state message_delayed_event_state
        local recycler = gameobject.GetRecycler(1);
        if not recycler or not recycler:IsAlive() then
            state.message = AudioMessage(constants.audio.lost_recycler);
            state:next();
        end
    end,
    function (state)
        --- @cast state message_delayed_event_state
        if not state.message or IsAudioMessageDone(state.message) then
            FailMission(GetTime() + 5, constants.debriefing.loss_recycler_destroyed);
            state:next();
        end
    end);

statemachine.Create("lose_command_tower",
    function (state)
        --- @cast state message_delayed_event_state
        if mission_data.key_objects.command_tower then
            if not mission_data.key_objects.command_tower or not mission_data.key_objects.command_tower:IsAlive() then
                if mission_data.protect_command_tower then
                    state.message = AudioMessage(constants.audio.lost_command_tower);
                end
                state:next();
            end
        end
    end,
    function (state)
        --- @cast state message_delayed_event_state
        if not state.message or IsAudioMessageDone(state.message) then
            if mission_data.protect_command_tower then
                FailMission(GetTime() + 5, constants.debriefing.loss_command_tower_died);
            else
                FailMission(GetTime() + 5, constants.debriefing.loss_killed_command_tower);
            end
            state:next();
        end
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
        --- @cast state RBD01_MissionState
        mission_data.key_objects.nav1 = navmanager.BuildImportantNav(nil, 1, "nav_path", 0);
        mission_data.key_objects.nav1:SetMaxHealth(0);
        mission_data.key_objects.nav1:SetObjectiveName(constants.names.nav1);
        mission_data.key_objects.nav1:SetObjectiveOn();
        objective.AddObjective(constants.objectives.bdmisn211, C.White);
        state:next();
    end },
    { "check_command_passfail", function (state)
        --- @cast state RBD01_MissionState
        local player = gameobject.GetPlayer();
        if player and player:GetDistance(mission_data.key_objects.command_tower) < 50.0 then
            mission_data.protect_command_tower = true;
            mission_data.mission_states:on("base_guntower_warn");
            AudioMessage(constants.audio.inspect);
            mission_data.key_objects.nav1:SetObjectiveOff();
            objective.UpdateObjective(constants.objectives.bdmisn211, C.Green);
            state:next();
        end
    end },
    { "destory_solar1_obj", function (state)
        --- @cast state RBD01_MissionState
        mission_data.key_objects.nav_solar1 = navmanager.BuildImportantNav(nil, 1, "nav_path", 1);
        mission_data.key_objects.nav_solar1:SetMaxHealth(0);
        mission_data.key_objects.nav_solar1:SetObjectiveName(constants.names.nav_solar1);
        mission_data.key_objects.nav_solar1:SetObjectiveOn();
        objective.AddObjective(constants.objectives.bdmisn212, C.White);
        state:next();
    end },
   { "destory_solar1_pass", function (state)
        --- @cast state RBD01_MissionState
        if(checkDead(mission_data.key_objects.solarfarm1)) then
            objective.UpdateObjective(constants.objectives.bdmisn212, C.Green);
			AudioMessage(constants.audio.power1);
            state:next();
        end
    end },
    { "destory_solar2_obj", function (state)
        --- @cast state RBD01_MissionState
        mission_data.key_objects.nav_solar1:SetObjectiveOff();
        mission_data.key_objects.nav_solar2 = navmanager.BuildImportantNav(nil, 1, "nav_path", 2);
        mission_data.key_objects.nav_solar2:SetMaxHealth(0);
        mission_data.key_objects.nav_solar2:SetObjectiveName("Solar Array 2");
        mission_data.key_objects.nav_solar2:SetObjectiveOn();
        objective.AddObjective(constants.objectives.bdmisn213, C.White);
        state:next();
    end },
    { "destory_solar2_pass", function (state)
        --- @cast state RBD01_MissionState
        if(checkDead(mission_data.key_objects.solarfarm2)) then
            mission_data.key_objects.nav_solar2:SetObjectiveOff();
            objective.UpdateObjective(constants.objectives.bdmisn213, C.Green);
            state:next();
        end
    end },
    { "destroy_solar_postgap", statemachine.SleepSeconds(3, "destroy_solar_success") },
    { "destroy_solar_success", function (state)
        mission_data.mission_states:off("base_guntower_warn");
        AudioMessage(constants.audio.power2);
        -- shut down blast guntowers
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
    -- could add a sleep here to smooth it out if needed, but it seems it's not needed
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
            --SucceedMission(GetTime()+5,constants.debriefing.bdmisn21wn);
            --Start 22 - Preparations
            --mission.Objective:Start("intermediate");
            --globals.intermediate = statemachine.Start("intermediate", { enemiesAtStart = false });
 

            state:next();
        end
    end },
    --statemachine.SleepSeconds(5), -- give a few seconds to apreciate success
    function (state)
        --- @cast state RBD01_MissionState
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
    --          objective.AddObjective(constants.objectives.bdmisn311b,"yellow"); -- this alternate text says the recycler is coming without warning about extra stuff
        end
        state:next();
    end,
    statemachine.SleepSeconds(90, nil, function (state) return not enemiesInRange(270,mission_data.nav_research) end),
    function (state)
        --- @cast state RBD01_MissionState
        if state.research_enemies_still_exist then
            objective.UpdateObjective(constants.objectives.bdmisn311, C.Green);
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
        --- @cast state RBD01_MissionState
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
        objective.AddObjective(constants.objectives.bdmisn2201,C.White);
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
 
        if IsEasyDifficulty() then
            state:next();
        else
            state:switch("make_comm");
        end
        mission_data.mission_states:on("delayed_spawn");
    end,

    -- START tutorial zone
    { "make_scavs", function (state)
        mission_data.nav_research:SetObjectiveOff();
        objective.AddObjective(constants.objectives.bdmisn2202,C.White);
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
        objective.AddObjective(constants.objectives.bdmisn2203,C.White);
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
        objective.AddObjective(constants.objectives.bdmisn2204,C.White);
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
    -- END tutorial zone

    { "make_comm", function (state)
        objective.AddObjective(constants.objectives.bdmisn2209,C.White);
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
        objective.AddObjective(constants.objectives.bdmisn2205,C.White);
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
        objective.AddObjective(constants.objectives.bdmisn2206,C.White);
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
		objective.AddObjective(constants.objectives.bdmisn2207, C.White);
    end },
    statemachine.SleepSeconds(45),
    function (state) -- this one might have been broken before
        if not (mission_data.sb_turr_1:IsAlive() or mission_data.sb_turr_2:IsAlive()) then
            state:next();
        elseif not mission_data.forward_rec_already_dead then
            local badRec = gameobject.GetRecycler(2);
            if not badRec or not badRec:IsAlive() then
                if mission_data.sb_turr_1:IsAlive() then
                    mission_data.sb_turr_1:SetObjectiveOn();
                end
                if mission_data.sb_turr_2:IsAlive() then
                    mission_data.sb_turr_2:SetObjectiveOn();
                end
                mission_data.forward_rec_already_dead = true;
            end
        end
    end,
    function (state)
        local badRec = gameobject.GetRecycler(2);
		if badRec and badRec:IsAlive() then
			badRec:SetObjectiveOff();
            objective.UpdateObjective(constants.objectives.bdmisn2207, C.Yellow); -- base destruction on hold
        else
            objective.UpdateObjective(constants.objectives.bdmisn2207, C.Green); -- base already destroyed
		end

		--mission.Objective:Start('nsdf_attack');
        state:next();
    end,
    { "nsdf_attack", function (state)
        --- @cast state RBD01_MissionState
        AudioMessage(constants.audio.nsdf);
        objective.AddObjective(constants.objectives.bdmisn2208, C.White);
        local a,b,camTarget = createWave("avwalk",{"spawn_avwalk1","spawn_avwalk2","spawn_avwalk3"},"nsdf_path");
        local c,e,g = createWave("avtank",{"spawn_avtank1","spawn_avtank2","spawn_avtank3"},"nsdf_path");
        local d,h,i = createWave("avtank",{"spawn_w1","spawn_w2","spawn_w3"},"west_path");
        local f,j = createWave("svtank",{"spawn_n4","spawn_n5"},"north_path");
        state.camTarget = camTarget;
        state.targets = {a,b,c,d,e,f,g,h,i,camTarget,j};
        camera.CameraReady();
        for _,v in pairs(state.targets) do
            v:SetObjectiveOn();
        end
        state:next();
        return statemachine.FastResult();
    end },
    function (state)
        --- @cast state RBD01_MissionState
        if state:SecondsHavePassed(10) or camera.CameraCancelled() or camera.CameraPath("camera_nsdf", 1000, 1500, state.camTarget) then
            state:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            camera.CameraFinish();
            objective.UpdateObjective(constants.objectives.bdmisn2208, C.White);
            state:next();
        end
    end,
    function (state)
        --- @cast state RBD01_MissionState
        if areAllDead(state.targets, 2) then
            objective.UpdateObjective(constants.objectives.bdmisn2208, C.Green);

            local badRec = gameobject.GetRecycler(2);
			if badRec and badRec:IsAlive() then
				badRec:SetObjectiveOn();
                objective.UpdateObjective(constants.objectives.bdmisn2207, C.White);
			end

            state:next();
        end
    end,
    function (state)
        local badRec = gameobject.GetRecycler(2);
        if not badRec or not badRec:IsAlive() then
            objective.UpdateObjective(constants.objectives.bdmisn2207, C.Green);
            state:next();
        end
    end,
    function (state)
        --- @cast state RBD01_MissionState
        state.win_audio = AudioMessage(constants.audio.win);
        state:next();
    end,
    function (state)
        --- @cast state RBD01_MissionState
        if not state.win_audio or IsAudioMessageDone(state.win_audio) then
            -- Wait for the audio to finish before proceeding
            SucceedMission(GetTime() + 5, constants.debriefing.win);
            state:next();
        end
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
 
    :Add("lose_recy", stateset.WrapStateMachine("lose_recy"))

    :Add("lose_command_tower", stateset.WrapStateMachine("lose_command_tower"))

    :Add("base_guntower_warn", function (state)
        local player = gameobject.GetPlayer();
        if not player or not player:IsAlive() then
            return;
        end
        for _, tower in pairs(mission_data.key_objects.sb_towers) do
            if tower and tower:IsAlive() and tower:GetDistance(player) < constants.blast_tower_warn_distance then
                AudioMessage(constants.audio.early_base_approach);
                state:off("base_guntower_warn");
                break;
            end
        end
	end)

    :Add("delayed_spawn", stateset.WrapStateMachine("delayed_spawn"))
 
    :Add("tug_relic_convoy", stateset.WrapStateMachine("tug_relic_convoy"));

hook.Add("Start", "Mission:Start", function ()
    -- Command tower to tap for communications
    mission_data.key_objects.command_tower = gameobject.GetGameObject(constants.labels.command_tower);

    for _, label in pairs(constants.labels.sb_towers) do
        local obj = gameobject.GetGameObject(label);
        if obj then
            table.insert(mission_data.key_objects.sb_towers, obj);
        else
            print("Warning: Soviet Blast Tower object " .. label .. " not found.");
        end
    end

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

    mission_data.mission_states = stateset.Start("mission")
        :on("main_objectives")
        :on("lose_command_tower");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
    mission_data.mission_states:run();
end);

hook.Add("NavManager:NavSwap", "Mission:NavManager_NavSwap", function (old, new)
    if mission_data.key_objects.nav1 == old then
        mission_data.key_objects.nav1 = new;
    end
    if mission_data.key_objects.nav_solar1 == old then
        mission_data.key_objects.nav_solar1 = new;
    end
    if mission_data.key_objects.nav_solar2 == old then
        mission_data.key_objects.nav_solar2 = new;
    end
    if mission_data.key_objects.nav_research == old then
        mission_data.key_objects.nav_research = new;
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
        camera.CameraFinish(); -- protected camera exit that won't crash
        machine_state:next(); -- move to the next state
    end
end);



--- @class RBD01_MissionState : StateMachineIter
--- @field recy GameObject?
--- @field win_audio AudioMessage?
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