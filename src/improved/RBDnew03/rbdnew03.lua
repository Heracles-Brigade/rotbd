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

local mission_data = { --Sets mission flow and progression. Booleans and values will be changed to "true" and appropriate names/integers as mission progresses. Necessary for save files to function as well as objective flow in later if statements.
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
Aud1 = 0
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
	if mission_data.ObjectiveNav then
		mission_data.ObjectiveNav:SetObjectiveOff();
	end
	nav:SetObjectiveOn();
	mission_data.ObjectiveNav = nav; -- Sets the new nav to the ObjectiveNav so that the next time this function is called, it can switch off of it.
end

local function SpawnFromTo(odf, fp, fpp, tp)
	local obj = gameobject.BuildGameObject(odf, 2, fp, fpp)
	if not obj then error("Failed to spawn "..odf.." from "..tostring(fp).." to "..tostring(tp)); end -- If the object fails to spawn, throw an error.
	obj:Goto(tp, 0);
	obj:SetLabel(fp.."_"..mission_data.NextDefender);
	mission_data.Defenders[mission_data.NextDefender] = obj;
	mission_data.NextDefender = mission_data.NextDefender + 1;
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
	if not mission_data.Wrecker and object:GetClassLabel() == "daywrecker" then
		mission_data.Wrecker = object
	end
end);


local function FailByDetection()
	Aud1 = AudioMessage(audio.lose4);
	FailMission(GetTime() + 5.0, "rbdnew03l4.des"); -- cover blown
	mission_data.MissionOver = true;
	objective.UpdateObjective(objectives.Detection, "RED");
end


--- @class scrap_field_filler_state : StateMachineIter
--- @field path string Path to the scrap field.
--- @field scrap_objects GameObject[] Table of scrap objects in the field.
--- @field scrap_options string[] Table of scrap odf options to choose from.

