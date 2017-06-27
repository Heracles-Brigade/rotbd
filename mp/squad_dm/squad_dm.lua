local OOP = require("oop");
local bzUtils = require("bz_core");
local net = require("bz_net");
local bzRoutine = require("bz_routine");
local misc = require("misc");

local KeyListener = misc.KeyListener;
local MpSyncable = misc.MpSyncable;
local PlayerListener = misc.PlayerListener;
local ObjectListener = misc.ObjectListener;
local CommandListener = misc.CommandListener;
local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local KeyListener = misc.KeyListener;
local BzDestroy = misc.BzDestroy;
local Class = OOP.Class;
local playerNavs = {};
local Routine = bzRoutine.Routine;

local killOnNext = {};
  
GetMissionFilename = GetMissionFilename or GetMapTRNFilename;


GetPathPointCount = GetPathPointCount or function(path)
  local c = 1;
  local ppoint = GetPosition(path,0);
  while true do
    local npoint = GetPosition(path,c);
    if(npoint == ppoint) then
      return c;
    end
    c = c + 1;
  end
end

GetPathCount = function(path)
  local c = 0;
  while true do
    local point = GetPosition((path):format(c+1));
    if(point.x ~= 0) or (point.z ~= 0) or (point.y ~= 0) then
      c = c + 1;
    else
      return c;
    end
  end
end



local missionBase = GetMissionFilename():match("[^%p]+");
print("missionBase",missionBase);
local squadIni = misc.odfFile(("%s.sqd"):format(missionBase));

print("Parent:",squadIni:getProperty("Meta","parent"));
print("Default:",squadIni:getProperty("SquadMatches","default"));

--print("Misn base:",missionBase);
--print("Valid?",squadIni:isValid());
--if(not squadIni:isValid()) then
  --squadIni = misc.odfFile("default.squads");
--end
if(EnableAllCloaking) then
  EnableAllCloaking(false);
end
local localSquadHandles = {};


local spawn_prefix = ("spawn_%d");

local function keepInside(handle,path)
  local p = GetPosition(path,0);
  local r = Length(p-GetPosition(path,1));
  local pp = GetPosition(handle);
  local dv = Normalize(pp-p);
  local d = Length(pp-p);
  local vel = GetVelocity(handle);
  local dprod = DotProduct(Normalize(vel),dv);
  local nvel = vel - dprod*dv;
  if(d > r) then
    local newp = (p + dv*r);
    local h = GetTerrainHeightAndNormal(newp);
    newp.y = math.max(h,newp.y);
    SetPosition(handle,newp);
    SetVelocity(handle,nvel);
  end
end

local lastSquad = "";

local function spawnSquad(handle,squad_name)
  local squad = {};
  local p = GetPosition(handle);
  print("Odf:",handle,GetOdf(handle));
  if(IsValid(handle)) then
    squad_name = squad_name or squadIni:getProperty("SquadMatches",GetOdf(handle) or "") or squadIni:getProperty("SquadMatches","default");
  else
    squad_name = squad_name or lastSquad;
  end
  if(squad_name == nil or squad_name == "") then
    error("No squad name!",handle);
  end
  local units = squadIni:getTable(squad_name,"unit");
  lastSquad = squad_name;
  for i,v in pairs(units) do
    local pn = GetPositionNear(p,20,100);
    local t = BuildDirectionalMatrix(pn,GetFront(handle));
    local h = BuildObject(v,GetTeamNum(handle),t);
    SetLocal(h);
    table.insert(squad,h);
  end
  return squad;
end

local ROUND_TIME = 60*5;
local LOBBY_TIME = 10;
local SURVIVE_TIME = 15;


