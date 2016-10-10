local Objective;
local Listener;
local ObjectiveInstance;
local ObjectiveManager;
--Listener 'class' is ued to keep track of callbacks
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
Listener.mt = {__call = Listener.new,__index = Listener.prototype};
setmetatable(Listener,Listener.mt);

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
            for i,v in pairs(userData) do
                local data = {};
                for i2,v2 in pairs(v) do
                    table.insert(data,v2);
                end
                self:parentCall('load',unpack(data));
            end
        end
    }
};
ObjectiveInstance.mt = {
    __index = ObjectiveInstance.prototype,
    __call = ObjectiveInstance.new
}
setmetatable(ObjectiveInstance,ObjectiveInstance.mt);

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
    addInstance = function(self,instance)
        table.insert(self.objectives,instance);
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

return {    
    Objective = Objective,
    Update = ObjectiveManager.Update,
    AddObject = ObjectiveManager.AddObject,
    DeleteObject = ObjectiveManager.DeleteObject,
    CreateObject = ObjectiveManager.CreateObject,
    Load = ObjectiveManager.Load,
    Save = ObjectiveManager.Save,
    objectives = ObjectiveManager.objectives,
}
