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

--- @class MissionData08_KeyObjects
--- @field comms GameObject[]
--- @field powers GameObject[]
--- @field grigg GameObject?

--- @class MissionData08
--- @field mission_states StateSetRunner
--- @field key_objects MissionData08_KeyObjects
--- @field sub_machines StateMachineIter[]
--- @field timerOut boolean didn't destroy all towers in time but did enough to progress mission
--- @field prior_dead integer?
--- @field grigg_start_evac boolean used to push grigg out of a held state
--- @field grigg_audio_waits number[]
local mission_data = {
    key_objects = {
        comms = {},
        powers = {},
    },
    sub_machines = {},
    timerOut = false,
    prior_dead = nil,
    grigg_start_evac = false,
    grigg_audio_waits = { 60, 30, 30},
};

local audio = {
    intro = "rbd0801.wav",
    -- after tower 1 is down
    tower1 = "rbd0802.wav",
    --(Grigg’s updates, interspersed throughout)
    grigg_updates = {"rbdnew0820.wav", "rbdnew0821.wav", "rbdnew0822.wav"},

    -- after tower 2 is down
    tower2 = "rbd0803.wav",
    --going_in = "rbd0804.wav", replaced by rbd0802.wav
    evacuate = "rbd0805.wav",
    timer_out = "rbd0806.wav",
    timer_out_loss = "rbd0802L.wav",
    one_minute = "rbd0807.wav",
    too_close_loss = "rbd0801L.wav",
}

local tower_audio = {
    audio.tower1,
    audio.tower2,
};

local function countDead(handles, team)
    local c = 0;
    for i,v in pairs(handles) do
        if not (v:IsAlive(v) and (team==nil or team == v:GetTeamNum())) then
            c = c + 1;
        end
    end
    return c;
end

local function countAlive(handles, team)
    local c = 0;
    for _,v in pairs(handles) do
        if v:IsAlive() and (team == nil or team == v:GetTeamNum()) then
            c = c + 1;
        end
    end
    return c;
end

