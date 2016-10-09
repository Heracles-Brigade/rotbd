local mission = require('cmisnlib');

--Define all objectives
local objective1 = mission.Objective:define('first_objective');
local objective2 = mission.Objective:define('second_objective');

--Objective 1
objective1.objective_otf = "p_obj1.otf";
objective1.time = 20;
objective1.random_var = 1;
objective1.next = 'second_objective';

objective1:on('start',function(objective,message)
    print(message); --will print 'This is sent to objective1.on("start")'
    AddObjective(objective.objective_otf,'white',8);
    objective.random_var = 5; --testing saving
end);

objective1:on('update',function(objective,dtime)
    objective.time = objective.time - dtime;
    if(objective.time <= 0) then
        objective:success();
    end
    
end);

objective1:on('success',function(objective)
    UpdateObjective(objective.objective_otf,'green',8);
    print("Success!");
    --Start objective2
    mission.Objective:Start(objective.next);
    --^Shorthand for version:
    --mission.Objective:getObjective(objective.next):start();
    
end);

objective1:on('save',function(objective)
    --Runs when the objective is being saved
    --Works just like Save does
    print('Saving objective1!')
    return objective.objective_otf, objective.time, objective.random_var;
end);

objective1:on('load',function(objective,a,b,c)
    --Runs when the objective is being loaded
    --Works just like Load does
    objective.objective_otf = a;
    objective.time = b;
    objective.random_var = c;
    print("After load, objective.random_var should be 5");
    if(objective.random_var ~= 5) then
        error("objective.random_var was not saved properly",objective.random_var);
    end
end);

--Objective 2
objective2.time = 20;
objective2.otf = "p_obj2.otf";

objective2:on('start',function(objective)
    --First thing that runs when the objective starts
    objective.target = GetRecyclerHandle(1);
    AddObjective(objective.otf,'white',8);
    StartCockpitTimer(objective2.time,10,5);
end);

objective2:on('update',function(objective,dtime)
    --Runs while the objective is still going
    objective.time = objective.time - dtime;
    if(not IsAlive(objective.target)) then
        objective:success();
    elseif(objective.time < 0) then
        objective:fail();
    end
end);

objective2:on('success',function(objective)
    --Will run once if the objective succeeds
    UpdateObjective(objective.otf,'green',8);
end);

objective2:on('fail',function(objective)
    --Will run once if the objective fails 
    UpdateObjective(objective.otf,'red',8);
end);

objective2:on('finish',function(objective)
    --Will run once when the objective finishes(succeeds or fails)
    --Remove the cockpit timer
    StopCockpitTimer();
    HideCockpitTimer();
end);

objective2:on('save',function(objective)
    return objective.otf, objective.time, objective.target;
end);

objective2:on('load',function(objective,a,b,c)
    objective.otf = a;
    objective.time = b;
    objective.target = c;
end);

function Start()
    local instance = objective1:start('This is sent to objective1.on("start")');
end

function Update(dtime)
    mission:Update(dtime);
end

function CreateObject(handle)
    mission:CreateObject(handle);
end

function AddObject(handle)
    mission:AddObject(handle);
end

function DeleteObject(handle)
    mission:DeleteObject(handle);
end

function Save()
    return mission:Save();
end

function Load(misison_date)
    mission:Load(misison_date);
end