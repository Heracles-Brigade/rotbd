--- Rise of the Black Dogs
---
--- [2] Covert Ops
--- Original Mission:
--- [3] Exploratory
---
--- World: Mars (Sol IV)
--- Map Data: Deus Ex Ceteri
---
--- Authors:
--- * Herp McDerperson
--- * Seqan
--- * GBD
--- * Vemahk
--- * Janne
--- * John "Nielk1" Klein
---
--- High Level Objectives
--- * Explore Mars base site
--- * Uncover information on Mammoth
---
--- Events
--- 
--- Information pieced together from CCA outposts on the moon reveals that the information gleaned from the armory was being used alongside research gained during the Fury project in the development of a CCA super heavy tank in the Cydonia region of Mars under the codename "Mammoth". Desperate to prevent the CCA from completing this weapon, and with the majority of NSDF forces on Titan, Shaw orders a wing of his men to redeploy to Mars to put a stop to the project.
--- 
--- With the information on the project's location vague and their numbers limited the Black Dogs have little choice but to deploy a single soldier to infiltrate the area and locate the site of the project's development. Cobra One is deployed in a stolen CCA IEVA suit to spy on the operation.
--- 
--- Cobra One's progress is hindered by a number of satellite towers around the area; by approaching these he risks exposure should the tower notice him and attempt to contact him. For this reason he is instructed to spend as little time near them as possible.
--- 
--- The only set of coordinates the Black Dogs discovered are not specific so Cobra One's first target is the nearest building of potential interest: a CCA hanger. The stolen suit connects to the radio automatically and reveals that the Mammoth is protected by several layers of security; of most immediate concern are tight access restrictions allowing only utility vehicles transporting cargo and personnel. Shaw tells Cobra One to hijack a supply shipment from a nearby outpost, so Cobra One makes their way there on foot.
--- 
--- When Cobra One arrives at the outpost they are able to steal an empty tug without being detected. Now that they have an authorised vehicle their next problem is the protective forcefield projected around the Mammoth and controlled from another outpost. The Black Dogs deploy an armory nearby and Shaw has Cobra One destroy the outpost using a Day Wrecker.
--- 
--- With the control tower destroyed Cobra One is able to proceed to the Mammoth. Getting close to it is enough to gather a technical readout but the transmission back to Shaw is detected by the CCA and a large attack squadron is deployed to eliminate the source and Cobra One is forced to flee to an evacuation point.
--- 
--- The stolen data will allow the Black Dogs to construct a Mammoth of their own once they have acquired the prototype.
---
--- Issues
--- * Right now when you are detected you lose the mission immediately.
---   * Desired: If you kill the other unit or remove its pilot in time, you don't lose.
---     * Side Effect: Bringing this invalid unit too close to the mammoth should lose.
--- * The docs say the player should have a normal rifile, they have one with 50 shots.
---   * N64 verison has a high power rifile, but that is as a BDog pilot.
---     * N64 mission was "sneak, kill, sneak, kill" while ours is "sneak, sneak, sneak"
---   * N64 rifile can kill in 3 like 3 shots, so we tried a rocket weapon but it flopped.
---   * If we fix the detection issue, should we drop it back down to 3 shots?
---
--- Notes
--- Satellite towers do not detect player for 30s within 100m, or two minutes within 200m. (not currently, clear up how this should work exactly?)
--- Player receives burst of Russian speech if they are detected by a Satellite Tower (not currently?)
--- Several tugs and APCs travelling between the Mammoth site and various outposts around the map
---
--- Issues (Remove these are they are fixed and move relevent information into Notes)
--- * Ensure player's pilot is correct pilot
--- The detection by the satellite towers is really slow, consider changes to this process to either be shorter or involve a "noticed" concept
--- The range on the first objective to investigate the mammoth has been reduced so it no longer trips while the mamoth is still outside of vis-range, but this still feels wrong.  Maybe the tug should need to actually approach the mammoth to see the shield and/or need to tug materials to the base to justify its presence?
--- For some reason they player has 100 sniper shots.  This doesn't make sense, especially since using it will lose the mission.
--- steal lines from Flying Solo for the hailing

local logger = require("_logger");

logger.print(logger.LogLevel.DEBUG, nil, "\27[34m----START MISSION----\27[0m");

require("_requirefix");

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
local color = require("_color");
local camera = require("_camera");

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

