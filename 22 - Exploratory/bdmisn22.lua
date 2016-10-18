-- Battlezone: Rise of the Black Dogs, Black Dog Mission 22 written by General BlackDragon.

local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
OpeningCinDone = false, -- Intro cinimatic camera.

HangarInfoed = false, -- Got intel?
--Radar1Warn = false, -- Warning VO for Radar 1
--Radar2Warn = false, -- Warning VO for Radar 2
--Radar3Warn = false, -- Warning VO for Radar 3
--Radar1Trigger = false, -- Triggered reinforcements for Radar 1.
--Radar2Trigger = false, -- Triggered reinforcements for Radar 2.
--Radar3Trigger = false, -- Triggered reinforcements for Radar 3.
SupplyReached = false, -- Are we there yet?
TugAquired = false, -- Are we in the tug? --NEW, you should get in the tug.
ShipAquired = false, -- Similar to above, but allows you to not steal tug? flags for the IsPerson check in original code. -GBD
ControlDead = false, -- Killed the Control Tower yet? --Why is it an sbmbld anyway? :P -GBD
MammothReached = false, -- Are we in range of mammoth?
MammothInfoed = false, -- We got it, now we run!
SafetyReached = false, -- Are we safe yet?

MissionOver = false, -- Yay!

-- Floats (realy doubles in Lua)
MammothTime = 0, -- Time to sit at Mammoth.

-- Handles
Player = nil,
Nav = { },
Mammoth = nil,
--Radar1 = nil,
--Radar2 = nil,
--Radar3 = nil,
ControlTower = nil,
Hangar = nil,
Supply = nil,

