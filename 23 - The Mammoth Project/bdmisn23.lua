-- Battlezone: Rise of the Black Dogs, Black Dog Mission 23 written by General BlackDragon.

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
Nav1Reached = false, -- Are we at nav1 yet? 
DecoyTriggered = false, -- It's a Trap!
TrapEscaped = false, -- Whew, close one!
MammothStolen = false, -- Steal the Mammoth!
MammothDead = false, -- You can't kill something that's extinct.
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

    print("Black Dog Mission 23 Lua created by General BlackDragon");

end

function AddObject(h)

	local Team = GetTeamNum(h);

end

function DeleteObject(h)

	
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0); -- Nope.
		M.MammothDecoy = GetHandle("badmammoth");
		SetIndependence(M.MammothDecoy, 0); -- Nope.

		M.Nav[1] = GetHandle("nav1");
		SetObjectiveName(M.Nav[1], "Navpoint 1");
		M.Nav[2] = GetHandle("nav2");
		SetObjectiveName(M.Nav[2], "Pickup Zone");
		-- In BZ64, navs are invincible, maybe keep it that way for now. (units in this mission use navs to goto)
		for i = 1, 2 do
			SetMaxHealth(M.Nav[i], 0);
		end
			
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
		M.Aud1 = AudioMessage("bdmisn2301.wav");
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
					AddObjective("bdmisn2301.otf", "WHITE");
				else
					-- but bad news!
					if not M.TrapEscaped then
						AddObjective("bdmisn2302.otf", "WHITE");
					else -- Go find me a Mammoth.
						AddObjective("bdmisn2302.otf", "GREEN");
						AddObjective("bdmisn2303.otf", "WHITE");
					end
				end		
			else -- Get to the drop zone.
				AddObjective("bdmisn2304.otf", "WHITE");
			end
		else -- ITS DEAD! NOOOOO! NEW Fail objective. -GBD
			AddObjective("bdmisn2305.otf", "RED");
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
		M.Aud1 = AudioMessage("bdmisn2302.wav");
		M.DecoyTriggered = true;
	end
	-- Okay, your safe.
	if M.DecoyTriggered and not M.TrapEscaped and GetDistance(M.Player, M.Nav[1]) > 400.0 then
		M.Aud1 = AudioMessage("bdmisn2303.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOn(M.Mammoth);
		M.TrapEscaped = true;
		M.UpdateObjectives = true;
	end
	
	-- Did you do the deed yet?
	if not M.MammothStolen and M.Player == M.Mammoth then
		M.Aud1 = AudioMessage("bdmisn2304.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOff(M.Mammoth);
		SetObjectiveOn(M.Nav[2]);
		M.MammothStolen = true;
		M.UpdateObjectives = true;
	end
	
	-- Win Conditions:
	if not M.MissionOver and M.MammothStolen and M.Player == M.Mammoth and GetDistance(M.Player, M.Nav[2]) < 50.0 then
		SucceedMission(GetTime()+5.0, "bdmisn23wn.des");
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
	-- Lose Conditions
	if not M.MissionOver and not IsValid(M.Mammoth) then
		FailMission(GetTime()+5.0, "bdmisn23l1.des");
		M.MammothDead = true;
		M.MissionOver = true;
		M.UpdateObjectives = true;
	end
	
end
