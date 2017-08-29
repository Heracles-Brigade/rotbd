local OOP = require("oop");
local misc = require("misc");
local bzAi = require("bz_ai");
local bzObjects = require("bz_objects");
local bzObjective = require("bz_objt");
local rx = require("rx");
local Decorate = OOP.Decorate;
local Implements = OOP.Implements;
local AiDecorator = bzAi.AiDecorator;
local Class = OOP.Class;
local assignObject = OOP.assignObject;
local odfFile = misc.odfFile;
local ProductionJob;
local JobBundle;

local isIn = OOP.isIn;

--Class for bundeling production jobs
JobBundle = Class("AI.JobBundle",{
  --Constructor takes a list of jobs as an argument
  constructor = function(...)
    self.jobs = {};
    self.left = 0;
    self.handles = {};
    self.subscriptions = {};
    self.jobsSet = false;
    self.finished = false;
    self:_setJobs(...);
  end,
  methods = {
    --private method for adding one job to the list
    _addJob = function(job)
      --increase self.left with one
      self.left = self.left + 1;
      self.jobs[job:getId()] = job;
      --Subscribe to the 'finish' oberver, we want to know when the job is dune
      self.subscriptions[job:getId()] = job:onFinish():subscribe(function(job,handle)
        --when job is done and an object has been made remove one from self.left
        self.left = self.left - 1;
        --Insert the handle of the object into self.handles
        table.insert(self.handles,handle);
        --if there are someone that are subscribed to 'forEach', let them know a unit has been made
        if(self.fsubject) then
          self.fsubject:onNext(job,handle);
        end
        --if there are no jobes left in the bundle
        if(self.left <= 0) then
          --set finished to true
          self.finished = true;
          --if there are someone that are subscribed to 'finish' tell them that all the jobs have been done
          --and give them a list of all the handles produced by the jobs in this bundle
          if(self.subject) then
            self.subject:onNext(self,self.handles);
            self.subject:onCompleted();
          end
          if(self.fsubject) then
            self.fsubject:onCompleted();
          end
        end
      end);
    end,
    --really 'addJobs', takes a list of jobs and adds them to the bundle
    --should only be done shortly after it was made
    _setJobs = function(...)
      self.jobsSet = true;
      for i,v in pairs({...}) do
        self:_addJob(v);
      end
    end,
    --returns an observable that resolves when all the jobs finish
    onFinish = function()
      if(not self.subject) then
        self.subject = rx.AsyncSubject.create();
      end
      return self.subject;
    end,
    --returns an observable that resolves for each job that is finished
    forEach = function()
      if(not self.fsubject) then
        self.fsubject = rx.Subject.create();
      end
      return self.fsubject;
    end,
    --return the jobs in this bundle
    getJobs = function()
      return self.jobs;
    end,
    --return an unique identifier for this bundle
    getId = function()
      if(self.UUID == nil) then
        self.UUID = class:nextId();
      end
      return self.UUID;
    end,
    save = function()
      local jobs = {};
      for i,v in pairs(self.jobs) do
        if(not v:isFinished()) then
          table.insert(jobs,i);
        end
      end
      return {
        left = self.left,
        UUID = self:getId(),
        jobs = jobs,
        handles = self.handles,
        finished = self.finished
      }
    end,
    isFinished = function()
      return self.finished;
    end,
    load = function(savedata,jobProvider)
      self.UUID = savedata.UUID;
      self.left = savedata.left;
      self.handles = savedata.handles;
      self.finished = savedata.finished;
      for i,v in pairs(savedata.jobs) do
        self:_addJob(jobProvider:getJob(v));
      end
    end
  },
  static = {
    nextId = function()
      class.nid = class.nid + 1;
      return class.nid;
    end,
    save = function()
      return class.nid;
    end,
    load = function(...)
      class.nid = ...;
    end,
    fromSave = function(saveData,jobProvider)
      local job = JobBundle();
      job:load(saveData,jobProvider);
      return job;
    end
  }
});
JobBundle.nid = 0;