--- @class RBD03_Constants_Audio
--- @field INTRO string -- Welcome to Mars
--- @field COMM_WARN string -- Careful, Cobra One. Keep an eye on those towers.
--- @field COMM_CLEAR string -- Hurry up, Cobra One!
--- @field INSPECT string -- Got it! According to this, the Mammoth should be...
--- @field TUG string -- Nice! You should be able to get close enough now.
--- @field FIRST_A string -- Bomb the shield control
--- @field DAY_W string -- Nice job, sir! You're clear to get through to the Mammoth now.
--- @field SECOND_A string -- We're picking up your signal, hang around for a bit.
--- @field TRANSINT string -- Out of range
--- @field BACK_IN_RANGE string -- Back in range
--- @field FLEE string -- They detected your transmission, run!
--- @field HURRY string -- Hurry up, Cobra One!
--- @field WIN string -- Good job, Lieutenant. Let's get you out of there.
--- @field LOSS_MAMMOTH_DESTROYED string -- Mammoth Destroyed/sniped (entire base just scrambled)
--- @field LOSS_FAILED_EXTRACT string --Failed to extract on time
----- @field lose3 string --Detected, loser (no exist)
--- @field LOSS_AIM_DAY_WRECKER string -- Evidently you can't aim Day Wreckers
--- @field DETECTED_KILL_THEM string -- They're on to you, Lieutenant! Take them out and let's pray they haven't gotten the word out yet!
--- @field lose5 string

--- @class RBD03_Constants_Names
--- @field EXTRACTION_POINT string
--- @field MAMMOTH string

--- @class RBD03_Constants_Labels
--- @field MAMMOTH string
--- @field HANGER string
--- @field SUPPLY string
--- @field TUG string
--- @field CONTROL string
--- @field RADAR string[] -- Radar towers, 3 of them
--- @field NAV string[]
--- @field PATROL string[][]

--- @class RBD03_Constants_Objectives
--- @field DETECTION string
--- @field HANGER string
--- @field TUG string
--- @field MAMMOTH_1 string
--- @field CONTROL string
--- @field MAMMOTH_2 string
--- @field TRAN_START string
--- @field TRAN_FIN string
--- @field EXTRACT string

--- @class RBD03_Constants_Debriefing
--- @field LOSS_MAMMOTH_DESTROYED string -- Mammoth destroyed before transmission complete
--- @field LOSS_LEFT_BEHIND string -- Failed to make it to the pickup zone
--- @field LOSS_HANGER_DESTROYED string -- Hanger destroyed
--- @field LOSS_COVER_BLOWN string -- Cover blown
--- @field LOSS_WRECKER_MISSED string -- Wrecker missed
--- @field WIN string -- Success

--- @class RBD03_Constants
--- @field AUDIO RBD03_Constants_Audio
--- @field LABELS RBD03_Constants_Labels
--- @field NAMES RBD03_Constants_Names
--- @field OBJECTIVES RBD03_Constants_Objectives
--- @field DEBRIEFING RBD03_Constants_Debriefing
--- @field RUNAWAY_TIMER number[] -- time, yellow, red
--- @field HURRY_THRESHHOLD number -- time to trigger the "hurry" audio message
local CONSTANTS = {
	AUDIO = {
		INTRO = "rbdnew0301.wav",
		COMM_WARN = "rbdnew0301W.wav",
		COMM_CLEAR = "", -- we don't have a clear vox
		INSPECT = "rbdnew0302.wav",
		TUG = "rbdnew0303.wav",
		FIRST_A = "rbdnew0304.wav",
		DAY_W = "rbdnew0305.wav",
		SECOND_A = "rbdnew0306.wav",
		TRANSINT = "rbdnew0306A.wav",
		BACK_IN_RANGE = "rbdnew0306B.wav",
		FLEE = "rbdnew0307.wav",
		HURRY = "rbdnew0302W.wav",
		WIN = "rbdnew0308.wav",
		LOSS_MAMMOTH_DESTROYED = "rbdnew0301L.wav",
		LOSS_FAILED_EXTRACT = "rbdnew0302L.wav",
		--lose3 = "rbdnew0303L.wav",
		LOSS_AIM_DAY_WRECKER = "rbdnew0304L.wav",
		DETECTED_KILL_THEM = "rbdnew0303W.wav",

		-- unused
		lose5 = "rbdnew0305L.wav", --Why didn't you make a Day Wrecker?
	},
	LABELS = {
		MAMMOTH = "mammoth",
		HANGER = "hangar",
		SUPPLY = "supply",
		TUG = "tug",
		CONTROL = "control",
		RADAR = { "radar1", "radar2", "radar3" },
		NAV = { "nav1", "nav2", "nav3", "nav4", "nav5" },
		PATROL = {
			{ "patrol1_1", "patrol1_2", "patrol1_3", "patrol1_4", "patrol1_5", "patrol1_6" },
			{ "patrol2_1", "patrol2_2", "patrol2_3", "patrol2_4", "patrol2_5", "patrol2_6", "patrol2_7", "patrol2_8", "patrol2_9", "patrol2_10" },
			{ "patrol3_1", "patrol3_2", "patrol3_3", "patrol3_4", "patrol3_5", "patrol3_6", "patrol3_7", "patrol3_8", "patrol3_9" }
		},
	},
	NAMES = {
		EXTRACTION_POINT = "Extraction Point",
		MAMMOTH = "Mammoth",
	},
	OBJECTIVES = {
		DETECTION = "rbdnew0300.otf",
		HANGER = "rbdnew0301.otf",
		TUG = "rbdnew0303.otf",
		MAMMOTH_1 = "rbdnew0302.otf",
		CONTROL = "rbdnew0304.otf",
		MAMMOTH_2 = "rbdnew0305.otf",
		TRAN_START = "rbdnew0306.otf",
		TRAN_FIN = "rbdnew0307.otf",
		EXTRACT = "rbdnew0308.otf"
	},
	DEBRIEFING = {
		LOSS_MAMMOTH_DESTROYED = "rbdnew03l1.des",
		LOSS_LEFT_BEHIND = "rbdnew03l2.des",
		LOSS_HANGER_DESTROYED = "rbdnew03l3.des",
		LOSS_COVER_BLOWN = "rbdnew03l4.des",
		LOSS_WRECKER_MISSED = "rbdnew03l5.des",
		WIN = "rbdnew03wn.des"
	},
	RUNAWAY_TIMER = { 120, 30, 10 },
	HURRY_THRESHHOLD = 30,
	sniper_range = 1000, -- used to look at candidates for being shot by player
	detection_range_player = 100, -- if anyone is within this distance of the player they detect when they attack
	detection_range_target = 100, -- if anyone is within this distance of the shot unit they detect when they attack
	detection_range_time = 1, -- units of time that the shot had to be within to count, to omit old hits
	detection_timeout = 10, -- time in seconds you have to save yourself from detection
}

