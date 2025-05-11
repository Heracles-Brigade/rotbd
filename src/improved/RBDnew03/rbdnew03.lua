--[[
	Contributors:
	 - Herp McDerperson
	 - Seqan
	 - GBD
	 - Vemahk
	 - Janne
--]]

require("_printfix");

print("\27[34m----START MISSION----\27[0m");

--- @diagnostic disable-next-line: lowercase-global
debugprint = print;
--traceprint = print;

require("_requirefix").addmod("rotbd");

require("_table_show");
local api = require("_api");
local gameobject = require("_gameobject");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");
--local tracker = require("_tracker");
local navmanager = require("_navmanager");
local objective = require("_objective");
local utility = require("_utility");

-- Fill navlist gaps with important navs
navmanager.SetCompactionStrategy(navmanager.CompactionStrategy.ImportantFirstToGap);

-- constrain tracker so it does less work, otherwise when it's required it watches everything
--tracker.setFilterTeam(1); -- track team 1 objects
--tracker.setFilterClass("scavenger"); -- track scavengers
--tracker.setFilterClass("factory"); -- track factories
--tracker.setFilterClass("commtower"); -- track comm towers
--tracker.setFilterOdf("bvtank"); -- track bvtanks
--tracker.setFilterOdf("bvhraz"); -- track bvhraz
--tracker.setFilterClass("turrettank"); -- track turrettanks












