-- Battlezone: Rise of the Black Dogs, Improved Mission 2 coded by Seqan, derived from GBD's original script


require("bz_logging");

local M = { --Sets mission flow and progression. Booleans will be changed to "true" as mission progresses. Necessary for save files to function as well as objective flow in later if statements.
StartDone = false, 
OpeningCinDone = false, --Forces intro to play
IsDetected = false,
HangarInfoed = false,
TugAquired = false,
ControlDead = false,
MammothReached = false,
MammothInfoed = false,
SafetyReached = false,
MissionOver = false,
MammothTime = 0,
RadarTime = 0,
LastShieldTime = 0,
-- Handles; values will be assigned during mission setup and play
Player = nil,
ObjectiveNav = nil,
NavCoord = { },
Defenders = { },
NextDefender = 1,
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
    print("Black Dog Improved Mission 2 coded by Seqan and Vemahk");
end

local function UpdateObjectives() --This entire function controls objective bubble and makes sure that objectives can flow in a linear order.
	ClearObjectives();
	
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
		if not M.TugAquired then
			AddObjective("rbdnew0203.otf", "WHITE");
		else
			AddObjective("rbdnew0203.otf", "GREEN");
			if not M.ControlDead then -- Destroy Control Tower.
				AddObjective("rbdnew0204.otf", "WHITE");
			else
				if not M.MammothReached then -- Goto Mammoth.
					AddObjective("rbdnew0205.otf", "WHITE");
				else
					if not M.MammothInfoed then -- Stream Mammoth data.
						AddObjective("rbdnew0206.otf", "WHITE");
					else
						AddObjective("rbdnew0207.otf", "GREEN");
						if not M.SafetyReached then -- At safe distance yet?
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

local function SpawnNav(num) -- Spawns the Nth Nav point.
	local nav = BuildObject("apcamr", 1, M.NavCoord[num]); -- Make the nav from the harvested coordinates.
	SetObjectiveName(nav, "Nav "..num); -- Set its name
	if num == 5 then
		SetObjectiveName(nav, "Extraction Point"); -- If it's the 5th nav, change its name. This is the name it checks for for the Win Condition; if you change this, change the win condition script as well.
	end
	SetMaxHealth(nav, 0); -- Can't go boom-boom. I accidentally destroyed Nav 3 with the DW before this.
	
	-- Switches the active objective from the old nav to the new nav.
	SetObjectiveOff(ObjectiveNav);
	SetObjectiveOn(nav);
	ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
end

local function SpawnFromTo(odf, fp, fpp, tp)
	local obj = BuildObject(odf, 2, fp, fpp)
	Goto(obj, tp, 0);
	SetLabel(obj, fp.."_"..M.NextDefender);
	M.Defenders[M.NextDefender] = obj;
	M.NextDefender = M.NextDefender + 1;
end

-- 
local function SpawnArmy()
	SpawnFromTo("svfigh", "patrol_2", 13, "def1");
	SpawnFromTo("svfigh", "patrol_2", 14, "def1");
	SpawnFromTo("svltnk", "patrol_2", 13, "def1");
	SpawnFromTo("svwalk", "def1", 1, "def1");
	
	SpawnFromTo("svtank", "patrol_2", 14, "def2");
	SpawnFromTo("svhraz", "patrol_2", 14, "def2");
	SpawnFromTo("svwalk", "def2", 1, "def2");
	
	SpawnFromTo("svtank", "patrol_2", 13, "def3");
	SpawnFromTo("svtank", "patrol_2", 13, "def3");
	SpawnFromTo("svrckt", "patrol_2", 15, "def3");
	SpawnFromTo("svrckt", "patrol_2", 13, "def3");
	
	SpawnFromTo("svtank", "patrol_2", 15, "def4");
	SpawnFromTo("svhraz", "patrol_2", 15, "def4");
	SpawnFromTo("svwalk", "def4", 1, "def4");
	
	SpawnFromTo("svltnk", "patrol_2", 14, "def5");
	SpawnFromTo("svfigh", "patrol_2", 15, "def5");
	SpawnFromTo("svfigh", "patrol_2", 13, "def5");
	SpawnFromTo("svwalk", "def5", 1, "def5");
end

local function keepOutside(h1,h2) -- This is the shield function for the Mammoth. Thank you, Mario
  local p = GetPosition(h2);
  local r = 625;
  local pp = GetPosition(h1);
  local dv = Normalize(pp-p);
  local vel2 = GetVelocity(h2);
  local d = Length(pp-p);
  local vel = GetVelocity(h1);
  local dprod = DotProduct(Normalize(vel),dv);
  local nvel = vel - dprod*dv;
  if(d < r) then
    local newp = (p + dv*r);
    local h = GetTerrainHeightAndNormal(newp);
    newp.y = math.max(h,newp.y);
    SetPosition(h1,newp);
    SetVelocity(h1,nvel);
  end
end

function Update()
	
	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0); -- Mammoth shouldn't respond or do anything in this mission.
		M.Hangar = GetHandle("hangar");
		M.Supply = GetHandle("supply");
		M.Tug = GetHandle("tug");
		RemovePilot(M.Tug);
		M.ControlTower = GetHandle("control");
		SetPerceivedTeam(M.Player, 2); -- Make sure player isn't detected right away.
		for i = 1, 3 do 
			M.Radar[i] = { RadarHandle = GetHandle("radar"..i), RadarWarn = false, RadarTrigger = false }
		end
		
		for i = 1, 5 do
			local navtmp = GetHandle("nav"..i); -- Harvests the current nav's coordinates then deletes it. The saved coordinates are used later to respawn the nav when it is needed.
			M.NavCoord[i] = GetPosition(navtmp);
			RemoveObject(navtmp);
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
	
	if not M.IsDetected and GetPerceivedTeam(M.Player) == 1 then
		M.IsDetected = true;
		UpdateObjectives();
	end
	
	--Opening Cinematic. Show off Deus Ex's wondrous creation!
	if not M.OpeningCinDone and CameraPath("camera_path", 1000, 2000, M.Mammoth) or CameraCancelled() then
		CameraFinish();
		SpawnNav(1);
		M.OpeningCinDone = true;
		UpdateObjectives();
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
							UpdateObjectives();
						end
					end
				end
			end
			
		end
	end
	
	if not M.HangarInfoed and IsAlive(M.Hangar) and GetDistance(M.Player, M.Hangar) < 50.0 then
		Aud1 = AudioMessage("rbdnew0203.wav");
		SpawnNav(2);
		M.HangarInfoed = true;
		UpdateObjectives();
	end
		
	if not M.TugAquired and M.Player == M.Tug then
		BuildObject("bvslf", 1, "NukeSpawn", 1);
		SetMaxScrap(1, 20);
		SetScrap(1, 20);
		M.TugAquired = true;
		UpdateObjectives();
		Aud1 = AudioMessage("rbdnew0204.wav");
		SpawnNav(3);
	end
	
	if not M.ControlDead then
		keepOutside(M.Player, M.Mammoth);
		if GetTime() >= M.LastShieldTime then
			M.LastShieldTime = GetTime() + 3.5;
			MakeExplosion("sdome", M.Mammoth);
		end
	end
	
	if not M.ControlDead and M.TugAquired and not IsAlive(M.ControlTower) then
		Aud1 = AudioMessage("rbdnew0205.wav");
		SpawnNav(4);
		M.ControlDead = true;
		SpawnArmy();
		UpdateObjectives();
	end
	
	if M.ControlDead and not M.MammothReached and GetDistance(M.Player, M.Mammoth) < 75 then
		M.MammothTime = GetTime() + 10.0; -- Wait 10 seconds to gather info.
		M.MammothReached = true;
		UpdateObjectives();
		Aud1 = AudioMessage("rbdnew0209.wav");
	end
	
    if M.MammothReached and not M.MammothInfoed and GetTime() > M.MammothTime then
        Aud1 = AudioMessage("rbdnew0206.wav");
        StartCockpitTimer(120, 60, 30);
        SpawnNav(5);
        M.MammothInfoed = true;
        UpdateObjectives();
        SetPerceivedTeam(M.Player, 1);
        for i=1, 18 do
            local tmp = M.Defenders[i];
            if GetOdf(tmp) ~= "svwalk" then
                Attack(tmp, M.Player);
            end
        end
    end
	
	-- Win / Lose conditions.
	if not M.MissionOver then
	
		-- Win Conditions:
		if M.MammothInfoed and GetObjectiveName(ObjectiveNav) == "Extraction Point" and GetDistance(M.Player, ObjectiveNav) < 50.0 then
			Aud1 = AudioMessage("rbdnew0210.wav");
			SucceedMission(GetTime()+5.0, "rbdnew02wn.des");
			M.MissionOver = true;
			M.SafetyReached = true;
			UpdateObjectives();
		end
		
		-- Lose Conditions:
		
		if not M.HangarInfoed and not IsAlive(M.Hangar) then
			FailMission(GetTime()+5.0, "rbdnew02l3.des");
			M.MissionOver = true;
			UpdateObjectives();
		end

		if  not IsAlive(M.Mammoth) then --not M.MammothInfoed and 
			FailMission(GetTime()+5.0, "rbdnew02l1.des");
			M.MissionOver = true;
			UpdateObjectives();
		end
		
		if M.MammothInfoed and GetCockpitTimer() == 0 then
			FailMission(GetTime(), "rbdnew02l2.des");
			M.MissionOver = true;
			UpdateObjectives();
		end
		
		if M.IsDetected and not M.MammothReached then
			Aud1 = AudioMessage("rbdnew0207.wav");
			FailMission(GetTime() + 5.0, "rbdnew02l4.des");
			M.MissionOver = true;
			UpdateObjectives();
		end
	end
end