--- @class MissionData03_KeyObjects
--- @field Player GameObject? The player object.
--- @field Mammoth GameObject? The mammoth object.
--- @field ObjectiveNav GameObject? The current objective nav point.
--- @field ControlTower GameObject? The control tower object.
--- @field Wrecker GameObject? The day wrecker object.
--- @field Hangar GameObject? The hangar object.
--- @field Tug GameObject? The tug object.
--- @field Supply GameObject? Seems unused?
--- @field Defenders GameObject[] A list of defender objects spawned during the mission.

--- @class MissionData03
--- @field key_objects MissionData03_KeyObjects
--- @field MammothReachedBefore boolean Has the mammoth been reached before?
--- @field mission_states StateSetRunner The state set for the mission.
local mission_data = { --Sets mission flow and progression. Booleans and values will be changed to "true" and appropriate names/integers as mission progresses. Necessary for save files to function as well as objective flow in later if statements.
	key_objects = {
		Player = nil,
		Mammoth = nil,
		ObjectiveNav = nil,
		ControlTower = nil,
		Wrecker = nil,
		Hangar = nil,
		Tug = nil,
		Supply = nil,
		Defenders = {},
	},

	MammothReachedBefore = false,

	-- Handles; values will be assigned during mission setup and play
	NavCoord = {},
}

local function SpawnNav(num) -- Spawns the Nth Nav point.
	local nav = navmanager.BuildImportantNav("apcamr", 1, mission_data.NavCoord[num]); -- Make the nav from the harvested coordinates.
	if not nav then error("Nav "..num.." failed to spawn!"); end -- If the nav fails to spawn, throw an error.
	nav:SetObjectiveName("Nav "..num); -- Set its name
	if num == 5 then
		nav:SetObjectiveName(CONSTANTS.NAMES.EXTRACTION_POINT); -- If it's the 5th nav, change its name. This is the name it checks for for the Win Condition; if you change this, change the win condition script as well.
	end
	nav:SetMaxHealth(0); -- Can't go boom-boom. I accidentally destroyed Nav 3 with the DW before this.
	
	-- Switches the active objective from the old nav to the new nav.
	if mission_data.key_objects.ObjectiveNav then
		mission_data.key_objects.ObjectiveNav:SetObjectiveOff();
	end
	nav:SetObjectiveOn();
	mission_data.key_objects.ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
end

