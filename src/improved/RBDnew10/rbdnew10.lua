require("_printfix");

print("\27[34m----START MISSION----\27[0m");

--- @diagnostic disable-next-line: lowercase-global
debugprint = print;
--traceprint = print;

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
local paramdb = require("_paramdb");
local waves = require("_waves");
require("_table_show");






local fail_des = {
    lpad = "rbd10l01.des",
    const = "rbd10l02.des",
    transports = "rbd10l04.des",
    recycler = "rbd10l03.des",
    factory = "rbd10l04.des"
};




local fury_waves = {
    {item = {"2 2", "2 2"}, chance = 1},
}

local light_waves = {
    {item = {" 2 ", "1 1"}, chance = 7},
    {item = {" 2 ", "7 7"}, chance = 7},
}

local heavy_waves = {
    {item = {" 2 ", "7 1"}, chance = 7}, --LIGHT
    {item = {"2 7 2", "3 1 1"}, chance = 7}, --ASSAULT
    {item = {"3 2", "4 4"}, chance = 5}, --BOMBER
    {item = {" 5 ", "5 7 7"}, chance = 4}, --APC
    {item = {" 6 ", "3 2"}, chance = 2} --WALKER
}




--[[
TODO:
- Land, fight some enemies
- Take command of base, build defenses
- Order Cons to    nav, he starts building
- Attack wavs get stronger
- Factory shows up, builds Mammoths
- Attack waves vanish
- Launch Pad finishes, Factory builds transports
- Furies show up
- Shaw abandoned us, we surrender

]]

local audio = {
    intro = "rbd1001.wav",
    furies = "rbd1002.wav",
    evacuate = "rbd1003.wav",
    shaw = "rbd1004.wav"
};





--- @param formation string[]
--- @param location Vector
--- @param dir Vector
--- @param units string[]
--- @param team TeamNum
--- @param seperation integer?
--- @return GameObject[] units
--- @return GameObject|nil leader
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
--- @param seperation integer?
local function spawnInFormation2(formation,location,units,team,seperation)
    local pos = GetPosition(location,0);
    if not pos then error("Failed to get position of " .. location) end
    local pos2 = GetPosition(location,1);
    if not pos2 then error("Failed to get position of " .. location) end
    local dir = pos2 - pos;
    return spawnInFormation(formation,pos,dir,units,team,seperation);
end

