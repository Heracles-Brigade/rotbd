-- Battlezone: Rise of the Black Dogs, Black Dog Mission 21 written by General BlackDragon.

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
OpeningCinDone = false, -- Intro cinimatic camera.
ConvoyCinDone = false, -- Convoy Camera.
CommandInfoed = false, -- Got intel?
Power1Dead = false, -- Destroyed all of Power1?
Power2Dead = false, -- Destroyed all of Power2?
--CommDead = false, -- Commtower Dead?
Patrol3Dead = false, -- Spawn more enemies!
TugGotRelic = false, -- Did it pick it up?
TugAway = false, -- Tug / APC gone.
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)

Camera1Time = 0,

-- Handles
Player = nil,
Nav = { },
Power1 = { },
Power2 = { },
CommTower = nil,
Command = nil,
Cafe = nil,
Relic = nil,

-- Convoy.
Tug = nil,
APC = nil,
Tank1 = nil,
Tank2 = nil,
Tank3 = nil,

-- Patrols
--Patrol1_1 = nil,
--Patrol1_2 = nil,
--Patrol2_1 = nil,
--Patrol2_2 = nil,
Patrol3_1 = nil,
Patrol3_2 = nil,

-- Reinforcements
Reinforcements = { },

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

    print("Black Dog Mission 21 Lua created by General BlackDragon");

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
		M.Command = GetHandle("command");
		M.Cafe = GetHandle("research");
		M.Relic = GetHandle("relic");
		SetMaxHealth(M.Relic, 0); -- This is invincible.
		
		for i = 1, 4 do
			M.Power1[i] = GetHandle("power1_" .. i);
			M.Power2[i] = GetHandle("power2_" .. i);
			
			M.Nav[i] = GetHandle("nav" .. i);
			SetObjectiveName(M.Nav[i], "Nav " .. i);
			SetMaxHealth(M.Nav[i], 0);
		end
		
		M.Patrol3_1 = GetHandle("patrol3_1");
		M.Patrol3_2 = GetHandle("patrol3_2");
		
		--[[ -- Units already set in BZN to do patrol. :)
		Patrol(M.Patrol1_1, "patrol_1", 1);
		Patrol(M.Patrol1_2, "patrol_1", 1);
		Patrol(M.Patrol2_1, "patrol_2", 1);
		Patrol(M.Patrol2_2, "patrol_2", 1);
		Patrol(M.Patrol3_1, "patrol_3", 1);
		Patrol(M.Patrol3_2, "patrol_3", 1);
		--]]
		
		M.StartDone = true;
		
		-- Start up the mission.
		CameraReady();
		M.Camera1Time = GetTime() + 20;
		M.Aud1 = AudioMessage("bdmisn2101.wav");
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		if not M.CommandInfoed then
			if not IsAlive(M.Command) then
				AddObjective("bdmisn211.otf", "RED");
			else
				AddObjective("bdmisn211.otf", "WHITE");
			end
		else
			AddObjective("bdmisn211.otf", "GREEN");
			
			if not M.Power1Dead then
				AddObjective("bdmisn212.otf", "WHITE");
			else
				AddObjective("bdmisn212.otf", "GREEN");
				
				if not M.Power2Dead then
					AddObjective("bdmisn213.otf", "WHITE");
				else
					AddObjective("bdmisn213.otf", "GREEN");
					
					if not M.CommDead then
						AddObjective("bdmisn214.otf", "WHITE");
					else
						AddObjective("bdmisn214.otf", "GREEN");
					end
				end
			end
		end
	end
	
	-- Do the opening Camera.
	if not M.OpeningCinDone and (CameraPath("opening_cin", 2000, 1000, M.Cafe) or CameraCancelled() or GetTime() > M.Camera1Time) then -- IsAudioMessageDone(M.Aud1) then 
		CameraFinish();
		SetObjectiveOn(M.Nav[1]);
		M.OpeningCinDone = true;
		M.UpdateObjectives = true;
	end
	
	-- If the player gets close to Command.
	if not M.CommandInfoed and GetDistance(M.Player, M.Command) < 50.0 then
		M.Aud1 = AudioMessage("bdmisn2102.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOn(M.Nav[2]);
		M.CommandInfoed = true;
		M.UpdateObjectives = true;
	end
	
	-- Is Power1 Dead yet?
	if not M.Power1Dead and (not IsAlive(M.Power1[1]) and not IsAlive(M.Power1[2]) and not IsAlive(M.Power1[3]) and not IsAlive(M.Power1[4])) then
		M.Aud1 = AudioMessage("bdmisn2103.wav");
		SetObjectiveOff(M.Nav[2]);
		SetObjectiveOn(M.Nav[3]);
		M.Power1Dead = true;
		M.UpdateObjectives = true;
	end
	
	-- Is Power2 Dead yet?
	if not M.Power2Dead and (not IsAlive(M.Power2[1]) and not IsAlive(M.Power2[2]) and not IsAlive(M.Power2[3]) and not IsAlive(M.Power2[4])) then
		M.Aud1 = AudioMessage("bdmisn2104.wav");
		CameraReady();
		SetObjectiveOff(M.Nav[3]);
		M.Power2Dead = true;
		-- Spawn Convoy.
		M.Tug = BuildObject("avhaul", 2, "spawn_tug");
		SetMaxHealth(M.Tug, 0); -- This is invincible.
		M.APC = BuildObject("avapc", 2, "spawn_apc");
		M.Tank1 = BuildObject("avtank", 2, "spawn_tank1");
		M.Tank2 = BuildObject("avtank", 2, "spawn_tank2");
		M.Tank3 = BuildObject("avtank", 2, "spawn_tank3");
		-- Give them their orders.
		Pickup(M.Tug, M.Relic, 1);
		Follow(M.APC, M.Tug, 1);
		-- Redundant, setup alternate location or pathpoint to goto incase comm is already dead.
		Goto(M.Tank1, M.CommTower, 1);
		Goto(M.Tank2, M.CommTower, 1);
		Goto(M.Tank3, M.CommTower, 1);		
	end
	-- Do the cinimatic
	if M.Power2Dead and not M.ConvoyCinDone and (CameraPath("convoy_cin", 2000, 2000, M.Cafe) or CameraCancelled()) then -- or IsAudioMessageDone(aud1) then
		CameraFinish();
		--SetObjectiveOn(M.Nav[4]);
		SetObjectiveOn(M.Comm);
		M.ConvoyCinDone = true;
		M.UpdateObjectives = true;
	end
	
	-- Watch for Tug to pickup Relic.
	if M.Power2Dead and not M.TugGotRelic and GetTug(M.Relic) == M.Tug then
		M.TugGotRelic = true;
		Goto(M.Tug, "spawn_svfigh1", 1);
	end
	
	-- Now watch for Mr Tug to vamoosh.
	if M.TugGotRelic and not M.TugAway and GetDistance(M.Tug, "spawn_svfigh1") < 25.0 then
		RemoveObject(M.Relic);
		RemoveObject(M.Tug);
		RemoveObject(M.APC);
		-- Original mision also removed Tank1 - 3, but I'm leaving them for realism/make it more difficult. They guard the Comm tower. -GBD
	end

	-- If Patrol 3 dies, spawn reinforcements.
	if not M.Patrol3Dead and not IsAlive(M.Patrol3_1) and not IsAlive(M.Patrol3_2) then
		M.Patrol3Dead = true;
		M.Reinforcements[1] = BuildObject("svfigh", 2, "spawn_svfigh1");
		M.Reinforcements[2] = BuildObject("svfigh", 2, "spawn_svfigh2");
		M.Reinforcements[3] = BuildObject("svrckt", 2, "spawn_svrckt1");
		M.Reinforcements[4] = BuildObject("svrckt", 2, "spawn_svrckt2");
		M.Reinforcements[5] = BuildObject("svhraz", 2, "spawn_svhraz");
		-- Send the reinforcements to Nav 4.
		for i = 1, 5 do
			Goto(M.Reinforcements[i], M.Nav[4], 1);
		end
	end
	
	-- Win Conditions:
	if (not M.MissionOver) and M.Power1Dead and M.Power2Dead and M.CommandInfoed and not IsAlive(M.CommTower) then
		SucceedMission(GetTime()+5.0, "bdmisn21wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	if (not M.MissionOver) and not M.CommandInfoed and not IsAlive(M.Command) then
		FailMission(GetTime()+5.0, "bdmisn21ls.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end