local function SpawnFromTo(odf, fp, fpp, tp)
	local obj = gameobject.BuildObject(odf, 2, fp, fpp)
	if not obj then error("Failed to spawn "..odf.." from "..tostring(fp).." to "..tostring(tp)); end -- If the object fails to spawn, throw an error.
	obj:Goto(tp, 0);
	obj:SetLabel(fp.."_"..(#mission_data.key_objects.Defenders + 1));
	table.insert(mission_data.key_objects.Defenders, obj);
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

--- Push H1 outside of H2's radius
--- @param h1 GameObject
--- @param h2 GameObject
local function keepOutside(h1,h2) -- This is the shield function for the Mammoth. Thank you, Janne
	local p = h2:GetPosition();
	local r = 40;
	local pp = h1:GetPosition();
	local dv = Normalize(pp-p);
	local vel2 = h2:GetVelocity();
	local d = Length(pp-p);
	local vel = h1:GetVelocity();
	local dprod = DotProduct(vel,-dv);
	local nvel = vel + dprod*dv*(1+GetTimeStep());
	if(d < r) then
		local newp = (p + dv*r);
		local h = GetTerrainHeightAndNormal(newp);
		newp.y = math.max(h,newp.y);
		h1:SetPosition(newp);
		h1:SetVelocity(nvel);
	end
end

hook.Add("CreateObject", "Mission:CreateObject", function (object)
	--- @cast object GameObject
	if not mission_data.key_objects.Wrecker and object:GetClassLabel() == "daywrecker" then
		mission_data.key_objects.Wrecker = object
	end
end);

local function FailByDetection()
	--AudioMessage(constants.audio.lose3);
	FailMission(GetTime() + 5.0, CONSTANTS.DEBRIEFING.LOSS_COVER_BLOWN); -- cover blown
	objective.UpdateObjective(CONSTANTS.OBJECTIVES.DETECTION, "RED");
end

statemachine.Create("scrap_field_filler", {
	{ "start", function (state)
		--- @cast state scrap_field_filler_state_03
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
		--- @cast state scrap_field_filler_state_03
		local pos = GetPosition(state.path); -- could consider saving the position, but using the path would let us handle modified mission loads
		if pos then
			for i, scrap in ipairs(state.scrap_objects) do -- consider making this a slow-loop that checks 1 per turn
				if not scrap or not scrap:IsValid() then
					state.scrap_objects[i] = gameobject.BuildObject(utility.ChooseOne(table.unpack(state.scrap_options)), 0, GetPositionNear(pos, 1, 35));
				end
			end
		end
	end }
});

statemachine.Create("mammoth_shield", function (state)
		if not mission_data.key_objects.Player then
			-- Player object is not available so abort the state logic.
			return;
		end
		keepOutside(mission_data.key_objects.Player, mission_data.key_objects.Mammoth);
		if state:SecondsHavePassed(3.5, true, true) then
			MakeExplosion("sdome", mission_data.key_objects.Mammoth:GetHandle());
		end
	end);

statemachine.Create("main_objectives", {
	{ "start", function (state)
		ColorFade(1.1, 0.4, 0, 0, 0);
		mission_data.key_objects.Mammoth = gameobject.GetGameObject(CONSTANTS.LABELS.MAMMOTH);
		mission_data.key_objects.Mammoth:SetIndependence(0); -- Mammoth shouldn't respond or do anything in this mission.
		mission_data.key_objects.Hangar = gameobject.GetGameObject(CONSTANTS.LABELS.HANGER);
		mission_data.key_objects.Supply = gameobject.GetGameObject(CONSTANTS.LABELS.SUPPLY);
		mission_data.key_objects.Tug = gameobject.GetGameObject(CONSTANTS.LABELS.TUG);
		mission_data.key_objects.Tug:RemovePilot();
		mission_data.key_objects.ControlTower = gameobject.GetGameObject(CONSTANTS.LABELS.CONTROL);
		SetMaxScrap(2,10000);
		mission_data.key_objects.Player:SetPerceivedTeam(2); -- Make sure player isn't detected right away.
		
		for i = 1, 5 do
			local navtmp = gameobject.GetGameObject(CONSTANTS.LABELS.NAV[i]); -- Harvests the current nav's coordinates then deletes it. The saved coordinates are used later to respawn the nav when it is needed.
			if navtmp then
				mission_data.NavCoord[i] = navtmp:GetPosition();
				navtmp:RemoveObject();
			end
		end
		
		for i = 1, 6 do
			gameobject.GetGameObject(CONSTANTS.LABELS.PATROL[1][i]):Patrol("patrol_1", 1);
		end
		for i = 1, 10 do
			gameobject.GetGameObject(CONSTANTS.LABELS.PATROL[2][i]):Patrol("patrol_2", 1);
		end
		for i = 1, 9 do
			gameobject.GetGameObject(CONSTANTS.LABELS.PATROL[3][i]):Patrol("patrol_3", 1);
		end
		
		state:next();
		
		-- Pre-play setup complete. Time to start the shit.
		camera.Start();
		AudioMessage(CONSTANTS.AUDIO.INTRO);

		mission_data.mission_states
			:on("detection_check_perceived_team")
			:on("hanger_still_alive")
			:on("mammoth_destroyed");

		return statemachine.FastResult();
	end },
	{ "cinematic", function (state)
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		if camera.Canceled() or camera.FollowPathAimFollowPath("pan_path", 10, 3, "pan_target_path") then
			state:next();
			return statemachine.FastResult();
		end
	end },
	{ "cinematic2", function (state)
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		if camera.Canceled() or camera.FollowPathAimFollowPath("pan2_path", 5, 3, "pan2_target_path", 0, 2) then
			state:next();
			return statemachine.FastResult();
		end
	end },
	{ "cinematic3", function (state)
		--- @cast state main_objectives03_state
		
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		--if camera.FollowPathAimObject("camera_path", 1000, 2000, mission_data.key_objects.Mammoth) or camera.Canceled() then
		if camera.Canceled() or camera.FollowPathAimFollowPath("pan3_path", 15, 4, "pan3_target_path", 0, 2) then
			camera.End();
			SpawnNav(1);
			state:next();

			objective.AddObjective(CONSTANTS.OBJECTIVES.DETECTION, "WHITE");
			objective.AddObjective(CONSTANTS.OBJECTIVES.HANGER, "WHITE");

			--UpdateObjectives();
			mission_data.mission_states
				:on("detection_check_radar_tower_1")
				:on("detection_check_radar_tower_2")
				:on("detection_check_radar_tower_3")
				:on("mammoth_shield"); -- double sure it's on
			
			state.shield_up = nil;
			return;
		end
		local cam_pos = camera.GetPosition();

		-- turn the shield on once the camera exits the shield area
		if not state.shield_up and mission_data.key_objects.Mammoth:GetDistance(cam_pos) > 40 then
			mission_data.mission_states:on("mammoth_shield");
			state.shield_up = true;
		end
	end },
	{ "hanger_info", function (state)
		if mission_data.key_objects.Hangar:IsAlive() and mission_data.key_objects.Player and mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Hangar) < 50.0 then
			AudioMessage(CONSTANTS.AUDIO.INSPECT);
			SpawnNav(2);
			objective.RemoveObjective(CONSTANTS.OBJECTIVES.HANGER);
			--UpdateObjectives();
			state:next();

			mission_data.mission_states:off("hanger_still_alive");
			objective.AddObjective(CONSTANTS.OBJECTIVES.TUG, "WHITE");
		end
	end },
	{ "aquire_tug", function (state)
		if mission_data.key_objects.Player == mission_data.key_objects.Tug then
			objective.UpdateObjective(CONSTANTS.OBJECTIVES.TUG, "GREEN");
			objective.AddObjective(CONSTANTS.OBJECTIVES.MAMMOTH_1, "WHITE");
			--UpdateObjectives();
			AudioMessage(CONSTANTS.AUDIO.TUG);
			SpawnNav(3)
			state:next();
		end
	end },
	{ "detect_shield", function (state)
		--if mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Mammoth) < 225.0 then
		if mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Mammoth) < 125.0 then
			mission_data.playerSLF = gameobject.BuildObject("bvslf", 1, "NukeSpawn", 1);
			SetMaxScrap(1, 20);
			SetScrap(1, 20);
			AudioMessage(CONSTANTS.AUDIO.FIRST_A);
			SpawnNav(4);
			objective.UpdateObjective(CONSTANTS.OBJECTIVES.MAMMOTH_1, "GREEN");
			objective.AddObjective(CONSTANTS.OBJECTIVES.CONTROL, "WHITE");
			--UpdateObjectives();
			state:next();
		end
	end },
	{ "armory_build_detect", function (state)
		if mission_data.playerSLF:IsValid() then
			mission_data.armoryCommand = mission_data.playerSLF:GetCurrentCommand();
			--print(mission_data.armoryCommand);
			--if mission_data.armoryCommand == AiCommand.BUILD and not mission_data.pollArmoryWho then
			--	mission_data.pollArmoryWho = true;
			--end
			if mission_data.armoryCommand == AiCommand.BUILD then
				state:next();
			end
		end
	end },
	{ "armory_who_poll", function (state)
		local temp = mission_data.playerSLF:GetCurrentWho();
		if temp and temp:IsValid() then
			mission_data.armoryTarget = temp;
			--print(mission_data.armoryTarget);
			mission_data.pollArmoryWho = false;
			state:next();
		end
	end },
	{ "wrecker", function (state)
		-- found set via a watcher in CreateObject for daywrecker instances
		if mission_data.key_objects.Wrecker and mission_data.key_objects.Wrecker:IsValid() then
			--if not mission_data.impactPending and not mission_data.wreckerTargetMissed then
				print(mission_data.armoryTarget, mission_data.armoryTarget.__type, table.show(mission_data.armoryTarget,"armoryTarget"))
				print(mission_data.key_objects.ControlTower, mission_data.key_objects.ControlTower.__type, table.show(mission_data.key_objects.ControlTower,"ControlTower"))
				print(mission_data.armoryTarget == mission_data.key_objects.ControlTower)
				if mission_data.armoryTarget == mission_data.key_objects.ControlTower then
					mission_data.impactPending = true;
					state:next();
					objective.UpdateObjective(CONSTANTS.OBJECTIVES.CONTROL, color.ColorLabel.Yellow);
					--UpdateObjectives(); --yellow
					-- there is no yellow objective, old comment?
				else

					AudioMessage(CONSTANTS.AUDIO.LOSS_AIM_DAY_WRECKER);
					FailMission(GetTime() + 5.0, CONSTANTS.DEBRIEFING.LOSS_WRECKER_MISSED);
					mission_data.wreckerTargetMissed = true;
					objective.UpdateObjective(CONSTANTS.OBJECTIVES.CONTROL, "RED");
					--UpdateObjectives(); --red
					-- there is no objective for this, old comment?
					state:switch(nil);
					return statemachine.AbortResult();
				end
			--end
		else
			-- can we kick back here to the armory build check?
			-- @todo I think we should switch back to "armory_build_detect" here, but I don't know the exact mechanisms in play to say for sure
			-- looks like there's some lag time here before it's valid
		end
	end },
	{ "impact_pending", function (state)
		if not mission_data.key_objects.Wrecker:IsValid() then
			-- we should expect a dead shield control tower right about now
			if not mission_data.key_objects.ControlTower:IsValid() then
				mission_data.mission_states:off("mammoth_shield");
				mission_data.impactPending = false;
				
				objective.UpdateObjective(CONSTANTS.OBJECTIVES.CONTROL, "GREEN");

				--UpdateObjectives(); -- green
				AudioMessage(CONSTANTS.AUDIO.DAY_W);
				mission_data.key_objects.ObjectiveNav:SetObjectiveOff();
				mission_data.key_objects.Mammoth:SetObjectiveOn();
				mission_data.key_objects.Mammoth:SetObjectiveName(CONSTANTS.NAMES.MAMMOTH);
				SpawnArmy();
				state:next();
				objective.AddObjective(CONSTANTS.OBJECTIVES.MAMMOTH_2, "WHITE");
			-- else
				-- if not M.wreckerTargetMissed == true then
					-- AudioMessage(constants.audio.lose4);
					-- FailMission(GetTime() + 5.0, constants.debriefing.rbdnew03l5);
					-- M.wreckerTargetMissed = true;
					-- UpdateObjectives(); --red
				-- end
			end
		else
			-- @todo we need an else condition here, unless we need to wait an extra Update to be safe, but I think the explosion should have been instant yes?
			-- Might be good to expand this state with a sleep and re-check on the target structure
		end
	end },
	{ "reach_mammoth_2", function (state)
		if mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Mammoth) < 35 then
			mission_data.mission_states
				:off("detection_check_perceived_team")
				:off("detection_check_radar_tower_1")
				:off("detection_check_radar_tower_2")
				:off("detection_check_radar_tower_3");
			objective.RemoveObjective(CONSTANTS.OBJECTIVES.DETECTION); -- should this be done sooner?
			objective.ReplaceObjective(CONSTANTS.OBJECTIVES.MAMMOTH_2, CONSTANTS.OBJECTIVES.TRAN_START, "WHITE"); -- should this be done sooner?
			--UpdateObjectives();
			if not mission_data.MammothReachedBefore then
				AudioMessage(CONSTANTS.AUDIO.SECOND_A);
				mission_data.MammothReachedBefore = true;
			else
				AudioMessage(CONSTANTS.AUDIO.BACK_IN_RANGE)
			end
			state:next();
		end
	end },
	{ "mammoth_scan_waiting", function (state)
		if state:SecondsHavePassed(10) then
			state:next();
		elseif mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Mammoth) > 35 then
			state:SecondsHavePassed();
			--UpdateObjectives();
			AudioMessage(CONSTANTS.AUDIO.TRANSINT);
			objective.ReplaceObjective(CONSTANTS.OBJECTIVES.TRAN_START, CONSTANTS.OBJECTIVES.MAMMOTH_2, "WHITE");
			state:switch("reach_mammoth_2");
		end
	end },
	{ "mammoth_scan_finished", function (state)
        AudioMessage(CONSTANTS.AUDIO.FLEE);
        StartCockpitTimer(unpack(CONSTANTS.RUNAWAY_TIMER));
		mission_data.key_objects.Mammoth:SetObjectiveOff();
--		BuildObject("bvapc", 3, GetPositionNear(GetPosition(GetHandle("nav5"))));
        SpawnNav(5);
		objective.ReplaceObjective(CONSTANTS.OBJECTIVES.TRAN_START, CONSTANTS.OBJECTIVES.TRAN_FIN, "GREEN");
		objective.AddObjective(CONSTANTS.OBJECTIVES.EXTRACT, "WHITE");
        --UpdateObjectives();
        mission_data.key_objects.Player:SetPerceivedTeam(1);
		for _, v in pairs(mission_data.key_objects.Defenders) do
			if v:GetOdf() ~= "svwalk" then
                v:Attack(mission_data.key_objects.Player);
			end
		end
		state:next();
	end },
	{ "run_away", function (state)
		--- @cast state main_objectives03_state
		
		if mission_data.key_objects.ObjectiveNav:GetObjectiveName() == CONSTANTS.NAMES.EXTRACTION_POINT and mission_data.key_objects.Player and mission_data.key_objects.Player:GetDistance(mission_data.key_objects.ObjectiveNav) < 50.0 then
			AudioMessage(CONSTANTS.AUDIO.WIN);
			SucceedMission(GetTime()+5.0, CONSTANTS.DEBRIEFING.WIN); -- mission complete
			objective.UpdateObjective(CONSTANTS.OBJECTIVES.EXTRACT, "GREEN");
			--UpdateObjectives();
			state:next();
		elseif GetCockpitTimer() == 0 then
			AudioMessage(CONSTANTS.AUDIO.LOSS_FAILED_EXTRACT);
			FailMission(GetTime() + 5.0, CONSTANTS.DEBRIEFING.LOSS_LEFT_BEHIND); -- time expired
			--UpdateObjectives();
			state:next();
		elseif not state.did_hurry and GetCockpitTimer() < CONSTANTS.HURRY_THRESHHOLD then
			-- if we haven't hurried yet, hurry up!
			AudioMessage(CONSTANTS.AUDIO.HURRY);
			state.did_hurry = true;
		end
	end }
});

