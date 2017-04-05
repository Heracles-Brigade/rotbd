-- Battlezone: Rise of the Black Dogs, Black Dog Mission 25 written by General BlackDragon.


require("bz_logging");

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
WalkerDead = false, -- Did it go poof?
SecondAttack = false, -- Better stay or prepare for this one.
SovDefenseSpawn = false, -- It's under attack, defend it!
SovietCommDead = false, -- Is it dead yet?
CommDead = false; -- Did you lose your toy?
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)
SecondWave = 0,

-- Handles
Player = nil,
CommTower = nil,
SovietComm = nil,
Walker = nil,

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

    print("Black Dog Mission 25 Lua created by General BlackDragon");

end

function AddObject(h)

	local Team = GetTeamNum(h);

end

function DeleteObject(h)

	
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.CommTower = GetHandle("commtower");
		M.SovietComm = GetHandle("sovietcomm");
		M.Walker = GetHandle("george");

		for i = 1, 13 do
			Patrol(GetHandle("patrol_" .. i), "patrol_path", 1);
		end
		
		for i = 1, 8 do
			if i == 2 then
				Attack(GetHandle("attacker_" .. i), M.Walker, 1);
			else
				Attack(GetHandle("attacker_" .. i), M.CommTower, 1);
			end
		end
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("bdmisn2501.wav");
		M.UpdateObjectives = true;
		SetObjectiveOn(M.CommTower);
		SetObjectiveOn(M.SovietComm);
		Goto(M.Walk, "walker_path", 0);
		M.SecondWave = GetTime()+135.0; -- 2 minutes 15 seconds later, spawn 2nd attack wave.
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		if not M.WalkerDead then
			-- Did you lose your base?
			if not M.CommDead then
				AddObjective("bdmisn2501.otf", "WHITE");
			else
				AddObjective("bdmisn2501.otf", "RED");
			end
			
			-- You maanged to win without losing the walker, good job.
			if not M.SovietCommDead then
				AddObjective("bdmisn2502.otf", "WHITE");
			else
				AddObjective("bdmisn2502.otf", "GREEN");
			end
		else
			if not M.SovietCommDead then
				AddObjective("bdmisn2503.otf", "WHITE");
			else
				AddObjective("bdmisn2503.otf", "GREEN");
			end
		end
	end
	
	-- Add Health to the SovietComm so it's harder to kill? IMPROVEMENT: Just set it's health to 20,000 instead. GBD
	--[[
	if GetFrame / GetTimeStep() then
		AddHealth(M.SovietComm, 100);
	end
	--]]
	
	-- If the walker dies, urge up the Attack.
	if not M.WalkerDead and not IsValid(M.Walker) then
		M.Aud1 = AudioMessage("bdmisn2502.wav");
		M.WalkerDead = true;
		M.UpdateObjectives = true;
	end
	
	-- Spawn the 2nd (and currently only) additional attack wave.
	if not M.SecondAttack and GetTime() > M.SecondWave then
		for i = 1, 4 do
			Attack(BuildObject("svfigh", 2, "patrol_path"), M.CommTower);
		end
		M.SecondAttack = true;	
	end
	
	-- Spawn CommTower defenses.
	if not M.SovDefenseSpawn and GetWhoShotMe(M.SovietComm) ~= 0 then
		Patrol(BuildObject("svfigh", 2, "defense_spawn"), "defense_path");
		Patrol(BuildObject("svfigh", 2, "defense_spawn"), "defense_path");
		Patrol(BuildObject("svltnk", 2, "defense_spawn"), "defense_path");
		M.SovDefenseSpawn = true;
	end
	
	-- Win Conditions:
	if not M.MissionOver and not IsAlive(M.SovietComm) then
		SucceedMission(GetTime()+5.0, "bdmisn25wn.des");
		M.SovietCommDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	if not M.MissionOver and not IsAlive(M.CommTower) then
		FailMission(GetTime()+5.0, "bdmisn25l1.des");
		M.CommDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end
