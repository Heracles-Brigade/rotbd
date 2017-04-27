--[[
	Contributors:
   - Seqan
	 - GBD
--]]
require("bz_logging");

local M = { --Sets mission flow and progression. Booleans will be changed to "true" as mission progresses. Necessary for save files to function as well as objective flow in later if statements.
UpdateObjectives = false,
StartDone = false, 
OpeningCinDone = false, --Forces intro to play
IsDetected = false,
HangarInfoed = false,
SupplyReached = false,
TugAquired = false,
ShipAquired = false,
ControlDead = false,
MammothReached = false,
MammothInfoed = false,
SafetyReached = false,
MissionOver = false,
MammothTime = 0,
RadarTime = 0,
-- Handles; values will be assigned during mission setup and play
Player = nil,
Nav = { },
Tug = nil,
Mammoth = nil,
ControlTower = nil,
Hangar = nil,
Supply = nil,
Radar = { },
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
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0); -- Mammoth shouldn't respond or do anything in this mission.
		M.Hangar = GetHandle("hangar");
		M.Supply = GetHandle("supply");
		M.Tug = GetHandle("tug");
		KillPilot(M.Tug);
		M.ControlTower = GetHandle("control");
		SetPerceivedTeam(M.Player, 2); -- Make sure player isn't detected right away.
		for i = 1, 3 do 
			M.Radar[i] = { RadarHandle = GetHandle("radar"..i), RadarWarn = false, RadarTrigger = false }
		end
		
		for i = 1, 5 do
			M.Nav[i] = GetHandle("nav" .. i);
			if i == 5 then
				SetObjectiveName(M.Nav[i], "Extraction Point");
			else
				SetObjectiveName(M.Nav[i], "Nav " .. i);
			end
			SetMaxHealth(M.Nav[i], 0);
		end
		
		-- Old script said the patrol units behave oddly. Patrol command here to make sure they behave as intended
		Patrol(GetHandle("patrol1_1"), "patrol_1", 1);
		for i =1, 4 do
			Patrol(GetHandle("patrol2_" .. i), "patrol_2", 1);
		end
		
		
		M.StartDone = true;
		
		-- Pre-play setup complete. Time to start the shit.
		CameraReady();
		Aud1 = AudioMessage("rbdnew0201.wav");
	end
	
	if M.UpdateObjectives then --This entire function controls objective bubble and makes sure that objectives can flow in a linear order.
	
		ClearObjectives();
		M.UpdateObjectives = false;
		
		if not M.IsDetected then
			AddObjective("rbdnew0200.otf", "WHITE");
		else
			if not M.MammothReached then
				AddObjective("rbdnew0200.otf", "RED");
			end
		end
		
		if not M.HangarInfoed then
			-- NEW: If hanger dies before acquiring intel, just fail mission. Should be impossible unless we have cheating players. Joke's on them! They failed the mission! HA!
			if not IsAlive(M.Hangar) then
				AddObjective("rbdnew0201.otf", "RED");
			else
				AddObjective("rbdnew0201.otf", "WHITE");
			end
		else
			-- We're at the Supply.
			if not M.SupplyReached then
				AddObjective("rbdnew0202.otf", "WHITE");
			else
				-- If your not in a ship, get in the tug?
				if not M.ShipAquired and not M.TugAquired then
					AddObjective("rbdnew0203.otf", "WHITE");
				end
				
				-- Tug Acquired
				if M.ShipAquired then
					if M.TugAquired then
						AddObjective("rbdnew0203.otf", "GREEN");
					end
					
					-- Destroy Control Tower.
					if not M.ControlDead then
						AddObjective("rbdnew0204.otf", "WHITE");
					else
						-- Goto Mammoth.
						if not M.MammothReached then
							AddObjective("rbdnew0205.otf", "WHITE");
						else
							-- Info Mammoth.
							if not M.MammothInfoed then
								AddObjective("rbdnew0206.otf", "WHITE");
							else
								AddObjective("rbdnew0207.otf", "GREEN");
								-- At safe distance yet?
								if not M.SafetyReached then
									AddObjective("rbdnew0208.otf", "WHITE");
								else
									AddObjective("rbdnew0208.otf", "GREEN");
								end															
							end						
						end					
					end				
				end
			end
		end	
	end
	
	if not M.IsDetected and GetPerceivedTeam(M.Player) == 1 then
		M.IsDetected = true;
		M.UpdateObjectives = true;
	end
	
	--Opening Cinematic. Show off Deus Ex's wonderous creation!
	if not M.OpeningCinDone and CameraPath("camera_path", 1000, 2000, M.Mammoth) or CameraCancelled() then
		CameraFinish();
		SetObjectiveOn(M.Nav[1]);
		M.OpeningCinDone = true;
		M.UpdateObjectives = true;
	end
	
	--Radar tower detection script
	for i = 1, 3 do
		if IsAlive(M.Radar[i].RadarHandle) then
			if not M.Radar[i].RadarWarn and GetDistance(M.Player, M.Radar[i].RadarHandle) < 100.0 then
				M.Aud1 = AudioMessage("rbdnew0202.wav");
				M.RadarTime = GetTime();
				M.Radar[i].RadarWarn = true;
				StartCockpitTimer(30, 15, 5);
			else
				if M.Radar[i].RadarWarn then
					if GetDistance(M.Player, M.Radar[i].RadarHandle) > 100.0 then
						Aud1 = AudioMessage("rbdnew0208.wav");
						M.RadarTime = 0;
						M.Radar[i].RadarWarn = false;
						StopCockpitTimer();
						HideCockpitTimer();
					else
						if GetTime() - M.RadarTime > 30.0 then
							M.IsDetected = true;
							M.UpdateObjectives = true;
						end
					end
				end
			end
			
		end
	end
	
	if not M.HangarInfoed and IsAlive(M.Hangar) and GetDistance(M.Player, M.Hangar) < 50.0 then
		Aud1 = AudioMessage("rbdnew0203.wav");
		SetObjectiveOff(M.Nav[1]);
		SetObjectiveOn(M.Nav[2]);
		M.HangarInfoed = true;
		M.UpdateObjectives = true;
	end
		
	if not M.TugAquired and M.Player == M.Tug then
		BuildObject("bvslf", 1, "NukeSpawn", 1);
		SetMaxScrap(1, 20);
		SetScrap(1, 20);
		M.TugAquired = true;
		M.ShipAquired = true;
		M.UpdateObjectives = true;
		Aud1 = AudioMessage("rbdnew0204.wav");
		SetObjectiveOff(M.Nav[2]);
		SetObjectiveOn(M.Nav[3]);
	end
	
	if not M.ControlDead and M.ShipAquired and not IsAlive(M.ControlTower) then
		Aud1 = AudioMessage("rbdnew0205.wav");
		SetObjectiveOff(M.Nav[3]);
		SetObjectiveOn(M.Nav[4]);
		M.ControlDead = true;
		M.UpdateObjectives = true;
	end
	
	if M.ControlDead and not M.MammothReached and GetDistance(M.Player, M.Mammoth) < 75 then
		M.MammothTime = GetTime() + 10.0; -- Wait 10 seconds to gather info.
		M.MammothReached = true;
		M.UpdateObjectives = true;
		Aud1 = AudioMessage("rbdnew0209.wav");
	end
	
	if M.MammothReached and not M.MammothInfoed and GetTime() > M.MammothTime then
		Aud1 = AudioMessage("rbdnew0206.wav");
		StartCockpitTimer(120, 60, 30);
		SetObjectiveOff(M.Nav[4]);
		SetObjectiveOn(M.Nav[5]);
		M.MammothInfoed = true;
		M.UpdateObjectives = true;
		SetPerceivedTeam(M.Player, 1);
	end
		
		
	
	-- Win / Lose conditions.
	if not M.MissionOver then
	
		-- Win Conditions:
		if M.MammothInfoed and GetDistance(M.Player, M.Nav[5]) < 50.0 then
			Aud1 = AudioMessage("rbdnew0210.wav");
			SucceedMission(GetTime()+5.0, "rbdnew02wn.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
			M.SafetyReached = true;
		end
		
		-- Lose Conditions:
		
		if not M.HangarInfoed and not IsAlive(M.Hangar) then
			FailMission(GetTime()+5.0, "rbdnew02l3.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end

		if  not IsAlive(M.Mammoth) then --not M.MammothInfoed and 
			FailMission(GetTime()+5.0, "rbdnew02l1.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
		
		if M.MammothInfoed and GetCockpitTimer() == 0 then
			FailMission(GetTime(), "rbdnew02l2.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
		
		if M.IsDetected and not M.MammothReached then
			Aud1 = AudioMessage("rbdnew0207.wav");
			FailMission(GetTime() + 5.0, "rbdnew02l4.des");
			M.MissionOver = true;
			M.UpdateObjectives = true;
		end
	end
end