--- Rise of the Black Dogs
---
--- [4] The Hunt Begins
--- Original Mission:
--- [5] The Last Stand
--- [6] Evacuate Venus
---
--- World: Venus (Sol II)
--- Map Data: Deus Ex Ceteri
---
--- Authors:
--- * ?
--- * John "Nielk1" Klein
--- 
--- High Level Objectives
--- Retrieve and defend Io relics
--- 
--- Events
---
--- The next set of coordinates leads the Black Dogs to Venus, near the outskirts of a large Coalition base. Cobra One is sent out to secure the relic while Shaw directs the construction of a command base from orbit.
--- 
--- Cobra One reaches and investigates the relic with minimal CCA resistance, but the Coalition are very quick to realise something is up and send a much larger force to secure the area. Fearing that they might discover the relic, Shaw orders Cobra One to destroy it - when that fails he orders the area bombed and retrieves as much information as possible via Cobra One's uplink before ordering him to evacuate. Shaw's base comes under attack while the data is transferring, but Cobra One is unable to assist without interrupting the transmission. When the Day Wrecker arrives he barely escapes it; the incoming forces do not.
--- 
--- Cobra One is forced to rush back to assist in the base's defence and is given command, but is too late to do anything of use and is instead ordered to destroy the Communication Tower coordinating the assault. When this is destroyed the influx of CCA forces stops, but the base is too damaged to support any further operations and, now that they have the data in hand, Shaw orders its evacuation. Two APCs are dropped at the landing site to the east and Cobra One is ordered to escort them first to the base and then to the dust-off site, past the remaining CCA forces and a hastily-erected blockade.
--- 
--- The data from the down ship reveals that the Stymphalian Birds were an elite fighter squadron designed to combat the Heracles Brigade. It also indicates the location of a Hadean research base on Io where part of the project was conducted.
---
--- Notes
--- Stymphalian Bird is at dust-off point to the north-west
--- Leaving relic too early results in mission failure
--- 
--- Issues
--- * Ensure player's pilot is correct pilot
--- * Objective stuck after destroying relic, check if fixed
--- * Constructor is given to player but not able to be ordered (factory was already destroyed in my test)
--- * Constructor can't build lpower, only spower, might need to swawp it (fixed autobuilder by type override)
--- * Rec can't make factory or constructor, is this intended?
--- * Stop all allies from attacking the mammoth once you are told it won't work, do a scan to gather than and stop them if they have such an order
--- * The attack force aimed at you when you shoot the soviet comm must be killed to advance the mission
---   * This is odd as they might come too slow, should probably look at objectifying them or killing them if you move too far away from them
--- * Consider swapping the cafeteria and barracks for black dog ones (NSDF style)
--- * Camera sequence needs timing adjustments
--- relic doesn't go enemy right away when voiceover starts, meaning it takes a while before you shoot at it
--- why does the armory have a DW that cost 200, why not remove it?

local logger = require("_logger");

logger.print(logger.LogLevel.DEBUG, nil, "\27[34m----START MISSION----\27[0m");

require("_requirefix");

require("_table_show");
local gameobject = require("_gameobject");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");
local navmanager = require("_navmanager");
local objective = require("_objective");
local producer = require("_producer");
local patrol = require("_patrol");
local camera = require("_camera");
local waves = require("_waves");
local paths = require("_paths");

-- Fill navlist gaps with important navs
navmanager.SetCompactionStrategy(navmanager.CompactionStrategy.ImportantFirstToGap);

-- constrain tracker so it does less work, otherwise when it's required it watches everything
--tracker.setFilterTeam(1); -- track team 1 objects
--tracker.setFilterClass("scavenger"); -- track scavengers
--tracker.setFilterClass("factory"); -- track factories
--tracker.setFilterClass("commtower"); -- track comm towers
--tracker.setFilterOdf("bvtank"); -- track bvtanks
--tracker.setFilterOdf("bvhraz"); -- track bvhraz
--tracker.setFilterClass("turrettank"); -- track turrettanks

paths.SetSpecialPathType({"make_bbtowe",
                          "make_bblpow",
                          "make_turrets"}, paths.SpecialPathType.Cloud);
paths.SetSpecialPathType({"26spawn_tank",
                          "26spawn_figh",
                          "26spawn_turr",
                          "26spawn_apc",
                          "26spawn_rock",
                          "26spawn_bomber",
                          "26spawn_nav"}, paths.SpecialPathType.Cloud);
paths.SetSpecialPathType({"spawn_pilots"}, paths.SpecialPathType.Cloud);

paths.LoggerIgnorePath({"walker_path",
                        "player_spawn",
                        "25cin_attack",
                        "25cin_pan2"});

--- @class RBD05_Constants_Audio
--- @field INTRO string -- Intro
--- @field INSPECT string -- Inspecting Relic
--- @field DESTROY_F string -- Relic Won't Die
--- @field DONE_D string -- Done, get back to base!
--- @field BACK_TO_BASE string -- Back at base
--- @field APC_SPAWN string -- Base being overrun, APCs spawned
--- @field PICKUP_DONE string -- Pickup done, escort the APCs to alt dustoff
--- @field WIN string -- Good work, mission complete

--- @class RBD05_Constants_Labels
--- @field GEYSERS string[]

--- @class RBD05_Constants_Objectives
--- @field RENDEZVOUS string -- Rendezvous with Shaw's base
--- @field WAIT_FOR_UNITS string -- Wait for units to be produced.
--- @field INVESTIGATE_RELIC string -- Investigate relic site. Use <I> to inspect any relic you find.
--- @field DESTROY_RELIC string -- Destroy the relic!
--- @field DEFEND_RELIC string -- Defend the site against any CCA forces. Do not leave the site!
--- @field UPLINE_CONNECTING string -- Uplink connecting...
--- @field UPLINK_TRANSMITTING string -- Connection established! Data transmitting...
--- @field RETURN_TO_BASE string -- Return to base!
--- @field UPLINK_RETRY string -- Uplink disconnected. Transmision aborted!
--- @field UPLINK_RUN_NUKE string -- Transmision complete! Get out of there before it blows!
--- @field ESCORT_APC_TO_BASE string -- Escort the APC's to the Black Dog command outpost.
--- @field SEND_APC_TO_EVAC string -- Send the APC's to the evacuation Rendezvous Point.
--- @field ESCORT_APC_TO_EVAC string -- Escort and protect the APC's on route to their destination.
--- @field MEET_APCS string -- Meet up with the two transports.
--- @field DESTROY_SOVIET_COMMS string -- Destroy the Soviet communications tower, located to the North.
--- @field ESCORD_APC_OUTPOST string -- Escort the APC's to the NSDF outpost, to rescue the surviving NSDF personel.

