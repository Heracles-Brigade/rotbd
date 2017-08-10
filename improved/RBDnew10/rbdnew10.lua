
require("bz_logging");

local mission = require("cmisnlib");

local audio = {
  intro = "rbd1001.wav",
  furies = "rbd1002.wav",
  evacuate = "rbd1003.wav",
  shaw = "rbd1004.wav"
};


function Save()
  return mission:Save();
end

function Load(...)	
  mission:Load(...);
end

function Start()
  mission:Start();
end

function AddObject(h)
  mission:AddObject(h);
end

function DeleteObject(h)
  mission:DeleteObject(h);
end

function Update(dtime)
  mission:Update(dtime);
end

-- Lets find a good target?
function FindAITarget()
  -- Pick a target. Attack silos or base.
  if math.random(1, 2) == 1 then
    if IsAlive(M.Silo1) then
      return M.Silo1;
    elseif IsAlive(Silo2) then
      return M.Silo2;
    elseif IsAlive(M.Silo3) then
      return M.Silo3;
    end
  else
    if IsAlive(M.CommTower) then
      return M.CommTower;
    elseif IsAlive(M.Recycler) then
      return M.Recycler;
    elseif IsAlive(M.Constructor) then
      return M.Constructor;
    end
  end
end
