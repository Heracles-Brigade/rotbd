local bzCore = require("bz_core");
local misc = require("misc");
local OOP = require("oop");
local Rx = require("rx");

local Class = OOP.Class;
local Decorate = OOP.Decorate;
local Meta = OOP.Meta;
local getClassRef = OOP.getClassRef;
local getClass = OOP.getClass;
local copyTable = OOP.copyTable;
local assignObject = OOP.assignObject;
local isIn = OOP.isIn;
local SetLabel = SetLabel;
local Implements = OOP.Implements;
local Interface = OOP.Interface;
local odfFile = misc.odfFile;

local Serializable = misc.Serializable;
local Updateable = misc.Updateable;
local ObjectListener = misc.ObjectListener;
local PlayerListener = misc.PlayerListener;
local CommandListener = misc.CommandListener;
local NetworkListener = misc.NetworkListener;
local StartListener = misc.StartListener;
local KeyListener = misc.KeyListener;
local BzInit = misc.BzInit;
local BzDestroy = misc.BzDestroy;
local BzRemove = misc.BzRemove;
local MpSyncable = misc.MpSyncable;
local BzAlive = misc.BzAlive;
local BzModule = misc.BzModule






local Packet = Class("MP.Packet",{
  constructor = function(id)
    self.contents = {n=0};
    self.cindex = 0;
    self.id = id;
  end,
  methods = {
    getId = function()
      return self.id;
    end,
    queue = function(...)
      local p = table.pack(...);
      for i=1, p.n do
        local v = p[i];
        self.contents.n = self.contents.n + 1;
        self.contents[self.contents.n] = v;
      end
    end,
    left = function()
      return self.contents.n;
    end,
    next = function()
      if(self.contents.n > 0) then
        self.contents.n = self.contents.n - 1;
        self.cindex = self.cindex + 1;
        return self.contents[self.cindex];
      end
    end
  }
});


local SockInterface = Class("MP.SockInterface",{
  constructor = function(to,id)
    self.sto = {};
    if(type(to) == "number") then
      table.insert(self.sto,to);
    else
      self.sto = copyTable(to);
    end
    self.id = id;
  end,
  methods = {
    send = function(...)
      for i,v in pairs(self.sto) do
        Send(v,"S",self.id,...);
      end
    end
  }
});

