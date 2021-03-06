--[[
	Contributors:
	 - Seqan
	 - GBD
	 - Vemahk
	 - Janne
--]]

local minit = require("minit")

local cmisnlib = require("cmisnlib");
local choose = cmisnlib.choose;

local audio = {
	intro = "rbdnew0301.wav",
	commwarn = "rbdnew0301W.wav",
	commclear = "rbdnew0302W.wav",
	inspect = "rbdnew0302.wav",
	tug = "rbdnew0303.wav",
	first_a = "rbdnew0304.wav",
	dayw = "rbdnew0305.wav",
	second_a = "rbdnew0306.wav",
	transint = "",
	backinrange = "",
	flee = "rbdnew0307.wav",
	win = "rbdnew0308.wav",
	lose1 = "rbdnew0301L.wav", --Mammoth Destroyed/sniped
	lose2 = "rbdnew0302L.wav", --Failed to extract on time
	lose3 = "rbdnew0303L.wav", --Detected, loser
	lose4 = "rbdnew0304L.wav", --Evidently you can't aim Day Wreckers
	lose5 = "rbdnew0305L.wav" --Why didn't you make a Day Wrecker?
}

local objectives = {
	Detection = "rbdnew0300.otf",
	Hanger = "rbdnew0301.otf",
	Tug = "rbdnew0303.otf",
	Mammoth1 = "rbdnew0302.otf",
	Control = "rbdnew0304.otf",
	Mammoth2 = "rbdnew0305.otf",
	TranStart = "rbdnew0306.otf",
	TranFin = "rbdnew0307.otf",
	Extract = "rbdnew0308.otf"
}

local M = { --Sets mission flow and progression. Booleans and values will be changed to "true" and appropriate names/integers as mission progresses. Necessary for save files to function as well as objective flow in later if statements.
StartDone = false, 
OpeningCinDone = false,
IsDetected = false,
HangarInfoed = false,
TugAquired = false,
ShieldDetected = false,
ControlDead = false,
MammothReached = false,
MammothReachedPrevious = false,
MammothInfoed = false,
SafetyReached = false,
MissionOver = false,
MammothTime = 0,
RadarTime = 0,
LastShieldTime = 0,
WreckTime1 = 0,
WreckTime2 = 0,
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
Wrecker = nil,
Armory = false,
Radar = { },
scrapFields = { },
Aud1 = 0
}

local function scrapFieldsFiller(p)
    local scrapFieldObjs = ObjectsInRange(35,p);
    local scrapFieldScrap = { };
    for obj in scrapFieldObjs do
        if GetClassLabel(obj) == "scrap" then
            table.insert(scrapFieldScrap,obj);
        end
    end
    M.scrapFields[p] = scrapFieldScrap;
end

function Start()
	scrapFieldsFiller("scrpfld1");
end

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

local function scrapRespawner()
	for path,field in pairs(M.scrapFields) do
		for i,scrap in ipairs(field) do
			if not IsValid(scrap) then
				local newScrap = BuildObject(choose("npscr1", "npscr2", "npscr3"),0,GetPositionNear(GetPosition(path),1,35));
				field[i] = newScrap;
			end
		end
	end
end

local function UpdateObjectives() --This entire function controls objective bubble and makes sure that objectives can flow in a linear order.
	ClearObjectives();
	
	if not M.IsDetected then
		AddObjective(objectives.Detection, "WHITE");
	else
		if not M.MammothReached then
			AddObjective(objectives.Detection, "RED");
		end
	end
	
	if not M.HangarInfoed then
		-- NEW: If hanger dies before acquiring intel, just fail mission. Should be impossible unless we have cheating players. Joke's on them! They failed the mission! HA!
		if not IsAlive(M.Hangar) then
			AddObjective(objectives.Hanger, "RED");
		else
			AddObjective(objectives.Hanger, "WHITE");
		end
	else
		if not M.TugAquired then
			AddObjective(objectives.Tug, "WHITE");
		else
			AddObjective(objectives.Tug, "GREEN");
			if not M.ShieldDetected then
				AddObjective(objectives.Mammoth1, "WHITE");
			else
				if not M.ControlDead then -- Destroy Control Tower.
					AddObjective(objectives.Control, "WHITE");
				else
					AddObjective(objectives.Control, "GREEN");
					if not M.MammothReached then -- Goto Mammoth.
						AddObjective(objectives.Mammoth2, "WHITE");
					else
						if not M.MammothInfoed then -- Stream Mammoth data.
							AddObjective(objectives.TranStart, "WHITE");
						else
							AddObjective(objectives.TranFin, "GREEN");
							if not M.SafetyReached then -- At safe distance yet?
								AddObjective(objectives.Extract, "WHITE");
							else
								AddObjective(objectives.Extract, "GREEN");
							end
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
	SetObjectiveOff(M.ObjectiveNav);
	SetObjectiveOn(nav);
	M.ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
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
	SpawnFromTo("svfigh", "armyspawn1", 1, "def1");
	SpawnFromTo("svfigh", "armyspawn1", 1, "def1");
	SpawnFromTo("svltnk", "armyspawn1", 1, "def1");
	SpawnFromTo("svwalk", "def1", 1, "def1");
	
	SpawnFromTo("svtank", "armyspawn2", 1, "def2");
	SpawnFromTo("svhraz", "armyspawn2", 1, "def2");
	SpawnFromTo("svwalk", "def2", 1, "def2");
	
	SpawnFromTo("svtank", "armyspawn3", 1, "def3");
	SpawnFromTo("svtank", "armyspawn3", 1, "def3");
	SpawnFromTo("svrckt", "armyspawn3", 1, "def3");
	SpawnFromTo("svrckt", "armyspawn3", 1, "def3");
	
	SpawnFromTo("svtank", "armyspawn4", 1, "def4");
	SpawnFromTo("svhraz", "armyspawn4", 1, "def4");
	SpawnFromTo("svwalk", "def4", 1, "def4");
	
	SpawnFromTo("svltnk", "armyspawn5", 1, "def5");
	SpawnFromTo("svfigh", "armyspawn5", 1, "def5");
	SpawnFromTo("svfigh", "armyspawn5", 1, "def5");
	SpawnFromTo("svwalk", "def5", 1, "def5");
