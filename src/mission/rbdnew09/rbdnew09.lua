--- Rise of the Black Dogs
---
--- [7] Pirates of the Frozen Sea
--- Original Mission:
--- [9] Capture the Armory
---
--- World: Europa (Jupiter II), Jupiter (Sol V)
--- Map Data: Deus Ex Ceteri
---
--- Authors:
--- * ?
--- * John "Nielk1" Klein
---
--- High Level Objectives
--- Secure armory
--- 
--- Events
--- The Black Dogs relocated to Europa to find the area around the base swarming with Coalition units on high-alert due to nearby Fury activity. With a full frontal assault impossible, Shaw inserts Cobra One at the head of an attack wing to sneak through the canyons and capture the base with as little combat as possible.
--- 
--- Cobra One is given the choice to carefully time a direct route through the patrols in the canyons or take a more winding path that results in lower risk of confrontation but slower progress, running the risk of encountering more Furies later.
--- 
--- The attack wing arrives at the base to discover that it is not built around a single relic as expected, but is in fact build within a much larger Hadean research and development site. Without the option of stealing the relic Cobra One is forced to secure the site against all nearby enemy units.
--- 
--- Further investigation of the site reveals that it was the primary site of the Stymphalian Birds project, and the technology found here should exponentially advance the combat capability of Black Dog units. With the relic trail complete the Black Dogs pack up to return to the main base on the moon.
--- 
--- Notes
--- Fury units to be Isis Vanguard fliers.
--- Fury attacks come in waves; allows player to choose to attack during or between waves.

local logger = require("_logger");

logger.print(logger.LogLevel.DEBUG, nil, "\27[34m----START MISSION----\27[0m");

require("_requirefix").addmod("rotbd");

local api = require("_api");
local gameobject = require("_gameobject");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");
--local tracker = require("_tracker");
local navmanager = require("_navmanager");
local objective = require("_objective");
local utility = require("_utility");
local color = require("_color");
local producer = require("_producer");
local patrol = require("_patrol");
local paths = require("_paths");
local waves = require("_waves");

--- @class RBD09_Constants_Audio
--- @field intro string
--- @field found string
--- @field clear string
--- @field warn1 string
--- @field win string

--- @class RBD09_Constants_Objectives
--- @field findRelic string
--- @field secureSite string
--- @field captureRecycler string
--- @field rbd0903 string
--- @field rbd0904 string
--- @field rbd0905 string
--- @field rbd0906 string

--- @class RBD09_Constants_Debriefing
--- @field apc string
--- @field rbd09wn string

--- @class RBD09_Constants
--- @field audio RBD09_Constants_Audio
--- @field objectives RBD09_Constants_Objectives
--- @field debriefing RBD09_Constants_Debriefing
local constants = {
    audio = {
        intro = "rbd0901.wav", -- intro
        -- side objective here?
        found = "rbd0902.wav", -- Approaching Base -- Good work, Cobra One. The base should be just up ahead.
        clear = "rbd0903.wav", -- Arrive at Base -- Oh, this place is huge... clear the base and take the Recycler.
        warn1 = "rbd0901W.wav", -- (Destroy Comm Tower) -- Damnit, they know we're here now.
        win = "rbd091wn.wav" -- Good job, Lieutenant. Looks like you're in the clear.

        -- rbd0901L
        -- (Optional objective "Destroy Comm Tower" failed)
        -- SHAW: Well looks like you're too late to destroy their comm tower, the transmission just went out. Just capture the armory and get ready for a helluva fight.

        -- rbd0901S
        -- (Optional objective "Destroy Comm Tower" success)
        -- SHAW: That'll shut them up.

        -- rbd0902W
        -- (Optional objective "Destroy Solar Powers" triggered)
        -- BAKR: Sir, it looks like Cobra One has found the generators powering the base defences.
        -- SHAW: Cobra One, take those out. It should make bypassing the Soviet guntowers a bit less hairy for you.

        -- rbd0903W
        -- (Optional objective "Capture Supply Outpost" triggered)
        -- BAKR: Woah woah woah, hold up, those are NSDF Hangars and Depots... Cobra One get closer, I might be able to switch their access codes through your computer. I'm sure your wingmen would appreciate some patching up.

        -- rbd0904
        -- (After securing the base)
        -- SHAW: Good job. Cobra One, get that base back up and running. Baker, see if you can get inside.
        -- BAKR: Yessir.
        -- GRIG: Radar contact, closing fast! What the hell is that?

        -- rbd0905
        -- (Final, massive Vanguard wave)
        -- SHAW: More of ‘em coming, boys, you're in for a fight!

        -- rbd0906
        -- (Immediately before the wave "turns off")
        -- GRIG: There's too many of them! We can't-

        -- rbd0907
        -- (The Vanguard turn neutral and wander off)
        -- GRIG: Wait, what... Ha! They're giving up! Baker must have found a way to turn them off!
    },
    objectives = {
        findRelic = "rbd0901.otf", -- Locate the opposition base  somewhere to the south-west. Use the APC to capture any recycler that might be there.
        secureSite = "rbd0902.otf", -- Secure the relic site.
        captureRecycler = "rbd0902b.otf", -- Bring the APC close to the recycler to capture it.
        rbd0903 = "rbd0903.otf", -- Set up a base and defend it against opposition forces.
        rbd0904 = "rbd0904.otf", -- Good work! You've captured a supply depot.
        rbd0905 = "rbd0905.otf", -- They're going to notice that their patroling units are missing, go take out that comm before they can warn the rest.
        rbd0906 = "rbd0906.otf", -- You were too late, but we have no time to lose. Continue with the main objective.
    },
    debriefing = {
        apc = "rbd09l01.des", -- You lost the APC.
        --tug = "rbd09l02.des", -- You lost the Tug.
        rbd09wn = "rbd09wn.des" -- success
    }
};

