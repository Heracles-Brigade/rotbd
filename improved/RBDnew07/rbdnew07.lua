
local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();

--Objective definitions
--Generic get relic Objective
local getRelic = mission.Objective:define("reteriveRelic"):createTasks(
  "getRelics"
):setListeners({
  init = function()
    self.otfs = {};
    self.relics = {};
    self.baseLocation = nil;
    self.ccaLocation = nil;
    self.nsdfLocation = nil;
  end,
  start = function(self)
    AddObjective(self.otf[1],"white");
    AddObjective(self.otf[2],"white");
  end,
  update = function(self)
    
  end,
  success = function(self)

  end,
  fail = function(self)
    FailMission(GetTime()+5);
  end
});

--Relic objective manager
local relicManager = mission.Objective:define("reteriveRelic"):setListeners