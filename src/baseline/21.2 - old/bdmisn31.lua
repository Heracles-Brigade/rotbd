--Combination of Grab The Scientists and Preparations
local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();

SetAIControl(2,false);

local function enemiesInRange(dist,place)
    local enemies_nearby = false;
    for v in ObjectsInRange(300,globals.nav[4]) do
        if(IsCraft(v) and GetTeamNum(v) == 2) then
            enemies_nearby = true;
        end
    end
    return enemies_nearby;
end

local function createWave(odf,path_list,follow)
    local ret = {};
    print("Spawning:" .. odf);
    for i,v in pairs(path_list) do
        local h = BuildObject(odf,2,v);
        if(follow) then
            Goto(h,follow);
        end
        table.insert(ret,h);
    end
    return unpack(ret);
end

local function spawnAtPath(odf,team,path)
    local handles = {};
    local current = GetPosition(path);
    local prev = nil;
    local c = 0;
    while current ~= prev do
        c = c + 1;
        table.insert(handles,BuildObject(odf,team,current));
        prev = current;
        current = GetPosition(path,c);
    end
    return handles;
end

--Define all objectives
local deployRecy = mission.Objective:define("deploy_recycler"):init({
    next = 'make_scavs',
    otf = 'bdmisn2201.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
		AudioMessage("bdmisn2201.wav");
    end,
    update = function(self)
        if(IsDeployed(GetRecyclerHandle(1))) then
            self:success();
            --mission.Objective:Start(self.next)
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        ClearObjectives();
        mission.Objective:Start(self.next);
		mission.Objective:Start('delayed_spawn');
    end
});

local DelayedSpawn = mission.Objective:define("delayed_spawn"):init({
    wait_timer = 120,
    wait_done = false
}):setListeners({
    update = function(self,dtime)
        if((not self.wait_done) and self.wait_timer <= 0) then
            createWave("svfigh",{"spawn_n1","spawn_n2"},"north_path");
            self.wait_done = true;
            self:success();
        end
        self.wait_timer = self.wait_timer - dtime;
    end,
    save = function(self)
        return self.wait_timer, self.wait_done;
    end,
    load = function(self,...)
        self.wait_timer, self.wait_done = ...;
    end
});