--- @class MissionData09_KeyObjects
--- @field apc GameObject?
--- @field recy GameObject?
--- @field patrol_units GameObject[]

--- @class MissionData09
--- @field mission_states StateSetRunner
--- @field key_objects MissionData09_KeyObjects
--- @field sub_machines StateMachineIter[]
--- @field failed_destroy_comm boolean?
local mission_data = {
    key_objects = {
        patrol_units = {},
    },
    sub_machines = {},
};

--- @param handle GameObject
--- @param odf string
--- @param kill boolean?
--- @return GameObject
local function copyObject(handle,odf,kill)
    local transform = handle:GetTransform();
    if not transform then error("Failed to get transform of " .. handle:GetObjectiveName()) end
    local nObject = gameobject.BuildObject(odf,handle:GetTeamNum(),transform);
    if not nObject then error("Failed to build object " .. odf .. " at " .. tostring(transform)) end
    local pilot = handle:GetPilotClass() or "";
    local hp = handle:GetCurHealth() or 0;
    local mhp = handle:GetMaxHealth() or 0;
    local ammo = handle:GetCurAmmo() or 0;
    local mammo = handle:GetMaxAmmo() or 0;
    local vel = handle:GetVelocity();
    local omega = handle:GetOmega();
    local label = handle:GetLabel();
    local d = handle:IsDeployed();
    local currentCommand = handle:GetCurrentCommand();
    local currentWho = handle:GetCurrentWho();
    local independence = handle:GetIndependence();
    local weapons = {
        handle:GetWeaponClass(0),
        handle:GetWeaponClass(1),
        handle:GetWeaponClass(2),
        handle:GetWeaponClass(3),
        handle:GetWeaponClass(4),
    };
    for i=1,#weapons do
        nObject:GiveWeapon(weapons[i],i-1);
    end
    nObject:SetTransform(transform);
    --SetMaxAmmo(nObject,mammo);
    --SetMaxHealth(nObject,mhp);
    nObject:SetCurHealth(hp);
    nObject:SetCurAmmo(hp);
    print("Kill?",kill);
    if(handle:IsAliveAndPilot()) then
        nObject:SetPilotClass(pilot);
    elseif((not handle:IsAlive()) and kill) then
        handle:RemovePilot();
    end
    if label == nil then error("Label is nil") end
    nObject:SetLabel(label); --- @todo figure out if a nil param is possible in stock API
    nObject:SetVelocity(vel);
    nObject:SetOmega(omega);
    if(not handle:IsBusy()) then
      --SetCommand(nObject,currentCommand,0,currentWho,transform,0);
    end
    if(d) then
        nObject:Deploy();
    end
    nObject:SetOwner(handle:GetOwner());
    return nObject;
    --RemoveObject(handle);
end


