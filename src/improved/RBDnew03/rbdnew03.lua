--[[
	Contributors:
	 - Herp McDerperson
	 - Seqan
	 - GBD
	 - Vemahk
	 - Janne
--]]

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












local function choose(...)
    local t = {...};
    local rn = math.random(#t);
    return t[rn];
end

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
NavCoord = { }
}




local function SpawnNav(num) -- Spawns the Nth Nav point.
	local nav = navmanager.BuildImportantNav("apcamr", 1, mission_data.NavCoord[num]); -- Make the nav from the harvested coordinates.
	if not nav then error("Nav "..num.." failed to spawn!"); end -- If the nav fails to spawn, throw an error.
	nav:SetObjectiveName("Nav "..num); -- Set its name
	if num == 5 then
		nav:SetObjectiveName("Extraction Point"); -- If it's the 5th nav, change its name. This is the name it checks for for the Win Condition; if you change this, change the win condition script as well.
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
	local obj = gameobject.BuildGameObject(odf, 2, fp, fpp)
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
	AudioMessage(audio.lose4);
	FailMission(GetTime() + 5.0, "rbdnew03l4.des"); -- cover blown
	objective.UpdateObjective(objectives.Detection, "RED");
end

--- @class scrap_field_filler_state_03 : StateMachineIter
--- @field path string Path to the scrap field.
--- @field scrap_objects GameObject[] Table of scrap objects in the field.
--- @field scrap_options string[] Table of scrap odf options to choose from.
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
					state.scrap_objects[i] = gameobject.BuildGameObject(choose(table.unpack(state.scrap_options)), 0, GetPositionNear(pos, 1, 35));
				end
			end
		end
	end }
});

--- @class mammoth_shield_state : StateMachineIter
--- @field first boolean DoWhile simulating bool
statemachine.Create("mammoth_shield", function (state)
		--- @cast state mammoth_shield_state
		keepOutside(mission_data.key_objects.Player, mission_data.key_objects.Mammoth);
		if state:SecondsHavePassed(3.5, true) or not state.first then
			MakeExplosion("sdome", mission_data.key_objects.Mammoth:GetHandle());
			state.first = true;
		end
	end);