--- @class RBD05_Constants_Debriefing
--- @field LOSS_COMMAND_TOWER_DESTROYED string -- Our Command Tower has been destroyed.
--- @field LOSS_RELIC_ABANDONED string -- You abandoned the relic without completing the examination.
--- @field LOSS_KILLED_RESCUED_MEN string -- You idiot, those were the men you were ordered to rescue!
--- @field LOSS_APC_LOST string -- The attacking forces have destroyed one of your APCs.
--- @field WIN string -- Success

--- @class RBD05_Constants
--- @field AUDIO RBD05_Constants_Audio
--- @field LABELS RBD05_Constants_Labels
--- @field OBJECTIVES RBD05_Constants_Objectives
--- @field DEBRIEFING RBD05_Constants_Debriefing
local CONSTANTS = {
    AUDIO = {
        INTRO = "rbd0501.wav",
        INSPECT = "rbd0502.wav",
        DESTROY_F = "rbd0503.wav",
        DONE_D = "rbd0504.wav",
        BACK_TO_BASE = "rbd0505.wav",
        APC_SPAWN = "rbd0506.wav",
        PICKUP_DONE = "rbd0507.wav",
        WIN = "rbd0508.wav"
    },
    LABELS = {
        GEYSERS = { "eggeizr10_geyser", "eggeizr11_geyser", "eggeizr12_geyser" },
    },
    OBJECTIVES = {
        RENDEZVOUS = "rbd0521.otf",
        WAIT_FOR_UNITS = "rbd0522.otf",
        INVESTIGATE_RELIC = "rbd0523.otf",
        DESTROY_RELIC = "rbd0524.otf",
        DEFEND_RELIC = "rbd0525.otf",
        UPLINE_CONNECTING = "rbd0530.otf",
        UPLINK_TRANSMITTING = "rbd0531.otf",
        RETURN_TO_BASE = "rbd0532.otf",
        UPLINK_RETRY = "rbd0533.otf",
        UPLINK_RUN_NUKE = "rbd0534.otf",
        ESCORT_APC_TO_BASE = "bdmisn2601.otf",
        SEND_APC_TO_EVAC = "bdmisn2602.otf",
        ESCORT_APC_TO_EVAC = "bdmisn2603.otf",
        MEET_APCS = "bdmisn2504.otf",
        DESTROY_SOVIET_COMMS = "rbdnew3502.otf",
        ESCORD_APC_OUTPOST = "rbdnew3503.otf"
    },
    DEBRIEFING = {
        LOSS_COMMAND_TOWER_DESTROYED = "rbdnew15l1.des",
        LOSS_RELIC_ABANDONED = "rbdnew15l2.des",
        LOSS_KILLED_RESCUED_MEN = "rbdnew15l3.des", -- "bdmisn26l2.des"
        LOSS_APC_LOST = "rbdnew15l4.des", -- "bdmisn26l1.des"
        WIN = "rbdnew15w.des"  -- "bdmisn26wn.des"
    }
};

--- @class MissionData05
--- @field patrol_r PatrolEngine?
local mission_data = {};

--- @param handle GameObject
--- @param odf string
--- @param kill boolean
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
    if not label then error("Failed to get label of " .. handle:GetObjectiveName()) end
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

--- @param handles GameObject[]
--- @return boolean
local function checkDead(handles)
    for i,v in pairs(handles) do
        if(v:IsAlive()) then
            return false;
        end
    end
    return true;
end

--- @param odf string
--- @param team TeamNum
--- @param path string
--- @return GameObject[]
local function spawnAtPath(odf,team,path)
    local handles = {};
    local current = paths.GetPosition(path);
    local prev = nil;
    local c = 0;
    while current and current ~= prev do
        c = c + 1;
        table.insert(handles,gameobject.BuildObject(odf,team,current));
        prev = current;
        current = paths.GetPosition(path,c);
    end
    return handles;
end

local function checkAnyDead(handles)
    for i,v in pairs(handles) do
        if(not v:IsAlive()) then
            return true;
        end
    end
    return false;
end

SetAIControl(2, false);
SetAIControl(3, false);

statemachine.Create("cca_relic_attack",
    function (state)
        --- @cast state CCA_Relic_Attack_state
        if state.v:GetCurrentCommand() == AiCommand.NONE then
            state:next();
        end
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        state.v:Goto("cca_relic_attack");
        state:next();
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        if state.v:GetCurrentCommand() == AiCommand.NONE then
            state:next();
        end
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        state.v:Defend2(state.relic);
        state:next();
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        if state.v:GetCurrentCommand() == AiCommand.NONE then
            state:next();
        end
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        state.v:Defend();
        state:next();
        return statemachine.AbortResult();
    end);

statemachine.Create("cca_attack_base",
    function (state)
        --- @cast state CCA_Relic_Attack_state
        if state.v:GetCurrentCommand() == AiCommand.NONE then
            state:next();
        end
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        state.v:Goto("front_line");
        state:next();
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        if state.v:GetCurrentCommand() == AiCommand.NONE then
            state:next();
        end
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        state.v:Defend();
        state:next();
        return statemachine.AbortResult();
    end);

