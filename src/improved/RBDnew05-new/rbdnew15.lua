--Combination of The Last Stand and Evacuate Venus

-- relic doesn't go enemy right away when voiceover starts, meaning it takes a while before you shoot at it
-- consider making all friendly units that are attacking the mammoth, STOP ATTACKING THE MAMMOTH, once it is shown to be impossible to damage
-- Constructor is not given to player when they go to base, why?
-- recycler cannot make constructor or factory, why?
-- why does the armory have a DW that cost 200, why not remove it?
-- In playtest camera somehow targeted non-existing object, despite code that says to point at each alive in sequence.
-- in a playtest, a light tank failed to attack an Lpower becaused it was being swarmed by its own allies following it, add timer to auto destroy everything is an emergency backup
-- Camera sequence only advances when the targets of the sequence die, when the player removes all combat units from the base due to knowing it's going to be destroyed, the attacker doesn't die, and thus the mission softlocks in a camera sequence.

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
--local tracker = require("_tracker");
local navmanager = require("_navmanager");
local objective = require("_objective");
local utility = require("_utility");
local color = require("_color");
local producer = require("_producer");
local patrol = require("_patrol");
local camera = require("_camera");

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











--local minit = require("minit")

local mission_data = {};
mission_data.pwers = {};

--local orig15setup = require("orig15p");
--local core = require("bz_core");
--local OOP = require("oop");
--local buildAi = require("buildAi");
--local bzRoutine = require("bz_routine");
--local bzObjects = require("bz_objects");

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


local IsIn = function(a,inB) 
    for i,v in pairs(inB) do
        if(a == v) then
            return true;
        end
    end
    return false;
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
    local current = GetPosition(path);
    local prev = nil;
    local c = 0;
    while current and current ~= prev do
        c = c + 1;
        table.insert(handles,gameobject.BuildObject(odf,team,current));
        prev = current;
        current = GetPosition(path,c);
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







--- @param formation string[]
--- @param location Vector
--- @param dir Vector
--- @param units string[]
--- @param team TeamNum
--- @param seperation integer
local function spawnInFormation(formation,location,dir,units,team,seperation)
    if(seperation == nil) then
        seperation = 10;
    end
    local tempH = {};
    local lead;
    local directionVec = Normalize(SetVector(dir.x,0,dir.z));
    local formationAlign = Normalize(SetVector(-dir.z,0,dir.x));
    for i2, v2 in ipairs(formation) do
        local length = v2:len();
        local i3 = 1;
        for c in v2:gmatch(".") do
        local n = tonumber(c);
        if(n) then
            local x = (i3-(length/2))*seperation;
            local z = i2*seperation*2;
            local pos = x*formationAlign + -z*directionVec + location;
            local h = gameobject.BuildObject(units[n],team,pos);
            if not h then error("Failed to build object " .. units[n] .. " at " .. tostring(pos)) end
            local t = BuildDirectionalMatrix(h:GetPosition(),directionVec);
            h:SetTransform(t);
            if(not lead) then
                lead = h;
            end
            table.insert(tempH,h);
        end
        i3 = i3+1;
        end
    end
    return tempH, lead;
end

--- @param formation string[]
--- @param location string
--- @param units string[]
--- @param team TeamNum
--- @param seperation integer
local function spawnInFormation2(formation,location,units,team,seperation)
    local pos = GetPosition(location,0);
    if not pos then error("Failed to get position of " .. location) end
    local pos2 = GetPosition(location,1);
    if not pos2 then error("Failed to get position of " .. location) end
    local dir = pos2 - pos;
    return spawnInFormation(formation,pos,dir,units,team,seperation);
end

--local ProducerAi = buildAi.ProducerAi;
--local ProductionJob = buildAi.ProductionJob;
--local PatrolController = require("patrolc");
--local mission = require('cmisnlib');

SetAIControl(2,false);
SetAIControl(3,false);


