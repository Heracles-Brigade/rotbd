local SendQueue = {};
local ReceiveQueue = {};
local pid = 0;

local subH = {
  Send = Send,
  Receive = Receive
}
local improvedSend = function(id,type,...)
  print("Sending!",id,type,...);
  local package = {...};
  --Find 'handles'
  --S = start package
  
  subH["Send"](id,"S",pid,type);
  for i,v in pairs(package) do
    subH["Send"](id,"I",pid,v);
  end
  subH["Send"](id,"E",pid)
  pid = pid + 1;
end

local improvedReceive = function(from,type,pid,...)
  print(from,type,pid,...);
  local rid = from * 10000;
  if(type == "S") then
    local ptype = ...;
    ReceiveQueue[rid] = {
      from = from,
      rid = rid,
      type = ptype,
      package = {}
    };
  elseif(type == "I") then
    local data = ...;
    table.insert(ReceiveQueue[rid].package,data)
  elseif(type == "E") then
    local l = ReceiveQueue[rid];
    subH["Receive"](l.from,l.type,unpack(l.package));
  end
end

local hooks = {
    Receive = improvedReceive
};

local p = {}; 
p.old = getmetatable(_G) or {};

p.__index = function(t,k)
  if(hooks[k]) then
    return hooks[k];
  elseif(p.old.__index) then
    return p.old.__index(t,k);
  else
    return rawget(t,k);
  end
end

p.__newindex = function(t,k,v)
    if(hooks[k]) then
        subH[k] = v;
    elseif(p.old.__newindex) then
        p.old.__newindex(t,k,v);
    else
        rawset(t,k,v);
    end
end

_G["Send"] = improvedSend;

setmetatable(_G,p);
--Todo create a packet manager


--[[

local Connection = Class("Net.Connection",{
  constructor = function()

  end,
  methods = {
    send = function()

    end
  }
})


local NetworkManager = D(BzModule("NetworkManagerModule"),
  Class("Net.NetworkManager", {
    constructor = function()
      self.connections = {};
      self.nextid = 1;
      self.id = class:getInstanceId();
      self.players = {
        all = {},
        remote = {},
        local = {}
      };
    end,
    static = {
      getInstanceId = function()
        class.instanceId = class.instanceId + 1;
        return class.instanceId;
      end
    },
    methods = {
      update = function(...)
        for i, v in pairs(self.modules) do
          v:update(...);
        end
      end,
      send = function(id,...)
        --Id, type, 'Namespace', data
        Send(id,"P","Net.NetPack",{
          pl = {id:id,...},
          pid = self.nextid + self.id*1000000
        });


        self.nextid = self.nextid + 1;
      end,
      onReceive = function(id,type,namespace,data)
        if(type == "P") then
          --Use map?
          if(namespace == "Net.NetPack") then
            
          end
        end
      end,
      getLocalPlayer = function()
        for i, v in pairs(self.players.local) do
          return v;
        end
      end,
      onAddPlayer = function(id,name,team)
        self.players.local[id] = nil;
        self.players.remote[id] = {id:id,name:name,team:team};
      end,
      onDeletePlayer = function(id,name,team)
        --Remove player
        self.players.remote[id] = nil;
        self.players.all[id] = nil;
      end,
      onCreatePlayer = function(id,name,team)
        --Add player
        self.players.all[id] = {id:id,name:name,team:team};
        self.players.local[id] = {id:id,name:name,team:team};
      end,
      onStart = function(...)
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
NetworkManager.instanceId = 0;
]]