--- This machine takes all existing attackers from the patrol engine and hands them to a "cca_attack_base" machine.
statemachine.Create("defendRelic.cca_attack_base", {
    function (self)
        for _, v in pairs(mission_data.patrol_r:GetGameObjects()) do
            local machine = statemachine.Start("cca_attack_base", nil, { v = v });
            table.insert(mission_data.sub_machines, machine);
        end
        mission_data.patrol_r = nil; -- don't need the patrol engine anymore
        mission_data.attack_waves = {
            { timer = 30, loc = "base_attack1", formation = {"4 4 4", "1 1"} },
            { timer = 15, loc = "base_attack2", formation = {"2 2", "1 1"} }
        };
        mission_data.attack_wave_idx = 1;
        self:next();
    end,
    { "spawn", function (self)
        if self:SecondsHavePassed(mission_data.attack_waves[mission_data.attack_wave_idx].timer) then
            self:SecondsHavePassed();
            self:next();
        end
    end },
    function (self)
        --spawn an attack wave
        local wave = table.remove(mission_data.attack_waves,1);
        for i,v in pairs(waves.SpawnInFormation(wave.formation, wave.loc, nil, {"svfigh","svtank","svrckt","svhraz","svltnk"}, 2, 15)) do
            v:Goto(wave.loc);
        end
        mission_data.attack_wave_idx = mission_data.attack_wave_idx + 1;
        if #mission_data.attack_waves < mission_data.attack_wave_idx then
            -- no more waves, end the machine
            self:next();
            return statemachine.AbortResult();
        end
        self:switch("spawn");
    end
});

statemachine.Create("secondWave",
    statemachine.SleepSeconds(10),
    function (state)
        for i = 1, 4 do
            gameobject.BuildObject("svfigh", 2, "patrol_path"):Goto("wave_2");
        end
        for i = 1, 2 do
            gameobject.BuildObject("svtank", 2, "patrol_path"):Goto("wave_2");
        end
        state:next();
        return statemachine.AbortResult();
    end);