--local WaveSpawner = require("wavec").WaveSpawner;

--function AddToPatrolTask(handle,p_id,sequencer)
--  --Look for enemies
--    local r = bzRoutine.routineManager:getRoutine(p_id);
--    if(r) then
--        r:addHandle(handle);
--    end
--end
--[[
  Notes:
    - Damage base when player arrives
    - MAYBE: let nsdf rebuild destroyed buildings
    - Some furies attack when the player has secured the site
]]

-- Added by Herp McDerperson 06/30/21
function ChangeTeamAndReplace(origHandle, odfName, newTeam)
    local origXfrm = origHandle:GetTransform();
    origHandle:RemoveObject();
	local newHandle = gameobject.BuildObject(odfName, newTeam, origXfrm);
    return newHandle
end




local function areAnyDead(handles)
    for _,v in pairs(handles) do
        if not v:IsAlive() then
            return true;
        end
    end
    return false;
end

local function areAllDead(handles, team)
    for i,v in pairs(handles) do
        if v:IsAlive() and (team==nil or team == v:GetTeamNum()) then
            return false;
        end
    end
    return true;
end

--- @class MainObjectives09_state : StateMachineIter
--- @field default_waves table<string, string[]>
--- @field extra_waves table<string, string[]>
--- @field units_to_kill GameObject[]
--- @field extraUnits boolean?
--- @field wave_timer integer
statemachine.Create("main_objectives", {
    { "captureRelic.init", function(state)
        --- @cast state MainObjectives09_state
 
        -- init
        mission_data.key_objects.apc = gameobject.GetGameObject("apc");
        mission_data.key_objects.recy = gameobject.GetGameObject("recycler");
        --state.check_interval = 50;
        --state.cframe = 0;
        --state.otfs = {
        --    findRelic = "rbd0901.otf",
        --    secureSite = "rbd0902.otf",
        --    captureRecycler = "rbd0902b.otf"
        --};

        -- start -- (patrol_id,patrol_units) from Start
        --state.patrol_id = patrol_id;
        --state.patrol_units = patrol_units;
        --state:startTask("findRelic");
        --if constants.objectives.findRelic ~= nil then
            objective.AddObjective(constants.objectives.findRelic);
        --end
        AudioMessage(constants.audio.intro);

        mission_data.mission_states:on("apc");

        state:next();
    end },
    { "findRelic.update.findRelic", function(state)
        --- @cast state MainObjectives09_state
        local ph = gameobject.GetPlayer();
        if ph == nil then error("Player handle is nil"); end
        if ph:GetDistance("relic_site") < 400 then
            --state:taskSucceed("findRelic");
            objective.UpdateObjective(constants.objectives.findRelic, "GREEN");
            AudioMessage(constants.audio.found);
            mission_data.key_objects.recy:SetTeamNum(0);
            --state:startTask("secureSite");
            --if(constants.objectives.secureSite ~= nil) then
                objective.AddObjective(constants.objectives.secureSite);
            --end
            state:next();
        end
    end },
    { "findRelic.update.cframeSleep", statemachine.SleepSeconds(50) },
    { "findRelic.update.secureSite", function(state)
        --- @cast state MainObjectives09_state
        --local tMap = {};
        --local pp = GetPathPoints("relic_site");
        local pp = utility.IteratorToArray(paths.IteratePath("relic_site"));
        local foundPower = false;
        local foundTurret = false;
        for obj in gameobject.ObjectsInRange(Length(pp[2]-pp[1]),pp[1]) do
            local cp = obj:GetClassLabel();
            if obj:GetTeamNum() == 2 and obj:IsAlive() then
                --tMap[cp] = true;
                --local other = ({turret="powerplant",powerplant="turret"})[cp];
                --if other ~= nil and tMap[other] then
                --    state:next();
                --    return;
                --elseif other == nil and obj:IsCraft() then
                --    state:next();
                --    return;
                --end
                if cp == "powerplant" then
                    foundPower = true;
                elseif cp == "turret" then
                    foundTurret = true;
                end
                if foundPower and foundTurret then
                    logger.print(logger.LogLevel.DEBUG, nil, "Found both powerplant and turret");
                    break;
                end
            end
        end
        if not foundPower or not foundTurret then
            state:next();
        else
            state:switch("findRelic.update.cframeSleep");
        end
    end },
    { "findRelic.update.secureSite.secure", function(state)
        --- @cast state MainObjectives09_state
        --state:taskSucceed("secureSite");
        AudioMessage(constants.audio.clear);
        local pp = utility.IteratorToArray(paths.IteratePath("relic_site"));
        for obj in gameobject.ObjectsInRange(Length(pp[2]-pp[1]),pp[1]) do
            if obj:IsBuilding() and obj:GetTeamNum() == 2 then
                obj:SetTeamNum(1);
            elseif obj:GetClassLabel() == "turret" and obj:GetTeamNum() == 2 then
                local odf = obj:GetOdf();
                ChangeTeamAndReplace(obj, odf, 1);
            end
        end
        --state:startTask("captureRecycler");
        objective.ClearObjectives();
        --if(constants.objectives.captureRecycler ~= nil) then
            objective.AddObjective(constants.objectives.captureRecycler);
        --end
        state:next();
    end },
    { "findRelic.update.captureRecycler", function(state)
        --- @cast state MainObjectives09_state
        if mission_data.key_objects.apc:IsWithin(mission_data.key_objects.recy,40) then
            mission_data.key_objects.apc:Stop(0);
            --state:taskSucceed("captureRecycler");
            objective.UpdateObjective(constants.objectives.captureRecycler,"GREEN");
            mission_data.key_objects.recy:SetTeamNum(1);
            SetScrap(1,30);
            copyObject(mission_data.key_objects.apc,"bvapc");
            mission_data.key_objects.apc:RemoveObject();
            --state:success();
            --mission.Objective:Start("defendSite",state.patrol_id,state.patrol_units);
            mission_data.mission_states:off("apc", true);
            state:next();
        end
    end },
    { "defendSite.start", function(state)
        --- @cast state MainObjectives09_state
        --state.patrol_id = patrol_id;
        --bzRoutine.routineManager:killRoutine(patrol_id);
        mission_data.patrol_r = nil; -- once we add reference tracking there will be no more references
        --local sideObjectives = mission.Objective:getObjective("sideObjectives"):getInstance();
        --state.extraUnits = sideObjectives:call("_hasBeenDetected"); -- check if side_objectives.destroy_comm has failed.  Will force it to fail if it is active, else will force it to end
        state.extraUnits = mission_data.failed_destroy_comm;
        state.units_to_kill = mission_data.key_objects.patrol_units;
        local baseDelay = 3*60;
        local defaultVanguardDelay = 7*60;
        local extraUnitsVanguardDelay = 4*60;
        local defaultWave2Delay = 2*60;
        local defaultWave4Delay = 3*60;
        local extraUnitsWave4Delay = defaultWave4Delay;
        --- @todo look into replacing absolute time offsets with offsets "relative to prior" so we can use our normal sleep logic.
        state.default_waves = {
            [("%d"):format(baseDelay                    )] = {"2 2 4","1 4 1"}, -- 3 * 60          = 180 (3m)
            [("%d"):format(baseDelay + defaultWave2Delay)] = {"2 3","1 1"},     -- 3 * 60 + 2 * 60 = 300 (5m)
            [("%d"):format( state.extraUnits and (baseDelay + defaultVanguardDelay                    ) or (baseDelay + extraUnitsVanguardDelay                       ) )] = {"5", "5"},     -- (3 * 60 + 7 * 60         ) OR (3 * 60 + 4 * 60         ) -> 600 OR 420 -> 10m or 7m
            [("%d"):format( state.extraUnits and (baseDelay + defaultVanguardDelay + defaultWave4Delay) or (baseDelay + extraUnitsVanguardDelay + extraUnitsWave4Delay) )] = {"5 5", "5 5"}, -- (3 * 60 + 7 * 60 + 3 * 60) OR (3 * 60 + 4 * 60 + 3 * 60) -> 13m OR 10m
        };
        state.extra_waves = {
            [("%d"):format(7 * 60 + 60 * 2 + 15)] = {"4 1 1"},             -- 420 + 135 = 555 (9m 15s)
            [("%d"):format(7 * 60 + 60 * 3     )] = {"2 4 4","4 1 1"},     -- 420 + 180 = 360 (10m)
            [("%d"):format(7 * 60 + 60 * 3 + 30)] = {"2 2 4 4","3 1 1 1"}, -- 420 + 210 = 390 (10m 30s)
            [("%d"):format(7 * 60 + 60 * 5     )] = {"2 2 2 4","3 4 1 1"}, -- 420 + 300 = 480 (12m)
        };
        for i, v in pairs(state.units_to_kill) do
            --local s = mission.TaskManager:sequencer(v);
            --s:clear(); -- if we're clearing an old sequencer we need to make the replacement state machine stored in a way you can access it via that
            v:Stop(0);
            ----Looks for target, if not found goto relic site
            --s:queue3("FindTarget","relic_site");

            --if v.task_sequencer then
            --    v.task_sequencer:switch(nil); -- switch the existing machine to a nil state so it gets cleaned up by our collects that cleans up stopped machines
            --end
            mission_data.patrol:RemoveGameObject(v);

            local machine = statemachine.Start("nsdf_attack_relic_site", nil, { v = v, alt = "relic_site" });
            table.insert(mission_data.sub_machines, machine);
        end
        objective.AddObjective(constants.objectives.rbd0903);
        state.wave_timer = 0;
        --state:startTask("spawn_waves");
        state:next();
    end },
    { "defendSite.spawn_waves.update", function(state, dtime)
        --- @cast state MainObjectives09_state
        state.wave_timer = state.wave_timer + dtime;
        local done = true;
        for i, v in pairs(state.default_waves) do
            done = false;
            local d = tonumber(i);
            if state.wave_timer >= d then
                local wave, lead = waves.SpawnInFormation(v, "nsdf_attack", nil, { "avfigh","avtank","avrckt","avltnk","hvngrd" }, 2);
                if not wave then error("Failed to spawn wave") end
                if not lead then error("Failed to get lead") end
                lead:Goto("nsdf_attack");
                for i2, v2 in pairs(wave) do
                    --local s = mission.TaskManager:sequencer(v2);
                    if v2 ~= lead  then
                        v2:Follow(lead);
                    end
                    --s:queue3("FindTarget","relic_site");
                    local machine = statemachine.Start("nsdf_attack_relic_site", nil, { v = v2, alt = "relic_site" });
                    table.insert(mission_data.sub_machines, machine);

                    table.insert(state.units_to_kill, v2);
                end
                state.default_waves[i] = nil;
            end
        end
        if state.extraUnits then
            for i, v in pairs(state.extra_waves) do
                done = false;
                local d = tonumber(i);
                if state.wave_timer >= d then
                    local wave, lead = waves.SpawnInFormation(v,"nsdf_attack",nil,{"avfigh","avtank","avrckt","avltnk","hvngrd"}, 2);
                    if not wave then error("Failed to spawn wave") end
                    if not lead then error("Failed to get lead") end
                    lead:Goto("nsdf_attack");
                    for i2, v2 in pairs(wave) do
                        --local s = mission.TaskManager:sequencer(v2);
                        if v2 ~= lead then
                            v2:Follow(lead);
                        end
                        --s:queue3("FindTarget","relic_site");
                        local machine = statemachine.Start("nsdf_attack_relic_site", nil, { v = v2, alt = "relic_site" });
                        table.insert(mission_data.sub_machines, machine);
 
                        table.insert(state.units_to_kill, v2);
                    end
                    state.extra_waves[i] = nil;
                end
            end
        end
        if(done) then
            --state:taskSucceed("spawn_waves");
            --state:startTask("kill_waves");
            state:next();
        end
    end },
    { "defendSite.kill_waves.update", function(state)
        --- @cast state MainObjectives09_state
        if(areAllDead(state.units_to_kill, 2)) then
            --state:taskSucceed("kill_waves");
            objective.UpdateObjective(constants.objectives.rbd0903, "GREEN");
            --state:success();
            AudioMessage(constants.audio.win);
            SucceedMission(GetTime() + 15, constants.debriefing.rbd09wn);
            state:next();
        end
    end }
});






