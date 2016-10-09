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
        AddObjective(self.otf,'white',8);
        self.random_var = 5; --testing saving
    end,
    update = function(self)
       self.time = self.time - dtime;
        if(self.time <= 0) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,'green',8);
        print("Success!");
        --Start objective2
        mission.Objective:Start(self.next);
        --^Shorthand for version:
        --mission.Objective:getObjective(self.next):start();
    end,
    save = function(self)
        --Runs when the objective is being saved
        --Works just like Save does
        print('Saving objective1!')
        return self.objective_otf, self.time, self.random_var;
    end,
    load = function(self)
        --Runs when the objective is being loaded
        --Works just like Load does
        self.objective_otf = a;
        self.time = b;
        self.random_var = c;
        print("After load, self.random_var should be 5");
        if(self.random_var ~= 5) then
            error("self.random_var was not saved properly",self.random_var);
        end
    end
});

--Objective 2
local objective2 = mission.Objective:define('second_objective'):init({
    time = 20,
    otf = "p_obj2.otf"
}):setListeners({
    start = function(self)
        --First thing that runs when the objective starts
        self.target = GetRecyclerHandle(1);
        AddObjective(self.otf,'white',8);
        StartCockpitTimer(self.time,10,5);
    end,
    update = function(self,dtime)
        --Runs while the objective is still going
        self.time = self.time - dtime;
        if(not IsAlive(self.target)) then
            self:success();
        elseif(objective.time < 0) then
            self:fail();
        end
    end,
    success = function(self)
        --Will run once if the objective succeeds
        UpdateObjective(self.otf,'green',8);
    end,
    fail = function(self)
        --Will run once if the objective fails 
        UpdateObjective(self.otf,'red',8);
    end,
    finish = function(self)
        --Will run once when the objective finishes(succeeds or fails)
        --Remove the cockpit timer
        StopCockpitTimer();
        HideCockpitTimer();
    end,
    save = function(self)
        return self.otf, self.time, self.target;
    end,
    load = function(self,a,b,c)
        self.otf = a;
        self.time = b;
        self.target = c;
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