statemachine.Create("detection_check_radar_tower", {
	{ "start", function (state)
		--- @cast state detection_check_radar_tower_state
		state.object = gameobject.GetGameObject(state.label);
		print(color.AnsiColorEscapeMap.MAGENTA.."Radar \""..state.label.."\" "..tostring(state.object).." found!"..color.AnsiColorEscapeMap.RESET);
		if not state.object then
			print("Radar "..state.label.." not found! Disabling detection checker.");
			state:switch(nil);
			return statemachine.AbortResult();
		end
		state:next();
	end },
	{ "check", function (state)
		--- @cast state detection_check_radar_tower_state
		if not mission_data.key_objects.Player then
			-- Player object is not available so abort the state logic.
			return;
		end
		if state.object:IsAlive() then
			if mission_data.key_objects.Player:GetDistance(state.object) < 100.0 then
				AudioMessage(CONSTANTS.AUDIO.COMM_WARN);
				StartCockpitTimer(30, 15, 5);
				state:next();
			end
		else
			-- Radar tower is dead, no need to check it anymore.
			state:switch(nil);
			return statemachine.AbortResult();
		end
	end },
	{ "too_close", function (state)
		--- @cast state detection_check_radar_tower_state
		if not mission_data.key_objects.Player then
			-- Player object is not available so abort the state logic.
			return;
		end
		if mission_data.key_objects.Player:GetDistance(state.object) > 100.0 then
			AudioMessage(CONSTANTS.AUDIO.COMM_CLEAR);
			state:SecondsHavePassed();
			state:switch("check");
			StopCockpitTimer();
			HideCockpitTimer();
		--elseif state:SecondsHavePassed(30) then
		elseif GetCockpitTimer() == 0 then
			--UpdateObjectives();
			-- this is a failure state
			-- Show Failed No-Detect Objective
			-- Trigger Game Over
			FailByDetection();

			state:switch(nil);
			return statemachine.AbortResult(); -- save CPU by telling stateset to stop checking this statemachine
		end
	end }		
});