ProductionJob = Class("AI.ProductionJob",{
  constructor = function(odf,team,location,priority)
    self.odf = odf;
    self.team = (team~=nil and team) or GetTeamNum(GetPlayerHandle());
    self.location = location or "GLOBAL";
    self.priority = priority;
    self.assigned = false;
    self.assignee = nil;
    self.finished = false;
  end,
  methods = {
    getId = function()
      if(self.UUID == nil) then
        self.UUID = class:nextId();
      end
      return self.UUID;
    end,
    getOdf = function()
      return self.odf;
    end,
    getTeam = function()
      return self.team;
    end,
    onFinish = function()
      if(not self.subject) then
        self.subject = rx.AsyncSubject.create();
      end
      return self.subject;
    end,
    finish = function(handle)
      self.finished = true;
      if(self.subject) then
        self.subject:onNext(self,handle);
        self.subject:onCompleted();
      end
    end,
    isFinished = function()
      return self.finished;
    end,
    getCost = function()
      local c = odfFile(self.odf):getInt("GameObjectClass","scrapCost");
      return c;
    end,
    getAssignee = function()
      return self.assignee;
    end,
    isAssigned = function()
      return self.assigned;
    end,
    getPriority = function()
      if(self.priority ~= nil) then
        return self.priority;
      end
      return self:getId();
    end,
    getLocation = function()
      return self.location;
    end,
    assignTo = function(who)
      self.assigned = true;
      self.assignee = who;
    end,
    unAssign = function()
      self.assigned = false;
      self.assignee = nil;
    end,
    save = function()
      return {
        odf = self.odf,
        team = self.team,
        location = self.location,
        priority = self.priority,
        assignee = self.assignee,
        assigned = self.assigned,
        UUID = self:getId(),
        finished = self.finished
      };
    end,
    load = function(data)
      assignObject(self,data);
    end
  },
  static = {
    compare = function(a,b)
      return a:getPriority() < b:getPriority();
    end,
    nextId = function()
      class.nid = class.nid + 1;
      return class.nid;
    end,
    save = function()
      return class.nid;
    end,
    load = function(...)
      class.nid = ...;
    end,
    fromSave = function(saveData)
      local job = ProductionJob();
      job:load(saveData);
      return job;
    end,
    createMultiple = function(count,...)
      local jobs = {};
      for i=1, count do
        table.insert(jobs,ProductionJob(...));
      end
      return unpack(jobs);
    end
  }
});

ProductionJob.nid = 0;