--First objective, go to base, get unit and investigate relic site
statemachine.Create("main_objectives", {
    { "start", function(self)
        mission_data.relic = gameobject.GetGameObject("relic_1")

        --Set up patrol paths
        --local patrol_rid, patrol_r = bzRoutine.routineManager:startRoutine("PatrolRoutine", nil, true);
        mission_data.patrol_r = patrol.new();
        --what are our `checkpoint` locations?
        --mission_data.patrol_r:RegisterLocation({"l_command","l_center","l_north","l_front"});
        --l_command connects to l_center via p_command_center path
        mission_data.patrol_r:AddRoute("l_command", "l_center", "p_command_center")

        --l_center connects to both l_front and l_north via p_center_front and p_center_north
        mission_data.patrol_r:AddRoute("l_center", "l_front", "p_center_front");
        mission_data.patrol_r:AddRoute("l_center", "l_north", "p_center_north");

        --l_front connects to l_command via either p_front_command or p_front_patrol_command
        mission_data.patrol_r:AddRoute("l_front", "l_command", "p_front_command");
        mission_data.patrol_r:AddRoute("l_front", "l_command", "p_front_patrol_command");

        --l_north only connects to l_center via p_north_center, slightly redundant, but there in case more paths are added
        mission_data.patrol_r:AddRoute("l_north", "l_center", "p_north_center");
        --set patrol_id
        --mission_data.patrol_id = patrol_rid;
        --Start first task, go to base
        --self:startTask("rendezvous");
        mission_data.endWait = 7;

        --Let us queue some production jobs for Shaw to do
        --ProducerAi:queueJob(ProductionJob("bvcnst",3));
        producer.QueueJob("bvcnst", 3);
        --ProducerAi:queueJobs(ProductionJob:createMultiple(2,"bvscav",3));
        producer.QueueJob("bvscav", 3);
        producer.QueueJob("bvscav", 3);
        --ProducerAi:queueJob(ProductionJob("bvslfz",3));
        producer.QueueJob("bvslfz", 3, nil, nil, { name = "_doneProducer", location = CONSTANTS.LABELS.GEYSERS[2] });
        --ProducerAi:queueJob(ProductionJob("bvmuf",3));
        producer.QueueJob("bvmuf", 3, nil, nil, { name = "_doneProducer", location = CONSTANTS.LABELS.GEYSERS[3] });
 
        --mission_data.relic_camera_id = ProducerAi:queueJobs(ProductionJob("apcamr",3,"relic_site"));
        producer.QueueJob("apcamr2", 3, "relic_site", TeamSlot.ARMORY, { name = "relic_camera" });

        --Tell AI to build patrol units, 3 tanks and 3 fighters
        --local tankJobs = {ProductionJob:createMultiple(3,"bvtank",3)};
        producer.QueueJob("bvtank", 3, nil, nil, { name = "patrolProd" });
        producer.QueueJob("bvtank", 3, nil, nil, { name = "patrolProd" });
        producer.QueueJob("bvtank", 3, nil, nil, { name = "patrolProd" });

        --local scoutJobs = {ProductionJob:createMultiple(3,"bvraz",3)};
        producer.QueueJob("bvraz", 3, nil, nil, { name = "patrolProd" });
        producer.QueueJob("bvraz", 3, nil, nil, { name = "patrolProd" });
        producer.QueueJob("bvraz", 3, nil, nil, { name = "patrolProd" });
 
        --Tell AI to build some guntowers for defence and a commtower
        -- build in this order:
        -- 1. Power A 
        -- 2. Tower A1
        -- 3. Tower A2
        -- 4. Power B
        -- 5. Tower B1
        -- 6. Tower B2
        -- 7. Power C
        -- 8. comm

        local countPow = paths.GetPathPointCount("make_bblpow");
        local countTow = paths.GetPathPointCount("make_bbtowe");
        local loopCount = math.max(countPow, math.ceil(countTow / 2));
        for i = 1, loopCount do
            if i <= countPow then
                producer.QueueJob("bblpow", 3, {"make_bblpow", i-1}, TeamSlot.CONSTRUCT);
            end
            if i*2 <= countTow then
                producer.QueueJob("bbtowe", 3, {"make_bbtowe", (i-1)*2});
            end
            if i*2+1 <= countTow then
                producer.QueueJob("bbtowe", 3, {"make_bbtowe", (i-1)*2+1});
            end
        end

        --ProducerAi:queueJob(ProductionJob("bbcomm",3,"make_bbcomm"));
        producer.QueueJob("bbcomm", 3, "make_bbcomm");
        --local turretJobs = {};
        --Tell AI to build turrets
        for i,v in paths.IteratePath("make_turrets") do
        --    table.insert(turretJobs,ProductionJob("bvturr",3,v,1));
            producer.QueueJob("bvturr", 3, nil, nil, { name = "_doneTurret", location = v });
        end
        --mission_data.turrProd = ProducerAi:queueJobs2(turretJobs);
        --Set up observer for turrets, when produced _forEachTurret will run
        --self:call("_setUpProdListeners",mission_data.turrProd,"_forEachTurret","_doneTurret");

        self:next();
      end },
    { "rendezvous__start", function(self)
        objective.AddObjective(CONSTANTS.OBJECTIVES.RENDEZVOUS);
        self:next();
    end },
    { "rendezvous__update", function(self)
        local rec = gameobject.GetRecycler(3);
        if rec and gameobject.GetPlayer():IsWithin(rec, 100) then
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.RENDEZVOUS,"GREEN");
            self:next();
        end
    end },
    { "wait_for_units__start", function(self)
        objective.AddObjective(CONSTANTS.OBJECTIVES.WAIT_FOR_UNITS);
        --Make producer create units
        --ProductionJob:createMultiple(count,odf,team)
        --Queue Production Jobs for the player
        mission_data.wait_for_units = 0;
        --local tankJobs = {ProductionJob:createMultiple(3,"bvtank",3)};
        producer.QueueJob("bvtank", 3, nil, nil, { name = "_forEachProduced1" });
        producer.QueueJob("bvtank", 3, nil, nil, { name = "_forEachProduced1" });
        producer.QueueJob("bvtank", 3, nil, nil, { name = "_forEachProduced1" });
        --local rcktJobs = {ProductionJob:createMultiple(2,"bvrckt",3)};
        producer.QueueJob("bvrckt", 3, nil, nil, { name = "_forEachProduced1" });
        producer.QueueJob("bvrckt", 3, nil, nil, { name = "_forEachProduced1" });
        producer.QueueJob("bvrckt", 3, nil, nil, { name = "_forEachProduced1" });
        --local scoutJobs = {ProductionJob:createMultiple(2,"bvraz",3)};
        producer.QueueJob("bvraz", 3, nil, nil, { name = "_forEachProduced1" });
        producer.QueueJob("bvraz", 3, nil, nil, { name = "_forEachProduced1" });
        producer.QueueJob("bvraz", 3, nil, nil, { name = "_forEachProduced1" });
        --mission_data.prodId = ProducerAi:queueJobs2(tankJobs,rcktJobs,scoutJobs);
        --self:call("_setUpProdListeners",mission_data.prodId,"_forEachProduced1","_doneProducing1");

        self:next();
    end },
    { "wait_for_units__update", function (state)
        if mission_data.wait_for_units >= 9 then
            state:next();
        end
    end },
    statemachine.SleepSeconds(7),
    function(self)
        objective.UpdateObjective(CONSTANTS.OBJECTIVES.WAIT_FOR_UNITS,"GREEN");
        self:next();
    end,
    { "success", function(self)
        objective.ClearObjectives();
        --mission.Objective:Start("defendRelic",mission_data.patrol_id);
        --- @todo determine if the team 3 "bvcnst" rebuilder, which isn't even restored yet, should be stopped after this
        self:next();
    end },
    { "goto_relic__start", function(self)
        objective.AddObjective(CONSTANTS.OBJECTIVES.INVESTIGATE_RELIC);
        mission_data.camera_handle:SetTeamNum(1);
        AudioMessage(CONSTANTS.AUDIO.INTRO);
        mission_data.camera_keep_teamed = true;
        self:next();
    end },
    { "goto_relic__update", function(self)
        if(IsInfo(mission_data.relic:GetOdf())) then
            self:next();
        end
    end },
    function(self)
        objective.UpdateObjective(CONSTANTS.OBJECTIVES.INVESTIGATE_RELIC,"GREEN");
        self:next();
    end,
    { "defendRelic", function(self)
        mission_data.failCauses = {};
        mission_data.relic = gameobject.GetGameObject("relic_1");

        --mission_data.patrol_id = patrol_id;
        mission_data.wait_while_shooting = 2;
        mission_data.nuke_wait_t1 = 5;
        mission_data.nuke_wait_t2 = 2;
        mission_data.nuke_state = 0;
        mission_data.t = 0;
        --self:startTask("destroy_relic");

        --First CCA attack
        local units, lead = waves.SpawnInFormation({"   1   ", "1   2 2", "3   3  "}, "relic_light", nil, {"svtank", "svltnk", "svfigh"}, 2, 15);
        mission_data.sub_machines = {};
        for _, v in pairs(units) do
            if lead ~= nil and v ~= lead then
                v:Defend2(lead);
            end
            --local s = mission.TaskManager:sequencer(v);
            --s:queue2("Goto","cca_relic_attack");
            --s:queue2("Defend2", mission_data.relic);
            --s:queue2("Defend");

            local machine = statemachine.Start("cca_relic_attack", nil, { v = v, relic = mission_data.relic });
            table.insert(mission_data.sub_machines, machine);
        end
        mission_data.msg_inspect =  AudioMessage(CONSTANTS.AUDIO.INSPECT);
        self:next();
    end },
    function (self)
        if IsAudioMessageDone(mission_data.msg_inspect) then
            self:next()
        end
    end,
    { "defendRelic.destroy_relic.start", function(self)
        objective.AddObjective(CONSTANTS.OBJECTIVES.DESTROY_RELIC);
        mission_data.relic:SetTeamNum(2);
        self:next();
    end },
    { "defendRelic.destroy_relic.update", function(self)
        if mission_data.relic:GetMaxHealth() - mission_data.relic:GetCurHealth() >= 1000 then
            mission_data.destroy_audio = AudioMessage(CONSTANTS.AUDIO.DESTROY_F);
            local machine = statemachine.Start("defendRelic.cca_attack_base");
            table.insert(mission_data.sub_machines, machine);
            self:next();
        end
    end },
    function(self)
        if not mission_data.destroy_audio or IsAudioMessageDone(mission_data.destroy_audio) then
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.DESTROY_RELIC,"RED");
            --self:startTask("nuke");
            self:next();
        end
    end,
    { "defendRelic.nuke.start", function(self)
        objective.AddObjective(CONSTANTS.OBJECTIVES.DEFEND_RELIC);
        mission_data.day_id = producer.QueueJob("apwrckz",3,mission_data.relic);
        --self:call("_setUpProdListeners",mission_data.day_id,"_setDayWrecker");
        mission_data.detect_daywrecker = true;
        local units, lead = waves.SpawnInFormation({"   1   ", "1 1 2 2", "3 3 3 3"}, "cca_relic_attack", nil, {"svtank", "svrckt", "svfigh"}, 2, 15);
        for i, v in pairs(units) do
            if lead ~= nil and v ~= lead then
                v:Defend2(lead);
            end
            --local s = mission.TaskManager:sequencer(v);
            --s:queue2("Goto","cca_relic_attack");
            --s:queue2("Defend2", mission_data.relic);
            --s:queue2("Defend");

            local machine = statemachine.Start("cca_relic_attack", nil, { v = v, relic = mission_data.relic });
            table.insert(mission_data.sub_machines, machine);
        end
        self:next();
    end },
    { "defendRelic.nuke.update", function(self)
        mission_data.mission_states:on("relic_leave_too_early_fail");
        self:next();
    end },
    { "defendRelic.nuke.update.0", statemachine.SleepSeconds(5) },
    { "defendRelic.nuke.update.0.next", function(self)
        objective.AddObjective(CONSTANTS.OBJECTIVES.UPLINE_CONNECTING);
        self:next();
    end },
    { "defendRelic.nuke.update.1", statemachine.SleepSeconds(2) },
    { "defendRelic.nuke.update.1.next", function(self)
        objective.RemoveObjective(CONSTANTS.OBJECTIVES.UPLINE_CONNECTING);
        objective.AddObjective(CONSTANTS.OBJECTIVES.UPLINK_TRANSMITTING);
        self:next();
    end },
    { "defendRelic.nuke.update.3", function(self)
        if mission_data.daywrecker and Length(mission_data.daywrecker:GetPosition() - mission_data.relic:GetPosition()) < 100 then
            objective.RemoveObjective(CONSTANTS.OBJECTIVES.UPLINE_CONNECTING);
            objective.RemoveObjective(CONSTANTS.OBJECTIVES.UPLINK_TRANSMITTING);
            objective.RemoveObjective(CONSTANTS.OBJECTIVES.DEFEND_RELIC);
            objective.AddObjective(CONSTANTS.OBJECTIVES.UPLINK_RUN_NUKE,"GREEN");
            AudioMessage(CONSTANTS.AUDIO.DONE_D);
            mission_data.mission_states:off("relic_leave_too_early_fail");
            mission_data.mission_states:off("RelicSiteNavReplacer");
            self:next();
        end
    end },
    { function(self)
        if mission_data.daywrecker and not mission_data.daywrecker:IsValid() then
            if mission_data.relic and mission_data.relic:IsValid() then
                -- wrecker does most damage by impact so in theory this could happen in a very strange situation
                mission_data.relic:Damage(mission_data.relic:GetMaxHealth() + 1000);
            end
            self:next();
        end
    end },
    { "rtbAssumeControl", function(self)
        if mission_data.relic and mission_data.relic:IsValid() then
            mission_data.relic:RemoveObject(); -- how the hell are you still here, go away!
        end
        objective.AddObjective(CONSTANTS.OBJECTIVES.RETURN_TO_BASE);
        self:next();
    end },
    { "rtbAssumeControl.update.fix_base", function(self)
        if(gameobject.GetPlayer():GetDistance("bdog_base") < 700) then
            --wait a bit, success
            local hasComm = false;
            gameobject.GetFactory(3):Damage(10000);
            local oldRecy = gameobject.GetRecycler(3);
            if not oldRecy then error("Failed to get recycler") end
            mission_data.recy = copyObject(oldRecy,"bvrecx",false); --- @todo this recycler seems to lack the ability to make a constructor
            oldRecy:RemoveObject();
            for v in gameobject.ObjectsInRange(500,"bdog_base") do
                if(v:GetClassLabel() == "wingman" and v:GetTeamNum() ~= 1) then
                    v:Damage(2500);
                end
                if(v:IsBuilding()) then
                    v:Damage(math.random()*1000 + 100);
                end
            end
            --self:taskSucceed("fix_base");
            self:next();
        end
    end },
    function (self)
        if gameobject.GetPlayer():GetDistance("bdog_base") < 200 then
            self:next();
        end
    end,
    statemachine.SleepSeconds(5),
    { "rtbAssumeControl.success", function(self)
        AudioMessage(CONSTANTS.AUDIO.BACK_TO_BASE);
        SetMaxScrap(1,50);
        SetScrap(1,30);
        for v in gameobject.ObjectsInRange(500,"bdog_base") do
            if(v:GetTeamNum() == 3) then
                v:SetTeamNum(1);
            end
        end
        objective.ClearObjectives();
        --orig15setup();
        local machine = statemachine.Start("secondWave");
        table.insert(mission_data.sub_machines, machine);

        self:next();
    end },
    { "destorySovietComm", function(self)
        mission_data.scomm = gameobject.GetGameObject("sovietcomm");
        objective.AddObjective(CONSTANTS.OBJECTIVES.DESTROY_SOVIET_COMMS);
        mission_data.spawnDef = false;
        mission_data.scc = false;
        mission_data.t1 = 30;
        self:next();
    end },
    { "destorySovietComm.update.spawnDef", function(self)
        -- when you attack the com tower, spawn defenders
        -- if the tower is gone, force advance
        if not mission_data.scomm or not mission_data.scomm:IsAlive() or mission_data.scomm:GetWhoShotMe() ~= nil then
            mission_data.spawnDef = true;
            mission_data.ktargets = {
                gameobject.BuildObject("svfigh", 2, "defense_spawn"),
                gameobject.BuildObject("svfigh", 2, "defense_spawn"),
                gameobject.BuildObject("svtank", 2, "defense_spawn"),
                gameobject.BuildObject("svltnk", 2, "defense_spawn")
            };
            for i,v in pairs(mission_data.ktargets) do
                v:Patrol("defense_path");
            end
            self:next();
        end
    end },
    { "destorySovietComm.update.scc", function(self)
        if not mission_data.scomm or not mission_data.scomm:IsAlive() then
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.DESTROY_SOVIET_COMMS,"GREEN");
            mission_data.scc = true;
            self:next();
        end
    end },
    { "destorySovietComm.update.scc.finish", statemachine.SleepSeconds(30, nil, function(state)
        --- @todo lack of feedback here is kinda strange, you don't know you need to kill the people attacking you
        return checkDead(mission_data.ktargets or {});
    end )},
    { "baseDestroyCin.initstart", function(self)
        -- init
        mission_data.targets = {
            "turr1",
            "turr2",
            "commtower",
            "recycler"
        };

        -- start
        --Spawns attackers in a formation
        mission_data.cam = false;
        mission_data.t1 = 7;
        mission_data.stageTimers = {
            15,
            10,
            5,
            10
        };
        mission_data.minwait = mission_data.t1 + 15 + 10 + 10 + 6 + 10;
        mission_data.waitleft = mission_data.minwait; -- time before the attack camera can be skipped
        mission_data.maxwait = mission_data.minwait + 30; -- time before the attack camera finishes (not counting last section that has its own countdown)
        mission_data.attacker_refocus = 5; -- seconds before refocusing on a new attacker
        mission_data.attackers = waves.SpawnInFormation({
            "1 2 3 2 3 2 1",
            "1 3 1 3 1 3 1",
            "4 4 4 4 4 4 4"
        },"base_attack1",nil,{"svfigh","svrckt","svltnk","svhraz"},2,20);
        for i, v in pairs(mission_data.attackers) do
            v:Goto("base_attack1");
        end
        self:next();
    end },
    { "baseDestroyCin.update", function(self)
        -- redirect all attacks to the base
        for _,v in pairs(mission_data.attackers) do
            if v and v:IsValid() and v:GetCurrentCommand() == AiCommand.NONE then
                v:Goto("bdog_base");
            end
        end
        self:next();
    end },
    statemachine.SleepSeconds(7),
    { "base_destruction_camera_start", function (self)
        --- @cast self MainObjectivesState
        camera.Start();
        --self:SecondsHavePassed(mission_data.minwait); -- start counting internally
        self.EndTimeMinimum = GetTime() + mission_data.minwait;
        self.EndTimeMaximum = GetTime() + mission_data.maxwait;
        self:next();
        self.WatchTarget = mission_data.attackers[3];
        return statemachine.FastResult(); -- trigger next state immediately
    end },

    { "base_destruction_camera_focus_start", function (self)
        --- @cast self MainObjectivesState
        if not self.WatchTarget or not self.WatchTarget:IsAlive() then
            self.WatchTarget = nil
            local rec = gameobject.GetRecycler(1);
            for _, obj in pairs(mission_data.attackers) do
                if obj and obj:IsAlive() then
                    if not self.WatchTarget then
                        self.WatchTarget = obj;
                    elseif rec then
                        if self.WatchTarget:GetDistance(rec) > obj:GetDistance(rec) then
                            self.WatchTarget = obj;
                        end
                    elseif self.WatchTarget:GetHealth() > obj:GetHealth() then
                        self.WatchTarget = obj;
                    end
                end
            end
        end
        if self.WatchTarget then
            self:next();
        else
            self:switch("base_destruction_camera_finish");
        end
        return statemachine.FastResult(); -- trigger next state immediately
    end  },
    { "base_destruction_camera_focus", function (self)
        --- @cast self MainObjectivesState
        if camera.Canceled() and self.EndTimeMinimum < GetTime() then
            self:SecondsHavePassed(); -- reset internal timer
            self:switch("base_destruction_camera_finish");
            return;
        end
        if self:SecondsHavePassed(mission_data.attacker_refocus) then
            self:SecondsHavePassed(); -- reset internal timer
            self:switch("base_destruction_camera_focus_start");
            self.WatchTarget = nil; -- reset watch target since we're doing a target swap by timeout
            return;
        end
        if self.EndTimeMaximum < GetTime() then
            self:SecondsHavePassed(); -- reset internal timer
            self:switch("base_destruction_camera_finish");
            return;
        end
        if camera.FollowObjectAimObject(self.WatchTarget, 0, 10, -30, self.WatchTarget) then
            self:SecondsHavePassed(); -- reset internal timer
            self:next();
            return;
        end
    end  },
    { "base_destruction_camera_focus_linger", statemachine.SleepSeconds(2.5, "base_destruction_camera_focus_start") },
    
    { "base_destruction_camera_finish", function (self)
        --- @cast self MainObjectivesState
        if camera.FollowPathAimPath("25cin_pan1", 50, 2, "bdog_base")
        or (camera.Canceled() and self.EndTimeMinimum < GetTime())
        or self:SecondsHavePassed(5) then
        --or self.EndTimeMaximum < GetTime() then
            self:SecondsHavePassed(); -- reset internal timer
            camera.End();
            self:next();
        end
    end },
    function (self, dtime)
        for v in gameobject.ObjectsInRange(500,"bdog_base") do
            if(gameobject.GetPlayer() ~= v) then
                if(v:GetTeamNum() == 1) then
                    v:Damage(v:GetMaxHealth()/12 * dtime * (math.random()*1.5 + 0.5));
                end
            end
        end
        if self:SecondsHavePassed(mission_data.minwait) then
            self:next();
        end
    end,
    function (self)
        --Make sure all units are destroyed
        for i,v in pairs(mission_data.attackers) do
            v:RemoveObject();
        end
        local vec = paths.GetPosition("nsdf_base");
        if not vec then error("Failed to get nsdf_base") end
        for v in gameobject.ObjectsInRange(500, vec) do
            if(gameobject.GetPlayer() ~= v) then
                v:Damage(100000);
            end
        end

        --miss26setup();
        --Spawns inital objects
        AudioMessage(CONSTANTS.AUDIO.APC_SPAWN);
        objective.RemoveObjective(CONSTANTS.OBJECTIVES.DESTROY_SOVIET_COMMS);
        spawnAtPath("proxminb",2,"spawn_prox");
        spawnAtPath("svfigh",2,"26spawn_figh");
        spawnAtPath("svrckt",2,"26spawn_rock");
        spawnAtPath("svturr",2,"26spawn_turr");
        spawnAtPath("svltnk",2,"26spawn_light");
        local apcs = spawnAtPath("bvapc26",1,"26spawn_apc");
        logger.print(logger.LogLevel.DEBUG, nil, table.show(apcs,"apcs"));
        for i, v in pairs(apcs) do
            v:SetLabel(("apc%d"):format(i));
            v:SetObjectiveName(("Transport %d"):format(i));
            v:SetObjectiveOn();
            v:Goto("26apc_meatup",1);
        end
        for i, v in pairs(spawnAtPath("bvtank",1,"26spawn_tank")) do
            v:Goto("26apc_meatup",1);
        end
        spawnAtPath("bvhraz",1,"26spawn_bomber")[1]:Goto("26bomber_rev",1);
        --apcMeetup:start();
        self:next();
    end,
    { "apcMeetup", function(self)
        -- init
        mission_data.apcs = {gameobject.GetGameObject("apc1"),gameobject.GetGameObject("apc2")};
        -- start
        objective.AddObjective(CONSTANTS.OBJECTIVES.MEET_APCS,"WHITE");
        --- @todo why does the mission talk about NSDF after this?
        self:next();
    end },
    { "apcMeetup.update", function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail();
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.MEET_APCS,"RED");
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_APC_LOST);
            self:switch(nil);
            return;
        end
        if(gameobject.GetPlayer():GetDistance(mission_data.apcs[1]) < 50) then
            --self:success();
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.MEET_APCS,"GREEN");
            --mission.Objective:Start("pickupSurvivors");
            self:next();
            return;
        end
    end },
    { "pickupSurvivors", function(self)
        -- init
        mission_data.apcs = {gameobject.GetGameObject("apc1"),gameobject.GetGameObject("apc2")};
        mission_data.nav = gameobject.GetGameObject("nav1");
        -- start
        objective.AddObjective(CONSTANTS.OBJECTIVES.ESCORD_APC_OUTPOST, "WHITE");
        mission_data.t1 = 30;
        mission_data.arived = false;
        local navs = spawnAtPath("apcamr",1,"26spawn_nav");
        for i, v in pairs(navs) do
            v:SetLabel(("nav%d"):format(i));
            v:SetMaxHealth(0);
            v:SetPosition(v:GetPosition() + SetVector(0,100,0));
        end
        navs[1]:SetObjectiveName("NSDF Outpost");
        navs[2]:SetObjectiveName("Rendezvous Point");
        for i, v in pairs(mission_data.apcs) do
            v:Goto("apc_follow_path");
        end
        mission_data.nav = navs[1];
 
        --mission_data.mission_states:on("pickupSurvivors.apc_watch");
        self:next();

    end },
    { "pickupSurvivors.update", function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail(1);
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_APC_LOST);
            self:switch(nil);
            return;
        end
        if(mission_data.apcs[1]:IsWithin(mission_data.nav,200) or
        mission_data.apcs[2]:IsWithin(mission_data.nav,200) or
            gameobject.GetPlayer():IsWithin(mission_data.nav,200)) then
            mission_data.pilots = spawnAtPath("aspilo",1,"spawn_pilots")
            for i,v in pairs(mission_data.pilots) do
                v:SetIndependence(0);
            end
            self:next();
        end
    end },
    { "pickupSurvivors.update.pilots", function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail(1);
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_APC_LOST);
            self:switch(nil);
            return;
        end
        if(checkAnyDead(mission_data.pilots)) then
            --self:fail(2);
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_KILLED_RESCUED_MEN);
            self:switch(nil);
            return;
        end
        if(mission_data.apcs[1]:IsWithin(mission_data.nav,50) or mission_data.apcs[2]:IsWithin(mission_data.nav,50)) then
            for i,v in ipairs(mission_data.pilots) do
                local t = mission_data.apcs[math.floor( (i-1)/3 ) + 1];
                if not t then error("Failed to get apc") end
                v:Goto(t);
            end
            mission_data.arived = true;
            self:next();
        end
    end },
    { "pickupSurvivors.update.pilots2", function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail(1);
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_APC_LOST);
            self:switch(nil);
            return;
        end
        if(checkAnyDead(mission_data.pilots)) then
            --self:fail(2);
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_KILLED_RESCUED_MEN);
            self:switch(nil);
            return;
        end
        for i,v in pairs(mission_data.apcs) do
            if(v:IsWithin(mission_data.nav,40) ) then
                local pos = v:GetPosition();
                if not pos then error("Failed to get position") end
                v:Dropoff(pos);
            end
        end
        --mission_data.t1 = mission_data.t1 - dtime;
        local pleft = 0;
        for i,v in pairs(mission_data.pilots) do
 
            local who = v:GetCurrentWho();
            if not who then error("Failed to get current who") end
            if v:IsWithin(who,10) or v:GetCurrentCommand() == AiCommand.NONE then
                v:RemoveObject();
                mission_data.pilots[i] = nil;
            else
                pleft = pleft + 1;
            end
 
        end
        if((pleft <= 0)) then---or (mission_data.t1 <= 0)) then
            --self:success();
            AudioMessage(CONSTANTS.AUDIO.PICKUP_DONE);
            for i,v in pairs(mission_data.apcs) do
                v:Stop(0);
            end
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.ESCORD_APC_OUTPOST,"GREEN");
            --mission.Objective:Start("escortAPCs");
            self:next();
        end
    end },
    { "escortAPCs", function(self)
        -- init
        mission_data.nav = gameobject.GetGameObject("nav2");
        mission_data.apcs = {gameobject.GetGameObject("apc1"),gameobject.GetGameObject("apc2")};
        -- start
        objective.ClearObjectives();
        objective.AddObjective(CONSTANTS.OBJECTIVES.SEND_APC_TO_EVAC,"WHITE");
        objective.AddObjective(CONSTANTS.OBJECTIVES.ESCORT_APC_TO_EVAC,"WHITE");

        self:next();
    end },
    function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail();
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.ESCORT_APC_TO_EVAC,"RED");
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_APC_LOST);
            self:switch(nil);
        end
        if(mission_data.apcs[1]:IsWithin(mission_data.nav,100) and mission_data.apcs[2]:IsWithin(mission_data.nav,100)) then
            --self:success();
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.SEND_APC_TO_EVAC,"GREEN");
            objective.UpdateObjective(CONSTANTS.OBJECTIVES.ESCORT_APC_TO_EVAC,"GREEN");
            AudioMessage(CONSTANTS.AUDIO.WIN);
            SucceedMission(GetTime()+5.0, CONSTANTS.DEBRIEFING.WIN);
            self:switch(nil);
        end
    end
});