statemachine.Create("main_objectives", {
	{ "start", function (state)
		ColorFade(1.1, 0.4, 0, 0, 0);
		mission_data.key_objects.Mammoth = gameobject.GetGameObject("mammoth");
		mission_data.key_objects.Mammoth:SetIndependence(0); -- Mammoth shouldn't respond or do anything in this mission.
		mission_data.key_objects.Hangar = gameobject.GetGameObject("hangar");
		mission_data.key_objects.Supply = gameobject.GetGameObject("supply");
		mission_data.key_objects.Tug = gameobject.GetGameObject("tug");
		mission_data.key_objects.Tug:RemovePilot();
		mission_data.key_objects.ControlTower = gameobject.GetGameObject("control");
		SetMaxScrap(2,10000);
		mission_data.key_objects.Player:SetPerceivedTeam(2); -- Make sure player isn't detected right away.
		
		for i = 1, 5 do
			local navtmp = gameobject.GetGameObject("nav"..i); -- Harvests the current nav's coordinates then deletes it. The saved coordinates are used later to respawn the nav when it is needed.
			if navtmp then
				mission_data.NavCoord[i] = navtmp:GetPosition();
				navtmp:RemoveObject();
			end
		end
		
		for i = 1, 6 do
			gameobject.GetGameObject("patrol1_" .. i):Patrol("patrol_1", 1);
		end
		for i = 1, 10 do
			gameobject.GetGameObject("patrol2_" .. i):Patrol("patrol_2", 1);
		end
		for i = 1, 9 do
			gameobject.GetGameObject("patrol3_" .. i):Patrol("patrol_3", 1)
		end
		
		state:next();
		
		-- Pre-play setup complete. Time to start the shit.
		camera.CameraReady();
		AudioMessage(audio.intro);

		mission_data.mission_states
			:on("detection_check_perceived_team")
			:on("hanger_still_alive")
			:on("mammoth_destroyed");

		return statemachine.FastResult();
	end },
	{ "cinematic", function (state)
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		if camera.CameraPathPathFollow("pan_path", 1000, 300, "pan_target_path") or camera.CameraCancelled() then
			state:next();
			return statemachine.FastResult();
		end
	end },
	{ "cinematic2", function (state)
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		if camera.CameraPathPathFollow("pan2_path", 1000, 300, "pan2_target_path", 0, 200) or camera.CameraCancelled() then
			state:next();
			return statemachine.FastResult();
		end
	end },
	{ "cinematic3", function (state)
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		--if camera.CameraPath("camera_path", 1000, 2000, mission_data.key_objects.Mammoth) or camera.CameraCancelled() then
		if camera.CameraPathPathFollow("pan3_path", 1500, 400, "pan3_target_path", 0, 200) or camera.CameraCancelled() then
			camera.CameraFinish();
			SpawnNav(1);
			state:next();

			objective.AddObjective(objectives.Detection, "WHITE");
			objective.AddObjective(objectives.Hanger, "WHITE");

			--UpdateObjectives();
			mission_data.mission_states
				:on("detection_check_radar_tower_1")
				:on("detection_check_radar_tower_2")
				:on("detection_check_radar_tower_3");
		end
		local cam_pos = camera.GetCameraPosition();

		-- turn the shield on once the camera exits the shield area
		if not mission_data.shield_up and mission_data.key_objects.Mammoth:GetDistance(cam_pos) > 40 then
			mission_data.mission_states:on("mammoth_shield");
			mission_data.shield_up = true;
		end
	end },
	{ "hanger_info", function (state)
		if mission_data.key_objects.Hangar:IsAlive() and mission_data.key_objects.Player and mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Hangar) < 50.0 then
			AudioMessage(audio.inspect);
			SpawnNav(2);
			objective.RemoveObjective(objectives.Hanger);
			--UpdateObjectives();
			state:next();

			mission_data.mission_states:off("hanger_still_alive");
			objective.AddObjective(objectives.Tug, "WHITE");
		end
	end },
	{ "aquire_tug", function (state)
		if mission_data.key_objects.Player == mission_data.key_objects.Tug then
			objective.UpdateObjective(objectives.Tug, "GREEN");
			objective.AddObjective(objectives.Mammoth1, "WHITE");
			--UpdateObjectives();
			AudioMessage(audio.tug);
			SpawnNav(3)
			state:next();
		end
	end },
	{ "detect_shield", function (state)
		if mission_data.key_objects.Player:GetDistance(mission_data.key_objects.Mammoth) < 225.0 then
			mission_data.playerSLF = gameobject.BuildGameObject("bvslf", 1, "NukeSpawn", 1);
			SetMaxScrap(1, 20);
			SetScrap(1, 20);
			AudioMessage(audio.first_a);
			SpawnNav(4);
			objective.UpdateObjective(objectives.Mammoth1, "GREEN");
			objective.AddObjective(objectives.Control, "WHITE");
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
				print(mission_data.armoryTarget == mission_data.key_objects.ControlTower)
				if mission_data.armoryTarget == mission_data.key_objects.ControlTower then
					mission_data.impactPending = true;
					state:next();
					objective.UpdateObjective(objectives.Control, color.ColorLabel.Yellow);
					--UpdateObjectives(); --yellow
					-- there is no yellow objective, old comment?
				else

					AudioMessage(audio.lose4);
					FailMission(GetTime() + 5.0, "rbdnew03l5.des");
					mission_data.wreckerTargetMissed = true;
					objective.UpdateObjective(objectives.Control, "RED");
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
				
				objective.UpdateObjective(objectives.Control, "GREEN");

				--UpdateObjectives(); -- green
				AudioMessage(audio.dayw);
				mission_data.key_objects.ObjectiveNav:SetObjectiveOff();
				mission_data.key_objects.Mammoth:SetObjectiveOn();
				mission_data.key_objects.Mammoth:SetObjectiveName("Mammoth");
				SpawnArmy();
				state:next();
				objective.AddObjective(objectives.Mammoth2, "WHITE");
			-- else
				-- if not M.wreckerTargetMissed == true then
					-- AudioMessage(audio.lose4);
					-- FailMission(GetTime() + 5.0, "rbdnew03l5.des");
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
			objective.RemoveObjective(objectives.Detection); -- should this be done sooner?
			objective.ReplaceObjective(objectives.Mammoth2, objectives.TranStart, "WHITE"); -- should this be done sooner?
			--UpdateObjectives();
			if not mission_data.MammothReachedBefore then
				AudioMessage(audio.second_a);
				mission_data.MammothReachedBefore = true;
			else
				AudioMessage(audio.backinrange)
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
			AudioMessage(audio.transint);
			objective.ReplaceObjective(objectives.TranStart, objectives.Mammoth2, "WHITE");
			state:switch("reach_mammoth_2");
		end
	end },
	{ "mammoth_scan_finished", function (state)
        AudioMessage(audio.flee);
        StartCockpitTimer(120, 30, 10);
		mission_data.key_objects.Mammoth:SetObjectiveOff();
--		BuildObject("bvapc", 3, GetPositionNear(GetPosition(GetHandle("nav5"))));
        SpawnNav(5);
		objective.ReplaceObjective(objectives.TranStart, objectives.TranFin, "GREEN");
		objective.AddObjective(objectives.Extract, "WHITE");
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
		if mission_data.key_objects.ObjectiveNav:GetObjectiveName() == "Extraction Point" and mission_data.key_objects.Player and mission_data.key_objects.Player:GetDistance(mission_data.key_objects.ObjectiveNav) < 50.0 then
			AudioMessage(audio.win);
			SucceedMission(GetTime()+5.0, "rbdnew03wn.des"); -- mission complete
			objective.UpdateObjective(objectives.Extract, "GREEN");
			--UpdateObjectives();
			state:next();
		elseif GetCockpitTimer() == 0 then
			AudioMessage(audio.lose2);
			FailMission(GetTime() + 5.0, "rbdnew03l2.des"); -- time expired
			--UpdateObjectives();
			state:next();
		end
	end }
});

