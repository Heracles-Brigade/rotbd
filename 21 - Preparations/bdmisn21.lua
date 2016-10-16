--Contributors:
    --Jarle Trollebø(Mario)


local mission = require('cmisnlib');
local globals = {
    keepGTsAtFullHealth = true
};



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
    otf = 'bdmisn2101.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
		AudioMessage("bdmisn2101.wav");
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
    end
});

local makeScavs = mission.Objective:define("make_scavs"):init({
    scav_count = 0,
    next = 'get_scrap',
    otf = 'bdmisn2102.otf'
}):setListeners({
    start = function(self)
        SetObjectiveOff(GetHandle("bzn64label_0005"));
        AddObjective(self.otf,"white");
    end,
    add_object = function(self,handle)
        if(GetClassLabel(handle) == "scavenger" and GetTeamNum(handle) == 1) then
            self.scav_count = self.scav_count + 1;
        end
        if(self.scav_count >= 2) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.scav_count;
    end,
    load = function(self,...)
        self.scav_count = ...;
    end
});

local getScrap = mission.Objective:define('get_scrap'):init({
    next = 'make_factory',
    otf = 'bdmisn2103.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        createWave("svfigh",{"bzn64path_000C","bzn64path_000D"},"bzn64path_0018");
    end,
    update = function(self)
        if(GetScrap(1) >= 20) then
            print("Scrap done!")
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
    otf = 'bdmisn2104.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        if(IsAlive(GetFactoryHandle(1))) then
            self:success();
        end
    end,
    add_object = function(self,handle)
        if(GetClassLabel(handle) == "factory" and GetTeamNum(handle) == 1) then
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
    tank_count = 0,
    bomber_count = 0,
    otf = 'bdmisn2105.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        createWave("svfigh",{"bzn64path_000C","bzn64path_000D"},"bzn64path_0018");
    end,
    add_object = function(self,handle)
        if(GetTeamNum(handle) == 1) then
            if(IsOdf(handle,"bvtank")) then
                self.tank_count = self.tank_count + 1;
            end
            if(IsOdf(handle,"bvhraz")) then
                self.bomber_count = self.bomber_count + 1;
            end
            if(self.bomber_count >= 1 and self.tank_count >= 3) then
                self:success();
            end
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end,
    save = function(self)
        return self.tank_count, self.bomber_count;
    end,
    load = function(self,...)
        self.tank_count, self.bomber_count = ...;
    end
});

local makeDefensive = mission.Objective:define("make_defensive"):init({
    next = 'destroy_soviet',
    otf = 'bdmisn2106.otf',
	--turr_count = 0
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
        createWave("svfigh",{"bzn64path_000C","bzn64path_000D"},"bzn64path_0018"); -- Original Script did nothing with these 2. Possibly sent to guard Scavs instead? -GBD
        createWave("svscav",{"bzn64path_000A","bzn64path_000B"});
		--Not really creating a wave, but spawns sbspow
		createWave("sbspow",{"bzn64path_000E","bzn64path_000F"});
    end,
    --add_object = function(self,handle)
	update = function(self)
       -- if(GetClassLabel(handle) == "turrettank" and GetTeamNum(handle) == 1) then
         --   self.turr_count = self.turr_count + 1;
        --    self:success();
        --end
        --if(self.turr_count >= 3) then
		if(globals.turr_count >= 3) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        mission.Objective:Start(self.next);
    end
	--[[
    save = function(self)
        return self.turr_count;
    end,
    load = function(self,...)
        self.turr_count = ...;
    end
	--]]
});

