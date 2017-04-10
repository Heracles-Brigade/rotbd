local OOP = require("oop");
local misc = require("misc");
local bzAi = require("bz_ai");
local bzObjects = require("bz_objects");
local bzObjective = require("bz_objt");
local AiDecorator = bzAi.AiDecorator;
local rx = require("rx");
local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local Class = OOP.Class;
local assignObject = OOP.assignObject;

--Range that the soldiers will scan for targets
local soldierRange = 150;

local constructorAiStatic = {
  addFromPath = function(path,o_team,o_odf)
    local odf = o_odf or path:match("make_(%a+)");
    local team = o_team or path:match("make_%a+_(%d+)");
    local sub = rx.Subject.create();
    for i,v in pairs(GetPathPoints(path)) do
      class:addBuilding(v,team,odf):subscribe(function(handle)
        sub:onNext(handle);
      end);
    end
    return sub;
  end,
  addBuilding = function(location,team,odf)
    class.reg[team] = class.reg[team] or {};
    class.reg[team][location] = {
      odf = odf,
      handle = nil,
      subject = rx.Subject.create()
    };
    local dist = 200;
    local h = nil;
    for v in ObjectsInRange(100,location) do
      if(IsOdf(v,odf) and getTeamNum(v) == team) then
        local nl = GetDistance(v,location);
        if(nl < dist) then
          nl = dist;
          h = v;
        end
      end
    end
    if(dist < 10) then
      class.reg[team][location].handle = h;
    else
      class.jobPool[team] = class.jobPool[team] or {};
      class.jobPool[team][location] = {
        team = team,
        location = location,
        odf = odf
      }
    end
    return class.reg[team][location].subject;
  end,
  getJob = function(me)
    local dist = 100000;
    local job;
    local t = me:getTeamNum();
    class.reg[t] = class.reg[t] or {};
    class.jobPool[t] = class.jobPool[t] or {};
    for i,v in pairs(class.reg[t]) do
      if not (IsValid(v.handle) or IsValid(v.assigned)) then
        class.jobPool[t][i] = {
          team = t,
          location = i,
          odf = v.odf
        }
      end
    end
    local idx = nil;
    for i,v in pairs(class.jobPool[t]) do
      if(not IsValid(class.reg[t][i].assigned)) then
        local nl = me:getDistance(i);
        if(nl < dist) then
          dist = nl;
          job = class.jobPool[t][i];
          idx = i;
        end
      end
    end
    if(job) then
      class.jobPool[t][idx] = nil;
      class.reg[t][idx].assigned = me:getHandle(); 
      return job;
    end
  end,
  cancelJob = function(job)
    class.reg[job.team][job.location].assigned = nil;
    class.jobPool[job.team][job.location] = job;
  end,
  finishJob = function(job,handle)
    local obj = class.reg[job.team][job.location];
    obj.handle = handle;
    obj.assigned = nil;
    obj.subject:onNext(handle);
  end
}