--- @class MainObjectives08_state : StateMachineIter
--- @field nextAudio integer
--- @field lastComm GameObject
statemachine.Create("main_objectives", {
    { "intoCinematic", function(state)
        --- @cast state MainObjectives08_state
        mission_data.comms = {
            gameobject.GetGameObject("comm1"),
            gameobject.GetGameObject("comm2"),
            gameobject.GetGameObject("comm3")
        };

        if not mission_data.comms[1]
        or not mission_data.comms[2]
        or not mission_data.comms[3] then
            error("Missing comms");
        end

        SetPilot(2,4);
        CameraReady();
        --self:startTask("focus_comm1");
        --self:startTask("build_howiz");
        AudioMessage(audio.intro);
        state:next();
        return statemachine.FastResult();
    end },
    { "intoCinematic.build_howiz", function(state)
        --- @cast state MainObjectives08_state
        producer.QueueJob("avartlf", 2, nil, { name = "_forEachHowie", location = GetPosition("base_artillery", 0) });
        producer.QueueJob("svartlf", 2, nil, { name = "_forEachHowie", location = GetPosition("base_artillery", 1) });
        producer.QueueJob("avartlf", 2, nil, { name = "_forEachHowie", location = GetPosition("base_artillery", 2) });
        producer.QueueJob("svartlf", 2, nil, { name = "_forEachHowie", location = GetPosition("base_artillery", 3) });
        state:next();
        return statemachine.FastResult();
    end },
    { "intoCinematic.focus_comm1", function(state)
        --- @cast state MainObjectives08_state
        if CameraCancelled() then
            state:switch("intoCinematic.end");
            return statemachine.FastResult();
        end
        if CameraPath("pan_1", 1500, 1000, mission_data.comms[1]:GetHandle()) then
            state:next();
        end
    end },
    { "intoCinematic.focus_comm2", function(state)
        --- @cast state MainObjectives08_state
        if CameraCancelled() then
            state:switch("intoCinematic.end");
            return statemachine.FastResult();
        end
        if CameraPath("pan_2", 1500, 1000, mission_data.comms[2]:GetHandle()) then
            state:next();
        end
    end },
    { "intoCinematic.focus_comm3", function(state)
        --- @cast state MainObjectives08_state
        if CameraCancelled() then
            state:switch("intoCinematic.end");
            return statemachine.FastResult();
        end
        if CameraPath("pan_3", 1500, 1000, mission_data.comms[3]:GetHandle()) then
            state:next();
        end
    end },
    { "intoCinematic.focus_base", function(state)
        --- @cast state MainObjectives08_state
        if CameraCancelled() or CameraPath("pan_4", 500, 2000, gameobject.GetGameObject("ubtart0_i76building"):GetHandle()) then
            state:next();
            return statemachine.FastResult();
        end
    end },
    { "intoCinematic.end", function(state)
        --- @cast state MainObjectives08_state
        CameraFinish();
        --mission.Objective:Start("misison"); -- destroyComms
        state:next();
        return statemachine.FastResult();
    end },
    { "destroyComms.init", function(state)
        --- @cast state MainObjectives08_state
        mission_data.key_objects.powers = {
            gameobject.GetGameObject("power1"),
            gameobject.GetGameObject("power2"),
            gameobject.GetGameObject("power3")
        };

        -- start
        --state.grigg_spawned = false;
        mission_data.key_objects.powers[1]:SetObjectiveOn();
        for i, v in ipairs(mission_data.key_objects.powers) do
            v:SetObjectiveName(("Power %d"):format(i));
        end
        --self:startTask("destroyComms");
        local timer = 60 * 8;
        state.nextAudio = 0;
        StartCockpitTimer(timer, timer * 0.5, timer * 0.1);
        state:next();
        return statemachine.FastResult();
    end },
    { "destroyComms.destroyComms.start", function(state)
        --- @cast state MainObjectives08_state
        mission_data.timerOut = false;
        objective.AddObjective("rbd0801.otf");
        mission_data.mission_states:on("grigg");
        state:next();
        return statemachine.FastResult();
    end },
    { "destroyComms.destroyComms", function(state)
        --- @cast state MainObjectives08_state
        local dead = countDead(mission_data.key_objects.powers);
        if dead ~= mission_data.prior_dead then
            state.nextAudio = state.nextAudio + 1;
            if tower_audio[state.nextAudio] then
                AudioMessage(tower_audio[state.nextAudio]);
            end
            mission_data.prior_dead = dead;

            -- this seems redandant but do check into it
            for i, v in ipairs(mission_data.key_objects.powers) do
                if v:IsAlive() then
                    v:SetObjectiveOn();
                    break;
                end
            end
        end
        if dead >= #mission_data.key_objects.powers then
            --self:taskSucceed("destroyComms");
            state:next();
            return;
        end
        if GetCockpitTimer() <= 0 then
            mission_data.timerOut = true;
            if countAlive(mission_data.key_objects.powers) > 1 then
                --self:taskFail("destroyComms");
                objective.UpdateObjective("rbd0801.otf", "RED");
                FailMission(GetTime()+5.0,"rbd08l02.des");
                state:switch(nil);
                return;
            else -- One tower left when time runs out, player does not fail
                -- Play audio message
                AudioMessage(audio.timer_out);
                --self:startTask("startEvac");
                state:next();
                return;
            end
        end
    end },
    { "destroyComms.destroyComms.finish", function(state)
        --- @cast state MainObjectives08_state
        StopCockpitTimer();
        HideCockpitTimer();
        objective.UpdateObjective("rbd0801.otf", "GREEN");
        --mission.AudioManager:Stop(self.grigg_id);
        
        mission_data.mission_states
            --:off("grigg")
            --:off("grigg_dead")
            :off("grigg_voice");
        state:next();
    end },
    { "evac.start", function(state)
        --- @cast state MainObjectives08_state
        --print("Evac started");
        --state.wait_timer = 5;
        --state:startTask("wait");
        --state.lastComm = lastComm; -- the old code just used the last comm object
        state.lastComm = mission_data.key_objects.comms[#mission_data.key_objects.comms];
        for i = #mission_data.key_objects.comms, 1, -1 do
            local comm = mission_data.key_objects.comms[i];
            if comm:IsAlive() then
                state.lastComm = comm;
                break;
            end
        end
        state:next();
    end },
    statemachine.SleepSeconds(5),
    { "evac.evacuate.start", function(state)
        --- @cast state MainObjectives08_state
        AudioMessage(audio.evacuate);
        objective.AddObjective("rbd0803.otf");

        --local s = mission.TaskManager:sequencer(mission_data.key_objects.grigg);
        --s:clear();
        mission_data.grigg_start_evac = true;
        --Goto(mission_data.key_objects.grigg,"grigg_to_gt");
        --s:queue3("GriggAtGt");
        state:next();
    end },
    { "evac.evacuate", function(state)
        --- @cast state MainObjectives08_state
        local d1 = Length(gameobject.GetPlayerGameObject():GetPosition() - GetPosition("spawn_griggs"));
        local d2 = Length(mission_data.key_objects.grigg:GetPosition() - GetPosition("spawn_griggs"));
        if d1 < 100 and d2 < 100 and (not state.lastComm or not state.lastComm:IsAlive()) then
            --self:taskSucceed("evacuate");
            state:next();
        end
    end },
    { "evac.evacuate.success", function(state)
        --- @cast state MainObjectives08_state
        objective.UpdateObjective("rbd0803.otf","GREEN");
        if(mission_data.timerOut) then
            SucceedMission(GetTime() + 5.0, "rbd08w02.des");
        else
            SucceedMission(GetTime() + 5.0, "rbd08w01.des");
        end
        state:switch(nil);
    end },
});

--- @class Grigg07_state : StateMachineIter
statemachine.Create("grigg", {
    { "powers", function(state)
        --- @cast state Grigg07_state
        local dead = countDead(mission_data.key_objects.powers);
        if dead >= 1 then
            mission_data.key_objects.grigg = gameobject.BuildGameObject("avtank", 1, "spawn_griggs");
            mission_data.key_objects.grigg:SetObjectiveName("Pvt. Grigg");
            mission_data.key_objects.grigg:SetObjectiveOn();
            --local s = mission.TaskManager:sequencer(mission_data.key_objects.grigg);
            --local pp = GetPathPoints("grigg_in");
            mission_data.key_objects.grigg:SetIndependence(0);
            mission_data.key_objects.grigg:SetPerceivedTeam(2);
            --s:queue2("Goto","grigg_in");
            --s:queue2("Dropoff",pp[#pp]);
            --self.grigg_spawned = true;
            
            --local griggAudioSequence = mission.AudioSequence();
            --griggAudioSequence:queueAudio(audio.grigg_updates[1], 55 + math.random(10));
            --griggAudioSequence:queueAudio(audio.grigg_updates[2], 20 + math.random(20));
            --griggAudioSequence:queueAudio(audio.grigg_updates[3], 20 + math.random(20));
            --self.grigg_id = mission.AudioManager:PlayAndCall(griggAudioSequence, self, nil, "_nextGriggAudio");

            mission_data.grigg_audio_waits = {
                55 + math.random(10),
                20 + math.random(20),
                20 + math.random(20),
            }

            mission_data.mission_states
                :on("grigg_dead")
                :on("grigg_voice");

            state:next();
        end
    end },
    { "order_wait_1", function (state)
        --- @cast state Grigg07_state
        if mission_data.grigg_start_evac then
            state:switch("evac");
            return;
        end
        if mission_data.key_objects.grigg:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end },
    { "goto", function (state)
        --- @cast state Grigg07_state
        if mission_data.grigg_start_evac then
            state:switch("evac");
            return;
        end
        mission_data.key_objects.grigg:Goto("grigg_in");
        state:next();
    end },
    { "order_wait_2", function (state)
        --- @cast state Grigg07_state
        if mission_data.grigg_start_evac then
            state:switch("evac");
            return;
        end
        if mission_data.key_objects.grigg:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end },
    { "dropoff", function (state)
        --- @cast state Grigg07_state
        if mission_data.grigg_start_evac then
            state:switch("evac");
            return;
        end
        --local pp = GetPathPoints("grigg_in");
        local last_path_point = GetPosition("grigg_in", GetPathPointCount("grigg_in") - 1);
        if last_path_point == nil then error("Grigg path point not found"); end
        mission_data.key_objects.grigg:Dropoff(last_path_point); -- stuck order since it's impossible
        state:next();
    end },
    --{ "order_wait_3", function (state)
    --    --- @cast state Grigg07_state
    --    if mission_data.grigg_start_evac then
    --        state:switch("evac");
    --        return;
    --    end
    --    if mission_data.key_objects.grigg:GetCurrentCommand() == AiCommand["NONE"] then
    --        state:next();
    --    end
    --end },
    { "hold_state", function (state)
        --- @cast state Grigg07_state
        if mission_data.grigg_start_evac then
            state:switch("evac");
        end
    end },
    { "evac", function (state)
        --- @cast state Grigg07_state
        mission_data.key_objects.grigg:Goto("grigg_to_gt");
        state:next();
    end },
    { "order_wait_4", function (state)
        --- @cast state Grigg07_state
        if mission_data.key_objects.grigg:GetCurrentCommand() == AiCommand["NONE"] then
            state:next();
        end
    end },
    { "goto_huntdown", function (state)
        --- @cast state Grigg07_state
        mission_data.key_objects.grigg:Goto("grigg_out");
        -- Make all base units hunt grigg
        local l = Length(GetPosition("base_warning", 1) - GetPosition("base_warning", 0));
        for obj in gameobject.ObjectsInRange(l, "base_warning") do
            if obj:GetTeamNum() == 2 and obj:IsCraft() and not obj:CanBuild() then
                obj:Attack(mission_data.key_objects.grigg);
            end
        end
        state:next();
    end }
});

--- @class AvoidBase08_state : StateMachineIter
--- @field warning boolean
statemachine.Create("avoidBase", {
    { "start", function(state)
        --- @cast state AvoidBase08_state
        objective.AddObjective("rbd0804.otf");
        state.warning = false;
        state:next();
    end },
    { "update", function (state)
        --- @cast state AvoidBase08_state
        local d = gameobject.GetPlayerGameObject():GetDistance("base_warning");
        local l = Length(GetPosition("base_warning", 1) - GetPosition("base_warning", 0));
        if not state.warning and d < l then
            --self:taskFail("warning");
            state.warning = true;
            objective.UpdateObjective("rbd0804.otf","YELLOW");
        elseif state.warning and d > l then
            --self:taskReset("warning");
            state.warning = false;
            objective.UpdateObjective("rbd0804.otf","WHITE");
        end

        local d2 = gameobject.GetPlayerGameObject():GetDistance("base");
        local l2 = Length(GetPosition("base",1) - GetPosition("base", 0));
        if d2 < l2 then
            objective.UpdateObjective("rbd0804.otf","RED");
            FailMission(GetTime() + 5.0, "rbd08l01.des");
            state:switch(nil);
        end
    end }
});

--- @class GriggVoice08_state : StateMachineIter
--- @field audio AudioMessage?
statemachine.Create("grigg_voice", {
    function(state)
        --- @cast state GriggVoice08_state
        if state:SecondsHavePassed(mission_data.grigg_audio_waits[1]) then
            state.audio = AudioMessage(audio.grigg_updates[1]);
            state:next();
        end
    end,
    function(state)
        --- @cast state GriggVoice08_state
        if not state.audio or IsAudioMessageDone(state.audio) then
            state.audio = nil;
            state:next();
        end
    end,
    function(state)
        --- @cast state GriggVoice08_state
        if state:SecondsHavePassed(mission_data.grigg_audio_waits[2]) then
            state.audio = AudioMessage(audio.grigg_updates[2]);
            state:next();
        end
    end,
    function(state)
        --- @cast state GriggVoice08_state
        if not state.audio or IsAudioMessageDone(state.audio) then
            state.audio = nil;
            state:next();
        end
    end,
    function(state)
        --- @cast state GriggVoice08_state
        if state:SecondsHavePassed(mission_data.grigg_audio_waits[3]) then
            state.audio = AudioMessage(audio.grigg_updates[3]);
            state:next();
        end
    end,
})

stateset.Create("mission")
    :Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
    :Add("avoidBase", stateset.WrapStateMachine("avoidBase"))
    :Add("grigg", stateset.WrapStateMachine("grigg"))
    :Add("grigg_voice", stateset.WrapStateMachine("grigg_voice"))
    :Add("grigg_dead", function(state, name)
        if not mission_data.key_objects.grigg or not mission_data.key_objects.grigg:IsAlive() then
            FailMission(GetTime()+5.0, "rbd08l05.des");
            state:off(name);
        end
    end)
;

hook.Add("Producer:BuildComplete", "Mission:ProducerBuildComplete", function (object, producer, data)
    --- @cast object GameObject
    --- @cast producer GameObject
    --- @cast data any

    debugprint("Producer:BuildComplete", object:GetOdf(), producer:GetOdf(), data and table.show(data));

    if data and data.name then
        if data.name == "_forEachHowie" then
            object:Goto(data.location);
        end
    end
end);

hook.Add("Start", "Mission:Start", function ()
    --introCinematic:start();
    --avoidBase:start();
    for i = 1, 6 do
        gameobject.BuildGameObject("avartl", 2, ("spawn_artl%d"):format(i));
    end
    SetPathLoop("walker1_path");
    SetPathLoop("walker2_path");
    gameobject.GetGameObject("avwalk1"):Goto("walker1_path");
    gameobject.GetGameObject("avwalk2"):Goto("walker2_path");
    for i = 1, 4 do
        local nav = gameobject.GetGameObject("nav" .. i);
        if not nav then error("Missing nav " .. i); end
        if i == 4 then
            nav:SetObjectiveName("Pickup Zone");
        else
            nav:SetObjectiveName("Navpoint " .. i);
        end
        nav:SetMaxHealth(0);
    end
    for i = 1, 3 do
        local comm = gameobject.GetGameObject("comm" .. i);
        if not comm then error("Missing comm " .. i); end
        comm:SetMaxHealth(0); -- These can't be killed.
    end

    mission_data.mission_states = stateset.Start("mission")
        :on("main_objectives")
        :on("avoidBase");
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