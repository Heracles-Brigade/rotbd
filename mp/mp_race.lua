local OOP = require("oop");
local bzUtils = require("bz_core");
local net = require("bz_net");
local bzRoutine = require("bz_routine");
local misc = require("misc");

local KeyListener = misc.KeyListener;
local MpSyncable = misc.MpSyncable;

local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local KeyListener = misc.KeyListener;
local BzDestroy = misc.BzDestroy;
local Class = OOP.Class;

local Routine = bzRoutine.Routine;

local gameManagerRoutine = Decorate(
  Implements(PlayerListener),
  Routine({
    name = "gameManger",
    delay = 0.5
  }),
  Class("gameManagerController",{
    constructor = function()

    end,
    methods = {
      onInit = function()

      end,
      update = function()

      end,
      isAlive = function()
        return true;
      end,
      onAddPlayer = function()

      end,
      onCreatePlayer = function()

      end,
      onDeletePlayer = function()

      end
    }
  })

);



function Start()

end

function Update()

end

function AddObject()

end

function DeleteObject()

end

function CreateObject()

end

function AddPlayer()

end

function CreatePlayer()

end

function DeletePlayer()

end