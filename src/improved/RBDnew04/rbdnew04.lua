-- Battlezone: Rise of the Black Dogs Redux, Mission 3 "The Mammoth Project" recoded by Vemahk and Seqan based off GBD's 1:1 script



require("_printfix");

print("\27[34m----START MISSION----\27[0m");

---@diagnostic disable-next-line: lowercase-global
debugprint = print;
--traceprint = print;

require("_requirefix").addmod("rotbd");

require("_table_show");
local api = require("_api");
local gameobject = require("_gameobject");
local hook = require("_hook");
local statemachine = require("_statemachine");
local stateset = require("_stateset");
--local tracker = require("_tracker");
local navmanager = require("_navmanager");
local objective = require("_objective");
local utility = require("_utility");

-- Fill navlist gaps with important navs
navmanager.SetCompactionStrategy(navmanager.CompactionStrategy.ImportantFirstToGap);

-- constrain tracker so it does less work, otherwise when it's required it watches everything
--tracker.setFilterTeam(1); -- track team 1 objects
--tracker.setFilterClass("scavenger"); -- track scavengers
--tracker.setFilterClass("factory"); -- track factories
--tracker.setFilterClass("commtower"); -- track comm towers
--tracker.setFilterOdf("bvtank"); -- track bvtanks
--tracker.setFilterOdf("bvhraz"); -- track bvhraz
--tracker.setFilterClass("turrettank"); -- track turrettanks




--Returns true of all of the handles given are dead
--areAnyAlive = not areAllDead
local function areAllDead(handles, team)
    for i,v in pairs(handles) do
        if v:IsAlive() and (team==nil or team == v:GetTeamNum(v)) then
            return false;
        end
    end
    return true;
end

