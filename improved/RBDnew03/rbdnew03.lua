-- Battlezone: Rise of the Black Dogs Redux Mission 3 coded by Seqan and Vemahk


require("bz_logging");
local bzCore = require("bz_core");
local mammoth = require("mammoth");





local M = {
-- Bools
UpdateObjectives = false,

StartDone = false, -- Some things don't work in the actual "Start" function.
Nav1Reached = false, -- Are we at nav1 yet? 
DecoyTriggered = false, -- It's a Trap!
TrapEscaped = false, -- Whew, close one!
MammothStolen = false, -- Steal the Mammoth!
MammothDead = false, -- You can't kill something that's extinct.
DropZoneReached = false, -- Are we there yet?
MissionOver = false, -- Yay!

-- Handles
Player = nil,
NavCoords = { },
ObjectiveNav = nil,
Mammoth = nil,
MammothDecoy = nil,

-- Ints
Aud1 = 0
}



local loaded = false;

function Save()
	return 
	M, bzCore:save();
end

function Load(missionData,bzUtilsData)	
	--[[if select('#', ...) > 0 then
	M
	= ...
	end--]]
	M = missionData;
	bzCore:load(bzUtilsData);
	loaded = true;
end

function GameKey(...)
	bzCore:onGameKey(...);
end

function Start()
	bzCore:onStart();
	print("Black Dog Mission 3 Lua created by Seqan and Vemahk");
end

function AddObject(h)
	bzCore:onAddObject(h);
	local Team = GetTeamNum(h);

end

function DeleteObject(h)
	bzCore:onDeleteObject(h);
end

function CreateObject(h)
	bzCore:onCreateObject(h);
end

function afterSave()
	bzCore:afterSave();
end

function afterLoad()
	bzCore:afterLoad();
	loaded = false;
end

local function UpdateObjectives() -- Handle Objectives.
	ClearObjectives();
	
	if not M.MammothDead then
		-- If you haven't stolen anything yet, you're a good boy.
		if not M.MammothStolen then
			-- First order, investigate the Mammoth.
			if not M.DecoyTriggered then
				AddObjective("rbdnew0301.otf", "WHITE");
			else
				-- but bad news!
				if not M.TrapEscaped then
					AddObjective("rbdnew0302.otf", "WHITE");
				else -- Go find me a Mammoth.
					AddObjective("rbdnew0302.otf", "GREEN");
					AddObjective("rbdnew0303.otf", "WHITE");
				end
			end		
		else -- Get to the drop zone.
			if not M.DropZoneReached then
				AddObjective("rbdnew0304.otf", "WHITE");
			else
				AddObjective("rbdnew0304.otf", "GREEN");
			end
		end
	else -- ITS DEAD! NOOOOO! NEW Fail objective. -GBD
		AddObjective("rbdnew0305.otf", "RED");
	end
end

local function SpawnNav(num)
	local nav = BuildObject("apcamr", 1, M.NavCoords[num]);
	SetLabel(nav, "nav"..num);
	
	if num == 2 then
		SetName(nav, "Pickup Site");
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

function Update(dtime)
	bzCore:update(dtime);
	
	if(loaded) then
		afterLoad();
	end

	M.Player = GetPlayerHandle();
	
	if not M.StartDone then
		
		M.Mammoth = GetHandle("mammoth");
		SetIndependence(M.Mammoth, 0); -- Nope.
		M.MammothDecoy = GetHandle("badmammoth");
		SetIndependence(M.MammothDecoy, 0); -- Nope.

		-- In BZ64, navs are invincible, maybe keep it that way for now. (units in this mission use navs to goto)
		for i = 1, 2 do
			local tmpnav = GetHandle("nav" .. i);
			M.NavCoords[i] = GetPosition(tmpnav);
			RemoveObject(tmpnav);
		end
		
		M.StartDone = true;
		
		-- Start up the mission.
		M.Aud1 = AudioMessage("rbdnew0301.wav");
		UpdateObjectives();
		SpawnNav(1);
	end
	
	-- You're there, but it's a trap!
	if not M.Nav1Reached and GetDistance(M.Player, M.ObjectiveNav) < 175.0 then
		Attack(BuildObject("svhraz", 2, "spawn_svhraz1"), M.Player);
		Attack(BuildObject("svhraz", 2, "spawn_svhraz2"), M.Player);
		Attack(BuildObject("svfigh", 2, "spawn_svfigh1"), M.Player);
		Attack(BuildObject("svfigh", 2, "spawn_svfigh2"), M.Player);
		Attack(BuildObject("svrckt", 2, "spawn_svrkct1"), M.Player);
		Attack(BuildObject("svrckt", 2, "spawn_svrckt2"), M.Player);
		M.Nav1Reached = true;
		UpdateObjectives();
	end
	
	-- IMPROVEMENT? Move spawn up to here, closer to when u get to mammoth decoy?
	if not M.DecoyTriggered and IsWithin(M.Player, M.MammothDecoy, 150.0) then
		BuildObject("xbmbxpl", 0, M.MammothDecoy);
		Damage(M.MammothDecoy, 9001); -- It's over 9000!!!
		M.Aud1 = AudioMessage("rbdnew0302.wav");
		M.DecoyTriggered = true;
		UpdateObjectives();
	end
	
	-- Okay, your (IT'S YOU'RE) safe.
	if M.DecoyTriggered and not M.TrapEscaped and GetDistance(M.Player, M.ObjectiveNav) > 400.0 then
		M.Aud1 = AudioMessage("rbdnew0303.wav");
		SetObjectiveOn(M.Mammoth);
		M.TrapEscaped = true;
		UpdateObjectives();
	end
	
	-- Did you do the deed yet?
	if not M.MammothStolen and M.Player == M.Mammoth then
		M.Aud1 = AudioMessage("rbdnew0304.wav");
		SetObjectiveOff(M.Mammoth);
		SpawnNav(2);
		M.MammothStolen = true;
		UpdateObjectives();
	end
	
	-- Win Conditions:
	if not M.MissionOver and M.MammothStolen and M.Player == M.Mammoth and IsWithin(M.Player, M.Nav[2], 50.0) then
		SucceedMission(GetTime()+5.0, "rbdnew03wn.des");
		M.MissionOver = true;
		M.DropZoneReached = true;
		UpdateObjectives();
	end
	
	-- Lose Conditions
	if not M.MissionOver and not IsValid(M.Mammoth) then
		FailMission(GetTime()+5.0, "rbdnew03l1.des");
		M.MammothDead = true;
		M.MissionOver = true;
		UpdateObjectives();
	end
end