local audio = {
    intro = "rbd0501.wav",
    inspect = "rbd0502.wav",
    destroy_f = "rbd0503.wav",
    done_d = "rbd0504.wav",
    back_to_base = "rbd0505.wav",

    apc_spawn = "rbd0506.wav",
    pickup_done = "rbd0507.wav",
    win = "rbd0508.wav"
}

local objective_files = {
    Rendezvous = "rbd0521.otf",
    WaitForUnits = "rbd0522.otf",
    InvestigateRelic = "rbd0523.otf",
    DestroyRelic = "rbd0524.otf",
    DefendRelic = "rbd0525.otf",
    UplinkConnecting = "rbd0530.otf",
    UplinkTransmitting = "rbd0531.otf",
    ReturnToBase = "rbd0532.otf",
    UplinkRetry = "rbd0533.otf",
    UplinkRunNuke = "rbd0534.otf",
    EscordAPCsToBase = "bdmisn2601.otf",
    SendAPCsToEvac = "bdmisn2602.otf",
    EscortAPCsToEvac = "bdmisn2603.otf",
    bdmisn2504 = "bdmisn2504.otf",
    rbdnew3502 = "rbdnew3502.otf",
};

local end_mission_text = {
    CommandTowerDestroyed = "rbdnew15l1.des",
    RelicDestroyedEarly = "rbdnew15l2.des",
    KilledRescueMen = "rbdnew15l3.des",
    ApcLost = "rbdnew15l4.des",
    Success5 = "rbdnew15w.des",
    Missing1 = nil,
    Missing2 = nil,
    ApcLost2 = "bdmisn26l1.des", -- possible dupe?
    SurvivingForcesKilled = "bdmisn26l2.des",
    EvacSuccess6 = "bdmisn26wn.des",
};

--- @class CCA_Relic_Attack_state : StateMachineIter
--- @field v GameObject
--- @field relic GameObject
statemachine.Create("cca_relic_attack",
    function (state)
        --- @cast state CCA_Relic_Attack_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
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
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
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
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
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
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
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
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state CCA_Relic_Attack_state
        state.v:Defend();
        state:next();
        return statemachine.AbortResult();
    end);