local ProducerAi = Decorate(
  AiDecorator({
    name = "ProducerAi",
    aiNames = {"RecyclerFriend","MUFFriend"},
    playerTeam = false
  }),
  Class("ProducerAi",{
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.buildState = 0;
    end,
    methods = {
      update = function(dtime)
        if(self.handle:isDeployed()) then
          if(self.buildState == 1 and (not self.handle:isBusy())) then
            local cmatch = nil;
            local dist = 300;
            for v in ObjectsInRange(100,self.handle:getHandle()) do
              if(IsOdf(v,self.currentJob.odf)) then
                local nl = self.handle:getDistance(v);
                if(nl < dist) then
                  cmatch = v;
                end
              end
            end
            class:finishJob(self.currentJob,cmatch);
            self.buildState = 0;
            self.currentJob = nil;
          end
          if(self.buildState == 3 and self.handle:isBusy()) then
            self.buildState = 1;
          end
        elseif(self.currentJob) then
          class:cancelJob(self.currentJob);
          self.currentJob = nil;
          self.buildState = 0;
        end
        if(self.handle:canBuild() and not (self.handle:isBusy())) then
          self:takeJob();
        end
      end,
      takeJob = function()
        local job = class:getJob(self.handle);
        if(job) then
          self.currentJob = job;
          self.buildState = 3;
          self.handle:buildAt(job.odf,self.handle:getPosition());
        end
      end,
      onInit = function()
      end,
      onReset = function()
        self.handle:stop(1);
        if(self.currentJob) then
          class:cancelJob(self.currentJob);
          self.currentJob = nil;
        end
        self:onInit();
      end,
      save = function()
        return self.currentJob, self.buildState;
      end,
      load = function(...)
        self.currentJob, self.buildState = ...;
        if(self.createJob) then
          self.currentJob.subject = rx.Subject.create();
        end
      end
    },
    static = {
      createJob = function(odf,team,priority,location)
        class.jobQueue = class.jobQueue or {};
        priority = priority or class.nextId;
        class.jobQueue[team] = class.jobQueue[team] or {};
        class.jobQueue[team][location or "GLOBAL"] = class.jobQueue[team][location or "GLOBAL"] or {};
        local job = {
          odf=odf,
          team=team,
          location = location or "GLOBAL",
          priority = priority,
          id = class.nextId,
          subject = rx.Subject.create()
        };
        class.jobQueue[team][location or "GLOBAL"][class.nextId] = job;
        class.nextId = class.nextId + 1;
        return job.subject;
      end,
      createJobs = function(...)
        local sub = rx.Subject.create();
        for i, v in pairs(...) do
          for i2=1, v.count or 1 do
            class:createJob(v.odf,v.team,v.priority,v.location):subscribe(function(...)
              sub:onNext(...);
            end);
          end
        end
        return sub;
      end,
      getJob = function(me)
        local dist = 100000;
        local job;
        local t = me:getTeamNum();
        local filtered = {};
        for i, v in pairs(class.jobQueue[t]) do
          for i2, v2 in pairs(v) do
            if(me:canMake(v2.odf)) then
              local n = OOP.copyTable(v2);
              local nl = me:getDistance(i);
              if(i == "GLOBAL") then
                n.priority = n.priority + 500;
              else
                n.priority = n.priority + nl;
              end
              table.insert(filtered,n);
            end
          end
        end
        table.sort(filtered,function(a,b) return a.priority > b.priority end);
        local job = table.remove(filtered);
        if(job) then
          class.jobQueue[t][job.location][job.id] = nil;
        end
        return job;
      end,
      cancelJob = function(job)
        class.jobQueue[job.team][job.location][job.id] = job;
      end,
      finishJob = function(job,handle)
        if(job.subject.onNext) then
          job.subject:onNext(handle);
        end
      end,
      save = function()
        return class.jobQueue, class.nextId;
      end,
      load = function(...)
        class.jobQueue, class.nextId = ...;
      end
    }
  })
);

ProducerAi.nextId = 0;

local ConstructorAi = Decorate(
  AiDecorator({
    name = "ConstructorAi",
    aiNames = {"RigFriend"},
    playerTeam = false
  }),
  Class("ConstructorAi", {
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.buildState = 0;
    end,
    methods = {
      update = function(dtime)
        local cc = self.handle:getCurrentCommand();
        if(AiCommand["BUILD"] == cc) then
          if(self.buildState == 3 and self.handle:isDeployed()) then
            self.buildState = 1;
          end
        end
        if((self.buildState == 1) and (not self.handle:isDeployed()) ) then
          local cmatch = nil;
          local dist = 300;
          for v in ObjectsInRange(100,self.handle:getHandle()) do
            if(IsOdf(v,self.currentJob.odf)) then
              local nl = self.handle:getDistance(v);
              if(nl < dist) then
                cmatch = v;
              end
            end
          end
          class:finishJob(self.currentJob,cmatch);
          self.currentJob = nil;
          self.buildState = 0;
        end
        if(self.buildState == 0) then
          self:takeJob();
        end
      end,
      takeJob = function()
        local job = class:getJob(self.handle);
        if(job) then
          self.currentJob = job;
          self.buildState = 3;
          self.handle:buildAt(job.odf,job.location);
        elseif(self.handle:getCurrentCommand() ~= AiCommand["GO"]) then
          local t = self.handle:getTeamNum();
          local target = GetRecyclerHandle(t) or GetFactoryHandle(t) or GetArmoryHandle(t);
          if(not self.handle:isWithin(target,50)) then
            self.handle:goto(GetPositionNear(GetPosition(target),20,40));
          end
        end
      end,
      onInit = function()
      end,
      onReset = function()
        self.handle:stop(1);
        if(self.currentJob) then
          class:cancelJob(self.currentJob);
          self.currentJob = nil;
        end
        self:onInit();
      end,
      save = function()
        if(self.currentJob) then
          self.currentJob.subject = nil;
        end
        return self.currentJob, self.buildState;
      end,
      load = function(...)
        self.currentJob, self.buildState = ...;
        if(self.currentJob) then
          self.currentJob.subject = rx.Subject.create();
        end
      end
    },
    static = constructorAiStatic
  })
);

ConstructorAi.jobPool = {};
ConstructorAi.reg = {};

ProducerAi.jobPool = {};
ProducerAi.reg = {};

bzAi.aiManager:declearClass(ConstructorAi);
bzAi.aiManager:declearClass(ProducerAi);

return {
  ConstructorAi = ConstructorAi,
  ProducerAi = ProducerAi
};