--[[
local roundBasedGame2 = Decorate(
  Implements(PlayerListener, ObjectListener),
  Routine({
    name = "gameManager",
    delay = 0.1
  }),
  Class("squaddm.gameManager",{
    constructor = function()
      self.playerHandle = GetPlayerHandle();
      self.sockets = {};
      self.roundStarted = false;
      self.subscriptions = {};
      
      
      net.netManager:getSockets("GAME.MG"):subscribe(function(...)
        self:_onSocketCreate(...);
      end);
      net.netManager:onNetworkReady():subscribe(function(...)
        self:_onNetworkReady(...);
      end);
    end,
    methods = {
      _onSocketCreate = function(socket,...)
        print("Socket created!",...);
        --When host connects
        if(self.subscriptions["host"]) then
          self.subscriptions["host"]:unsubscribe();
        end
        self.sockets.host = socket;
        self.subscriptions["host"] = self.sockets.host:getPackets():subscribe(function(...)
          self:_onSocketPacket(...);
        end);
      end,
      _onNetworkReady = function()
        --Called when network is ready
        --We need to wait for this before doing any networking
        

      end,
      _onSocketPacket = function(from,what,...)
        if(what == "SPAWN") then

        elseif(what == "ROUND_OVER") then

        elseif(what == "SYNC") then
          
        elseif(what == "DEAD") then

        end
      end
    }
  })

);
--]]