--- @todo add this to the script
--delete_object = function(self,handle)
--    local c = GetConstructorHandle(3);
--    if(c ~= nil and not IsAlive(c)) then
--        ProducerAi:queueJob(ProductionJob("bvcnst",3));
--    end
--end

stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
    --:Add("pickupSurvivors.apc_watch", function(state, name)
    --    if(checkAnyDead(mission_data.apcs)) then
    --        FailMission(GetTime()+5.0,constants.debriefing.ApcLost2);
    --        state:off(name, true);
    --    end
    --end)
    :Add("RelicSiteNavReplacer", function(state)
        if not mission_data.camera_handle or mission_data.camera_handle:IsValid() then
            return;
        end
        producer.QueueJob("apcamr2", 3, "relic_site", TeamSlot.ARMORY, { name = "relic_camera" });
        state:off("RelicSiteNavReplacer");
    end)
    :Add("relic_leave_too_early_fail", function(state, name)
        if gameobject.GetPlayer():IsAlive() and gameobject.GetPlayer():GetDistance("relic_site") > 200 then
            objective.RemoveObjective(CONSTANTS.OBJECTIVES.UPLINE_CONNECTING);
            objective.RemoveObjective(CONSTANTS.OBJECTIVES.UPLINK_TRANSMITTING);
            objective.AddObjective(CONSTANTS.OBJECTIVES.UPLINK_RETRY,"RED");
            FailMission(GetTime()+5.0,CONSTANTS.DEBRIEFING.LOSS_RELIC_ABANDONED);
            state:off("main_objectives", true); -- turn off main machine, we lost
            state:off(name, true); -- turn off this machine too
        end
    end)
    :Add("nuke_watch", function(state, name)

    end)
    ;