--- @todo a hop-out triggers this too, so I question if that should be seen as odd behavior or not
statemachine.Create("detection_check_perceived_team", {
	{ "start", function (state)
		--- @cast state detection_check_perceived_team_state
		local player = mission_data.key_objects.Player;
		if player and player:GetPerceivedTeam() == 1 then
			-- find everyone who saw that
			print("Detection check: looking for angry bees");

			state.AngryBees = {};
			local time = GetTime();
			local foundTarget = false;
			
			-- Scan the area around the player for potential targets
			-- If they are not allies note them
			-- If they are not allies and they were shot by the player recently note them and search around them for other targets
			for candidate in gameobject.ObjectsInRange(CONSTANTS.sniper_range, player) do
				if candidate then
					if candidate:GetTeamNum() ~= 0 and not candidate:IsAlly(player) then
						if not foundTarget and candidate:GetWhoShotMe() == player and candidate:GetLastEnemyShot() + CONSTANTS.detection_range_time > time then
							-- we shot this guy recently, so he is angry
							if candidate:IsCraft() or candidate:IsPerson() then
								state.AngryBees[candidate] = true;
							end
							foundTarget = true;
							for sub_candidate in gameobject.ObjectsInRange(CONSTANTS.detection_range_target, candidate) do
								-- these guys saw he wa shot, so they are angry too
								if sub_candidate then
									if sub_candidate:GetTeamNum() ~= 0 and not sub_candidate:IsAlly(player) then
										if sub_candidate:IsCraft() or sub_candidate:IsPerson() then
											state.AngryBees[sub_candidate] = true;
										end
									end
								end
							end
						elseif candidate:GetDistance(player) < CONSTANTS.detection_range_player then
							-- this guy saw us shooting so even he's angry!
							if candidate:IsCraft() or candidate:IsPerson() then
								state.AngryBees[candidate] = true;
							end
						end
					end
				end
			end

			local HaveAngry = false;
			for angry, _ in pairs(state.AngryBees) do
				if angry then
					if angry:IsAliveAndPilot() then
						angry:SetObjectiveOn();
						HaveAngry = true;
					end
				end
			end

			if HaveAngry then
				-- if we have angry bees, we need to check them
				AudioMessage(CONSTANTS.AUDIO.DETECTED_KILL_THEM);
				objective.UpdateObjective(CONSTANTS.OBJECTIVES.DETECTION, "YELLOW");
				state:next(); -- begin the attempt to save yourself
			else
				-- if we don't have angry bees, we can just return
				player:SetPerceivedTeam(2);
				return;
			end
			-- if only dead people saw it, return perceived team to 2
		end
	end },
	{ "check", function (state)
		--- @cast state detection_check_perceived_team_state
		local player = mission_data.key_objects.Player;
		if state:SecondsHavePassed(CONSTANTS.detection_timeout) then
			state:SecondsHavePassed(); -- reset the timer
			FailByDetection();
			state:next();
			return statemachine.AbortResult(); -- I think this is implied by being in a nil state but, whatever
		end
		if player then
			local theyBeAngry = false;
			local shotMe = player:GetWhoShotMe();
			if shotMe then
				state.AngryBees[shotMe] = true; -- if we were shot by someone, they are angry too
			end
			for angry, _ in pairs(state.AngryBees) do
				if angry then
					if angry:IsAliveAndPilot() and not angry:IsAlly(player) then
						-- bee still angry
						theyBeAngry = true;
						--break; -- can't break since we're removing objectives on calm bees
						angry:SetObjectiveOn(); -- maybe they can become re-angry?
					else
						angry:SetObjectiveOff();
					end
				end
			end
			if not theyBeAngry then
				state:SecondsHavePassed(); -- reset the timer
				objective.UpdateObjective(CONSTANTS.OBJECTIVES.DETECTION, "WHITE");
				state:switch("start"); -- no more angry bees, we can return to perceived team 2
				player:SetPerceivedTeam(2);
				return;
			end
		end
	end }
});

