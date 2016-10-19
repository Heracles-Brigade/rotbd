-- Battlezone: Rise of the Black Dogs, Black Dog Mission 26 written by General BlackDragon.

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
OpeningCinDone = false, -- Intro cinimatic camera.
DistressSignal = false, -- You have to go here now.
DistressActivate = false, -- Are you there?
DistressFinished = false, -- Trap done.
GotOne = false, -- Got 1st relic?
PickedUpSecond = false, -- Grabbed it yet?
GotTwo = false, -- Got 2nd relic?
AttackSpawnDead = false, -- CCA Retaliation!
TugDead = false, -- Bad!
RecyDead = false, -- Badder!
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)

-- Handles
Player = nil,
Nav = { },
Relic1 = nil,
Relic2 = nil,
Tug = nil,
Recycler = nil,
Distressee = { },
Attackers = { },

-- Not used but plan to.
SovHQ = nil,
SovTug1 = nil,
SovTug2 = nil,

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
		
		M.Relic1 = GetHandle("relic1");
		SetObjectiveName(M.Relic1, "Alien Relic");
		M.Relic2 = GetHandle("relic2");
		SetObjectiveName(M.Relic2, "Alien Relic");
		
		M.Recycler = GetHandle("recycler");
		--Goto(M.Recycler, GetHandle("recygeyser"), 1);
		--Deploy(M.Recycler);
		M.Tug = GetHandle("tug");
		
		M.SovHQ = GetHandle("soviethq");
		M.SovTug1 = GetHandle("sovtug1");
		M.SovTug2 = GetHandle("sovtug2");
		
		for i = 1, 4 do
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 4 then
				SetObjectiveName(M.Nav[i], "Navpoint 4");
			elseif i == 3 then
				SetObjectiveName(M.Nav[i], "Black Dog Outpost");
			else
				SetObjectiveName(M.Nav[i], "Relic Site");
			end
			SetMaxHealth(M.Nav[i], 0);
		end
		
		M.StartDone = true;
		
		-- Start up the mission.
		CameraReady();
		M.Aud1 = AudioMessage("bdmisn2601.wav");
		SetObjectiveOn(M.Relic1);
		SetObjectiveOn(M.Relic2);
		SetObjectiveOn(M.Recycler);
		SetObjectiveOn(M.Tug);
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		-- Have u gotten to first relic yet?
		if not M.TugDead then
			if not M.DistressSignal then
				AddObjective("bdmisn2601.otf", "WHITE");
			else
				if not M.DistressFinished then
					AddObjective("bdmisn2602.otf", "WHITE");
				else
					-- You destroyed the distress signal trap.
					if not M.GotOne then
						AddObjective("bdmisn2602.otf", "GREEN");
						AddObjective("bdmisn2603.otf", "WHITE");
					else -- Got first Relic back to base, good job. Now go get the other.
						if not M.PickedUpSecond then
							AddObjective("bdmisn2604.otf", "WHITE");
						else
							if not M.GotTwo then
								AddObjective("bdmisn2605.otf", "WHITE");
							else
								if not M.RecyDead then
									if not M.AttackSpawnDead then
										AddObjective("bdmisn2606.otf", "WHITE");
									else
										AddObjective("bdmisn2606.otf", "GREEN");
									end
								else -- You failed!
									AddObjective("bdmisn2606.otf", "RED");
								end
							end
						end
					end
				end
			end
		else -- You lost the Tug?! BAD!
			AddObjective("bdmisn2607.otf", "RED");
		end
	end
	
	-- Intro camera.
	if not M.OpeningCinDone and (CameraPath("camera_path", 1000, 1000, M.Relic1) or CameraCancelled()) then
		CameraFinish();
		M.OpeningCinDone = true;
		M.UpdateObjectives = true;
	end
	
	-- When you get close to one of the relics, trigger a distraction.
	if not M.DistressSignal and (GetDistance(M.Tug, M.Relic1) < 50 or GetDistance(M.Tug, M.Relic2) < 50) then
		--M.Aud1 = AudioMessage("bdmisn2603.wav"); -- ADD ME! // "We're picking up a distress signal, we've dropped a Nav beacon."
		M.DistressSignal = true;
		M.UpdateObjectives = true;
	end
	
	-- Trigger the distress call.
	if M.DistressSignal and not M.DistressActivate and GetDistance(M.Player, M.Nav[4]) < 200 then
		M.Distressee[1] = BuildObject("svrckt", 2, "spawn_call1");
		M.Distressee[2] = BuildObject("svrckt", 2, "spawn_call2");
		M.Distressee[3] = BuildObject("svhraz", 2, "spawn_call3");
		M.Distressee[4] = BuildObject("svfigh", 2, "spawn_call4");
		-- Attack player!
		for i = 1, 4 do
			Attack(M.Distressee[i], M.Player, 1);
		end
		M.DistressActivate = true;
	end
	
	-- Watch for trap to finish.
	if M.DistressActivate and not M.DistressFinished then
		M.DistressFinished = true
		for i = 1, 4 do
			if IsAlive(M.Distressee[i]) and GetTeamNum(M.Distressee[i]) == 2 then
				M.DistressFinished = false; -- Nope, not done yet.
			end
		end	
		-- Is it done?
		if M.DistressFinished then
			M.UpdateObjectives = true;
			-- IMPROVEMENT: Make this spawn based on which Relic was captured, using "spawn_defend2_1" and "spawn_defend2_2" if Relic 1 was the one captured.
			BuildObject("svhraz", 2, "spawn_defend1_1");
			BuildObject("svfigh", 2, "spawn_defend1_2");
		end
	end
	
	-- Check if we got the relics back safe.
	if not M.GotOne and (GetDistance(M.Relic1, M.Nav[3]) < 200 or GetDistance(M.Relic2, M.Nav[3]) < 200) then
		M.GotOne = true;
		M.UpdateObjectives = true;
	elseif not M.GotTwo and GetDistance(M.Relic1, M.Nav[3]) < 200 and GetDistance(M.Relic2, M.Nav[3]) < 200 then -- Got one, watch for the other.
		M.Aud1 = AudioMessage("bdmisn2602.wav");
		M.GotTwo = true;
		M.UpdateObjectives = true;
		for i = 1, 4 do
			if i < 2 then
				M.Attackers[i] = BuildObject("svhraz", 2, "spawn_attacker" .. i);
			else
				M.Attackers[i] = BuildObject("svrckt", 2, "spawn_attacker" .. i);
			end
			Attack(M.Attackers[i], M.Recycler, 1);
		end
	end
	
	-- If we GotOne, and we picked up 2nd.
	if M.GotOne and not M.PickedUpSecond and (GetDistance(M.Relic1, M.Nav[3]) > 200 and GetTug(M.Relic1)) or (GetDistance(M.Relic2, M.Nav[3]) > 200 and GetTug(M.Relic2)) then
		M.PickedUpSecond = true;
		M.UpdateObjectives = true;
	end
	
	-- if GotTwo and not attack wave dead.
	if M.GotTwo and not M.AttackSpawnDead then
		M.AttackSpawnDead = true;
		for i = 1, 4 do
			if IsAlive(M.Attackers[i]) and GetTeamNum(M.Attackers[i]) == 2 then
				M.AttackSpawnDead = false -- Nope!
			end
		end
	end

	-- Win Conditions:
	if not M.MissionOver and M.AttackSpawnDead and M.GotOne and M.GotTwo then
		SucceedMission(GetTime()+5.0, "bdmisn26wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	-- If Recy dies.
	if not M.MissionOver and not IsAlive(M.Recycler) then
		FailMission(GetTime()+5.0, "bdmisn26l1.des");
		M.RecyDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	-- If tug dies.
	if not M.MissionOver and not IsAlive(M.Tug) then
		FailMission(GetTime()+5.0, "bdmisn26l2.des");
		M.TugDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end

	
	
end