hook.Add("Producer:BuildComplete", "Mission:ProducerBuildComplete", function (object, producer, data)
    --- @cast object GameObject
    --- @cast producer GameObject
    --- @cast data any

    --logger.print(logger.LogLevel.DEBUG, nil, "Producer:BuildComplete", object:GetOdf(), producer:GetOdf(), data and table.show(data));

    if data and data.name then
        if data.name == "relic_camera" then
            object:SetObjectiveName("Relic Site");
            mission_data.camera_handle = object;
            if mission_data.camera_keep_teamed then
                object:SetTeamNum(1);
            end
            mission_data.mission_states:on("RelicSiteNavReplacer");
        end
        if data.name == "patrolProd" then
            --self:call("_forEachPatrolUnit",...);
            --For each unit produced in order to patrol the base, add them to the patrol routine
            --local mission_data.patrol_r = bzRoutine.routineManager:getRoutine(mission_data.patrol_id);
            mission_data.patrol_r:AddGameObject(object);
        end
        if data.name == "_doneTurret" then
            object:Goto(data.location);
        end
        if data.name == "_forEachProduced1" then
            object:SetTeamNum(1);
            mission_data.wait_for_units = mission_data.wait_for_units + 1;
        end
        if data.name == "_doneProducer" then
            local geyser = gameobject.GetGameObject(data.location);
            if geyser then
            object:Goto(geyser);
            end
        end
    end
end);

