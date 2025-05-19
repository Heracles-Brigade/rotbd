--Rev_2

local api = require("_api");
local gameobject = require("_gameobject");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");
local objective = require("_objective");

--- @class MissionData_KeyObjects
--- @field recy GameObject?
--- @field tug GameObject?

--- @class RelicData
--- @field name string
--- @field other string
--- @field relic_name string
--- @field pickup_name string
--- @field vehicles string[]
--- @field relic GameObject?

--- @class MissionData
--- @field key_objects MissionData_KeyObjects
--- @field relic_data table<string, RelicData>
local mission_data = {};
mission_data.key_objects = {};
mission_data.relic_data = {
    nsdf = { name = "nsdf",
    other = "cca",
             relic_name = "relic_nsdf",
             pickup_name = "relic_nsdf_pickup",
             vehicles = { "avfigh","avtank","avltnk","avhaul","avrckt","avhraz" },
             wave = "wave5" },
    cca  = { name = "cca",
             other = "nsdf",
             relic_name = "relic_cca",
             pickup_name = "relic_cca_pickup",
             vehicles = { "svfigh","svtank","svrckt","svhaul","svltnk","svhraz" },
             wave = "wave4" },

}




local labels = {
    relic_tug = "relic_tug"
};

--local minit = require("minit")

--local mission = require('cmisnlib');
--local globals = {};
--local tracker = mission.UnitTracker:new();

-- NOTES:
--[[
1) Remove decorative gesyers in middle-map CHECK
2) Enemy Tugs speed 5m/s CHECK
3) Enemy Tug wingmen are two scouts/fighters CHECK
4) Increase pickup zone radius but keep it where it is imho CHECK
5) Allied Grizzlies show up at base to assist when Distress Call happens
]]

--[[
  Make escort smaller:
    two scouts/fighters
]]




--- @param formation string[]
--- @param location Vector
--- @param dir Vector
--- @param units string[]
--- @param team TeamNum
--- @param seperation number
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
            local h = gameobject.BuildGameObject(units[n],team,pos);
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