local ProducerAi = Decorate(
  AiDecorator({
    name = "ProducerAi",
    aiNames = {"RecyclerFriend","MUFFriend","RigFriend","SLFFriend"},
    playerTeam = false
  }),
  Class("ProducerAi",{
    constructor = function(handle)
      self.handle = bzObjects.Handle(handle);
      self.currentJob = nil;
      self.buildState = 0;
      self.wait = 10;
      self.last_command = self.handle:getCurrentCommand();
    end,
    methods = {
      update = function(dtime)
        self.wait = self.wait - 1;
        local nc = self.handle:getCurrentCommand();
        if(nc ~= self.last_command) then
          if((not isIn(AiCommand[nc],{"DROPOFF","NONE","BUILD"})) and self.buildState ~= 0) then
            self.currentJob:unAssign();
            self.currentJob = nil;
            self.buildState = 0;
          end
        end
        self.last_command = nc;
        if(self.wait <= 0) then
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
              --if(IsValid(cmatch)) then
              self.currentJob:finish(cmatch);
              self.buildState = 0;
              self.currentJob = nil;
              --else
                --self.currentJob:unAssign();
              --end
            end
            if(self.buildState == 3 and self.handle:isBusy()) then
              self.buildState = 1;
            end
          end
          
          if((not self.handle:canBuild()) and self.currentJob) then
            self.currentJob:unAssign();
            self.currentJob = nil;
            self.buildState = 0;
          end
          if(self.handle:canBuild() and not (self.handle:isBusy())) then
            self:_requestJob();
          end
        end
      end,
      _requestJob = function()
        local job = class:requestJob(self.handle);
        self.wait = 20;
        if(job) then
          self.wait = 0;
          self.currentJob = job;
          self.buildState = 3;
          self.handle:buildAt(job:getOdf(),(job:getLocation()~="GLOBAL" and job:getLocation()) or self.handle:getPosition());
        end
      end,
      onInit = function()
      end,
      onReset = function()
        self.handle:stop(0);
        if(self.currentJob) then
          self.currentJob:unAssign();
          self.currentJob = nil;
          self.buildState = 0;
        end
        self:onInit();
      end,
      save = function()
        local jobId = nil;
        if(self.currentJob) then
          jobId = self.currentJob:getId();
        end
        return {
          jobId = jobId, 
          state = self.buildState
        }
      end,
      load = function(data)
        if(data.jobId) then
          self.currentJob = class:getJob(data.jobId);
        end
        self.buildState = data.state;
      end
    },
    static = {
      queueJob = function(job)
        class.jobs[job:getId()] = job;
        job:onFinish():subscribe(function()
          class:removeJob(job:getId());
        end);
        return job:getId();
      end,
      queueJobs = function(...)
        local jobs = {...};
        for i,v in pairs(jobs) do
          class:queueJob(v);
        end
        local bundle = JobBundle(...);
        class.bundled[bundle:getId()] = bundle;
        bundle:onFinish():subscribe(function(b)
          class:removeBundle(bundle:getId());
        end);
        return bundle:getId();
      end,
      --Assumes jobs are in contained lists, args: {job1,job2},{job3,job4},{...},...
      queueJobs2 = function(...)
        local queue = {};
        for i, v in pairs({...}) do
          for i2, v2 in pairs(v) do
            table.insert(queue,v2);
          end
        end
        return class:queueJobs(unpack(queue));
      end,
      removeJob = function(jobId)
        class.jobs[jobId] = nil;
      end,
      removeBundle = function(bundleId)
        class.bundled[bundleId] = nil;
      end,
      requestJob = function(me,distprio)
        local dist = 100000;
        local job;
        local t = me:getTeamNum();
        local filtered = {};
        local jobPair = nil;
        local smallestPrio = math.huge;
        for i, v in pairs(class.jobs) do
          if((not v:isFinished()) and (not v:isAssigned()) and (v:getTeam() == t) and me:canMake(v:getOdf())) then
            local nl = me:getDistance(v:getLocation());
            local relativePriority = v:getPriority()*10;
            local scrapDiff = GetScrap(t) - v:getCost();
            if(v:getLocation() == "GLOBAL") then
              relativePriority = relativePriority + 100;
            else
              relativePriority = relativePriority + nl;
            end
            if(scrapDiff < 0) then
              relativePriority = relativePriority - scrapDiff*5;
            end
            if(relativePriority < smallestPrio) then
              smallestPrio = relativePriority;
              jobPair = {
                job = v,
                relativePriority = relativePriority
              };
            end
            --[[table.insert(filtered,{
              job = v,
              relativePriority = relativePriority
            });--]]
          end
        end
        --table.sort(filtered,function(a,b) return a.relativePriority < b.relativePriority end);
        --local jobPair = table.remove(filtered,1);
        if(jobPair) then
          --class.jobQueue[t][job.location][job.id] = nil;
          local job = jobPair.job;
          if(GetScrap(t) >= job:getCost()) then
            job:assignTo(me:getHandle());
            return jobPair.job;
          end
        end
      end,
      getJob = function(jobId)
        return class.jobs[jobId];
      end,
      getBundle = function(bundleId)
        return class.bundled[bundleId];
      end,
      _createBundle = function(jobs)
        --Creates a bundle out of a list of jobs
        local bundle = JobBundle(unpack(jobs));
        class.bundled[bundle:getId()] = bundle;
        return bundle;
      end,
      save = function()
        local jobSave = {};
        local bundleSave = {};
        for i,v in pairs(class.jobs) do
          if(not v:isFinished()) then
            jobSave[v:getId()] = v:save();
          end
        end
        for i,v in pairs(class.bundled) do
          if(not v:isFinished()) then
            bundleSave[v:getId()] = v:save();
          end
        end
        return {
          jobs = jobSave,
          bundled = bundleSave
        };
      end,
      load = function(data)
        for i,v in pairs(data.jobs) do
          class.jobs[i] = ProductionJob:fromSave(v);
          class.jobs[i]:onFinish():subscribe(function()
            class:removeJob(i);
          end);
        end
        class.bundled = data.bundled;
        --Set up subject for bundled jobs
        for i,v in pairs(data.bundled) do
          class.bundled[i] = JobBundle:fromSave(v,class);
          class.bundled[i]:onFinish():subscribe(function()
            class:removeBundle(i);
          end);
        end
      end
    }
  })
);


ProducerAi.jobs = {};
ProducerAi.bundled = {};

bzAi.aiManager:declearClass(ProducerAi);

return {
  ProducerAi = ProducerAi,
  ProductionJob = ProductionJob
};