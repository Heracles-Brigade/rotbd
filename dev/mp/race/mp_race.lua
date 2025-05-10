local OOP = require("oop");
local bzUtils = require("bz_core");
local net = require("bz_net");
local bzRoutine = require("bz_routine");
local misc = require("misc");
--routine for spectating
local _ = require("spectate_r");

local KeyListener = misc.KeyListener;
local MpSyncable = misc.MpSyncable;

local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local KeyListener = misc.KeyListener;
local BzDestroy = misc.BzDestroy;
local Class = OOP.Class;
local killOnNext = {};
local PlayerListener = misc.PlayerListener;
local CommandListener = misc.CommandListener;
local ObjectListener = misc.ObjectListener;
local Routine = bzRoutine.Routine;

--Weapon lua's
local RaceWasp = require("grcwasp");




RaceWasp();

local function posModifier(pos,center)
  return math.min(1 / (pos - center - 1 / 64) - 1 / (pos - center + 1 / 64),1);
end

local slotsTemplate = {"A","B","C","D","E","F","G","H","I","J","K","M","L"}

local MAX_AMMO = 300;
local MAX_HEALTH = 3000;
local IM = 0;
local ODFS = {};

GetMissionFilename = GetMissionFilename or GetMapTRNFilename;

local missionBase = GetMissionFilename():match("[^%p]+");
print("missionBase",missionBase);
local raceSettings = misc.odfFile(("%s.race"):format(missionBase));



