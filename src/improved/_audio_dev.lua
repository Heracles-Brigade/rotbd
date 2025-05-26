--- BZ98R LUA Extended AudioMessage Dev Hack.
---
--- Monkeypatch AudioMessages to use text files if missing.
---
--- @module '_audio_dev'
--- @author John "Nielk1" Klein

--- @diagnostic disable: undefined-global
local debugprint = debugprint or function(...) end;
local traceprint = traceprint or function(...) end;
--- @diagnostic enable: undefined-global

debugprint("_audio_dev Loading");

local objective = require("_objective");
local utility = require("_utility");
local hook = require("_hook");

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
    objective.AddObjective(msg.wav, "GREY", msg.time, "["..tostring(math.floor(msg.end_time - world_ttime)).."] "..msg.content, 999, true);
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
--- @function RepeatAudioMessage
function RepeatAudioMessage()
    if utility.istable(lastAudio) then
        --- @cast lastAudio DummyAudioMessage
        PlayFakeAudioMessage(lastAudio);
        return;
    end
    Original.RepeatAudioMessage();
end

local function splitToLines(input, maxWidth)
    local result = ""
    local currentLine = ""

    for word in input:gmatch("%S+") do
        if #currentLine + #word + 1 <= maxWidth then
            -- Add the word to the current line
            currentLine = currentLine == "" and word or (currentLine .. " " .. word)
        else
            -- Add the current line to the result and start a new line
            result = result .. currentLine .. "\n"
            currentLine = word
        end
    end

    -- Add the last line if it exists
    if currentLine ~= "" then
        result = result .. currentLine
    end

    return result
end

--- Plays the given audio file, which must be an uncompressed RIFF WAVE (.WAV) file.
--- Returns an audio message handle.
--- @param filename string
--- @return AudioMessage
--- @function AudioMessage
function AudioMessage(filename)
    local fileExists = UseItem(filename) and true or false;
    if fileExists then
        lastAudio = Original.AudioMessage(filename);
        return lastAudio;
    end
    local txdi = string.gsub(filename, "%.wav$", ".txdi");
    local content = UseItem(txdi);
    if content then
        local cleanContent = splitToLines(content, 40);
        print("AudioMessage: "..filename.." ("..txdi..")");
        print(cleanContent);
        local length = content:len() / 10;
        lastAudio = {
            dummy_audio = true,
            wav = filename,
            txdi = txdi,
            content = cleanContent,
            time = length,
            end_time = world_ttime + length,
        };
        PlayFakeAudioMessage(lastAudio);
        --- @cast lastAudio AudioMessage
        return lastAudio;
    end
    return Original.AudioMessage(filename);
end

--- Returns true if the audio message has stopped. Returns false otherwise.
--- @param msg AudioMessage|DummyAudioMessage
--- @return boolean
--- @function IsAudioMessageDone
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
--- @function IsAudioMessagePlaying
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
                objective.UpdateObjective(msg.wav, "GREY", nil, "["..tostring(math.floor(msg.end_time - world_ttime)).."] "..msg.content);
            end
        end
    end
end);

--- @class DummyAudioMessage
--- @field dummy_audio boolean
--- @field wav string
--- @field txdi string
--- @field content string
--- @field time number
--- @field end_time number