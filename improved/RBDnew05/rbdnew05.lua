--Combination of The Last Stand and Evacuate Venus
--Contributors:
    --Jarle Trollebø(Mario)
    --General BlackDragon

--[[
    mission.Objective:define("name"):init({

    }):setListeners({
        start = function(self)
        end,
        update = function(self,dtime)
        end,
        save = function(self,save)
        end,
        load = function(self,save,...)
        end,
        success = function(self)
        end
    });
    mission.Objective:Start
]]
local miss25setup;
local miss26setup;

local mission = require('cmisnlib');
local globals = {};
local tracker = mission.UnitTracker:new();

SetAIControl(2,false);

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


local function checkDead(handles)
    for i,v in pairs(handles) do
        if(IsAlive(v)) then
            return false;
        end
    end
    return true;
end

local function checkAnyDead(handles)
    for i,v in pairs(handles) do
        if(not IsAlive(v)) then
            return true;
        end
    end
    return false;
end
--Define all objectives for mission 25
--Second wave:
local secondWave = mission.Objective:define("secondWave"):setListeners({
    start = function(self)
        self.time = 135
    end,
    update = function(self,dtime)
        self.time = self.time - dtime;
        if(self.time <= 0) then
            self:success();
        end
    end,
    save = function(self)
        return self.time;
    end,
    load = function(self,...)
        self.time = ...;
    end,
    success = function(self)
        --Spawn second wave
        for i = 1, 4 do
			Attack(BuildObject("svfigh", 2, "patrol_path"), GetHandle("commtower"));
		end
        for i = 1, 2 do
			Attack(BuildObject("svtank", 2, "patrol_path"), GetHandle("commtower"));
		end
    end
});
--Lose condition:
local defendComm = mission.Objective:define("defendComm"):setListeners({
    init = function(self)
        self.comm = GetHandle("commtower");
    end,
    start = function(self)
        AddObjective("rbdnew3501.otf","white");
        AddObjective("rbdnew3502.otf","white");
    end,
    update = function(self,dtime)
        if(not IsAlive(self.comm)) then
            self:fail();
        end
    end,
    save = function(self)
    end,
    load = function(self,...)
    end,
    fail = function(self)
    	UpdateObjective("rbdnew3501.otf","red");
        FailMission(GetTime()+5.0, "bdmisn25l1.des");
        --Lose mission
    end
});