local destorySoviet = mission.Objective:define("destroy_soviet"):init({
    otf = 'bdmisn2107.otf',
    next = 'nsdf_attack',
    wait_timer = 45,
    wait_done = false
}):setListeners({
    start = function()
        createWave("svfigh",{"bzn64path_0010","bzn64path_0011"},"bzn64path_001A");
    end,
    update = function(self,dtime)
        if((not self.wait_done) and self.wait_timer <= 0) then
            AddObjective(self.otf,"white");
            globals.keepGTsAtFullHealth = false;
            SetObjectiveOn(globals.sb_turr_1);
            SetObjectiveOn(globals.sb_turr_2);
            SetObjectiveOn(GetRecyclerHandle(2));
            self.wait_done = true;
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
    otf = 'bdmisn2108.otf',
    next = 'make_comm',
    camOn = false,
    camTime = 10,
    targets = {},
    recycler_target = false
}):setListeners({
    start = function(self)
		AudioMessage("bdmisn2103.wav");
        AddObjective(self.otf,"whtie");
        local a,b,camTarget = createWave("avwalk",{"bzn64path_0013","bzn64path_0014","bzn64path_0015"},"bzn64path_001B");
        local c = createWave("avtank",{"bzn64path_0016"},"bzn64path_001B");
        local d = createWave("avtank",{"bzn64path_0004"},"bzn64path_0018");
        local f = createWave("svfigh",{"bzn64path_0008","bzn64path_0009"},"bzn64path_0019");
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
            CameraPath("bzn64path_0017",1000,1500,self.camTarget);
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
    otf = 'bdmisn2109.otf'
}):setListeners({
    start = function(self)
        AddObjective(self.otf,"white");
    end,
    add_object = function(self,handle)
        if(GetTeamNum(handle) == 1 and GetClassLabel(handle) == "commtower") then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective(self.otf,"green");
        SucceedMission(GetTime() + 5, "bdmisn21win.des");
    end
});

-- Lose conditions by GBD. No idea if i did this right, mission doesn't update otfs, or goto a next thing, it runs throughout the mission. (distance check until ordered to attack CCA base, and recy loss throughout entire mission.)
local loseRecy = mission.Objective:define("lose_recy"):init({
    next = '',
    otf = ''
}):setListeners({
    update = function(self)
        if(not IsAlive(GetRecyclerHandle(1))) then
            self:fail();
        end
    end,
	fail = function(self)
		FailMission(GetTime() + 5, "bdmisn21ls2.des");
	end
});
-- If you go too far.
local TooFarFromRecy = mission.Objective:define("toofarfrom_recy"):init({
    next = '',
    otf = ''
}):setListeners({
    update = function(self)
		if(globals.keepGTsAtFullHealth) then
			if IsAlive(GetRecyclerHandle(1)) and GetDistance(GetPlayerHandle(), GetRecyclerHandle(1)) > 700.0 then
				self:fail();
			end
		end
    end,
    fail = function(self)
        FailMission(GetTime() + 5, "bdmisn21ls1.des");
    end
});

-- AddObject Listener for Turrets? 
local turretCounter = mission.Objective:define("turret_counter"):init({
}):setListeners({
    add_object = function(self,handle)
        if(GetClassLabel(handle) == "turrettank" and GetTeamNum(handle) == 1) then
            globals.turr_count = globals.turr_count + 1;
        end
    end,
});

function Start()
    SetScrap(1,10);
    SetPilot(1,5);
    SetScrap(2,0);
    SetPilot(2,0);
        
    SetObjectiveOn(GetRecyclerHandle(1));
    SetObjectiveOn(GetHandle("bzn64label_0005"));
    SetObjectiveName(GetHandle("bzn64label_0005"),"Navpoint 4");
    --initial wave
    BuildObject("svrecy",2,"bzn64path_0003");
    globals.sb_turr_1 = BuildObject("sbtowe",2,"bzn64path_0001");
    globals.sb_turr_2 = BuildObject("sbtowe",2,"bzn64path_0002");
	globals.turr_count = 0;
    
    createWave("svfigh",{"bzn64path_0005","bzn64path_0006","bzn64path_0007"},"bzn64path_0019");

    local instance = deployRecy:start();
	local instance2 = loseRecy:start();
	local instance3 = TooFarFromRecy:start();
	local instance4 = turretCounter:start();
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
    return mission:Save(), globals;
end

function Load(misison_date,g)
    mission:Load(misison_date);
    globals = g;
end