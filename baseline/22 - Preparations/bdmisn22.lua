--Contributors:
    --Jarle Trollebø(Mario)
	--General BlackDragon

require("bz_logging");
local mission = require('cmisnlib');
local globals = {
    keepGTsAtFullHealth = true
};
local tracker = mission.UnitTracker:new();


SetAIControl(2,false);


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
        if(self.tracker:gotOfOdf("bvtank",3) and self.tracker:gotOfOdf("bvhraz",1)) then
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
            globals.keepGTsAtFullHealth = false;
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
        AddObjective(self.otf,"whtie");
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
            if(self.camTime <= 0) then
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
			self:kill();
		end
        if IsAlive(GetRecyclerHandle(1)) and GetDistance(GetPlayerHandle(), GetRecyclerHandle(1)) > 700.0 then
            print(self.alive);
            self:fail();
        end
    end,
    fail = function(self)
        FailMission(GetTime() + 5, "bdmisn22l1.des");
    end
});

-- AddObject Listener for Turrets? 

function Start()
    SetScrap(1,20);
    SetPilot(1,10);
    SetScrap(2,0);
    SetPilot(2,0);
        
    SetObjectiveOn(GetRecyclerHandle(1));
    SetObjectiveOn(GetHandle("nav4"));
	for i = 1, 4 do
		SetObjectiveName(GetHandle("nav" .. i),"Navpoint " .. i);
	end
    --initial wave
    BuildObject("svrecy",2,"spawn_svrecy");
    globals.sb_turr_1 = BuildObject("sbtowe",2,"spawn_sbtowe1");
    globals.sb_turr_2 = BuildObject("sbtowe",2,"spawn_sbtowe2");

    createWave("svfigh",{"spawn_n1","spawn_n2","spawn_n3"},"north_path");

    local instance = deployRecy:start();
	local instance2 = loseRecy:start();
	local instance3 = TooFarFromRecy:start();
end

function Update(dtime)
    if(globals.keepGTsAtFullHealth) then
        SetCurHealth(globals.sb_turr_1,GetMaxHealth(globals.sb_turr_1));
        SetCurHealth(globals.sb_turr_2,GetMaxHealth(globals.sb_turr_2));
    end
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