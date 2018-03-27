local Objective;
local Listener;
local ObjectiveInstance;
local ObjectiveManager;
local UnitTracker;
local UnitTrackerManager;
local MissionManager;
local TaskSequencer;
local TaskManager;



local function isBzr() 
    return string.gmatch(GameVersion, "%d+")() == "2";
end

local function fixTugs()
    for v in AllCraft() do
        if(HasCargo(v)) then
            Deploy(v);
        end
    end
end

local function choose(...)
    local t = {...};
    local rn = math.random(#t);
    return t[rn];
end

local function chooseA(...)
    local t = {...};
    local m = 0;
    for i, v in pairs(t) do
        m = m + v.chance; 
    end
    local rn = math.random()*m;
    local n = 0;
    for i, v in ipairs(t) do
        if (v.chance+n) > rn then
        return v.item;
        end
        n = n + v.chance;
    end
end


local function createWave(odf,path_list,follow)
    local ret = {};
    for i,v in pairs(path_list) do
        local h = BuildObject(odf,2,v);
        if(follow) then
            Goto(h,follow);
        end
        table.insert(ret,h);
    end
    return unpack(ret);
end


local _GetOdf = GetOdf;

function table.pack(...)
  return { n = select("#", ...), ... };
end
local old_unpack = unpack;

function unpack(t)
    if(t.n) then
        return old_unpack(t,1,t.n);
    end
    return old_unpack(t);
end

local function enemiesInRange(dist,place)
    local enemies_nearby = false;
    for v in ObjectsInRange(300,globals.nav[4]) do
        if(IsCraft(v) and GetTeamNum(v) == 2) then
            enemies_nearby = true;
        end
    end
    return enemies_nearby;
end

local function spawnAtPath(odf,team,path)
    local handles = {};
    local current = GetPosition(path);
    local prev = nil;
    local c = 0;
    while current ~= prev do
        c = c + 1;
        table.insert(handles,BuildObject(odf,team,current));
        prev = current;
        current = GetPosition(path,c);
    end
    return handles;
end
--Returns true of all of the handles given are dead
--areAnyAlive = not areAllDead
local function areAllDead(handles, team)
    for i,v in pairs(handles) do
        if(IsAlive(v) and (team==nil or team == GetTeamNum(v))) then
            return false;
        end
    end
    return true;
end

local function countDead(handles, team)
    local c = 0;
    for i,v in pairs(handles) do
        if not (IsAlive(v) and (team==nil or team == GetTeamNum(v))) then
            c = c + 1;
        end
    end
    return c;
end

local function countAlive(handles, team)
    local c = 0;
    for i,v in pairs(handles) do
        if (IsAlive(v) and (team==nil or team == GetTeamNum(v))) then
            c = c + 1;
        end
    end
    return c;
end
--Returns true of any of the handles given are dead
--areAllAlive = not areAnyDead
local function areAnyDead(handles)
    for i,v in pairs(handles) do
        if(not IsAlive(v)) then
            return true;
        end
    end
    return false;
end


if(not SetLabel) then
    SetLabel = SettLabel;
end
--GetOdf sometimes returns junk after the name
--This wrapper removes that junk
GetOdf = function(...)
    local r = _GetOdf(...);
    if(r) then
        return r:gmatch("[^%c]+")();
    end
    return r;
    --return _GetOdf(...):gmatch("[^%c]+")();
end
--Spawn in formation from bzUtils3
local function spawnInFormation(formation,location,dir,units,team,seperation)
    if(seperation == nil) then 
        seperation = 10;
    end
    local tempH = {};
    local lead;
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
            if(not lead) then
                lead = h;
            end
            table.insert(tempH,h);
        end
        i3 = i3+1;
        end
    end
    return tempH, lead;
end

local function spawnInFormation2(formation,location,...)
    return spawnInFormation(formation,GetPosition(location,0),GetPosition(location,1) - GetPosition(location,0),...);
end

TaskSequencer = {
    new = function(cls,handle)
        self = setmetatable({},cls.mt);
        self.tasks = {};
        self.handle = handle;
        return self;
    end,
    prototype = {
        update = function(self,dtime)
            if((#self.tasks > 0) and (GetCurrentCommand(self.handle) == AiCommand["NONE"])) then
                local next = table.remove(self.tasks, 1);
                print(next.fname,next.type,GetLabel(self.handle),unpack(next.args));
                if(next.type == 1) then
                    SetCommand(self.handle,unpack(next.args));
                elseif(next.type == 2) then
                    _G[next.fname](self.handle,unpack(next.args));
                elseif(next.type == 3) then
                    table.insert(next.args,self);
                    _G[next.fname](self.handle,unpack(next.args));
                end
            end
        end,
        save = function(self)
            return self.tasks;
        end,
        load = function(self,...)
            self.tasks = ...;
        end,
        clear = function(self)
            self.tasks = {};
        end,
        push = function(self,...)
            table.insert(self.tasks,1,{type=1,args=table.pack(...)});
        end,
        push2 = function(self,fname,...)
            table.insert(self.tasks,1,{type=2,fname=fname,args=table.pack(...)});
        end,
        push3 = function(self,fname,...)
            table.insert(self.tasks,1,{type=3,fname=fname,args={...}});
        end,
        queue = function(self,...)
            table.insert(self.tasks,{type=1,args=table.pack(...)});
        end,
        queue2 = function(self,fname,...)
            table.insert(self.tasks,{type=2,fname=fname,args=table.pack(...)});
        end,
        queue3 = function(self,fname,...)
            table.insert(self.tasks,{type=3,fname=fname,args={...}});
        end
    }
}
TaskSequencer.mt = {__index = TaskSequencer.prototype};
setmetatable(TaskSequencer,{__call = TaskSequencer.new});


UnitTracker = {
    new = function(cls)
        local self = setmetatable({
            classT = {},
            odfT = {},
            handles = {},
            alive = true
        },cls.mt);
        UnitTrackerManager:addTracker(self);
        return self;
    end,
    Load = function(cls,data)
        local inst = cls:new();
        inst:load(data);
        return inst;
    end,
    prototype = {
        addObject = function(self,handle)
            if(self.handles[handle]) then
                return;
            end
            self.handles[handle] = {
                class = GetClassLabel(handle),
                odf = GetOdf(handle),
                team = GetTeamNum(handle)
            };
            local c = GetClassLabel(handle);
            local o = GetOdf(handle);
            local t = GetTeamNum(handle);
            if(not self.classT[t]) then
                self.classT[t] = {};
            end
            if(not self.odfT[t]) then
                self.odfT[t] = {};
            end
            if(not self.classT[t][c]) then
                self.classT[t][c] = {count = 0,total=0,handles={}};
            end
            if(not self.odfT[t][o]) then
                self.odfT[t][o] = {count = 0,handles={},total=0};
            end
            self.classT[t][c].handles[handle] = true;
            self.odfT[t][o].handles[handle] = true;
            self.classT[t][c].count = self.classT[t][c].count + 1;
            self.odfT[t][o].count = self.odfT[t][o].count + 1;
            self.classT[t][c].total = self.classT[t][c].total + 1;
            self.odfT[t][o].total = self.odfT[t][o].total + 1;          
        end,
        kill = function(self)
            self.alive = false;
        end,
        deleteObject = function(self,handle)
            if(self.handles[handle]) then
                local c = self.handles[handle].class;
                local o = self.handles[handle].odf;
                local t = self.handles[handle].team;
                if(self.classT[t] and self.classT[t][c]) then
                    self.classT[t][c].handles[handle] = nil;
                    self.classT[t][c].count = self.classT[t][c].count - 1;
                end
                if(self.odfT[t] and self.odfT[t][o]) then
                    self.odfT[t][o].handles[handle] = nil;
                    self.odfT[t][o].count = self.odfT[t][o].count - 1;
                end
            end
        end,
        countByClass = function(self,class,team)
            team = team or GetTeamNum(GetPlayerHandle())
            if(self.classT[team] and self.classT[team][class]) then
                return self.classT[team][class].count;
            end
            return 0;
        end,
        countByOdf = function(self,odf,team)
            team = team or GetTeamNum(GetPlayerHandle());
            if(self.odfT[team] and self.odfT[team][odf]) then
                return self.odfT[team][odf].count;
            end
            return 0;
        end,
        totalByClass = function(self,class,team)
            team = team or GetTeamNum(GetPlayerHandle())
            if(self.classT[team] and self.classT[team][class]) then
                return self.classT[team][class].total;
            end
            return 0;
        end,
        totalByOdf = function(self,odf,team)
            team = team or GetTeamNum(GetPlayerHandle())
            if(self.odfT[team] and self.odfT[team][odf]) then
                return self.odfT[team][odf].total;
            end
            return 0;
        end,
        hasBuiltOfClass = function(self,class,count,team)
            return self:totalByClass(class,team) >= count;
        end,
        hasBuiltOfOdf = function(self,odf,count,team)
            return self:totalByOdf(odf,team) >= count;
        end,
        gotOfClass = function(self,class,count,team)
            return self:countByClass(class,team) >= count;
        end,
        gotOfOdf = function(self,odf,count,team)
            return self:countByOdf(odf,team) >= count;
        end,
        save = function(self)
            return self;
        end,
        load = function(self,data)
            self.classT = data.classT;
            self.odfT = data.odfT;
            self.handles = data.handles;
        end
    } 
}

UnitTracker.mt = {__index = UnitTracker.prototype};
setmetatable(UnitTracker,{__call = UnitTracker.new});

UnitTrackerManager = {
    trackers = {},
    addTracker = function(self,tracker)
        table.insert(self.trackers,tracker);
    end,
    AddObject = function(self,...)
        for i,v in pairs(self.trackers) do
            if(v.alive) then
                v:addObject(...);
            else
                self.trackers[i] = nil;
            end
        end
    end,
    DeleteObject = function(self,...)
        for i,v in pairs(self.trackers) do
            if(v.alive) then
                v:deleteObject(...);
            else
                self.trackers[i] = nil;
            end
        end
    end
}


--Listener 'class' is used to keep track of callbacks
--Dosen't do much
Listener = {
    new = function(cls,event,callback)
        local self = {
            event = event,
            callback = callback
        };
        return setmetatable(self,cls.mt);
    end,
    prototype = {
        call = function(self,...)
            return self.callback(...);
        end,
        getEvent = function(self)
            return self.event;
        end
    }
}
Listener.mt = {__index = Listener.prototype};
setmetatable(Listener,{__call = Listener.new});

ObjectiveInstance = {
    new = function(cls,parent_name,default,subTasks)
        local self = setmetatable({
            parentName = parent_name,
            parentRef = Objective:getObjective(parent_name),
            subTasks = {},
            subCount = 0,
            alive = true,
            started = false
        },cls.mt);
        self.parentRef.child = self;
        self.parentRef.hasChild = true;
        if(subTasks) then
            for i,v in pairs(subTasks) do
                assert(self.subTasks[v] == nil, ("Task %s defined more than once!"):format(v));
                self.subCount = self.subCount + 1;
                self.subTasks[v] = {
                    running = false,
                    done = false,
                    state = 0,
                    success_count = 0,
                    fail_count = 0
                };
            end
        end
        for i,v in pairs(default) do
            self[i] = v;
        end
        ObjectiveManager:addInstance(self);
        self:init();
        return self;
    end,
    Load = function(cls,save_data)
        local objDefinition = Objective:getObjective(save_data.parentName);
        local inst = cls:new(save_data.parentName,objDefinition.child_vars);
        inst.started = save_data.started;
        inst.alive = save_data.alive;
        inst.subTasks = save_data.subTasks;
        inst.subCount = inst.subCount;
        inst:load(save_data.userData);
        return inst;
    end,
    prototype = {
        parentCall = function(self,event,...) 
            return self.parentRef:dispatchEvent(event,self,...)
        end,
        call = function(self,...)
            return unpack(self:parentCall(...)[1] or {});
        end,
        start = function(self,...)
            self:parentCall('start',...);
            self.started = true;
        end,
        kill = function(self)
            self.alive = false;
        end,
        update = function(self,...)
            self:parentCall('update',...);
        end,
        success = function(self,...)
            self:kill(); --<-- killed to prevent feedback loop
            self:parentCall('success',...);
            self:_finish();
        end,
        fail = function(self,...)
            self:kill(); --<-- killed to prevent feedback loop
            self:parentCall('fail',...);
            self:_finish();
        end,
        _finish = function(self,...)
            self:kill();
            self:parentCall('finish',...);
        end,
        init = function(self,...)
            self:parentCall('init',...);
        end,
        addObject = function(self,...)
            self:parentCall('add_object',...);
        end,  
        deleteObject = function(self,...)
            self:parentCall('delete_object',...);
        end,
        createObject = function(self,...)
            self:parentCall('create_object',...)
        end,
        isTaskActive = function(self,name)
            if(self.subTasks[name]) then
                return self.subTasks[name].running and (not self:isTaskDone(name));
            end
        end,
        isTaskDone = function(self,name)
            if(self.subTasks[name]) then
                return self.subTasks[name].done;
            end
        end,
        _hasTasksState = function(self,state,...)
            local all = true;
            for i,v in pairs({...}) do
                all = all and self:_hasTaskState(v,state);
            end
            return all;
        end,
        _hasTaskState = function(self,name,state)
            if(self.subTasks[name]) then
                return self.subTasks[name].state == state;
            end
        end,
        hasTasksSucceeded = function(self,...)
            return self:_hasTasksState(2,...)
        end,
        hasTaskSucceeded = function(self,name)
            return self:_hasTaskState(name,2);
        end,
        hasTaskSucccededBefore = function(self,name)
            return self.subTasks[name].success_count > 0;
        end,
        hasTaskFailedBefore = function(self,name)
            return self.subTasks[name].fail_count > 0;
        end,
        hasTasksFailed = function(self,...)
            return self:_hasTasksState(3,...)
        end,
        hasTaskFailed = function(self,name)
            return self:_hasTaskState(name,3);
        end,
        hasTaskStarted = function(self,name)
            if(self.subTasks[name]) then
                return self.subTasks[name].state > 0;
            end
        end,
        startTask = function(self,name,...)
            if(self.subTasks[name]) then
                local t = self.subTasks[name];
                t.state = 1;
                t.running = true;
                self:parentCall('task_start',name,...);
            end
        end,
        _tasksWithState = function(self,state)
            local c = 0;
            for i,v in pairs(self.subTasks) do
                if(v.state == state) then
                    c = c + 1;
                end
            end
            return c;
        end,
        countSucceeded = function(self)
            return self:_tasksWithState(2);
        end,
        countFailed = function(self)
            return self:_tasksWithState(3);
        end,
        taskCount = function(self)
            return self.subCount;
        end,
        taskEnd = function(self,name)
            if(self.subTasks[name]) then
                local t = self.subTasks[name];
                t.done = true;
                --t.state = 1;
            end
        end,
        taskSucceed = function(self,name,...)
            if(self.subTasks[name]) then
                local t = self.subTasks[name];
                local pstate = t.state;
                t.done = true;
                t.state = 2;
                t.success_count = t.success_count + 1;
                self:parentCall('task_success',name,pstate <= 3,t.success_count==1,...);
            end
        end,
        taskReset = function(self,name,...)
            if(self.subTasks[name]) then
                local t = self.subTasks[name];
                t.done = false;
                t.state = t.state + 3;
                self:parentCall('task_reset',name,...);
            end 
        end,
        taskFail = function(self,name,...)
            if(self.subTasks[name]) then
                local t = self.subTasks[name];
                local pstate = t.state;
                t.done = true;
                t.state = 3;
                t.fail_count = t.fail_count + 1;
                self:parentCall('task_fail',name,pstate <= 3,t.fail_count==0,...);
            end
        end,
        save = function(self,...)
            local save_data = {
                parentName = self.parentName,
                alive = self.alive,
                userData = {},
                subTasks = self.subTasks,
                started = self.started,
                subCount = self.subCount
            };
            for i,v in pairs(self:parentCall('save',...)) do
                table.insert(save_data.userData,v);
            end
            return save_data;
        end,
        load = function(self,userData)
            self:parentCall('load',unpack(userData[1] or {}));
        end
    }
};
ObjectiveInstance.mt = {
    __index = ObjectiveInstance.prototype
}
setmetatable(ObjectiveInstance,{__call = ObjectiveInstance.new});

--Objective 'class', this is used to define objectives
Objective = {
    define = function(cls,name,defaults,listener_table)
        local self = setmetatable({
            name = name,
            listeners = {},
            subTasks = {},
            child_vars = {},
            child = false,
            hasChild = false
        },cls.mt);
        self:init(defaults or {}):setListeners(listener_table or {});
        
        cls:addObjective(self);
        return self;
    end,
    Start = function(cls,name,...)
        return cls:getObjective(name):start(...);
    end,
    getObjective = function(cls,name)
        return cls.objectives[name];
    end,
    addObjective = function(cls,obj)
        if(not cls:getObjective(name)) then
            cls.objectives[obj.name] = obj;
        else
            error("Objective already exist!");
        end
    end,
    objectives = {},
    prototype = {
        --possible events for an objective
        events = {
            'init',
            'start',
            'finish',
            'update',
            'fail',
            'success',
            'create_object',
            'add_object',
            'save',
            'load',
            'delete_object'
        },
        init = function(self,vars)
            for i,v in pairs(vars) do
                self.child_vars[i] = v;
            end
            return self;
        end,
        setListeners = function(self,listeners)
            for i,v in pairs(listeners) do
                self:on(i,v);
            end
            return self;
        end,
        createTasks = function(self,...)
            self.subTasks = {...};
            return self;
        end,
        getInstance = function(self)
            return self.child;
        end,
        getName = function(self)
            return self.name;
        end,
        --bind an event to a callback
        on = function(self,event,callback)
            if(not self.listeners[event]) then
                self.listeners[event] = {};
            end
            table.insert(self.listeners[event],Listener(event,callback));
        end,
        dispatchEvent = function(self,event,...)
            local ret = {};
            if(self.listeners[event]) then
                for i,listener in pairs(self.listeners[event]) do
                    table.insert(ret,table.pack(listener:call(...)));
                end
            end
            return ret;
        end,
        --construct an objective instance
        start = function(self,...)
            local instance = ObjectiveInstance:new(self.name,self.child_vars,self.subTasks);
            self.child = instance;
            self.hasChild = true;
            instance:start(...);
            return instance;
        end
    }
}
Objective.mt = {
    __index = function(t,i)
        if(t.hasChild and t.child[i]) then
            return (t.child[i]);
        else
            return t.child_vars[i] or Objective.prototype[i];
        end
    end,
    __newindex = function(t,i,v)
        t.child_vars[i] = v;
    end
};
setmetatable(Objective,Objective.mt);

TaskManager = {
    sequencers = {},
    Update = function(self,...)
        for i,v in pairs(self.sequencers) do
            if(IsValid(i)) then
                v:update(...);
            else
                self.sequencers[i] = nil;
            end
        end
    end,
    DeleteObject = function(self,h)
        --self.sequencers[h] = nil;
    end,
    Save = function(self,...)
        local sdata = {};
        for i,v in pairs(self.sequencers) do
            sdata[i] = table.pack(v:save());
        end
        return sdata;
    end,
    sequencer = function(self,handle)
        if(not self.sequencers[handle]) then
            self.sequencers[handle] = TaskSequencer(handle);
        end
        return self.sequencers[handle];
    end,
    Load = function(self,data)
        for i,v in pairs(data) do
            local s = self:sequencer(i);
            s:load(unpack(v));
        end
    end
}



ObjectiveManager = {
    objectives = {},
    getObjective = function(self,name)
        return self.objectives[name];
    end,
    addInstance = function(self,instance)
        self.objectives[instance.parentName] = instance;
        --table.insert(self.objectives,instance);
    end,
    Update = function(self,...)
        for i,obj in pairs(self.objectives) do 
            if(obj.alive and obj.started) then
                obj:update(...);
            else
                self.objectives[i] = nil;
            end
        end
    end,
    AddObject = function(self,...)
        for i,obj in pairs(self.objectives) do 
            if(obj.alive and obj.started) then
                obj:addObject(...);
            end
        end
    end,
    CreateObject = function(self,...)
        for i,obj in pairs(self.objectives) do 
            if(obj.alive and obj.started) then
                obj:createObject(...);
            end
        end    
    end,
    DeleteObject = function(self,...)
        for i,obj in pairs(self.objectives) do 
            if(obj.alive and obj.started) then
                obj:deleteObject(...);
            end
        end
    end,
    Save = function(self,...)
        local ret = {};
        for i,obj in pairs(self.objectives) do
            if(obj.alive) then
                table.insert(ret,obj:save(...));
            end
        end
        return ret;
    end,
    Load = function(self,data)
        for i,obj in pairs(data) do
            ObjectiveInstance:Load(obj);
        end
    end
}

MissionManager = {
    Update = function(self,...)
        TaskManager:Update(...);
        ObjectiveManager:Update(...);
    end,
    AddObject = function(self,...)
        UnitTrackerManager:AddObject(...);
        ObjectiveManager:AddObject(...);
    end,
    CreateObject = function(self,...)
        ObjectiveManager:CreateObject(...);
    end,
    DeleteObject = function(self,...)
        TaskManager:DeleteObject(...)
        UnitTrackerManager:DeleteObject(...);
        ObjectiveManager:DeleteObject(...);
    end,
    Save = function(self)
        return {ObjectiveManager:Save(), TaskManager:Save()};
    end,
    Load = function(self,data)
        ObjectiveManager:Load(data[1]);
        TaskManager:Load(data[2]);
    end
}



return {    
    Objective = Objective,
    Update = MissionManager.Update,
    AddObject = MissionManager.AddObject,
    DeleteObject = MissionManager.DeleteObject,
    CreateObject = MissionManager.CreateObject,
    Load = MissionManager.Load,
    Save = MissionManager.Save,
    getObjective = ObjectiveManager.getObjective,
    objectives = ObjectiveManager.objectives,
    UnitTracker = UnitTracker,
    spawnInFormation = spawnInFormation,
    spawnInFormation2 = spawnInFormation2,
    spawnAtPath = spawnAtPath,
    enemiesInRange = enemiesInRange,
    areAllDead = areAllDead,
    areAnyDead = areAnyDead,
    countAlive = countAlive,
    countDead = countDead,
    TaskManager = TaskManager,
    createWave = createWave,
    fixTugs = fixTugs,
    isBzr = isBzr,
    choose = choose,
    chooseA = chooseA
}
