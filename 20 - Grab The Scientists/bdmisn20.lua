-- Battlezone: Rise of the Black Dogs, Black Dog Mission 20 written by General BlackDragon.

local M = {
-- Bools
UpdateObjectives = false,

-- Floats

Nav3Time = 0,
-- Handles
Player = nil,
Nav = { },
Power1 = { },
Power2 = { },

-- Ints
MissionState = 0,

endme = 0
}

--function InitialSetup()
--	M.Difficulty = IFace_GetInteger("options.play.difficulty");
--end

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

    print("Black Dog Mission 20 Lua created by General BlackDragon");
	
	M.Difficulty = 0; --IFace_GetInteger("options.play.difficulty");
	M.StopScript = 0; --GetVarItemInt("network.session.ivar119");
	
	if M.StopScript == 0 then
	
		
		M.MissionState = 0; -- Start the mission.
		
	end

end

--function CreateObject(h)

--	if M.StopScript == 0 then
	
--	end
--end

function AddObject(h)

	local Team = GetTeamNum(h);

	if M.StopScript == 0 then

	end

end

function DeleteObject(h)

	
end

function Update()

	M.ElapsedGameTime = M.ElapsedGameTime + 1;
	
	if M.StopScript == 0 then
		
		M.Player = GetPlayerHandle();
	
	end
	
end

-- BuildAngleObject from BZClassic mod. Looks for an object with a specified label, if not present, it spawns it, at the specified angle in degrees (0 = North), at the specified Height, and optionally Empty. Written by General BlackDragon. -- Needs a SetLabel function to fully work as intended. :(
function BuildAngleObject(Odf, Team, Path, Label, Angle, HeightOffset, Empty)

	local h = 0;
	
	if Label ~= nil then
		h = GetHandle(Label); -- Check to see if it already exists first.
	end
	
	if not IsValid(h) then -- Nope, build it.
	
		local BuildPos = GetPosition(Path);
		local BuildLoc = IdentityMatrix;
		
		if BuildPos ~= nil then 

			if Angle == nil then 
				Angle = 0;
			end
			if HeightOffset == nil then
				HeightOffset = 0;
			end
			
			if not (HeightOffset == 0) then 
				BuildPos.y = BuildPos.y + HeightOffset;
			end
			
			if (Angle > 0) then 
				BuildLoc = BuildPositionRotationMatrix(0, math.rad(Angle), 0, BuildPos.x, BuildPos.y, BuildPos.z);
				h = BuildObject(Odf, Team, BuildLoc);
				--print("Angle is: ", Angle, " Path name is: ", Path, " Vector Is: ", BuildLoc.posit.x, ", ", BuildLoc.posit.y, ", ", BuildLoc.posit.z);
			else
				h = BuildObject(Odf, Team, BuildPos);
			end
			
			if(Empty) then 
				RemovePilot(h);
			end
			
			SetLabel(h, Label);
			
		else
			print("ERROR: Path: ", Path, " doesn't exist!");
		end
		
	end

	return h;
end