--- @class SideObjectivesDestroyComm09_state : StateMachineIter
--- @field commtower GameObject
--- @field comm_timer integer
--- @field units GameObject[]
statemachine.Create("side_objectives.destroy_comm", {
    { "init", function(state)
        --- @cast state SideObjectivesDestroyComm09_state
        -- init
        local commtower = gameobject.GetGameObject("commtower");
        if not commtower then error("Failed to get commtower") end
        state.commtower = commtower;
        state.comm_timer = 60*4;

        -- start -- function(state,patrol_units)
        state.units = mission_data.key_objects.patrol_units;
        --state:startTask("capture_supply");
        state:next();
    end },
    { "hold_to_start", function(state)
        --- @cast state SideObjectivesDestroyComm09_state
        if state.commtower:IsAlive() and areAnyDead(state.units) then
            state:next();
        end
    end },
    { "task_start", function(state)
        --- @cast state SideObjectivesDestroyComm09_state
        AudioMessage(constants.audio.warn1);
        objective.AddObjective(constants.objectives.rbd0905);
        StartCockpitTimer(state.comm_timer, state.comm_timer * 0.5, state.comm_timer * 0.1);
        state.commtower:SetObjectiveOn();
        state:next();
    end },
    { "update", function(state)
        --- @cast state SideObjectivesDestroyComm09_state
        --state.comm_timer = state.comm_timer - dtime;
        --if(state.comm_timer <= 0) then
        if GetCockpitTimer() <= 0 then
            --state:taskFail("destroy_comm");
            objective.ReplaceObjective(constants.objectives.rbd0905, constants.objectives.rbd0906, "YELLOW");
            StopCockpitTimer();
            HideCockpitTimer();
            state.commtower:SetObjectiveOff();
            mission_data.failed_destroy_comm = true;
            state:next();
        elseif not state.commtower:IsAlive() then
            --state:taskSucceed("destroy_comm");
            objective.UpdateObjective(constants.objectives.rbd0905, "GREEN");
            StopCockpitTimer();
            HideCockpitTimer();
            state:next();
        end
    end }
});