local function closestPathPoints(paths,pos)
  local path, lop, closestPoints, pindex;
  local minDist = math.huge;
  for i2, v2 in pairs(paths) do
    local pp = GetPathPoints(i2);
    for i3, v3 in ipairs(pp) do
      if(i3 >= #pp) then break; end
      local v4 = pp[i3+1];
      local pair = {v3,v4}
      local d = ((Length(pos- v3) + Length(pos - v4))/(2*v2));
      if(d < minDist) then
        closestPoints = pair;
        lop = v2;
        minDist = d;
        path = i2;
        pindex = i3;
      end
    end
  end
  return path, pindex, lop, closestPoints;
end

local function positionToDistance(pos,check)
  local path, pindex, lop, closestPoints = closestPathPoints(check.paths,pos);
  local np = pos;
  local distance = 0;
  if(closestPoints) then
    local vec1 = pos-closestPoints[1];
    local vec2 = closestPoints[2]-closestPoints[1];
    local pval = DotProduct(vec1,vec2/Length(vec2));
    local plen = (pval + GetPathLength(path,false,pindex))/lop;
    distance = distance + plen;
    np = pval * vec2/Length(vec2) + closestPoints[1];
  end
  return distance, np, closestPoints;
end

local function keepInside(handle,path)
  local p = GetPosition(path,0);
  local r = Length(p-GetPosition(path,1));
  local pp = GetPosition(handle);
  local dv = Normalize(pp-p);
  local d = Length(pp-p);
  local vel = GetVelocity(handle);
  local dprod = DotProduct(vel,-dv);
  local nvel = vel + dprod*dv*(1+GetTimeStep());
  if(d > r) then
    local newp = (p + dv*r);
    local h = GetTerrainHeightAndNormal(newp);
    newp.y = math.max(h,newp.y);
    SetPosition(handle,newp);
    SetVelocity(handle,nvel);
  end
end

local function stayInLobby(handle,...)
  keepInside(handle,...);
  SetMaxAmmo(handle,IM);
  SetMaxHealth(handle,IM);
end

local pickupManagerRoutine = Decorate(
  Implements(ObjectListener),
  Routine({
    name = "pickupManager",
    delay = 1
  }),
  Class("pickupManager",{
    constructor = function()
      self.pickups = {};
      self.timers = {};
      self.cwep = 1;
      self.cycleTimer = misc.Timer(0.25,true);
      self.sub = self.cycleTimer:onAlarm():subscribe(function(...)
        --disabled, currently lags the game with a lot of powerups on the map
        --self:_cycleAnim();
      end);
    end,
    methods = {
      _spawnPowerups = function(path)
        local p = self.paths[path];
        local pps = GetPathPoints(path);
        local vec = pps[2] - pps[1];
        local len = Length(vec);
        local inc = len/p.count;
        local dir = Normalize(vec);
        for i=0, p.count do
          local powerup = p.powerups[i];
          if (not powerup) or (not IsValid(powerup.h)) then
            local pos = dir*inc*i + pps[1];
            pos.y = GetTerrainHeightAndNormal(pos) + 1.0;
            local h = BuildObject(("wpnran%d"):format(self.cwep),0,pos);
            p.powerups[i] = {
              h = h,
              p = pos
            };
            self.pickups[h] = path;
          end
        end
      end,
      _cycleAnim = function()
        self.cwep = self.cwep%4 + 1;
        self.doNotTrigger = true;
        for i, v in pairs(self.paths) do
          for i2, v2 in pairs(v.powerups) do
            if(IsValid(v2.h)) then
              local p = GetTransform(v2);
              local h = BuildObject(("wpnran%d"):format(self.cwep),0,p);
              
              v.powerups[i2] = {
                h = h,
                p = v2.p
              };
              self.pickups[h] = v.name;
              RemoveObject(v2.h);
            end
          end
        end
        self.doNotTrigger = false;
      end,
      onInit = function(paths,interval,count)
        interval = interval or 10;
        count = count or 5;
        self.paths = {};
        for i, v in pairs(paths) do
          local o = {
            name = v,
            powerups = {},
            timer = misc.Timer(interval,false),
            count = count
          }
          o.sub = o.timer:onAlarm():subscribe(function()
            self:_spawnPowerups(v);
          end);
          self.paths[v] = o;
          self:_spawnPowerups(v);
        end
        self.cycleTimer:start();
      end,
      update = function(dtime)
        self.cycleTimer:update(dtime);
        for i, v in pairs(self.paths) do
          v.timer:update(dtime);
          for i2, v2 in pairs(v.powerups) do
            if(IsValid(v2.h)) then
              SetPosition(v2.h,v2.p);
            else
              v.powerups[i2] = nil;
            end
          end
        end
      end,
      onDeleteObject = function(handle)
        if(not self.doNotTrigger) then
          local path = self.pickups[handle];
          if(path) then
            local p = self.paths[path];
            if(p) then
              p.timer:restart();
            end
          end
        end
        self.pickups[handle] = nil;
      end,
      isAlive = function()
        return true;
      end,
      onDestroy = function()
        --remove all powerups
        self.doNotTrigger = true;
        self.sub:unsubscribe();
        self.cycleTimer:stop();
        self.cycleTimer = nil;
        for i, v in pairs(self.paths) do
          v.sub:unsubscribe();
          v.timer:stop();
          v.timer = nil;
          for i2, v2 in pairs(v.powerups) do
            RemoveObject(v2.h);
          end
        end
      end,
      save = function()
      end,
      load = function()
      end,
      onAddObject = function()
      end,
      onCreateObject = function()
      end
    }
  })
);


--Give weapon to player
local giveWeaponRoutine = Decorate(
  Routine({
    name = "giveWeaponRoutine",
    delay = 0.5
  }),
  Class("giveWeaponRoutine",{
    constructor = function()
      self.handles = {};
    end,
    methods = {
      onInit = function(handles,tiers)
        for i, v in pairs(handles) do
          self:addHandle(v);
        end
        self.tiers = tiers;
      end,
      addHandle = function(handle)
        self.handles[handle] = 0;
      end,
      updateHandle = function(handle,pos)
        self.handles[handle] = pos;
      end,
      update = function(dtime)
        for handle, pos in pairs(self.handles) do
          if(IsValid(handle)) then
            local weapon = GetWeaponClass(handle,0);
            if(weapon == "grand") then
              local hchance = 0;
              local index = 1;
              for i, v in ipairs(self.tiers) do
                local ch = (posModifier(pos,v.center) * v.chance)*math.random();
                if(ch > hchance) then
                  hchance = ch;
                  index = i;
                end
              end
              local wep = math.random(#self.tiers[index].weapons);
              if(self.tiers[index].weapons[wep]) then
                GiveWeapon(handle,self.tiers[index].weapons[wep],0);
                if(GetMaxAmmo(handle) > 0) then
                  SetCurAmmo(handle,GetMaxAmmo(handle));
                end
              end
            end
          else
            self.handles[handle] = nil;
          end
        end
      end,
      onDestroy = function()
      end,
      save = function()
      end,
      load = function()
      end,
      isAlive = function()
        return true;
      end
    }
  })
);


local gameManagerRoutine = Decorate(
  Implements(PlayerListener,CommandListener),
  Routine({
    name = "gameManger",
    delay = 0.01
  }),
  Class("gameManagerController",{
    constructor = function()
      self.localState = {
        inRace = false,
        slot = nil
      }

      self.lobbyState = {
        lobbyTimer = 30
      }
      
      self.userSettings = {
        afk = false
      }

      self.hostSettings = {
        laps = raceSettings:getInt("Settings","laps",3),
        autostart = raceSettings:getBool("Settings","autostart",false),
        timelimit = raceSettings:getInt("Settings","timelimit",60*10),
        minplayers = raceSettings:getInt("Settings","minplayers",2),
        ex_physics = raceSettings:getBool("Settings","ex_physics",true)
      }

      self.startInit = false;
      self.sockets = {};
      self.lastPlayerPositions = {SetVector(0,0,0)};
      self.navPoints = {};
      self.afkPlayers = {};


      self.raceState = {
        raceStarted = 0, -- 0 not started, 1 - get ready - 2 go
        countdown = self.hostSettings.countdown,
        players = {},
        totalLaps = self.hostSettings.laps,
        avaliableSlots = {},
        timelimit = self.hostSettings.timelimit
      }
    end,
    methods = {
      onInit = function(checkpoints,deathtraps,wpn_pickups,lobby_pickups)
        self.checkpoints = checkpoints;
        self.deathtraps = deathtraps;
        self.lobby_pickups = lobby_pickups;
        self.wpn_pickups = wpn_pickups;
        self.weapon_tiers = {};
        for i=1, raceSettings:getInt("Tiers","tier_count") do
          local head = ("Tier%d"):format(i);
          table.insert(self.weapon_tiers,{
            chance = raceSettings:getFloat(head,"chance"),
            center = raceSettings:getFloat(head,"center"),
            weapons = raceSettings:getTable(head,"weapon")
          });
        end
        
        self.wep_r = bzRoutine.routineManager:startRoutine("giveWeaponRoutine",{},self.weapon_tiers);
        net.netManager:getSockets("GAME.MG"):subscribe(function(...)
          self:_onSocketCreate(...);
        end);
        
        net.netManager:onNetworkReady():subscribe(function(...)
          self:_onNetworkReady(...);
        end);

        net.netManager:getHosts():subscribe(function(...)
          self:_setHost(...);
        end);

        self.calcTimer = misc.Timer(0.2,true);
        self.calcTimer:onAlarm():subscribe(function(...)
          if(self.raceState.raceStarted == 2) then
            self:_calcPlayerPositions();
          end
        end);
        self.calcTimer:start();

        --check powerups

      end,
      _calcPlayerPositions = function()
        local sortedPositions = {};
        for i, v in pairs(self.raceState.players) do
          if not(i == self.localPlayer.id and self.localState.respawning) then
            local pH = net.netManager:getPlayerHandle(v.team);
            v.distance = v.checkpoint*10 + (v.lap-1) * (((#self.checkpoints+1)*20))
            if(IsValid(pH)) then
              local playerP = GetPosition(pH);
              local tempD,lastPP, closestPoints = positionToDistance(playerP,self.checkpoints[v.checkpoint]);
              if(closestPoints) then
                lastPP = GetPositionNear(lastPP,5,25); 
                lastPP.y = (GetTerrainHeightAndNormal(lastPP)) + 15;
                v.lastValidTransform = BuildDirectionalMatrix(lastPP,Normalize(closestPoints[2]-closestPoints[1]));
              end
              if(v.finished) then
                v.distance = v.distance/v.time;
              else
                v.distance = v.distance + tempD;
              end
            end
          end
          table.insert(sortedPositions,{player=net.netManager:playersInGame()[i],distance=v.distance});
        end
        table.sort(sortedPositions,function(a,b) return a.distance > b.distance end);
        self.localState.lastSortedPositions = sortedPositions;
        return sortedPositions;
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
        if(what == "SYNC") then
          self:load(...);
        elseif(what == "GET_READY") then
          self.raceState.raceStarted = 1;
          self.raceState.countdown, self.raceState.totalLaps, self.raceState.timelimit = ...;
          if(not self.userSettings.afk) then
            self:_send("JOIN_GAME");
          end
        elseif(what == "SET_SLOT") then
          self.localState.slot = ...;
          self.localState.inRace = true;
        elseif(what == "RACE_START") then
          self.raceState.raceStarted = 2;
          self.raceState.players = ...;
          if(self.userSettings.afk) then
            self:_trySpectate();
          end
        elseif(what == "END_RACE") then
          self.localState.inRace = false;
          self.localState.slot = nil;
          if(self.sp_r) then
            bzRoutine.routineManager:killRoutine(self.sp_r);
            self.sp_r = nil;
          end
        elseif(what == "JOIN_GAME") then
          self.raceState.players[from] = {
            team = net.netManager:playersInGame()[from].team,
            checkpoint = 1,
            distance = 0,
            lap = 1,
            time = 0,
            finished = false
          }
          self:_sendTo(self.sockets[from],"SET_SLOT",table.remove(self.avaliableSlots,1));
          self.raceState.countdown = 5;
        elseif(what == "CHECKPOINT") then
          local player, checkpoint, lap, time = ...;
          self.raceState.players[player].checkpoint = checkpoint;
          self.raceState.players[player].lap = lap;
          self.raceState.players[player].time = time;
          self.raceState.players[player].finished = self:_hasPlayerFinished(self.raceState.players[player]);
          print("Player reached checkpoint!",net.netManager:playersInGame()[from].name,checkpoint,lap);
          if(self.host) then
            self:_send("CHECKPOINT",...);
            self:_checkIfDone();
          end
          if(self.sp_r) then
            bzRoutine.routineManager:getRoutine(self.sp_r):removeKey(player);
          end
        elseif(what == "NAVPOINT_MISSING") then
          local missing = ...;
          local nav = self.navPoints[missing];
          self:_sendTo(self.sockets[from],"NAVPOINT",missing,nav);
        elseif(what == "NAVPOINT") then
          self:_setClientNav(...);
        elseif(what == "AFK") then
          local id, afk;
          if(self.host) then
            id = from;
            afk = ...;
            self.afkPlayers[from] = ...;
            self:_send("AFK",from,self.afkPlayers[from]);
          else
            id, afk = ...;
            self.afkPlayers[id] = afk;
          end
          local p = net.netManager:playersInGame()[id];
          if(p) then
            DisplayMessage(("%s is %s"):format(p.name,afk and "afk" or "no longer afk"));
          end
        elseif(what == "TELL") then
          DisplayMessage(...);
          if(self.host) then
            self:_send("TELL",...);
          end
        elseif(what == "SETTINGS") then
          self.hostSettings = ...;
        end
      end,
      --Check if everyone have reached goal
      _checkIfDone = function()
        local allDone = true;
        for i, v in pairs(self.raceState.players) do
          if(not v.finished) then
            allDone = false;
            break;
          end
        end
        if(allDone) then
          self:_endRace();
        end
      end,
      _setClientNav = function(name,nav)
        local checkpointMap = {};
        for i, v in ipairs(self.checkpoints) do
          checkpointMap[v.name] = i;
        end
        local navs = {[name] = nav};
        for i, v in pairs(navs) do
          self.navPoints[i] = v;
          local idx = checkpointMap[i];
          SetObjectiveName(v,idx > 1 and ("CHECKPOINT %d"):format(idx-1) or "FINISH");
        end
      end,
      _connectToAllPlayers = function()
        for i,v in pairs(net.netManager:getRemotePlayers()) do
          print(("  %d: %s"):format(i,v.name));
          self:_connectPlayer(v.id);
        end
        self.host = true;
      end,
      _hostSetup = function()
        if(self.clientSubject) then
          self.clientSubject:unsubscribe();
          self.clientTimer:stop();
          self.clientTimer = nil;
        end
        self.lobbyPickups_id = bzRoutine.routineManager:startRoutine("pickupManager",self.lobby_pickups,2,5);
        self:_connectToAllPlayers();
        if(self.raceState.raceStarted > 0) then
          self.racePickups_id = bzRoutine.routineManager:startRoutine("pickupManager",self.wpn_pickups,10,5);
        end
      end,
      _setHost = function(...)
        --Whenever host changes, check if I am new host
        self.hostPlayer = ...;
        if(IsHosting()) then
          self:_hostSetup();
        else
          self.clientTimer = misc.Timer(2,true);
          self.clientSubject = self.clientTimer:onAlarm():subscribe(function()
            self:_clientUpdate();
          end);
          self.clientTimer:start();
        end
      end,
      _onNetworkReady = function(player)
        self.localPlayer = player;
        print("Local player",player.id,player.name);
        if(IsHosting()) then
          self:_hostSetup();
        end
      end,
      _hostSyncPlayer = function(socket)
        local p = socket:packet();
        p:queue("SYNC",self:save());
        socket:flush(p);
      end,
      _hostSyncAll = function()
        for i, v in pairs(self.sockets) do
          self:_hostSyncPlayer(v);
        end
      end,
      _connectPlayer = function(id)
        if(not self.sockets[id] ) then
          print("connecting to player",id);
          local socket = net.netManager:createSocket("GAME.MG",id);
          self.sockets[id] = socket;
          socket:getPackets():subscribe(function(...)
            self:_onSocketPacket(...);
          end);
          self:_hostSyncPlayer(socket);
        end
      end,
      _clientUpdate = function()
        for i, v in pairs(self.checkpoints) do
          if(not IsValid(self.navPoints[v.name])) then
            self:_send("NAVPOINT_MISSING",v.name);
          end
        end
      end,
      _hostUpdate = function(dtime)
        for i, v in pairs(self.checkpoints) do
          local nav = self.navPoints[v.name];
          local pps = GetPathPoints(v.name);
          local p = pps[1] + (pps[2]-pps[1])/2;
          p.y = GetTerrainHeightAndNormal(p) + 1;
          if(not IsValid(nav)) then
            nav = BuildObject("apcmri",0,p);
            SetLocal(nav);
            self.navPoints[v.name] = nav;
            self:_send("NAVPOINT",v.name,nav);
            SetObjectiveName(nav,i > 1 and ("CHECKPOINT %d"):format(i-1) or "FINISH");
          end
          SetVelocity(nav,0);
          SetPosition(nav,p);
          --SetCurHealth(v,GetMaxHealth(v));
        end
        if(self.raceState.raceStarted == 2) then
          self.raceState.timelimit = self.raceState.timelimit - dtime;
          if(self.raceState.timelimit <= 0) then
            self:_endRace();
          end
        end
      end,
      _send = function(...)
        if(self.host) then
          for i, v in pairs(self.sockets) do
            self:_sendTo(v,...);
          end
        elseif(self.hostSocket) then
          self:_sendTo(self.hostSocket,...);
        end
      end,
      _endRace = function()
        self.lobbyState.lobbyTimer = 60;
        if(self.racePickups_id) then
          bzRoutine.routineManager:killRoutine(self.racePickups_id);
        end
        local endResult = self:_calcPlayerPositions();
        self.raceState = {
          raceStarted = 0, -- 0 not started, 1 - get ready - 2 go
          countdown = self.hostSettings.countdown,
          players = {},
          totalLaps = self.hostSettings.laps,
          avaliableSlots = {},
          timelimit = self.hostSettings.timelimit
        }
        self:_send("END_RACE");
        local winner = self.localState.lastSortedPositions[1];
        self:_tell(("Race ended, %s won!"):format(winner.player.name));
        self.localState.inRace = false;
        self.localState.slot = nil;
        if(self.sp_r) then
          bzRoutine.routineManager:killRoutine(self.sp_r);
          self.sp_r = nil;
        end
        self:_hostSyncAll();
      end,
      _tell = function(what)
        if(self.host) then
          DisplayMessage(what);
        end
        self:_send("TELL",what);
      end,
      _sendTo = function(socket,...)
        print("Sending to",socket,...);
        if(socket) then
          local p = socket:packet();
          p:queue(...);
          socket:flush(p);
        end
      end,
      _incCheckpoint = function(p)
        p.checkpoint = p.checkpoint + 1;
        if(p.checkpoint > #self.checkpoints) then
          p.checkpoint = 1;
          p.lap = p.lap + 1;
          p.finished = self:_hasPlayerFinished(p);
        end
      end,
      _incLocalCheckpoint = function()
        local p = self.raceState.players[self.localPlayer.id];
        self:_incCheckpoint(p);
        self:_send("CHECKPOINT",self.localPlayer.id,p.checkpoint,p.lap,p.time);
        if(self.host) then
          self:_checkIfDone();
        end
      end,
      _hasPlayerFinished = function(p)
        return p.lap > self.raceState.totalLaps;
      end,
      _setUpRace = function()
        if(self.host and self.raceState.raceStarted == 0) then
          self.lobbyState.lobbyTimer = 60;
          local playersAvailable = 0;
          for i, v in pairs(net.netManager:playersInGame()) do
            if(not self.afkPlayers[i]) then
              playersAvailable = playersAvailable + 1;
            end
          end
          if(playersAvailable >= self.hostSettings.minplayers) then
            self.localState.inRace = not self.userSettings.afk;
            self.raceState.raceStarted = 1;
            self.raceState.countdown = 5;
            self.raceState.timelimit = self.hostSettings.timelimit;
            self.raceState.totalLaps = self.hostSettings.laps
            self.avaliableSlots = OOP.copyTable(slotsTemplate);
            
            for i, v in pairs(net.netManager:playersInGame()) do
              if(self.localPlayer.id ~= i) then
                self:_sendTo(self.sockets[i],"GET_READY",self.raceState.countdown,self.raceState.totalLaps,self.raceState.timelimit);
              elseif(self.localState.inRace) then
                self.localState.slot = table.remove(self.avaliableSlots,1);
                print("Got Slot",self.localState.slot);
              end
            end
            self.racePickups_id = bzRoutine.routineManager:startRoutine("pickupManager",self.wpn_pickups);
          else
            DisplayMessage(("Not enough players to start round: %d/%d"):format(playersAvailable,self.hostSettings.minplayers))
          end
        end
      end,
      update = function(dtime)
        self.calcTimer:update(dtime);
        local newPh = net.netManager:getPlayerHandle() or self.playerHandle;
        if(not IsValid(newPh) and self.localState.inRace) then
          self.localState.respawning = true;
          self.localState.respawning_countdown = 2;
        elseif(self.localState.inRace and self.localState.respawning) then
          self.localState.respawning_countdown = self.localState.respawning_countdown - dtime;
          if(self.localState.respawning_countdown < 0) then
            self.localState.respawning = false;
            SetMaxHealth(handle,MAX_HEALTH);
            SetCurHealth(handle,MAX_HEALTH);
          else
            local p = self.raceState.players[self.localPlayer.id];
            if(p and p.lastValidTransform) then
              SetTransform(newPh,p.lastValidTransform);
              SetVelocity(newPh,SetVector(0,0,0));
              SetMaxHealth(handle,IM);
              SetCurAmmo(handle,0);
            end
          end
        end
        if(newPh ~= self.playerHandle) then
          self.lastPlayerPositions = {GetPosition(newPh)};
        end
        self.playerHandle = newPh;
        bzRoutine.routineManager:getRoutine(self.wep_r):updateHandle(self.playerHandle,0);
        --Make sure the player can't eject or hop out
        SetPilotClass(self.playerHandle,"");
        --We have to wait for the localPlayer to be set before we do anything
        local pps1 = GetPathPoints("test_1");
        local pps2 = GetPathPoints("test_2");
        if(not self.startInit) then
          self.startInit = true;
          --calculate race path
          local newDeathtraps = {};
          for i, v in ipairs(self.deathtraps) do
            newDeathtraps[v] = {
              center = GetCenterOfPath(v),
              radius = GetRadiusOfPath(v)
            }
          end
          self.deathtraps = newDeathtraps;
          local newChecks = {};
          for i, v in ipairs(self.checkpoints) do
            local paths = {};
            for i2, v2 in ipairs(v.paths) do
              paths[v2] = GetPathLength(v2);
            end
            table.insert(newChecks,{
              name = v.name,
              paths = paths
            });
          end
          self.checkpoints = newChecks;
          AddObjective("SCORE_BOARD","yellow",0,"");
        end

        if(not self.localPlayer) then
          return;
        end

        if(self.host) then
          self:_hostUpdate(dtime);
        elseif(self.clientTimer) then
          self.clientTimer:update(dtime);
        end
        if(self.raceState.raceStarted == 0 and net.netManager:getPlayerCount() > 0) then
          if(self.host) then
            self.lobbyState.lobbyTimer = self.lobbyState.lobbyTimer - dtime;
            if(self.lobbyState.lobbyTimer <= 0) then
              self:_setUpRace();
            end
          end
        elseif(self.raceState.raceStarted == 1) then
          self.raceState.countdown = self.raceState.countdown - dtime;
          if(self.localState.inRace) then
            SetCurAmmo(self.playerHandle,0);
            local t = misc.moveInFormation(self.playerHandle,self.localState.slot,{"A B C D","E F G H"},"race_start");
            SetTransform(self.playerHandle,t);
          end
          if(self.raceState.countdown <= 0) then
            if(self.host) then
              self.raceState.raceStarted = 2;
              self.raceState.players[self.localPlayer.id] = {
                team = net.netManager:playersInGame()[self.localPlayer.id].team,
                checkpoint = 1,
                distance = 0,
                lap = 1,
                time = 0,
                finished = false
              };
              self:_send("RACE_START",self.raceState.players);
            end
          end
        elseif(self.raceState.raceStarted == 2) then
          if((not self.localState.respawning) and self.localState.inRace and IsValid(self.playerHandle)) then
            --check if player has crossed the checkpoint
            local playerPos = GetPosition(self.playerHandle);
            self.raceState.players[self.localPlayer.id].time = self.raceState.players[self.localPlayer.id].time + dtime;
            SetMaxHealth(self.playerHandle,MAX_HEALTH);
            if(self.raceState.players[self.localPlayer.id].finished) then
              self.localState.inRace = false;
              self:_trySpectate();
            end
            local odf = ODFS[GetOdf(self.playerHandle)] or misc.odfFile(GetOdf(self.playerHandle));
            ODFS[GetOdf(self.playerHandle)] = odf;
            local g = GetTerrainHeightAndNormal(playerPos);
            local h = odf:getFloat("HoverCraftClass","setAltitude");
            local d = math.max(playerPos.y-g,0);
            if(d <= h+2) then
              for i, v in pairs(self.deathtraps) do
                if((GetDistance(self.playerHandle,v.center) <= v.radius) and IsInsideArea(self.playerHandle,i)) then
                  Damage(self.playerHandle,100000000);
                end
              end
            end
            local v = GetVelocity(self.playerHandle);
           
            --Experimental physics
            if(self.hostSettings.ex_physics) then
              playerPos.y = math.max(g + h*0.5,playerPos.y);
              SetPosition(self.playerHandle,playerPos)
              SetVelocity(self.playerHandle,v + SetVector(0,math.min(math.max(-math.pow(d,2)/4,-9),9),0)*dtime);
            end
            local cpI = (self.raceState.players[self.localPlayer.id].checkpoint%#self.checkpoints)+1;
            local pathPoints = GetPathPoints(self.checkpoints[cpI].name);
            for i, v in pairs(self.lastPlayerPositions) do
              local moveVec = v-playerPos;
              if DoLinesIntersect(playerPos,pathPoints[1],moveVec,pathPoints[2]-pathPoints[1]) then
                self:_incLocalCheckpoint();
                break;
              end
            end
          end
          for i, v in pairs(self.navPoints) do
            local turnOn = false;
            if(self.localState.inRace) then
              local cpI = (self.raceState.players[self.localPlayer.id].checkpoint%#self.checkpoints)+1;
              turnOn = (i == self.checkpoints[cpI].name);
            end
            if(turnOn) then
              SetObjectiveOn(v);
            else
              SetObjectiveOff(v);
            end
          end
          local score_board = self.localState.lastSortedPositions or {};
          local out = "Player positions:\n";
          for i, v in ipairs(score_board) do
            out = out .. ("%d. %s"):format(i,v.player.name);
          end
          UpdateObjective("SCORE_BOARD","yellow",1,out);
        end
        if(not self.localState.inRace) then
          --Keep player in starting area
          stayInLobby(self.playerHandle,"lobby_area");
        else
          SetMaxAmmo(newPh,MAX_AMMO);
        end
        self.lastPlayerPositions[1] = GetPosition(self.playerHandle);
      end,
      isAlive = function()
        return true;
      end,
      onAddPlayer = function(id,...)
        --Put player in lobby list
        if(self.localPlayer) then
          if(IsHosting()) then
            if(net.netManager:getPlayerCount() <= 1) then
            end
            self:_connectPlayer(id);
          end
        end
      end,
      onCreatePlayer = function()
      end,
      onDeletePlayer = function(id,...)
        --Remove player from race
        self.raceState.players[id] = nil;
        --TODO: check if more player are left in race, else quit and start new round
      end,
      onDestroy = function()
      end,
      save = function(...)
        return 
          self.raceState.raceStarted,
          self.raceState.countdown,
          self.raceState.players,
          self.raceState.timelimit,
          self.raceState.totalLaps,
          self.afkPlayers,
          self.hostSettings;
      end,
      load = function(...)
        self.raceState.raceStarted,
          self.raceState.countdown,
          self.raceState.players,
          self.raceState.timelimit,
          self.raceState.totalLaps,
          self.afkPlayers,
          self.hostSettings = ...;
      end,
      _trySpectate = function(player)
        if((not self.localState.inRace) and (self.raceState.raceStarted > 0)) then
          local key;
          local targets = {};
          if(self.sp_r) then
            bzRoutine.routineManager:killRoutine(self.sp_r);
            self.sp_r = nil;
          end
          for i,v in pairs(self.raceState.players) do
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
      end,
      onCommand = function(command,...)
        command = command:lower();
        local validCommand = false;
        if(not self.localState.inRace) then
          if(self.host and self.raceState.raceStarted == 0) then
            if(command == "start") then
              self:_setUpRace();
              validCommand = true;
            elseif(command == "enable") then
              local key = ...;
              if(type(self.hostSettings[key]) == "boolean") then
                self.hostSettings[key] = true;
                validCommand = true;
                self:_tell(("%s enabled %s"):format(self.localPlayer.name,key));
              end
            elseif(command == "disable") then
              local key = ...;
              if(type(self.hostSettings[key]) == "boolean") then
                self.hostSettings[key] = false;
                validCommand = true;
                self:_tell(("%s disabled %s"):format(self.localPlayer.name,key));
              end
            elseif(command == "set") then
              local key, val = ...;
              if(type(self.hostSettings[key]) == "number") then
                self.hostSettings[key] = tonumber(val) or 1;
                validCommand = true;
                self:_tell(("%s set %s to %d"):format(self.localPlayer.name,key,self.hostSettings[key]));
              end
            end
            if(validCommand) then
              self:_send("SETTINGS",self.hostSettings);
            end
          end
          if(command == "helprace") then
            DisplayMessage("Commands:");
            DisplayMessage("/helprace - show this list");
            DisplayMessage("/afk - enable/disable afk mode");
            DisplayMessage("/show - show host settings");
            DisplayMessage("Host commands:");
            DisplayMessage("/start - get ready for next round");
            DisplayMessage("/disable [autostart]");
            DisplayMessage("/enable [autostart]");
            DisplayMessage("  autostart - starts new round automatically after 30 sec");
            DisplayMessage("  ex_physics - starts new round automatically after 30 sec");
            DisplayMessage("/set [laps|timelimit|minplayers] number");
            DisplayMessage("  laps - how many laps");
            DisplayMessage("  timelimit - how long should a round last");
            DisplayMessage("  minplayers - min players required to race");
            validCommand = true;
          elseif(command == "afk") then
            self.userSettings.afk = not self.userSettings.afk;
            self.afkPlayers[self.localPlayer.id] = self.userSettings.afk;
            validCommand = true;
            if(not self.host) then
              self:_send("AFK",self.userSettings.afk);
            end
          elseif(command == "show") then 
            for i, v in pairs(self.hostSettings) do
              DisplayMessage(("%s: %s"):format(i,tostring(v)));
            end
            validCommand = true;
          elseif(command == "spectate") then
            local player = tonumber(... or "1");
            self:_trySpectate(player);
            validCommand = true;
          end
          if(not validCommand) then
            DisplayMessage("Invalid command or arguments.");
          end
        else
          DisplayMessage("Commands are disabled while in race");
        end
      end
    }
  })

);


bzRoutine.routineManager:registerClass(gameManagerRoutine);
bzRoutine.routineManager:registerClass(pickupManagerRoutine);
bzRoutine.routineManager:registerClass(giveWeaponRoutine);


function GameKey(...)
  bzUtils:onGameKey(...);
end

function Start(...)
  bzUtils:onStart(...);
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
  local playerCam = (GetClassLabel(h) == "camerapod") and GetTeamNum(h) ~= 0;
  if(((GetClassLabel(h) == "person") or playerCam) and (not IsRemote(h))) then
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

return function(...)
  local routine = bzRoutine.routineManager:startRoutine("gameManger",...);
end