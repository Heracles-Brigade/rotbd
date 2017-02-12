
local p = require("scr");
require("luaio");


local haswin = false;

local template = "Mission ran for: %d seconds\nRandom number of the day: %d";

function beforeWin()
  local f = io.open("addon/win.des","w");
  f:write(template:format(GetTime(),math.random()*255));
  f:close();
end



function Update()
  if((not haswin) and GetTime() > 10) then
    beforeWin();
    SucceedMission(2.0,"win.des");
    haswin = true;
  end
end

local fname = ...;

function Start()
  print(unpack(p));
end