local function choose(...)
    local t = {...};
    local rn = math.random(#t);
    return t[rn];
end

local audio = {
	intro = "rbdnew0301.wav",
	commwarn = "rbdnew0301W.wav",
	commclear = "rbdnew0302W.wav",
	inspect = "rbdnew0302.wav",
	tug = "rbdnew0303.wav",
	first_a = "rbdnew0304.wav",
	dayw = "rbdnew0305.wav",
	second_a = "rbdnew0306.wav",
	transint = "",
	backinrange = "",
	flee = "rbdnew0307.wav",
	win = "rbdnew0308.wav",
	lose1 = "rbdnew0301L.wav", --Mammoth Destroyed/sniped
	lose2 = "rbdnew0302L.wav", --Failed to extract on time
	lose3 = "rbdnew0303L.wav", --Detected, loser
	lose4 = "rbdnew0304L.wav", --Evidently you can't aim Day Wreckers
	lose5 = "rbdnew0305L.wav" --Why didn't you make a Day Wrecker?
}

local objectives = {
	Detection = "rbdnew0300.otf",
	Hanger = "rbdnew0301.otf",
	Tug = "rbdnew0303.otf",
	Mammoth1 = "rbdnew0302.otf",
	Control = "rbdnew0304.otf",
	Mammoth2 = "rbdnew0305.otf",
	TranStart = "rbdnew0306.otf",
	TranFin = "rbdnew0307.otf",
	Extract = "rbdnew0308.otf"
}

local M = { --Sets mission flow and progression. Booleans and values will be changed to "true" and appropriate names/integers as mission progresses. Necessary for save files to function as well as objective flow in later if statements.
StartDone = false, 
OpeningCinDone = false,
IsDetected = false,
HangarInfoed = false,
TugAquired = false,
ShieldDetected = false,
ControlDead = false,
MammothReached = false,
MammothReachedPrevious = false,
MammothInfoed = false,
SafetyReached = false,
MissionOver = false,
MammothTime = 0,
RadarTime = 0,
LastShieldTime = 0,
WreckTime1 = 0,
WreckTime2 = 0,
-- Handles; values will be assigned during mission setup and play
Player = nil,
ObjectiveNav = nil,
NavCoord = { },
Defenders = { },
NextDefender = 1,
Tug = nil,
Mammoth = nil,
ControlTower = nil,
Hangar = nil,
Supply = nil,
Wrecker = nil,
Armory = false,
Radar = { },
scrapFields = { },
Aud1 = 0
}

-- memorize scrap around a scrap field
local function scrapFieldsFiller(p)
    local scrapFieldScrap = {};
    for obj in gameobject.ObjectsInRange(35, p) do
        if obj:GetClassLabel() == "scrap" then
            table.insert(scrapFieldScrap, obj);
        end
    end
    M.scrapFields[p] = scrapFieldScrap;
end

-- if scrap is gone, respawn it (is this instant? seems like a bad idea)
local function scrapRespawner()
	for path, field in pairs(M.scrapFields) do
		for i, scrap in ipairs(field) do
			if not scrap or not scrap:IsValid() then
				field[i] = gameobject.BuildGameObject(choose("npscr1", "npscr2", "npscr3"), 0, GetPositionNear(GetPosition(path) or SetVector(), 1, 35));
			end
		end
	end
end

hook.Add("Start", "Mission:Start", function ()
	scrapFieldsFiller("scrpfld1");
end);

hook.AddSaveLoad("Mission",
function()
    return M;
end,
function(g)
    M = g;
end);


local function UpdateObjectives() --This entire function controls objective bubble and makes sure that objectives can flow in a linear order.
	objective.ClearObjectives();
	
	if not M.IsDetected then
		objective.AddObjective(objectives.Detection, "WHITE");
	elseif not M.MammothReached then
		objective.AddObjective(objectives.Detection, "RED");
	end
	
	if not M.HangarInfoed then
		-- NEW: If hanger dies before acquiring intel, just fail mission. Should be impossible unless we have cheating players. Joke's on them! They failed the mission! HA!
		if not M.Hangar:IsAlive() then
			objective.AddObjective(objectives.Hanger, "RED");
		else
			objective.AddObjective(objectives.Hanger, "WHITE");
		end
	else
		if not M.TugAquired then
			objective.AddObjective(objectives.Tug, "WHITE");
		else
			objective.AddObjective(objectives.Tug, "GREEN");
			if not M.ShieldDetected then
				objective.AddObjective(objectives.Mammoth1, "WHITE");
			else
				if not M.ControlDead then -- Destroy Control Tower.
					objective.AddObjective(objectives.Control, "WHITE");
				else
					objective.AddObjective(objectives.Control, "GREEN");
					if not M.MammothReached then -- Goto Mammoth.
						objective.AddObjective(objectives.Mammoth2, "WHITE");
					else
						if not M.MammothInfoed then -- Stream Mammoth data.
							objective.AddObjective(objectives.TranStart, "WHITE");
						else
							objective.AddObjective(objectives.TranFin, "GREEN");
							if not M.SafetyReached then -- At safe distance yet?
								objective.AddObjective(objectives.Extract, "WHITE");
							else
								objective.AddObjective(objectives.Extract, "GREEN");
							end
						end															
					end						
				end					
			end				
		end
	end	
end

local function SpawnNav(num) -- Spawns the Nth Nav point.
	local nav = navmanager.BuildImportantNav("apcamr", 1, M.NavCoord[num]); -- Make the nav from the harvested coordinates.
	if not nav then error("Nav "..num.." failed to spawn!"); end -- If the nav fails to spawn, throw an error.
	nav:SetObjectiveName("Nav "..num); -- Set its name
	if num == 5 then
		nav:SetObjectiveName("Extraction Point"); -- If it's the 5th nav, change its name. This is the name it checks for for the Win Condition; if you change this, change the win condition script as well.
	end
	nav:SetMaxHealth(0); -- Can't go boom-boom. I accidentally destroyed Nav 3 with the DW before this.
	
	-- Switches the active objective from the old nav to the new nav.
	M.ObjectiveNav:SetObjectiveOff();
	nav:SetObjectiveOn();
	M.ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
end

local function SpawnFromTo(odf, fp, fpp, tp)
	local obj = gameobject.BuildGameObject(odf, 2, fp, fpp)
	if not obj then error("Failed to spawn "..odf.." from "..tostring(fp).." to "..tostring(tp)); end -- If the object fails to spawn, throw an error.
	obj:Goto(tp, 0);
	SetLabel(obj:GetHandle(), fp.."_"..M.NextDefender);
	M.Defenders[M.NextDefender] = obj;
	M.NextDefender = M.NextDefender + 1;
end

-- 
local function SpawnArmy()
	SpawnFromTo("svfigh", "armyspawn1", 1, "def1");
	SpawnFromTo("svfigh", "armyspawn1", 1, "def1");
	SpawnFromTo("svltnk", "armyspawn1", 1, "def1");
	SpawnFromTo("svwalk", "def1", 1, "def1");
	
	SpawnFromTo("svtank", "armyspawn2", 1, "def2");
	SpawnFromTo("svhraz", "armyspawn2", 1, "def2");
	SpawnFromTo("svwalk", "def2", 1, "def2");
	
	SpawnFromTo("svtank", "armyspawn3", 1, "def3");
	SpawnFromTo("svtank", "armyspawn3", 1, "def3");
	SpawnFromTo("svrckt", "armyspawn3", 1, "def3");
	SpawnFromTo("svrckt", "armyspawn3", 1, "def3");
	
	SpawnFromTo("svtank", "armyspawn4", 1, "def4");
	SpawnFromTo("svhraz", "armyspawn4", 1, "def4");
	SpawnFromTo("svwalk", "def4", 1, "def4");
	
	SpawnFromTo("svltnk", "armyspawn5", 1, "def5");
	SpawnFromTo("svfigh", "armyspawn5", 1, "def5");
	SpawnFromTo("svfigh", "armyspawn5", 1, "def5");
	SpawnFromTo("svwalk", "def5", 1, "def5");
end

local function keepOutside(h1,h2) -- This is the shield function for the Mammoth. Thank you, Janne
	local p = h2:GetPosition();
	local r = 40;
	local pp = h1:GetPosition();
	local dv = Normalize(pp-p);
	local vel2 = h2:GetVelocity();
	local d = Length(pp-p);
	local vel = h1:GetVelocity();
	local dprod = DotProduct(vel,-dv);
	local nvel = vel + dprod*dv*(1+GetTimeStep());
	if(d < r) then
		local newp = (p + dv*r);
		local h = GetTerrainHeightAndNormal(newp);
		newp.y = math.max(h,newp.y);
		h1:SetPosition(newp);
		h1:SetVelocity(nvel);
	end
end


hook.Add("CreateObject", "Mission:CreateObject", function (object)
	if(not M.Wrecker and object:GetClassLabel() == "daywrecker") then
		M.Wrecker = object
	end
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
	M.Player = gameobject.GetPlayerGameObject();
	scrapRespawner();
	
	if not M.StartDone then
		
		M.Mammoth = gameobject.GetGameObject("mammoth");
		M.Mammoth:SetIndependence(0); -- Mammoth shouldn't respond or do anything in this mission.
		M.Hangar = gameobject.GetGameObject("hangar");
		M.Supply = gameobject.GetGameObject("supply");
		M.Tug = gameobject.GetGameObject("tug");
		M.Tug:RemovePilot();
		M.ControlTower = gameobject.GetGameObject("control");
		SetMaxScrap(2,10000);
		M.Player:SetPerceivedTeam(2); -- Make sure player isn't detected right away.
		for i = 1, 3 do 
			M.Radar[i] = { RadarHandle = gameobject.GetGameObject("radar"..i), RadarWarn = false, RadarTrigger = false }
		end
		
		for i = 1, 5 do
			local navtmp = gameobject.GetGameObject("nav"..i); -- Harvests the current nav's coordinates then deletes it. The saved coordinates are used later to respawn the nav when it is needed.
			if navtmp then
				M.NavCoord[i] = navtmp:GetPosition();
				navtmp:RemoveObject();
			end
		end
		
		for i =1, 6 do
			gameobject.GetGameObject("patrol1_" .. i):Patrol("patrol_1", 1);
		end
		for i =1, 10 do
			gameobject.GetGameObject("patrol2_" .. i):Patrol("patrol_2", 1);
		end
		for i =1, 9 do
			gameobject.GetGameObject("patrol3_" .. i):Patrol("patrol_3", 1)
		end
		
		
		M.StartDone = true;
		
		-- Pre-play setup complete. Time to start the shit.
		CameraReady();
		M.Aud1 = AudioMessage(audio.intro);
	end
	
	if not M.IsDetected and M.Player:GetPerceivedTeam() == 1 then
		M.IsDetected = true;
		UpdateObjectives();
	end
	
	--Opening Cinematic. Show off Deus Ex's wondrous creation!
	if not M.OpeningCinDone and CameraPath("camera_path", 1000, 2000, M.Mammoth:GetHandle()) or CameraCancelled() then
		CameraFinish();
		SpawnNav(1);
		M.OpeningCinDone = true;
		UpdateObjectives();
	end
	
	--Radar tower detection script
	for i = 1, 3 do
		if M.Radar[i].RadarHandle:IsAlive() then
			if not M.Radar[i].RadarWarn and M.Player:GetDistance(M.Radar[i].RadarHandle) < 100.0 then
				M.Aud1 = AudioMessage(audio.commwarn);
				M.RadarTime = GetTime();
				M.Radar[i].RadarWarn = true;
				StartCockpitTimer(30, 15, 5);
			else
				if M.Radar[i].RadarWarn then
					if M.Player:GetDistance(M.Radar[i].RadarHandle) > 100.0 then
						Aud1 = AudioMessage(audio.commclear);
						M.RadarTime = 0;
						M.Radar[i].RadarWarn = false;
						StopCockpitTimer();
						HideCockpitTimer();
					else
						if GetTime() - M.RadarTime > 30.0 then
							M.IsDetected = true;
							UpdateObjectives();
						end
					end
				end
			end
		end
	end
	

	if not M.HangarInfoed and M.Hangar:IsAlive() and M.Player:GetDistance(M.Hangar) < 50.0 then
		M.Aud1 = AudioMessage(audio.inspect);
		SpawnNav(2);
		M.HangarInfoed = true;
		UpdateObjectives();
	end
	
	if not M.TugAquired and M.Player == M.Tug then
		M.TugAquired = true;
		UpdateObjectives();
		M.Aud1 = AudioMessage(audio.tug);
		SpawnNav(3)
	end
	
	if M.TugAquired and M.Player:GetDistance(M.Mammoth) < 225.0 and not M.ShieldDetected then
		M.playerSLF = gameobject.BuildGameObject("bvslf", 1, "NukeSpawn", 1);
		M.Armory = true;
		SetMaxScrap(1, 20);
		SetScrap(1, 20);
		M.ShieldDetected = true;
		M.Aud1 = AudioMessage(audio.first_a);
		SpawnNav(4);
		UpdateObjectives();
	end

	if M.playerSLF:IsValid() then
		M.armoryCommand = M.playerSLF:GetCurrentCommand();
		print(M.armoryCommand);
		if M.armoryCommand == 21 and not M.pollArmoryWho then -- 21
			M.pollArmoryWho = true;
		end
	end
	if M.pollArmoryWho == true then
		local temp = M.playerSLF:GetCurrentWho();
		if temp:IsValid() then
			M.armoryTarget = temp;
			print(M.armoryTarget);
			M.pollArmoryWho = false;
		end
	end
	if M.Wrecker:IsValid() then
		if not M.impactPending and not M.wreckerTargetMissed then
			print(M.armoryTarget == M.ControlTower)
			if M.armoryTarget == M.ControlTower then
				M.impactPending = true;
				UpdateObjectives(); --yellow
			else
				if not M.wreckerTargetMissed == true then
					M.Aud1 = AudioMessage(audio.lose4);
					FailMission(GetTime() + 5.0, "rbdnew03l5.des");
					M.MissionOver = true;
					M.wreckerTargetMissed = true;
					UpdateObjectives(); --red
				end
			end
		end
	end
	if M.impactPending and not M.Wrecker:IsValid() then
		-- we should expect a dead shield control tower right about now
		if not M.ControlTower:IsValid() and not M.ControlDead then
			M.ControlDead = true;
			M.impactPending = false;
			UpdateObjectives(); -- green
			M.Aud1 = AudioMessage(audio.dayw);
			M.ObjectiveNav:SetObjectiveOff();
			M.Mammoth:SetObjectiveOn();
			M.Mammoth:SetObjectiveName("Mammoth");
			SpawnArmy();
		-- else
			-- if not M.wreckerTargetMissed == true then
				-- M.Aud1 = AudioMessage(audio.lose4);
				-- FailMission(GetTime() + 5.0, "rbdnew03l5.des");
				-- M.MissionOver = true;
				-- M.wreckerTargetMissed = true;
				-- UpdateObjectives(); --red
			-- end
		end
	end

	if not M.ControlDead and M.OpeningCinDone then
		keepOutside(M.Player, M.Mammoth);
		if GetTime() >= M.LastShieldTime then
			M.LastShieldTime = GetTime() + 3.5;
			MakeExplosion("sdome", M.Mammoth:GetHandle());
		end
	end
	
	if not M.ControlDead and M.TugAquired and not M.ControlTower:IsAlive() then
		M.Aud1 = AudioMessage(audio.dayw);
		M.ObjectiveNav:SetObjectiveOff();
		M.Mammoth:SetObjectiveOn();
		M.Mammoth:SetObjectiveName("Mammoth");
		M.ControlDead = true;
		SpawnArmy();
		UpdateObjectives();
	end
	
	if M.ControlDead and not M.MammothReached and M.Player:GetDistance(M.Mammoth) < 35 then
		M.MammothTime = GetTime() + 10.0; -- Wait 10 seconds to gather info.
		M.MammothReached = true;
		UpdateObjectives();
		if not M.MammothReachedPrevious then
			M.Aud1 = AudioMessage(audio.second_a);
			M.MammothReachedPrevious = true;
		else
			M.Aud1 = AudioMessage(audio.backinrange)
		end
	end
	
	if GetTime() < M.MammothTime and M.MammothReached and M.Player:GetDistance(M.Mammoth) > 35 then
		M.MammothTime = 0;
		M.MammothReached = false;
		UpdateObjectives();
		M.Aud1 = AudioMessage(audio.transint);
	end
	
    if M.MammothReached and not M.MammothInfoed and GetTime() > M.MammothTime then
        M.Aud1 = AudioMessage(audio.flee);
        StartCockpitTimer(120, 30, 10);
		M.Mammoth:SetObjectiveOff();
--		BuildObject("bvapc", 3, GetPositionNear(GetPosition(GetHandle("nav5"))));
        SpawnNav(5);
        M.MammothInfoed = true;
        UpdateObjectives();
        M.Player:SetPerceivedTeam(1);
        for i=1, 18 do
            local tmp = M.Defenders[i];
            if tmp:GetOdf() ~= "svwalk" then
                tmp:Attack(M.Player);
            end
        end
    end
	
	-- Win / Lose conditions.
	if not M.MissionOver then
	
		-- Win Conditions:
		if M.MammothInfoed and M.ObjectiveNav:GetObjectiveName() == "Extraction Point" and M.Player:GetDistance(M.ObjectiveNav) < 50.0 then
			Aud1 = AudioMessage(audio.win);
			SucceedMission(GetTime()+5.0, "rbdnew03wn.des");
			M.MissionOver = true;
			M.SafetyReached = true;
			UpdateObjectives();
		end
		
		-- Lose Conditions:
		
		if not M.HangarInfoed and not M.Hangar:IsAlive() then
			FailMission(GetTime()+5.0, "rbdnew03l3.des");
			M.MissionOver = true;
			UpdateObjectives();
		end

		if not M.Mammoth:IsAlive() then 
			M.Aud1 = AudioMessage(audio.lose1);
			FailMission(GetTime()+5.0, "rbdnew03l1.des");
			M.MissionOver = true;
			UpdateObjectives();
		end
		
		if M.MammothInfoed and GetCockpitTimer() == 0 and not M.MissionOver then
			Aud1 = AudioMessage(audio.lose2);
			FailMission(GetTime() + 5.0, "rbdnew03l2.des");
			M.MissionOver = true;
			UpdateObjectives();
		end

		if M.IsDetected and not M.MammothReached then
			Aud1 = AudioMessage(audio.lose4);
			FailMission(GetTime() + 5.0, "rbdnew03l4.des");
			M.MissionOver = true;
			UpdateObjectives();
		end
			
		-- -- the DW detonated and the target is still intact!
		-- if M.impactPending and not IsValid(M.Wrecker) and not M.ControlDead then
			-- --M.impactPending = false;
			-- M.wreckWatchdogStarted = false;
			-- M.wreckerTargetMissed = true;
			-- M.Aud1 = AudioMessage(audio.lose4);
			-- FailMission(GetTime() + 5.0, "rbdnew03l5.des");
			-- M.MissionOver = true;
			-- UpdateObjectives();
		-- end
			
		-- if M.Wrecker and not IsValid(M.Wrecker) and not M.ControlDead and M.WreckTime1 == 0 then
			-- M.WreckTime1 = GetTime() + 1.0;
		-- end
		-- if M.WreckTime1 ~= 0 and GetTime() >=M.WreckTime1 and not M.ControlDead then
			-- M.Aud1 = AudioMessage(audio.lose4);
			-- FailMission(GetTime() + 5.0, "rbdnew03l5.des");
			-- M.MissionOver = true;
			-- UpdateObjective(objectives.Control, "RED");
		-- end

		-- if not M.Wrecker and M.Armory and GetScrap(1) < 20 and not M.ControlDead and M.WreckTime2 == 0 then
			-- M.WreckTime2 = GetTime() + 1.5;
		-- end
		-- if M.WreckTime2 ~= 0 and GetTime() > M.WreckTime2 and not M.ControlDead and not M.Wrecker then
			-- Aud1 = AudioMessage(audio.lose5);
			-- FailMission(GetTime() + 5.0, "rbdnew03l5.des");
			-- M.MissionOver = true;
			-- UpdateObjective(objectives.Control, "RED");
		-- end
	end
end);