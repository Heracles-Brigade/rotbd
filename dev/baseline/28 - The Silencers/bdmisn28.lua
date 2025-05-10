-- Battlezone: Rise of the Black Dogs, Black Dog Mission 28 written by General BlackDragon.


;


local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
Power1Murder = false, -- Murder.
Power2Death = false, -- Death.
Power3Kill = false, -- Kill.
TransmissionDone = false, -- You got it!
MeetGriggs = false, -- Time to leave.
TimeUp = false, -- Uh Oh...
GriggsDead = false, -- Oh crap...
MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)
WaitTimer = 0,

-- Handles
Player = nil,
Griggs = nil, -- Woohoo, another charachter!
Nav = { },
Power = { },
Comm = { },
Attackers = { },

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

    print("Black Dog Mission 28 Lua created by General BlackDragon");

end

function AddObject(h)

	local Team = GetTeamNum(h);

end

function DeleteObject(h)

	
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		for i = 1, 3 do
			M.Comm[i] = GetHandle("comm" .. i);
			M.Power[i] = GetHandle("power" .. i);
			SetMaxHealth(M.Comm[i], 0); -- These can't be killed.
		end
		
		for i = 1, 4 do
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 4 then
				SetObjectiveName(M.Nav[i], "Pickup Zone");
			else
				SetObjectiveName(M.Nav[i], "Navpoint " .. i);
			end
			SetMaxHealth(M.Nav[i], 0);
		end
		
		for i = 1, 6 do
			BuildObject("avartl", 2, "spawn_artl" .. i);
		end
		
		Patrol(GetHandle("avwalk1"), "walker1_path");
		Patrol(GetHandle("avwalk2"), "walker2_path");
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("bdmisn2801.wav");
		StartCockpitTimer(300, 60, 30);
		SetObjectiveOn(M.Nav[1]);
		M.UpdateObjectives = true;
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		-- Objective 1, kill power.
		if not M.Power3Kill then
			if not M.Power1Murder then
				if not M.TimeUp then
					AddObjective("bdmisn2801.otf", "WHITE");
				else
					AddObjective("bdmisn2801.otf", "RED");
				end
			else -- One down, kill 2nd.
				if not M.Power2Death then
					if not M.TimeUp then
						AddObjective("bdmisn2802.otf", "WHITE");
					else
						AddObjective("bdmisn2802.otf", "RED");
					end
				else -- Two down, kill 3rd.
					if not M.TimeUp then
						AddObjective("bdmisn2803.otf", "WHITE");
					else
						AddObjective("bdmisn2803.otf", "RED");
					end
				end
			end
		else -- All  3 power are dead, do transmisison.
			if not M.TransmissionDone then
				AddObjective("bdmisn2804.otf", "WHITE");
			else -- Transmission complete, show pretty green success objective.
				if not M.MeetGriggs then
					AddObjective("bdmisn2805.otf", "GREEN");
				else -- Okay, go meet Griggs. We should really make him talk...
					if not M.MissionOver then
						AddObjective("bdmisn2806.otf", "WHITE");
					else -- NEW: If Griggs dies, you lose.
						if M.GriggsDead then
							AddObjective("bdmisn2806.otf", "RED");
						else
							AddObjective("bdmisn2806.otf", "GREEN");
						end
					end
				end			
			end		
		end
	end
		
	-- Spawn pilots when you get close. (IMPROVEMENT: OR APC GETS CLOSE!)
	if not M.Power1Murder and not IsAlive(M.Power[1]) then
		M.Aud1 = AudioMessage("bdmisn2802.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOn(M.Nav[2]);
		M.Power1Murder = true;
		M.UpdateObjectives = true;
	end
	-- Power 2
	if M.Power1Murder and not M.Power2Death and not IsAlive(M.Power[2]) then
		M.Aud1 = AudioMessage("bdmisn2803.wav");
		SetObjectiveOff(M.Nav[2]);
		SetObjectiveOn(M.Nav[3]);
		M.Power2Death = true;
		M.UpdateObjectives = true;
	end
	-- Power 3
	if M.Power2Death and not M.Power3Kill and not IsAlive(M.Power[3]) then
		M.WaitTimer = GetTime() + 5.0;
		M.Power3Kill = true;
		M.UpdateObjectives = true;
	end
	
	-- Transmission.
	if M.Power3Kill and not M.TransmissionDone and GetTime() > M.WaitTimer then
		M.WaitTimer = GetTime() + 10.0;
		StopCockpitTimer();
		HideCockpitTimer();
		M.TransmissionDone = true;
		M.UpdateObjectives = true;
	end
	
	-- Meet Griggs:
	if M.TransmissionDone and not M.MeetGriggs and GetTime() > M.WaitTimer then
		M.Aud1 = AudioMessage("bdmisn2804.wav");
		SetObjectiveOff(M.Nav[3]);
		SetObjectiveOn(M.Nav[4]);
		-- Spawn NSDF forces:
		for i = 1, 8 do -- NOTE: There are 9 spawns, last one is unused. -GBD
			if i == 1 then
				M.Attackers[i] = BuildObject("avhraz", 2, "spawn_nsdf" .. i);
			elseif i < 6 then
				M.Attackers[i] = BuildObject("avtank", 2, "spawn_nsdf" .. i);
			elseif i < 8 then
				M.Attackers[i] = BuildObject("avhraz", 2, "spawn_nsdf" .. i);
			else
				M.Attackers[i] = BuildObject("avrckt", 2, "spawn_nsdf" .. i);
			end
			-- Only these ships move to attack, rest stay put. May make them do something else?
			if i < 5 then
				Attack(M.Attackers[i], M.Player, 1);
			--else 
				-- Make other ships do something else? Goto M.Nav[4]?  Too hard? 
			end
		end
		M.Griggs = BuildObject("bvtank", 1, "spawn_griggs");
		SetObjectiveName(M.Griggs, "Pvt. Griggs");
		Stop(M.Griggs, 1); -- He can't respond to commands. -- Why doesn't this work? :(
		--SetIndependence(M.Girggs, 0); -- Brain dead too?
		M.MeetGriggs = true;
		M.UpdateObjectives = true;
	end
	-- Rude Hack,...Ugh.
	if M.MeetGriggs then
		Stop(M.Griggs, 1); -- He can't respond to commands. -- Why doesn't this work? :(
	end

	-- Win Conditions:
	if not M.MissionOver and M.MeetGriggs and GetDistance(M.Player, M.Nav[4]) < 30 then
		SucceedMission(GetTime()+5.0, "bdmisn28wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	if not M.MissionOver and not M.Power3Kill and GetCockpitTimer() == 0 then
		FailMission(GetTime()+5.0, "bdmisn28l1.des");
		M.TimeUp = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- IMPROVEMENT: Mission fail if Griggs is killed?
	if not M.MissionOver and M.MeetGriggs and not IsAlive(M.Griggs) then
		FailMission(GetTime()+5.0, "bdmisn28l2.des");
		M.GriggsDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;	
	end
	
end
