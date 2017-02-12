--contains metadata
local metaObj = setmetatable({},{__mode="k"});
local classTable = {};
local classId = 0;

local _assert = _G["assert"];
_G["assert"] = function(c,m,l)
  if(not c) then
    error(m,(l~=nil and (l + 1)) or 2);
  end
end

local assignObject = function(obj,...)
  local other = {...};
  for i,v in pairs(other) do
    for i2,v2 in pairs(v) do
      obj[i2] = v2;
    end
  end
  return obj;
end


local copyTable = function(t)
  local ret = {};
  for i,v in pairs(t) do
    ret[i] = v;
  end
  return ret;
end

local isIn = function(a,inB) 
  for i,v in pairs(inB) do
    if(a == v) then
      return true;
    end
  end
  return false;
end

local newEnv = function(env)
  return setmetatable(copyTable(env),{__index = getfenv(2)});
end

local callenv = function(f,env,...)
  local ret = {(setfenv(f,newEnv(env)))(...)};
  setfenv(f,newEnv({}));
  return unpack(ret);
end

local function applyMeta(obj,metadata)
  metaObj[obj] = assignObject(metaObj[obj] or {},metadata);
  return obj;
end

local function getMeta(obj)
  assert(obj,"Can't get meta of nil'",4);
  return copyTable(metaObj[obj] or {});
end

local function Meta(obj,oMetadata)
  if(obj==nil) then return {}; end
  return oMetadata and applyMeta(obj,oMetadata) or getMeta(obj);
end

