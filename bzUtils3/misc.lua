local OOP = require("oop");
local rx = require("rx");
local Interface = OOP.Interface;
local Class = OOP.Class;

local getClassRef = OOP.getClassRef;
local getClass = OOP.getClass;

local isIn = OOP.isIn;
local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local Meta = OOP.Meta;

--GetOdf sometimes returns junk after the name
--This wrapper removes that junk
local _GetOdf = GetOdf;

GetOdf = function(...)
  local r = _GetOdf(...);
  if(r) then
    return r:gmatch("[^%c]+")();
  end
  return r;
    --return _GetOdf(...):gmatch("[^%c]+")();
end

local function global2Local(vec,t)
  local up = SetVector(t.up_x,t.up_y,t.up_z);
  local front = SetVector(t.front_x,t.front_y,t.front_z);
  local right = SetVector(t.right_x,t.right_y,t.right_z);
  return vec.x * front + vec.y*up + vec.z * right;
end

local function local2Global(vec,t)
  local up = SetVector(t.up_x,t.up_y,t.up_z);
  local front = SetVector(t.front_x,t.front_y,t.front_z);
  local right = SetVector(t.right_x,t.right_y,t.right_z);
  return vec.x/front + vec.y/up + vec.z/right;
end

local function stringlist(str)
  local m = str:gmatch("%s*([%.%w]+)%s*,?");
  local ret = {};
  for v in m do
    table.insert(ret,m());
  end
  return unpack(ret);
end

local function str2vec(str)
  local m = str:gmatch("%s*(%-?%d*%.?%d*)%a*%s*,?");
  return SetVector(m(),m(),m());
end

--Get id of table/function
local function getHash(a)
  local nameref = tostring(a);
  return tonumber(({nameref:gsub("%a+: ","")})[1],16);
end

local TableStore = Class("TableStore",{
  constructor = function()
    this.tables = {};
    this.newIndecies = {};
  end,
  static = {
    load = function(data)
      return class:new():load(data);
    end
  },
  methods = {
    register = function(t)
      if(not t) then
        error("Can not register a nil value",2)
      end
      if(not this:hasTable(getHash(t))) then
        this.tables[getHash(t)] = t;
      else
        error(string.format("Table[0x%X] is already registered",getHash(t)),2);
      end
    end,
    getTable = function(index)
      if(self:hasTable(index)) then
        return self.tables[index];
      else
        error(string.format("Could not find table[0x%X]",index),2);
      end
    end,
    hasTable = function(index)
      return ((self.tables[index] and {true}) or {false})[1];
    end,
    getNewIndex = function(old)
      --return new index after load
      if(self.newIndecies[old]) then
        return self.newIndecies[old];
      else
        error(string.format("Could not get new index from 0x%X",old));
      end
    end,
    save = function()
      return self.tables;
    end,
    load = function(data)
      for i,v in pairs(data) do
        local newIndex = getHash(v);
        self.newIndecies[i] = newIndex;
        self:register(v);
      end
    end
  }
})

--temp tablestore
local tableRefs = TableStore();

local Pointer;
Pointer = Class("Pointer",{
  constructor = function(tornum)
    local t;
    local i;
    if(type(tornum) == "number") then
      i = tornum;
      t = class:_toTable(tornum);
    else
      i = class:_get(tornum);
      t = tornum;
    end
    self.tref = t;
    self.index = i;
  end,
  static = {
    _get = function(t)
      print("Get",class,t);
      local i = getHash(t);
      if(not tableRefs:hasTable(i)) then
          tableRefs:register(t);
      end
      return i;
    end,
    _toTable = function(index)
      print("To table",class);
      return tableRefs:getTable(index);
    end,
    _fromOld = function(index)
      print("From old",class)
      return tableRefs:getTable(tableRefs:getNewIndex(index));
    end
  },
  methods = {
    save = function()
      return self.index;
    end,
    getHash = function()
      return self.index;
    end,
    getTable = function()
      return self.tref;
    end
  },
  metatable = {
    __index = function(t,k)
      return t:getTable()[k];
    end,
    __newindex = function(t,k,v)
      t:getTable()[k] = v;
    end
  }
});