--- @class nsdf_attack_relic_site_state : StateMachineIter
--- @field v GameObject
--- @field alt string
statemachine.Create("nsdf_attack_relic_site", {
    function (state)
        --- @cast state nsdf_attack_relic_site_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    { "FindTarget", function (state)
        --- @cast state nsdf_attack_relic_site_state

        local target = state.v:GetNearestEnemy();
        if target and target:IsValid() then
            --sequencer:queue2("Attack",GetNearestEnemy(handle));
            --sequencer:queue3("FindTarget", state.alt);
            state.v:Attack(target);
            state:switch("Wait");
        elseif state.v:GetDistance(state.alt) > 50 then
            --sequencer:queue2("Goto", state.alt);
            --sequencer:queue3("FindTarget", state.alt);
            state.v:Goto(state.alt);
            state:switch("Wait");
        else
            --sequencer:queue(AiCommand["Hunt"]);
            state.v:Hunt();
            state:switch("Wait");
        end

    end },
    { "Wait",
    function (state)
        --- @cast state nsdf_attack_relic_site_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:switch("FindTarget");
        end
    end },
});








stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
    :Add("side_objectives.destroy_comm", stateset.WrapStateMachine("side_objectives.destroy_comm"))
    :Add("side_objectives.capture_supply", function(state, name)
        local secure = true;
        local pp = utility.IteratorToArray(paths.IteratePath("supply_site"));
        local l = Length(pp[2] - pp[1])
        if gameobject.GetPlayer():GetDistance(pp[1]) < l then
            for obj in gameobject.ObjectsInRange(l, pp[1]) do
                if obj:IsCraft() and obj:GetTeamNum() == 2 then
                    secure = false;
                    break;
                end
            end
            if(secure) then
                local pp = utility.IteratorToArray(paths.IteratePath("supply_site"));
                for obj in gameobject.ObjectsInRange(Length(pp[2] - pp[1]), pp[1]) do
                    if obj:IsBuilding() and obj:GetTeamNum() == 2 then
                        obj:SetTeamNum(1);
                    end
                end
                objective.AddObjective(constants.objectives.rbd0904, "GREEN");
                state:off(name, true);
            end
        end
    end)
    :Add("apc", function(state, name)
        if not mission_data.key_objects.apc:IsAlive() then
            FailMission(GetTime() + 5.0 ,constants.debriefing.apc);
        end
    end)