stateset.Create("mission")
	:Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
	:Add("scrap_field_filler_1", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld1" }))
	:Add("detection_check_perceived_team", stateset.WrapStateMachine("detection_check_perceived_team"))
	:Add("detection_check_radar_tower_1", stateset.WrapStateMachine("detection_check_radar_tower", nil, { label = CONSTANTS.LABELS.RADAR[1] }))
	:Add("detection_check_radar_tower_2", stateset.WrapStateMachine("detection_check_radar_tower", nil, { label = CONSTANTS.LABELS.RADAR[2] }))
	:Add("detection_check_radar_tower_3", stateset.WrapStateMachine("detection_check_radar_tower", nil, { label = CONSTANTS.LABELS.RADAR[3] }))
	:Add("hanger_still_alive", function (state, name)
		if not mission_data.key_objects.Hangar:IsAlive() then
			FailMission(GetTime()+5.0, CONSTANTS.DEBRIEFING.LOSS_HANGER_DESTROYED); -- hangar destroyed
			objective.UpdateObjective(CONSTANTS.OBJECTIVES.HANGER, "RED");
			--UpdateObjectives();
		end
	end)
	:Add("mammoth_shield", stateset.WrapStateMachine("mammoth_shield"))
	:Add("mammoth_destroyed", function (state, name)
		if not mission_data.key_objects.Mammoth:IsAlive() then
			AudioMessage(CONSTANTS.AUDIO.LOSS_MAMMOTH_DESTROYED);
			FailMission(GetTime()+5.0, CONSTANTS.DEBRIEFING.LOSS_MAMMOTH_DESTROYED); -- mammoth destroyed
			--UpdateObjectives();
		end
	end);

hook.Add("Start", "Mission:Start", function ()
    mission_data.mission_states = stateset.Start("mission")
		:on("scrap_field_filler_1")
		:on("main_objectives");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
	mission_data.key_objects.Player = gameobject.GetPlayer();
	mission_data.mission_states:run();
end);

hook.AddSaveLoad("Mission",
function()
    return mission_data;
end,
function(g)
    mission_data = g;
end);

print("\27[34m----END MISSION----\27[0m");
--- @todo remove dev cheats and modules
require("_audio_dev");

--- @class main_objectives03_state : StateMachineIter
--- @field shield_up boolean? Camera mammoth shield activation debounce, temporary
--- @field did_hurry boolean? Did we play the hurry audio message?

--- @class scrap_field_filler_state_03 : StateMachineIter
--- @field path string Path to the scrap field.
--- @field scrap_objects GameObject[] Table of scrap objects in the field.
--- @field scrap_options string[] Table of scrap odf options to choose from.

--- @class detection_check_radar_tower_state : StateMachineIter
--- @field label string
--- @field object GameObject?

--- @class detection_check_perceived_team_state : StateMachineIter
--- @field AngryBees table<GameObject, boolean> A table of angry bees (non-ally units that saw the player lose perceived team).