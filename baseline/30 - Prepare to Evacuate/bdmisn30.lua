-- Battlezone: Rise of the Black Dogs, Black Dog Mission 30

--Contributors:
    --Jarle Trollebø(Mario)
    --General BlackDragon



local _ = require("bz_logging");

if not SetLabel then SetLabel = SettLabel end -- BZ1.5 backwards compatability.

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
FuryCinDone = false, -- Fury cinimatic camera.
SiloAttacked = false, -- Give warning to protect Silos.
ScrapClear = false, -- Scrap gone?
LPadOrdered = false, -- NEW: Actually order cons to make it! :)
LPadBuilt = false, -- Is it there?
AttackWaveSpawn = { }, -- Yay! Attack Waves!
BaseDead = false, -- Oh Nooo!
LPadDead = false, -- Uh oh.
ConsDead = false, -- Nope!
TransportDead = false, -- You killed Kenny!
SilosDead = false, -- New, if you lose all 3 silos, game over mate.
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)
AttackWaveTimer = { }, -- Timers.
ConsTimer = 0, -- For construction time. IMPROVEMENT: Just force it to Goto.
CameraTime = 0, -- For camera.

--Magic Scrap!
MagiScrapCounter = { }, -- Respawn these scrap 10 times, exactly.
MagiScrapPosition = { }, -- Saved position.
MagiScrap = { }, -- Handles.
MagiScrapOdf = { }, -- ODF.

-- Handles
Player = nil,
Nav = { },
Recycler = nil, 
CommTower = nil,
LPad = nil,
Silo1 = nil,
Silo2 = nil,
Silo3 = nil,
MovieStar = nil, -- Star Fury!
Transport = { },

--Magiscrap = { }, -- Can remove in BZR.
--CCARecy = nil,
--CCAComm = nil,
--NSDFRecy = nil,

-- Ints
Aud1 = 0
}

local function checkAnyDead(handles)
    for i,v in pairs(handles) do
        if(not IsAlive(v)) then
            return true;
        end
    end
    return false;
end

function Save()
    return 
		M
end

function Load(...)	
    if select('#', ...) > 0 then
		M
		= ...
    end
end

function Start()

    print("Black Dog Mission 30 Lua created by General BlackDragon");

end

function AddObject(h)

	local Team = GetTeamNum(h);
	
	-- NEW: Detect actual LPad construction?
	if not M.LPadBuilt and IsOdf(h, "ablpad") then
		M.LPad = h;
		M.LPadBuilt = true;
		CameraReady();
		M.CameraTime = GetTime() + 10.0;
		Goto(BuildObject("hvsav", 3, "spawn_fury1"), "fury_path"); -- IMPROVEMENT: Put furies on Team 3, they attack everything. Formerly this Attacked Player.
		Attack(BuildObject("hvsav", 3, "spawn_fury1"), M.Recycler);
		M.MovieStar = BuildObject("hvsat", 3, "spawn_fury3");
		Attack(BuildObject("hvsat", 3, "spawn_fury4"), M.Recycler); -- Attack LPad?
		Goto(M.MovieStar, M.LPad); -- Our movie star, yay! -- Attack?
		M.UpdateObjectives = true;
	end

end

function DeleteObject(h)