local odfHeader = Class("odfHeader",{
  constructor = function(file,name)
    self.file = file;
    self.header = name;
  end,
  methods = {
    getVar = function(varName,...)
      return GetODFString(self.file,self.header,varName,...);
    end,
    getAsInt = function(varName,...)
      return GetODFInt(self.file,self.header,varName,...);
    end,
    getAsBool = function(varName,...)
      return GetODFBool(self.file,self.header,varName,...);
    end,
    getAsFloat = function(varName,...)
      return GetODFFloat(self.file,self.header,varName,...);
    end,
    getAsVector = function(varName,...)
      local v = self:getVar(varName,...);
      if(v) then
          return str2vec(v);
      end
    end,
    getAsTable = function(varName,...)
      local ret = {};
      local c = 1;
      local max = self:getAsInt(varName .. "Count",100);
      local n = self:getVar(varName .. c,...);
      while n and (c <= max) do
        table.insert(ret,n);
        c = c + 1;
        n = self:getVar(varName .. c,...);
      end
      return ret;
    end
  }
})
local odfFile;
odfFile = Class("odfFile",{
  constructor = function(fileName)
    self.name = fileName;
    self.file = OpenODF(fileName);
    self.headers = {};
    local parent = self:getProperty("Meta","parent");
    if(parent) then
      self.parent =  odfFile(parent);
    end
    --assert(self.file,"Could not open \"%s\"!",self.name);
  end,
  methods = {
    getHeader = function(headerName)
      local this = self;
      if(not this.headers[headerName]) then
          this.headers[headerName] = odfHeader(this.file,headerName);
      end
      return this.headers[headerName];
    end,
    getInt = function(header,...)
      local this = self;
      return (this:getHeader(header):getVar(...)~=nil and this:getHeader(header):getAsInt(...))
              or (this.parent and this.parent:getInt(header,...));
    end,
    getFloat = function(header,...)
      local this = self;
      return (this:getHeader(header):getVar(...)~=nil and this:getHeader(header):getAsFloat(...))
              or (this.parent and this.parent:getFloat(header,...));
    end,
    getProperty = function(header,...)
      local this = self;
      return this:getHeader(header):getVar(...) or (this.parent and this.parent:getProperty(header,...));
    end,
    getBool = function(header,...)
      local this = self;
      return (this:getHeader(header):getVar(...)~=nil and this:getHeader(header):getAsBool(...))
              or (this.parent and this.parent:getBool(header,...));
    end,
    getTable = function(header,...)
      local this = self;
      local t1 = this:getHeader(header):getAsTable(...);
      if(#t1 <= 0) then
        t1 = (this.parent and this.parent:getTable(header,...)) or t1;
      end
      return t1;
    end,
    getVector = function(header,...)
      local this = self;
      return (this:getHeader(header):getVar(...)~=nil and this:getHeader(header):getAsVector(...))
              or (this.parent and this.parent:getVector(header,...));
    end,
    isValid = function()
      return self.file ~= nil;
    end
  }
})

local function spawnInFormation(formation,location,dir,units,team,seperation)
  if(seperation == nil) then 
    seperation = 10;
  end
  local tempH = {};
  local directionVec = Normalize(SetVector(dir.x,0,dir.z));
  local formationAlign = Normalize(SetVector(-dir.z,0,dir.x));
  for i2, v2 in ipairs(formation) do
    local length = v2:len();
    local i3 = 1;
    for c in v2:gmatch(".") do
      local n = tonumber(c);
      if(n) then
        local x = (i3-(length/2))*seperation;
        local z = i2*seperation*2;
        local pos = x*formationAlign + -z*directionVec + location;
        local h = BuildObject(units[n],team,pos);
        local t = BuildDirectionalMatrix(GetPosition(h),directionVec);
        SetTransform(h,t);
        table.insert(tempH,h);
      end
      i3 = i3+1;
    end
  end
  return tempH;
end

local function spawnInFormation2(formation,location,units,team,seperation)
  return spawnInFormation(formation,GetPosition(location,0),GetPosition(location,1) - GetPosition(location,0),units,team,seperation);
end

--Div interfaces
local Serializable = Interface("Serializable",{"save","load"});
local AfterLoad = Interface("AfterLoad",{"afterLoad"});
local AfterSave = Interface("AfterSave",{"afterSave"});
local Updateable = Interface("Updateable",{"update"});
local ObjectListener = Interface("ObjectListener",{"onAddObject","onCreateObject","onDeleteObject"});
local PlayerListener = Interface("PlayerListener",{"onAddPlayer","onCreatePlayer","onDeletePlayer"});
local CommandListener = Interface("CommandListener",{"onCommand"});
local NetworkListener = Interface("ReceiveListener",{"onReceive"});
local MessageListener = Interface("MessageListener",{"onMessage"});
local KeyListener = Interface("Key",{"onGameKey"});
local StartListener = Interface("StartListener",{"onStart"});
local BzInit = Interface("BzInit",{"onInit"});
local BzDestroy = Interface("BzDestroy",{"onDestroy"});
local BzRemove = Interface("BzRemove",{"onRemove"});
local MpSyncable = Interface("MpSyncable",{"mpLoseObject","mpGainObject"});
local BzAlive = Interface("BzAlive",{"isAlive"});


local usedNames = {};

local BzModule = function(name)    
  return function(class)
    assert(not usedNames[name], "Duplicate module!",1);
    usedNames[name] = true;
    Meta(class,{
      BzModule = {
        name = name
      }
    });
    Decorate(Implements(StartListener,Serializable,Updateable,ObjectListener,
                        PlayerListener,CommandListener,NetworkListener,KeyListener,AfterLoad,AfterSave),class);
  end
end




local DefaultRuntimeModule = Decorate(
  BzModule("DefaultRuntimeModule"),
  Class("DefaultRuntimeModule",{
    constructor = function(containers)
      self.all = containers.all or {};
      self.afterSaveListeners = setmetatable(containers.afterSaveListeners or {}, {__mode=v});
      self.afterLoadListeners = setmetatable(containers.afterLoadListeners or {}, {__mode=v});
      self.netListeners = setmetatable(containers.netListeners or {}, {__mode=v});
      self.objectListeners = setmetatable(containers.objectListeners or {}, {__mode=v});
      self.playerListeners = setmetatable(containers.playerListeners or {}, {__mode=v});
      self.commandListeners = setmetatable(containers.commandListeners or {}, {__mode=v});
      self.keyListeners = setmetatable(containers.keyListeners or {}, {__mode=v});
      self.startListeners = setmetatable(containers.startListeners or {}, {__mode=v});
      self.classes = containers.classes or {};
    end,
    methods = {
      update = function(...)
        for i,v in pairs(self.all) do
          if(v:isAlive()) then
              v:update(...);
          else
              --Remove
          end
        end
      end,
      onStart = function(...)
        for i,v in pairs(self.startListeners) do
          v:onStart(...);
        end
      end,
      save = function()
        local objdata = {};
        for i,v in pairs(self.all) do
          table.insert(objdata,{
            data = {v:save()},
            class = getClassRef(v);
          });
        end
        return {objects = objdata};
      end,
      load = function(saveData)
        local objdata = saveData.objects;
        for i,v in pairs(objdata) do
          local c = getClass(v.class);
          local i = c:new();
          i:load(unpack(v.data));
          self:registerInstance(i);
        end
      end,
      afterSave = function()
        for i,v in pairs(self.afterSaveListeners) do
          v:afterSave();
        end
      end,
      afterLoad = function()
        for i,v in pairs(self.afterLoadListeners) do
          v:afterLoad();
        end   
      end,
      onGameKey = function(...)
        for i,v in pairs(self.keyListeners) do
          v:onGameKey(...);
        end
      end,
      onCommand = function(...)
        for i,v in pairs(self.commandListeners) do
          v:onCommand(...);
        end
      end,
      onAddPlayer = function(...)
        for i,v in pairs(self.playerListeners) do
          v:onAddPlayer(...);
        end
      end,
      onDeletePlayer = function(...)
        for i,v in pairs(self.playerListeners) do
          v:onDeletePlayer(...);
        end
      end,
      onCreatePlayer = function(...)
        for i,v in pairs(self.playerListeners) do
          v:onCreatePlayer(...);
        end
      end,
      onCreateObject = function(handle,...)
        for i,v in pairs(self.objectListeners) do
          v:onCreateObject(handle,...);
        end
      end,
      onAddObject = function(handle,...)
        for i,v in pairs(self.objectListeners) do
          v:onAddObject(handle,...);
        end
      end,
      onDeleteObject = function(handle,...)
        for i,v in pairs(self.objectListeners) do
          v:onDeleteObject(handle,...);
        end
      end,
      onReceive = function(...)
        for i,v in pairs(self.netListeners) do
          v:onReceive(...);
        end
      end,
      unregisterInstance = function(obj)
        table.remove(self.all,obj);
      end,
      registerInstance = function(obj)
        table.insert(self.all,obj);
        if(NetworkListener:made(obj)) then
          table.insert(self.netListeners,obj);
        end
        if(PlayerListener:made(obj)) then
          table.insert(self.playerListeners,obj);
        end
        if(CommandListener:made(obj)) then
          table.insert(self.commandListeners,obj);
        end
        if(ObjectListener:made(obj)) then
          table.insert(self.objectListeners,obj);
        end
        if(KeyListener:made(obj)) then
          table.insert(self.keyListeners,obj);
        end
        if(StartListener:made(obj)) then
          table.insert(self.startListeners,obj);
        end
        if(AfterLoad:made(obj)) then
          table.insert(self.afterLoadListeners,obj);
        end
        if(AfterSave:made(obj)) then
          table.insert(self.afterSaveListenersobj);
        end
      end
    }
  })
);

local normalWeps = {
  "cannon", "machinegun", "thermallauncher", "imagelauncher"
};
--Maybe ignore these?
--Can't count shot count of beam weapons
local dispenserWeps = {
  radarlauncher = {"RadarLauncherClass", "objectClass"}, 
  dispenser = {"DispenserClass", "objectClass"}
}


local function getAmmoCost(weaponOdf)
  local wepOdf = odfFile(weaponOdf);
  local ctype = wepOdf:getProperty("WeaponClass","classLabel");
  if(isIn(ctype,normalWeps)) then
    local ord = wepOdf:getProperty("WeaponClass","ordName");
    if(ord) then
      local ordOdf = odfFile(ord);
      return ordOdf:getInt("OrdnanceClass","ammoCost");
    end
  end
  return 0;
end


local Timer = Decorate(
  Implements(Updateable,Serializable),
  Class("misc.Timer",{
    constructor = function(limit,looping,...)
      self.tsubject = rx.Subject.create();
      self.count = 0;
      self.looping = looping;
      self.time = 0;
      self.limit = limit;
      self.running = false;
    end,
    methods = {
      update = function(dtime)
        if(self.running) then
          self.time = self.time + dtime;
          if(self.time >= self.limit) then
            self.count = self.count + 1;
            self.tsubject:onNext(self.count);
            if(self.looping) then
              self:restart();
            else
              self:stop();
            end
          end
        end
      end,
      setTime = function(time)
        self.time = time;
      end,
      start = function()
        self.running = true;
      end,
      restart = function()
        self:stop();
        self:start();
      end,
      stop = function()
        self:pause();
        self.time = 0;
      end,
      pause = function()
        self.running = false;
      end,
      onAlarm = function()
        return self.tsubject;
      end,
      save = function()
        return self.time, self.count;
      end,
      load = function(...)
        self.time,self.count = ...;
      end,
      getTime = function()
        return self.time;
      end,
      getTotalTime = function()
        return self:getTime() + self.count * self.limit;
      end
    }
  })
);



return {
  Serializable = Serializable,
  Updateable = Updateable,
  ObjectListener = ObjectListener,
  PlayerListener = PlayerListener,
  CommandListener = CommandListener,
  NetworkListener = NetworkListener,
  StartListener = StartListener,
  BzMessage = BzMessage,
  KeyListener = KeyListener,
  AfterLoad = AfterLoad,
  AfterSave = AfterSave,
  MpSyncable = MpSyncable,
  BzInit = BzInit,
  BzDestroy = BzDestroy,
  BzRemove = BzRemove,
  BzAlive = BzAlive,
  getHash = getHash,
  Pointer = Pointer,
  odfHeader = odfHeader,
  odfFile = odfFile,
  TableManager = tableRefs,
  BzModule = BzModule,
  str2vec = str2vec,
  local2Global = local2Global,
  global2Local = global2Local,
  DefaultRuntimeModule = DefaultRuntimeModule,
  getAmmoCost = getAmmoCost,
  spawnInFormation = spawnInFormation,
  spawnInFormation2 = spawnInFormation2,
  Timer = Timer
}