local function choose(...)
    local t = {...};
    local rn = math.random(#t);
    return t[rn];
end

local function chooseA(...)
    local t = {...};
    local m = 0;
    for i, v in pairs(t) do
        m = m + v.chance; 
    end
    local rn = math.random()*m;
    local n = 0;
    for i, v in ipairs(t) do
        if (v.chance+n) > rn then
        return v.item;
        end
        n = n + v.chance;
    end
end

--- @todo this likely isn't needed
--"Warming" up the RNG
for i=1, math.random(100,1000) do
    math.random();
end

--1.5 polyfill
--Formation = Formation or function(me,him,priority)
--  if(priority == nil) then
--    priority = 1;
--  end
--  SetCommand(me,AiCommand["FORMATION"],priority,him);
--end

--function TugPickup(handle,target,priority,sequencer)
--    local t = target:GetTug();
--    if(t:IsValid()) then
--        --If another tug has the relic, goto the relic
--        handle:Goto(target,priority);
--        --When reached the relic, do a check again
--        sequencer:push3("TugPickup",target,priority);
--    else
--        --Else try to pickup the relic
--        handle:Pickup(target,priority);
--    end
--end

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

--All the otfs we use
local otfs = {
    escort = "rbd0701.otf",
    relics = "rbd07ob1.otf",
    nsdf_distress = "rbd0703.otf",
    cca_distress = "rbd0704.otf",
    nsdf_tug = "rbd0705.otf",
    cca_tug = "rbd0706.otf"
}

--All the description files we use
local des = {
    loseRecycler = "rbd07los.des",
    loseTug = "rbd07l04.des",
    relic_nsdf_loss = "rbd07l02.des",
    relic_cca_loss = "rbd07l02.des",
    win = "rbd07win.des",
    relic_destroyed = "rbd07l03.des"
}

local audio = {
    intro = "rbd0701.wav",
    surrender = "rbd0702.wav",
    relic = "rbd0703.wav",
    relic_secured_1 = "rbd0704.wav",
    distress = "rbd0705.wav",
    trap = "rbd0706.wav",
    win = "rbd07wn.wav",
    tug_loss = "rbd0701L.wav",
    enemy_tug = "rbd0701W.wav",
    attack_wave = "rbd0702W.wav",
    enemy_got_relic = "rbd0703W.wav",
    enemy_captured_relic = "rbd0702L.wav"
}

--[[
  TODO:
    -Get feedback
    -Adjust difficulty (wave size, timers, etc)
    -Create cinematic for tugs
]]

--- @class AttackWaveStateMachineIter : StateMachineIter
--- @field delay number Delay in seconds
--- @field formation string[] Formation String Table
--- @field spawn string Spawn Location
--- @field dest string Destination Location
--- @field odfs string[] ODFs to spawn matching Formation String Table
--- @field team TeamNum Team to spawn the units on
--- @field seperation number Distance between units in formation
--- @return GameObject[]|StateMachineIterWrappedResult
statemachine.Create("delayed_spawn_formation_and_goto", {
    function(state)
        --- @cast state AttackWaveStateMachineIter
        if state:SecondsHavePassed(state.delay) then
            state:next();
        end
    end,
    function(state)
        --- @cast state AttackWaveStateMachineIter
        local units = {};
        for _, unit in pairs(spawnInFormation2(state.formation, state.spawn, state.odfs, state.team, state.seperation)) do
            unit:Goto(state.dest);
            table.insert(units, unit);
        end
        state:switch(nil);
        return statemachine.AbortResult(units);
    end,
});

--- @class MainMissionStateMachineIter : StateMachineIter
--- @field recy GameObject
--- @field tug GameObject
--- @field attacker_machines StateMachineIter[] StateMachines for the attackers, will nil when no longer used
--- @field attackers GameObject[] "attackers" spawned at the start, will nil when no longer used
--- @field cond_escort_completed boolean Temporary memo boolean to reduce calls
--- @field cond_kill_attackers_completed boolean Temporary memo boolean to reduce calls
statemachine.Create("main_objectives", {
    { "escortRecycler.start", function (state)
        --- @cast state MainMissionStateMachineIter
        
        -- init
        mission_data.key_objects.recy = gameobject.GetRecyclerGameObject();
        mission_data.key_objects.tug = gameobject.GetHandle(labels.relic_tug);
        
        local formation = {" 2 ",
                           "1 1"};
        -- start
        state.attacker_machines = {
            statemachine.Start("delayed_spawn_formation_and_goto", nil, { delay =  2, formation = formation, spawn = "wave1", dest = "wave1_path", odfs = { "svfigh", "avltnk" }, team = 2, seperation = 15 }),
            statemachine.Start("delayed_spawn_formation_and_goto", nil, { delay = 25, formation = formation, spawn = "wave2", dest = "wave2_path", odfs = { "avfigh", "avltnk" }, team = 2, seperation = 15 }),
            statemachine.Start("delayed_spawn_formation_and_goto", nil, { delay =  1, formation = formation, spawn = "wave3", dest = "wave3_path", odfs = { "svfigh", "svltnk" }, team = 2, seperation = 15 }),
        };
        state.attackers = {};
        objective.AddObjective(otfs.escort,"WHITE");
        AudioMessage(audio.intro);
        
        -- enable loss conditions
        mission_data.mission_states:on("loseTug"):on("loseRecycler");

        state:next();
    end },
    { "escortRecycler.attack_wait", function(state)
        --- @cast state MainMissionStateMachineIter
        local count_finished_attacker_machines = 0;
        for _, machine in ipairs(state.attacker_machines) do
            local success, attackers = machine:run();
            if success then
                if attackers then
                    for _, attacker in ipairs(attackers) do
                        table.insert(state.attackers, attacker);
                    end
                    count_finished_attacker_machines = count_finished_attacker_machines + 1; -- despite running this was the last step
                end
            else
                count_finished_attacker_machines = count_finished_attacker_machines + 1; -- not running so it must have finished prior
            end
        end
        if count_finished_attacker_machines == #state.attacker_machines then
            state.attacker_machines = nil; -- reduce save size
            state:next();
            return statemachine.FastResult();
        end
    end },
    { "escortRecycler.update", function(state)
        --- @cast state MainMissionStateMachineIter
        state.cond_escort_completed = state.cond_escort_completed or gameobject.GetRecyclerGameObject():GetDistance("bdog_base") < 100;
        state.cond_kill_attackers_completed = state.cond_kill_attackers_completed or areAllDead(state.attackers, 2);
        if state.cond_escort_completed and state.cond_kill_attackers_completed then
            objective.UpdateObjective(otfs.escort,"GREEN");
            state.cond_escort_completed = nil;
            state.cond_kill_attackers_completed = nil;
            state.attackers = nil;
            state:next();
        end
    end },
    { "reteriveRelics.state", function(self)
        -- init
        --self.enemies = {
        --    relic_nsdf = "nsdf",
        --    relic_cca = "cca",
        --    relic_nsdf_pickup = "nsdf",
        --    relic_cca_pickup = "cca"
        --}
        --self.other = {
        --    nsdf = "cca",
        --    cca = "nsdf"
        --}
        --mission_data.relic_data.nsdf.relic = gameobject.GetGameObject("relic_nsdf");
        --mission_data.relic_data.cca.relic  = gameobject.GetGameObject("relic_cca");
        --self.vehicles = {
        --    cca  = {"svfigh","svtank","svrckt","svhaul","svltnk","svhraz"},
        --    nsdf = {"avfigh","avtank","avltnk","avhaul","avrckt","avhraz"}
        --}
        --self.waves = {
        --    relic_nsdf = "wave5",
        --    relic_cca  = "wave4"
        --}
        --mission_data.key_objects.recy = gameobject.GetRecyclerGameObject();
        --mission_data.key_objects.tug = gameobject.GetGameObject(labels.relic_tug);
        --self.waveInterval = 140;

        -- start

        --Spawn attack @ nsdf_attack
        for _, v in pairs(spawnInFormation2({"1 3"}, ("nsdf_attack"), mission_data.relic_data.nsdf.vehicles, 2, 15)) do
            v:Goto("nsdf_attack");
        end
        
        --Spawn attack @ nsdf_base
        for _, v in pairs(spawnInFormation2({"1 1","6 6"}, "nsdf_path", mission_data.relic_data.nsdf.vehicles, 2, 15)) do
            --local def_seq = mission.TaskManager:sequencer(v);
            ----Goto relic site
            --def_seq:queue2("Goto",("nsdf_path"):format(f));
            ----Attack players base
            --def_seq:queue2("Goto",("nsdf_attack"):format(f));

            local def_seq = statemachine.Start("nsdf_base_attack", nil, { v = v });
            mission_data.sub_machines = mission_data.sub_machines or {};
            table.insert(mission_data.sub_machines, def_seq);
        end

        for _, v in pairs(spawnInFormation2({" 1 ","5 5"}, "cca_attack", mission_data.relic_data.cca.vehicles, 2, 15)) do
            v:Goto("cca_attack");
        end

        --self:startTask("relic_nsdf");
        --self:startTask("relic_cca");
        --self:startTask("relic_nsdf_pickup");
        --self:startTask("relic_cca_pickup");

        mission_data.fucking_garbage = mission_data.fucking_garbage or {};
        mission_data.fucking_garbage.relic_nsdf = "running";
        mission_data.fucking_garbage.relic_cca = "running";
        mission_data.fucking_garbage.relic_nsdf_pickup = "running";
        mission_data.fucking_garbage.relic_cca_pickup = "running";

        --Give the player some time to build units
        --Timer will be set to 30 if the player
        --picks up one of the relics
        local ranC = math.random(0,1);
        self.bufferTime = {
            cca = ranC*500 + 500,
            nsdf = math.abs(ranC-1)*500 + 500
        };
        self.spawnedEnemyTugs = {
            cca = false,
            nsdf = false
        };
        --self.waveTimer = {
        --    cca = ranC*self.waveInterval + self.waveInterval,
        --    nsdf = math.abs(ranC-1)*self.waveInterval + self.waveInterval
        --};
        self.distressCountdown = 5;
        self.audio_played = false;
        objective.AddObjective(otfs.relics, "WHITE", 16);
        
        self.nsdf_attack = statemachine.Run("relic_wave_spawner", nil, { f = "nsdf", noExtraWait = ranC == 1,  waveInterval = 140, vehicles = { "avfigh","avtank","avltnk","avhaul","avrckt","avhraz" } });
        self.cca_attack  = statemachine.Run("relic_wave_spawner", nil, { f = "cca" , noExtraWait = ranC == 0 , waveInterval = 140, vehicles = { "svfigh","svtank","svrckt","svhaul","svltnk","svhraz" } });
        self.nsdf_tug = statemachine.Run("relic_tug_spawner", nil, { f = "nsdf", noExtraWait = ranC == 1,  bufferTime = 500, vehicles = { "avfigh","avtank","avltnk","avhaul","avrckt","avhraz" }, otf = otfs.nsdf_tug });
        self.cca_tug  = statemachine.Run("relic_tug_spawner", nil, { f = "cca" , noExtraWait = ranC == 0 , bufferTime = 500, vehicles = { "svfigh","svtank","svrckt","svhaul","svltnk","svhraz" }, otf = otfs.cca_tug  });
        mission_data.sub_machines = mission_data.sub_machines or {};
        table.insert(mission_data.sub_machines, self.nsdf_attack);
        table.insert(mission_data.sub_machines, self.cca_attack);
        table.insert(mission_data.sub_machines, self.nsdf_tug);
        table.insert(mission_data.sub_machines, self.cca_tug);

        mission_data.mission_states:on("relic_destroyed");

        self:next();
    end },
    { "reteriveRelics.update", function(self)
        for relic_task,relic in pairs(mission_data.key_objects.relics) do
            --- @cast relic GameObject
            --- @cast relic_task "relic_nsdf"|"relic_cca" -- was k

            local f = self.enemies[relic_task];
            --- @cast f "nsdf"|"cca"
            
            --- Pickup Task
            local pickup_relic_task = relic_task.."_pickup"; -- was ptask
            --- @cast pickup_relic_task "relic_nsdf_pickup"|"relic_cca_pickup"
            
            --Check which base the relics are in if any at all
            local bdog = relic:GetDistance("bdog_base") < 100;
            local cca  = relic:GetDistance("cca_base" ) < 100;
            local nsdf = relic:GetDistance("nsdf_base") < 100;
            local tug = relic:GetTug();
            --If no one has capture the relic yet
            if(mission_data.fucking_garbage[relic_task] == "running") then -- NSDF and CCA base tasks are active
                --If bdog has it, set state to succeeded
                if(bdog) then
                    if(not tug or not tug:IsValid()) then
                        --self:taskSucceed(relic_task);
                        mission_data.fucking_garbage[relic_task] = "succeeded"

                        local fac = self.enemies[relic_task];
                        objective.UpdateObjective(otfs[("%s_tug"):format(fac)],"GREEN");
                        if(not self.audio_played) then
                            AudioMessage(audio.relic_secured_1);
                            self.audio_played = true;
                        end
                    end
                    --Else if cca or nsdf has it, set state to failed
                elseif(cca or nsdf) then
                    --self:taskFail(relic_task);
                    mission_data.fucking_garbage[relic_task] = "failed"

                    local fac = self.enemies[relic_task];
                    objective.UpdateObjective(otfs[("%s_tug"):format(fac)],"RED");
                    --self:fail(("%s_loss"):format(name));
                    FailMission(GetTime() + 5,des[("%s_loss"):format(name)]);
                end
                --If someone had it, but no longer has reset the state
            elseif(mission_data.fucking_garbage[relic_task] == "running" and (not (bdog or cca or nsdf) )) then
                --self:taskReset(relic_task);
                mission_data.fucking_garbage[relic_task] = "running"

                local fac = self.enemies[relic_task];
                objective.UpdateObjective(otfs[("%s_tug"):format(fac)],"WHITE");
            end
            if(mission_data.fucking_garbage[pickup_relic_task] == "running" ) then -- NSDF and CCA pickup tasks are active
                if(tug and tug:GetTeamNum() == 1) then
                    --self:taskSucceed(pickup_relic_task);
                    mission_data.fucking_garbage[pickup_relic_task] = "succeeded"
                elseif(tug and tug:GetTeamNum() == 2) then
                    --self:taskFail(pickup_relic_task,tug,relic);
                    mission_data.fucking_garbage[pickup_relic_task] = "failed"
                    --Fail task, reset if player manages to retake it
                    
                    --Paint the enemy tug carrying the relic
                    tug:SetObjectiveOn()
                    --Unpaint the relic
                    relic:SetObjectiveOff()
                    --Set relic's team to 2, so that the AI can attack
                    --the tug carrying it, might want to do this when the
                    --players tug also captures the relic
                    relic:SetTeamNum(2);
                end
            elseif(tug and mission_data.fucking_garbage[pickup_relic_task] ~= "running" and not tug:IsValid()) then
                --self:taskReset(pickup_relic_task,tug,relic);
                mission_data.fucking_garbage[pickup_relic_task] = "running"
                
                --Unpain the tug carrying the relic
                tug:SetObjectiveOff();
                --Pain the relic
                relic:SetObjectiveOn();
                --Reset team of the relic to 0
                relic:SetTeamNum(0);
            end
        end
        
        if not mission_data.fucking_garbage.distress and
          (mission_data.fucking_garbage["relic_nsdf_pickup"] == "succeeded"
        or mission_data.fucking_garbage["relic_cca_pickup"] == "succeeded"
        or mission_data.fucking_garbage["relic_nsdf"] == "succeeded"
        or mission_data.fucking_garbage["relic_cca"] == "succeeded") then
            for i,v in pairs(mission_data.key_objects.relics) do
                local pickup_task = i .. "_pickup";
                local faction = self.enemies[i];
                local other_faction = self.other[faction];
                local other_task = ("relic_%s"):format(other_faction);
                local other_pickup_task = other_task .. "_pickup";
                local other_relic = mission_data.key_objects.relics[other_task];
                --If we have picked up one of the relics
                --if(name == pickup_task) then
                if(true) then
                    --AI has no time to lose
                    self.bufferTime[faction] = math.min(self.bufferTime[faction],10);
                    self.bufferTime[other_faction] = math.min(self.bufferTime[other_faction],180);
                    --If there hasn't been a distress call yet
                    if(self:hasTaskSucccededBefore(other_pickup_task) and (not self:hasTaskStarted("distress"))) then
                        --The same faction should create a distress call
                        mission_data.distress_faction = faction;
                        mission_data.fucking_garbage.distress = "running";
                        stateset:on("distress");
                    end
                end

                if(name == i) then
                    --Spawn wave4 or wave5
                    local p = self.waves[i];
                    --Spawn two bombers
                    for _,v in pairs(spawnInFormation2({"6 6"},p,self.vehicles[faction],2,15)) do
                        v:Goto(("%s_path"):format(p));
                    end
                end
            end
        end
        
        if mission_data.fucking_garbage.distress == "succeeded"
        and mission_data.fucking_garbage["relic_nsdf"] == "succeeded"
        and mission_data.fucking_garbage["relic_cca"] == "succeeded" then
            objective.UpdateObjective(otfs.relics,"GREEN");
            SucceedMission(GetTime() + 5, des.win);
            self:next();
        end
    end }
});

--- @class RelicTugEscortOrders_state : StateMachineIter
--- @field v GameObject
--- @field tug GameObject
--- @field f string
statemachine.Create("relic_tug_escort_orders", {
    function (state)
        --- @cast state RelicTugEscortOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugEscortOrders_state
        state.v:Defend2(state.tug);
        state:next();
    end,
    function (state)
        --- @cast state RelicTugEscortOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugEscortOrders_state
        state.v:Goto(("%s_attack"):format(state.f));
        state:next();
    end
});

--- @class RelicTugAttackOrders_state : StateMachineIter
--- @field v GameObject
--- @field f string
statemachine.Create("relic_tug_attack_orders", {
    function (state)
        --- @cast state RelicTugAttackOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugAttackOrders_state
        state.v:Goto(("%s_path"):format(state.f));
        state:next();
    end,
    function (state)
        --- @cast state RelicTugAttackOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugAttackOrders_state
        state.v:Goto(("%s_attack"):format(state.f));
        state:next();
    end
});

--- @class RelicTugOrders_state : StateMachineIter
--- @field v GameObject
--- @field f string
--- @field relic GameObject
statemachine.Create("relic_tug_orders", {
    function (state)
        --- @cast state RelicTugOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugOrders_state
        state.v:Goto(("%s_path"):format(state.f));
        state:next();
    end,
    { "pre_tug_state", function (state)
        --- @cast state RelicTugOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end },
    function (state)
        --- @cast state RelicTugOrders_state
        local t = state.relic:GetTug();
        if t and t:IsValid() then
            --If another tug has the relic, goto the relic
            state.v:Goto(state.v, 1);
            --When reached the relic, do a check again
            --sequencer:push3("TugPickup", state.v, 1);
            state:switch("pre_tug_state");
        else
            --Else try to pickup the relic
            state.v:Pickup(state.relic, 1);
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugOrders_state
        state.v:Goto(("%s_path"):format(state.f));
        state:next();
    end,
    function (state)
        --- @cast state RelicTugOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugOrders_state
        state.v:Goto(("%s_return"):format(state.f));
        state:next();
        return statemachine.AbortResult();
    end,
    function (state)
        --- @cast state RelicTugOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state RelicTugOrders_state
        state.v:Dropoff(("%s_base"):format(state.f));
        state:next();
        return statemachine.AbortResult();
    end
});

--- @class NSDFBaseAttack_state : StateMachineIter
--- @field v GameObject
statemachine.Create("nsdf_base_attack", {
    function (state)
        --- @cast state NSDFBaseAttack_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state NSDFBaseAttack_state
        state.v:Goto("nsdf_path");
        state:next();
        return statemachine.AbortResult();
    end,
    function (state)
        --- @cast state NSDFBaseAttack_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        --- @cast state NSDFBaseAttack_state
        state.v:Goto("nsdf_attack");
        state:next();
        return statemachine.AbortResult();
    end
});

--- @class RelicTugSpawner_state : StateMachineIter
--- @field noExtraWait boolean
--- @field f string Prefix to some path point names
--- @field otf string
statemachine.Create("relic_tug_spawner", {
    function (state)
        --- @cast state RelicTugSpawner_state
        -- I thought this was to stagger the waves but this just delays one a cycle, but after that will line up with each other
        -- I feel like it would make more sense to make this delay for waveinterval/2 instead
        if state.noExtraWait or state:SecondsHavePassed(mission_data.bufferTime) then
            state:SecondsHavePassed();
            state:next();
            return statemachine.FastResult(); -- start next state immediately
        end
    end,
    function (state)
        --- @cast state RelicTugSpawner_state
        if state:SecondsHavePassed(mission_data.bufferTime) then
            --AddObjective(otfs[("%s_tug"):format(state.f)],color);
            objective.AddObjective(state.otf,"WHITE");

            local s = ("%s_spawn"):format(f);
            local tug = gameobject.BuildGameObject(state.vehicles[4],2,s);
            --Create a sequence with all the tugs actions from creation to end
            --local tug_sequencer = mission.TaskManager:sequencer(tug);
            --tug_sequencer:queue2("Goto",("%s_path"):format(f));
            --tug_sequencer:queue3("TugPickup",relic,1);
            --tug_sequencer:queue2("Goto",("%s_return"):format(f));
            --tug_sequencer:queue2("Dropoff",("%s_base"):format(f));
            local tug_sequencer = statemachine.Start("relic_tug_orders", nil, { v = tug, f = state.f, relic = state.relic });

            mission_data.sub_machines = mission_data.sub_machines or {};
            table.insert(mission_data.sub_machines, tug_sequencer);

            --Create escort
            for _,v in pairs(spawnInFormation2({"2 2"},s,state.vehicles,2,15)) do
                --local def_seq = mission.TaskManager:sequencer(v);
                --def_seq:queue2("Defend2",tug);
                ----If tug dies, attack the players base
                --def_seq:queue2("Goto",("%s_attack"):format(f));
                local def_seq = statemachine.Start("relic_tug_escort_orders", nil, { v = v, tug = tug, f = state.f });
                table.insert(mission_data.sub_machines, def_seq);
            end
            
            --Create Attack
            for _,v in pairs(spawnInFormation2({"1 1"},("%s_path"):format(state.f),state.vehicles,2,15)) do
                --local def_seq = mission.TaskManager:sequencer(v);
                ----Goto relic site
                --def_seq:queue2("Goto",("%s_path"):format(f));
                ----Attack players base
                --def_seq:queue2("Goto",("%s_attack"):format(f));
                local def_seq = statemachine.Start("relic_tug_attack_orders", nil, { v = v, f = state.f });
                table.insert(mission_data.sub_machines, def_seq);
            end

            state:next();
        end
    end
});

--- @class RelicWaveSpawner_state : StateMachineIter
--- @field waveInterval number
--- @field f string Prefix to some path point names
--- @field vehicles string[] Vehicles odfs to spawn
--- @field noExtraWait boolean
statemachine.Create("relic_wave_spawner", {
    function (state)
        --- @cast state RelicWaveSpawner_state
        -- I thought this was to stagger the waves but this just delays one a cycle, but after that will line up with each other
        -- I feel like it would make more sense to make this delay for waveinterval/2 instead
        if state.noExtraWait or state:SecondsHavePassed(mission_data.waveinterval) then
            state:SecondsHavePassed();
            state:next();
            return statemachine.FastResult(); -- start next state immediately
        end
    end,
    function (state)
        --- @cast state RelicWaveSpawner_state
        if state:SecondsHavePassed(mission_data.waveinterval) then -- can't use lap mode due to needing to change the delay
            mission_data.waveinterval = mission_data.waveinterval + mission_data.waveinterval*0.05; -- push the next wave out further

            local wave = chooseA(
                { item = { " 2 ", "1 1" }, chance = 10 }, -- tank, two fighters
                { item = { " 2 ", "3 5" }, chance =  9 }, -- tank, one rkct tank and one light tank
                { item = { " 2 ", " 6 " }, chance =  4 }  -- tank and two bombers
            );

            local units, lead = spawnInFormation2(wave,("%s_path"):format(state.f),self.vehicles,2,15)
            mission_data.sub_machines = mission_data.sub_machines or {};
            for i2, v2 in pairs(units) do
                local machine = statemachine.Start("relic_wave_orders", nil, { v = v2, f = state.f, lead = lead });
                table.insert(mission_data.sub_machines, machine);
            end
        end
    end
});

--- @class RelicWaveOrders_state : StateMachineIter
--- @field v GameObject
--- @field f string
--- @field leader GameObject
statemachine.Create("relic_wave_orders", {
    function (state)
        --- @cast state RelicWaveOrders_state
        if state.v ~= state.leader then
            state.v:Defend2(state.leader);
            state:next();
        else
            state:switch("leader_goto");
        end
    end,
    function (state)
        --- @cast state RelicWaveOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:switch("attack"); -- if the leader dies, inherit attack state
        end
    end,
    -- Goto relic site
    { "leader_goto", function (state)
        --- @cast state RelicWaveOrders_state
        state.v:Goto(("%s_path"):format(state.f));
        state:next();
    end },
    function (state)
        --- @cast state RelicWaveOrders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    -- Attack players base
    { "attack", function (state)
        --- @cast state RelicWaveOrders_state
        state.v:Goto(("%s_attack"):format(state.f));
        state:next();
        return statemachine.AbortResult();
    end }
});

statemachine.Create("FUCKING WHATEVER THE FUCK THIS IS", {
    function (state)
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    function (state)
        state.v:Attack(gameobject.GetPlayerGameObject());
        state:next();
    end,
    function (state)
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    -- Attack players base
    { "attack", function (state)
        state.v:Goto(("%s_attack"):format(mission_data.distress_faction));
        state:next();
        return statemachine.AbortResult();
    end }
});

stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))

    :Add("loseTug", function (state)
        if not mission_data.key_objects.tug:IsAlive() then
            objective.UpdateObjective(otfs.escort,"RED");
            FailMission(GetTime() + 5,des.loseTug);
        end
    end)
    :Add("loseRecycler", function (state)
        if not mission_data.key_objects.recy:IsAlive() then
            objective.UpdateObjective(otfs.escort,"RED");
            FailMission(GetTime() + 5,des.loseRecycler);
        end
    end)
    :Add("relic_destroyed", function (state, name)
        if not mission_data.key_objects.relics.nsdf or not mission_data.key_objects.relics.nsdf:IsAlive() then
            --objective.UpdateObjective(otfs.escort,"RED"); -- not sure what objective to red here
            FailMission(GetTime() + 5,des.relic_destroyed);
            state:off(name, true);
            return;
        end
        if not mission_data.key_objects.relics.cca or not mission_data.key_objects.relics.cca:IsAlive() then
            --objective.UpdateObjective(otfs.escort,"RED"); -- not sure what objective to red here
            FailMission(GetTime() + 5,des.relic_destroyed);
            state:off(name, true);
            return;
        end
    end)

    :Add("distress", stateset.WrapStateMachine("distress"))