local makeScavs = mission.Objective:define("make_scavs"):init({
    next = 'get_scrap',
    otf = 'bdmisn2202.otf'
}):setListeners({
    start = function(self)
        SetObjectiveOff(GetHandle("nav4"));
        AddObjective(self.otf,"white");
    end,
    update = function(self)
        --Check if player has 2 scavengers
        if(tracker:gotOfClass("scavenger",2)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

local getScrap = mission.Objective:define('get_scrap'):init({
    next = 'make_factory',
    otf = 'bdmisn2203.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
    end,
    update = function(self)
        if(GetScrap(1) >= 20) then
            self:success();
        end
    end,
    success = function(self)
        ClearObjectives();
        mission.Objective:Start(self.next);
    end
});

local makeFactory = mission.Objective:define("make_factory"):init({
    next = 'make_offensive',
    otf = 'bdmisn2204.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
    end,
    update = function(self)
        if(tracker:gotOfClass("factory",1)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

local makeOffensive = mission.Objective:define("make_offensive"):init({
    next = 'make_defensive',
    otf = 'bdmisn2205.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        self.tracker = mission.UnitTracker:new();
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path");
    end,
    update = function(self)
        --Check if got 3 more tanks + 1 bomber, since mission start
        if(self.tracker:gotOfOdf("bvtank1",3) and self.tracker:gotOfOdf("bvhraz",1)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.tracker:save();
    end,
    load = function(self,tdata)
        self.tracker = mission.UnitTracker:Load(tdata);
    end,
    finish = function(self)
        self.tracker:kill();
    end
});

local makeDefensive = mission.Objective:define("make_defensive"):init({
    next = 'destroy_soviet',
    otf = 'bdmisn2206.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        createWave("svfigh",{"spawn_w4","spawn_w5"},"west_path"); -- Original Script did nothing with these 2. Possibly sent to guard Scavs instead? -GBD
        createWave("svscav",{"spawn_w2","spawn_w3"});
		--Not really creating a wave, but spawns sbspow
		createWave("sbspow",{"spawn_sbspow1","spawn_sbspow2"});
    end,
    update = function(self)
        if(tracker:gotOfClass("turrettank",3)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
});

local destorySoviet = mission.Objective:define("destroy_soviet"):init({
    otf = 'bdmisn2207.otf',
    next = 'nsdf_attack',
    wait_timer = 45,
    wait_done = false
}):setListeners({
    start = function()
        createWave("svfigh",{"spawn_e1","spawn_e2"},"east_path");
    end,
    update = function(self,dtime)
        if((not self.wait_done) and self.wait_timer <= 0) then
            AddObjective(self.otf,"white");
            SetObjectiveOn(globals.sb_turr_1);
            SetObjectiveOn(globals.sb_turr_2);
            SetObjectiveOn(GetRecyclerHandle(2));
            self.wait_done = true;
            mission:getObjective("toofarfrom_recy"):success();
        else
            if(not(IsAlive(globals.sb_turr_1) or IsAlive(globals.sb_turr_2))) then
                self:success();
            end
        end
        
        self.wait_timer = self.wait_timer - dtime;
    end,
    success = function(self)
        SetObjectiveOff(GetRecyclerHandle(2));
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.wait_timer, self.wait_done;
    end,
    load = function(self,...)
        self.wait_timer, self.wait_done = ...;
    end
});

local nsdfAttack = mission.Objective:define("nsdf_attack"):init({
    otf = 'bdmisn2208.otf',
    next = 'make_comm',
    camOn = false,
    camTime = 10,
    targets = {},
    recycler_target = false
}):setListeners({
    start = function(self)
		ClearObjectives();
		AudioMessage("bdmisn2203.wav");
        AddObjective(self.otf,"white");
        local a,b,camTarget = createWave("avwalk",{"spawn_avwalk1","spawn_avwalk2","spawn_avwalk3"},"nsdf_path");
        local c = createWave("avtank",{"spawn_tank1"},"nsdf_path");
        local d = createWave("avtank",{"spawn_w1"},"west_path");
        local f = createWave("svfigh",{"spawn_n4","spawn_n5"},"north_path");
        self.camTarget = camTarget;
        self.camOn = CameraReady();
        self.targets = {
            [a]=true,
            [b]=true,
            [camTarget]=true,
            [c]=true,
            [d]=true
        };
        for i,v in pairs(self.targets) do
            SetObjectiveOn(i);
        end
    end,
    update = function(self,dtime)
        if(self.camOn) then
            CameraPath("camera_nsdf",1000,1500,self.camTarget);
            self.camTime = self.camTime - dtime;
            if(self.camTime <= 0 or CameraCancelled()) then
                self.camOn = not CameraFinish();
            end
        end
        if(self.recycler_target and not IsAlive(GetRecyclerHandle(2))) then
            self:success();
        end        
    end,
    delete_object = function(self,handle)
        if(not self.recycler_target) then
            if(self.targets[handle]) then
                self.targets[handle] = false;
            end
            local anyleft = false;
            for i,v in pairs(self.targets) do
                anyleft = anyleft or v;
            end
            if(not anyleft) then
                self.recycler_target = true;
                SetObjectiveOn(GetRecyclerHandle(2));
            end
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.camTarget,self.camOn,self.camTime,self.targets,self.recycler_target;
    end,
    load = function(self,...)
        self.camTarget, self.camOn,self.camTime,self.targets ,self.recycler_target= ...;
    end
});

local makeComm = mission.Objective:define("make_comm"):init({
    otf = 'bdmisn2209.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
    end,
    update = function(self)
        if(tracker:gotOfClass("commtower",1)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        SucceedMission(GetTime() + 5, "bdmisn22wn.des");
    end
});

-- Lose conditions by GBD. No idea if i did this right, mission doesn't update otfs, or goto a next thing, it runs throughout the mission. (distance check until ordered to attack CCA base, and recy loss throughout entire mission.)
local loseRecy = mission.Objective:define("lose_recy"):setListeners({
    update = function(self)
        if(not IsAlive(GetRecyclerHandle(1))) then
            self:fail();
        end
    end,
	fail = function(self)
		FailMission(GetTime() + 5, "bdmisn22l2.des");
	end
});
-- If you go too far.
local TooFarFromRecy = mission.Objective:define("toofarfrom_recy"):setListeners({
    update = function(self)
        if not globals.keepGTsAtFullHealth then -- GBD 12/3/16. I thought this used to deactivate on this bool before, can't find it. Now self kill this function when this becomes false. (triggered in Destroy_Soviet)
			self:finish();
		end
        if IsAlive(GetRecyclerHandle(1)) and GetDistance(GetPlayerHandle(), GetRecyclerHandle(1)) > 700.0 then
            print(self.alive);
            self:fail();
        end
    end,
    fail = function(self)
        FailMission(GetTime() + 5, "bdmisn22l1.des");
    end,
    finish = function(self)
        globals.keepGTsAtFullHealth = false;    
    end
});

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
    t1=3,
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
    update = function(self,dtime)
        if(self.power1_4 and checkDead(self.handles)) then
            self.power1_4 = false;
            UpdateObjective(self.otf1,"green");
			AudioMessage("bdmisn2103.wav");
        end
        if(not (self.power1_4 or self.power5_8init)) then
            SetObjectiveOff(globals.nav[2]);
            SetObjectiveOn(globals.nav[3]);
            AddObjective(self.otf2,"white");
            self.handles = {};
            for i,v in pairs(self.target_l2) do
                self.handles[i] = GetHandle(v);
            end
            self.power5_8init = true;
        elseif(self.power5_8init) then
            self.t1 = self.t1 - dtime;
            if(checkDead(self.handles) and self.t1 <= 0) then
                self:success();
            end
        end
    end,
    save = function(self)
        return self.handles,self.power1_4,self.power5_8init,self.t1;
    end,
    load = function(self,...)
        self.handles,self.power1_4,self.power5_8init,self.t1 = ...;
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
        SetMaxHealth(self.tug, 0); -- This is invincible.
        SetMaxHealth(self.apc, 0); -- This is invincible.
        SetPilotClass(self.tug, ""); -- This is invincible.
        SetPilotClass(self.apc, ""); -- This is invincible.
        Follow(self.apc,self.tug);
        Pickup(self.tug,globals.relic);
        print("Pickup",self.tug,globals.relic);
        Goto(BuildObject("avtank",2,"spawn_tank1"),globals.comm);
        Goto(BuildObject("avtank",2,"spawn_tank2"),globals.comm);
        Goto(BuildObject("avtank",2,"spawn_tank3"),globals.comm);
        
        for i,v in pairs(spawnAtPath("bvtank1",1,"extra_tanks")) do
            Follow(v,GetPlayerHandle(),0);
        end   
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
        --SucceedMission(GetTime()+5,"bdmisn21wn.des");
        --Start 22 - Preparations
        mission.Objective:Start("intermediate");
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
    end
});

local intermediate = mission.Objective:define("intermediate"):init({
    timer = 90,
    recyspawned = false,
    enemiesAtStart = false
}):setListeners({
    init = function(self)
        self.nav = GetHandle("nav4");
    end,
    start = function(self)
        ClearObjectives();
        --Only show if area is not cleared
        if(enemiesInRange(270,globals.nav[4])) then
            AddObjective("bdmisn311.otf","white");
        else
            self.enemiesAtStart = true;
            AddObjective("bdmisn311b.otf","yellow");
        end
    end,
    update = function(self,dtime)
        --Check for enemies nearby?
        self.timer = self.timer - dtime;
        --Check for enemies @ nav4
        if((not self.recyspawned) and  (self.timer <= 0 or (not enemiesInRange(270,globals.nav[4]))) ) then
            self.recyspawned = true;
            local recy = BuildObject("bvrecy22",1,"recy_spawn");
            local e1 = BuildObject("bvtank1",1,GetPositionNear(GetPosition("recy_spawn"),20,100));
            local e2 = BuildObject("bvtank1",1,GetPositionNear(GetPosition("recy_spawn"),20,100));
            Defend2(e1,recy,0);
            Defend2(e2,recy,0);
            --Make recycler follow path
            Goto(recy,self.nav,0);
            self.recy = recy;
            
            SetObjectiveOn(recy);
            --self:success();
        end
        if(self.recy and IsWithin(self.recy,self.nav,200)) then
            self:success();
        end
    end,
    save = function(self)
        return self.timer, self.recy, self.recyspawned;
    end,
    load = function(self,...)
        self.timer, self.recy, self.recyspawned = ...;
    end,
    success = function(self)
        if(self.enemiesAtStart) then
            UpdateObjective("bdmisn311.otf","green");
        end
        globals.keepGTsAtFullHealth = true;
        --Spawn in recycler
        --Recycler escort

        AddScrap(1,20);
        AddPilot(1,10);
        SetScrap(2,0);
        SetPilot(2,0);
        SetObjectiveOn(self.nav);
        --initial wave
        BuildObject("svrecy",2,"spawn_svrecy");
        globals.sb_turr_1 = BuildObject("sbtowe",2,"spawn_sbtowe1");
        globals.sb_turr_2 = BuildObject("sbtowe",2,"spawn_sbtowe2");
        --Start wave after a delay?
        createWave("svfigh",{"spawn_n1","spawn_n2","spawn_n3"},"north_path");
        local instance = deployRecy:start();
        local instance2 = loseRecy:start();
        local instance3 = TooFarFromRecy:start();
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
        SetObjectiveName(GetHandle("nav" .. i),"Navpoint " .. i);
        SetMaxHealth(v,0);
    end
	AudioMessage("bdmisn2101.wav");
 
    local instance = cinematic:start();
    local instance2 = patrolControl:start();
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
    return mission:Save(), globals, tracker:save();
end

function Load(misison_date,g,tdata)
    mission:Load(misison_date);
    globals = g;
    tracker = mission.UnitTracker:Load(tdata);
end