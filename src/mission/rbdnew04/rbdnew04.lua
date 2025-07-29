-- Battlezone: Rise of the Black Dogs Redux, Mission 3 "The Mammoth Project" recoded by Vemahk and Seqan based off GBD's 1:1 script

-- for some reason the backup objective of going to the fake after driving the real mammoth didn't work, look into why
-- flash bang and explosion of the fake happened late


require("_printfix");

print("\27[34m----START MISSION----\27[0m");

--- @diagnostic disable-next-line: lowercase-global
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

local mission_data = {
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

local function SpawnNav(num)
	local nav = navmanager.BuildImportantNav("apcamr", 1, mission_data.NavCoords[num]);
	mission_data.Nav[num] = nav;

	if nav == nil then
		error("Nav "..num.." is nil!");
	end

	nav:SetLabel("nav"..num);
	
	if num == 3 then
		nav:SetName("Extraction Point");
	else
		nav:SetName("Nav "..num);
	end
	
	nav:SetMaxHealth(0); -- Can't go boom-boom.
	
	-- Switches the active objective from the old nav to the new nav.
	if mission_data.ObjectiveNav then
		mission_data.ObjectiveNav:SetObjectiveOff();
	end
	nav:SetObjectiveOn();
	mission_data.ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
end

local function SpawnBaker()
	mission_data.Baker = gameobject.BuildObject("bvhaul", 3, "bakerspawn");
	local bakerspawn = GetPosition("bakerspawn");
	if bakerspawn == nil then
		error("Baker spawn is nil!");
	end
	gameobject.BuildObject("bvfigh", 3, GetPositionNear(bakerspawn)):Defend2(mission_data.Baker, 1);
	gameobject.BuildObject("bvfigh", 3, GetPositionNear(bakerspawn)):Defend2(mission_data.Baker, 1);
	gameobject.BuildObject("bvtank", 3, GetPositionNear(bakerspawn)):Defend2(mission_data.Baker, 1);
	gameobject.BuildObject("bvtank", 3, GetPositionNear(bakerspawn)):Defend2(mission_data.Baker, 1);
	gameobject.BuildObject("bvtank", 3, GetPositionNear(bakerspawn)):Defend2(mission_data.Baker, 1);
	gameobject.BuildObject("bvtank", 3, GetPositionNear(bakerspawn)):Defend2(mission_data.Baker, 1);
end





--- @class scrap_field_filler_state_04 : StateMachineIter
--- @field path string Path to the scrap field.
--- @field scrap_objects GameObject[] Table of scrap objects in the field.
--- @field scrap_options string[] Table of scrap odf options to choose from.

statemachine.Create("scrap_field_filler", {
	{ "start", function (state)
		--- @cast state scrap_field_filler_state_04
		state.scrap_objects = {};
		for obj in gameobject.ObjectsInRange(35, state.path) do
			if obj:GetClassLabel() == "scrap" then
				table.insert(state.scrap_objects, obj);
			end
		end
		if #state.scrap_objects == 0 then
			print("Scrap field "..state.path.." is empty! Disabling respawner.");
			state:switch(nil);
			return statemachine.AbortResult();
		end

		if state.scrap_options == nil then
			state.scrap_options = {"npscr1", "npscr2", "npscr3"};
		end

		state:next();
	end },
	{ "respawner", function (state)
		--- @cast state scrap_field_filler_state_04
		local pos = GetPosition(state.path); -- could consider saving the position, but using the path would let us handle modified mission loads
		if pos then
			for i, scrap in ipairs(state.scrap_objects) do -- consider making this a slow-loop that checks 1 per turn
				if not scrap or not scrap:IsValid() then
					state.scrap_objects[i] = gameobject.BuildObject(choose(table.unpack(state.scrap_options)), 0, GetPositionNear(pos, 1, 35));
				end
			end
		end
	end }
});


stateset.Create("mission")
	:Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
	:Add("scrap_field_filler_1", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld11" }))
	:Add("scrap_field_filler_2", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld12" }))
	:Add("scrap_field_filler_3", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld13" }))
	:Add("scrap_field_filler_4", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld14" }))
	:Add("scrap_field_filler_5", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld15" }))
	:Add("mammoth_destroyed", function (state)
		-- Lose Conditions
		if not mission_data.Mammoth:IsValid() then -- YA BLEW UP THE MAMMOTH YA GOOF
			FailMission(GetTime()+5.0, "rbdnew04l1.des");
			mission_data.MammothDead = true;
			mission_data.MissionOver = true;

			-- ITS DEAD! NOOOOO! NEW Fail objective. -GBD
			objective.ClearObjectives();
			objective.AddObjective("rbdnew0405.otf", "RED");
		end
	end)
	:Add("extra_find_decoy_after_real", function (state)
		-- DecoyTriggered (Player enters real Mammoth)
		if mission_data.Player:IsWithin(mission_data.MammothDecoy, 100.0) --[[and mission_data.Player == mission_data.Mammoth--]] then
			mission_data.Aud1 = AudioMessage(audio.wasatrap);
			mission_data.DecoyTriggered = true;
			state:off("extra_find_decoy_after_real");
		end
	end);

hook.Add("Start", "Mission:Start", function ()
    mission_data.mission_states = stateset.Start("mission")
		:on("scrap_field_filler_1")
		:on("scrap_field_filler_2")
		:on("scrap_field_filler_3")
		:on("scrap_field_filler_4")
		:on("scrap_field_filler_5")
		:on("main_objectives")
		:on("mammoth_destroyed");
end);

statemachine.Create("main_objectives", {
	{ "start", function (state)
		Ally(1,3)
		mission_data.Mammoth = gameobject.GetGameObject("mammoth");
		mission_data.Mammoth:SetIndependence(0);
		mission_data.MammothDecoy = gameobject.GetGameObject("badmammoth");
		mission_data.MammothDecoy:SetIndependence(0);
		SetMaxScrap(2,10000);
		SetMaxScrap(1, 45);
		SetScrap(1, 40);
		mission_data.Mammoth:RemovePilot();
		mission_data.Mammoth:SetPerceivedTeam(1);
		
		for i = 1,3 do
			local tmpnav = gameobject.GetGameObject("nav" .. i);
			if tmpnav == nil then
				error("Nav "..i.." is nil!");
			end
			mission_data.NavCoords[i] = tmpnav:GetPosition();
			tmpnav:RemoveObject();
		end
		
		mission_data.StartDone = true;
		
		mission_data.Aud1 = AudioMessage(audio.intro);
		--UpdateObjectives();
		objective.AddObjective(objs.recon, "WHITE");
		SpawnNav(1);
		state:next();
	end },
	{ "MammothMonitor", function (state)
		if mission_data.Player:IsWithin(mission_data.MammothDecoy, 250.0) then
			state:next();
		elseif mission_data.Player == mission_data.Mammoth then
			state:switch("MammothStolen");
			-- also enable special event for finding fake mammoth 2nd
			mission_data.mission_states:on("extra_find_decoy_after_real");
		end
	end },
	{ "DecoyTriggered", function (state)
		-- Spawn Armada
		mission_data.DecoyAmbush = {
			gameobject.BuildObject("svhraz", 2, "spawn_svhraz1"),
			gameobject.BuildObject("svhraz", 2, "spawn_svhraz2"),
			gameobject.BuildObject("svfigh", 2, "spawn_svfigh1"),
			gameobject.BuildObject("svfigh", 2, "spawn_svfigh2"),
			gameobject.BuildObject("svrckt", 2, "spawn_svrckt1"),
			gameobject.BuildObject("svrckt", 2, "spawn_svrckt2"),
			gameobject.BuildObject("svtank", 2, "spawn_svtank1"),
			gameobject.BuildObject("svtank", 2, "spawn_svtank2"),
			gameobject.BuildObject("svtank", 2, "spawn_svtank3"),
			gameobject.BuildObject("svtank", 2, "spawn_svtank4"),
		}
		for i = 1,#mission_data.DecoyAmbush do
			mission_data.DecoyAmbush[i]:Attack(mission_data.Player);
		end
		--mission_data.DecoyTime = GetTime() + 4.0;
		mission_data.Aud1 = AudioMessage(audio.itsatrap);
		--UpdateObjectives();
		objective.RemoveObjective(objs.recon);
		objective.AddObjective(objs.escape, "WHITE");
		state:next();
	end },
	statemachine.SleepSeconds(4),
	function (state) 
		--	Blow up da mammoth
		MakeExplosion("xbmbxpl", mission_data.MammothDecoy:GetHandle());
		mission_data.MammothDecoy:Damage(90000);

		--	Blind Player
		--mission_data.FlashTime = GetTime() + 3.0;
		state:next();
	end,
	statemachine.SleepSeconds(3),
	function (state)
		ColorFade(100.0, 1.0, 255, 255, 255);
		MakeExplosion("xbmbblnd", mission_data.Player:GetHandle());
		mission_data.DecoyTriggered = true;
		state:next();
	end,
	{ "TrapEscaped", function (state)
		if areAllDead(mission_data.DecoyAmbush, 2) then
			mission_data.Aud1 = AudioMessage(audio.freedom);
			mission_data.TrapEscaped = true;
			SpawnNav(2);
			--UpdateObjectives();
			objective.UpdateObjective(objs.escape, "GREEN");
			objective.AddObjective(objs.findit, "WHITE");
			state:next();
		end
	end },
	{ "PlansChange", function (state)
		if not mission_data.Player:IsWithin(mission_data.Nav[1], 750.0) then
			mission_data.Aud1 = AudioMessage(audio.planschange);
			mission_data.PlansChange = true;
			state:next();
		end
	end },
	function (state)
		if mission_data.Player == mission_data.Mammoth then
			state:next();
		end
	end,
	{ "MammothStolen", function (state)
		if mission_data.TrapEscaped then
			mission_data.Aud1 = AudioMessage(audio.gtfo);
			--SpawnNav(3);
			--SpawnBaker();
			--mission_data.Player:SetPerceivedTeam(1)
			--mission_data.MammothStolen = true;
			--UpdateObjectives();
		else
			mission_data.Aud1 = AudioMessage(audio.bypass);
			--SpawnNav(3);
			--SpawnBaker();
			--mission_data.Player:SetPerceivedTeam(1)
			--mission_data.MammothStolen = true;
			--UpdateObjectives();
		end
		SpawnNav(3);
		SpawnBaker();
		mission_data.Player:SetPerceivedTeam(1)
		mission_data.MammothStolen = true;
		objective.ClearObjectives();
		objective.AddObjective(objs.findit, "GREEN");
		objective.AddObjective(objs.extraction, "WHITE", nil, nil, 10);
		state:next();
	end },
	{ "WantItBack", function (state)
		if mission_data.ObjectiveNav:GetLabel() == "nav3" and mission_data.Player:GetDistance(mission_data.ObjectiveNav) < 1450 and mission_data.Player == mission_data.Mammoth then
			mission_data.RecoverySquad = {
				gameobject.BuildObject("svfigh", 2, "final_spawn3"),
				gameobject.BuildObject("svfigh", 2, "final_spawn4"),
				gameobject.BuildObject("svfigh", 2, "final_spawn6"),
				gameobject.BuildObject("svfigh", 2, "final_spawn7"),
				gameobject.BuildObject("svrckt", 2, "final_spawn1"),
				gameobject.BuildObject("svrckt", 2, "final_spawn2")
			}
			for i = 1,#mission_data.RecoverySquad do
				mission_data.RecoverySquad[i]:Attack(mission_data.Player); -- what if the player isn't in the mammoth anymore?
			end
			mission_data.Aud1 = AudioMessage(audio.wantitback);
			mission_data.WantItBack = true;
			--UpdateObjectives();
			objective.AddObjective(objs.mine, "WHITE");
			state:next();
		end
	end },
	{ "RecoveryBeaten", function (state)
		if areAllDead(mission_data.RecoverySquad, 2) and mission_data.Player == mission_data.Mammoth then
			mission_data.RecoveryBeaten = true;
			--UpdateObjectives();
			objective.UpdateObjective(objs.mine, "GREEN");
			state:next();
		end
	end },
	{ "End", function (state)
		if mission_data.Player == mission_data.Mammoth and mission_data.Player:IsWithin(mission_data.Nav[3], 75.0) then
			mission_data.Aud1 = AudioMessage(audio.homefree);
			SucceedMission(GetTime()+5.0, "rbdnew04wn.des");
			mission_data.MissionOver = true;
			mission_data.DropZoneReached = true;
			--UpdateObjectives();
			objective.UpdateObjective(objs.extraction, "GREEN");
			state:switch(nil);
		end
	end }
});

hook.Add("Update", "Mission:Update", function (dtime, ttime)
	mission_data.Player = gameobject.GetPlayer();
	mission_data.mission_states:run();
end);

hook.AddSaveLoad("Mission",
function()
    return mission_data;
end,
function(g)
    mission_data = g;
end);

require("_audio_dev");