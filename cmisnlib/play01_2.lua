local mission = require('cmisnlib');

--Define all objectives
local objective1 = mission.Objective:define('first_objective'):init({
    otf = 'p_obj1.otf',
    time = 20,
    random_var = 1,
    next = 'second_objective'
}):setListeners({
    start = function(self)
        print(message); --will print 'This is sent to objective1.on("start")'
        AddObjective(objective.otf,'white',8);
        objective.random_var = 5; --testing saving
    end,
    update = function(self)
       objective.time = objective.time - dtime;
        if(objective.time <= 0) then
            objective:success();
        end
    end,
    success = function(self)
        UpdateObjective(objective.otf,'green',8);
        print("Success!");
        --Start objective2
        mission.Objective:Start(objective.next);
        --^Shorthand for version:
        --mission.Objective:getObjective(objective.next):start();
    end,
    save = function(self)
        --Runs when the objective is being saved
        --Works just like Save does
        print('Saving objective1!')
        return objective.objective_otf, objective.time, objective.random_var;
    end,
    load = function(self)
        --Runs when the objective is being loaded
        --Works just like Load does
        objective.objective_otf = a;
        objective.time = b;
        objective.random_var = c;
        print("After load, objective.random_var should be 5");
        if(objective.random_var ~= 5) then
            error("objective.random_var was not saved properly",objective.random_var);
        end
    end
});

--Objective 2
local objective2 = mission.Objective:define('second_objective'):init({
    time = 20,
    otf = "p_obj2.otf"
}):setListeners({
    start = function(objective)
        --First thing that runs when the objective starts
        objective.target = GetRecyclerHandle(1);
        AddObjective(objective.otf,'white',8);
        StartCockpitTimer(objective2.time,10,5);
    end,
    update = function(objective,dtime)
        --Runs while the objective is still going
        objective.time = objective.time - dtime;
        if(not IsAlive(objective.target)) then
            objective:success();
        elseif(objective.time < 0) then
            objective:fail();
        end
    end,
    success = function(objective)
        --Will run once if the objective succeeds
        UpdateObjective(objective.otf,'green',8);
    end,
    fail = function(objective)
        --Will run once if the objective fails 
        UpdateObjective(objective.otf,'red',8);
    end,
    finish = function(objective)
        --Will run once when the objective finishes(succeeds or fails)
        --Remove the cockpit timer
        StopCockpitTimer();
        HideCockpitTimer();
    end,
    save = function(objective)
        return objective.otf, objective.time, objective.target;
    end,
    load = function(objective,a,b,c)
        objective.otf = a;
        objective.time = b;
        objective.target = c;
    end
});

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