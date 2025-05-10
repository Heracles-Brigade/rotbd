-- Battlezone: Rise of the Black Dogs, Black Dog Mission 24 written by General BlackDragon.


;
local bzCore = require("bz_core");
local mammoth = require("mammoth");





local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
Nav1Reached = false, -- Are we at nav1 yet? 
DecoyTriggered = false, -- It's a Trap!
TrapEscaped = false, -- Whew, close one!
MammothStolen = false, -- Steal the Mammoth!
MammothDead = false, -- You can't kill something that's extinct.
DropZoneReached = false, -- Are we there yet?
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)

-- Handles
Player = nil,
Nav = { },
Mammoth = nil,
MammothDecoy = nil,

-- Ints
Aud1 = 0
}



local loaded = false;

function Save()
	return 
	M, bzCore:save();
end

function Load(missionData,bzUtilsData)	
	--[[if select('#', ...) > 0 then
	M
	= ...
	end--]]
	M = missionData;
	bzCore:load(bzUtilsData);
	loaded = true;
end

function GameKey(...)
	bzCore:onGameKey(...);
end

function Start()
	bzCore:onStart();
	print("Black Dog Mission 24 Lua created by General BlackDragon");
end

function AddObject(h)
	bzCore:onAddObject(h);
	local Team = GetTeamNum(h);

end

function DeleteObject(h)
	bzCore:onDeleteObject(h);
end

function CreateObject(h)
	bzCore:onCreateObject(h);
end

function afterSave()
	bzCore:afterSave();
end

function afterLoad()
	bzCore:afterLoad();
	loaded = false;
end

function Update(dtime)
	bzCore:update(dtime);
	
	if(loaded) then
		afterLoad();
	end

	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0); -- Nope.
		M.MammothDecoy = GetHandle("badmammoth");
		SetIndependence(M.MammothDecoy, 0); -- Nope.

		-- In BZ64, navs are invincible, maybe keep it that way for now. (units in this mission use navs to goto)
		for i = 1, 2 do
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 2 then
				SetObjectiveName(M.Nav[i], "Pickup Zone");
			else
				SetObjectiveName(M.Nav[i], "Navpoint 1");
			end
			SetMaxHealth(M.Nav[i], 0);
		end
			
		--[[ -- Units already set in BZN to do patrol. :)
		for i = 1, 2 do
			Patrol(GetHandle("patrol1_" .. i), "patrol_1", 1);
			Patrol(GetHandle("patrol2_" .. i),  "patrol_2", 1);
			Patrol(GetHandle("patrol3_" .. i),  "patrol_3", 1);
		--]]
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("bdmisn2401.wav");
		M.UpdateObjectives = true;
		SetObjectiveOn(M.Nav[1]);
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		if not M.MammothDead then
			-- If you haven't stolen anything yet, you're a good boy.
			if not M.MammothStolen then
				-- First order, investigate the Mammoth.
				if not M.DecoyTriggered then
					AddObjective("bdmisn2401.otf", "WHITE");
				else
					-- but bad news!
					if not M.TrapEscaped then
						AddObjective("bdmisn2402.otf", "WHITE");
					else -- Go find me a Mammoth.
						AddObjective("bdmisn2402.otf", "GREEN");
						AddObjective("bdmisn2403.otf", "WHITE");
					end
				end		
			else -- Get to the drop zone.
				if not M.DropZoneReached then
					AddObjective("bdmisn2404.otf", "WHITE");
				else
					AddObjective("bdmisn2404.otf", "GREEN");
				end
			end
		else -- ITS DEAD! NOOOOO! NEW Fail objective. -GBD
			AddObjective("bdmisn2405.otf", "RED");
		end
	end
	
	-- You're there, but it's a trap!
	if not M.Nav1Reached and GetDistance(M.Player, M.Nav[1]) < 175.0 then
		Attack(BuildObject("svhraz", 2, "spawn_svhraz1"), M.Player);
		Attack(BuildObject("svhraz", 2, "spawn_svhraz2"), M.Player);
		Attack(BuildObject("svfigh", 2, "spawn_svfigh1"), M.Player);
		Attack(BuildObject("svfigh", 2, "spawn_svfigh2"), M.Player);
		Attack(BuildObject("svrckt", 2, "spawn_svrkct1"), M.Player);
		Attack(BuildObject("svrckt", 2, "spawn_svrckt2"), M.Player);
		M.Nav1Reached = true;
		M.UpdateObjectives = true;
	end
	-- IMPROVEMENT? Move spawn up to here, closer to when u get to mammoth decoy?
	if not M.DecoyTriggered and GetDistance(M.Player, M.MammothDecoy) < 150.0 then
		Damage(M.MammothDecoy, 90001); -- It's over 9000!!!
		M.Aud1 = AudioMessage("bdmisn2402.wav");
		M.DecoyTriggered = true;
		M.UpdateObjectives = true;
	end
	-- Okay, your safe.
	if M.DecoyTriggered and not M.TrapEscaped and GetDistance(M.Player, M.Nav[1]) > 400.0 then
		M.Aud1 = AudioMessage("bdmisn2403.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOn(M.Mammoth);
		M.TrapEscaped = true;
		M.UpdateObjectives = true;
	end
	
	-- Did you do the deed yet?
	if not M.MammothStolen and M.Player == M.Mammoth then
		M.Aud1 = AudioMessage("bdmisn2404.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOff(M.Mammoth);
		SetObjectiveOn(M.Nav[2]);
		M.MammothStolen = true;
		M.UpdateObjectives = true;
	end
	
	-- Win Conditions:
	if not M.MissionOver and M.MammothStolen and M.Player == M.Mammoth and GetDistance(M.Player, M.Nav[2]) < 50.0 then
		SucceedMission(GetTime()+5.0, "bdmisn24wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
		M.DropZoneReached = true;
	end
	
	-- Lose Conditions
	if not M.MissionOver and not IsValid(M.Mammoth) then
		FailMission(GetTime()+5.0, "bdmisn24l1.des");
		M.MammothDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end
