local bzCore = require("bz_core");
local misc = require("misc");
local OOP = require("oop");

local Class = OOP.Class;
local D = OOP.Decorate;
local Meta = OOP.Meta;
local getClassRef = OOP.getClassRef;
local getClass = OOP.getClass;
local copyTable = OOP.copyTable;
local assignObject = OOP.assignObject;
local isIn = OOP.isIn;
local SetLabel = SetLabel;
local Implements = OOP.Implements;
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


local AfterLoad = misc.AfterLoad;
local AfterSave = misc.AfterSave;

local BzModule = misc.BzModule;

if ((not SetLabel) and SettLabel) then
  SetLabel = SettLabel;
end

--Wrapper for handle
local Handle = Class("Handle", {
  constructor = function(handle)
    self.handle = handle;
  end,
  methods = {
    getHandle = function()
      return self.handle;
    end,
    removeObject = function()
      RemoveObject(self:getHandle());
    end,
    getOdf = function()
      return GetOdf(self:getHandle());
    end,
    isOdf = function(...)
      return IsOdf(self:getHandle(), ...);
    end,
    getBase = function()
      return GetBase(self:getHandle());
    end,
    getLabel = function()
      return GetLabel(self:getHandle());
    end,
    setLabel = function(label)
      SetLabel(self:getHandle(), label);
    end,
    getClassSig = function()
      return GetClassSig(self:getHandle());
    end,
    getClassLabel = function()
      return GetClassLabel(self:getHandle());
    end,
    getClassId = function()
      return GetClassId(self:getHandle());
    end,
    getNation = function()
      return GetNation(self:getHandle());
    end,
    isValid = function()
      return IsValid(self:getHandle());
    end,
    isAlive = function()
      return IsAlive(self:getHandle());
    end,
    isAliveAndPilot = function()
      return IsAliveAndPilot(self:getHandle());
    end,
    isCraf = function()
      return IsCraft(self:getHandle());
    end,
    isBuilding = function()
      return IsBuilding(self:getHandle());
    end,
    isPerson = function()
      return IsPerson(self:getHandle());
    end,
    isDamaged = function(threshold)
      return IsDamaged(self:getHandle(), threshold);
    end,
    getTeamNum = function()
      return GetTeamNum(self:getHandle());
    end,
    getTeam = function()
      return self:getTeamNum();
    end,
    setTeamNum = function(...)
      SetTeamNum(self:getHandle(), ...);
    end,
    setTeam = function(...)
      self:setTeamNum(...);
    end,
    getPerceivedTeam = function()
      return GetPerceivedTeam(self:getHandle());
    end,
    setPerceivedTeam = function(...)
      SetPerceivedTeam(self:getHandle(), ...);
    end,
    setTarget = function(...)
      SetTarget(self:getHandle(), ...);
    end,
    getTarget = function()
      return GetTarget(self:getHandle());
    end,
    setOwner = function(...)
      SetOwner(self:getHandle(), ...);
    end,
    getOwner = function()
      return GetOwner(self:getHandle());
    end,
    setPilotClass = function(...)
      SetPilotClass(self:getHandle(), ...);
    end,
    getPilotClass = function()
      return GetPilotClass(self:getHandle());
    end,
    setPosition = function(...)
      SetPosition(self:getHandle(), ...);
    end,
    getPosition = function()
      return GetPosition(self:getHandle());
    end,
    getFront = function()
      return GetFront(self:getHandle());
    end,
    setTransform = function(...)
      SetTransform(self:getHandle());
    end,
    getTransform = function()
      return GetTransform(self:getHandle());
    end,
    getVelocity = function()
      return GetVelocity(self:getHandle());
    end,
    setVelocity = function(...)
      SetVelocity(self:getHandle(), ...);
    end,
    getOmega = function()
      return GetOmega(self:getHandle());
    end,
    SetOmega = function(...)
      SetOmega(self:getHandle(), ...);
    end,
    getWhoShotMe = function(...)
      return GetWhoShotMe(self:getHandle(), ...);
    end,
    getLastEnemyShot = function()
      return GetLastEnemyShot(self:getHandle());
    end,
    getLastFriendShot = function()
      return GetLastFriendShot(self:getHandle());
    end,
    isAlly = function(...)
      return IsAlly(self:getHandle(), ...);
    end,
    setObjectiveOn = function()
      SetObjectiveOn(self:getHandle());
    end,
    setObjectiveOff = function()
      SetObjectiveOff(self:getHandle());
    end,
    setObjectiveName = function(...)
      SetObjectiveName(self:getHandle(), ...);
    end,
    getObjectiveName = function()
      return GetObjectiveName(self:getHandle());
    end,
    getDistance = function(...)
      return GetDistance(self:getHandle(), ...);
    end,
    isWithin = function(...)
      return IsWithin(self:getHandle(), ...);
    end,
    getNearestObject = function()
      return GetNearestObject(self:getHandle());
    end,
    getNearestVehicle = function()
      return GetNearestVehicle(self:getHandle());
    end,
    getNearestBuilding = function()
      return GetNearestBuilding(self:getHandle());
    end,
    getNearestEnemy = function()
      return GetNearestEnemy(self:getHandle());
    end,
    getNearestFriend = function()
      return GetNearestFriend(self:getHandle());
    end,
    countUnitsNearObject = function(...)
      return CountUnitsNearObject(self:getHandle(), ...);
    end,
    isDeployed = function()
      return IsDeployed(self:getHandle());
    end,
    deploy = function()
      Deploy(self:getHandle());
    end,
    isSelected = function()
      return IsSelected(self:getHandle());
    end,
    isCritical = function()
      return IsCritical(self:getHandle());
    end,
    setCritical = function(...)
      SetCritical(self:getHandle(), ...);
    end,
    setWeaponMask = function(...)
      SetWeaponMask(self:getHandle(), ...);
    end,
    giveWeapon = function(...)
      GiveWeapon(self:getHandle(), ...);
    end,
    getWeaponClass = function(...)
      return GetWeaponClass(self:getHandle(), ...);
    end,
    fireAt = function(...)
      FireAt(self:getHandle(), ...);
    end,
    damage = function(...)
      Damage(self:getHandle(), ...);
    end,
    canCommand = function()
      return CanCommand(self:getHandle());
    end,
    canBuild = function()
      return CanBuild(self:getHandle());
    end,
    isBusy = function()
      return IsBusy(self:getHandle());
    end,
    getCurrentCommand = function()
      return GetCurrentCommand(self:getHandle());
    end,
    getCurrentWho = function()
      return GetCurrentWho(self:getHandle());
    end,
    getIndependence = function()
      return GetIndependence(self:getHandle());
    end,
    setIndependence = function(...)
      SetIndependence(self:getHandle(), ...);
    end,
    setCommand = function(...)
      SetCommand(self:getHandle(), ...);
    end,
    attack = function(...)
      Attack(self:getHandle(), ...);
    end,
    goto = function(...)
      Goto(self:getHandle(), ...);
    end,
    mine = function(...)
      Mine(self:getHandle(), ...);
    end,
    follow = function(...)
      Follow(self:getHandle(), ...);
    end,
    defend = function(...)
      Defend(self:getHandle(), ...);
    end,
    defend2 = function(...)
      Defend2(self:getHandle(), ...);
    end,
    stop = function(...)
      Stop(self:getHandle(), ...);
    end,
    patrol = function(...)
      Patrol(self:getHandle(), ...);
    end,
    retreat = function(...)
      Retreat(self:getHandle(), ...);
    end,
    getIn = function(...)
      GetIn(self:getHandle(), ...);
    end,
    pickup = function(...)
      Pickup(self:getHandle(), ...);
    end,
    dropoff = function(...)
      Dropoff(self:getHandle(), ...);
    end,
    build = function(...)
      Build(self:getHandle(), ...);
    end,
    buildAt = function(...)
      BuildAt(self:getHandle(), ...);
    end,
    hasCargo = function()
      return HasCargo(self:getHandle());
    end,
    getTug = function()
      return GetTug(self:getHandle());
    end,
    ejectPilot = function()
      EjectPilot(self:getHandle());
    end,
    hopOut = function()
      HopOut(self:getHandle());
    end,
    killPilot = function()
      KillPilot(self:getHandle());
    end,
    removePilot = function()
      RemovePilot(self:getHandle());
    end,
    hoppedOutOf = function()
      HoppedOutOf(self:getHandle());
    end,
    getHealth = function()
      return GetHealth(self:getHandle());
    end,
    getCurHealth = function()
      return GetCurHealth(self:getHandle());
    end,
    getMaxHealth = function()
      return GetMaxHealth(self:getHandle());
    end,
    setCurHealth = function(...)
      SetCurHealth(self:getHandle(), ...);
    end,
    setMaxHealth = function(...)
      SetMaxHealth(self:getHandle(), ...);
    end,
    addHealth = function(...)
      AddHealth(self:getHandle(), ...);
    end,
    getAmmo = function()
      return GetAmmo(self:getHandle());
    end,
    getCurAmmo = function()
      return GetCurAmmo(self:getHandle());
    end,
    getMaxAmmo = function()
      return GetMaxAmmo(self:getHandle());
    end,
    setCurAmmo = function(...)
      SetCurAmmo(self:getHandle(), ...);
    end,
    setMaxAmmo = function(...)
      SetMaxAmmo(self:getHandle(), ...);
    end,
    addAmmo = function(...)
      AddAmmo(self:getHandle());
    end,
    _setLocal = function(...)
      --Should have some security check
      SetLocal(self:getHandle(), ...);
    end,
    isLocal = function()
      return IsLocal(self:getHandle());
    end,
    isRemote = function()
      return IsRemote(self:getHandle());
    end,
    isUnique = function()
      return self:isLocal() and (self:isRemote());
    end,
    setHealth = function(fraction)
      self:setCurHealth(self:getMaxHealth() * fraction);
    end,
    setAmmo = function(fraction)
      self:setCurAmmo(self:getMaxAmmo() * fraction);
    end,
    getCommand = function()
      return AiCommand[self:getCurrentCommand()];
    end,
    getOdfFile = function()
      local file = self.odfFile;
      if (not file) then
        file = odfFile:new(self:getOdf());
        self.odfFile = file;
      end
      return file;
    end,
    getProperty = function(section, var, ...)
      return self:getOdfFile():getProperty(section, var, ...); -- [section][var];
    end,
    getFloat = function(section, var, ...)
      return self:getOdfFile():getFloat(section, var, ...); --[section]:getAsFloat(var);
    end,
    getBool = function(section, var, ...)
      return self:getOdfFile():getBool(section, var, ...); --[section]:getAsBool(var);
    end,
    getInt = function(section, var, ...)
      return self:getOdfFile():getInt(section, var, ...); --[section]:getAsInt(var);
    end,
    getTable = function(...)
      return self:getOdfFile():getTable(...);
    end,
    getVector = function(...)
      return self:getOdfFile():getVector(...);
    end
  }
});