;

statemachine.Create("distress", {
    function (state)
        if mission_data.distress_faction then
            state:next();
        end
    end,
    statemachine.SleepSeconds(5),
    function (self)
        local distress_l = ("%s_distress"):format(a1); 
        local nav = gameobject.BuildGameObject("apcamr",1,distress_l);
        nav:SetObjectiveName("Distress Call");
        objective.AddObjective(otfs[distress_l]);
        self:next();
    end,
    function (self)
        local dpath = ("%s_distress"):format(mission_data.distress_faction);
        local apath = ("%s_ambush"):format(mission_data.distress_faction);
        local d_att = self.vehicles[mission_data.distress_faction];
        if(gameobject.GetPlayerGameObject():GetDistance(dpath) < 100) then
            --It is a trap, spawn ambush
            for _,v in pairs(spawnInFormation2({"1 2 3 1"},apath,d_att,2,15)) do
                --local tm = mission.TaskManager:sequencer(v);
                ----Everyone attack the player
                --tm:queue2("Attack",gameobject.GetPlayerGameObject());
                ----Then attack the base!
                --tm:queue2("Goto",("%s_attack"):format(mission_data.distress_faction));

                local tm = statemachine.Start("FUCKING WHATEVER THE FUCK THIS IS", nil, { v = v });
                mission_data.sub_machines = mission_data.sub_machines or {};
                table.insert(mission_data.sub_machines, tm);
            end
            --self:taskSucceed("distress");
            self:next();
        end
    end,
    function (self)
        objective.UpdateObjective(otfs[("%s_distress"):format(mission_data.distress_faction)],"GREEN");
        mission_data.fucking_garbage.distress = "succeeded";
        self:next();
    end
});





