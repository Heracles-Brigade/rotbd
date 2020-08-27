-- Battlezone: Rise of the Black Dogs, Black Dog Mission 29 written by General BlackDragon.



;


local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
OpeningCinDone = false, -- Intro cinimatic camera.
NSDFDead = false, -- Are they gone?
ObjectifyNSDF = false, -- If they're not, do it.
ArmoryDead = false, -- Oops.
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)

-- Handles
Player = nil,
Nav1 = nil,
Armory = nil, 
NSDFHQ = nil, -- Not used, maybe use it?
Fury = nil, -- Not used, maybe use it?
NSDFGuard = { },

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

    print("Black Dog Mission 29 Lua created by General BlackDragon");

end

function AddObject(h)

	local Team = GetTeamNum(h);

end

function DeleteObject(h)

	
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.Nav1 = GetHandle("nav1");
		SetObjectiveName(M.Nav1, "American Base");
		SetMaxHealth(M.Nav1, 0);
		
		M.Armory = GetHandle("armory");
		--M.NSDFHQ = GetHandle("nsdfhq"); -- Not used.
		--M.Fury = GetHandle("furry"); -- Not used.
		
		for i = 1, 10 do
			M.NSDFGuard[i] = GetHandle("nsdfguard" .. i);
		end
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("bdmisn2901.wav");
		CameraReady();
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		-- Whew, that was a tough one...
		if not M.MissionWon then
			AddObjective("bdmisn2901.otf", "WHITE");
		elseif M.ArmoryDead then -- Oops.
			AddObjective("bdmisn2901.otf", "RED");
		else
			AddObjective("bdmisn2901.otf", "GREEN");
		end
	end
		
	-- Intro camera.
	if not M.OpeningCinDone and (CameraPath("camera_path", 1000, 1000, M.Armory) or CameraCancelled()) then
		CameraFinish();
		M.OpeningCinDone = true;
		M.UpdateObjectives = true;
	end
	
	-- Are all NSDF Dead?
	if not M.NSDFDead then
		M.NSDFDead = true;
		for i = 1, 10 do
			if IsAlive(M.NSDFGuard[i]) then
				M.NSDFDead = false;
				break;
			end
		end
	end
	
	-- Objectify the NSDF if they're not dead.
	if not M.ObjectifyNSDF and GetDistance(M.Player, M.Armory) < 100 then
		for i = 1, 10 do
			SetObjectiveOn(M.NSDFGuard[i]);
		end
		M.ObjectifyNSDF = true;
	end
	
	-- Win Conditions:
	if not M.MissionOver and M.NSDFDead and GetDistance(M.Player, M.Armory) < 100 then
		SucceedMission(GetTime()+5.0, "bdmisn29wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	-- NEW: If Armory is destroyed.
	if not M.MissionOver and not IsAlive(M.Armory) then
		FailMission(GetTime()+5.0, "bdmisn29l1.des");
		M.ArmoryDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end