local function GameObject(data)
  return function(class)
    Meta(class, {GameObject = assignObject({
      odfs = {},
      classLabels = {},
      customClass = nil
    }, data)});
    D(Implements(Serializable, Updateable, BzInit), class);
  end
end



local ObjectManager = D(BzModule("ObjectManagerModule"),
  Class("Obj.ObjectManager", {
    constructor = function()
      self.all = {};
      self.afterSaveListeners = {};
      self.afterLoadListeners = {};
      self.netListeners = {};
      self.objectListeners = {};
      self.playerListeners = {};
      self.commandListeners = {};
      self.keyListeners = {};
      self.startListeners = {};
      self.classes = {};
      self.objsToBeDecided = {};
    end,
    methods = {
      update = function(...)
        for i, v in pairs(self.objsToBeDecided) do
          --Test if remote, a bit temp
          if(not (IsNetGame() and IsRemote(i)) ) then
            for i, v in pairs(self:registerHandle(i)) do
              v:onInit();
            end
          end
        end
        self.objsToBeDecided = {};
        for i, v in pairs(self.all) do
          --Create new method for 'meta' tracking
          self:updateMeta(i, v);
          for i2, v2 in pairs(v) do
            v2:update(...);
          end
        end
      end,
      updateMeta = function(handle, objs)
        if ((not Meta(handle).dead) and GetCurHealth(handle) < -1) then
          Meta(handle, {dead = true});
          for i, v in pairs(objs) do
            if (BzDestroy:made(v)) then
              v:onDestroy();
            end
          end
        end
        if ((Meta(handle).truelocal) and ((not IsLocal(handle)) and (IsRemote(handle)))) then
          --Object has been moved to another machine!
          --Do sync
          Meta(handle, {truelocal = false});
          local objdata = {};
          for i2, v2 in pairs(objs) do
            if (MpSyncable:made(v2)) then
              v2:onMachineChange();
              objdata[getClassRef(v2)] = {v2:mpSyncSend()};
              self:unregisterHandle(handle);
            end
          end
          --Find out what player got the new object?
          --Create a new system for async sending of data
          Send(0,"O","mov",{h=handle,i=objdata});

        end
      end,
      onStart = function(...)
        for v in AllObjects() do
          self:onAddObject(v);
        end
        for i, v in pairs(self.startListeners) do
          for i2, v2 in pairs(v) do
            v2:onStart(...);
          end
        end
      end,
      save = function()
        local objdata = {};
        for i, v in pairs(self.all) do
          objdata[i] = {};
          for i2, v2 in pairs(v) do
            objdata[i][getClassRef(v2)] = {v2:save()};
          end
        end
        return {objects = objdata};
      end,
      load = function(saveData)
        local objdata = saveData.objects;
        --Use register handle?
        for h, v in pairs(objdata) do
          for i2, v2 in pairs(v) do
            local c = getClass(i2);
            local i = c:new(h);
            i:load(unpack(v2));
            self:registerObject(h, i);
          end
        end
      end,
      afterSave = function()
        for i, v in pairs(self.afterSaveListeners) do
          for i2, v2 in pairs(v) do
            v2:afterSave();
          end
        end
      end,
      afterLoad = function()
        for i, v in pairs(self.afterLoadListeners) do
          for i2, v2 in pairs(v) do
            v2:afterLoad();
          end
        end
      end,
      onGameKey = function(...)
        for i, v in pairs(self.keyListeners) do
          for i2, v2 in pairs(v) do
            v2:onGameKey(...);
          end
        end
      end,
      onCommand = function(...)
        for i, v in pairs(self.commandListeners) do
          for i2, v2 in pairs(v) do
            v2:onCommand(...);
          end
        end
      end,
      onAddPlayer = function(...)
        for i, v in pairs(self.playerListeners) do
          for i2, v2 in pairs(v) do
            v2:onAddPlayer(...);
          end
        end
      end,
      onDeletePlayer = function(...)
        for i, v in pairs(self.playerListeners) do
          for i2, v2 in pairs(v) do
            v2:onDeletePlayer(...);
          end
        end
      end,
      onCreatePlayer = function(...)
        for i, v in pairs(self.playerListeners) do
          for i2, v2 in pairs(v) do
            v2:onCreatePlayer(...);
          end
        end
      end,
      onCreateObject = function(handle, ...)
        for i, v in pairs(self.objectListeners) do
          for i2, v2 in pairs(v) do
            v2:onCreateObject(handle, ...);
          end
        end
        self.objsToBeDecided[handle] = true;
      end,
      onAddObject = function(handle, ...)
        self.objsToBeDecided[handle] = nil;
        for i, v in pairs(self.objectListeners) do
          for i2, v2 in pairs(v) do
            v2:onAddObject(handle, ...);
          end
        end
        for i, v in pairs(self:registerHandle(handle)) do
          v:onInit();
        end
      end,
      registerHandle = function(handle)
        local objs = {};
        local odf = GetOdf(handle);
        local classLabel = GetClassLabel(handle);
        local customClasses = Handle(handle):getTable("GameObjectClass", "customClass");

        Meta(handle, {
          dead = false,
          truelocal = not (IsNetGame() and IsRemote(handle));
        });
        for i, v in pairs(self.classes) do
          local objectMeta = Meta(v).GameObject;
          
          local m = isIn(odf, objectMeta.odfs or {})
            or isIn(classLabel, objectMeta.classLabels or {})
            or isIn(objectMeta.customClass, customClasses or {});
          
          if (m) then
            local obj = v:new(handle);
            table.insert(objs, obj);
            self:registerObject(handle, obj);
          end
        end
        return objs;
      end,
      unregisterHandle = function(handle)
        if (self.all[handle]) then
          for i, v in pairs(self.all[handle]) do
            if (BzRemove:made(v)) then
              v:onRemove();
            end
          end
        end
        self.all[handle] = nil;
        self.afterSaveListeners[handle] = nil;
        self.afterLoadListeners[handle] = nil;
        self.netListeners[handle] = nil;
        self.objectListeners[handle] = nil;
        self.playerListeners[handle] = nil;
        self.commandListeners[handle] = nil;
        self.keyListeners[handle] = nil;
        self.startListeners[handle] = nil;
      end,
      onDeleteObject = function(handle, ...)
        self:unregisterHandle(handle);
        for i, v in pairs(self.objectListeners) do
          for i2, v2 in pairs(v) do
            v2:onDeleteObject(handle, ...);
          end
        end
      end,
      onReceive = function(id,type,ns,data)
        if(type=="O" and ns=="mov") then
          if(not IsRemote(data.h) and IsLocal(data.h) ) then
            local objs = self:registerHandle(data.h);
            for i, v in pairs(objs) do
              if MpSyncable:made(v) then
                for i2, v2 in pairs(data.i) do
                  if(i2 == getClassRef(v)) then
                    v:mpSyncReceive(unpack(v2));
                  end
                end
              else
                v:onInit();
              end
            end
          end
        end
        for i, v in pairs(self.netListeners) do
          for i2, v2 in pairs(v) do
            v2:onReceive(id,type,ns,data);
          end
        end
      end,
      registerObject = function(handle, obj)
        self.all[handle] = self.all[handle] or {};
        table.insert(self.all[handle], obj);
        if (NetworkListener:made(obj)) then
          self.netListeners[handle] = self.netListeners[handle] or {};
          table.insert(self.netListeners[handle], obj);
        end
        if (PlayerListener:made(obj)) then
          self.playerListeners[handle] = self.playerListeners[handle] or {};
          table.insert(self.playerListeners[handle], obj);
        end
        if (CommandListener:made(obj)) then
          self.commandListeners[handle] = self.commandListeners[handle] or {};
          table.insert(self.commandListeners[handle], obj);
        end
        if (ObjectListener:made(obj)) then
          self.objectListeners[handle] = self.objectListeners[handle] or {};
          table.insert(self.objectListeners[handle], obj);
        end
        if (KeyListener:made(obj)) then
          print("KeyListener made", obj);
          self.keyListeners[handle] = self.keyListeners[handle] or {};
          table.insert(self.keyListeners[handle], obj);
        end
        if (StartListener:made(obj)) then
          self.startListeners[handle] = self.startListeners[handle] or {};
          table.insert(self.startListeners[handle], obj);
        end
        if (AfterLoad:made(obj)) then
          self.afterLoadListeners[handle] = self.afterLoadListeners[handle] or {};
          table.insert(self.afterLoadListeners[handle], obj);
        end
        if (AfterSave:made(obj)) then
          self.afterSaveListeners[handle] = self.afterSaveListeners[handle] or {};
          table.insert(self.afterSaveListeners[handle], obj);
        end
      end,
      declearClass = function(obj)
        print("Declearing class",Meta(obj).name);
        table.insert(self.classes, obj);
      end
    }
  })
);
local objectManager = bzCore:addModule(ObjectManager);
--objectManager:declearClass(tank);
return {
  Handle = Handle,
  objectManager = objectManager,
  GameObject = GameObject
}