statemachine.Create("defendRelic.cca_attack_base", {
    function (self)
        --local patrol = bzRoutine.routineManager:getRoutine(mission_data.patrol_id);
        for i,v in pairs(mission_data.patrol_r:getGameObjects()) do
            --local s = mission.TaskManager:sequencer(v);
            --s:queue2("Goto","front_line");
            --s:queue2("Defend");
            
            local machine = statemachine.Start("cca_attack_base", nil, { v = v });
            table.insert(mission_data.sub_machines, machine);
        end
        --bzRoutine.routineManager:killRoutine(mission_data.patrol_id);
        mission_data.patrol_r = nil; -- once we add reference tracking there will be no more references
        mission_data.attack_timers = {30,15};
        mission_data.attack_waves = {
            {loc = "base_attack1",formation={"4 4 4","1 1"}},
            {loc = "base_attack2",formation={"2 2","1 1"}}
        };
        mission_data.attack_timer = nil;
        self:next();
    end,
    function (self, dtime)
        if(mission_data.attack_timer == nil) then
            if(#mission_data.attack_timers <= 0) then
                --self:taskSucceed("cca_attack_base");
                self:switch(nil);
            else
                mission_data.attack_timer = table.remove(mission_data.attack_timers,1);
            end
        end
        if(mission_data.attack_timer ~= nil) then
            mission_data.attack_timer = mission_data.attack_timer - dtime;
            if(mission_data.attack_timer <= 0) then
                --spawn an attack wave
                local wave = table.remove(mission_data.attack_waves,1);
                for i,v in pairs(spawnInFormation2(wave.formation,wave.loc,{"svfigh","svtank","svrckt","svhraz","svltnk"},2,15)) do
                    v:Goto(wave.loc);
                end
                mission_data.attack_timer = nil;
            end
        end
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
        mission_data.patrol_r:registerLocations({"l_command","l_center","l_north","l_front"});
        --l_command connects to l_center via p_command_center path
        mission_data.patrol_r:defineRoutes("l_command",{
            p_command_center = "l_center"
        });
        --l_center connects to both l_front and l_north via p_center_front and p_center_north
        mission_data.patrol_r:defineRoutes("l_center",{
            p_center_front = "l_front",
            p_center_north = "l_north"
        });
        --l_front connects to l_command via either p_front_command or p_front_patrol_command
        mission_data.patrol_r:defineRoutes("l_front",{
            p_front_command = "l_command",
            p_front_patrol_command = "l_command"
        });
        --l_north only connects to l_center via p_north_center, slightly redundant, but there in case more paths are added
        mission_data.patrol_r:defineRoutes("l_north",{
            p_north_center = "l_center"
        });
        --set patrol_id
        --mission_data.patrol_id = patrol_rid;
        --Start first task, go to base
        --self:startTask("rendezvous");
        mission_data.endWait = 7;

        --Let us queue some production jobs for Shaw to do
        --ProducerAi:queueJob(ProductionJob("bvcnst",3));
        producer.QueueJob("bvcnst", 3);
        --ProducerAi:queueJobs(ProductionJob:createMultiple(2,"bvscav",3));
        producer.QueueJob("bvscav",  3);
        producer.QueueJob("bvscav",  3);
        --ProducerAi:queueJob(ProductionJob("bvslfz",3));
        producer.QueueJob("bvslfz", 3);
        --ProducerAi:queueJob(ProductionJob("bvmuf",3));
        producer.QueueJob("bvmuf", 3);
        
        --mission_data.relic_camera_id = ProducerAi:queueJobs(ProductionJob("apcamr",3,"relic_site"));
        producer.QueueJob("apcamr", 3, "relic_site", nil, { name = "relic_camera" });

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
        --- @todo reorder these so they make more sense
        for i,v in utility.IteratePath("make_bblpow") do
        --    ProducerAi:queueJob(ProductionJob("bblpow",3,v),0);
            producer.QueueJob("bblpow", 3, v);
        end
        for i,v in utility.IteratePath("make_bbtowe") do
        --    ProducerAi:queueJob(ProductionJob("bbtowe",3,v),1);
            producer.QueueJob("bbtowe", 3, v);
        end
        --ProducerAi:queueJob(ProductionJob("bbcomm",3,"make_bbcomm"));
        producer.QueueJob("bbcomm", 3, "make_bbcomm");
        --local turretJobs = {};
        --Tell AI to build turrets
        for i,v in utility.IteratePath("make_turrets") do
        --    table.insert(turretJobs,ProductionJob("bvturr",3,v,1));
            producer.QueueJob("bvturr", 3, nil, nil, { name = "_doneTurret", location = v });
        end
        --mission_data.turrProd = ProducerAi:queueJobs2(turretJobs);
        --Set up observer for turrets, when produced _forEachTurret will run
        --self:call("_setUpProdListeners",mission_data.turrProd,"_forEachTurret","_doneTurret");

        self:next();
      end },
    { "rendezvous__start", function(self)
        objective.AddObjective(objective_files.Rendezvous);
        self:next();
    end },
    { "rendezvous__update", function(self)
        local rec = gameobject.GetRecycler(3);
        if rec and gameobject.GetPlayer():IsWithin(rec, 100) then
            objective.UpdateObjective(objective_files.Rendezvous,"GREEN");
            self:next();
        end
    end },
    { "wait_for_units__start", function(self)
        objective.AddObjective(objective_files.WaitForUnits);
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
        objective.UpdateObjective(objective_files.WaitForUnits,"GREEN");
        self:next();
    end,
    { "success", function(self)
        objective.ClearObjectives();
        --mission.Objective:Start("defendRelic",mission_data.patrol_id);
        --- @todo determine if the team 3 "bvcnst" rebuilder, which isn't even restored yet, should be stopped after this
        self:next();
    end },
    { "goto_relic__start", function(self)
        objective.AddObjective(objective_files.InvestigateRelic);
        mission_data.camera_handle:SetTeamNum(1);
        AudioMessage(audio.intro);
        mission_data.camera_keep_teamed = true;
        self:next();
    end },
    { "goto_relic__update", function(self)
        if(IsInfo(mission_data.relic:GetOdf())) then
            self:next();
        end
    end },
    function(self)
        objective.UpdateObjective(objective_files.InvestigateRelic,"GREEN");
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
        local units, lead = spawnInFormation2({"   1   ","1   2 2", "3   3  "},"relic_light",{"svtank","svltnk","svfigh"},2,15);
        mission_data.sub_machines = {};
        for i, v in pairs(units) do
            if(v ~= lead) then
                v:Defend2(lead);
            end
            --local s = mission.TaskManager:sequencer(v);
            --s:queue2("Goto","cca_relic_attack");
            --s:queue2("Defend2", mission_data.relic);
            --s:queue2("Defend");

            local machine = statemachine.Start("cca_relic_attack", nil, { v = v, relic = mission_data.relic });
            table.insert(mission_data.sub_machines, machine);
        end


        mission_data.msg_inspect =  AudioMessage(audio.inspect);

        self:next();
    end },
    function (self)
        if IsAudioMessageDone(mission_data.msg_inspect) then
            self:next()
        end
    end,
    { "defendRelic.destroy_relic.start", function(self)
        objective.AddObjective(objective_files.DestroyRelic);
        mission_data.relic:SetTeamNum(2);
        self:next();
    end },
    { "defendRelic.destroy_relic.update", function(self)
        if mission_data.relic:GetMaxHealth() - mission_data.relic:GetCurHealth() >= 1000 then
            mission_data.destroy_audio = AudioMessage(audio.destroy_f);
            -- @todo start a side-machine for "defendRelic.cca_attack_base"
            local machine = statemachine.Start("defendRelic.cca_attack_base");
            table.insert(mission_data.sub_machines, machine);
            self:next();
        end
    end },
    function(self)
        if not mission_data.destroy_audio or IsAudioMessageDone(mission_data.destroy_audio) then
            objective.UpdateObjective(objective_files.DestroyRelic,"RED");
            --self:startTask("nuke");
            self:next();
        end
    end,
    { "defendRelic.nuke.start", function(self)
        objective.AddObjective(objective_files.DefendRelic);
        mission_data.day_id = producer.QueueJob("apwrckz",3,mission_data.relic);
        --self:call("_setUpProdListeners",mission_data.day_id,"_setDayWrecker");
        mission_data.detect_daywrecker = true;
        local units, lead = spawnInFormation2({"   1   ","1 1 2 2", "3 3 3 3"},"cca_relic_attack",{"svtank","svrckt","svfigh"},2,15);
        for i, v in pairs(units) do
            if(v ~= lead) then
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
        objective.AddObjective(objective_files.UplinkConnecting);
        self:next();
    end },
    { "defendRelic.nuke.update.1", statemachine.SleepSeconds(2) },
    { "defendRelic.nuke.update.1.next", function(self)
        objective.RemoveObjective(objective_files.UplinkConnecting);
        objective.AddObjective(objective_files.UplinkTransmitting);
        self:next();
    end },
    { "defendRelic.nuke.update.3", function(self)
        if mission_data.daywrecker and Length(mission_data.daywrecker:GetPosition() - mission_data.relic:GetPosition()) < 100 then
            objective.RemoveObjective(objective_files.UplinkConnecting);
            objective.RemoveObjective(objective_files.UplinkTransmitting);
            objective.AddObjective(objective_files.UplinkRunNuke,"GREEN");
            AudioMessage(audio.done_d);
            mission_data.mission_states:off("relic_leave_too_early_fail");
            self:next();
        end
    end },
    { function(self)
        --- @todo this might need an extra delay giving time for the relic to be destroyed by the daywrecker's explosion
        if mission_data.daywrecker and not mission_data.daywrecker:IsValid() then
            -- wait till the daywrecker is dead but the var is valid (probably don't need the valid var check)
            if not mission_data.relic:IsValid() then
                -- if relic is dead, we are done
                --self:taskSucceed("nuke");
                objective.ClearObjectives();
                --mission.Objective:Start("rtbAssumeControl");
                self:next();
            else
                -- relic is still alive, we failed (but how, isn't this automatic?)
                --self:taskFail("nuke");
                objective.UpdateObjective(objective_files.DefendRelic,"RED");
                FailMission(GetTime()+5.0,end_mission_text.Missing2);
                self:switch(nil);
            end
        end
    end },
    { "rtbAssumeControl", function(self)
        objective.AddObjective(objective_files.ReturnToBase);
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
        AudioMessage(audio.back_to_base);
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
        objective.AddObjective(objective_files.rbdnew3502);
        mission_data.spawnDef = false;
        mission_data.scc = false;
        mission_data.t1 = 30;
        self:next();
    end },
    { "destorySovietComm.update.spawnDef", function(self)
        -- when you attack the com tower, spawn defenders
        if GetWhoShotMe(mission_data.scomm:GetHandle()) ~= nil then
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
        if not mission_data.scomm:IsAlive() then
            objective.UpdateObjective(objective_files.rbdnew3502,"GREEN");
            mission_data.scc = true;
            self:next();
        end
    end },
    { "destorySovietComm.update.scc.finish", statemachine.SleepSeconds(30, nil, function(state)
        --- @todo lack of feedback here is kinda strange
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
        mission_data.camstage = 0;
        mission_data.t1 = 7;
        mission_data.stageTimers = {
            15,
            10,
            5,
            10
        };
        mission_data.minwait = mission_data.t1 + 15 + 10 + 10 + 6 + 10;
        mission_data.waitleft = mission_data.minwait;
        mission_data.attackers = spawnInFormation2({
            "1 2 3 2 3 2 1",
            "1 3 1 3 1 3 1",
            "4 4 4 4 4 4 4"
        },"base_attack1",{"svfigh","svrckt","svltnk","svhraz"},2,20);
        for i, v in pairs(mission_data.attackers) do
            v:Goto("base_attack1");
        end
        self:next();
    end },
    { "baseDestroyCin.update", function(self)
        for i,v in pairs(mission_data.attackers) do
            local task = v:GetCurrentCommand() ~= AiCommand["NONE"];
            --[[if(not task) then
                for i2,v2 in pairs(mission_data.targets) do
                    if( i<=(i2*3) and (not task) ) then
                        local t = gameobject.GetGameObject(v2);
                        if(IsAlive(t)) then
                            Attack(v,t);
                            task = true;
                        end
                    end
                end
            end--]]
            if(not task) then
                v:Goto("bdog_base");
            end
        end
        self:next();
    end },
    statemachine.SleepSeconds(7),
    { "base_destruction_camera_start", function (self)
        camera.CameraReady();
        mission_data.camstage = 1;
        self:SecondsHavePassed(mission_data.minwait); -- start counting internally
        self:next();
        return statemachine.FastResult(); -- trigger next state immediately
    end },
    function (self)
        if mission_data.attackers[3]:IsAlive() then
            camera.CameraObject(mission_data.attackers[3],0,1000,-3000,mission_data.attackers[3]);
        else
            mission_data.camstage = mission_data.camstage + 1;
            self:next();
        end
    end,
    function (self)
        if mission_data.attackers[8]:IsAlive() then
            camera.CameraObject(mission_data.attackers[8],0,1000,-3000,mission_data.attackers[8]);
        else
            mission_data.camstage = mission_data.camstage + 1;
            self:next();
        end
    end,
    function (self)
        if mission_data.attackers[12]:IsAlive() then
            camera.CameraObject(mission_data.attackers[12],0,1000,-3000,mission_data.attackers[12]);
        else
            mission_data.camstage = mission_data.camstage + 1;
            self:next();
        end
    end,
    function (self)
        if mission_data.attackers[9]:IsAlive() then
            camera.CameraPath("25cin_pan1",5000,200,mission_data.attackers[9]);
        else
            mission_data.camstage = mission_data.camstage + 1;
            camera.CameraFinish();
            self:next();
        end
    end,
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
        local vec = GetPosition("nsdf_base");
        if not vec then error("Failed to get nsdf_base") end
        for v in gameobject.ObjectsInRange(500, vec) do
            if(gameobject.GetPlayer() ~= v) then 
                v:Damage(100000);
            end
        end

        --miss26setup();
        --Spawns inital objects
        AudioMessage(audio.apc_spawn);
        objective.RemoveObjective(objective_files.rbdnew3502);
        spawnAtPath("proxminb",2,"spawn_prox");
        spawnAtPath("svfigh",2,"26spawn_figh");
        spawnAtPath("svrckt",2,"26spawn_rock");
        spawnAtPath("svturr",2,"26spawn_turr");
        spawnAtPath("svltnk",2,"26spawn_light");
        local apcs = spawnAtPath("bvapc26",1,"26spawn_apc");
        debugprint(table.show(apcs,"apcs"));
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
        objective.AddObjective(objective_files.bdmisn2504,"WHITE");
        --- @todo why does the mission talk about NSDF after this?
        self:next();
    end },
    { "apcMeetup.update", function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail();
            objective.UpdateObjective(objective_files.bdmisn2504,"RED");
            FailMission(GetTime()+5.0,end_mission_text.ApcLost2);
            self:switch(nil);
            return;
        end
        if(gameobject.GetPlayer():GetDistance(mission_data.apcs[1]) < 50) then
            --self:success();
            objective.UpdateObjective(objective_files.bdmisn2504,"GREEN");
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
        objective.AddObjective("rbdnew3503.otf", "WHITE");
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
            FailMission(GetTime()+5.0,end_mission_text.ApcLost2);
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
            FailMission(GetTime()+5.0,end_mission_text.ApcLost2);
            self:switch(nil);
            return;
        end
        if(checkAnyDead(mission_data.pilots)) then
            --self:fail(2);
            FailMission(GetTime()+5.0,end_mission_text.SurvivingForcesKilled);
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
            FailMission(GetTime()+5.0,end_mission_text.ApcLost2);
            self:switch(nil);
            return;
        end
        if(checkAnyDead(mission_data.pilots)) then
            --self:fail(2);
            FailMission(GetTime()+5.0,end_mission_text.SurvivingForcesKilled);
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
            if v:IsWithin(who,10) or v:GetCurrentCommand() == AiCommand["NONE"] then
                v:RemoveObject();
                mission_data.pilots[i] = nil;
            else
                pleft = pleft + 1;
            end
            
        end
        if((pleft <= 0)) then---or (mission_data.t1 <= 0)) then
            --self:success();
            AudioMessage(audio.pickup_done);
            for i,v in pairs(mission_data.apcs) do
                v:Stop(0);
            end  
            objective.UpdateObjective("rbdnew3503.otf","GREEN");
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
        objective.AddObjective(objective_files.SendAPCsToEvac,"WHITE");
        objective.AddObjective(objective_files.EscortAPCsToEvac,"WHITE");

        self:next();
    end },
    function(self)
        if(checkAnyDead(mission_data.apcs)) then
            --self:fail();
            objective.UpdateObjective(objective_files.EscortAPCsToEvac,"RED");
            FailMission(GetTime()+5.0,end_mission_text.ApcLost2);
            self:switch(nil);
        end
        if(mission_data.apcs[1]:IsWithin(mission_data.nav,100) and mission_data.apcs[2]:IsWithin(mission_data.nav,100)) then
            --self:success();
            objective.UpdateObjective(objective_files.SendAPCsToEvac,"GREEN");
            objective.UpdateObjective(objective_files.EscortAPCsToEvac,"GREEN");
            AudioMessage(audio.win);
            SucceedMission(GetTime()+5.0, end_mission_text.EvacSuccess6);
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
    --        FailMission(GetTime()+5.0,"bdmisn26l1.des");
    --        state:off(name, true);
    --    end
    --end)
    :Add("relic_leave_too_early_fail", function(state, name)
        if gameobject.GetPlayer():IsAlive() and gameobject.GetPlayer():GetDistance("relic_site") > 200 then
            objective.RemoveObjective(objective_files.UplinkConnecting);
            objective.RemoveObjective(objective_files.UplinkTransmitting);
            objective.AddObjective(objective_files.UplinkRetry,"RED");
            FailMission(GetTime()+5.0,end_mission_text.Missing1);
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

    debugprint("Producer:BuildComplete", object:GetOdf(), producer:GetOdf(), data and table.show(data));

    if data and data.name then
        if data.name == "relic_camera" then
            -- @todo auto queue remaking this?
            object:SetObjectiveName("Relic Site");
            mission_data.camera_handle = object;
            if mission_data.camera_keep_teamed then
                object:SetTeamNum(1);
            end
        end
        if data.name == "patrolProd" then
            --self:call("_forEachPatrolUnit",...);
            --For each unit produced in order to patrol the base, add them to the patrol routine
            --local mission_data.patrol_r = bzRoutine.routineManager:getRoutine(mission_data.patrol_id);
            mission_data.patrol_r:addGameObject(object);
        end
        if data.name == "_doneTurret" then
            object:Goto(data.location);
        end
        if data.name == "_forEachProduced1" then
            object:SetTeamNum(1);
            mission_data.wait_for_units = mission_data.wait_for_units + 1;
        end
    end
end);




hook.Add("Start", "Mission:Start", function ()
    --core:onStart();
    SetPilot(1,5);
    SetScrap(1,8);
    Ally(1,3);
    gameobject.GetGameObject("abbarr2_barracks"):SetMaxHealth(0);
    gameobject.GetGameObject("abbarr3_barracks"):SetMaxHealth(0);
    gameobject.GetGameObject("abcafe3_i76building"):SetMaxHealth(0);
    SetMaxScrap(3,5000);
    SetScrap(3,2000);
    SetMaxPilot(3,5000);
    SetPilot(3,1000);
    local h = gameobject.GetGameObject("relic_1");
    if not h then error("relic_1 not found") end
    h:SetMaxHealth(900000);
    h:SetCurHealth(900000);
    --intro:start();
    for i = 1, 13 do
        gameobject.GetGameObject("patrol_" .. i):Patrol("patrol_path");
    end
    --ConstructorAi:addFromPath("make_bblpow",3,"bblpow");

      mission_data.mission_states = stateset.Start("mission")
        :on("main_objectives");
end);


hook.Add("Update", "Mission:Update", function (dtime, ttime)
    --core:update(dtime);
    --mission:Update(dtime);
    for i,v in pairs(mission_data.pwers) do
        if v.h:GetCurrentCommand() == AiCommand["GO"] then
            v.h:SetTeamNum(v.t);
            mission_data.pwers[i] = nil;
        end
    end

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

    --core:onCreateObject(handle);
    --mission:CreateObject(handle);
    local l = object:GetClassLabel();
    if(IsIn(l,{"ammopack","repairkit","daywrecker","wpnpower","camerapod"})) then
        table.insert(mission_data.pwers,{h=object,t=object:GetTeamNum()});
        object:SetTeamNum(1);
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

require("_audio_dev");