local destorySovietComm = mission.Objective:define("destorySovietComm"):setListeners({
    init = function(self)
        self.scomm = GetHandle("sovietcomm");
    end,
    start = function(self)
        self.spawnDef = false;
        self.scc = false;
        self.t1 = 30;
    end,
    update = function(self,dtime)
        if( (not self.spawnDef) and GetWhoShotMe(self.scomm) ~= nil) then
            self.spawnDef = true;
            self.ktargets = {
                BuildObject("svfigh", 2, "defense_spawn"),
                BuildObject("svfigh", 2, "defense_spawn"),
				BuildObject("svtank", 2, "defense_spawn"),
                BuildObject("svltnk", 2, "defense_spawn")
            };
            for i,v in pairs(self.ktargets) do
                Patrol(v,"defense_path");
            end
        end
        if( (not IsAlive(self.scomm) ) and not (self.scc)) then
            UpdateObjective("rbdnew3502.otf","green");
            self.scc = true;
        end
        if(self.scc) then
            self.t1 = self.t1 - dtime;
            if( (self.t1 <= 0) or checkDead(self.ktargets or {}) ) then
                self:success();
            end
        end
    end,
    save = function(self,...)
        return self.spawnDef,self.ktargets,self.t1,self.scc;
    end,
    load = function(self,...)
        self.spawnDef,self.ktargets,self.t1,self.scc = ...;
    end,
    success = function(self)
        --Start mission 26
        --End defend mission?
        --You don't have to defend the comm tower anymore after this
        mission:getObjective("defendComm"):success();
        --Base will be obliterated so don't send any more force
        local sw = mission:getObjective("secondWave");
        if(sw) then
            sw:success();
        end
        mission.Objective:Start("baseDestroyCin",self.ktargets);
    end
});
--Cinematic of attack on base
local baseDestroyCin = mission.Objective:define("baseDestroyCin"):setListeners({
    init = function(self)
        self.targets = {
            "turr1",
            "turr2",
            "commtower",
            "recycler"
        };
    end,
    start = function(self)
        --Spawns attackers in a formation
        self.cam = false;
        self.camstage = 0;
        self.t1 = 7;
        self.stageTimers = {
            15,
            10,
            5,
            10
        };
        self.minwait = self.t1 + 15 + 10 + 10 + 6 + 10;
        self.waitleft = self.minwait;
        self.attackers = mission.spawnInFormation2({
            "1 2 3 2 3 2 1",
            "1 3 1 3 1 3 1"
        },"25cin_attack",{"svfigh","svrckt","svltnk"},2,20);
    end,
    update = function(self,dtime)
        for i,v in pairs(self.attackers) do
            local task = GetCurrentCommand(v) ~= AiCommand["NONE"];
            if(not task) then
                for i2,v2 in pairs(self.targets) do
                    if( i<=(i2*3) and (not task) ) then
                        local t = GetHandle(v2);
                        if(IsAlive(t)) then
                            Attack(v,t);
                            task = true;
                        end
                    end
                end
            end
            if(not task) then
                Goto(v,"26bomber_rev");
            end
        end
        self.waitleft = self.waitleft - dtime;
        if(self.waitleft <= 0) then
            self:success();
            return;
        elseif(self.waitleft <= 10) then
            if(self.cam) then
                self.cam = not CameraFinish();
            end
            for v in ObjectsInRange(500,"nsdf_base") do
                if(GetPlayerHandle() ~= v) then
                    if(GetTeamNum(v) == 1) then
                        Damage(v,GetMaxHealth(v)/12 * dtime * (math.random()*1.5 + 0.5));
                    end
                end
            end
        end
        if(not self.cam) then
            self.t1 = self.t1 - dtime;
        elseif(self.cam) then 
            if(CameraCancelled() and (self.waitleft <= (self.minwait - 5) ) ) then
                self.cam = not CameraFinish();
            end
            if(self.camstage > #self.stageTimers) then
                self.cam = not CameraFinish();
                return;
            end
            self.stageTimers[self.camstage] = self.stageTimers[self.camstage] - dtime;
            if(self.stageTimers[self.camstage] <= 0) then
                self.camstage = self.camstage + 1;
            end
        end
        if( (self.camstage == 0) and (self.t1 <= 0) ) then
            self.cam = CameraReady();
            self.camstage = 1;
        end
        if(self.cam) then
            local t = nil;
            local p = nil;
            
            if(self.camstage == 1) then
                --Look at lead one of the attackers
                t = self.attackers[3];
            elseif(self.camstage == 2) then
                t = self.attackers[8];
            elseif(self.camstage == 4) then
                t = self.attackers[9];
                p = "25cin_pan1";
            elseif(self.camstage == 3) then
                t = self.attackers[12]; 
            end
            if(not IsAlive(t)) then
                self.camstage = self.camstage + 1;
            end
            if(p) then
                CameraPath(p,5000,200,t);
            else
                CameraObject(t,0,1000,-3000,t);
            end
        end
    end,
    save = function(self)
        return self.attackers,self.cam,self.t1,self.stageTimers,self.camstage,self.minwait,self.waitleft;
    end,
    load = function(self,...)
        self.attackers,self.cam,self.t1,self.stageTimers,self.camstage,self.minwait,self.waitleft = ...;
    end,
    success = function(self)
        --Make sure all units are destroyed

        for i,v in pairs(self.attackers) do
            RemoveObject(v);
        end
        for v in ObjectsInRange(500,GetPosition("nsdf_base")) do
            if(GetPlayerHandle() ~= v) then 
                Damage(v,100000);
            end
        end


        miss26setup();
    end
});

--Mission 26 objectives:

local apcMeatup = mission.Objective:define("apcMeatup"):setListeners({
    init = function(self)
        self.apcs = {GetHandle("apc1"),GetHandle("apc2")};
    end,
    start = function(self)
        AddObjective("bdmisn2504.otf","white");
    end,
    update = function(self)
        if(checkAnyDead(self.apcs)) then
            self:fail();
        end
        if(GetDistance(GetPlayerHandle(),self.apcs[1]) < 50) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective("bdmisn2504.otf","green");
        mission.Objective:Start("pickupSurvivors");
    end,
    fail = function(self)
        UpdateObjective("bdmisn2504.otf","red");
        FailMission(GetTime()+5.0,"bdmisn26l1.des");
    end
});

local pickupSurvivors = mission.Objective:define("pickupSurvivors"):setListeners({
    init = function(self)
        self.apcs = {GetHandle("apc1"),GetHandle("apc2")};
        self.nav = GetHandle("nav1");
    end,
    start = function(self)
        RemoveObjective("rbdnew3501.otf");
        AddObjective("rbdnew3503.otf", "WHITE");
        self.t1 = 30;
        self.arived = false;
        local navs = spawnAtPath("apcamr",1,"26spawn_nav");
        for i, v in pairs(navs) do
            SetLabel(v,("nav%d"):format(i));
            SetMaxHealth(v,0);
            SetPosition(v,GetPosition(v) + SetVector(0,100,0));
        end
        SetObjectiveName(navs[1],"NSDF Outpost");
        SetObjectiveName(navs[2],"Rendezvous Point");
        self.nav = navs[1];
    end,
    update = function(self,dtime)
        if(checkAnyDead(self.apcs)) then
            self:fail(1);
        end
        if(not self.pilots) then
            if(IsWithin(self.apcs[1],self.nav,200) or 
               IsWithin(self.apcs[2],self.nav,200) or 
               IsWithin(GetPlayerHandle(),self.nav,200)) then
                self.pilots = spawnAtPath("aspilo",1,"spawn_pilots")
                for i,v in pairs(self.pilots) do
                    SetIndependence(v,0);
                end
            end
        else
            if(checkAnyDead(self.pilots)) then
                self:fail(2);
            end
            if(not self.arived) then
                if(IsWithin(self.apcs[1],self.nav,50) or IsWithin(self.apcs[2],self.nav,50)) then
                    for i,v in ipairs(self.pilots) do
                        local t = self.apcs[math.floor( (i-1)/3 ) + 1];
                        Goto(v, t);
                    end
                    self.arived = true;
                end
            else
                for i,v in pairs(self.apcs) do
                    if(IsWithin(v,self.nav,40) ) then
                        Dropoff(v,GetPosition(v));
                    end
                end
                self.t1 = self.t1 - dtime;
                local pleft = 0;
                for i,v in pairs(self.pilots) do
                    
                    if(IsWithin(v,GetCurrentWho(v),10) or (GetCurrentCommand(v) == AiCommand["NONE"]) ) then
                        RemoveObject(v);
                        self.pilots[i] = nil;
                    else
                        pleft = pleft + 1;
                    end
                    
                end
                if((pleft <= 0)) then---or (self.t1 <= 0)) then
                    self:success();
                end
            end
        end
    end,
    save = function(self)
        return self.pilots, self.arived,self.t1;
    end,
    load = function(self,...)
        self.pilots,self.arived,self.t1 = ...;
    end,
    success = function(self)
        for i,v in pairs(self.apcs) do
            Stop(v,0);
        end  
        UpdateObjective("rbdnew3503.otf","green");
        mission.Objective:Start("escortAPCs");
    end,
    fail = function(self,v)
        UpdateObjective("rbdnew3503.otf","red");
        if v == 1 then 
            FailMission(GetTime()+5.0,"bdmisn26l1.des"); 
        else
            FailMission(GetTime()+5.0,"bdmisn26l2.des"); 
        end
    end
});