end

local function keepOutside(h1,h2) -- This is the shield function for the Mammoth. Thank you, Janne
  local p = GetPosition(h2);
  local r = 40;
  local pp = GetPosition(h1);
  local dv = Normalize(pp-p);
  local vel2 = GetVelocity(h2);
  local d = Length(pp-p);
  local vel = GetVelocity(h1);
  local dprod = DotProduct(vel,-dv);
  local nvel = vel + dprod*dv*(1+GetTimeStep());
  if(d < r) then
    local newp = (p + dv*r);
    local h = GetTerrainHeightAndNormal(newp);
    newp.y = math.max(h,newp.y);
    SetPosition(h1,newp);
    SetVelocity(h1,nvel);
  end
end


function AddObject(h) -- check if daywrecker was spawned by the armory assuming player will have 0-1 scrap after building it
	local armory = GetArmoryHandle();
	
	if IsValid(armory) then
		if((not M.Wrecker) and GetClassLabel(h) == "daywrecker" and GetOwner(h) == armory) then
			M.Wrecker = h
		end
	end
end

function CreateObject(h)  

end

function Update()
	
	M.Player = GetPlayerHandle();
	scrapRespawner();
	
	if not M.StartDone then
		
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0); -- Mammoth shouldn't respond or do anything in this mission.
		M.Hangar = GetHandle("hangar");
		M.Supply = GetHandle("supply");
		M.Tug = GetHandle("tug");
		RemovePilot(M.Tug);
		M.ControlTower = GetHandle("control");
		SetMaxScrap(2,10000);
		SetPerceivedTeam(M.Player, 2); -- Make sure player isn't detected right away.
		for i = 1, 3 do 
			M.Radar[i] = { RadarHandle = GetHandle("radar"..i), RadarWarn = false, RadarTrigger = false }
		end
		
		for i = 1, 5 do
			local navtmp = GetHandle("nav"..i); -- Harvests the current nav's coordinates then deletes it. The saved coordinates are used later to respawn the nav when it is needed.
			M.NavCoord[i] = GetPosition(navtmp);
			RemoveObject(navtmp);
		end
		
		for i =1, 6 do
			Patrol(GetHandle("patrol1_" .. i), "patrol_1", 1);
		end
		for i =1, 10 do
			Patrol(GetHandle("patrol2_" .. i), "patrol_2", 1);
		end
		for i =1, 9 do
			Patrol(GetHandle("patrol3_" .. i), "patrol_3", 1)
		end
		
		
		M.StartDone = true;
		
		-- Pre-play setup complete. Time to start the shit.
		CameraReady();
		M.Aud1 = AudioMessage(audio.intro);
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
				M.Aud1 = AudioMessage(audio.commwarn);
				M.RadarTime = GetTime();
				M.Radar[i].RadarWarn = true;
				StartCockpitTimer(30, 15, 5);
			else
				if M.Radar[i].RadarWarn then
					if GetDistance(M.Player, M.Radar[i].RadarHandle) > 100.0 then
						Aud1 = AudioMessage(audio.commclear);
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
		M.Aud1 = AudioMessage(audio.inspect);
		SpawnNav(2);
		M.HangarInfoed = true;
		UpdateObjectives();
	end
	
	if not M.TugAquired and M.Player == M.Tug then
		M.TugAquired = true;
		UpdateObjectives();
		M.Aud1 = AudioMessage(audio.tug);
		SpawnNav(3)
	end
	
	if M.TugAquired and GetDistance(M.Player, M.Mammoth) < 225.0 and not M.ShieldDetected then
		BuildObject("bvslf", 1, "NukeSpawn", 1);
		M.Armory = true;
		SetMaxScrap(1, 20);
		SetScrap(1, 20);
		M.ShieldDetected = true;
		M.Aud1 = AudioMessage(audio.first_a);
		SpawnNav(4);
		UpdateObjectives();
	end
		
	
	if not M.ControlDead and M.OpeningCinDone then
		keepOutside(M.Player, M.Mammoth);
		if GetTime() >= M.LastShieldTime then
			M.LastShieldTime = GetTime() + 3.5;
			MakeExplosion("sdome", M.Mammoth);
		end
	end
	
	if not M.ControlDead and M.TugAquired and not IsAlive(M.ControlTower) then
		M.Aud1 = AudioMessage(audio.dayw);
		SetObjectiveOff(M.ObjectiveNav);
		SetObjectiveOn(M.Mammoth);
		SetObjectiveName(M.Mammoth, "Mammoth");
		M.ControlDead = true;
		SpawnArmy();
		UpdateObjectives();
	end
	
	if M.ControlDead and not M.MammothReached and GetDistance(M.Player, M.Mammoth) < 35 then
		M.MammothTime = GetTime() + 10.0; -- Wait 10 seconds to gather info.
		M.MammothReached = true;
		UpdateObjectives();
		if not M.MammothReachedPrevious then
			M.Aud1 = AudioMessage(audio.second_a);
			M.MammothReachedPrevious = true;
		else
			M.Aud1 = AudioMessage(audio.backinrange)
		end
	end
	
	if GetTime() < M.MammothTime and M.MammothReached and GetDistance(M.Player, M.Mammoth) > 35 then
		M.MammothTime = 0;
		M.MammothReached = false;
		UpdateObjectives();
		M.Aud1 = AudioMessage(audio.transint);
	end
	
    if M.MammothReached and not M.MammothInfoed and GetTime() > M.MammothTime then
        M.Aud1 = AudioMessage(audio.flee);
        StartCockpitTimer(120, 30, 10);
		SetObjectiveOff(M.Mammoth);