-- Radar Arrays.
--Radar { RadarHandle = nil, RadarWarn = false, RadarTrigger = false, }
Radar = { },

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

    print("Black Dog Mission 22 Lua created by General BlackDragon");

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
		SetIndependence(M.Mammoth, 0); -- Mammoth doesn't respond or do anything in this mission.
		M.Hangar = GetHandle("hangar");
		--SetMaxHealth(M.Hangar, 0); -- This is invincible. -- Omitted, made a lose condition instead. -GBD
		M.Supply = GetHandle("supply");
		--SetMaxHealth(M.Supply, 0); -- This is invincible. -- Omitted, used GetDistance Nav 2 instead. -GBD
		
		for i = 1, 3 do 
			M.Radar[i] = { RadarHandle = GetHandle("radar"..i), RadarWarn = false, RadarTrigger = false }
		end
		
		M.Tug = GetHandle("tug");
		M.ControlTower = GetHandle("control");
		
		for i = 1, 5 do 
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 5 then
				SetObjectiveName(M.Nav[i], "Rendezvous Point");
			else
				SetObjectiveName(M.Nav[i], "Navpoint " .. i);
			end
			SetMaxHealth(M.Nav[i], 0);
		end
				
		-- Units in BZN set to do wierd thing? Idk. Reset Patrols here. -GBD
		Patrol(GetHandle("patrol1_1"), "patrol_1", 1);
		for i = 1, 4 do
			Patrol(GetHandle("patrol2_" .. i), "patrol_2", 1);
		end
		
		M.StartDone = true;
		
		-- Start up the mission.
		CameraReady();
		Aud1 = AudioMessage("bdmisn2201.wav");
	end
	
	-- Handle Objectives.
	if M.UpdateObjectives then
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		if not M.HangarInfoed then
			-- NEW: If hanger dies before intel, just fail mission.
			if not IsAlive(M.Hangar) then
				AddObjective("bdmisn2201.otf", "RED");
			else
				AddObjective("bdmisn2201.otf", "WHITE");
			end
		else
			-- We're at the Supply.
			if not M.SupplyReached then
				AddObjective("bdmisn2202.otf", "WHITE");
			else
				-- If your not in a ship, get in the tug?
				if not M.ShipAquired and not M.TugAquired then
					AddObjective("bdmisn2203.otf", "WHITE");
				end
				
				-- Are u in a ship? if so, continue.
				if M.ShipAquired then
					-- Congrats if u got in the tug, otherwise forget about it.
					if M.TugAquired then
						AddObjective("bdmisn2203.otf", "GREEN");
					end
					
					-- Destroy Cotnrol Tower.
					if not M.ControlDead then
						AddObjective("bdmisn2204.otf", "WHITE");
					else
						-- Goto Mammoth.
						if not M.MammothReached then
							AddObjective("bdmisn2205.otf", "WHITE");
						else
							-- Info Mammoth.
							if not M.MammothInfoed then
								AddObjective("bdmisn2206.otf", "WHITE");
							else
								AddObjective("bdmisn2207.otf", "GREEN");
								-- At safe distance yet?
								if not M.SafetyReached then
									AddObjective("bdmisn2208.otf", "WHITE");
								else
									AddObjective("bdmisn2208.otf", "GREEN");
								end															
							end						
						end					
					end				
				end
			end
		end
		
	end
	
	-- Do the opening Camera. Reveal Deus Ex Ceteri's Beast! 
	if not M.OpeningCinDone and CameraPath("camera_path", 1000, 2000, M.Mammoth) or CameraCancelled() then
		CameraFinish();
		SetObjectiveOn(M.Nav[1]); --SetUserTarget(M.Nav[1]);
		M.OpeningCinDone = true;
		M.UpdateObjectives = true;
	end
	
	-- Give player ammo every second. -- Cut, instead gave BZN a special bsuser22.odf with high powered sniper rifle and 100 ammo. -GBD
	--[[
	if(GetTime() / GetFrame()) then -- Okay, so I also CBA to remember how to do BZ1's finicky timing thing, since code runs at FPS and not a static rate like it should. -GBD
		AddAmmo(M.Player, 3);
	end
	--]]
	
	-- Radar Arrays, each one has a warning and a spawn trigger.
	for i = 1, 3 do
		if IsAlive(M.Radar[i].RadarHandle) then
			if not M.Radar[i].RadarWarn and GetDistance(M.Player, M.Radar[i].RadarHandle) < 150.0 then
				M.Aud1 = AudioMessage("bdmisn2202.wav");
				M.Radar[i].RadarWarn = true;
			end
			
			if not M.Radar[i].RadarSpawn and GetDistance(M.Player, M.Radar[i].RadarHandle) < 100.0 then
				local Path = "spawn_radar" .. i;
				Attack(BuildObject("svfigh", 2, Path), M.Player);
				Attack(BuildObject("svhraz", 2, Path), M.Player);
				Attack(BuildObject("svhraz", 2, Path), M.Player);
				M.Radar[i].RadarSpawn = true;
			end	
		end
	end
	
	-- Inspect the Hangar.
	if not M.HangarInfoed and IsAlive(M.Hangar) and GetDistance(M.Player, M.Hangar) < 50.0 then
		Aud1 = AudioMessage("bdmisn2203.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOn(M.Nav[2]);
		M.HangarInfoed = true;
		M.UpdateObjectives = true;
	end
	
	-- Go to Supply.
	if not M.SupplyReached and (not IsAlive(M.Tug) or GetDistance(M.Player, M.Tug) < 50.0) then --GetDistance(M.Player, M.Supply) < 50.0 -- Old code did this, and made it invulnerable. I prefer to allow pewpew all around. -GBD
		M.SupplyReached = true;
		M.UpdateObjectives = true;
	end
	-- New, old code just checked if IsPerson(M.Player) then. Now does the opposite, to see if you're in a ship, or stole tug.
	if not M.TugAquired and M.Player == M.Tug then
		M.TugAquired = true;
	end
	-- You got in the Tug, or had a Limo pick you up elsewhere...
	if M.SupplyReached and not M.ShipAquired and not IsPerson(M.Player) then
		Aud1 = AudioMessage("bdmisn2204.wav");
		SetObjectiveOff(M.Nav[2]);
		SetObjectiveOn(M.Nav[3]);
		M.ShipAquired = true;
		M.UpdateObjectives = true;
	end
	
	-- Destroy Shield Control Tower.
	if not M.ControlDead and M.ShipAquired and not IsAlive(M.ControlTower) then
		Aud1 = AudioMessage("bdmisn2205.wav");
		SetObjectiveOff(M.Nav[3]);
		SetObjectiveOn(M.Nav[4]);
		M.ControlDead = true;
		M.UpdateObjectives = true;
	end
	
	-- !! Improvement? Add in actual shield, do deactivation here?
	
	-- Reached mammoth, grab intel.
	if M.ControlDead and not M.MammothReached and GetDistance(M.Player, M.Mammoth) < 75 then
		M.MammothTime = GetTime() + 10.0; -- Wait 10 seconds to gather info.
		M.MammothReached = true;
		M.UpdateObjectives = true;
	end
	-- Times up, time to run away!
	if M.MammothReached and not M.MammothInfoed and GetTime() > M.MammothTime then
		Aud1 = AudioMessage("bdmisn2206.wav");
		StartCockpitTimer(120, 60, 30);
		SetObjectiveOff(M.Nav[4]);
		SetObjectiveOn(M.Nav[5]);
		M.MammothInfoed = true;
		M.UpdateObjectives = true;
	end
	
	-- Win / Lose conditions.
	if not M.MissionOver then
	
		-- Win Conditions:
		if M.MammothInfoed and GetDistance(M.Player, M.Nav[5]) < 50.0 then
			SucceedMission(GetTime()+5.0, "bdmisn22wn.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
		
		-- Lose Conditions:
		-- Kill Hanger too soon?
		if not M.HangarInfoed and not IsAlive(M.Hangar) then
			FailMission(GetTime()+5.0, "bdmisn22l3.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
		-- Kill Mammoth too soon?
		if  not M.MammothInfoed and not IsAlive(M.Mammoth) then
			FailMission(GetTime()+5.0, "bdmisn22l1.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
		-- Fail to escape in time?
		if M.MammothInfoed and GetCockpitTimer() == 0 then
			FailMission(GetTime(), "bdmisn22l2.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
	end
end
