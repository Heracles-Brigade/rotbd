--Contributors:
    --Jarle Trollebø(Mario)
    --General BlackDragon

local mission = require 'cmisnlib';



local globals = {}

local function checkDead(handles)
    for i,v in pairs(handles) do
        if(IsAlive(v)) then
            return false;
        end
    end
    return true;
end

local cinematic = mission.Objective:define("cinematic"):init({
    camOn = false,
    camTime = 20,
    next = 'checkCommand'
}):setListeners({
    start = function(self)
        self.camOn = CameraReady();
    end,
    update = function(self,dtime)
        if(self.camOn) then
            CameraPath("opening_cin", 2000, 1000, globals.cafe)
            if(self.camTime <= 0 or CameraCancelled()) then
                self.camOn = CameraFinish();
                self:success();
            end
            self.camTime = self.camTime - dtime;
        end
    end,
    save = function(self)
        return self.camOn,self.camTime;
    end,
    load = function(self,...)
        self.camOn,self.camTime = ...;
    end,
    success = function(self)
        mission.Objective:Start(self.next);
    end
});

local checkCommand = mission.Objective:define("checkCommand"):init({
    otf = 'bdmisn211.otf',
    next = 'destorySolar'
}):setListeners({
    start = function(self)
        SetObjectiveOn(globals.nav[1]);
        AddObjective(self.otf,"white");
        self.command = GetHandle("command");
        print(self.otf,self.command);
    end,
    update = function(self)
        if(GetDistance(GetPlayerHandle(), self.command) < 50.0) then
			AudioMessage("bdmisn2102.wav");
            self:success();
        elseif(not IsAlive(self.command)) then
            self:fail();
        end
    end,
    load = function(self,...)
        self.command = GetHandle("command");
    end,
    success = function(self)
        SetObjectiveOff(globals.nav[1]);
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    fail = function(self)
        UpdateObjective(self.otf,"red");
        FailMission(GetTime() + 5,"bdmisn21ls.des");
    end
});

local destroySolar = mission.Objective:define("destorySolar"):init({
    otf1 = 'bdmisn212.otf',
    otf2 = 'bdmisn213.otf',
    next = 'destroyComm',
    target_l1 = {"power1_1","power1_2","power1_3","power1_4"},
    target_l2 = {"power2_1","power2_2","power2_3","power2_4"},
    power1_4 = true,
    power5_8init = false
}):setListeners({
    start = function(self)
        SetObjectiveOn(globals.nav[2]);
        AddObjective(self.otf1,"white");
        self.handles = {};
        for i,v in pairs(self.target_l1) do
            self.handles[i] = GetHandle(v)
        end
    end,
    update = function(self)
        if(self.power1_4 and checkDead(self.handles)) then
            self.power1_4 = false;
            UpdateObjective(self.otf1,"green");
			AudioMessage("bdmisn2103.wav");
        elseif(not (self.power1_4 or self.power5_8init)) then
            SetObjectiveOff(globals.nav[2]);
            SetObjectiveOn(globals.nav[3]);
            AddObjective(self.otf2,"white");
            self.handles = {};
            for i,v in pairs(self.target_l2) do
                self.handles[i] = GetHandle(v);
            end
            self.power5_8init = true;
        elseif(checkDead(self.handles)) then
            self:success();
        end
    end,
    save = function(self)
        return self.handles,self.power1_4,self.power5_8init
    end,
    load = function(self,...)
        self.handles,self.power1_4,self.power5_8init = ...;
    end,
    success = function(self)
        SetObjectiveOff(globals.nav[3]);
        UpdateObjective(self.otf2,"green");
        mission.Objective:Start(self.next);
    end
});



local destroyComm = mission.Objective:define("destroyComm"):init({
    otf = 'bdmisn214.otf',
    otf2 = 'bdmisn215.otf',
    camOn = false,
    gotRelic = false
}):setListeners({
    start = function(self)
		AudioMessage("bdmisn2104.wav");
        --SetObjectiveOn(globals.nav[4]);
        SetObjectiveOn(globals.comm);
        AddObjective(self.otf,"white");
        AddObjective(self.otf2,"white");
        self.camOn = CameraReady();
        self.apc = BuildObject("avapc",2,"spawn_apc");
        self.tug = BuildObject("avhaul",2,"spawn_tug");
        SetMaxHealth(self.tug,0);
        Follow(self.apc,self.tug);
        Pickup(self.tug,globals.relic);
        print("Pickup",self.tug,globals.relic);
        Goto(BuildObject("avtank",2,"spawn_tank1"),globals.comm);
        Goto(BuildObject("avtank",2,"spawn_tank2"),globals.comm);
        Goto(BuildObject("avtank",2,"spawn_tank3"),globals.comm);
        
    end,
    update = function(self)
        if(self.camOn) then
            if (CameraPath("convoy_cin",2000,2000, globals.cafe) or CameraCancelled()) then
                self.camOn = not CameraFinish();
            end
        end
        if((not self.gotRelic) and GetTug(globals.relic) == self.tug) then
            Goto(self.tug,"spawn_svfigh1");
            self.gotRelic = true;
        elseif(IsValid(self.tug) and GetDistance(self.tug, "spawn_svfigh1") < 25.0) then
            RemoveObject(globals.relic);
            RemoveObject(self.tug);
            RemoveObject(self.apc);
        end
        if(not IsAlive(globals.comm)) then
            self:success();
        end
    end,
    save = function(self)
        return self.camOn, self.apc, self.tug;
    end,
    load = function(self,...)
        self.camOn, self.apc, self.tug = ...;
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        UpdateObjective(self.otf2,"green");
        SucceedMission(GetTime()+5,"bdmisn21wn.des");
    end
});

local patrolControl = mission.Objective:define("destoryNSDF"):init({
    spawned = false
}):setListeners({
    update = function(self)
        if( not self.spawned and checkDead(globals.patrolUnits) ) then
            local reinforcements = {
                BuildObject("svfigh", 2, "spawn_svfigh1"),
                BuildObject("svfigh", 2, "spawn_svfigh2"),
                BuildObject("svrckt", 2, "spawn_svrckt1"),
                BuildObject("svrckt", 2, "spawn_svrckt2"),
                BuildObject("svhraz", 2, "spawn_svhraz")
            };
            -- Send the reinforcements to Nav 4.
            for i,v in pairs(reinforcements) do
                Goto(v, globals.nav[4]);
            end
            print("Spawning reinforcements");
            self.spawned = true;
        end
    end,
    save = function(self)
        return self.spawned;
    end,
    load = function(self,...)
        self.spawned = ...;
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
    end
});
function Start()
    globals.nav = {
        GetHandle("nav1"),
        GetHandle("nav2"),
        GetHandle("nav3"),
        GetHandle("nav4"),
    };
    globals.cafe = GetHandle("research");
    globals.comm = GetHandle("commtower");
    globals.relic = GetHandle("relic");
    SetMaxHealth(globals.relic,0);
    globals.patrolUnits = {
        GetHandle("patrol3_1"),
        GetHandle("patrol3_2")
    };
    for i,v in pairs(globals.nav) do
        SetObjectiveName(v,"Nav " .. i);
        SetMaxHealth(v,0);
    end
	AudioMessage("bdmisn2101.wav");
 
    local instance = cinematic:start();
    local instance2 = patrolControl :start();
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
    return mission:Save(), globals;
end

function Load(misison_date,g)
    mission:Load(misison_date);
    globals = g;
end