----setUpBase objective that isn't currently used
---- was between escortRecycler and reteriveRelics
--local setUpBase = mission.Objective:define("setUpBase"):setListeners({
--    start = function()
--        AudioMessage(audio.surrender);
--        AddObjective(otfs.createBase);
--    end,
--    update = function(self)
--        if(tracker:gotOfClass("wingman",5,1) and tracker:gotOfClass("turrettank",2)) then
--            self:success();
--        elseif(not IsAlive(GetRecyclerHandle())) then
--            self:fail();
--        end
--    end,
--    success = function(self)
--        UpdateObjective(otfs.createBase,"GREEN");
--    end,
--    fail = function(self)
--        UpdateObjective(otfs.createBase,"RED");
--        FailMission(GetTime()+5,des.loseRecycler);
--    end
--});




hook.Add("Start", "Mission:Start", function ()
    SetScrap(1,10);
    SetPilot(1,25)
    --Start objective to escort recycler
    --escortRecycler:start();
    mission_data.mission_states = stateset.Start("mission"):on("main_objectives");
    --mission.fixTugs();
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

    mission_data.mission_states:run();
end);

--function CreateObject(handle)
--    mission:CreateObject(handle);
--end
--
--function AddObject(handle)
--    mission:AddObject(handle);
--end
--
--function DeleteObject(handle)
--    mission:DeleteObject(handle);
--end

hook.AddSaveLoad("Mission",
function()
    return mission_data;
end,
function(g)
    mission_data = g;
end);