--- @class detection_check_radar_tower_state : StateMachineIter
--- @field label string
--- @field object GameObject?

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
		if state.object:IsAlive() then
			if mission_data.key_objects.Player:GetDistance(state.object) < 100.0 then
				AudioMessage(audio.commwarn);
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
		if mission_data.key_objects.Player:GetDistance(state.object) > 100.0 then
			AudioMessage(audio.commclear);
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

stateset.Create("mission")
	:Add("main_objectives", stateset.WrapStateMachine("main_objectives"))
	:Add("scrap_field_filler_1", stateset.WrapStateMachine("scrap_field_filler", nil, { path = "scrpfld1" }))
	:Add("detection_check_perceived_team", function(state, name)
		if mission_data.key_objects.Player and mission_data.key_objects.Player:GetPerceivedTeam() == 1 then
			--UpdateObjectives();
			-- this is a failure state
			-- Show Failed No-Detect Objective
			-- Trigger Game Over
			FailByDetection();
			
			state:off(name); -- turn this check off
		end
	end)
	:Add("detection_check_radar_tower_1", stateset.WrapStateMachine("detection_check_radar_tower", nil, { label = "radar1" }))
	:Add("detection_check_radar_tower_2", stateset.WrapStateMachine("detection_check_radar_tower", nil, { label = "radar2" }))
	:Add("detection_check_radar_tower_3", stateset.WrapStateMachine("detection_check_radar_tower", nil, { label = "radar3" }))
	:Add("hanger_still_alive", function (state, name)
		if not mission_data.key_objects.Hangar:IsAlive() then
			FailMission(GetTime()+5.0, "rbdnew03l3.des"); -- hangar destroyed
			objective.UpdateObjective(objectives.Hanger, "RED");
			--UpdateObjectives();
		end
	end)
	:Add("mammoth_shield", stateset.WrapStateMachine("mammoth_shield"))
	:Add("mammoth_destroyed", function (state, name)
		if not mission_data.key_objects.Mammoth:IsAlive() then 
			AudioMessage(audio.lose1);
			FailMission(GetTime()+5.0, "rbdnew03l1.des"); -- mammoth destroyed
			--UpdateObjectives();
		end
	end);