statemachine.Create("scrap_field_filler", {
	{ "start", function (state)
		--- @cast state scrap_field_filler_state
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
		--- @cast state scrap_field_filler_state
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
		keepOutside(mission_data.Player, mission_data.Mammoth);
		if state:SecondsHavePassed(3.5, true) or not state.first then
			MakeExplosion("sdome", mission_data.Mammoth:GetHandle());
			state.first = true;
		end
	end);

statemachine.Create("main_objectives", {
	{ "start", function (state)
		mission_data.Mammoth = gameobject.GetGameObject("mammoth");
		mission_data.Mammoth:SetIndependence(0); -- Mammoth shouldn't respond or do anything in this mission.
		mission_data.Hangar = gameobject.GetGameObject("hangar");
		mission_data.Supply = gameobject.GetGameObject("supply");
		mission_data.Tug = gameobject.GetGameObject("tug");
		mission_data.Tug:RemovePilot();
		mission_data.ControlTower = gameobject.GetGameObject("control");
		SetMaxScrap(2,10000);
		mission_data.Player:SetPerceivedTeam(2); -- Make sure player isn't detected right away.
		
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
		CameraReady();
		mission_data.Aud1 = AudioMessage(audio.intro);

		mission_data.mission_states
			:on("detection_check_perceived_team")
			:on("hanger_still_alive")
			:on("mammoth_destroyed");
	end },
	{ "cinematic", function (state)
		--Opening Cinematic. Show off Deus Ex's wondrous creation!
		if CameraPath("camera_path", 1000, 2000, mission_data.Mammoth:GetHandle()) or CameraCancelled() then
			CameraFinish();
			SpawnNav(1);
			mission_data.OpeningCinDone = true;
			state:next();

			objective.AddObjective(objectives.Detection, "WHITE");
			objective.AddObjective(objectives.Hanger, "WHITE");

			--UpdateObjectives();
			mission_data.mission_states
				:on("detection_check_radar_tower_1")
				:on("detection_check_radar_tower_2")
				:on("detection_check_radar_tower_3")
				:on("mammoth_shield");
		end
	end },
	{ "hanger_info", function (state)
		if mission_data.Hangar:IsAlive() and mission_data.Player and mission_data.Player:GetDistance(mission_data.Hangar) < 50.0 then
			mission_data.Aud1 = AudioMessage(audio.inspect);
			SpawnNav(2);
			mission_data.HangarInfoed = true;
			objective.RemoveObjective(objectives.Hanger);
			--UpdateObjectives();
			state:next();

			mission_data.mission_states:off("hanger_still_alive");
			objective.AddObjective(objectives.Tug, "WHITE");
		end
	end },
	{ "aquire_tug", function (state)
		if mission_data.Player == mission_data.Tug then
			mission_data.TugAquired = true;
			objective.UpdateObjective(objectives.Tug, "GREEN");
			objective.AddObjective(objectives.Mammoth1, "WHITE");
			--UpdateObjectives();
			mission_data.Aud1 = AudioMessage(audio.tug);
			SpawnNav(3)
			state:next();
		end
	end },
	{ "detect_shield", function (state)
		if mission_data.Player:GetDistance(mission_data.Mammoth) < 225.0 then
			mission_data.playerSLF = gameobject.BuildGameObject("bvslf", 1, "NukeSpawn", 1);
			mission_data.Armory = true;
			SetMaxScrap(1, 20);
			SetScrap(1, 20);
			mission_data.ShieldDetected = true;
			mission_data.Aud1 = AudioMessage(audio.first_a);
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
		if mission_data.Wrecker and mission_data.Wrecker:IsValid() then
			--if not mission_data.impactPending and not mission_data.wreckerTargetMissed then
				print(mission_data.armoryTarget == mission_data.ControlTower)
				if mission_data.armoryTarget == mission_data.ControlTower then
					mission_data.impactPending = true;
					state:next();
					objective.UpdateObjective(objectives.Control, color.ColorLabel.Yellow);
					--UpdateObjectives(); --yellow
					-- there is no yellow objective, old comment?
				else

					mission_data.Aud1 = AudioMessage(audio.lose4);
					FailMission(GetTime() + 5.0, "rbdnew03l5.des");
					mission_data.MissionOver = true;
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
		if not mission_data.Wrecker:IsValid() then
			-- we should expect a dead shield control tower right about now
			if not mission_data.ControlTower:IsValid() then
				mission_data.ControlDead = true;
				mission_data.mission_states:off("mammoth_shield");
				mission_data.impactPending = false;
				
				objective.UpdateObjective(objectives.Control, "GREEN");

				--UpdateObjectives(); -- green
				mission_data.Aud1 = AudioMessage(audio.dayw);
				mission_data.ObjectiveNav:SetObjectiveOff();
				mission_data.Mammoth:SetObjectiveOn();
				mission_data.Mammoth:SetObjectiveName("Mammoth");
				SpawnArmy();
				state:next();
				objective.AddObjective(objectives.Mammoth2, "WHITE");
			-- else
				-- if not M.wreckerTargetMissed == true then
					-- M.Aud1 = AudioMessage(audio.lose4);
					-- FailMission(GetTime() + 5.0, "rbdnew03l5.des");
					-- M.MissionOver = true;
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
		if mission_data.Player:GetDistance(mission_data.Mammoth) < 35 then
			mission_data.MammothTime = GetTime() + 10.0; -- Wait 10 seconds to gather info.
			mission_data.MammothReached = true;
			mission_data.mission_states
				:off("detection_check_perceived_team")
				:off("detection_check_radar_tower_1")
				:off("detection_check_radar_tower_2")
				:off("detection_check_radar_tower_3");
			objective.RemoveObjective(objectives.Detection); -- should this be done sooner?
			objective.ReplaceObjective(objectives.Mammoth2, objectives.TranStart, "WHITE"); -- should this be done sooner?
			--UpdateObjectives();
			if not mission_data.MammothReachedPrevious then
				mission_data.Aud1 = AudioMessage(audio.second_a);
				mission_data.MammothReachedPrevious = true;
			else
				mission_data.Aud1 = AudioMessage(audio.backinrange)
			end
			state:next();
		end
	end },
	{ "mammoth_scan_waiting", function (state)
		if GetTime() < mission_data.MammothTime then
			if mission_data.MammothReached and mission_data.Player:GetDistance(mission_data.Mammoth) > 35 then
				mission_data.MammothTime = 0;
				mission_data.MammothReached = false;
				--UpdateObjectives();
				mission_data.Aud1 = AudioMessage(audio.transint);
				objective.ReplaceObjective(objectives.TranStart, objectives.Mammoth2, "WHITE");
				state:switch("reach_mammoth_2");
			end
		else
			state:next();
		end
	end },
	{ "mammoth_scan_finished", function (state)
        mission_data.Aud1 = AudioMessage(audio.flee);
        StartCockpitTimer(120, 30, 10);
		mission_data.Mammoth:SetObjectiveOff();
--		BuildObject("bvapc", 3, GetPositionNear(GetPosition(GetHandle("nav5"))));
        SpawnNav(5);
        mission_data.MammothInfoed = true;
		objective.ReplaceObjective(objectives.TranStart, objectives.TranFin, "GREEN");
		objective.AddObjective(objectives.Extract, "WHITE");
        --UpdateObjectives();
        mission_data.Player:SetPerceivedTeam(1);
        for i=1, 18 do
            local tmp = mission_data.Defenders[i];
            if tmp:GetOdf() ~= "svwalk" then
                tmp:Attack(mission_data.Player);
            end
        end
		state:next();
	end },
	{ "run_away", function (state)
		if mission_data.ObjectiveNav:GetObjectiveName() == "Extraction Point" and mission_data.Player and mission_data.Player:GetDistance(mission_data.ObjectiveNav) < 50.0 then
			Aud1 = AudioMessage(audio.win);
			SucceedMission(GetTime()+5.0, "rbdnew03wn.des"); -- mission complete
			mission_data.MissionOver = true;
			mission_data.SafetyReached = true;
			objective.UpdateObjective(objectives.Extract, "GREEN");
			--UpdateObjectives();
			state:next();
		elseif GetCockpitTimer() == 0 then
			Aud1 = AudioMessage(audio.lose2);
			FailMission(GetTime() + 5.0, "rbdnew03l2.des"); -- time expired
			mission_data.MissionOver = true;
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
			if mission_data.Player:GetDistance(state.object) < 100.0 then
				mission_data.Aud1 = AudioMessage(audio.commwarn);
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
		if mission_data.Player:GetDistance(state.object) > 100.0 then
			Aud1 = AudioMessage(audio.commclear);
			state:SecondsHavePassed();
			state:switch("check");
			StopCockpitTimer();
			HideCockpitTimer();
		--elseif state:SecondsHavePassed(30) then
		elseif GetCockpitTimer() == 0 then
			mission_data.IsDetected = true;
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
		if mission_data.Player and mission_data.Player:GetPerceivedTeam() == 1 then
			mission_data.IsDetected = true;
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
		if not mission_data.Hangar:IsAlive() then
			FailMission(GetTime()+5.0, "rbdnew03l3.des"); -- hangar destroyed
			mission_data.MissionOver = true;
			objective.UpdateObjective(objectives.Hanger, "RED");
			--UpdateObjectives();
		end
	end)
	:Add("mammoth_shield", stateset.WrapStateMachine("mammoth_shield"))
	:Add("mammoth_destroyed", function (state, name)
		if not mission_data.Mammoth:IsAlive() then 
			mission_data.Aud1 = AudioMessage(audio.lose1);
			FailMission(GetTime()+5.0, "rbdnew03l1.des"); -- mammoth destroyed
			mission_data.MissionOver = true;
			--UpdateObjectives();
		end
	end);

hook.Add("Start", "Mission:Start", function ()
    mission_data.mission_states = stateset.Start("mission")
		:on("scrap_field_filler_1")
		:on("main_objectives");
end);

hook.Add("Update", "Mission:Update", function (dtime, ttime)
	mission_data.Player = gameobject.GetPlayerGameObject();
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