--[[ -- BAD! BuildObject in DeleteObject() crashes on Exit (Mission Cleanup, calls DeleteObject on all things).
	for i = 1, 10 do
		if GetLabel(h) == "magiscrap" .. i then -- BZR version.
			if M.MagicScrapCounter[i] < 10 then
				SetLabel(BuildObject(GetOdf(h), 0, h), "magiscrap" .. i); -- Replace this asap. -- BZR version. SetLabel required. :(
				M.BuildMagicScrap = { local Pos = GetPosition(h)};
				M.MagiScrapCounter[i] = M.MagiScrapCounter[i] + 1;
			end		
		end
	end
	--]]
	
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		for i = 1, 2 do 
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 1 then
				SetObjectiveName(M.Nav[i], "Black Dog Outpost");
			else
				SetObjectiveName(M.Nav[i], "Navpoint 1");
			end
			SetMaxHealth(M.Nav[i], 0);
		end
		
		M.Recycler = GetHandle("recycler");
		M.Constructor = GetHandle("constructor");
		M.CommTower = GetHandle("comm");
		M.Silo1 = GetHandle("silo1");
		M.Silo2 = GetHandle("silo2");
		M.Silo3 = GetHandle("silo3");
		
		--M.CCARecy = GetHandle("ccarecy");
		--M.CCAComm = GetHandle("ccacomm");
		--M.NSDFRecy = GetHandle("nsdfrecy");
		
		-- Magic Scrap.
		for i = 1, 10 do
			M.MagiScrap[i] = GetHandle("magiscrap" .. i);
			M.MagiScrapOdf[i] = GetOdf(M.MagiScrap[i]);
			M.MagiScrapPosition[i] = GetPosition(M.MagiScrap[i]);
			M.MagiScrapCounter[i] = 0;
		end
		
		-- Setup timers.
		M.AttackWaveTimer[1] = GetTime() + 210.0;
		M.AttackWaveTimer[2] = GetTime() + 390.0;
		M.AttackWaveTimer[3] = GetTime() + 600.0;
		M.AttackWaveTimer[4] = GetTime() + 750.0;
		M.AttackWaveTimer[5] = GetTime() + 855.0;
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("bdmisn3001.wav");
		SetObjectiveOn(M.Nav[1]);
		SetObjectiveOn(M.Nav[2]);
		Goto(BuildObject("avfigh", 2, "spawn_se3"), M.Silo1); --Attack?
		Goto(BuildObject("avfigh", 2, "spawn_se1"), M.Silo2); --IMPOVEMENT: moved from s3 to s1 for spread outness.
		M.UpdateObjectives = true;
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		-- Whew, that was a tough one...
		if not M.LPadBuilt then
			if not M.BaseDead and not M.ConsDead and not M.SilosDead then --NEW: Fail if all 3 Silos die.
				AddObjective("bdmisn3001.otf", "WHITE");
			else
				AddObjective("bdmisn3001.otf", "RED");
			end
			AddObjective("bdmisn3002.otf", "WHITE");
		else
			if not M.LPadDead and not M.TransportDead then -- Run away!
				AddObjective("bdmisn3003.otf", "GREEN");
			else
				AddObjective("bdmisn3003.otf", "RED");
			end
		end
	end
	
	-- Respawning Scrap.
	for i = 1, 10 do
		if not IsValid(M.MagiScrap[i]) and M.MagiScrapCounter[i] < 10 then
			M.MagiScrap[i] = BuildObject(M.MagiScrapOdf[i], 0, M.MagiScrapPosition[i]);
			M.MagiScrapCounter[i] = M.MagiScrapCounter[i] + 1;
		end
	end
	
	-- Attack Waves: 
	for i = 1, 5 do
		if GetTime() > M.AttackWaveTimer[i] then
			if i == 1 then -- First Attack, NSDF+CCA 
				-- NSDF Units.
				Attack(BuildObject("avwalk", 2, "spawn_se1"), M.Recycler);
				Attack(BuildObject("avwalk", 2, "spawn_se2"), M.Recycler);
				Attack(BuildObject("avtank", 2, "spawn_se1"), M.CommTower);
				Attack(BuildObject("avtank", 2, "spawn_se4"), M.Silo1);
				-- IMPROVEMENT: make tanks Goto(blah, "nsdf_path");
				-- CCA Units.
				Attack(BuildObject("svhraz", 2, "spawn_s1"), M.Player);
				Attack(BuildObject("svhraz", 2, "spawn_s2"), M.Player);
				Attack(BuildObject("svhraz", 2, "spawn_s3"), M.Silo1);
			elseif i == 2 then -- Second Attack, CCA.
				Attack(BuildObject("svfigh", 2, "spawn_sw1"), M.Silo1);
				Attack(BuildObject("svhraz", 2, "spawn_sw2"), M.Player);
				-- IMPROVEMENT: make some Goto(blah, "soviet_path");
			elseif i == 3 then -- Third Attack, CCA.
				Attack(BuildObject("svhraz", 2, "spawn_sw3"), M.Silo1);
				Attack(BuildObject("svhraz", 2, "spawn_sw4"), M.Player);
				-- IMPROVEMENT: Make some Goto(blah, "soviet_path");
			elseif i == 4 then -- Fourth Attack, CCA.
				Attack(BuildObject("svfigh", 2, "spawn_w1"), M.Silo1);
				Attack(BuildObject("svfigh", 2, "spawn_w2"), M.Silo2);
				Attack(BuildObject("svfigh", 2, "spawn_w1"), M.Silo3);
				Attack(BuildObject("svhraz", 2, "spawn_w4"), M.Player);
			elseif i == 5 then -- Final Attack, NSDF.
				Attack(BuildObject("avtank", 2, "spawn_s5"), M.Recycler);
				Attack(BuildObject("avtank", 2, "spawn_s6"), M.Recycler);
			end
			M.AttackWaveTimer[i] = 999999; -- Hacky :P
		end
	end
	
	-- If NSDF Scouts attack Silo:
	if not M.SiloAttacked and GetTime() < M.AttackWaveTimer[1] and 
	((GetWhoShotMe(M.Silo1) and GetTeamNum(GetWhoShotMe(M.Silo1)) == 2) or 
	(GetWhoShotMe(M.Silo2) and GetTeamNum(GetWhoShotMe(M.Silo2)) == 2) or 
	(GetWhoShotMe(M.Silo3) and GetTeamNum(GetWhoShotMe(M.Silo3)) == 2)) then
		M.Aud1 = AudioMessage("bdmisn3002.wav");
		M.SiloAttacked = true;	
	end
	
	-- Is Scrap Clear?
	if not M.ScrapClear and CountUnitsNearObject(M.Nav[2], 200.0, 0) == 0 then
		Goto(M.Constructor, M.Nav[2], 1);
		M.ScrapClear = true;
	end
	
	-- Order the cons to actually make it?
	if M.ScrapClear and not M.LPadOrdered and GetDistance(M.Constructor, M.Nav[2]) < 50.0 then
		M.Aud1 = AudioMessage("bdmisn3003.wav");
		BuildAt(M.Constructor, "ablpad", "launchpad", 1); -- IMPROVEMENT: Actually create the thing...
		M.LPadOrdered = true;
	end
	
	-- Fury camera.
	if M.LPadBuilt and not M.FuryCinDone and (CameraPath("fury_cam", 1000, 1000, M.MovieStar) or CameraCancelled() or GetTime() > M.CameraTime) then
		CameraFinish();
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOff(M.Nav[2]);
		SetObjectiveOn(M.LPad);
		for i = 1, 3 do
			M.Transport[i] = BuildObject("bvhaul", 1, "spawn_trans" .. i);
			SetObjectiveName(M.Transport[i], "Transport " .. i);
			SetObjectiveOn(M.Transport[i]);
			Goto(M.Transport[i], M.LPad, 1);
		end
		M.FuryCinDone = true;
		M.UpdateObjectives = true;
	end
	
	-- Win Conditions:
	if not M.MissionOver and M.FuryCinDone and GetDistance(M.Transport[1], M.LPad) < 100 and GetDistance(M.Transport[2], M.LPad) < 100 and GetDistance(M.Transport[3], M.LPad) < 100 then
		SucceedMission(GetTime()+5.0, "bdmisn30wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	-- Lose Recy:
	if not M.MissionOver and not IsAlive(M.Recycler) then
		FailMission(GetTime()+5.0, "bdmisn30l1.des");
		M.BaseDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Cons: OPTIONAL: Remove/redirect player to build new one if it dies?
	if not M.MissionOver and not M.LPadBuilt and not IsAlive(M.Constructor) then
		FailMission(GetTime()+5.0, "bdmisn30l2.des");
		M.ConsDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose a Transport
	if M.FuryCinDone and (not M.MissionOver) and M.LPadBuilt and checkAnyDead(M.Transport) then
		FailMission(GetTime()+5.0, "bdmisn30l3.des");
		M.TransportDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- If the LPad dies.
	if not M.MissionOver and M.LPadBuilt and not IsAlive(M.LPad) then
		FailMission(GetTime()+5.0, "bdmisn30l4.des");
		M.LPadDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	--NEW: If all 3 silos die.
	if not M.MissionOver and not M.LPadBuilt and not IsAlive(M.Silo1) and not IsAlive(M.Silo2) and not IsAlive(M.Silo3) then
		FailMission(GetTime()+5.0, "bdmisn30l5.des");
		M.SilosDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end

-- Lets find a good target?
function FindAITarget()

	-- Pick a target. Attack silos or base.
	if math.random(1, 2) == 1 then
		if IsAlive(M.Silo1) then
			return M.Silo1;
		elseif IsAlive(Silo2) then
			return M.Silo2;
		elseif IsAlive(M.Silo3) then
			return M.Silo3;
		end
	else
		if IsAlive(M.CommTower) then
			return M.CommTower;
		elseif IsAlive(M.Recycler) then
			return M.Recycler;
		elseif IsAlive(M.Constructor) then
			return M.Constructor;
		end
	end
end