;

















local function setUpPatrols()
    --local patrol_rid, patrol_r = bzRoutine.routineManager:startRoutine("PatrolRoutine");
    --- @type PatrolEngine patrol_r
    local patrol_r = patrol.new();

    --what are our `checkpoint` locations?
    patrol_r:RegisterLocations({"l_comm","l_c1","l_c2","l_c3","l_solar","l_north","l_west","l_sw"});

    patrol_r:DefineRoutes("l_comm",{
        p_comm_c3 = "l_c3"
    });
 
    patrol_r:DefineRoutes("l_c1",{
        p_c1_c2 = "l_c2",
        p_c1_sw = "l_sw"
    });

    patrol_r:DefineRoutes("l_c2",{
        p_c2_c3 = "l_c3",
        p_c2_north = "l_north"
    });
 
    patrol_r:DefineRoutes("l_c3",{
        p_c3_comm = "l_comm",
        p_c3_c1 = "l_c1"
    });

    patrol_r:DefineRoutes("l_solar",{
        p_solar_c3 = "l_c3"
    });

    patrol_r:DefineRoutes("l_north",{
        p_north_west = "l_west",
        p_north_solar = "l_solar",
        p_north_comm = "l_comm"
    });

    patrol_r:DefineRoutes("l_west",{
        p_west_c2 = "l_c2"
    });

    patrol_r:DefineRoutes("l_sw",{
        p_sw_c1 = "l_c1"
    });
    --return patrol_rid, patrol_r;
    return patrol_r;
