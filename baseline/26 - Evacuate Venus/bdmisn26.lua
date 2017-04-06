-- Battlezone: Rise of the Black Dogs, Black Dog Mission 26 written by General BlackDragon.



require("bz_logging");

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
PilotsSpawn = false, -- We have peoples!
APCsThere = false, -- Are you there?
PilotsInAPC = false, -- Timed pilot deletion.
APCDead = false, -- Did you goof?
PilotsDead = false, -- NEW: Lose if the pilots die.
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)
PilotTime = 0,

-- Handles
Player = nil,
Nav = { },
APC1 = nil,
APC2 = nil,
Minions = { },

-- Ints
Aud1 = 0
}

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

    print("Black Dog Mission 26 Lua created by General BlackDragon");

end

function AddObject(h)

	local Team = GetTeamNum(h);

end

function DeleteObject(h)

	
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.APC1 = GetHandle("apc1");
		M.APC2 = GetHandle("apc2");
		
		for i = 1, 2 do
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 1 then
				SetObjectiveName(M.Nav[i], "Black Dog Outpost");
			elseif i == 2 then
				SetObjectiveName(M.Nav[i], "Rendezvous Point");
			end
			SetMaxHealth(M.Nav[i], 0);
		end
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("bdmisn2601.wav");
		M.UpdateObjectives = true;
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		if not M.PilotsInAPC then
			if not M.APCDead and not M.PilotsDead then
				AddObjective("bdmisn2601.otf", "WHITE");
			else
				AddObjective("bdmisn2601.otf", "RED");
			end
		else
			if not M.APCDead and M.MissionOver then -- You win.
				AddObjective("bdmisn2602.otf", "GREEN");
				AddObjective("bdmisn2603.otf", "GREEN");
			else -- Your not there yet, only lose if your APC dies.
				AddObjective("bdmisn2602.otf", "WHITE");
				if not M.APCDead then
					AddObjective("bdmisn2603.otf", "WHITE");
				else -- BAD BOY!
					AddObjective("bdmisn2603.otf", "RED");
				end
			end
		end
	end
		
	-- Spawn pilots when you get close. (IMPROVEMENT: OR APC GETS CLOSE!)
	if not M.PilotsSpawn and (GetDistance(M.Player, M.Nav[1]) < 200 or GetDistance(M.APC1, M.Nav[i]) < 200 or GetDistance(M.APC2, M.Nav[1]) < 200) then
		for i = 1, 6 do
			M.Minions[i] = BuildObject("bspilo", 1, "spawn_pilo" .. i);
			SetIndependence(M.Minions[i], 0); -- Don't let them get in empty ships by themselves.
		end
		M.PilotsSpawn = true;
	end
	
	-- The APC is there, trigger timer and soldiers to get in.
	if not M.APCsThere and GetDistance(M.APC1, M.Nav[1]) < 50 and GetDistance(M.APC2, M.Nav[1]) < 50 then
		for i = 1, 3 do
			Goto(M.Minions[i], M.APC1, 1);
		end
		
		for i = 4, 6 do
			Goto(M.Minions[i], M.APC2, 1);
		end
		
		M.PilotTime = GetTime()+15.0;
		M.APCsThere = true;
	end
	
	-- Pilots are in apc, or close enough now. Delete them, and update objectives.
	if not M.PilotsInAPC and M.APCsThere and GetTime() > M.PilotTime then
		M.Aud1 = AudioMessage("bdmisn2402.wav");
		for i = 1, 6 do
			RemoveObject(M.Minions[i]);
		end
		M.PilotsInAPC = true;
		M.UpdateObjectives = true;
	end

	-- Win Conditions:
	if not M.MissionOver and M.PilotsInAPC and GetDistance(M.APC1, M.Nav[2]) < 100 and GetDistance(M.APC2, M.Nav[2]) < 100 then
		SucceedMission(GetTime()+5.0, "bdmisn26wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	if not M.MissionOver and (not IsAlive(M.APC1) or not IsAlive(M.APC2)) then
		FailMission(GetTime()+5.0, "bdmisn26l1.des");
		M.APCDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Tell if any pilots are dead?
	if M.PilotsSpawn and not M.PilotsDead and not M.PilotsInAPC then
		for	i = 1, 6 do
			if not IsAlive(M.Minions[i]) then
				M.PilotsDead = true;
				break;
			end
		end
	end
	-- NEW: If pilots die before they get into APCs give funny lose description.
	if not M.MissionOver and M.PilotsDead then
		FailMission(GetTime()+5.0, "bdmisn26l2.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end
