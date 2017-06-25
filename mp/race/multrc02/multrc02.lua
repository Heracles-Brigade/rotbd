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

game(checkpointPaths,deathtraps);
