--Combination of The Last Stand and Evacuate Venus
--Contributors:
    --Jarle Trollebø(Mario)


require("bz_logging");



local mission = require('cmisnlib');

SetAIControl(2,false);

function Start()
    SetPilot(1,5);
    SetScrap(1,8);
	SetMaxHealth(GetHandle("abbarr2_barracks"),0);
	SetMaxHealth(GetHandle("abbarr3_barracks"),0);
	SetMaxHealth(GetHandle("abcafe3_i76building"),0)
end

function Update(dtime)
    mission:Update(dtime);
end

function CreateObject(handle)
    mission:CreateObject(handle);
end

function AddObject(handle)
    mission:AddObject(handle);
end

function DeleteObject(handle)
    mission:DeleteObject(handle);
end

function Save()
    return mission:Save();
end

function Load(missison_date)
    mission:Load(missison_date);
end