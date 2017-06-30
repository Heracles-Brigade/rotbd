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
local _GetWeaponClass = GetWeaponClass;
GetWeaponClass  = function(...)
  local r = _GetWeaponClass(...);
  if(r) then
    return r:gmatch("[^%c]+")();
  end
  return r;
end

GetPathPointCount = GetPathPointCount or function(path)
  local p = GetPosition(path, 0)
  local lp = SetVector(0, 0, 0)
  local c = 0
  while p ~= lp do
    lp = p
    c = c + 1
    p = GetPosition(path, c)
  end
  return c
end
GetPathPoints = function(path)
  local _accum_0 = { }
  local _len_0 = 1
  for i = 0, GetPathPointCount(path)-1 do
    _accum_0[_len_0] = GetPosition(path, i)
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
GetPathLength = function(path,loop,max)
  loop = loop or false;
  if(max) then
    max = max - 1;
  else
    max = math.huge;
  end
  local dist = 0;
  local pps = GetPathPoints(path);
  local l = math.min(max,loop and #pps or (#pps-1));
  for i3=1, l do
    dist = dist + Length(pps[i3]-pps[(i3)%(#pps)+1]);
  end
  return dist;
end
GetCenterOfPolygon = function(vertecies)
  local center = SetVector(0, 0, 0)
  local signedArea = 0
  local a = 0
  for i, v in ipairs(vertecies) do
    local v2 = vertecies[i % #vertecies + 1]
    a = v.x * v2.z - v2.x * v.z
    signedArea = signedArea + a
    center = center + (SetVector(v.x + v2.x, 0, v.z + v2.z) * a)
  end
  signedArea = signedArea / 2
  center = center / (6 * signedArea)
  return center
end

GetRadiusOfPolygon = function(...)
  local pp = GetPathPoints(...);
  local center = GetCenterOfPolygon(pp);
  local radius = 0;
  for i,v in ipairs(pp) do
    radius = math.max(radius,Length(v-center));
  end
  return radius;
end

GetCenterOfPath = function(path)
  return GetCenterOfPolygon(GetPathPoints(path));
end

GetRadiusOfPath = function(...)
  return GetRadiusOfPolygon(...);
end


DoBoundingBoxesIntersect = function(p1,p2,p3,p4)
  local x1 = math.min(p1.x,p2.x);
  local x2 = math.max(p1.x,p2.x);
  local x3 = math.min(p3.x,p4.x);
  local x4 = math.max(p3.x,p4.x);

  local y1 = math.min(p1.z,p2.z);
  local y2 = math.max(p1.z,p2.z);
  local y3 = math.min(p3.z,p4.z);
  local y4 = math.max(p3.z,p4.z);
  


  return (
    x1 <= x4 and
    x2 >= x3 and
    y1 <= y4 and
    y2 >= y3
  );
end
IsInsideArea = IsInsideArea or function()
  return false;
end 
IsPointOnLine = function(a1,a2,b)
  local aTmp = a2-a1;
  local bTmp = b-a1;
  local r = CrossProduct(aTmp, bTmp).y;
  return math.abs(r) < 0.05;
end


IsPointRightOfLine = function(a1,a2,b)
  local aTmp = a2-a1;
  local bTmp = b-a1;
  return CrossProduct(aTmp, bTmp).y < 0;
end

LineSegmentTouchesOrCrossesLine = function(p1,p2,p3,p4)
  return (
    IsPointOnLine(p1,p2,p3) or
    IsPointOnLine(p1,p2,p4) or (
      IsPointRightOfLine(p1,p2,p3) ==
      not(IsPointRightOfLine(p1,p2,p4))
    )
  );
end

DoLinesIntersect = function(p1,p3,vec1,vec2)
  p1.y = 0;
  p3.y = 0;
  vec1.y = 0;
  vec2.y = 0;
  local p2 = p1 + vec1;
  local p4 = p3 + vec2;
  return (
    DoBoundingBoxesIntersect(p1,p2,p3,p4) and
    LineSegmentTouchesOrCrossesLine(p1,p2,p3,p4) and
    LineSegmentTouchesOrCrossesLine(p3,p4,p1,p2)
  );
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
  --return SetVector(0,0,0);
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
      return ret, c > 1;
    end
  }
})
local odfFile;
odfFile = Class("odfFile",{
  constructor = function(fileName)
    self.name = fileName;
    self.file = OpenODF(fileName);
    self.headers = {};
    assert(self.file,"Could not open \"%s\"!",self.name);
    local parent, exists = self:getProperty("Meta","parent");
    if(exists) then
      self.parent = odfFile(parent);
    end
  end,
  methods = {
    getHeader = function(headerName)
      if(headerName == nil) then
        error("Header was nil!");
      end
      if(not self.headers[headerName]) then
        self.headers[headerName] = odfHeader(self.file,headerName);
      end
      return self.headers[headerName];
    end,
    getInt = function(header,...)
      local v, found = self:getHeader(header):getAsInt(...);
      if self.parent and (not found) then
        v, found = self.parent:getInt(header,...);
      end
      return v, found;
    end,
    getFloat = function(header,...)
      local v, found = self:getHeader(header):getAsFloat(...);
      if self.parent and (not found) then
        v, found = self.parent:getFloat(header,...);
      end
      return v, found;
    end,
    getProperty = function(header,...)
      local v, found = self:getHeader(header):getVar(...);
      if self.parent and (not found) then
        v, found = self.parent:getProperty(header,...);
      end
      return v, found;
    end,
    getBool = function(header,...)
      local v, found = self:getHeader(header):getAsBool(...);
      if self.parent and (not found) then
        v, found = self.parent:getBool(header,...);
      end
      return v, found;
    end,
    getTable = function(header,...)
      local v, found = self:getHeader(header):getAsTable(...);
      if self.parent and (not found) then
        v, found = self.parent:getTable(header,...);
      end
      return v, found;
    end,
    getVector = function(header,...)
      local v, found = self:getHeader(header):getAsVector(...);
      if self.parent and (not found) then
        v, found = self.parent:getVector(header,...);
      end
      return v, found;
    end
  }
})

local function createFormation(formation,location,dir,seperation,height)
  if(seperation == nil) then 
    seperation = 10;
  end
  if(height == nil) then
    height = 0;
  end
  local positions = {};
  local directionVec = Normalize(SetVector(dir.x,0,dir.z));
  local formationAlign = Normalize(SetVector(-dir.z,0,dir.x));
  for i2, v2 in ipairs(formation) do
    local length = v2:len();
    local i3 = 1;
    for c in v2:gmatch(".") do
      local n = c;
      if(n) then
        local x = (i3-(length/2))*seperation;
        local z = i2*seperation*2;
        local pos = x*formationAlign + -z*directionVec + location;
        local fh = GetTerrainHeightAndNormal(pos);
        pos.y = math.max(pos.y,fh+height);
        local t = BuildDirectionalMatrix(pos,directionVec);
        positions[n] = t;
      end
      i3 = i3+1;
    end
  end
  return positions;
end

local function createFormation2(formation,location,seperation,height)
  return createFormation(formation,GetPosition(location,0),GetPosition(location,1) - GetPosition(location,0),seperation,height);
end

local function moveAllInFormation(handles,...)
  local transforms = createFormation2(...);
  for i,v in pairs(handles) do
    local t = transforms[i];
    local f = odfFile(GetOdf(v));
    local height = f:getFloat("HoverCraftClass","setAltitude");
    t.posit_y = t.posit_y + height;
    if(t) then
      SetTransform(v,t);
    end
  end
  
end

local function moveInFormation(handle,key,...)
  moveAllInFormation({[key] = handle},...);
end





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
        local fh = GetTerrainHeightAndNormal(pos);
        pos.y = math.max(pos.y,fh);
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
      self.map = {};
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
        local key = obj;
        local obj = obj;
        if(type(obj) == "table") then
          key = self.map[obj];
        else
          obj = self.all[key];
        end
        self.map[obj] = nil;
        self.all[key] = nil;
      end,
      registerInstance = function(obj,key)
        self.map[obj] = key;
        self.all[key] = obj;
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
      start = function()
        self.running = true;
      end,
      setTime = function(t)
        self.time = t;
      end,
      restart = function()
        self:stop();
        self:start();
      end,
      stop = function()
        self:pause();
        self:setTime(0);
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
  Timer = Timer,
  createFormation = createFormation,
  createFormation2 = createFormation2,
  moveInFormation = moveInFormation,
  moveAllInFormation = moveAllInFormation
}