local Socket = Class("MP.Socket",{
  constructor = function(interface,machine_id)
    self.packets = {};
    self.s_queue = {};
    self.r_queue = {};
    self.s_interface = interface;
    self.machine_id = machine_id;
    self.r_subject = Rx.ReplaySubject.create();
    self.frameLimit = 10;
    self.alive = true;
    self._current_id = 0;
  end,
  methods = {
    nextId = function()
      self._current_id = self._current_id + 1;
      return self._current_id + self.machine_id*1000;
    end,
    kill = function()
      self.alive = false;
    end,
    isAlive = function()
      return self.alive;
    end,
    packet = function()
      local id = self:nextId();
      local p = Packet(id);
      self.packets[id] = {
        subject = Rx.Subject.create(),
        packet = p
      };
      return p;
    end,
    flush = function(packet)
      table.insert(self.s_queue,{i = 1, p = packet});
      return packet.subject;
    end,
    sendNext = function()
      if(#self.s_queue > 0) then
        local p = self.s_queue[1].p;
        for i=1,math.min(p:left(),self.frameLimit) do
          local n = p:next();
          self.s_interface:send(1,p:getId(),n);
        end
        if(p:left() <= 0) then
          self.s_interface:send(2,p:getId());
          table.remove(self.s_queue,1);
        end
      end
    end,
    getPackets = function()
      return self.r_subject;
    end,
    receive = function(from,type,id,payload)
      if(not self.r_queue[id]) then
        local r = {
          id = id,
          from = from,
          size = 0,
          contents = {}
        };
        self.r_queue[id] = r;
      end
      local p = self.r_queue[id];
      if(type == 1) then
        p.size = p.size + 1;
        p.contents[p.size] = payload;
      elseif(type == 2) then
        p.contents.n = p.size;
        self.r_subject:onNext(p.from,unpack(p.contents));
        self.r_queue[id] = nil;
      end
    end
  }
});

local NetworkManager = Decorate(BzModule("NetworkManagerModule"),
  Class("Net.NetworkManager", {
    constructor = function()
      self.sockets = setmetatable({},{__mode="v"});
      self.socketSubjects = {};
      self.hostSubject = Rx.ReplaySubject.create();
      self._current_id = 0;
      self.stardedAsHost = IsHosting();
      self._whoIsHost = 0;
      self.migrating = false;
      self.waitToMigrate = 30;
      self.networkIsReady = false;
      self.playerHandles = {
        me = GetPlayerHandle(),
        remote = {}
      }
      self.networkReadySubject = Rx.ReplaySubject.create();
      self.players = {
        all = {},
        remote = {},
        me = {},
        allInGame = {},
        l = nil
      };

    end,
    methods = {
      update = function(...)
        if(self.networkIsReady) then
          local c = self.playerHandles.me;
          self.playerHandles.me = (IsValid(GetPlayerHandle()) and GetPlayerHandle()) or c;
          if(c ~= self.playerHandles.me) then
            print("New handle!",c,self.playerHandles.me,GetPlayerHandle());
            --New playerhandle, send it to the other users
            Send(0,"Z",self.playerHandles.me,self.playerHandles.me == nil);
          end
        end
        for i, v in pairs(self:getRemotePlayers()) do
          local idx = v.team or "NON";
          c = self.playerHandles.remote[idx];
          self.playerHandles.remote[idx] = 
            (IsValid(GetPlayerHandle(v.team)) and 
              GetPlayerHandle(v.team)) or
            (self.playerHandles.remote[idx]);
          if(c ~= self.playerHandles.remote[idx]) then
            Send(i,"Y",self.playerHandles.remote[idx]);
          end
        end
        if(self.migrating and IsHosting()) then
          self.waitToMigrate = self.waitToMigrate - 1;
          if(self.waitToMigrate <= 0) then
            for i,v in pairs(self.players.remote) do
              Send(i,"H");
            end
            self:_setHostId(self:getLocalPlayer().id);
          end
        end
        for i,v in pairs(self.sockets) do
          if(v:isAlive()) then
            v:sendNext();
          else
            self.sockets[i] = nil;
          end
        end
      end,
      getPlayerHandle = function(team)
        local h;
        if((team == nil) or (team == self:getLocalPlayer().team)) then
          h = self.playerHandles.me;
        else
          h = self.playerHandles.remote[team];
        end
        return (IsValid(GetPlayerHandle(team)) and GetPlayerHandle(team)) or 
          (IsValid(h) and h);
      end,
      onNetworkReady = function()
        return self.networkReadySubject;
      end,
      nextId = function()
        self._current_id = (self._current_id%9000) + 1;
        local p = self:getLocalPlayer().id;
        return self._current_id + p*10000;
      end,
      onReceive = function(id,type,interface_id,a,...)
        self.players.me[id] = nil;
        if(type == "S") then
          local args = {...};
          if(a == 0) then
            local name = table.remove(args,1);
            local csock = self:_createSocket(id,interface_id);
            if(self.socketSubjects[name]) then
              self.socketSubjects[name]:onNext(csock,unpack(args));
            end
          elseif(self.sockets[interface_id]) then
            self.sockets[interface_id]:receive(id,a,...);
          end
        elseif(type == "H") then
          self:_setHostId(id);
        elseif(type == "X") then
          if(not self.players.l) then
            local myid = interface_id;
            self.players.l = self.players.all[myid];
            self.players.me = {self.players.l};
            self.players.allInGame[myid] = self.players.l;
            self.networkReadySubject:onNext(self.players.l);
          end
        elseif(type == "Z") then
          local p = self.players.all[id];
          if(p) then
            self.playerHandles.remote[p.team or "NON"] = interface_id;
          end
        elseif(type == "Y") then
          self.playerHandles.me = (IsValid(self.playerHandles.me) and self.playerHandles.me) or interface_id;
        elseif(type == "R") then
          Send(id,"Z",self.playerHandles.me,self.playerHandles.me == nil);
        end
      end,
      _createSocket = function(to,interface_id)
        local i = SockInterface(to,interface_id);
        local player = self:getLocalPlayer();
        local socket = Socket(i,player.id);
        self.sockets[interface_id] = socket;
        table.insert(self.sockets,socket);
        return socket,i;
      end,
      _setHostId = function(id)
        if(self.migrating) then
          if(IsHosting()) then
            DisplayMessage(("New host is you"));
          else
            local h = self.players.all[id];
            if(h) then
              DisplayMessage(("New host is %s"):format(h.name));
            else
              --Probably local player
              DisplayMessage(("New host is 'unknown'"));
            end
          end
          self.migrating = false;
        end
        self._whoIsHost = id;
        self.hostSubject:onNext(self.players.all[id]);
      end,
      getPlayerCount = function()
        local l = 0;
        for i,v in pairs(self.players.allInGame) do
          l = l + 1;
        end
        return l;
      end,
      playersInGame = function()
        return self.players.allInGame;
      end,
      getHostId = function()
        return self._whoIsHost; 
      end,
      getHosts = function()
        return self.hostSubject;
      end,
      localPlayerCount = function()
        local c = 0;
        for i,v in pairs(self.players.me) do
          c = c + 1;
        end
        return c;
      end,
      createSocket = function(name,to,...)
        local socket,sinterface = self:_createSocket(to,self:nextId());
        sinterface:send(0,name,...);
        return socket;
      end,
      getSockets = function(name)
        if(not self.socketSubjects[name]) then
          self.socketSubjects[name] = Rx.Subject.create();
        end
        return self.socketSubjects[name];
      end,
      getLocalPlayer = function()
        if(self.players.l) then
          return self.players.l;
        end
        for i, v in pairs(self.players.me) do
          self.players.l = v;
          return v;
        end
      end,
      getRemotePlayers = function()
        return self.players.remote;
      end,
      onAddPlayer = function(id,name,team)
        print("AddPlayer",id,name,team);
        --Tell players their ID
        Send(id,"X",id);
        self.players.me[id] = nil;
        self.players.remote[id] = {id=id,name=name,team=team};
        self.players.allInGame[id] = {id=id,name=name,team=team};
        if(IsHosting()) then
          Send(id,"H");
        end
      end,
      onDeletePlayer = function(id,name,team)
        --Remove player
        print("Deleting player!",id,name,team);
        if(self:getHostId() == id) then
          DisplayMessage("Host left, migrating...");
          self.migrating = true;
          self.waitToMigrate = 30;
        end
        self.players.remote[id] = nil;
        self.players.all[id] = nil;
        self.players.allInGame[id] = nil;
      end,
      onCreatePlayer = function(id,name,team)
        --Add player
        print("CreatePlayer",id,name,team);
        self.players.all[id] = {id=id,name=name,team=team};
        self.players.me[id] = {id=id,name=name,team=team};
      end,
      onStart = function(...)
        --Check player count
        print("onStart");
        local l = 0;
        local index = 1;
        for i,v in pairs(self.players.all) do
          l = l + 1;
          index = i;
        end
        
        if(l == 1) then
          local myid = index;
          self.players.l = self.players.all[myid];
          self.players.me = {self.players.l};
          self.players.allInGame[myid] = self.players.l;
          self.networkIsReady = true;
          self.networkReadySubject:onNext(self.players.l);
        end
      end,
      save = function()
      end,
      load = function(saveData)
      end,
      afterSave = function()
      end,
      afterLoad = function()
      end,
      onGameKey = function(...)
      end,
      onCommand = function(...)
      end,
      onCreateObject = function(...)
      end,
      onAddObject = function(...)
      end,
      onDeleteObject = function(...)
      end
    }
  })
);

local netManager = bzCore:addModule(NetworkManager);


return {
  netManager = netManager
};