local function Decorate(...)
  local decorators = {...};
  local obj = decorators[#decorators];
  decorators[#decorators] = nil;
  for i,v in ipairs(decorators) do
    v(obj);
  end
  return obj;
end
--Decorator for implementing interfaces, throws errors on unimplemented
--methods


local function Implements(...)
  local interfaces = {...};
  local allInterfaces = {...};
  local methods = {};
  while #interfaces > 0 do
    local n = {}
    for i,v in pairs(interfaces) do
      for i2, method in pairs(v) do
        methods[method] = true;
      end
      if(Meta(v).superInterface) then
        table.insert(n,Meta(v).superInterface);
        table.insert(allInterfaces,Meta(v).superInterface);
      end
    end
    interfaces = n;
  end
  
  return function(class)
    assert(Meta(class).type == "CLASS","Argument passed was not a class",3);
    for i,v in pairs(methods) do
      local s = class;--Meta(s).super
      local gotMethod = false;
      while s and (not gotMethod) do
        gotMethod = s.__methods[i] and true or false;
        s = Meta(s).super;
      end
      assert(gotMethod, tostring(Meta(class).name) .. " is missing method " .. tostring(i),3);
    end
    local implements = Meta(class).implements or {};
    for i,v in pairs(allInterfaces) do
      implements[v] = true; 
    end
    Meta(class,{implements = implements});
  end

end

local interfaceMeta = {
  __index = {
    made = function(i,obj)
      local m = Meta(obj);
      if(m.type == "INSTANCE") then
        local c = Meta(m.class);
        if(c.implements and c.implements[i]) then
          return true;
        end
      end
      return false;
    end
  }
}

local createInterface = function(name,definition,superInterface)
  local interface = setmetatable(copyTable(definition),interfaceMeta);
  Meta(interface,{
    type = "INTERFACE",
    super = superInterface,
    name = name,
    ref = interface
  });
  return interface;
end


local function getClassRef(instance)
  return Meta(instance).classrf;
end

local function getClass(classrf)
  return classTable[classrf];
end

local mindex = function(t,k,_t)
  return type(t) == "table" and t[k] or t(_t,k);
end

local mnindex = function(t,k,v,_t)
  if(type(t) == "table") then 
    t[k] = v;
  else
    t(_t,k,v);
  end
end

local classMeta = {
  __index = function(t,k)
    if(Meta(t).classmethods[k]) then
      return Meta(t).classmethods[k];
    elseif(t.__static[k]) then
      return function(cls,...)
        return callenv(t.__static[k],{
          class = cls,
          cls = cls,
          super = Meta(cls).super
        },...);
      end
    elseif(Meta(t).super) then
      return Meta(t).super[k];
    end
  end,
  __call = function(t,...)
    return Meta(t).classmethods["new"](t,...);
  end
}

local instanceMeta = {
  __index = function(t,k)
    local m = Meta(t);
    local class = m.class;
    local i = class.__mt.__index;
    local si2 = Meta(t).superinstance;
    assert(class,"Instance has no class");
    local ret;
    if(class.__methods[k]) then
      ret = function(self,...)
        --super class
        local sc = Meta(class).super;
        --super instance
        local si = Meta(self).superinstance;
        local environment = {
          this = self,
          self = self,
          class = Meta(self).class,
          super = setmetatable({},{
            __index = function(t,k)
              if(sc[k]) then
                return function(dummy,...) 
                  return sc[k](sc,...);
                end
              end
              if(type(si[k])=="function") then
                return function(dummy,...)
                  return si[k](si,...);
                end
              end
            end
          });
        };
        if(not sc) then
          environment.super = nil;
        end
        return callenv(class.__methods[k],environment,...);
      end
    elseif(si2) then
      local m = si2[k];
      if(m and type(m) == "function") then
        ret = function(self,...) 
          local si = Meta(self).superinstance;
          return m(si,...);
        end
      end
    end
    if( (not ret) and i) then
      ret = mindex(i,k,t);
    end
    return ret;
  end
}

local function subclasscheck(super,subclass)
  return Meta(subclass).super == super or subclasscheck(super,Meta(subclass).super);
end

local classmethods = {
  getName = function(cls)
    return Meta(cls).name;
  end,
  made = function(cls,instance)
    assert(cls, "Missing class");
    assert(instance, "Missing instance");
    assert(Meta(cls).type == "CLASS", "Type of class is not \"CLASS\"!");
    assert(Meta(instance).type == "INSTANCE", "Type of instance is not \"INSTANCE\"!");
    return (Meta(instance).class == cls) or (subclasscheck(cls,Meta(instance).class));
  end,
  constructor = function(...)
    super(...);
    --DEFAULT CONSTRUCTOR
  end,
  new = function(cls,...)
    local instance = setmetatable({},instanceMeta);
    Meta(instance,{
      class = cls,
      type = "INSTANCE",
      classrf = Meta(cls).id .. "_" .. Meta(cls).name
    });
    --super class
    local sc = Meta(cls).super;
    local environment = {
      self = instance,
      this = instance,
      class = cls,
      cls = cls,
      super = setmetatable({},{
        __index = function(t,k)
          if(sc[k]) then
            return function(dummy,...) 
              return sc[k](sc,...);
            end
          end
          return function(dummy,...)
            local si = Meta(instance).superinstance;
            return si[k](si,...);
          end
        end,
        __call = function(dummy,...)
          Meta(instance,{
            superinstance = Meta(sc).classmethods["new"](sc,...)
          });
        end
      });
    };
    if(not sc) then
      environment.super = nil;
    end
    callenv(Meta(cls).classmethods.constructor,environment,...);
    return setmetatable(instance,assignObject({},cls.__mt,Meta(cls).mt));
  end
}



local createClass = function(name,definition,superClass)
  local cls = {
    __methods = {
      class = function(self)
        return Meta(self).class;
      end
    },
    __static = {},
    __mt = {}
  };
  local meta = {
    type = "CLASS",
    mt = copyTable(instanceMeta),
    super = superClass,
    name = name,
    id = classId,
    ref = cls,
    attachables = {},
    implements = copyTable(Meta(superClass).implements or {}),
    classmethods = copyTable(classmethods)
  };
  classId = classId+1;
  if(definition.constructor) then
    meta.classmethods.constructor = definition.constructor;
  end
  if(definition.static) then
    for i,v in pairs(definition.static) do
      assert(not meta.classmethods[i], "Illegal name for static method: " .. tostring(i));
      cls.__static[i] = v;
    end
  end
  if(definition.methods) then
    for i,v in pairs(definition.methods) do
      assert(not cls.__methods[i], "Duplicate method! " .. tostring(i) .. " is already defined");
      cls.__methods[i] = v;
    end
  end
  cls.__mt = assignObject({},definition.metatable);
  Meta(cls,meta);
  classTable[meta.id .. "_" .. meta.name] = cls;
  return setmetatable(cls,classMeta);
end

local Counter = createClass("Counter",{
  constructor = function(name)
    self.name = name;
    self.count = 0;
  end,
  static = {
    printShit = function(...)
      print(...);
    end
  },
  methods = {
    inc = function()
      self.count = self.count + 1;
    end,
    dec = function()
      self.count = self.count - 1;
    end,
    getCount = function()
      return self.count;
    end,
    setCount = function(count)
      self.count = count;
    end
  },
  metatable = {
    __tostring = function(self)
      return self.name .. ": " .. self.count;
    end
  }
});

--class test 1
local kills = Counter("Kills");
assert(Counter:made(kills),"Kills is not instance of Counter!")
assert(kills:getCount() == 0, "Wrong state!");
kills:inc();
assert(kills:getCount() == 1, "Wrong state!");
kills:inc();
assert(kills:getCount() == 2, "Wrong state!");
kills:dec();
assert(kills:getCount() == 1, "Wrong state!");
kills:inc();
kills:inc();
assert(kills:getCount() == 3, "Wrong state!");

local SpecialCounter = createClass("SpecialCounter",{
  methods = {
    addFive = function()
      super:setCount(super:getCount() + 5);
    end,
    inc = function()
      super:inc();
      super:inc();
    end
  }
},Counter);

local OtherCounter = createClass("OtherCounter",{
  methods = {
    inc = function()
      super:inc();
      super:inc();
    end
  }
},SpecialCounter);


local sp = OtherCounter("SpecialCounter instance");
assert(Counter:made(sp),"Sp is not instance of Counter!")
assert(sp:getCount() == 0, "Wrong state!");

sp:inc();
assert(sp:getCount() == 4, "Wrong state!");
sp:inc();
assert(sp:getCount() == 8, "Wrong state!");
sp:dec();
assert(sp:getCount() == 7, "Wrong state!");
sp:inc();
sp:inc();
assert(sp:getCount() == 7+8, "Wrong state!");
sp:addFive();
assert(sp:getCount() == (7+8+5), "Wrong state! " .. sp:getCount());


Counter = nil;

local OOP = {
  Class = createClass,
  Meta = Meta,
  copyTable = copyTable,
  Decorate = Decorate,
  assignObject = assignObject,
  Interface = createInterface,
  Implements = Implements,
  getClassRef = getClassRef,
  getClass = getClass,
  isIn = isIn
};


return OOP;