end

hook.Add("Start", "Mission:Start", function ()
    --Set up patrolling units
    local patrol_form = {
        p_comm_c3 = {" 2 ", "3 3"},
        p_west_c2 = {" 2 ", "1 1"},
        p_north_solar = {" 2 ", "3 3"},
        p_c2_c3 = {" 2 ", "3 3"},
        p_sw_c1 = {" 2 ", "1 1"}
    }

    --local p_id, p = setUpPatrols();
    mission_data.patrol = setUpPatrols();
    --mission_data.key_objects.patrol_units = {};
    for i, v in pairs(patrol_form) do
        local units, lead = waves.SpawnInFormation(v, i, nil, {"svfigh", "svtank", "svltnk"}, 2);
        if not units then error("Failed to spawn units") end
        if not lead then error("Failed to get lead") end
        for _, v2 in pairs(units) do
            table.insert(mission_data.key_objects.patrol_units,v2);
            if(v2 ~= lead) then
                --local s = mission.TaskManager:sequencer(v2);
                v2:Follow(lead);
                --s:queue3("AddToPatrolTask",p_id);
                mission_data.patrol:AddGameObject(v2);

                --v2.task_sequencer = s;
            end
        end
        mission_data.patrol:AddGameObject(lead);
    end
    local i = 1;
    local h;
    repeat
        h = gameobject.GetGameObject(("patrol%d"):format(i));
        i = i + 1;
    until not h or not h:IsValid()

    local player_units, apc = waves.SpawnInFormation({" 1 ", "2 2 2", "4  2  4"},"player_units",nil,{"bvapc09","bvtank","bvraz","bvltnk"},1,7);
    if not apc then error("Failed to get APC") end
    apc:SetLabel("apc");
    --captureRelic:start(p_id,patrol_units);
    --sideObjectives:start(patrol_units);
    --core:onStart();

    mission_data.mission_states = stateset.Start("mission")
        :on("main_objectives")
        :on("side_objectives.destroy_comm")
        :on("side_objectives.capture_supply");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
    if mission_data.sub_machines then
        -- call update on all items and remove them if they return false
        for i = #mission_data.sub_machines, 1, -1 do
            local v = mission_data.sub_machines[i];
            if(v) then
                local success = v:run(dtime);
                --- @cast success StateMachineIterWrappedResult
                if not success or (statemachine.isstatemachineiterwrappedresult(success) and success.Abort) then
                    table.remove(mission_data.sub_machines,i); -- clean up dead machines from the list
                end
            end
        end
    end

    mission_data.mission_states:run(dtime); -- passed dtime in for the waves logic
end);

--function CreateObject(handle)
--    core:onCreateObject(handle);
--    mission:CreateObject(handle);
--end
--
--function AddObject(handle)
--    core:onAddObject(handle);
--    mission:AddObject(handle);
--end
--
--function DeleteObject(handle)
--    core:onDeleteObject(handle);
--    mission:DeleteObject(handle);
--end

hook.AddSaveLoad("Mission",
function()
    return mission_data;
end,
function(g)
    mission_data = g;
end);

print("\27[34m----END MISSION----\27[0m");
--- @todo remove dev cheats and modules
require("_audio_dev");