local Objective;
local Listener;
local ObjectiveInstance;
local ObjectiveManager;
local UnitTracker;
local UnitTrackerManager;
local MissionManager;

local _GetOdf = GetOdf;
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
    new = function(cls,parent_name,default)
        local self = setmetatable({
            parentName = parent_name,
            parentRef = Objective:getObjective(parent_name),
            alive = true,
            started = false
        },cls.mt);
        self.parentRef.child = self;
        self.parentRef.hasChild = true;
        for i,v in pairs(default) do
            self[i] = v;
        end
        ObjectiveManager:addInstance(self);
        return self;
    end,
    Load = function(cls,save_data)
        local objDefinition = Objective:getObjective(save_data.parentName);
        local inst = cls:new(save_data.parentName,objDefinition.child_vars);
        inst.started = save_data.started;
        inst.alive = save_data.alive;
        inst:load(save_data.userData);
        return inst;
    end,
    prototype = {
        parentCall = function(self,event,...) 
            return self.parentRef:dispatchEvent(event,self,...)
        end,
        start = function(self,...)
            self:parentCall('start',...);
            self.started = true;
        end,
        kill = function(self)
            self.alive = false;
            print(self,self.alive);
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
        save = function(self,...)
            local save_data = {
                parentName = self.parentName,
                alive = self.alive,
                userData = {},
                started = self.started
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
            child_vars = {},
            child = false,
            hasChild = false
        },cls.mt);
        self:init(defaults or {}):setListeners(listener_table or {});
        
        cls:addObjective(self);
        return self;
    end,
    Start = function(cls,name)
        return cls:getObjective(name):start();
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
                    table.insert(ret,{listener:call(...)});
                end
            end
            return ret;
        end,
        --construct an objective instance
        start = function(self,...)
            local instance = ObjectiveInstance:new(self.name,self.child_vars);
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
        UnitTrackerManager:DeleteObject(...);
        ObjectiveManager:DeleteObject(...);
    end,
    Save = function(self,...)
        return ObjectiveManager:Save(...);
    end,
    Load = function(self,data)
        ObjectiveManager:Load(data);
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
    getObjective = MissionManager.getObjective,
    objectives = ObjectiveManager.objectives,
    UnitTracker = UnitTracker
}