local function joinTables(...)
    local n = {};
    for i, v in ipairs({...}) do
      for i2, v2 in ipairs(v) do
        n[#n+1] = v2;
      end
    end
    return n;
  end

local function choose(...)
    local t = {...};
    local rn = math.random(#t);
    return t[rn];
end


--- @class MissionData10_KeyObjects
--- @field lpad GameObject?
--- @field const GameObject?
--- @field transports GameObject[]
--- @field enemy_units GameObject[]
--- @field furies GameObject[]

--- @class MissionData10
--- @field mission_states StateSetRunner
--- @field key_objects MissionData10_KeyObjects
--- @field sub_machines StateMachineIter[]
--- @field attacker_machines StateMachineIter[]
--- @field wave_controllers WaveSpawner[]
local mission_data = {
    key_objects = {
        transports = {},
        enemy_units = {},
        furies = {},
    },
    sub_machines = {},
    attacker_machines = {},
    wave_controllers = {},
    transport_count = 0,
};



--- @class MainObjectives10_state : StateMachineIter
--- @field building boolean
--- @field wave_timer number
--- @field factory_timer number
--- @field wave_controllers table<number, GameObject>
--- @field enemy_units GameObject[]
--- @field waves table<number, table<number, table<number, string>>>
statemachine.Create("main_objectives", {
    { "getToBase.start", function(state)
        --- @cast state MainObjectives10_state
        --Spawn two fighters attacking each silo in sequence
        for i, v in ipairs(spawnInFormation2({"1 1"}, "east_wave", {"avfigh"}, 2)) do
            --local s = mission.TaskManager:sequencer(v);
            --for i2=1, 3 do
            --    s:queue2("Attack",GetHandle(("silo%d"):format(i2)));
            --end

            local machine = statemachine.Start("getToBase_EastWave", nil, {
                v = v,
                targets = {
                    gameobject.GetGameObject("silo1"),
                    gameobject.GetGameObject("silo2"),
                    gameobject.GetGameObject("silo3"),
                },
            });
            table.insert(mission_data.sub_machines, machine);
        end
        state:next();
        return statemachine.FastResult(true);
    end },
    { "getToBase.update", function(state)
        --- @cast state MainObjectives10_state
        --local pp = GetPathPoints("bdog_base");
        local pp = utility.IteratorToArray(utility.IteratePath("bdog_base"));
        pp[1].y = 0;
        pp[2].y = 0;
        if gameobject.GetPlayerGameObject():GetDistance(pp[1]) < Length(pp[2]-pp[1]) then
            state:next();
            return statemachine.FastResult(true);
        end
    end },
    { "build_launchpad.start", function(state)
        --- @cast state MainObjectives10_state
        --state.subscriptions = {};

        AudioMessage(audio.intro);
        objective.AddObjective("rbd1001.otf");
        --state:startTask("order_to_build");
        state.building = false;
        state.wave_timer = 0;
        state.factory_timer = 60*15;
        mission_data.wave_controllers = {};
        mission_data.key_objects.enemy_units = {};
        state.waves = {
            [("%d"):format(0)] = {
                --{frequency,wave_count,variance,wave_type}
                {1/120,8,0.5,heavy_waves},
                {1/60,11,0.1,light_waves}
            },
            [("%d"):format(16*60)] = {
                {1/60,15,0.1,heavy_waves},
                {1/60,3,0.1,light_waves}
            },
            [("%d"):format(15*60)] = {
                {1/100,10,0.2,heavy_waves},
                {1/80,10,0.2,heavy_waves}
            }
        }
        state:next();
        return statemachine.FastResult(true);
    end },
    { "build_launchpad.order_to_build.start", function(state)
        --- @cast state MainObjectives10_state
        --bzRoutine.routineManager:startRoutine("waveSpawner",{"cca","nsdf"},{"east","west","cca","nsdf"},1/70,8,0.05,light_waves);
        mission_data.wave_state = "build_launchpad";
        waves.new("wavesStart", {"cca","nsdf"},{"east","west","cca","nsdf"},1/70,8,0.05,light_waves);
        state:next();
        return statemachine.FastResult(true);
    end },
    { "build_launchpad.order_to_build.update", function(state)
        --- @cast state MainObjectives10_state
        
        local const = gameobject.GetConstructorGameObject();
        if not const then error("Constructor not found") end
        local d1 = GetPosition("launchpad");
        local ctask = const:GetCurrentCommand();
        --debugprint("Constructor command", ctask);
        if not state.building and const:GetDistance("launchpad") < 100 and ctask == AiCommand["NONE"] then
            --local pp = GetPathPoints("launchpad");
            local pp = utility.IteratorToArray(utility.IteratePath("launchpad"));
            local t = BuildDirectionalMatrix(pp[1], pp[2] - pp[1]);
            state.building = true;
            mission_data.key_objects.const = const;
            --state.lpad_bid = ProducerAi:queueJob(ProductionJob("ablpadx",1,t));
            --state:call("_setUpProdListener",state.lpad_bid,"_lpad_done");
            producer.QueueJob("ablpadx", 1, t, TeamSlot.CONSTRUCT, { name = "_lpad_done" });
            --BuildAt(mission_data.key_objects.const,"ablpadx",t);
        end
        if not mission_data.order_to_build and state.building and mission_data.key_objects.const:IsDeployed() then
            --state:taskSucceed("order_to_build");
            mission_data.order_to_build = true;

            --self:startTask("build_lpad");
            objective.AddObjective("rbd1002.otf");
            --local btime = misc.odfFile("ablpadx"):getFloat("GameObjectClass","buildTime");
            local btime = paramdb.GetBuildTime("ablpadx");
            --self.factory_timer = math.min(self.factory_timer,btime);
            debugprint("Factory timer", btime);
            StartCockpitTimer(btime);

            --self:startTask("build_lpad");
            --self:startTask("factory_spawn");
            mission_data.mission_states:on("wave_spawner");
            mission_data.mission_states:on("factory_spawn");
            objective.RemoveObjective("rbd1001.otf");
            --state:next();
            --return;
        elseif state.building and not mission_data.key_objects.const:IsAlive() then
            --state:taskFail("order_to_build");
            --self:fail("const");
            FailMission(GetTime() + 5.0, fail_des["const"]);
            state:switch(nil);
            return;
        end


        --if self:hasTasksSucceeded("build_lpad","order_to_build","factory_spawn") then
        if mission_data.key_objects.lpad and mission_data.order_to_build and mission_data.factory_spawn then
            objective.UpdateObjective("rbd1002.otf", "GREEN");
            --self:success();
            --mission.Objective:Start("defend_and_escort",self.lpad,OOP.copyTable(mission_data.key_objects.enemy_units),mission_data.wave_controllers);
            state:next();
        end
    end },
    { "defend_and_escort.start", function(state)
        mission_data.key_objects.transports = {};
        --mission_data.key_objects.lpad = launchpad;
        --mission_data.key_objects.enemy_units = enemy_units;
        for i, v in pairs(mission_data.attacker_machines) do
            v:switch(nil);
        end
        for i, v in pairs(mission_data.key_objects.enemy_units) do
            --local s = mission.TaskManager:sequencer(v);
            --s:clear();
            --- @todo make sure if the unit is in an order state machine that we attach it to the unit so we can set it to a nil state here
            v:Retreat("enemy_base");
        end
        mission_data.mission_states:on("wave_spawner"); -- stop spawning waves
        --mission_data.wave_controllers = wave_controllers;
        --for i, v in pairs(mission_data.wave_controllers) do
        --    state:call("_hook_controller",v);
        --end
        mission_data.wave_state = "defend_and_escort";
        mission_data.key_objects.furies = {};
        --state:startTask("build_transports");
        state:next();
        AudioMessage(audio.evacuate);
    end },
    { "defend_and_escort.build_transports", function(state)
        --function(self,launchpad,enemy_units,wave_controllers)
        --self.fury_id = bzRoutine.routineManager:startRoutine("waveSpawner",{"fury"},{"fury"},1/30,5,0.05,fury_waves);
        waves.new("fury_spawn", {"fury"},{"fury"},1/30,5,0.05,fury_waves);
        mission_data.wave_state = "defend_and_escort";
        --bzRoutine.routineManager:getRoutine(self.fury_id):onWaveSpawn():subscribe(function(...)
        --    self:call("_fury_spawn",...);
        --end);
        --self.transport_job = ProducerAi:queueJobs(ProductionJob:createMultiple(3,"bvhaul30",1));
        producer.QueueJob("bvhaul30", 1, { name = "_transports_done" });
        producer.QueueJob("bvhaul30", 1, { name = "_transports_done" });
        producer.QueueJob("bvhaul30", 1, { name = "_transports_done" });
        --self:call("_setUpProdListeners",self.transport_job,"_transports_done","_each_transport");
        mission_data.mission_states:on("transports_alive"); -- if they exist, check if they are alive
        state:next();
    end },
    function(state)
        if mission_data.transport_count >= 3 then
            --self:taskSucceed("build_transports");
            --self:startTask("escort_transports");
            state:next();
        else
            if not gameobject.GetFactoryGameObject():IsAlive() then
                --self:taskFail("build_transports","factory");
                --self:fail("factory");
                objective.UpdateObjective("rbd1003.otf","RED");
                FailMission(GetTime()+5.0,fail_des["factory"]);
                state:switch(nil);
            end
        end
    end,
    { "escort_transports.start", function(state)
        --Make furies target transports
        for i, v in pairs(mission_data.key_objects.furies) do
            v:Attack(choose(unpack(mission_data.key_objects.transports)));
        end
        objective.AddObjective("rbd1003.otf");
        for i, v in ipairs(mission_data.key_objects.transports) do
            v:Goto(mission_data.key_objects.lpad);
        end
        state:next();
    end },
    { "escort_transports.update", function(state)
        for i, v in ipairs(mission_data.key_objects.transports) do --- @todo this should iterate backwards to make removals not break iteration shouldn't it?
            if v:GetDistance(mission_data.key_objects.lpad) < 60 then
                table.remove(mission_data.key_objects.transports, i); -- prevent system from marking them as dead by removing from tracking
                v:RemoveObject();
            end
        end
        if #mission_data.key_objects.transports <= 0 then
            mission_data.mission_states:off("transports_alive", true); -- no more transports to track
            --self:taskSucceed("escort_transports");
            objective.UpdateObjective("rbd1003.otf","GREEN");
            --self:success();
            AudioMessage(audio.shaw);
            SucceedMission(GetTime()+10.0,"rbd10w01.des");
            state:switch(nil);
        end
    end },
});


--- @class factory_spawn_state : StateMachineIter
statemachine.Create("factory_spawn", {
    { "start", function(state)
        -- wait for the timer started before this machine is activated to know when to advance
        if state:SecondsHavePassed(15 * 60) or GetCockpitTimer() <= 0 then
            state:SecondsHavePassed();
            state:next();
        end
    end },
    { "update", function(state)
        local f = gameobject.BuildGameObject("bvmuf30",1,"spawn_factory");
        --local s = mission.TaskManager:sequencer(f);
        --s:queue2("Goto","factory_path");
        --s:queue(AiCommand["GO_TO_GEYSER"]);

        local machine = statemachine.Start("factory_orders", nil, {
            v = f,
        });
        table.insert(mission_data.sub_machines, machine);

        --ProducerAi:queueJobs(ProductionJob:createMultiple(3,"bvmtnk30",1));
        producer.QueueJob("bvmtnk30", 1, nil, TeamSlot.FACTORY);
        producer.QueueJob("bvmtnk30", 1, nil, TeamSlot.FACTORY);
        producer.QueueJob("bvmtnk30", 1, nil, TeamSlot.FACTORY);
        --self:taskSucceed("factory_spawn");
        mission_data.factory_spawn = true;

        state:next();
    end },
    { "alive_monitor", function(state)
        if not gameobject.GetFactoryGameObject():IsAlive() then
            FailMission(GetTime()+5.0,fail_des["factory"]);
            state:switch(nil);
        end
    end },
});


--- @class bdog_base_attack_state10 : StateMachineIter
--- @field v GameObject
--- @field alt string
statemachine.Create("bdog_base_attack", {
    function (state)
        --- @cast state bdog_base_attack_state10
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end,
    { "FindTarget", function (state)
        --- @cast state bdog_base_attack_state10

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
        --- @cast state bdog_base_attack_state10
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:switch("FindTarget");
        end
    end },
});

--- @class factory_orders_state : StateMachineIter
--- @field v GameObject
statemachine.Create("factory_orders", {
    function (state)
        --- @cast state factory_orders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state.v:Goto("factory_path");
            state:next();
        end
    end,
    function (state)
        --- @cast state factory_orders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state.v:SetCommand(AiCommand["GO_TO_GEYSER"]);
            state:next();
        end
    end,
});


--- @class getToBase_EastWave_state : StateMachineIter
--- @field v GameObject
--- @field targets GameObject[]
--- @field index integer
statemachine.Create("getToBase_EastWave", {
     { "Wait", function (state)
        --- @cast state getToBase_EastWave_state
        if not state.v:IsAlive() then
            state:switch(nil); -- stop the machine if the unit is dead
            return statemachine.AbortResult();
        end
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end },
    { "Attack", function (state)
        --- @cast state getToBase_EastWave_state
        
        if not state.index then
            state.index = 1;
        end
        if state.index > #state.targets then
            state:switch(nil);
            return;
        end

        state.v:Attack(state.targets[state.index]);
        state:switch("Wait");
    end },
});

--- @class wave_spawner_state : StateMachineIter
--- @field wave_timer number
--- @field waves table<number, table<number, table<number, any>>>
statemachine.Create("wave_spawner", {
    { "start", function(state)
        --- @cast state wave_spawner_state
        state.wave_timer = 0;
        state.waves = {
            --[("%d"):format(0)] = {
            [0] = {
                --{frequency,wave_count,variance,wave_type}
                {1/120,8,0.5,heavy_waves},
                {1/60,11,0.1,light_waves}
            },
            --[("%d"):format(16*60)] = {
            [16*60] = {
                {1/60,15,0.1,heavy_waves},
                {1/60,3,0.1,light_waves}
            },
            --[("%d"):format(15*60)] = {
            [15*60] = {
                {1/100,10,0.2,heavy_waves},
                {1/80,10,0.2,heavy_waves}
            }
        }
        state:next();
        return statemachine.FastResult();
    end },
    function(state, dtime)
        --- @cast state wave_spawner_state
        state.wave_timer = state.wave_timer + dtime;
        for i, v in pairs(state.waves) do
            if(state.wave_timer > tonumber(i)) then
                for i2, wave_args in ipairs(v) do
                    --local r_id, r = bzRoutine.routineManager:startRoutine("waveSpawner",{"cca","nsdf"},{"east","west","cca","nsdf"},unpack(wave_args));
                    local r = waves.new("waves_from_spawner", {"cca","nsdf"}, {"east","west","cca","nsdf"}, unpack(wave_args));
                    --table.insert(mission_data.wave_controllers,r_id);
                    table.insert(mission_data.wave_controllers,r);
                    --state:call("_hook_controller",r_id);

                    --s:queue3("FindTarget", "bdog_base")
                    --local s = mission.TaskManager:sequencer(v);
                    --s:clear();
                    --Retreat(v,"enemy_base");
                    --table.insert(mission_data.key_objects.enemy_units,v);
                    --v:Retreat("enemy_base");
                    --table.insert(mission_data.key_objects.enemy_units, v);

                    --local machine = statemachine.Start("wave_orders", nil, {
                    --    v = v
                    --});
                    --table.insert(mission_data.key_objects.enemy_units,v);
                    --table.insert(mission_data.sub_machines, machine);
                end
                state.wave_timer = 0;
                state.waves[i] = nil;
                break;
            end
        end

    end
});

--[[
--- @class wave_orders_state : StateMachineIter
--- @field v GameObject
statemachine.Create("wave_orders", {
    function(state)
        --- @cast state wave_orders_state
        if state.v:GetCurrentCommand() == AiCommand["NONE"] then
            state.v:Retreat("enemy_base");
            state:next();
        end
    end,
});
--]]

stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
    :Add("protectRecycler", function(state, name)
        local playerRecycler = gameobject.GetRecyclerGameObject();
        if not playerRecycler or not playerRecycler:IsAlive() then
            FailMission(GetTime()+5.0,fail_des.recycler);
            state:off(name, true);
        end
    end)
    :Add("protectConstructor", function(state, name)
        local playerCons = gameobject.GetConstructorGameObject();
        if not playerCons or not playerCons:IsAlive() then
            objective.UpdateObjective("rbd1002.otf", "RED");
            FailMission(GetTime()+5.0,fail_des.const);
            state:off(name, true);
        end
    end)
    :Add("protectLPad", function(state, name)
        if not mission_data.key_objects.lpad:IsAlive() then
            objective.UpdateObjective("rbd1003.otf","RED");
            FailMission(GetTime()+5.0,fail_des["lpad"]);
            state:off(name, true);
        end
    end)
    :Add("factory_spawn", stateset.WrapStateMachine("factory_spawn"))
    :Add("wave_spawner",  stateset.WrapStateMachine("wave_spawner"))
    :Add("transports_alive", function(state, name)

        for i, v in pairs(mission_data.key_objects.transports) do
            if not v:IsAlive() then
                objective.UpdateObjective("rbd1003.otf","RED");
                FailMission(GetTime()+5.0,fail_des["transports"]);
                state:off(name, true);
            end
        end
    end)
;




hook.Add("WaveSpawner:Spawned", "Mission:WaveSpawnerSpawned", function (name, units, leader)
    --- @cast name string
    --- @cast units GameObject[]
    --- @cast leader GameObject

    debugprint("WaveSpawner:Spawned", name, table.show(units,"units"), leader);

    if mission_data.wave_state == "build_launchpad" then
        local n = {};
        for i, v in pairs(mission_data.key_objects.enemy_units) do
            if v:IsAlive() then
                table.insert(n, v);
            end
        end
        mission_data.key_objects.enemy_units = joinTables(n, units);
    elseif mission_data.wave_state == "defend_and_escort" then
        for i, v in pairs(units) do
            --local s = mission.TaskManager:sequencer(v);
            --s:clear();
            --- @todo make sure if the unit is in an order state machine that we attach it to the unit so we can set it to a nil state here
            v:Retreat("enemy_base");
            table.insert(mission_data.key_objects.enemy_units, v);
        end
    end
    if name == "waves_from_spawner" then
        for i, v in pairs(units) do
            --s:queue3("FindTarget", "bdog_base")

            local machine = statemachine.Start("bdog_base_attack", nil, { v = v, alt = "bdog_base" });
            table.insert(mission_data.attacker_machines, machine);

            --v:Retreat("enemy_base");
            table.insert(mission_data.key_objects.enemy_units, v);
        end
    end
    if name == "fury_spawn" then
        mission_data.key_objects.furies = joinTables(mission_data.key_objects.furies,units);
    end
end);

hook.Add("Producer:BuildComplete", "Mission:ProducerBuildComplete", function (object, producer, data)
    --- @cast object GameObject
    --- @cast producer GameObject
    --- @cast data any

    debugprint("Producer:BuildComplete", object:GetOdf(), producer:GetOdf(), data and table.show(data));

    if data and data.name then
        if data.name == "_lpad_done" then
            mission_data.key_objects.lpad = object;
            gameobject.GetConstructorGameObject():Stop(0);
            HideCockpitTimer();
            mission_data.mission_states:on("protectLPad");
            --self:taskSucceed("build_lpad"); -- assume true when mission_data.key_objects.lpad is not nil
        elseif data.name == "_transports_done" then
            table.insert(mission_data.key_objects.transports, object);
            object:SetObjectiveName(("Transport %d"):format(#mission_data.key_objects.transports));
            object:SetObjectiveOn();
            mission_data.transport_count = mission_data.transport_count + 1;
            --if mission_data.transport_count >= 3 then
            --    --self:taskSucceed("build_transports");
            --    self:startTask("escort_transports");
            --end
        end
    end
end);

hook.Add("Start", "Mission:Start", function ()
    --core:onStart();
    --getToBase:start();
    --protectRecycler:start();
    local n1 = gameobject.GetGameObject("nav1");
    local n2 = gameobject.GetGameObject("nav2");
    if not n1 or not n2 then error("Failed to get nav points") end
    n1:SetObjectiveName("Black Dog Outpost");
    n2:SetObjectiveName("Dropship build site");

    -- Move player into the air
    local player = gameobject.GetPlayerGameObject();
    if not player then error("Failed to get player") end
    local p = player:GetPosition();
    if not p then error("Failed to get player position") end
    local h = GetTerrainHeightAndNormal(p);
    p.y = h + 400;
    if not p then error("Failed to get player position") end
    player:SetPosition(p);

    mission_data.mission_states = stateset.Start("mission")
        :on("main_objectives")
        :on("protectRecycler");
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
                    debugprint("Removing sub machine", i);
                    table.remove(mission_data.sub_machines,i); -- clean up dead machines from the list
                end
            end
        end
    end
    if mission_data.attacker_machines then
        -- call update on all items and remove them if they return false
        for i = #mission_data.attacker_machines, 1, -1 do
            local v = mission_data.attacker_machines[i];
            if(v) then
                local success = v:run(dtime);
                --- @cast success StateMachineIterWrappedResult
                if not success or (statemachine.isstatemachineiterwrappedresult(success) and success.Abort) then
                    debugprint("Removing attacker machine", i);
                    table.remove(mission_data.attacker_machines,i); -- clean up dead machines from the list
                end
            end
        end
    end

    mission_data.mission_states:run(dtime); -- passed dtime in for the waves logic


    --cheating for testing
    local cons = gameobject.GetConstructorGameObject();
    if cons and cons:IsAlive() then cons:SetCurHealth(cons:GetMaxHealth()); end
    local rec = gameobject.GetRecyclerGameObject();
    if rec and rec:IsAlive() then rec:SetCurHealth(rec:GetMaxHealth()); end
    local fac = gameobject.GetFactoryGameObject();
    if fac and fac:IsAlive() then fac:SetCurHealth(fac:GetMaxHealth()); end
    local armory = gameobject.GetArmoryGameObject();
    if armory and armory:IsAlive() then armory:SetCurHealth(armory:GetMaxHealth()); end
    local lpad = mission_data.key_objects.lpad;
    if lpad and lpad:IsAlive() then lpad:SetCurHealth(lpad:GetMaxHealth()); end
    local silo1 = gameobject.GetGameObject("silo1");
    local silo2 = gameobject.GetGameObject("silo2");
    local silo3 = gameobject.GetGameObject("silo3");
    if silo1 and silo1:IsAlive() then silo1:SetCurHealth(silo1:GetMaxHealth()); end
    if silo2 and silo2:IsAlive() then silo2:SetCurHealth(silo2:GetMaxHealth()); end
    if silo3 and silo3:IsAlive() then silo3:SetCurHealth(silo3:GetMaxHealth()); end
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

require("_audio_dev");