--		BuildObject("bvapc", 3, GetPositionNear(GetPosition(GetHandle("nav5"))));
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
		if M.MammothInfoed and GetObjectiveName(M.ObjectiveNav) == "Extraction Point" and GetDistance(M.Player, M.ObjectiveNav) < 50.0 then
			Aud1 = AudioMessage(audio.win);
			SucceedMission(GetTime()+5.0, "rbdnew03wn.des");
			M.MissionOver = true;
			M.SafetyReached = true;
			UpdateObjectives();
		end
		
		-- Lose Conditions:
		
		if not M.HangarInfoed and not IsAlive(M.Hangar) then
			FailMission(GetTime()+5.0, "rbdnew03l3.des");
			M.MissionOver = true;
			UpdateObjectives();
		end

		if  not IsAlive(M.Mammoth) then 
			M.Aud1 = AudioMessage(audio.lose1);
			FailMission(GetTime()+5.0, "rbdnew03l1.des");
			M.MissionOver = true;
			UpdateObjectives();
		end
		
		if M.MammothInfoed and GetCockpitTimer() == 0 and not M.MissionOver then
			Aud1 = AudioMessage(audio.lose2);
			FailMission(GetTime() + 5.0, "rbdnew03l2.des");
			M.MissionOver = true;
			UpdateObjectives();
		end

		if M.IsDetected and not M.MammothReached then
			Aud1 = AudioMessage(audio.lose4);
			FailMission(GetTime() + 5.0, "rbdnew03l4.des");
			M.MissionOver = true;
			UpdateObjectives();
		end

		if M.Wrecker and not IsValid(M.Wrecker) and not M.ControlDead and M.WreckTime1 == 0 then
			M.WreckTime1 = GetTime() + 1.0;
		end
		if M.WreckTime1 ~= 0 and GetTime() >=M.WreckTime1 and not M.ControlDead then
			M.Aud1 = AudioMessage(audio.lose4);
			FailMission(GetTime() + 5.0, "rbdnew03l5.des");
			M.MissionOver = true;
			UpdateObjective(objectives.Control, "RED");
		end

		if not M.Wrecker and M.Armory and GetScrap(1) < 20 and not M.ControlDead and M.WreckTime2 == 0 then
			M.WreckTime2 = GetTime() + 1.5;
		end
		if M.WreckTime2 ~= 0 and GetTime() > M.WreckTime2 and not M.ControlDead and not M.Wrecker then
			Aud1 = AudioMessage(audio.lose5);
			FailMission(GetTime() + 5.0, "rbdnew03l5.des");
			M.MissionOver = true;
			UpdateObjective(objectives.Control, "RED");
		end
	end
end


minit.init()