hook.Add("Start", "Mission:Start", function ()
    --core:onStart();
    SetPilot(1, 5);
    SetScrap(1, 8);
    Ally(1,3 );
    gameobject.GetGameObject("abbarr2_barracks"):SetMaxHealth(0);
    gameobject.GetGameObject("abbarr3_barracks"):SetMaxHealth(0);
    gameobject.GetGameObject("abcafe3_i76building"):SetMaxHealth(0);
    SetMaxScrap(3, 5000);
    SetScrap(3, 2000);
    SetMaxPilot(3, 5000);
    SetPilot(3, 1000);
    local h = gameobject.GetGameObject("relic_1");
    if not h then error("relic_1 not found") end
    h:SetMaxHealth(900000);
    h:SetCurHealth(900000);
    for i = 1, 13 do
        gameobject.GetGameObject("patrol_" .. i):Patrol("patrol_path");
    end

    mission_data.mission_states = stateset.Start("mission")
        :on("main_objectives");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
    if mission_data.sub_machines then
        -- call update on all items and remove them if they return false
        for i = #mission_data.sub_machines, 1, -1 do
            local v = mission_data.sub_machines[i];
            if v then
                local success = v:run(dtime);
                --- @cast success StateMachineIterWrappedResult
                if not success or (statemachine.IsStateMachineIterWrappedResult(success) and success.Abort) then
                    table.remove(mission_data.sub_machines,i); -- clean up dead machines from the list
                end
            end
        end
    end

    mission_data.mission_states:run(dtime);
end);

hook.Add("CreateObject", "Mission:CreateObject", function (object)
    --- @cast object GameObject
    if mission_data.detect_daywrecker and not mission_data.daywrecker and object:GetOdf() == "apwrckz" then
        object:SetMaxHealth(0);
        object:SetObjectiveOn();
        mission_data.daywrecker = object
        mission_data.detect_daywrecker = nil;
    end
end);

--function AddObject(handle)
--  core:onAddObject(handle);
--  mission:AddObject(handle);
--end

--function DeleteObject(handle)
--  core:onDeleteObject(handle);
--  mission:DeleteObject(handle);
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

--- @class CCA_Relic_Attack_state : StateMachineIter
--- @field v GameObject
--- @field relic GameObject

--- @class MainObjectivesState : StateMachineIter
--- @field EndTimeMinimum number
--- @field EndTimeMaximum number
--- @field WatchTarget GameObject?