hook.Add("Start", "Mission:Start", function ()
    mission_data.mission_states = stateset.Start("mission")
		:on("scrap_field_filler_1")
		:on("main_objectives");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
	mission_data.key_objects.Player = gameobject.GetPlayerGameObject();
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

print("COLOR TEST Exact ["..
color.RGBAtoAnsi24Escape(color.ColorValues.BLACK    ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKGREY   ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.GREY     ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.WHITE    ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.BLUE     ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKBLUE   ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.GREEN    ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKGREEN  ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.YELLOW   ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKYELLOW ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.RED      ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKRED    ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.CYAN     ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKCYAN   ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.MAGENTA  ).."██"..
color.RGBAtoAnsi24Escape(color.ColorValues.DKMAGENTA).."██"..
color.AnsiColorEscapeMap._.."]");

print("COLOR TEST 256   ["..
color.RGBAtoAnsi256Escape(color.ColorValues.BLACK    ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKGREY   ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.GREY     ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.WHITE    ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.BLUE     ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKBLUE   ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.GREEN    ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKGREEN  ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.YELLOW   ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKYELLOW ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.RED      ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKRED    ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.CYAN     ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKCYAN   ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.MAGENTA  ).."██"..
color.RGBAtoAnsi256Escape(color.ColorValues.DKMAGENTA).."██"..
color.AnsiColorEscapeMap._.."]");

print("COLOR TEST 16p   ["..
color.AnsiColorEscapeMap.BLACK    .."██"..
color.AnsiColorEscapeMap.DKGREY   .."██"..
color.AnsiColorEscapeMap.GREY     .."██"..
color.AnsiColorEscapeMap.WHITE    .."██"..
color.AnsiColorEscapeMap.BLUE     .."██"..
color.AnsiColorEscapeMap.DKBLUE   .."██"..
color.AnsiColorEscapeMap.GREEN    .."██"..
color.AnsiColorEscapeMap.DKGREEN  .."██"..
color.AnsiColorEscapeMap.YELLOW   .."██"..
color.AnsiColorEscapeMap.DKYELLOW .."██"..
color.AnsiColorEscapeMap.RED      .."██"..
color.AnsiColorEscapeMap.DKRED    .."██"..
color.AnsiColorEscapeMap.CYAN     .."██"..
color.AnsiColorEscapeMap.DKCYAN   .."██"..
color.AnsiColorEscapeMap.MAGENTA  .."██"..
color.AnsiColorEscapeMap.DKMAGENTA.."██"..
color.AnsiColorEscapeMap._.."]");

local rave_exact = "";
for i = 1, #color.RAVE_COLOR do
	rave_exact = rave_exact..color.RGBAtoAnsi24Escape(color.RAVE_COLOR[i]).."█";
end
print("COLOR TEST RAVE Exact    ["..rave_exact..color.AnsiColorEscapeMap._.."]");

local rave_256 = "";
for i = 1, #color.RAVE_COLOR do
	rave_256 = rave_256..color.RGBAtoAnsi256Escape(color.RAVE_COLOR[i]).."█";
end
print("COLOR TEST RAVE 256      ["..rave_256..color.AnsiColorEscapeMap._.."]");

local rave_16Map = "";
for i = 1, #color.RAVE_COLOR do
	rave_16Map = rave_16Map..color.RGBAtoAnsi24Escape(color.ColorValues[color.GetClosestColorCode(color.RAVE_COLOR[i])]).."█";
end
print("COLOR TEST RAVE 16->Exact["..rave_16Map..color.AnsiColorEscapeMap._.."]");

local rave_16 = "";
for i = 1, #color.RAVE_COLOR do
	rave_16 = rave_16..color.AnsiColorEscapeMap[color.GetClosestColorCode(color.RAVE_COLOR[i])].."█";
end
print("COLOR TEST RAVE 16p      ["..rave_16..color.AnsiColorEscapeMap._.."]");


require("_audio_dev");