--Escort to Rendezvous
local escortAPCs = mission.Objective:define("escortAPCs"):setListeners({
    init = function(self)
        self.nav = GetHandle("nav2");
        self.apcs = {GetHandle("apc1"),GetHandle("apc2")};
    end,
    start = function(self)
        ClearObjectives();
        AddObjective("bdmisn2602.otf","white");
        AddObjective("bdmisn2603.otf","white");
    end,
    update = function(self)
        if(checkAnyDead(self.apcs)) then
            self:fail();
        end
        if(IsWithin(self.apcs[1],self.nav,100) and IsWithin(self.apcs[2],self.nav,100)) then
            self:success();
        end
    end,
    success = function(self)
        UpdateObjective("bdmisn2602.otf","green");
        UpdateObjective("bdmisn2603.otf","green");
	    SucceedMission(GetTime()+5.0, "bdmisn26wn.des");
    end,
    fail = function(self)
        UpdateObjective("bdmisn2603.otf","red");
        FailMission(GetTime()+5.0,"bdmisn26l1.des"); 
    end

});


--setup for miss 25 and 26
miss25setup = function()
    local walker = GetHandle("george");
    local comm = GetHandle("commtower");
    --SetMaxHealth(comm,GetMaxHealth(comm)*2.5);
    --SetCurHealth(comm,GetMaxHealth(comm));
    --Set units to patrol
    for i = 1, 13 do
        Patrol(GetHandle("patrol_" .. i), "patrol_path");
    end

    --First wave
    for i = 1, 8 do
        if i == 2 then
            Attack(GetHandle("attacker_" .. i), GetHandle("george"));
        else
            Attack(GetHandle("attacker_" .. i), GetHandle("commtower"));
        end
    end

    Goto(walker,"walker_path",1);
	SetObjectiveName (walker,"Cmdr. George");
    local swave = secondWave:start();
    local loseObjective = defendComm:start();
    local attackObjective = destorySovietComm:start();

end




miss26setup = function()
    --Spawns inital objects
    UpdateObjective("rbdnew3501.otf","red");
    RemoveObjective("rbdnew3502.otf");
    spawnAtPath("proxminb",2,"spawn_prox");
    spawnAtPath("svfigh",2,"26spawn_figh");
    spawnAtPath("svrckt",2,"26spawn_rock");
    spawnAtPath("svturr",2,"26spawn_turr");
    spawnAtPath("svltnk",2,"26spawn_light");
    local apcs = spawnAtPath("bvapc26",1,"26spawn_apc");
    for i, v in pairs(apcs) do
        SetLabel(v,("apc%d"):format(i));
        SetObjectiveName(v,("Transport %d"):format(i));
        SetObjectiveOn(v);
        Goto(v,"26apc_meatup",1);
    end
    for i, v in pairs(spawnAtPath("bvtank",1,"26spawn_tank")) do
        Goto(v,"26apc_meatup",1);
    end
    Goto(spawnAtPath("bvhraz",1,"26spawn_bomber")[1],"26bomber_rev",1);
    apcMeatup:start();
end

function Start()
    SetPilot(1,5);
    SetScrap(1,8);
    miss25setup();
	SetMaxHealth(GetHandle("abbarr2_barracks"),0);
	SetMaxHealth(GetHandle("abbarr3_barracks"),0);
	SetMaxHealth(GetHandle("abcafe3_i76building"),0)
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