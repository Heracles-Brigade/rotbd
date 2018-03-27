local OOP = require("oop");
local misc = require("misc");
local bzRoutine = require("bz_routine");
local rx = require("rx");
local mission = require("cmisnlib");

local Routine = bzRoutine.Routine;

local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local Class = OOP.Class;
local Serializable = misc.Serializable;
local Updateable = misc.Serializable;
local StartListener = misc.StartListener;
local ObjectListener = misc.ObjectListener;
local BzInit = misc.BzInit;


local choose = mission.choose;
local chooseA = mission.chooseA;


function FindTarget(handle,alt,sequencer)
  local ne = GetNearestEnemy(handle);
  if(IsValid(ne)) then
    sequencer:queue2("Attack",GetNearestEnemy(handle));
    sequencer:queue3("FindTarget",alt);
  elseif(GetDistance(handle,alt) > 50) then
    sequencer:queue2("Goto",alt);
    sequencer:queue3("FindTarget",alt);
  else
    sequencer:queue(AiCommand["Hunt"]);
  end
end

local function spawnWave(wave_table,faction,location)
  print("Spawn Wave",wave_table,faction,location,units[faction]);
  local units, lead = mission.spawnInFormation2(wave_table,("%s_wave"):format(location),units[faction],2);
  for i, v in pairs(units) do
    local s = mission.TaskManager:sequencer(v);
    if(v == lead) then
      s:queue2("Goto",("%s_path"):format(location));
    else
      s:queue2("Follow",lead);
    end
    s:queue3("FindTarget","bdog_base");
  end
  return units;
end


local WaveSpawner = Decorate(
  Routine({
    name = "waveSpawner",
    delay = 2
  }),
  Class("waveSpawnerClass",{
    constructor = function()
      self.waves_left = 0;
      self.wave_frequency = 0;
      self.timer = 0;
      self.variance = 0;
      self.c_variance = 0;
      self.wave_subject = rx.Subject.create();
    end,
    methods = {
      isAlive = function()
        return self.waves_left > 0;
      end,
      save = function()
        return self.wave_frequency, 
          self.waves_left, 
          self.timer, 
          self.variance, 
          self.c_variance, 
          self.wave_types,
          self.factions,
          self.locations;
      end,
      load = function(...)
        self.wave_frequency, 
          self.waves_left, 
          self.timer, 
          self.variance, 
          self.c_variance, 
          self.wave_types,
          self.factions,
          self.locations = ...;
      end,
      onWaveSpawn = function()
        return self.wave_subject;
      end,
      onInit = function(...)
        self.factions,
          self.locations,
          self.wave_frequency, 
          self.waves_left, 
          self.variance, 
          self.wave_types = ...;

        local f = self.wave_frequency*self.variance;
        self.c_variance =  f + 2*f*math.random();
      end,
      onDestroy = function()
      end,
      update = function(dtime)
        self.timer = self.timer + dtime;
        local freq = self.wave_frequency + self.c_variance;
        if(self.timer * freq >= 1) then
          self.timer = self.timer - 1/freq;
          local f = self.wave_frequency*self.variance;
          self.c_variance =  f + 2*f*math.random();
          self.waves_left = self.waves_left - 1;
          local fac = choose(unpack(self.factions));
          local locations = {};
          for i, v in pairs(self.locations) do
            if (not isIn(v,self.factions)) or (isIn(v,self.factions) and fac==v) then
              table.insert(locations,v);
            end
          end
          local location = choose(unpack(locations));
          local w_type = chooseA(unpack(self.wave_types));
          self.wave_subject:onNext(spawnWave(w_type,fac,location));
        end
      end
    }
  })
);

return {
  WaveSpawner = WaveSpawner
}