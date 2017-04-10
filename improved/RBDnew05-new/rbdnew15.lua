--Combination of The Last Stand and Evacuate Venus
--Contributors:
    --Jarle Trollebø(Mario)


require("bz_logging");
local core = require("bz_core");

local miscAi = require("constAI");

local ConstructorAi = miscAi.ConstructorAi;
local ProducerAi = miscAi.ProducerAi;


local mission = require('cmisnlib');

SetAIControl(2,false);

function Start()
    core:onStart();
    SetPilot(1,5);
    SetScrap(1,8);
    Ally(1,3);
	SetMaxHealth(GetHandle("abbarr2_barracks"),0);
	SetMaxHealth(GetHandle("abbarr3_barracks"),0);
	SetMaxHealth(GetHandle("abcafe3_i76building"),0);
    SetMaxScrap(3,5000);
    SetScrap(3,2000);
    SetMaxPilot(3,5000);
    SetPilot(3,1000);
    ConstructorAi:addFromPath("make_bblpow",3,"bblpow"):subscribe(function(handle)
        print("Object made: ", handle);
    end);
    ProducerAi:createJob("bvtank",3):subscribe(function(handle)
        print("Unit made: ",handle);
    end);
    ProducerAi:createJob("bvtank",3):subscribe(function(handle)
        print("Unit made: ",handle);
    end);
    ProducerAi:createJob("bvcnst",3):subscribe(function(handle)
        print("Unit made: ",handle);
    end);
end

function Update(dtime)
    core:update(dtime);
    mission:Update(dtime);
end

function CreateObject(handle)
    core:onCreateObject(handle);
    mission:CreateObject(handle);
end

function AddObject(handle)
    core:onAddObject(handle);
    mission:AddObject(handle);
end

function DeleteObject(handle)
    core:onDeleteObject(handle);
    mission:DeleteObject(handle);
end

function Save()
    return mission:Save(),{core:save()};
end

function Load(missison_date,cdata)
    mission:Load(missison_date);
    core:load(unpack(cdata));
end