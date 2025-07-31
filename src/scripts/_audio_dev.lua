--- BZ98R LUA Extended AudioMessage Dev Hack.
---
--- Monkeypatch AudioMessages to use text files if missing.
---
--- @module '_audio_dev'
--- @author John "Nielk1" Klein

-- Estimated timing constants
local SECONDS_PER_CHAR = 1/13
local SECONDS_PER_DEADAIR_UNIT = 1/10

local logger = require("_logger");

logger.print(logger.LogLevel.DEBUG, nil, "_audio_dev Loading");

local objective = require("_objective");
local utility = require("_utility");
local hook = require("_hook");
local camera = require("_camera");

local Original = {
    RepeatAudioMessage = _G.RepeatAudioMessage,
    AudioMessage = _G.AudioMessage,
    IsAudioMessageDone = _G.IsAudioMessageDone,
    StopAudioMessage = _G.StopAudioMessage,
    IsAudioMessagePlaying = _G.IsAudioMessagePlaying,
};

--- @type AudioMessage|DummyAudioMessage|nil
local lastAudio = nil;
local world_ttime = 0;
local messages = {};

--- @param msg DummyAudioMessage
local function PlayFakeAudioMessage(msg)
    messages[msg.wav] = msg;
    objective.AddObjective(msg.wav, "GREY", msg.time, "["..tostring(math.floor(msg.end_time - world_ttime)).."]\n"..msg.content, 999, true);
end

--- @param msg DummyAudioMessage
--- @return boolean
local function IsFakeAudioMessageDone(msg)
    if messages[msg.wav] then
        return world_ttime > msg.end_time;
    end
    return true;
end

--- @param msg DummyAudioMessage
local function StopFakeAudioMessage(msg)
    if messages[msg.wav] then
        --messages[msg.wav] = nil;
        messages[msg.wav].end_time = 0;
        objective.RemoveObjective(msg.wav);
    end
end

--- @return boolean
local function IsFakeAudioMessagePlaying()
    for _, msg in pairs(messages) do
        if world_ttime < msg.end_time then
            return true;
        end
    end
    return false;
end

--- Repeat the last audio message.
function RepeatAudioMessage()
    if utility.istable(lastAudio) then
        --- @cast lastAudio DummyAudioMessage
        PlayFakeAudioMessage(lastAudio);
        return;
    end
    Original.RepeatAudioMessage();
end

local function splitToLines(input, maxWidth)
    local wrapped_lines = {}
    for orig_line in input:gmatch("[^\n]*") do
        local result = ""
        local currentLine = ""
        for word in orig_line:gmatch("%S+") do
            if #currentLine + #word + 1 <= maxWidth then
                currentLine = currentLine == "" and word or (currentLine .. " " .. word)
            else
                result = result .. currentLine .. "\n"
                currentLine = word
            end
        end
        if currentLine ~= "" then
            result = result .. currentLine
        end
        -- Trim leading/trailing spaces from each wrapped line
        for line in result:gmatch("[^\n]+") do
            wrapped_lines[#wrapped_lines + 1] = line:gsub("^%s+", ""):gsub("%s+$", "")
        end
    end
    return table.concat(wrapped_lines, "\n")
end

--- Plays the given audio file, which must be an uncompressed RIFF WAVE (.WAV) file.
--- Returns an audio message handle.
--- @param filename string
--- @return AudioMessage
function AudioMessage(filename)
    local fileExists = UseItem(filename)
    if fileExists ~= nil then
        lastAudio = Original.AudioMessage(filename)
        return lastAudio
    end
    local txdi = string.gsub(string.lower(filename), "%.wav$", ".wtx");
    local content = UseItem(txdi);
    if content ~= nil then
        local cleanContent = string.gsub(content, "PARENT diag%.voices\r?\n", "")
        cleanContent = string.gsub(cleanContent, "START\r?\n", "")

        cleanContent = string.gsub(cleanContent, ";$", "")

        -- Extract and sum all numbers between brackets
        local deadAirTime = 0
        cleanContent = string.gsub(cleanContent, "%[(%d+)%]", function(num)
            local localDeadAir = tonumber(num) or 0;
            deadAirTime = deadAirTime + localDeadAir
            if localDeadAir >= 100 then
                return "\n";
            end
            return "";
        end)

        -- remove paranthesis
        cleanContent = string.gsub(cleanContent, "%(([^)]+])%)", function(num)
            return "";
        end)

        -- Collapse multiple spaces to a single space
        while string.find(cleanContent, "  ") do
            cleanContent = string.gsub(cleanContent, "  ", " ")
        end

        cleanContent = splitToLines(cleanContent, 40)

        print("AudioMessage: "..filename.." ("..txdi..")")
        print(cleanContent)
        local length = (content:len() * SECONDS_PER_CHAR) + (deadAirTime * SECONDS_PER_DEADAIR_UNIT)
        lastAudio = {
            dummy_audio = true,
            wav = filename,
            txdi = txdi,
            content = cleanContent,
            time = length,
            end_time = world_ttime + length,
            camera = camera.InCamera(),
        }
        PlayFakeAudioMessage(lastAudio)
        --- @cast lastAudio AudioMessage
        return lastAudio
    end
    return Original.AudioMessage(filename);
end

--- Returns true if the audio message has stopped. Returns false otherwise.
--- @param msg AudioMessage|DummyAudioMessage
--- @return boolean
function IsAudioMessageDone(msg)
    if utility.istable(msg) then
        --- @cast msg DummyAudioMessage
        return IsFakeAudioMessageDone(msg);
    end
    return Original.IsAudioMessageDone(msg);
end

--- Stops the given audio message.
--- @param msg AudioMessage|DummyAudioMessage
--- @function StopAudioMessage
function StopAudioMessage(msg)
    if utility.istable(msg) then
        --- @cast msg DummyAudioMessage
        StopFakeAudioMessage(msg);
        return;
    end
    Original.StopAudioMessage(msg);
end

--- Returns true if <em>any</em> audio message is playing. Returns false otherwise.
--- @return boolean
function IsAudioMessagePlaying()
    return IsFakeAudioMessagePlaying() or Original.IsAudioMessagePlaying();
end

hook.Add("Update", "FakeAudioMessage.Update", function(dtime, ttime)
    world_ttime = ttime;
    for _, msg in pairs(messages) do
        if msg.dummy_audio then
            if world_ttime > msg.end_time then
                objective.RemoveObjective(msg.wav);
                --messages[msg.wav] = nil;
            else
                if camera.InCamera() then
                    msg.camera = true;
                    msg.end_time = msg.end_time + dtime; -- bump the end time if the camera is active
                end
                objective.UpdateObjective(msg.wav, "GREY", nil, (msg.camera and "[Delayed]" or "").."["..tostring(math.floor(msg.end_time - world_ttime)).."]\n"..msg.content);
            end
        end
    end
end);

hook.AddSaveLoad("FakeAudioMessage", function()
    return lastAudio, world_ttime, messages;
end, function(_lastAudio, _world_ttime, _messages)
    lastAudio = _lastAudio;
    world_ttime = _world_ttime;
    messages = _messages;
end);

logger.print(logger.LogLevel.DEBUG, nil, "_audio_dev Loaded");

--- @class DummyAudioMessage
--- @field dummy_audio boolean
--- @field wav string
--- @field txdi string
--- @field content string
--- @field time number
--- @field end_time number
--- @field camera boolean? If true, the camera was active and we were delayed