local function choose(...)
    local t = {...};
    local rn = math.random(#t);
    return t[rn];
end



local audio = {
	intro = "rbdnew0401.wav",
	itsatrap = "rbdnew0402.wav",
	freedom = "rbdnew0403.wav",
	planschange = "rbdnew0404.wav",
	gtfo = "rbdnew0405.wav",
	bypass = "rbdnew04a1.wav",
	wasatrap = "rbdnew04a2.wav",
	wantitback = "rbdnew0406.wav",
	homefree = "rbdnew0407.wav"
}

local objs = {
	recon = "rbdnew0401.otf",
	escape = "rbdnew0402.otf",
	findit = "rbdnew0403.otf",
	extraction = "rbdnew0404.otf",
	mine = "rbdnew0406.otf"
}

local M = {
	-- Bools
	UpdateObjectives = false,

	StartDone = false, -- Some things don't work in the actual "Start" function.
	Nav1Reached = false, -- Are we at nav1 yet? 
	DecoyTriggered = false, -- It's a Trap!
	TrapEscaped = false, -- Whew, close one!
	PlansChange = false, -- Shaw is a dick
	MammothStolen = false, -- Steal the Mammoth!
	MammothDead = false, -- You can't kill something that's extinct.
	WantItBack = false, -- They're coming for you
	RecoveryBeaten = false, -- You ditched the recall effort
	DropZoneReached = false, -- Are we there yet?
	MissionOver = false, -- Yay!

	-- Handles
	Player = nil,
	NavCoords = { },
	Nav = { },
	ObjectiveNav = nil,
	Mammoth = nil,
	MammothDecoy = nil,
	DecoyAmbush = { },
	RecoverySquad = { },
	Baker = nil,
	scrapFields = {},

	-- Ints
	Aud1 = 0,
	DecoyTime = 0,
	FlashTime = 0
}

local function scrapFieldsFiller(p)
    local scrapFieldScrap = {};
    for obj in gameobject.ObjectsInRange(35, p) do
        if obj:GetClassLabel() == "scrap" then
            table.insert(scrapFieldScrap, obj);
        end
    end
    M.scrapFields[p] = scrapFieldScrap;
end

-- if scrap is gone, respawn it (is this instant? seems like a bad idea)
local function scrapRespawner()
	for path, field in pairs(M.scrapFields) do
		for i, scrap in ipairs(field) do
			if not scrap or not scrap:IsValid() then
				field[i] = gameobject.BuildGameObject(choose("npscr1", "npscr2", "npscr3"), 0, GetPositionNear(GetPosition(path) or SetVector(), 1, 35));
			end
		end
	end
end

hook.Add("Start", "Mission:Start", function ()
	for i = 1,5 do
		scrapFieldsFiller("scrpfld"..i);
	end
end);


hook.AddSaveLoad("Mission",
function()
    return M;
end,
function(g)
    M = g;
end);


local function UpdateObjectives() -- Handle Objectives.
	ClearObjectives();
	
	if not M.MammothDead then
		-- If you haven't stolen anything yet, you're a good boy.
		if not M.MammothStolen then
			-- First order, investigate the Mammoth.
			if not M.DecoyTriggered then
				AddObjective(objs.recon, "WHITE");
			else
				-- but bad news!
				if not M.TrapEscaped then
					AddObjective(objs.escape, "WHITE");
				else -- Go find me a Mammoth.
					AddObjective(objs.escape, "GREEN");
					AddObjective(objs.findit, "WHITE");
				end
			end		
		else -- Get to the drop zone.
			if not M.DropZoneReached then
				AddObjective(objs.findit, "GREEN");
				AddObjective(objs.extraction, "WHITE");
				if M.WantItBack then
					if not M.RecoveryBeaten then
						AddObjective(objs.mine, "WHITE");
					else
						AddObjective(objs.mine, "GREEN");
					end
				end
			else
					AddObjective(objs.extraction, "GREEN");
			end
		end
	else -- ITS DEAD! NOOOOO! NEW Fail objective. -GBD
		AddObjective("rbdnew0405.otf", "RED");
	end
end

local function SpawnNav(num)
	local nav = BuildObject("apcamr", 1, M.NavCoords[num]);
	M.Nav[num] = nav;
	SetLabel(nav, "nav"..num);
	
	if num == 3 then
		SetName(nav, "Extraction Point");
	else
		SetName(nav, "Nav "..num);
	end
	
	SetMaxHealth(nav, 0); -- Can't go boom-boom.
	
	-- Switches the active objective from the old nav to the new nav.
	if M.ObjectiveNav then
		SetObjectiveOff(M.ObjectiveNav);
	end
	SetObjectiveOn(nav);
	M.ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
end

local function SpawnBaker()
	M.Baker = BuildObject("bvhaul", 3, "bakerspawn");
	Defend2(BuildObject("bvfigh", 3, GetPositionNear(GetPosition("bakerspawn"))), M.Baker, 1);
	Defend2(BuildObject("bvfigh", 3, GetPositionNear(GetPosition("bakerspawn"))), M.Baker, 1);
	Defend2(BuildObject("bvtank", 3, GetPositionNear(GetPosition("bakerspawn"))), M.Baker, 1);
	Defend2(BuildObject("bvtank", 3, GetPositionNear(GetPosition("bakerspawn"))), M.Baker, 1);
	Defend2(BuildObject("bvtank", 3, GetPositionNear(GetPosition("bakerspawn"))), M.Baker, 1);
	Defend2(BuildObject("bvtank", 3, GetPositionNear(GetPosition("bakerspawn"))), M.Baker, 1);
end

function Update()

	M.Player = GetPlayerHandle();
	scrapRespawner();
	
	if not M.StartDone then
		Ally(1,3)
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0);
		M.MammothDecoy = GetHandle("badmammoth");
		SetIndependence(M.MammothDecoy, 0);
		SetMaxScrap(2,10000);
		SetMaxScrap(1, 45);
		SetScrap(1, 40);
		RemovePilot(M.Mammoth);
		SetPerceivedTeam(M.Mammoth, 1);
		
		for i = 1,3 do
			local tmpnav = GetHandle("nav" .. i);
			M.NavCoords[i] = GetPosition(tmpnav);
			RemoveObject(tmpnav);
		end
		
		M.StartDone = true;
		
		M.Aud1 = AudioMessage(audio.intro);
		UpdateObjectives();
		SpawnNav(1);
	end
	
	if not M.DecoyTriggered and IsWithin(M.Player, M.MammothDecoy, 250.0) and M.Player ~= M.Mammoth then
		if M.DecoyTime == 0 then
			-- Spawn Armada
			M.DecoyAmbush = {
			BuildObject("svhraz", 2, "spawn_svhraz1"),
			BuildObject("svhraz", 2, "spawn_svhraz2"),
			BuildObject("svfigh", 2, "spawn_svfigh1"),
			BuildObject("svfigh", 2, "spawn_svfigh2"),
			BuildObject("svrckt", 2, "spawn_svrckt1"),
			BuildObject("svrckt", 2, "spawn_svrckt2"),
			BuildObject("svtank", 2, "spawn_svtank1"),
			BuildObject("svtank", 2, "spawn_svtank2"),
			BuildObject("svtank", 2, "spawn_svtank3"),
			BuildObject("svtank", 2, "spawn_svtank4")
			}
			for i = 1,#M.DecoyAmbush do
				Attack(M.DecoyAmbush[i], M.Player);
			end
            M.DecoyTime = GetTime() + 4.0;
            M.Aud1 = AudioMessage(audio.itsatrap);
			UpdateObjectives();
        end
		if GetTime() > M.DecoyTime then
		--	Blow up da mammoth
			MakeExplosion("xbmbxpl", M.MammothDecoy);
			Damage(M.MammothDecoy, 90000);
		
		--	Blind Player
			M.FlashTime = GetTime() + 3.0;
		end
		if GetTime() < M.FlashTime then
			ColorFade(100.0, 1.0, 255, 255, 255);
			MakeExplosion("xbmbblnd", M.Player);
			M.DecoyTriggered = true;
		end
	end
	
	if M.TrapEscaped and not M.PlansChange and not IsWithin(M.Player, M.Nav[1], 750.0) and M.Player ~= M.Mammoth then
		M.Aud1 = AudioMessage(audio.planschange);
		M.PlansChange = true;
	end
	
	if not M.DecoyTriggered and IsWithin(M.Player, M.MammothDecoy, 100.0) and M.Player == M.Mammoth then
		M.Aud1 = AudioMessage(audio.wasatrap);
		M.DecoyTriggered = true;
	end
	
	if M.DecoyTriggered and not M.TrapEscaped and areAllDead(M.DecoyAmbush, 2) and M.Player ~= M.Mammoth then
		M.Aud1 = AudioMessage(audio.freedom);
		M.TrapEscaped = true;
		SpawnNav(2);
		UpdateObjectives();
	end
	
	if not M.MammothStolen and M.Player == M.Mammoth then
		if M.TrapEscaped then
			M.Aud1 = AudioMessage(audio.gtfo);
			SpawnNav(3);
			SpawnBaker();
			SetPerceivedTeam(M.Player, 1)
			M.MammothStolen = true;
			UpdateObjectives();
		else
			M.Aud1 = AudioMessage(audio.bypass);
			SpawnNav(3);
			SpawnBaker();
			SetPerceivedTeam(M.Player, 1)
			M.MammothStolen = true;
			UpdateObjectives();
		end
	end
	
	if M.MammothStolen and GetLabel(M.ObjectiveNav) == "nav3" and GetDistance(M.Player, M.ObjectiveNav) < 1450 and not M.WantItBack then
		M.RecoverySquad = {
		BuildObject("svfigh", 2, "final_spawn3"),
		BuildObject("svfigh", 2, "final_spawn4"),
		BuildObject("svfigh", 2, "final_spawn6"),
		BuildObject("svfigh", 2, "final_spawn7"),
		BuildObject("svrckt", 2, "final_spawn1"),
		BuildObject("svrckt", 2, "final_spawn2")
		}
		for i = 1,#M.RecoverySquad do
			Attack(M.RecoverySquad[i], M.Player);
		end
		M.Aud1 = AudioMessage(audio.wantitback);
		M.WantItBack = true;
		UpdateObjectives();
	end
	
	if M.MammothStolen and M.WantItBack and areAllDead(M.RecoverySquad, 2) and M.Player == M.Mammoth then
		M.RecoveryBeaten = true;
		UpdateObjectives();
	end
	
	-- Win Conditions:
	if not M.MissionOver and M.MammothStolen and M.Player == M.Mammoth and IsWithin(M.Player, M.Nav[3], 75.0) and M.RecoveryBeaten then
		M.Aud1 = AudioMessage(audio.homefree);
		SucceedMission(GetTime()+5.0, "rbdnew04wn.des");
		M.MissionOver = true;
		M.DropZoneReached = true;
		UpdateObjectives();
	end
	
	-- Lose Conditions
	if not M.MissionOver and not IsValid(M.Mammoth) then -- YA BLEW UP THE MAMMOTH YA GOOF
		FailMission(GetTime()+5.0, "rbdnew04l1.des");
		M.MammothDead = true;
		M.MissionOver = true;
		UpdateObjectives();
	end
end


minit.init()