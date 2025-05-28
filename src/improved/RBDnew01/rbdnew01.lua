--Combination of Grab The Scientists and Preparations

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

local mission_data = {};

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
        local h = gameobject.BuildGameObject(odf, 2, v);
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
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        state.tug:Pickup(state.relic);
        state:next();
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        state.tug:Goto("leave_path");
        state:next();
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        if state.tug:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state TugRelicConvoy_state
        state.apc:RemoveObject();
        state.relic:RemoveObject();
        state:next();
    end);

statemachine.Create("delayed_spawn",
    statemachine.SleepSeconds(120),
    function (state)
        createWave("svfigh",{"spawn_n1","spawn_n2"},"north_path");
        createWave("svtank",{"spawn_n3"},"north_path");
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
        camera.CameraReady();
        AudioMessage(audio.intro);
        state:next();
    end },
    { "opening_cin", function (state)
        if state:SecondsHavePassed(20) or camera.CameraPath("opening_cin", 2000, 1000, mission_data.cafe) or camera.CameraCancelled() then
            state:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            camera.CameraFinish();
            state:next();
        end
    end },
    { "check_command_obj", function (state)
        --- @cast state RBD01_Mission_state
        state.nav1 = navmanager.BuildImportantNav(nil, 1, "nav_path", 0);
        state.nav1:SetMaxHealth(0);
        state.nav1:SetObjectiveName("Navpoint 1");
        state.nav1:SetObjectiveOn();
        objective.AddObjective('bdmisn211.otf', "WHITE");
        state.command = gameobject.GetGameObject("sbhqcp0_i76building");
        state:next();
    end },
    { "check_command_passfail", function (state)
        --- @cast state RBD01_Mission_state
        if gameobject.GetPlayerGameObject():GetDistance(state.command) < 50.0 then
            AudioMessage(audio.inspect);
            state.nav1:SetObjectiveOff();
            objective.UpdateObjective('bdmisn211.otf',"GREEN");
            state:next();
        --elseif(not IsAlive(state.command)) then
        --    objective.UpdateObjective('bdmisn211.otf',"red");
        --    FailMission(GetTime() + 5,"bdmisn21ls.des");
        --    state:switch("end");
        end
    end },
    { "destory_solar1_obj", function (state)
        --- @cast state RBD01_Mission_state
        
        -- move this to configuration
        state.target_l1 = {"sbspow1_powerplant","sbspow2_powerplant","sbspow3_powerplant","sbspow4_powerplant"};
        state.target_l2 = {"sbspow7_powerplant","sbspow8_powerplant","sbspow5_powerplant","sbspow6_powerplant"};

        state.nav_solar1 = navmanager.BuildImportantNav(nil, 1, "nav_path", 1);
        state.nav_solar1:SetMaxHealth(0);
        state.nav_solar1:SetObjectiveName("Solar Array 1");
        state.nav_solar1:SetObjectiveOn();
        objective.AddObjective('bdmisn212.otf',"WHITE");
        state.handles = {};
        for i,v in pairs(state.target_l1) do
            state.handles[i] = gameobject.GetGameObject(v)
        end
        state:next();
    end },
   { "destory_solar1_pass", function (state)
        --- @cast state RBD01_Mission_state
        if(checkDead(state.handles)) then
            objective.UpdateObjective('bdmisn212.otf',"GREEN");
			AudioMessage(audio.power1);
            state:next();
        end
    end },
    { "destory_solar2_obj", function (state)
        --- @cast state RBD01_Mission_state
        state.nav_solar1:SetObjectiveOff();
        state.nav_solar2 = navmanager.BuildImportantNav(nil, 1, "nav_path", 2);
        state.nav_solar2:SetMaxHealth(0);
        state.nav_solar2:SetObjectiveName("Solar Array 2");
        state.nav_solar2:SetObjectiveOn();
        objective.AddObjective('bdmisn213.otf',"WHITE");
        state.handles = {};
        for i,v in pairs(state.target_l2) do
            state.handles[i] = gameobject.GetGameObject(v);
        end
        state:next();
    end },
    { "destory_solar2_pass", function (state)
        --- @cast state RBD01_Mission_state
        if(checkDead(state.handles)) then
            state.nav_solar2:SetObjectiveOff();
            objective.UpdateObjective('bdmisn213.otf',"GREEN");
            state:next();
        end
    end },
    { "destroy_solar_postgap", statemachine.SleepSeconds(3, "destroy_solar_success") },
    { "destroy_solar_success", function (state)
        AudioMessage(audio.power2);
        state:next();
    end },
    { "destroy_comm_start", function (state)
        mission_data.nav_research = navmanager.BuildImportantNav(nil, 1, "nav_path", 3);
        mission_data.nav_research:SetMaxHealth(0);
        mission_data.nav_research:SetObjectiveName("Research Facility");
        mission_data.nav_research:SetObjectiveOn();

        mission_data.comm:SetObjectiveOn();
        
        objective.AddObjective('bdmisn214.otf',"WHITE");
        objective.AddObjective('bdmisn215.otf',"WHITE");
        camera.CameraReady();
        local apc = gameobject.BuildGameObject("avapc",2,"spawn_apc");
        if not apc then error("Failed to create APC."); end
        local tug = gameobject.BuildGameObject("avhaul",2,"spawn_tug");
        if not tug then error("Failed to create Tug."); end
        tug:SetMaxHealth(0); -- This is invincible.
        apc:SetMaxHealth(0); -- This is invincible.
        tug:SetPilotClass(""); -- This is invincible.
        apc:SetPilotClass(""); -- This is invincible.
        apc:Follow(tug);

        -- attach values to the StateMachineIter so it can use them
        if not mission_data.mission_states.StateMachines.tug_relic_convoy then
            -- this table will be converted into a StateMachineIter when it first runs
            mission_data.mission_states.StateMachines.tug_relic_convoy = {};
        end
        mission_data.mission_states.StateMachines.tug_relic_convoy.tug = tug;
        mission_data.mission_states.StateMachines.tug_relic_convoy.apc = apc;
        mission_data.mission_states.StateMachines.tug_relic_convoy.relic = mission_data.relic;
        mission_data.mission_states:on("tug_relic_convoy");

        --Pickup(tug,globals.relic); -- this seems redundant

        gameobject.BuildGameObject("avtank",2,"spawn_tank1"):Goto(mission_data.comm);
        gameobject.BuildGameObject("avtank",2,"spawn_tank2"):Goto(mission_data.comm);
        gameobject.BuildGameObject("avtank",2,"spawn_tank3"):Goto(mission_data.comm);

        state:next();
    end },
    { "convoy_cin", function (state)
        if camera.CameraPath("convoy_cin",2000,2000, mission_data.cafe) or camera.CameraCancelled() then
            camera.CameraFinish();
            state:next();
        end
    end },
    { "destroy_obj", function (state)
        if not mission_data.comm:IsAlive() then

            objective.UpdateObjective('bdmisn214.otf',"GREEN");
            objective.UpdateObjective('bdmisn215.otf',"GREEN");
            --SucceedMission(GetTime()+5,"bdmisn21wn.des");
            --Start 22 - Preparations
            --mission.Objective:Start("intermediate");
            --globals.intermediate = statemachine.Start("intermediate", { enemiesAtStart = false });
            

            state:next();
        end
    end },
    function (state)
        --- @cast state RBD01_Mission_state
        objective.ClearObjectives();
            
        state.nav1:RemoveObject();
        state.nav_solar1:RemoveObject();
        state.nav_solar2:RemoveObject();

        -- @todo We might want to re-order the navs here, but we might not, need to talk thorugh it
        -- @todo If we do, moving the nav is hard unless we have SetTeamSlot access.
        -- @todo Consider remaking the nav here to ensure it's at the top?

        --Only show if area is not cleared
        if(enemiesInRange(270,mission_data.nav_research)) then
            state.research_enemies_still_exist = true;
            objective.AddObjective("bdmisn311.otf","WHITE");
    --      else --Removed due to redundancy
    --          objective.AddObjective("bdmisn311b.otf","yellow"); -- this alternate text says the recycler is coming without warning about extra stuff
        end
        state:next();
    end,
    statemachine.SleepSeconds(90, nil, function (state) return not enemiesInRange(270,mission_data.nav_research) end),
    function (state)
        --- @cast state RBD01_Mission_state
        if state.research_enemies_still_exist then
            objective.UpdateObjective("bdmisn311.otf","GREEN");
            -- if we use the alternate text we have to turn it green here
        end
        AudioMessage(audio.recycler);
        local recy = gameobject.BuildGameObject("bvrecy22",1,"recy_spawn");
        if not recy then error("Failed to create recycler."); end
        local e1 = gameobject.BuildGameObject("bvtank",1,GetPositionNear(GetPosition("recy_spawn") or SetVector(),20,100));
        if not e1 then error("Failed to create escort tank 1."); end
        local e2 = gameobject.BuildGameObject("bvtank",1,GetPositionNear(GetPosition("recy_spawn") or SetVector(),20,100));
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
        --- @cast state RBD01_Mission_state
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
        gameobject.BuildGameObject("svrecy",2,"spawn_svrecy");
        gameobject.BuildGameObject("svmuf",2,"spawn_svmuf");
        --AudioMessage(audio.attack);
        mission_data.sb_turr_1 = gameobject.BuildGameObject("sbtowe",2,"spawn_sbtowe1");
        mission_data.sb_turr_2 = gameobject.BuildGameObject("sbtowe",2,"spawn_sbtowe2");
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
        if gameobject.GetRecyclerGameObject(1):IsDeployed() then
            state:next();
        end
    end,
    function (state)
        objective.UpdateObjective('bdmisn2201.otf',"GREEN");
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
        objective.UpdateObjective('bdmisn2202.otf',"GREEN");
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
        objective.UpdateObjective('bdmisn2204.otf',"GREEN");
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
        objective.UpdateObjective('bdmisn2209.otf',"GREEN");
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
        objective.UpdateObjective('bdmisn2205.otf',"GREEN");
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
        objective.UpdateObjective('bdmisn2206.otf',"GREEN");
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
        AudioMessage(audio.attack);
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
        --UpdateObjective('bdmisn2207.otf',"GREEN");
        gameobject.GetRecyclerGameObject(2):SetObjectiveOff();

        --mission.Objective:Start('nsdf_attack');
        state:next();
    end,
    { "nsdf_attack", function (state)
        --- @cast state RBD01_Mission_state
        -- @todo the cutscene shows walkers acting like pingpong balls and tanks acting like paddles, might need an adjustment to spawn location
        AudioMessage(audio.nsdf);
        objective.AddObjective('bdmisn2208.otf',"WHITE");
        local a,b,camTarget = createWave("avwalk",{"spawn_avwalk1","spawn_avwalk2","spawn_avwalk3"},"nsdf_path");
        local c,e,g = createWave("avtank",{"spawn_avtank1","spawn_avtank2","spawn_avtank3"},"nsdf_path");
        local d,h,i = createWave("avtank",{"spawn_w1","spawn_w2","spawn_w3"},"west_path");
        local f,j = createWave("svtank",{"spawn_n4","spawn_n5"},"north_path");
        state.camTarget = camTarget;
        camera.CameraReady();
        state.targets = {a,b,c,d,e,f,g,h,i,camTarget,j};
        for i,v in pairs(state.targets) do
            v:SetObjectiveOn();
        end
        if not gameobject.GetRecyclerGameObject(2):IsAlive() then
            objective.UpdateObjective('bdmisn2208.otf',"GREEN"); -- this is odd, this code isn't running anymore right?
        end
        state:next();
    end },
    function (state)
        --- @cast state RBD01_Mission_state
        if (state:SecondsHavePassed(10) or camera.CameraPath("camera_nsdf", 1000, 1500, state.camTarget) or camera.CameraCancelled()) then
            state:SecondsHavePassed(); -- clear timer if we got here without it being cleared
            camera.CameraFinish();
            state:next();
        end
    end,
    function (state)
        gameobject.GetRecyclerGameObject(2):SetObjectiveOn();
        objective.UpdateObjective('bdmisn2208.otf',"GREEN");
        state:next();
    end,
    function (state)
        --- @cast state RBD01_Mission_state
        if areAllDead(state.targets, 2) then
            gameobject.GetRecyclerGameObject(2):SetObjectiveOn();
            objective.UpdateObjective('bdmisn2208.otf',"GREEN");
            state:next();
        end
    end,
    function (state)
        if not gameobject.GetRecyclerGameObject(2):IsAlive() then
            objective.UpdateObjective("bdmisn2207.otf","GREEN");
            state:next();
        end
    end,
    function (state)
        AudioMessage(audio.win);
        SucceedMission(GetTime() + 10, "bdmisn22wn.des");
        state:next();
    end
});

stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))

    :Add("destoryNSDF", function (state)
        if( checkDead(mission_data.patrolUnits) ) then
            local reinforcements = {
                gameobject.BuildGameObject("svfigh", 2, "spawn_svfigh1"),
                gameobject.BuildGameObject("svfigh", 2, "spawn_svfigh2"),
                gameobject.BuildGameObject("svrckt", 2, "spawn_svrckt1"),
                gameobject.BuildGameObject("svrckt", 2, "spawn_svrckt2"),
                gameobject.BuildGameObject("svhraz", 2, "spawn_svhraz")
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
    --    if(gameobject.GetPlayerGameObject():IsAlive()) then
    --        if gameobject.GetRecyclerGameObject(1):IsAlive() and gameobject.GetPlayerGameObject():GetDistance(gameobject.GetRecyclerGameObject(1) or SetVector()) > 700.0 then
    --            print(state.alive);
    --            FailMission(GetTime() + 5, "bdmisn22l1.des");
    --            state:off("toofarfrom_recy");
    --        end
    --    end
    --end)
    
    -- Lose conditions by GBD. No idea if i did this right, mission doesn't update otfs, or goto a next thing, it runs throughout the mission. (distance check until ordered to attack CCA base, and recy loss throughout entire mission.)
    :Add("lose_recy", function (state)
        if not gameobject.GetRecyclerGameObject(1):IsAlive() then
            FailMission(GetTime() + 5, "bdmisn22l2.des");
            state:off("lose_recy");
        end
	end)

    :Add("delayed_spawn", stateset.WrapStateMachine("delayed_spawn"))
    
    :Add("tug_relic_convoy", stateset.WrapStateMachine("tug_relic_convoy"));

hook.Add("Start", "Mission:Start", function ()
    mission_data.cafe = gameobject.GetGameObject("sbcafe1_i76building");
    mission_data.comm = gameobject.GetGameObject("sbcomm1_commtower");
    mission_data.relic = gameobject.GetGameObject("obdata3_artifact");
    mission_data.relic:SetMaxHealth(0);
    mission_data.patrolUnits = {
        gameobject.GetGameObject("svfigh4_wingman"),
        gameobject.GetGameObject("svfigh5_wingman")
    };

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