--Routine for handling the game logic
local roundBasedGame = Decorate(
  --We need to listne to players
  Implements(PlayerListener,ObjectListener,CommandListener),
  Routine({
    name = "roundBasedGame",
    delay = 0.1
  }),
  Class("roundBasedGameController",{
    constructor = function()
      --Variables for local player
      self.inRound = false;
      self.roundStarted = false;
      self.timeUntilStart = LOBBY_TIME;
      self.roundTimeLeft = 0;
      self.sockets = {};
      self.localPlayer = nil;
      self.hostPlayer = nil;
      self.hostSocket = nil;
      self.playersLeft = {};
      self.psquad = "";
      self.squad = {};
      self.playerHandle = nil;
      self.sp_r = nil;
      self.host = IsHosting();
      net.netManager:getSockets("GAME.MG"):subscribe(function(...)
        self:_onSocketCreate(...);
      end);
      net.netManager:onNetworkReady():subscribe(function(...)
        self:_onNetworkReady(...);
      end);
    end,
    methods = {
      startRound = function()
        if(self.sp_r) then
          bzRoutine.routineManager:killRoutine(self.sp_r);
          self.sp_r = nil;
        end


        self.roundTimeLeft = ROUND_TIME;
        self.roundStarted = true;
        self.inRound = true;
        --Tell everyone to spawn in
        local c = 2;
        for i,v in pairs(net.netManager:playersInGame()) do
          self.playersLeft[i] = true;
        end
        local random_list = {};
        for i=1, GetPathCount(spawn_prefix) do
          table.insert(random_list,i);
        end
        for i,v in pairs(self.sockets) do
          local p = v:packet();
          p:queue("SPAWN",ROUND_TIME,table.remove(random_list,1 + math.floor(math.random()*#random_list)),self.playersLeft);
          v:flush(p);
          c = c + 1;
        end
        StopCockpitTimer();
        StartCockpitTimer(0);
        self:_spawnIn(table.remove(random_list,1 + math.floor(math.random()*#random_list)));
      end,
      _onSocketCreate = function(socket,...)
        print("Socket created!",...);
        --When host connects
        if(self.sockSub1) then
          self.sockSub1:unsubscribe();
        end
        self.hostSocket = socket;
        self.sockSub1 = self.hostSocket:getPackets():subscribe(function(...)
          self:_onSocketPacket(...);
        end);
      end,
      _onSocketPacket = function(from,what,...)
        print(from,what,...);
        if(what == "SPAWN") then
          --"SPAWN" can be sent twice if host leaves
          --just as the game is about to start
          if(self.sp_r) then
            bzRoutine.routineManager:killRoutine(self.sp_r);
            self.sp_r = nil;
          end
          if(not self.roundStarted) then
            --Spawn
            local timeleft,location,plef = ...;
            self.roundTimeLeft,self.playersLeft = timeleft,plef;
            StopCockpitTimer();
            StartCockpitTimer(0);
            self.roundStarted = true;
            self.inRound = true;
            self:_spawnIn(location);
          end
        elseif(what == "ROUND_OVER") then
          StopCockpitTimer();
          StartCockpitTimer(0);
          if(self.sp_r) then
            bzRoutine.routineManager:killRoutine(self.sp_r);
            self.sp_r = nil;
          end
          self.roundStarted = false;
          self.inRound = false;
          local winner;
          self.timeUntilStart, winner = ...;
          local wplayer = net.netManager.players.all[winner];
          if(wplayer) then
            DisplayMessage(("Winner was %s"):format(wplayer.name));
          else
            DisplayMessage("Nobody won this round");
          end
          DisplayMessage(("Next round starts in %d seconds."):format(self.timeUntilStart));
          self:_removeSquad();
        elseif(what == "SYNC") then
          self.roundStarted, self.timeUntilStart, self.roundTimeLeft,self.playersLeft = ...;
        elseif(what == "DEAD") then
          local d_id = ...;
          d_id = d_id or from;
          self:_updatePlayersLeft(d_id);
        end
      end,
      _connectToAllPlayers = function()
        for i,v in pairs(net.netManager:getRemotePlayers()) do
          print(("  %d: %s"):format(i,v.name));
          self:_connectPlayer(v.id);
        end
        self.host = true;
      end,
      _setHost = function(...)
        --Whenever host changes, check if I am new host
        self.hostPlayer = ...;
        if(IsHosting()) then
          self:_connectToAllPlayers();
        end
      end,
      _spawnIn = function(location)
        local l = spawn_prefix:format(location);
        local dir = GetPosition(l,1) - GetPosition(l,0);
        local t = BuildDirectionalMatrix(GetPosition(l),dir);
        local h = net.netManager:getPlayerHandle() or self.playerHandle;
        local of = misc.odfFile(GetOdf(self.playerHandle));
        local maxHp = of:getInt("GameObjectClass","maxHealth");
        local maxAmmo = of:getInt("GameObjectClass","maxAmmo");
        SetMaxHealth(self.playerHandle,maxHp);
        SetMaxAmmo(self.playerHandle,maxAmmo);
        SetCurAmmo(h,maxAmmo);
        SetCurHealth(h,maxHp);
        SetTransform(h,t);
        self.squad = spawnSquad(h);
        for i,v in pairs(self.squad) do
          Follow(v,h,0);
        end
      end,
      _removeSquad = function()
        --Remove Cameras
        for i=TeamSlot.MIN_BEACON, TeamSlot.MAX_BEACON do
          local cam = GetTeamSlot(i);
          if(IsValid(cam)) then
            RemoveObject(cam);
          end
        end
        for i,v in pairs(self.squad) do
          RemoveObject(v);
        end
        self.squad = {};
      end,
      _updatePlayersLeft = function(pdead)
        self.playersLeft[pdead] = nil;
        if(IsHosting()) then
          for i,v in pairs(self.sockets) do
            local p = v:packet();
            p:queue("DEAD",pdead);
            v:flush(p);
          end
        end
        local l = 0;
        for i,v in pairs(self.playersLeft) do
          l = l + 1;
        end
        if(l <= 1) then
          self.roundTimeLeft = SURVIVE_TIME;
          DisplayMessage(("Last player alive, has to survive for %d seconds"):format(self.roundTimeLeft));
        end
      end,
      endRound = function(winner)
        self.inRound = false;
        self.roundStarted = false;
        self.timeUntilStart = LOBBY_TIME;
        if(self.sp_r) then
          bzRoutine.routineManager:killRoutine(self.sp_r);
          self.sp_r = nil;
        end
        local wplayer = net.netManager.players.all[winner];
        if(wplayer) then
          DisplayMessage(("Winner was %s"):format(wplayer.name));
        else
          DisplayMessage("Nobody won this round");
        end
        for i,v in pairs(self.sockets) do
          local p = v:packet();
          p:queue("ROUND_OVER",self.timeUntilStart,winner);
          v:flush(p);
        end
        self:_removeSquad();
      end,
      onInit = function()
        net.netManager:getHosts():subscribe(function(...)
          self:_setHost(...);
        end);
      end,
      _onNetworkReady = function(player)
        self.localPlayer = player;
        print("Local player",player.id,player.name);
        if(IsHosting()) then
          self:_connectToAllPlayers();
        end
      end,
      update = function(dtime)
        self.playerHandle = net.netManager:getPlayerHandle() or self.playerHandle;
        --Make sure the player can't eject or hop out
        SetPilotClass(self.playerHandle,"");
        --We have to wait for the localPlayer to be set before we do anything
        if(not self.localPlayer) then
          return;
        end
        if(self.inRound and ((not IsValid(self.playerHandle)) or GetCurHealth(self.playerHandle) <= 0)) then
          
          local id;
          local targets = {};
          local anyPlayers = false;
          for i,v in pairs(self.playersLeft) do
            local p = net.netManager:playersInGame()[i];
            local target = net.netManager:getPlayerHandle(p.team);
            print("Player left",i,p.team,target);
            if(IsValid(target)) then
              targets[i] = target;
              anyTargets = true;
            end
          end
          if(not anyTargets) then
            for i,v in pairs(self.squad) do
              if(IsValid(v)) then
                table.insert(targets,v);
                break;
              end
            end
          end
          if(anyTargets) then
            self.sp_r = bzRoutine.routineManager:startRoutine("spectateRoutine",targets);
          end
          if(IsHosting()) then
            self:_updatePlayersLeft(self.localPlayer.id);
          else
            local p = self.hostSocket:packet();
            p:queue("DEAD");
            self.hostSocket:flush(p);
          end
          local p = GetPositionNear(GetPosition("lobby"),0,Length(GetPosition("lobby") - GetPosition("lobby",1)));
          SetPosition(self.playerHandle,p);
          for i,v in pairs(self.squad) do
            local c = AiCommand[GetCurrentCommand(v)];
            if(OOP.isIn(c,{"FOLLOW","FORMATION","DEFEND","RESCUE","GOTO","NONE"})) then
              SetCommand(v, AiCommand.HUNT);
            else
              SetCommand(v,AiCommand[c],1,GetCurrentWho(v));
            end
          end
          self.inRound = false;
        end
        for i,v in pairs(self.squad) do
          keepInside(v,"battleground");
        end
        if(self.inRound) then
          keepInside(self.playerHandle,"battleground");
        else
          SetMaxAmmo(self.playerHandle,0);
          SetMaxHealth(self.playerHandle,0);
          keepInside(self.playerHandle,"lobby");
        end

        if(self.roundStarted) then
          self.roundTimeLeft = self.roundTimeLeft - dtime;
        else
          self.timeUntilStart = self.timeUntilStart - dtime;
        end
        if(self.host) then
          if(not self.roundStarted) then
            if(net.netManager:getPlayerCount() > 1) then
              if(self.timeUntilStart <= 0) then
                self:startRound();
              end
            elseif(self.timeUntilStart <= 0) then
              DisplayMessage("Waiting for more players to join");
              self.timeUntilStart = LOBBY_TIME;
            end
          else
            local l = 0;
            local winner = 0;
            for i,v in pairs(self.playersLeft) do
              l = l + 1;
              winner = i;
            end
            if(l ~= 1) then
              winner = 0;
            end
            if(self.roundTimeLeft <= 0) then
              self:endRound(winner);
            end
          end
        end
      end,
      isAlive = function()
        return true;
      end,
      _connectPlayer = function(id)
        if(not self.sockets[id] ) then
          print("connecting to player",id);
          local s = net.netManager:createSocket("GAME.MG",id);
          local p = s:packet();
          p:queue("SYNC",self.roundStarted,self.timeUntilStart,self.roundTimeLeft,self.playersLeft);
          s:flush(p);
          self.sockets[id] = s;
          s:getPackets():subscribe(function(...)
            self:_onSocketPacket(...);
          end);
        end
      end,
      onAddPlayer = function(id,...)
        --Put player in lobby list
        if(self.localPlayer) then
          if(IsHosting()) then
            self.timeUntilStart = LOBBY_TIME;
            if(net.netManager:getPlayerCount() <= 1) then
            end
            self:_connectPlayer(id);
          end
        end
      end,
      onCreatePlayer = function()

      end,
      onDeletePlayer = function(id,...)
        print("Del player",id);
        self:_updatePlayersLeft(id);
        --self.playersLeft[id] = nil;
        print("Players left:");
        for i,v in pairs(self.playersLeft) do
          print(i,net.netManager.players.all[i].name);
        end
      end,
      onAddObject = function(h)
      end,
      onDeleteObject = function(h)
        if(self.playerHandle == h) then
          self.inRound = false;
        end
      end,
      onDestroy = function()
      end,
      onCreateObject = function()
      end,
      save = function()
      end,
      load = function()
      end,
      onCommand = function(cmd,...)
        cmd = cmd:lower();
        if(cmd == "spectate") then
          if((not self.inRound) and self.roundStarted) then
            local player = tonumber(... or "1");
            local key;
            local targets = {};
            if(self.sp_r) then
              bzRoutine.routineManager:killRoutine(self.sp_r);
            end
            for i,v in pairs(self.playersLeft) do
              local p = net.netManager:playersInGame()[i];
              local target = net.netManager:getPlayerHandle(p.team);
              if(player == p.team) then
                key = player;
              end
              if(IsValid(target)) then
                targets[i] = target;
              end
            end
            self.sp_r = bzRoutine.routineManager:startRoutine("spectateRoutine",targets,key);
          end
        end
      end
    }
  })
);

local spectateRoutine = Decorate(
  --We need to listne to players
  Implements(KeyListener),
  Routine({
    name = "spectateRoutine",
    delay = 0.0
  }),
  Class("spectateRoutine",{
    constructor = function()
      self.sp_targets = nil;
      self.alive = true;
      self.cam = false;
    end,
    methods = {
      onInit = function(...)
        local ts, key = ...;
        self.sp_targets = ts;
        self.key_list = {};
        self.key_i = 1;
        for i, v in pairs(self.sp_targets) do
          table.insert(self.key_list,i);
          if(i == key) then
            self.key_i = #self.key_list;
          end
        end
        if(#self.key_list > 0) then
          print("Spectating started");
        else
          self:stop();
        end
      end,
      watchNext = function()
        if(#self.key_list <= 0) then
          return false;
        end
        self.key_i = (self.key_i%#self.key_list) + 1;
        return true;
      end,
      update = function(dtime)
        if(self.cam) then
          if(CameraCancelled()) then
            self:stop();
            return;
          end
          local h = self.sp_targets[self.key_list[self.key_i]];
          if(IsValid(h)) then
            --TODO: add smoothing
            CameraObject(h,0,1000,-3000,h);
          else
            self.sp_targets[self.key_list[self.key_i]] = nil;
            table.remove(self.key_list,key_i);
            if not self:watchNext() then
              self:stop();
            end
          end
        elseif(IsValid(GetPlayerHandle())) then
          self.cam = CameraReady();
        end
      end,
      isAlive = function()
        return self.alive;
      end,
      save = function()
      end,
      load = function()
      end,
      stop = function()
        print("STOP!");
        self.alive = false;
      end,
      onDestroy = function()
        print("Spectating stoped");
        CameraFinish();
      end,
      onGameKey = function(key)
        if(key == "Tab") then
          self:watchNext();
        end
      end
    }
  })
);


bzRoutine.routineManager:registerClass(roundBasedGame);
bzRoutine.routineManager:registerClass(spectateRoutine);

local routine = bzRoutine.routineManager:startRoutine("roundBasedGame");


function Start(...)
  --Spawn squad
  bzUtils:onStart(...);
end

function GameKey(...)
  bzUtils:onGameKey(...);
end

function Update(...)
  local ph = GetPlayerHandle();
  for i,v in pairs(killOnNext) do
    if((i ~= ph) and IsLocal(i)) then
      RemoveObject(i);
    end
  end
  killOnNext = {};
  bzUtils:update(...);
end

function AddObject(...)
  bzUtils:onAddObject(...);
end

function DeleteObject(...)

  bzUtils:onDeleteObject(...);
end

function CreateObject(...)
  local h = ...;
  if((GetClassLabel(h) == "person") and (not IsRemote(h))) then
    killOnNext[h] = true;
  end
  bzUtils:onCreateObject(...);
end

function AddPlayer(...)
  bzUtils:onAddPlayer(...);
end

function CreatePlayer(...)
  bzUtils:onCreatePlayer(...);
end

function DeletePlayer(...)
  bzUtils:onDeletePlayer(...);
end

function Receive(...)
  bzUtils:onReceive(...);
end

function Command(command,args)
  local a = {};
  for i in string.gmatch(args or "", "%S+") do
    table.insert(a,i);
  end
  bzUtils:onCommand(command,unpack(a));
  return true;
end


return {
  gameRoutine = routine;
}
