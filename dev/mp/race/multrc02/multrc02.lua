local game = require("mp_race");
local checkpointPaths = {};

for i=1, 18 do
  table.insert(checkpointPaths,{
    name = ("check_point%d"):format(i);
    paths = {("p_check%d"):format((i%18)+1)}
  });
end
local deathtraps = {};
for i=1, 8 do
  table.insert(deathtraps,("death_area%d"):format(i));
end

local weaponPickups = {};
for i=1, 5 do
  table.insert(weaponPickups,("wpn_pickup_%d"):format(i));
end

game(checkpointPaths,deathtraps,weaponPickups,{"lobby_pickup1","lobby_pickup2","lobby_pickup3","lobby_pickup4"});
