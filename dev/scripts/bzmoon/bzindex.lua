package.preload['rx'] = (function (...)
-- RxLua v0.0.3
-- https://github.com/bjornbytes/rxlua
-- MIT License

local util = {}

util.pack = table.pack or function(...) return { n = select('#', ...), ... } end
util.unpack = table.unpack or unpack
util.eq = function(x, y) return x == y end
util.noop = function() end
util.identity = function(x) return x end
util.constant = function(x) return function() return x end end
util.isa = function(object, class)
  return type(object) == 'table' and getmetatable(object).__index == class
end
util.tryWithObserver = function(observer, fn, ...)
  local success, result = pcall(fn, ...)
  if not success then
    observer:onError(result)
  end
  return success, result
end

--- @class Subscription
-- @description A handle representing the link between an Observer and an Observable, as well as any
-- work required to clean up after the Observable completes or the Observer unsubscribes.
local Subscription = {}
Subscription.__index = Subscription
Subscription.__tostring = util.constant('Subscription')

--- Creates a new Subscription.
-- @arg {function=} action - The action to run when the subscription is unsubscribed. It will only
--                           be run once.
-- @returns {Subscription}
function Subscription.create(action)
  local self = {
    action = action or util.noop,
    unsubscribed = false
  }

  return setmetatable(self, Subscription)
end

--- Unsubscribes the subscription, performing any necessary cleanup work.
function Subscription:unsubscribe()
  if self.unsubscribed then return end
  self.action(self)
  self.unsubscribed = true
end

--- @class Observer
-- @description Observers are simple objects that receive values from Observables.
local Observer = {}
Observer.__index = Observer
Observer.__tostring = util.constant('Observer')

--- Creates a new Observer.
-- @arg {function=} onNext - Called when the Observable produces a value.
-- @arg {function=} onError - Called when the Observable terminates due to an error.
-- @arg {function=} onCompleted - Called when the Observable completes normally.
-- @returns {Observer}
function Observer.create(onNext, onError, onCompleted)
  local self = {
    _onNext = onNext or util.noop,
    _onError = onError or error,
    _onCompleted = onCompleted or util.noop,
    stopped = false
  }

  return setmetatable(self, Observer)
end

--- Pushes zero or more values to the Observer.
-- @arg {*...} values
function Observer:onNext(...)
  if not self.stopped then
    self._onNext(...)
  end
end

--- Notify the Observer that an error has occurred.
-- @arg {string=} message - A string describing what went wrong.
function Observer:onError(message)
  if not self.stopped then
    self.stopped = true
    self._onError(message)
  end
end

--- Notify the Observer that the sequence has completed and will produce no more values.
function Observer:onCompleted()
  if not self.stopped then
    self.stopped = true
    self._onCompleted()
  end
end

--- @class Observable
-- @description Observables push values to Observers.
local Observable = {}
Observable.__index = Observable
Observable.__tostring = util.constant('Observable')

--- Creates a new Observable.
-- @arg {function} subscribe - The subscription function that produces values.
-- @returns {Observable}
function Observable.create(subscribe)
  local self = {
    _subscribe = subscribe
  }

  return setmetatable(self, Observable)
end

--- Shorthand for creating an Observer and passing it to this Observable's subscription function.
-- @arg {function} onNext - Called when the Observable produces a value.
-- @arg {function} onError - Called when the Observable terminates due to an error.
-- @arg {function} onCompleted - Called when the Observable completes normally.
function Observable:subscribe(onNext, onError, onCompleted)
  if type(onNext) == 'table' then
    return self._subscribe(onNext)
  else
    return self._subscribe(Observer.create(onNext, onError, onCompleted))
  end
end

--- Returns an Observable that immediately completes without producing a value.
function Observable.empty()
  return Observable.create(function(observer)
    observer:onCompleted()
  end)
end

--- Returns an Observable that never produces values and never completes.
function Observable.never()
  return Observable.create(function(observer) end)
end

--- Returns an Observable that immediately produces an error.
function Observable.throw(message)
  return Observable.create(function(observer)
    observer:onError(message)
  end)
end

--- Creates an Observable that produces a set of values.
-- @arg {*...} values
-- @returns {Observable}
function Observable.of(...)
  local args = {...}
  local argCount = select('#', ...)
  return Observable.create(function(observer)
    for i = 1, argCount do
      observer:onNext(args[i])
    end

    observer:onCompleted()
  end)
end

--- Creates an Observable that produces a range of values in a manner similar to a Lua for loop.
-- @arg {number} initial - The first value of the range, or the upper limit if no other arguments
--                         are specified.
-- @arg {number=} limit - The second value of the range.
-- @arg {number=1} step - An amount to increment the value by each iteration.
-- @returns {Observable}
function Observable.fromRange(initial, limit, step)
  if not limit and not step then
    initial, limit = 1, initial
  end

  step = step or 1

  return Observable.create(function(observer)
    for i = initial, limit, step do
      observer:onNext(i)
    end

    observer:onCompleted()
  end)
end

--- Creates an Observable that produces values from a table.
-- @arg {table} table - The table used to create the Observable.
-- @arg {function=pairs} iterator - An iterator used to iterate the table, e.g. pairs or ipairs.
-- @arg {boolean} keys - Whether or not to also emit the keys of the table.
-- @returns {Observable}
function Observable.fromTable(t, iterator, keys)
  iterator = iterator or pairs
  return Observable.create(function(observer)
    for key, value in iterator(t) do
      observer:onNext(value, keys and key or nil)
    end

    observer:onCompleted()
  end)
end

--- Creates an Observable that produces values when the specified coroutine yields.
-- @arg {thread|function} fn - A coroutine or function to use to generate values.  Note that if a
--                             coroutine is used, the values it yields will be shared by all
--                             subscribed Observers (influenced by the Scheduler), whereas a new
--                             coroutine will be created for each Observer when a function is used.
-- @returns {Observable}
function Observable.fromCoroutine(fn, scheduler)
  return Observable.create(function(observer)
    local thread = type(fn) == 'function' and coroutine.create(fn) or fn
    return scheduler:schedule(function()
      while not observer.stopped do
        local success, value = coroutine.resume(thread)

        if success then
          observer:onNext(value)
        else
          return observer:onError(value)
        end

        if coroutine.status(thread) == 'dead' then
          return observer:onCompleted()
        end

        coroutine.yield()
      end
    end)
  end)
end

--- Creates an Observable that produces values from a file, line by line.
-- @arg {string} filename - The name of the file used to create the Observable
-- @returns {Observable}
function Observable.fromFileByLine(filename)
  return Observable.create(function(observer)
    local file = io.open(filename, 'r')
    if file then
      file:close()

      for line in io.lines(filename) do
        observer:onNext(line)
      end

      return observer:onCompleted()
    else
      return observer:onError(filename)
    end
  end)
end

--- Creates an Observable that creates a new Observable for each observer using a factory function.
-- @arg {function} factory - A function that returns an Observable.
-- @returns {Observable}
function Observable.defer(fn)
  if not fn or type(fn) ~= 'function' then
    error('Expected a function')
  end

  return setmetatable({
    subscribe = function(_, ...)
      local observable = fn()
      return observable:subscribe(...)
    end
  }, Observable)
end

--- Returns an Observable that repeats a value a specified number of times.
-- @arg {*} value - The value to repeat.
-- @arg {number=} count - The number of times to repeat the value.  If left unspecified, the value
--                        is repeated an infinite number of times.
-- @returns {Observable}
function Observable.replicate(value, count)
  return Observable.create(function(observer)
    while count == nil or count > 0 do
      observer:onNext(value)
      if count then
        count = count - 1
      end
    end
    observer:onCompleted()
  end)
end

--- Subscribes to this Observable and prints values it produces.
-- @arg {string=} name - Prefixes the printed messages with a name.
-- @arg {function=tostring} formatter - A function that formats one or more values to be printed.
function Observable:dump(name, formatter)
  name = name and (name .. ' ') or ''
  formatter = formatter or tostring

  local onNext = function(...) print(name .. 'onNext: ' .. formatter(...)) end
  local onError = function(e) print(name .. 'onError: ' .. e) end
  local onCompleted = function() print(name .. 'onCompleted') end

  return self:subscribe(onNext, onError, onCompleted)
end

--- Determine whether all items emitted by an Observable meet some criteria.
-- @arg {function=identity} predicate - The predicate used to evaluate objects.
function Observable:all(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if not predicate(...) then
          observer:onNext(false)
          observer:onCompleted()
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(true)
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Given a set of Observables, produces values from only the first one to produce a value.
-- @arg {Observable...} observables
-- @returns {Observable}
function Observable.amb(a, b, ...)
  if not a or not b then return a end

  return Observable.create(function(observer)
    local subscriptionA, subscriptionB

    local function onNextA(...)
      if subscriptionB then subscriptionB:unsubscribe() end
      observer:onNext(...)
    end

    local function onErrorA(e)
      if subscriptionB then subscriptionB:unsubscribe() end
      observer:onError(e)
    end

    local function onCompletedA()
      if subscriptionB then subscriptionB:unsubscribe() end
      observer:onCompleted()
    end

    local function onNextB(...)
      if subscriptionA then subscriptionA:unsubscribe() end
      observer:onNext(...)
    end

    local function onErrorB(e)
      if subscriptionA then subscriptionA:unsubscribe() end
      observer:onError(e)
    end

    local function onCompletedB()
      if subscriptionA then subscriptionA:unsubscribe() end
      observer:onCompleted()
    end

    subscriptionA = a:subscribe(onNextA, onErrorA, onCompletedA)
    subscriptionB = b:subscribe(onNextB, onErrorB, onCompletedB)

    return Subscription.create(function()
      subscriptionA:unsubscribe()
      subscriptionB:unsubscribe()
    end)
  end):amb(...)
end

--- Returns an Observable that produces the average of all values produced by the original.
-- @returns {Observable}
function Observable:average()
  return Observable.create(function(observer)
    local sum, count = 0, 0

    local function onNext(value)
      sum = sum + value
      count = count + 1
    end

    local function onError(e)
      observer:onError(e)
    end

    local function onCompleted()
      if count > 0 then
        observer:onNext(sum / count)
      end

      observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that buffers values from the original and produces them as multiple
-- values.
-- @arg {number} size - The size of the buffer.
function Observable:buffer(size)
  if not size or type(size) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local buffer = {}

    local function emit()
      if #buffer > 0 then
        observer:onNext(util.unpack(buffer))
        buffer = {}
      end
    end

    local function onNext(...)
      local values = {...}
      for i = 1, #values do
        table.insert(buffer, values[i])
        if #buffer >= size then
          emit()
        end
      end
    end

    local function onError(message)
      emit()
      return observer:onError(message)
    end

    local function onCompleted()
      emit()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that intercepts any errors from the previous and replace them with values
-- produced by a new Observable.
-- @arg {function|Observable} handler - An Observable or a function that returns an Observable to
--                                      replace the source Observable in the event of an error.
-- @returns {Observable}
function Observable:catch(handler)
  handler = handler and (type(handler) == 'function' and handler or util.constant(handler))

  return Observable.create(function(observer)
    local subscription

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(e)
      if not handler then
        return observer:onCompleted()
      end

      local success, _continue = pcall(handler, e)
      if success and _continue then
        if subscription then subscription:unsubscribe() end
        _continue:subscribe(observer)
      else
        observer:onError(success and e or _continue)
      end
    end

    local function onCompleted()
      observer:onCompleted()
    end

    subscription = self:subscribe(onNext, onError, onCompleted)
    return subscription
  end)
end

--- Returns a new Observable that runs a combinator function on the most recent values from a set
-- of Observables whenever any of them produce a new value. The results of the combinator function
-- are produced by the new Observable.
-- @arg {Observable...} observables - One or more Observables to combine.
-- @arg {function} combinator - A function that combines the latest result from each Observable and
--                              returns a single value.
-- @returns {Observable}
function Observable:combineLatest(...)
  local sources = {...}
  local combinator = table.remove(sources)
  if type(combinator) ~= 'function' then
    table.insert(sources, combinator)
    combinator = function(...) return ... end
  end
  table.insert(sources, 1, self)

  return Observable.create(function(observer)
    local latest = {}
    local pending = {util.unpack(sources)}
    local completed = {}
    local subscription = {}

    local function onNext(i)
      return function(value)
        latest[i] = value
        pending[i] = nil

        if not next(pending) then
          util.tryWithObserver(observer, function()
            observer:onNext(combinator(util.unpack(latest)))
          end)
        end
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted(i)
      return function()
        table.insert(completed, i)

        if #completed == #sources then
          observer:onCompleted()
        end
      end
    end

    for i = 1, #sources do
      subscription[i] = sources[i]:subscribe(onNext(i), onError, onCompleted(i))
    end

    return Subscription.create(function ()
      for i = 1, #sources do
        if subscription[i] then subscription[i]:unsubscribe() end
      end
    end)
  end)
end

--- Returns a new Observable that produces the values of the first with falsy values removed.
-- @returns {Observable}
function Observable:compact()
  return self:filter(util.identity)
end

--- Returns a new Observable that produces the values produced by all the specified Observables in
-- the order they are specified.
-- @arg {Observable...} sources - The Observables to concatenate.
-- @returns {Observable}
function Observable:concat(other, ...)
  if not other then return self end

  local others = {...}

  return Observable.create(function(observer)
    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function chain()
      return other:concat(util.unpack(others)):subscribe(onNext, onError, onCompleted)
    end

    return self:subscribe(onNext, onError, chain)
  end)
end

--- Returns a new Observable that produces a single boolean value representing whether or not the
-- specified value was produced by the original.
-- @arg {*} value - The value to search for.  == is used for equality testing.
-- @returns {Observable}
function Observable:contains(value)
  return Observable.create(function(observer)
    local subscription

    local function onNext(...)
      local args = util.pack(...)

      if #args == 0 and value == nil then
        observer:onNext(true)
        if subscription then subscription:unsubscribe() end
        return observer:onCompleted()
      end

      for i = 1, #args do
        if args[i] == value then
          observer:onNext(true)
          if subscription then subscription:unsubscribe() end
          return observer:onCompleted()
        end
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(false)
      return observer:onCompleted()
    end

    subscription = self:subscribe(onNext, onError, onCompleted)
    return subscription
  end)
end

--- Returns an Observable that produces a single value representing the number of values produced
-- by the source value that satisfy an optional predicate.
-- @arg {function=} predicate - The predicate used to match values.
function Observable:count(predicate)
  predicate = predicate or util.constant(true)

  return Observable.create(function(observer)
    local count = 0

    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if predicate(...) then
          count = count + 1
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(count)
      observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new throttled Observable that waits to produce values until a timeout has expired, at
-- which point it produces the latest value from the source Observable.  Whenever the source
-- Observable produces a value, the timeout is reset.
-- @arg {number|function} time - An amount in milliseconds to wait before producing the last value.
-- @arg {Scheduler} scheduler - The scheduler to run the Observable on.
-- @returns {Observable}
function Observable:debounce(time, scheduler)
  time = time or 0

  return Observable.create(function(observer)
    local debounced = {}

    local function wrap(key)
      return function(...)
        local value = util.pack(...)

        if debounced[key] then
          debounced[key]:unsubscribe()
        end

        local values = util.pack(...)

        debounced[key] = scheduler:schedule(function()
          return observer[key](observer, util.unpack(values))
        end, time)
      end
    end

    local subscription = self:subscribe(wrap('onNext'), wrap('onError'), wrap('onCompleted'))

    return Subscription.create(function()
      if subscription then subscription:unsubscribe() end
      for _, timeout in pairs(debounced) do
        timeout:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that produces a default set of items if the source Observable produces
-- no values.
-- @arg {*...} values - Zero or more values to produce if the source completes without emitting
--                      anything.
-- @returns {Observable}
function Observable:defaultIfEmpty(...)
  local defaults = util.pack(...)

  return Observable.create(function(observer)
    local hasValue = false

    local function onNext(...)
      hasValue = true
      observer:onNext(...)
    end

    local function onError(e)
      observer:onError(e)
    end

    local function onCompleted()
      if not hasValue then
        observer:onNext(util.unpack(defaults))
      end

      observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the values of the original delayed by a time period.
-- @arg {number|function} time - An amount in milliseconds to delay by, or a function which returns
--                                this value.
-- @arg {Scheduler} scheduler - The scheduler to run the Observable on.
-- @returns {Observable}
function Observable:delay(time, scheduler)
  time = type(time) ~= 'function' and util.constant(time) or time

  return Observable.create(function(observer)
    local actions = {}

    local function delay(key)
      return function(...)
        local arg = util.pack(...)
        local handle = scheduler:schedule(function()
          observer[key](observer, util.unpack(arg))
        end, time())
        table.insert(actions, handle)
      end
    end

    local subscription = self:subscribe(delay('onNext'), delay('onError'), delay('onCompleted'))

    return Subscription.create(function()
      if subscription then subscription:unsubscribe() end
      for i = 1, #actions do
        actions[i]:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that produces the values from the original with duplicates removed.
-- @returns {Observable}
function Observable:distinct()
  return Observable.create(function(observer)
    local values = {}

    local function onNext(x)
      if not values[x] then
        observer:onNext(x)
      end

      values[x] = true
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that only produces values from the original if they are different from
-- the previous value.
-- @arg {function} comparator - A function used to compare 2 values. If unspecified, == is used.
-- @returns {Observable}
function Observable:distinctUntilChanged(comparator)
  comparator = comparator or util.eq

  return Observable.create(function(observer)
    local first = true
    local currentValue = nil

    local function onNext(value, ...)
      local values = util.pack(...)
      util.tryWithObserver(observer, function()
        if first or not comparator(value, currentValue) then
          observer:onNext(value, util.unpack(values))
          currentValue = value
          first = false
        end
      end)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces the nth element produced by the source Observable.
-- @arg {number} index - The index of the item, with an index of 1 representing the first.
-- @returns {Observable}
function Observable:elementAt(index)
  if not index or type(index) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local subscription
    local i = 1

    local function onNext(...)
      if i == index then
        observer:onNext(...)
        observer:onCompleted()
        if subscription then
          subscription:unsubscribe()
        end
      else
        i = i + 1
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    subscription = self:subscribe(onNext, onError, onCompleted)
    return subscription
  end)
end

--- Returns a new Observable that only produces values of the first that satisfy a predicate.
-- @arg {function} predicate - The predicate used to filter values.
-- @returns {Observable}
function Observable:filter(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if predicate(...) then
          return observer:onNext(...)
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the first value of the original that satisfies a
-- predicate.
-- @arg {function} predicate - The predicate used to find a value.
function Observable:find(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if predicate(...) then
          observer:onNext(...)
          return observer:onCompleted()
        end
      end, ...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that only produces the first result of the original.
-- @returns {Observable}
function Observable:first()
  return self:take(1)
end

--- Returns a new Observable that transform the items emitted by an Observable into Observables,
-- then flatten the emissions from those into a single Observable
-- @arg {function} callback - The function to transform values from the original Observable.
-- @returns {Observable}
function Observable:flatMap(callback)
  callback = callback or util.identity
  return self:map(callback):flatten()
end

--- Returns a new Observable that uses a callback to create Observables from the values produced by
-- the source, then produces values from the most recent of these Observables.
-- @arg {function=identity} callback - The function used to convert values to Observables.
-- @returns {Observable}
function Observable:flatMapLatest(callback)
  callback = callback or util.identity
  return Observable.create(function(observer)
    local innerSubscription

    local function onNext(...)
      observer:onNext(...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function subscribeInner(...)
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      return util.tryWithObserver(observer, function(...)
        innerSubscription = callback(...):subscribe(onNext, onError)
      end, ...)
    end

    local subscription = self:subscribe(subscribeInner, onError, onCompleted)
    return Subscription.create(function()
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      if subscription then
        subscription:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that subscribes to the Observables produced by the original and
-- produces their values.
-- @returns {Observable}
function Observable:flatten()
  return Observable.create(function(observer)
    local subscriptions = {}
    local remaining = 1

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      remaining = remaining - 1
      if remaining == 0 then
        return observer:onCompleted()
      end
    end

    local function onNext(observable)
      local function innerOnNext(...)
        observer:onNext(...)
      end

      remaining = remaining + 1
      local subscription = observable:subscribe(innerOnNext, onError, onCompleted)
      subscriptions[#subscriptions + 1] = subscription
    end

    subscriptions[#subscriptions + 1] = self:subscribe(onNext, onError, onCompleted)
    return Subscription.create(function ()
      for i = 1, #subscriptions do
        subscriptions[i]:unsubscribe()
      end
    end)
  end)
end

--- Returns an Observable that terminates when the source terminates but does not produce any
-- elements.
-- @returns {Observable}
function Observable:ignoreElements()
  return Observable.create(function(observer)
    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(nil, onError, onCompleted)
  end)
end

--- Returns a new Observable that only produces the last result of the original.
-- @returns {Observable}
function Observable:last()
  return Observable.create(function(observer)
    local value
    local empty = true

    local function onNext(...)
      value = {...}
      empty = false
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      if not empty then
        observer:onNext(util.unpack(value or {}))
      end

      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the values of the original transformed by a function.
-- @arg {function} callback - The function to transform values from the original Observable.
-- @returns {Observable}
function Observable:map(callback)
  return Observable.create(function(observer)
    callback = callback or util.identity

    local function onNext(...)
      return util.tryWithObserver(observer, function(...)
        return observer:onNext(callback(...))
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the maximum value produced by the original.
-- @returns {Observable}
function Observable:max()
  return self:reduce(math.max)
end

--- Returns a new Observable that produces the values produced by all the specified Observables in
-- the order they are produced.
-- @arg {Observable...} sources - One or more Observables to merge.
-- @returns {Observable}
function Observable:merge(...)
  local sources = {...}
  table.insert(sources, 1, self)

  return Observable.create(function(observer)
    local completed = {}
    local subscriptions = {}

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted(i)
      return function()
        table.insert(completed, i)

        if #completed == #sources then
          observer:onCompleted()
        end
      end
    end

    for i = 1, #sources do
      subscriptions[i] = sources[i]:subscribe(onNext, onError, onCompleted(i))
    end

    return Subscription.create(function ()
      for i = 1, #sources do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end

--- Returns a new Observable that produces the minimum value produced by the original.
-- @returns {Observable}
function Observable:min()
  return self:reduce(math.min)
end

--- Returns an Observable that produces the values of the original inside tables.
-- @returns {Observable}
function Observable:pack()
  return self:map(util.pack)
end

--- Returns two Observables: one that produces values for which the predicate returns truthy for,
-- and another that produces values for which the predicate returns falsy.
-- @arg {function} predicate - The predicate used to partition the values.
-- @returns {Observable}
-- @returns {Observable}
function Observable:partition(predicate)
  return self:filter(predicate), self:reject(predicate)
end

--- Returns a new Observable that produces values computed by extracting the given keys from the
-- tables produced by the original.
-- @arg {string...} keys - The key to extract from the table. Multiple keys can be specified to
--                         recursively pluck values from nested tables.
-- @returns {Observable}
function Observable:pluck(key, ...)
  if not key then return self end

  if type(key) ~= 'string' and type(key) ~= 'number' then
    return Observable.throw('pluck key must be a string')
  end

  return Observable.create(function(observer)
    local function onNext(t)
      return observer:onNext(t[key])
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end):pluck(...)
end

--- Returns a new Observable that produces a single value computed by accumulating the results of
-- running a function on each value produced by the original Observable.
-- @arg {function} accumulator - Accumulates the values of the original Observable. Will be passed
--                               the return value of the last call as the first argument and the
--                               current values as the rest of the arguments.
-- @arg {*} seed - A value to pass to the accumulator the first time it is run.
-- @returns {Observable}
function Observable:reduce(accumulator, seed)
  return Observable.create(function(observer)
    local result = seed
    local first = true

    local function onNext(...)
      if first and seed == nil then
        result = ...
        first = false
      else
        return util.tryWithObserver(observer, function(...)
          result = accumulator(result, ...)
        end, ...)
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(result)
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces values from the original which do not satisfy a
-- predicate.
-- @arg {function} predicate - The predicate used to reject values.
-- @returns {Observable}
function Observable:reject(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if not predicate(...) then
          return observer:onNext(...)
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that restarts in the event of an error.
-- @arg {number=} count - The maximum number of times to retry.  If left unspecified, an infinite
--                        number of retries will be attempted.
-- @returns {Observable}
function Observable:retry(count)
  return Observable.create(function(observer)
    local subscription
    local retries = 0

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function onError(message)
      if subscription then
        subscription:unsubscribe()
      end

      retries = retries + 1
      if count and retries > count then
        return observer:onError(message)
      end

      subscription = self:subscribe(onNext, onError, onCompleted)
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces its most recent value every time the specified observable
-- produces a value.
-- @arg {Observable} sampler - The Observable that is used to sample values from this Observable.
-- @returns {Observable}
function Observable:sample(sampler)
  if not sampler then error('Expected an Observable') end

  return Observable.create(function(observer)
    local latest = {}

    local function setLatest(...)
      latest = util.pack(...)
    end

    local function onNext()
      if #latest > 0 then
        return observer:onNext(util.unpack(latest))
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local sourceSubscription = self:subscribe(setLatest, onError)
    local sampleSubscription = sampler:subscribe(onNext, onError, onCompleted)

    return Subscription.create(function()
      if sourceSubscription then sourceSubscription:unsubscribe() end
      if sampleSubscription then sampleSubscription:unsubscribe() end
    end)
  end)
end

--- Returns a new Observable that produces values computed by accumulating the results of running a
-- function on each value produced by the original Observable.
-- @arg {function} accumulator - Accumulates the values of the original Observable. Will be passed
--                               the return value of the last call as the first argument and the
--                               current values as the rest of the arguments.  Each value returned
--                               from this function will be emitted by the Observable.
-- @arg {*} seed - A value to pass to the accumulator the first time it is run.
-- @returns {Observable}
function Observable:scan(accumulator, seed)
  return Observable.create(function(observer)
    local result = seed
    local first = true

    local function onNext(...)
      if first and seed == nil then
        result = ...
        first = false
      else
        return util.tryWithObserver(observer, function(...)
          result = accumulator(result, ...)
          observer:onNext(result)
        end, ...)
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that skips over a specified number of values produced by the original
-- and produces the rest.
-- @arg {number=1} n - The number of values to ignore.
-- @returns {Observable}
function Observable:skip(n)
  n = n or 1

  return Observable.create(function(observer)
    local i = 1

    local function onNext(...)
      if i > n then
        observer:onNext(...)
      else
        i = i + 1
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that omits a specified number of values from the end of the original
-- Observable.
-- @arg {number} count - The number of items to omit from the end.
-- @returns {Observable}
function Observable:skipLast(count)
  if not count or type(count) ~= 'number' then
    error('Expected a number')
  end

  local buffer = {}
  return Observable.create(function(observer)
    local function emit()
      if #buffer > count and buffer[1] then
        local values = table.remove(buffer, 1)
        observer:onNext(util.unpack(values))
      end
    end

    local function onNext(...)
      emit()
      table.insert(buffer, util.pack(...))
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      emit()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that skips over values produced by the original until the specified
-- Observable produces a value.
-- @arg {Observable} other - The Observable that triggers the production of values.
-- @returns {Observable}
function Observable:skipUntil(other)
  return Observable.create(function(observer)
    local triggered = false
    local function trigger()
      triggered = true
    end

    other:subscribe(trigger, trigger, trigger)

    local function onNext(...)
      if triggered then
        observer:onNext(...)
      end
    end

    local function onError()
      if triggered then
        observer:onError()
      end
    end

    local function onCompleted()
      if triggered then
        observer:onCompleted()
      end
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that skips elements until the predicate returns falsy for one of them.
-- @arg {function} predicate - The predicate used to continue skipping values.
-- @returns {Observable}
function Observable:skipWhile(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local skipping = true

    local function onNext(...)
      if skipping then
        util.tryWithObserver(observer, function(...)
          skipping = predicate(...)
        end, ...)
      end

      if not skipping then
        return observer:onNext(...)
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the specified values followed by all elements produced by
-- the source Observable.
-- @arg {*...} values - The values to produce before the Observable begins producing values
--                      normally.
-- @returns {Observable}
function Observable:startWith(...)
  local values = util.pack(...)
  return Observable.create(function(observer)
    observer:onNext(util.unpack(values))
    return self:subscribe(observer)
  end)
end

--- Returns an Observable that produces a single value representing the sum of the values produced
-- by the original.
-- @returns {Observable}
function Observable:sum()
  return self:reduce(function(x, y) return x + y end, 0)
end

--- Given an Observable that produces Observables, returns an Observable that produces the values
-- produced by the most recently produced Observable.
-- @returns {Observable}
function Observable:switch()
  return Observable.create(function(observer)
    local innerSubscription

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function switch(source)
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      innerSubscription = source:subscribe(onNext, onError, nil)
    end

    local subscription = self:subscribe(switch, onError, onCompleted)
    return Subscription.create(function()
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      if subscription then
        subscription:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that only produces the first n results of the original.
-- @arg {number=1} n - The number of elements to produce before completing.
-- @returns {Observable}
function Observable:take(n)
  n = n or 1

  return Observable.create(function(observer)
    if n <= 0 then
      observer:onCompleted()
      return
    end

    local i = 1

    local function onNext(...)
      observer:onNext(...)

      i = i + 1

      if i > n then
        observer:onCompleted()
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces a specified number of elements from the end of a source
-- Observable.
-- @arg {number} count - The number of elements to produce.
-- @returns {Observable}
function Observable:takeLast(count)
  if not count or type(count) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local buffer = {}

    local function onNext(...)
      table.insert(buffer, util.pack(...))
      if #buffer > count then
        table.remove(buffer, 1)
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      for i = 1, #buffer do
        observer:onNext(util.unpack(buffer[i]))
      end
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that completes when the specified Observable fires.
-- @arg {Observable} other - The Observable that triggers completion of the original.
-- @returns {Observable}
function Observable:takeUntil(other)
  return Observable.create(function(observer)
    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    other:subscribe(onCompleted, onCompleted, onCompleted)

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces elements until the predicate returns falsy.
-- @arg {function} predicate - The predicate used to continue production of values.
-- @returns {Observable}
function Observable:takeWhile(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local taking = true

    local function onNext(...)
      if taking then
        util.tryWithObserver(observer, function(...)
          taking = predicate(...)
        end, ...)

        if taking then
          return observer:onNext(...)
        else
          return observer:onCompleted()
        end
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Runs a function each time this Observable has activity. Similar to subscribe but does not
-- create a subscription.
-- @arg {function=} onNext - Run when the Observable produces values.
-- @arg {function=} onError - Run when the Observable encounters a problem.
-- @arg {function=} onCompleted - Run when the Observable completes.
-- @returns {Observable}
function Observable:tap(_onNext, _onError, _onCompleted)
  _onNext = _onNext or util.noop
  _onError = _onError or util.noop
  _onCompleted = _onCompleted or util.noop

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        _onNext(...)
      end, ...)

      return observer:onNext(...)
    end

    local function onError(message)
      util.tryWithObserver(observer, function()
        _onError(message)
      end)

      return observer:onError(message)
    end

    local function onCompleted()
      util.tryWithObserver(observer, function()
        _onCompleted()
      end)

      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that unpacks the tables produced by the original.
-- @returns {Observable}
function Observable:unpack()
  return self:map(util.unpack)
end

--- Returns an Observable that takes any values produced by the original that consist of multiple
-- return values and produces each value individually.
-- @returns {Observable}
function Observable:unwrap()
  return Observable.create(function(observer)
    local function onNext(...)
      local values = {...}
      for i = 1, #values do
        observer:onNext(values[i])
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces a sliding window of the values produced by the original.
-- @arg {number} size - The size of the window. The returned observable will produce this number
--                      of the most recent values as multiple arguments to onNext.
-- @returns {Observable}
function Observable:window(size)
  if not size or type(size) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local window = {}

    local function onNext(value)
      table.insert(window, value)

      if #window >= size then
        observer:onNext(util.unpack(window))
        table.remove(window, 1)
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces values from the original along with the most recently
-- produced value from all other specified Observables. Note that only the first argument from each
-- source Observable is used.
-- @arg {Observable...} sources - The Observables to include the most recent values from.
-- @returns {Observable}
function Observable:with(...)
  local sources = {...}

  return Observable.create(function(observer)
    local latest = setmetatable({}, {__len = util.constant(#sources)})
    local subscriptions = {}

    local function setLatest(i)
      return function(value)
        latest[i] = value
      end
    end

    local function onNext(value)
      return observer:onNext(value, util.unpack(latest))
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    for i = 1, #sources do
      subscriptions[i] = sources[i]:subscribe(setLatest(i), util.noop, util.noop)
    end

    subscriptions[#sources + 1] = self:subscribe(onNext, onError, onCompleted)
    return Subscription.create(function ()
      for i = 1, #sources + 1 do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end

--- Returns an Observable that merges the values produced by the source Observables by grouping them
-- by their index.  The first onNext event contains the first value of all of the sources, the
-- second onNext event contains the second value of all of the sources, and so on.  onNext is called
-- a number of times equal to the number of values produced by the Observable that produces the
-- fewest number of values.
-- @arg {Observable...} sources - The Observables to zip.
-- @returns {Observable}
function Observable.zip(...)
  local sources = util.pack(...)
  local count = #sources

  return Observable.create(function(observer)
    local values = {}
    local active = {}
    local subscriptions = {}
    for i = 1, count do
      values[i] = {n = 0}
      active[i] = true
    end

    local function onNext(i)
      return function(value)
        table.insert(values[i], value)
        values[i].n = values[i].n + 1

        local ready = true
        for i = 1, count do
          if values[i].n == 0 then
            ready = false
            break
          end
        end

        if ready then
          local payload = {}

          for i = 1, count do
            payload[i] = table.remove(values[i], 1)
            values[i].n = values[i].n - 1
          end

          observer:onNext(util.unpack(payload))
        end
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted(i)
      return function()
        active[i] = nil
        if not next(active) or values[i].n == 0 then
          return observer:onCompleted()
        end
      end
    end

    for i = 1, count do
      subscriptions[i] = sources[i]:subscribe(onNext(i), onError, onCompleted(i))
    end

    return Subscription.create(function()
      for i = 1, count do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end

--- @class ImmediateScheduler
-- @description Schedules Observables by running all operations immediately.
local ImmediateScheduler = {}
ImmediateScheduler.__index = ImmediateScheduler
ImmediateScheduler.__tostring = util.constant('ImmediateScheduler')

--- Creates a new ImmediateScheduler.
-- @returns {ImmediateScheduler}
function ImmediateScheduler.create()
  return setmetatable({}, ImmediateScheduler)
end

--- Schedules a function to be run on the scheduler. It is executed immediately.
-- @arg {function} action - The function to execute.
function ImmediateScheduler:schedule(action)
  action()
end

--- @class CooperativeScheduler
-- @description Manages Observables using coroutines and a virtual clock that must be updated
-- manually.
local CooperativeScheduler = {}
CooperativeScheduler.__index = CooperativeScheduler
CooperativeScheduler.__tostring = util.constant('CooperativeScheduler')

--- Creates a new CooperativeScheduler.
-- @arg {number=0} currentTime - A time to start the scheduler at.
-- @returns {CooperativeScheduler}
function CooperativeScheduler.create(currentTime)
  local self = {
    tasks = {},
    currentTime = currentTime or 0
  }

  return setmetatable(self, CooperativeScheduler)
end

--- Schedules a function to be run after an optional delay.  Returns a subscription that will stop
-- the action from running.
-- @arg {function} action - The function to execute. Will be converted into a coroutine. The
--                          coroutine may yield execution back to the scheduler with an optional
--                          number, which will put it to sleep for a time period.
-- @arg {number=0} delay - Delay execution of the action by a virtual time period.
-- @returns {Subscription}
function CooperativeScheduler:schedule(action, delay)
  local task = {
    thread = coroutine.create(action),
    due = self.currentTime + (delay or 0)
  }

  table.insert(self.tasks, task)

  return Subscription.create(function()
    return self:unschedule(task)
  end)
end

function CooperativeScheduler:unschedule(task)
  for i = 1, #self.tasks do
    if self.tasks[i] == task then
      table.remove(self.tasks, i)
    end
  end
end

--- Triggers an update of the CooperativeScheduler. The clock will be advanced and the scheduler
-- will run any coroutines that are due to be run.
-- @arg {number=0} delta - An amount of time to advance the clock by. It is common to pass in the
--                         time in seconds or milliseconds elapsed since this function was last
--                         called.
function CooperativeScheduler:update(delta)
  self.currentTime = self.currentTime + (delta or 0)

  local i = 1
  while i <= #self.tasks do
    local task = self.tasks[i]

    if self.currentTime >= task.due then
      local success, delay = coroutine.resume(task.thread)

      if coroutine.status(task.thread) == 'dead' then
        table.remove(self.tasks, i)
      else
        task.due = math.max(task.due + (delay or 0), self.currentTime)
        i = i + 1
      end

      if not success then
        error(delay)
      end
    else
      i = i + 1
    end
  end
end

--- Returns whether or not the CooperativeScheduler's queue is empty.
function CooperativeScheduler:isEmpty()
  return not next(self.tasks)
end

--- @class TimeoutScheduler
-- @description A scheduler that uses luvit's timer library to schedule events on an event loop.
local TimeoutScheduler = {}
TimeoutScheduler.__index = TimeoutScheduler
TimeoutScheduler.__tostring = util.constant('TimeoutScheduler')

--- Creates a new TimeoutScheduler.
-- @returns {TimeoutScheduler}
function TimeoutScheduler.create()
  return setmetatable({}, TimeoutScheduler)
end

--- Schedules an action to run at a future point in time.
-- @arg {function} action - The action to run.
-- @arg {number=0} delay - The delay, in milliseconds.
-- @returns {Subscription}
function TimeoutScheduler:schedule(action, delay, ...)
  local timer = require 'timer'
  local subscription
  local handle = timer.setTimeout(delay, action, ...)
  return Subscription.create(function()
    timer.clearTimeout(handle)
  end)
end

--- @class Subject
-- @description Subjects function both as an Observer and as an Observable. Subjects inherit all
-- Observable functions, including subscribe. Values can also be pushed to the Subject, which will
-- be broadcasted to any subscribed Observers.
local Subject = setmetatable({}, Observable)
Subject.__index = Subject
Subject.__tostring = util.constant('Subject')

--- Creates a new Subject.
-- @returns {Subject}
function Subject.create()
  local self = {
    observers = {},
    stopped = false
  }

  return setmetatable(self, Subject)
end

--- Creates a new Observer and attaches it to the Subject.
-- @arg {function|table} onNext|observer - A function called when the Subject produces a value or
--                                         an existing Observer to attach to the Subject.
-- @arg {function} onError - Called when the Subject terminates due to an error.
-- @arg {function} onCompleted - Called when the Subject completes normally.
function Subject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  table.insert(self.observers, observer)

  return Subscription.create(function()
    for i = 1, #self.observers do
      if self.observers[i] == observer then
        table.remove(self.observers, i)
        return
      end
    end
  end)
end

--- Pushes zero or more values to the Subject. They will be broadcasted to all Observers.
-- @arg {*...} values
function Subject:onNext(...)
  if not self.stopped then
    for i = #self.observers, 1, -1 do
      self.observers[i]:onNext(...)
    end
  end
end

--- Signal to all Observers that an error has occurred.
-- @arg {string=} message - A string describing what went wrong.
function Subject:onError(message)
  if not self.stopped then
    for i = #self.observers, 1, -1 do
      self.observers[i]:onError(message)
    end

    self.stopped = true
  end
end

--- Signal to all Observers that the Subject will not produce any more values.
function Subject:onCompleted()
  if not self.stopped then
    for i = #self.observers, 1, -1 do
      self.observers[i]:onCompleted()
    end

    self.stopped = true
  end
end

Subject.__call = Subject.onNext

--- @class AsyncSubject
-- @description AsyncSubjects are subjects that produce either no values or a single value.  If
-- multiple values are produced via onNext, only the last one is used.  If onError is called, then
-- no value is produced and onError is called on any subscribed Observers.  If an Observer
-- subscribes and the AsyncSubject has already terminated, the Observer will immediately receive the
-- value or the error.
local AsyncSubject = setmetatable({}, Observable)
AsyncSubject.__index = AsyncSubject
AsyncSubject.__tostring = util.constant('AsyncSubject')

--- Creates a new AsyncSubject.
-- @returns {AsyncSubject}
function AsyncSubject.create()
  local self = {
    observers = {},
    stopped = false,
    value = nil,
    errorMessage = nil
  }

  return setmetatable(self, AsyncSubject)
end

--- Creates a new Observer and attaches it to the AsyncSubject.
-- @arg {function|table} onNext|observer - A function called when the AsyncSubject produces a value
--                                         or an existing Observer to attach to the AsyncSubject.
-- @arg {function} onError - Called when the AsyncSubject terminates due to an error.
-- @arg {function} onCompleted - Called when the AsyncSubject completes normally.
function AsyncSubject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  if self.value then
    observer:onNext(util.unpack(self.value))
    observer:onCompleted()
    return
  elseif self.errorMessage then
    observer:onError(self.errorMessage)
    return
  end

  table.insert(self.observers, observer)

  return Subscription.create(function()
    for i = 1, #self.observers do
      if self.observers[i] == observer then
        table.remove(self.observers, i)
        return
      end
    end
  end)
end

--- Pushes zero or more values to the AsyncSubject.
-- @arg {*...} values
function AsyncSubject:onNext(...)
  if not self.stopped then
    self.value = util.pack(...)
  end
end

--- Signal to all Observers that an error has occurred.
-- @arg {string=} message - A string describing what went wrong.
function AsyncSubject:onError(message)
  if not self.stopped then
    self.errorMessage = message

    for i = 1, #self.observers do
      self.observers[i]:onError(self.errorMessage)
    end

    self.stopped = true
  end
end

--- Signal to all Observers that the AsyncSubject will not produce any more values.
function AsyncSubject:onCompleted()
  if not self.stopped then
    for i = 1, #self.observers do
      if self.value then
        self.observers[i]:onNext(util.unpack(self.value))
      end

      self.observers[i]:onCompleted()
    end

    self.stopped = true
  end
end

AsyncSubject.__call = AsyncSubject.onNext

--- @class BehaviorSubject
-- @description A Subject that tracks its current value. Provides an accessor to retrieve the most
-- recent pushed value, and all subscribers immediately receive the latest value.
local BehaviorSubject = setmetatable({}, Subject)
BehaviorSubject.__index = BehaviorSubject
BehaviorSubject.__tostring = util.constant('BehaviorSubject')

--- Creates a new BehaviorSubject.
-- @arg {*...} value - The initial values.
-- @returns {BehaviorSubject}
function BehaviorSubject.create(...)
  local self = {
    observers = {},
    stopped = false
  }

  if select('#', ...) > 0 then
    self.value = util.pack(...)
  end

  return setmetatable(self, BehaviorSubject)
end

--- Creates a new Observer and attaches it to the BehaviorSubject. Immediately broadcasts the most
-- recent value to the Observer.
-- @arg {function} onNext - Called when the BehaviorSubject produces a value.
-- @arg {function} onError - Called when the BehaviorSubject terminates due to an error.
-- @arg {function} onCompleted - Called when the BehaviorSubject completes normally.
function BehaviorSubject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  local subscription = Subject.subscribe(self, observer)

  if self.value then
    observer:onNext(util.unpack(self.value))
  end

  return subscription
end

--- Pushes zero or more values to the BehaviorSubject. They will be broadcasted to all Observers.
-- @arg {*...} values
function BehaviorSubject:onNext(...)
  self.value = util.pack(...)
  return Subject.onNext(self, ...)
end

--- Returns the last value emitted by the BehaviorSubject, or the initial value passed to the
-- constructor if nothing has been emitted yet.
-- @returns {*...}
function BehaviorSubject:getValue()
  if self.value ~= nil then
    return util.unpack(self.value)
  end
end

BehaviorSubject.__call = BehaviorSubject.onNext

--- @class ReplaySubject
-- @description A Subject that provides new Subscribers with some or all of the most recently
-- produced values upon subscription.
local ReplaySubject = setmetatable({}, Subject)
ReplaySubject.__index = ReplaySubject
ReplaySubject.__tostring = util.constant('ReplaySubject')

--- Creates a new ReplaySubject.
-- @arg {number=} bufferSize - The number of values to send to new subscribers. If nil, an infinite
--                             buffer is used (note that this could lead to memory issues).
-- @returns {ReplaySubject}
function ReplaySubject.create(n)
  local self = {
    observers = {},
    stopped = false,
    buffer = {},
    bufferSize = n
  }

  return setmetatable(self, ReplaySubject)
end

--- Creates a new Observer and attaches it to the ReplaySubject. Immediately broadcasts the most
-- contents of the buffer to the Observer.
-- @arg {function} onNext - Called when the ReplaySubject produces a value.
-- @arg {function} onError - Called when the ReplaySubject terminates due to an error.
-- @arg {function} onCompleted - Called when the ReplaySubject completes normally.
function ReplaySubject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  local subscription = Subject.subscribe(self, observer)

  for i = 1, #self.buffer do
    observer:onNext(util.unpack(self.buffer[i]))
  end

  return subscription
end

--- Pushes zero or more values to the ReplaySubject. They will be broadcasted to all Observers.
-- @arg {*...} values
function ReplaySubject:onNext(...)
  table.insert(self.buffer, util.pack(...))
  if self.bufferSize and #self.buffer > self.bufferSize then
    table.remove(self.buffer, 1)
  end

  return Subject.onNext(self, ...)
end

ReplaySubject.__call = ReplaySubject.onNext

Observable.wrap = Observable.buffer
Observable['repeat'] = Observable.replicate

return {
  util = util,
  Subscription = Subscription,
  Observer = Observer,
  Observable = Observable,
  ImmediateScheduler = ImmediateScheduler,
  CooperativeScheduler = CooperativeScheduler,
  TimeoutScheduler = TimeoutScheduler,
  Subject = Subject,
  AsyncSubject = AsyncSubject,
  BehaviorSubject = BehaviorSubject,
  ReplaySubject = ReplaySubject
} end)
package.preload['tiny'] = (function (...)
--[[
Copyright (c) 2016 Calvin Rose

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

--- @module tiny-ecs
-- @author Calvin Rose
-- @license MIT
-- @copyright 2016
local tiny = {}

-- Local versions of standard lua functions
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local setmetatable = setmetatable
local type = type
local select = select

-- Local versions of the library functions
local tiny_manageEntities
local tiny_manageSystems
local tiny_addEntity
local tiny_addSystem
local tiny_add
local tiny_removeEntity
local tiny_removeSystem

--- Filter functions.
-- A Filter is a function that selects which Entities apply to a System.
-- Filters take two parameters, the System and the Entity, and return a boolean
-- value indicating if the Entity should be processed by the System. A truthy
-- value includes the entity, while a falsey (nil or false) value excludes the
-- entity.
--
-- Filters must be added to Systems by setting the `filter` field of the System.
-- Filter's returned by tiny-ecs's Filter functions are immutable and can be
-- used by multiple Systems.
--
--    local f1 = tiny.requireAll("position", "velocity", "size")
--    local f2 = tiny.requireAny("position", "velocity", "size")
--
--    local e1 = {
--        position = {2, 3},
--        velocity = {3, 3},
--        size = {4, 4}
--    }
--
--    local entity2 = {
--        position = {4, 5},
--        size = {4, 4}
--    }
--
--    local e3 = {
--        position = {2, 3},
--        velocity = {3, 3}
--    }
--
--    print(f1(nil, e1), f1(nil, e2), f1(nil, e3)) -- prints true, false, false
--    print(f2(nil, e1), f2(nil, e2), f2(nil, e3)) -- prints true, true, true
--
-- Filters can also be passed as arguments to other Filter constructors. This is
-- a powerful way to create complex, custom Filters that select a very specific
-- set of Entities.
--
--    -- Selects Entities with an "image" Component, but not Entities with a
--    -- "Player" or "Enemy" Component.
--    filter = tiny.requireAll("image", tiny.rejectAny("Player", "Enemy"))
--
-- @section Filter

-- A helper function to compile filters.
local filterJoin

-- A helper function to filters from string
local filterBuildString

do

    local loadstring = loadstring or load
    local function getchr(c)
        return "\\" .. c:byte()
    end
    local function make_safe(text)
        return ("%q"):format(text):gsub('\n', 'n'):gsub("[\128-\255]", getchr)
    end

    local function filterJoinRaw(prefix, seperator, ...)
        local accum = {}
        local build = {}
        for i = 1, select('#', ...) do
            local item = select(i, ...)
            if type(item) == 'string' then
                accum[#accum + 1] = ("(e[%s] ~= nil)"):format(make_safe(item))
            elseif type(item) == 'function' then
                build[#build + 1] = ('local subfilter_%d_ = select(%d, ...)')
                    :format(i, i)
                accum[#accum + 1] = ('(subfilter_%d_(system, e))'):format(i)
            else
                error 'Filter token must be a string or a filter function.'
            end
        end
        local source = ('%s\nreturn function(system, e) return %s(%s) end')
            :format(
                table.concat(build, '\n'),
                prefix,
                table.concat(accum, seperator))
        local loader, err = loadstring(source)
        if err then error(err) end
        return loader(...)
    end

    function filterJoin(...)
        local state, value = pcall(filterJoinRaw, ...)
        if state then return value else return nil, value end
    end

    local function buildPart(str)
        local accum = {}
        local subParts = {}
        str = str:gsub('%b()', function(p)
            subParts[#subParts + 1] = buildPart(p:sub(2, -2))
            return ('\255%d'):format(#subParts)
        end)
        for invert, part, sep in str:gmatch('(%!?)([^%|%&%!]+)([%|%&]?)') do
            if part:match('^\255%d+$') then
                local partIndex = tonumber(part:match(part:sub(2)))
                accum[#accum + 1] = ('%s(%s)')
                    :format(invert == '' and '' or 'not', subParts[partIndex])
            else
                accum[#accum + 1] = ("(e[%s] %s nil)")
                    :format(make_safe(part), invert == '' and '~=' or '==')
            end
            if sep ~= '' then
                accum[#accum + 1] = (sep == '|' and ' or ' or ' and ')
            end
        end
        return table.concat(accum)
    end

    function filterBuildString(str)
        local source = ("return function(_, e) return %s end")
            :format(buildPart(str))
        local loader, err = loadstring(source)
        if err then
            error(err)
        end
        return loader()
    end

end

--- Makes a Filter that selects Entities with all specified Components and
-- Filters.
function tiny.requireAll(...)
    return filterJoin('', ' and ', ...)
end

--- Makes a Filter that selects Entities with at least one of the specified
-- Components and Filters.
function tiny.requireAny(...)
    return filterJoin('', ' or ', ...)
end

--- Makes a Filter that rejects Entities with all specified Components and
-- Filters, and selects all other Entities.
function tiny.rejectAll(...)
    return filterJoin('not', ' and ', ...)
end

--- Makes a Filter that rejects Entities with at least one of the specified
-- Components and Filters, and selects all other Entities.
function tiny.rejectAny(...)
    return filterJoin('not', ' or ', ...)
end

--- Makes a Filter from a string. Syntax of `pattern` is as follows.
--
--   * Tokens are alphanumeric strings including underscores.
--   * Tokens can be separated by |, &, or surrounded by parentheses.
--   * Tokens can be prefixed with !, and are then inverted.
--
-- Examples are best:
--    'a|b|c' - Matches entities with an 'a' OR 'b' OR 'c'.
--    'a&!b&c' - Matches entities with an 'a' AND NOT 'b' AND 'c'.
--    'a|(b&c&d)|e - Matches 'a' OR ('b' AND 'c' AND 'd') OR 'e'
-- @param pattern
function tiny.filter(pattern)
    local state, value = pcall(filterBuildString, pattern)
    if state then return value else return nil, value end
end

--- System functions.
-- A System is a wrapper around function callbacks for manipulating Entities.
-- Systems are implemented as tables that contain at least one method;
-- an update function that takes parameters like so:
--
--   * `function system:update(dt)`.
--
-- There are also a few other optional callbacks:
--
--   * `function system:filter(entity)` - Returns true if this System should
-- include this Entity, otherwise should return false. If this isn't specified,
-- no Entities are included in the System.
--   * `function system:onAdd(entity)` - Called when an Entity is added to the
-- System.
--   * `function system:onRemove(entity)` - Called when an Entity is removed
-- from the System.
--   * `function system:onModify(dt)` - Called when the System is modified by
-- adding or removing Entities from the System.
--   * `function system:onAddToWorld(world)` - Called when the System is added
-- to the World, before any entities are added to the system.
--   * `function system:onRemoveFromWorld(world)` - Called when the System is
-- removed from the world, after all Entities are removed from the System.
--   * `function system:preWrap(dt)` - Called on each system before update is
-- called on any system.
--   * `function system:postWrap(dt)` - Called on each system in reverse order
-- after update is called on each system. The idea behind `preWrap` and
-- `postWrap` is to allow for systems that modify the behavior of other systems.
-- Say there is a DrawingSystem, which draws sprites to the screen, and a
-- PostProcessingSystem, that adds some blur and bloom effects. In the preWrap
-- method of the PostProcessingSystem, the System could set the drawing target
-- for the DrawingSystem to a special buffer instead the screen. In the postWrap
-- method, the PostProcessingSystem could then modify the buffer and render it
-- to the screen. In this setup, the PostProcessingSystem would be added to the
-- World after the drawingSystem (A similar but less flexible behavior could
-- be accomplished with a single custom update function in the DrawingSystem).
--
-- For Filters, it is convenient to use `tiny.requireAll` or `tiny.requireAny`,
-- but one can write their own filters as well. Set the Filter of a System like
-- so:
--    system.filter = tiny.requireAll("a", "b", "c")
-- or
--    function system:filter(entity)
--        return entity.myRequiredComponentName ~= nil
--    end
--
-- All Systems also have a few important fields that are initialized when the
-- system is added to the World. A few are important, and few should be less
-- commonly used.
--
--   * The `world` field points to the World that the System belongs to. Useful
-- for adding and removing Entities from the world dynamically via the System.
--   * The `active` flag is whether or not the System is updated automatically.
-- Inactive Systems should be updated manually or not at all via
-- `system:update(dt)`. Defaults to true.
--   * The `entities` field is an ordered list of Entities in the System. This
-- list can be used to quickly iterate through all Entities in a System.
--   * The `interval` field is an optional field that makes Systems update at
-- certain intervals using buffered time, regardless of World update frequency.
-- For example, to make a System update once a second, set the System's interval
-- to 1.
--   * The `index` field is the System's index in the World. Lower indexed
-- Systems are processed before higher indices. The `index` is a read only
-- field; to set the `index`, use `tiny.setSystemIndex(world, system)`.
--   * The `indices` field is a table of Entity keys to their indices in the
-- `entities` list. Most Systems can ignore this.
--   * The `modified` flag is an indicator if the System has been modified in
-- the last update. If so, the `onModify` callback will be called on the System
-- in the next update, if it has one. This is usually managed by tiny-ecs, so
-- users should mostly ignore this, too.
--
-- There is another option to (hopefully) increase performance in systems that
-- have items added to or removed from them often, and have lots of entities in
-- them.  Setting the `nocache` field of the system might improve performance.
-- It is still experimental. There are some restriction to systems without
-- caching, however.
--
--   * There is no `entities` table.
--   * Callbacks such onAdd, onRemove, and onModify will never be called
--   * Noncached systems cannot be sorted (There is no entities list to sort).
--
-- @section System

-- Use an empty table as a key for identifying Systems. Any table that contains
-- this key is considered a System rather than an Entity.
local systemTableKey = { "SYSTEM_TABLE_KEY" }

-- Checks if a table is a System.
local function isSystem(table)
    return table[systemTableKey]
end

-- Update function for all Processing Systems.
local function processingSystemUpdate(system, dt)
    local preProcess = system.preProcess
    local process = system.process
    local postProcess = system.postProcess

    if preProcess then
        preProcess(system, dt)
    end

    if process then
        if system.nocache then
            local entities = system.world.entities
            local filter = system.filter
            if filter then
                for i = 1, #entities do
                    local entity = entities[i]
                    if filter(system, entity) then
                        process(system, entity, dt)
                    end
                end
            end
        else
            local entities = system.entities
            for i = 1, #entities do
                process(system, entities[i], dt)
            end
        end
    end

    if postProcess then
        postProcess(system, dt)
    end
end

-- Sorts Systems by a function system.sortDelegate(entity1, entity2) on modify.
local function sortedSystemOnModify(system)
    local entities = system.entities
    local indices = system.indices
    local sortDelegate = system.sortDelegate
    if not sortDelegate then
        local compare = system.compare
        sortDelegate = function(e1, e2)
            return compare(system, e1, e2)
        end
        system.sortDelegate = sortDelegate
    end
    tsort(entities, sortDelegate)
    for i = 1, #entities do
        indices[entities[i]] = i
    end
end

--- Creates a new System or System class from the supplied table. If `table` is
-- nil, creates a new table.
function tiny.system(table)
    table = table or {}
    table[systemTableKey] = true
    return table
end

--- Creates a new Processing System or Processing System class. Processing
-- Systems process each entity individual, and are usually what is needed.
-- Processing Systems have three extra callbacks besides those inheritted from
-- vanilla Systems.
--
--     function system:preProcess(dt) -- Called before iteration.
--     function system:process(entity, dt) -- Process each entity.
--     function system:postProcess(dt) -- Called after iteration.
--
-- Processing Systems have their own `update` method, so don't implement a
-- a custom `update` callback for Processing Systems.
-- @see system
function tiny.processingSystem(table)
    table = table or {}
    table[systemTableKey] = true
    table.update = processingSystemUpdate
    return table
end

--- Creates a new Sorted System or Sorted System class. Sorted Systems sort
-- their Entities according to a user-defined method, `system:compare(e1, e2)`,
-- which should return true if `e1` should come before `e2` and false otherwise.
-- Sorted Systems also override the default System's `onModify` callback, so be
-- careful if defining a custom callback. However, for processing the sorted
-- entities, consider `tiny.sortedProcessingSystem(table)`.
-- @see system
function tiny.sortedSystem(table)
    table = table or {}
    table[systemTableKey] = true
    table.onModify = sortedSystemOnModify
    return table
end

--- Creates a new Sorted Processing System or Sorted Processing System class.
-- Sorted Processing Systems have both the aspects of Processing Systems and
-- Sorted Systems.
-- @see system
-- @see processingSystem
-- @see sortedSystem
function tiny.sortedProcessingSystem(table)
    table = table or {}
    table[systemTableKey] = true
    table.update = processingSystemUpdate
    table.onModify = sortedSystemOnModify
    return table
end

--- World functions.
-- A World is a container that manages Entities and Systems. Typically, a
-- program uses one World at a time.
--
-- For all World functions except `tiny.world(...)`, object-oriented syntax can
-- be used instead of the documented syntax. For example,
-- `tiny.add(world, e1, e2, e3)` is the same as `world:add(e1, e2, e3)`.
-- @section World

-- Forward declaration
local worldMetaTable

--- Creates a new World.
-- Can optionally add default Systems and Entities. Returns the new World along
-- with default Entities and Systems.
function tiny.world(...)
    local ret = setmetatable({

        -- List of Entities to remove
        entitiesToRemove = {},

        -- List of Entities to change
        entitiesToChange = {},

        -- List of Entities to add
        systemsToAdd = {},

        -- List of Entities to remove
        systemsToRemove = {},

        -- Set of Entities
        entities = {},

        -- List of Systems
        systems = {}

    }, worldMetaTable)

    tiny_add(ret, ...)
    tiny_manageSystems(ret)
    tiny_manageEntities(ret)

    return ret, ...
end

--- Adds an Entity to the world.
-- Also call this on Entities that have changed Components such that they
-- match different Filters. Returns the Entity.
function tiny.addEntity(world, entity)
    local e2c = world.entitiesToChange
    e2c[#e2c + 1] = entity
    return entity
end
tiny_addEntity = tiny.addEntity

--- Adds a System to the world. Returns the System.
function tiny.addSystem(world, system)
    assert(system.world == nil, "System already belongs to a World.")
    local s2a = world.systemsToAdd
    s2a[#s2a + 1] = system
    system.world = world
    return system
end
tiny_addSystem = tiny.addSystem

--- Shortcut for adding multiple Entities and Systems to the World. Returns all
-- added Entities and Systems.
function tiny.add(world, ...)
    for i = 1, select("#", ...) do
        local obj = select(i, ...)
        if obj then
            if isSystem(obj) then
                tiny_addSystem(world, obj)
            else -- Assume obj is an Entity
                tiny_addEntity(world, obj)
            end
        end
    end
    return ...
end
tiny_add = tiny.add

--- Removes an Entity from the World. Returns the Entity.
function tiny.removeEntity(world, entity)
    local e2r = world.entitiesToRemove
    e2r[#e2r + 1] = entity
    return entity
end
tiny_removeEntity = tiny.removeEntity

--- Removes a System from the world. Returns the System.
function tiny.removeSystem(world, system)
    assert(system.world == world, "System does not belong to this World.")
    local s2r = world.systemsToRemove
    s2r[#s2r + 1] = system
    return system
end
tiny_removeSystem = tiny.removeSystem

--- Shortcut for removing multiple Entities and Systems from the World. Returns
-- all removed Systems and Entities
function tiny.remove(world, ...)
    for i = 1, select("#", ...) do
        local obj = select(i, ...)
        if obj then
            if isSystem(obj) then
                tiny_removeSystem(world, obj)
            else -- Assume obj is an Entity
                tiny_removeEntity(world, obj)
            end
        end
    end
    return ...
end

-- Adds and removes Systems that have been marked from the World.
function tiny_manageSystems(world)
    local s2a, s2r = world.systemsToAdd, world.systemsToRemove

    -- Early exit
    if #s2a == 0 and #s2r == 0 then
        return
    end

    world.systemsToAdd = {}
    world.systemsToRemove = {}

    local worldEntityList = world.entities
    local systems = world.systems

    -- Remove Systems
    for i = 1, #s2r do
        local system = s2r[i]
        local index = system.index
        local onRemove = system.onRemove
        if onRemove and not system.nocache then
            local entityList = system.entities
            for j = 1, #entityList do
                onRemove(system, entityList[j])
            end
        end
        tremove(systems, index)
        for j = index, #systems do
            systems[j].index = j
        end
        local onRemoveFromWorld = system.onRemoveFromWorld
        if onRemoveFromWorld then
            onRemoveFromWorld(system, world)
        end
        s2r[i] = nil

        -- Clean up System
        system.world = nil
        system.entities = nil
        system.indices = nil
        system.index = nil
    end

    -- Add Systems
    for i = 1, #s2a do
        local system = s2a[i]
        if systems[system.index or 0] ~= system then
            if not system.nocache then
                system.entities = {}
                system.indices = {}
            end
            if system.active == nil then
                system.active = true
            end
            system.modified = true
            system.world = world
            local index = #systems + 1
            system.index = index
            systems[index] = system
            local onAddToWorld = system.onAddToWorld
            if onAddToWorld then
                onAddToWorld(system, world)
            end

            -- Try to add Entities
            if not system.nocache then
                local entityList = system.entities
                local entityIndices = system.indices
                local onAdd = system.onAdd
                local filter = system.filter
                if filter then
                    for j = 1, #worldEntityList do
                        local entity = worldEntityList[j]
                        if filter(system, entity) then
                            local entityIndex = #entityList + 1
                            entityList[entityIndex] = entity
                            entityIndices[entity] = entityIndex
                            if onAdd then
                                onAdd(system, entity)
                            end
                        end
                    end
                end
            end
        end
        s2a[i] = nil
    end
end

-- Adds, removes, and changes Entities that have been marked.
function tiny_manageEntities(world)

    local e2r = world.entitiesToRemove
    local e2c = world.entitiesToChange

    -- Early exit
    if #e2r == 0 and #e2c == 0 then
        return
    end

    world.entitiesToChange = {}
    world.entitiesToRemove = {}

    local entities = world.entities
    local systems = world.systems

    -- Change Entities
    for i = 1, #e2c do
        local entity = e2c[i]
        -- Add if needed
        if not entities[entity] then
            local index = #entities + 1
            entities[entity] = index
            entities[index] = entity
        end
        for j = 1, #systems do
            local system = systems[j]
            if not system.nocache then
                local ses = system.entities
                local seis = system.indices
                local index = seis[entity]
                local filter = system.filter
                if filter and filter(system, entity) then
                    if not index then
                        system.modified = true
                        index = #ses + 1
                        ses[index] = entity
                        seis[entity] = index
                        local onAdd = system.onAdd
                        if onAdd then
                            onAdd(system, entity)
                        end
                    end
                elseif index then
                    system.modified = true
                    local tmpEntity = ses[#ses]
                    ses[index] = tmpEntity
                    seis[tmpEntity] = index
                    seis[entity] = nil
                    ses[#ses] = nil
                    local onRemove = system.onRemove
                    if onRemove then
                        onRemove(system, entity)
                    end
                end
            end
        end
        e2c[i] = nil
    end

    -- Remove Entities
    for i = 1, #e2r do
        local entity = e2r[i]
        e2r[i] = nil
        local listIndex = entities[entity]
        if listIndex then
            -- Remove Entity from world state
            local lastEntity = entities[#entities]
            entities[lastEntity] = listIndex
            entities[entity] = nil
            entities[listIndex] = lastEntity
            entities[#entities] = nil
            -- Remove from cached systems
            for j = 1, #systems do
                local system = systems[j]
                if not system.nocache then
                    local ses = system.entities
                    local seis = system.indices
                    local index = seis[entity]
                    if index then
                        system.modified = true
                        local tmpEntity = ses[#ses]
                        ses[index] = tmpEntity
                        seis[tmpEntity] = index
                        seis[entity] = nil
                        ses[#ses] = nil
                        local onRemove = system.onRemove
                        if onRemove then
                            onRemove(system, entity)
                        end
                    end
                end
            end
        end
    end
end

--- Manages Entities and Systems marked for deletion or addition. Call this
-- before modifying Systems and Entities outside of a call to `tiny.update`.
-- Do not call this within a call to `tiny.update`.
function tiny.refresh(world)
    tiny_manageSystems(world)
    tiny_manageEntities(world)
    local systems = world.systems
    for i = #systems, 1, -1 do
        local system = systems[i]
        if system.active then
            local onModify = system.onModify
            if onModify and system.modified then
                onModify(system, 0)
            end
            system.modified = false
        end
    end
end

--- Updates the World by dt (delta time). Takes an optional parameter, `filter`,
-- which is a Filter that selects Systems from the World, and updates only those
-- Systems. If `filter` is not supplied, all Systems are updated. Put this
-- function in your main loop.
function tiny.update(world, dt, filter)

    tiny_manageSystems(world)
    tiny_manageEntities(world)

    local systems = world.systems

    -- Iterate through Systems IN REVERSE ORDER
    for i = #systems, 1, -1 do
        local system = systems[i]
        if system.active then
            -- Call the modify callback on Systems that have been modified.
            local onModify = system.onModify
            if onModify and system.modified then
                onModify(system, dt)
            end
            local preWrap = system.preWrap
            if preWrap and
                ((not filter) or filter(world, system)) then
                preWrap(system, dt)
            end
        end
    end

    --  Iterate through Systems IN ORDER
    for i = 1, #systems do
        local system = systems[i]
        if system.active and ((not filter) or filter(world, system)) then

            -- Update Systems that have an update method (most Systems)
            local update = system.update
            if update then
                local interval = system.interval
                if interval then
                    local bufferedTime = (system.bufferedTime or 0) + dt
                    while bufferedTime >= interval do
                        bufferedTime = bufferedTime - interval
                        update(system, interval)
                    end
                    system.bufferedTime = bufferedTime
                else
                    update(system, dt)
                end
            end

            system.modified = false
        end
    end

    -- Iterate through Systems IN ORDER AGAIN
    for i = 1, #systems do
        local system = systems[i]
        local postWrap = system.postWrap
        if postWrap and system.active and
            ((not filter) or filter(world, system)) then
            postWrap(system, dt)
        end
    end

end

--- Removes all Entities from the World.
function tiny.clearEntities(world)
    local el = world.entities
    for i = 1, #el do
        tiny_removeEntity(world, el[i])
    end
end

--- Removes all Systems from the World.
function tiny.clearSystems(world)
    local systems = world.systems
    for i = #systems, 1, -1 do
        tiny_removeSystem(world, systems[i])
    end
end

--- Gets number of Entities in the World.
function tiny.getEntityCount(world)
    return #world.entities
end

--- Gets number of Systems in World.
function tiny.getSystemCount(world)
    return #world.systems
end

--- Sets the index of a System in the World, and returns the old index. Changes
-- the order in which they Systems processed, because lower indexed Systems are
-- processed first. Returns the old system.index.
function tiny.setSystemIndex(world, system, index)
    local oldIndex = system.index
    local systems = world.systems

    if index < 0 then
        index = tiny.getSystemCount(world) + 1 + index
    end

    tremove(systems, oldIndex)
    tinsert(systems, index, system)

    for i = oldIndex, index, index >= oldIndex and 1 or -1 do
        systems[i].index = i
    end

    return oldIndex
end

-- Construct world metatable.
worldMetaTable = {
    __index = {
        add = tiny.add,
        addEntity = tiny.addEntity,
        addSystem = tiny.addSystem,
        remove = tiny.remove,
        removeEntity = tiny.removeEntity,
        removeSystem = tiny.removeSystem,
        refresh = tiny.refresh,
        update = tiny.update,
        clearEntities = tiny.clearEntities,
        clearSystems = tiny.clearSystems,
        getEntityCount = tiny.getEntityCount,
        getSystemCount = tiny.getSystemCount,
        setSystemIndex = tiny.setSystemIndex
    },
    __tostring = function()
        return "<tiny-ecs_World>"
    end
}

return tiny end)
package.preload['json'] = (function (...)
--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function json.encode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end


return json end)
package.preload['base64'] = (function (...)
--[[
Copyright (c) 2012, Daniel Lindsley
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
* Neither the name of the base64 nor the names of its contributors may be
  used to endorse or promote products derived from this software without
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]


-- Base64-encoding
-- Sourced from http://en.wikipedia.org/wiki/Base64

local __author__ = 'Daniel Lindsley'
local __version__ = 'scm-1'
local __license__ = 'BSD'


local index_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local to_base64
local to_binary
local to_decode
local to_encode
local from_base64
local from_binary


function to_binary(integer)
    local remaining = tonumber(integer)
    local bin_bits = ''

    for i = 7, 0, -1 do
        local current_power = 2 ^ i

        if remaining >= current_power then
            bin_bits = bin_bits .. '1'
            remaining = remaining - current_power
        else
            bin_bits = bin_bits .. '0'
        end
    end

    return bin_bits
end

function from_binary(bin_bits)
    return tonumber(bin_bits, 2)
end


function to_base64(to_encode)
    local bit_pattern = ''
    local encoded = ''
    local trailing = ''

    for i = 1, string.len(to_encode) do
        bit_pattern = bit_pattern .. to_binary(string.byte(string.sub(to_encode, i, i)))
    end

    -- Check the number of bytes. If it's not evenly divisible by three,
    -- zero-pad the ending & append on the correct number of ``=``s.
    if string.len(bit_pattern) % 3 == 2 then
        trailing = '=='
        bit_pattern = bit_pattern .. '0000000000000000'
    elseif string.len(bit_pattern) % 3 == 1 then
        trailing = '='
        bit_pattern = bit_pattern .. '00000000'
    end

    for i = 1, string.len(bit_pattern), 6 do
        local byte = string.sub(bit_pattern, i, i+5)
        local offset = tonumber(from_binary(byte))
        encoded = encoded .. string.sub(index_table, offset+1, offset+1)
    end

    return string.sub(encoded, 1, -1 - string.len(trailing)) .. trailing
end


function from_base64(to_decode)
    local padded = to_decode:gsub("%s", "")
    local unpadded = padded:gsub("=", "")
    local bit_pattern = ''
    local decoded = ''

    for i = 1, string.len(unpadded) do
        local char = string.sub(to_decode, i, i)
        local offset, _ = string.find(index_table, char)
        if offset == nil then
             error("Invalid character '" .. char .. "' found.")
        end

        bit_pattern = bit_pattern .. string.sub(to_binary(offset-1), 3)
    end

    for i = 1, string.len(bit_pattern), 8 do
        local byte = string.sub(bit_pattern, i, i+7)
        decoded = decoded .. string.char(from_binary(byte))
    end

    local padding_length = padded:len()-unpadded:len()

    if (padding_length == 1 or padding_length == 2) then
        decoded = decoded:sub(1,-2)
    end
    return decoded
end

return {
  decode = from_base64,
  encode = to_base64
} end)
package.preload['uuid'] = (function (...)
---------------------------------------------------------------------------------------
-- Copyright 2012 Rackspace (original), 2013 Thijs Schreijer (modifications)
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS-IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- see http://www.ietf.org/rfc/rfc4122.txt
--
-- Note that this is not a true version 4 (random) UUID.  Since `os.time()` precision is only 1 second, it would be hard
-- to guarantee spacial uniqueness when two hosts generate a uuid after being seeded during the same second.  This
-- is solved by using the node field from a version 1 UUID.  It represents the mac address.
--
-- 28-apr-2013 modified by Thijs Schreijer from the original [Rackspace code](https://github.com/kans/zirgo/blob/807250b1af6725bad4776c931c89a784c1e34db2/util/uuid.lua) as a generic Lua module.
-- Regarding the above mention on `os.time()`; the modifications use the `socket.gettime()` function from LuaSocket
-- if available and hence reduce that problem (provided LuaSocket has been loaded before uuid).
--
-- **6-nov-2015 Please take note of this issue**; [https://github.com/Mashape/kong/issues/478](https://github.com/Mashape/kong/issues/478)
-- It demonstrates the problem of using time as a random seed. Specifically when used from multiple processes.
-- So make sure to seed only once, application wide. And to not have multiple processes do that
-- simultaneously (like nginx does for example).

local M = {}
local math = require('math')
local os = require('os')
local string = require('string')

local bitsize = 32  -- bitsize assumed for Lua VM. See randomseed function below.
local lua_version = tonumber(_VERSION:match("%d%.*%d*"))  -- grab Lua version used

local MATRIX_AND = {{0,0},{0,1} }
local MATRIX_OR = {{0,1},{1,1}}
local HEXES = '0123456789abcdef'

local math_floor = math.floor
local math_random = math.random
local math_abs = math.abs
local string_sub = string.sub
local to_number = tonumber
local assert = assert
local type = type

-- performs the bitwise operation specified by truth matrix on two numbers.
local function BITWISE(x, y, matrix)
  local z = 0
  local pow = 1
  while x > 0 or y > 0 do
    z = z + (matrix[x%2+1][y%2+1] * pow)
    pow = pow * 2
    x = math_floor(x/2)
    y = math_floor(y/2)
  end
  return z
end

local function INT2HEX(x)
  local s,base = '',16
  local d
  while x > 0 do
    d = x % base + 1
    x = math_floor(x/base)
    s = string_sub(HEXES, d, d)..s
  end
  while #s < 2 do s = "0" .. s end
  return s
end

----------------------------------------------------------------------------
-- Creates a new uuid. Either provide a unique hex string, or make sure the
-- random seed is properly set. The module table itself is a shortcut to this
-- function, so `my_uuid = uuid.new()` equals `my_uuid = uuid()`.
--
-- For proper use there are 3 options;
--
-- 1. first require `luasocket`, then call `uuid.seed()`, and request a uuid using no
-- parameter, eg. `my_uuid = uuid()`
-- 2. use `uuid` without `luasocket`, set a random seed using `uuid.randomseed(some_good_seed)`,
-- and request a uuid using no parameter, eg. `my_uuid = uuid()`
-- 3. use `uuid` without `luasocket`, and request a uuid using an unique hex string,
-- eg. `my_uuid = uuid(my_networkcard_macaddress)`
--
-- @return a properly formatted uuid string
-- @param hwaddr (optional) string containing a unique hex value (e.g.: `00:0c:29:69:41:c6`), to be used to compensate for the lesser `math_random()` function. Use a mac address for solid results. If omitted, a fully randomized uuid will be generated, but then you must ensure that the random seed is set properly!
-- @usage
-- local uuid = require("uuid")
-- print("here's a new uuid: ",uuid())
function M.new(hwaddr)
  -- bytes are treated as 8bit unsigned bytes.
  local bytes = {
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255),
      math_random(0, 255)
    }

  if hwaddr then
    assert(type(hwaddr)=="string", "Expected hex string, got "..type(hwaddr))
    -- Cleanup provided string, assume mac address, so start from back and cleanup until we've got 12 characters
    local i,str = #hwaddr, hwaddr
    hwaddr = ""
    while i>0 and #hwaddr<12 do
      local c = str:sub(i,i):lower()
      if HEXES:find(c, 1, true) then
        -- valid HEX character, so append it
        hwaddr = c..hwaddr
      end
      i = i - 1
    end
    assert(#hwaddr == 12, "Provided string did not contain at least 12 hex characters, retrieved '"..hwaddr.."' from '"..str.."'")

    -- no split() in lua. :(
    bytes[11] = to_number(hwaddr:sub(1, 2), 16)
    bytes[12] = to_number(hwaddr:sub(3, 4), 16)
    bytes[13] = to_number(hwaddr:sub(5, 6), 16)
    bytes[14] = to_number(hwaddr:sub(7, 8), 16)
    bytes[15] = to_number(hwaddr:sub(9, 10), 16)
    bytes[16] = to_number(hwaddr:sub(11, 12), 16)
  end

  -- set the version
  bytes[7] = BITWISE(bytes[7], 0x0f, MATRIX_AND)
  bytes[7] = BITWISE(bytes[7], 0x40, MATRIX_OR)
  -- set the variant
  bytes[9] = BITWISE(bytes[7], 0x3f, MATRIX_AND)
  bytes[9] = BITWISE(bytes[7], 0x80, MATRIX_OR)
  return INT2HEX(bytes[1])..INT2HEX(bytes[2])..INT2HEX(bytes[3])..INT2HEX(bytes[4]).."-"..
         INT2HEX(bytes[5])..INT2HEX(bytes[6]).."-"..
         INT2HEX(bytes[7])..INT2HEX(bytes[8]).."-"..
         INT2HEX(bytes[9])..INT2HEX(bytes[10]).."-"..
         INT2HEX(bytes[11])..INT2HEX(bytes[12])..INT2HEX(bytes[13])..INT2HEX(bytes[14])..INT2HEX(bytes[15])..INT2HEX(bytes[16])
end

----------------------------------------------------------------------------
-- Improved randomseed function.
-- Lua 5.1 and 5.2 both truncate the seed given if it exceeds the integer
-- range. If this happens, the seed will be 0 or 1 and all randomness will
-- be gone (each application run will generate the same sequence of random
-- numbers in that case). This improved version drops the most significant
-- bits in those cases to get the seed within the proper range again.
-- @param seed the random seed to set (integer from 0 - 2^32, negative values will be made positive)
-- @return the (potentially modified) seed used
-- @usage
-- local socket = require("socket")  -- gettime() has higher precision than os.time()
-- local uuid = require("uuid")
-- -- see also example at uuid.seed()
-- uuid.randomseed(socket.gettime()*10000)
-- print("here's a new uuid: ",uuid())
function M.randomseed(seed)
  seed = math_floor(math_abs(seed))
  if seed >= (2^bitsize) then
    -- integer overflow, so reduce to prevent a bad seed
    seed = seed - math_floor(seed / 2^bitsize) * (2^bitsize)
  end
  if lua_version < 5.2 then
    -- 5.1 uses (incorrect) signed int
    math.randomseed(seed - 2^(bitsize-1))
  else
    -- 5.2 uses (correct) unsigned int
    math.randomseed(seed)
  end
  return seed
end

----------------------------------------------------------------------------
-- Seeds the random generator.
-- It does so in 2 possible ways;
--
-- 1. use `os.time()`: this only offers resolution to one second (used when
-- LuaSocket hasn't been loaded yet
-- 2. use luasocket `gettime()` function, but it only does so when LuaSocket
-- has been required already.
-- @usage
-- local socket = require("socket")  -- gettime() has higher precision than os.time()
-- -- LuaSocket loaded, so below line does the same as the example from randomseed()
-- uuid.seed()
-- print("here's a new uuid: ",uuid())
function M.seed()
  if package.loaded["sockdl"] and package.loaded["sockdl"].gettime then
    return M.randomseed(package.loaded["socket"].gettime()*10000)
  else
    return M.randomseed(os.time())
  end
end

return setmetatable( M, { __call = function(self, hwaddr) return self.new(hwaddr) end} ) end)
package.preload['serpent'] = (function (...)
local n, v = "serpent", "0.302" -- (C) 2012-18 Paul Kulchenko; MIT License
local c, d = "Paul Kulchenko", "Lua serializer and pretty printer"
local snum = {[tostring(1/0)]='1/0 --[[math.huge]]',[tostring(-1/0)]='-1/0 --[[-math.huge]]',[tostring(0/0)]='0/0'}
local badtype = {thread = true, userdata = true, cdata = true}
local getmetatable = debug and debug.getmetatable or getmetatable
local pairs = function(t) return next, t end -- avoid using __pairs in Lua 5.2+
local keyword, globals, G = {}, {}, (_G or _ENV)
for _,k in ipairs({'and', 'break', 'do', 'else', 'elseif', 'end', 'false',
  'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
  'return', 'then', 'true', 'until', 'while'}) do keyword[k] = true end
for k,v in pairs(G) do globals[v] = k end -- build func to name mapping
for _,g in ipairs({'coroutine', 'debug', 'io', 'math', 'string', 'table', 'os'}) do
  for k,v in pairs(type(G[g]) == 'table' and G[g] or {}) do globals[v] = g..'.'..k end end

local function s(t, opts)
  local name, indent, fatal, maxnum = opts.name, opts.indent, opts.fatal, opts.maxnum
  local sparse, custom, huge = opts.sparse, opts.custom, not opts.nohuge
  local space, maxl = (opts.compact and '' or ' '), (opts.maxlevel or math.huge)
  local maxlen, metatostring = tonumber(opts.maxlength), opts.metatostring
  local iname, comm = '_'..(name or ''), opts.comment and (tonumber(opts.comment) or math.huge)
  local numformat = opts.numformat or "%.17g"
  local seen, sref, syms, symn = {}, {'local '..iname..'={}'}, {}, 0
  local function gensym(val) return '_'..(tostring(tostring(val)):gsub("[^%w]",""):gsub("(%d%w+)",
    -- tostring(val) is needed because __tostring may return a non-string value
    function(s) if not syms[s] then symn = symn+1; syms[s] = symn end return tostring(syms[s]) end)) end
  local function safestr(s) return type(s) == "number" and tostring(huge and snum[tostring(s)] or numformat:format(s))
    or type(s) ~= "string" and tostring(s) -- escape NEWLINE/010 and EOF/026
    or ("%q"):format(s):gsub("\010","n"):gsub("\026","\\026") end
  local function comment(s,l) return comm and (l or 0) < comm and ' --[['..select(2, pcall(tostring, s))..']]' or '' end
  local function globerr(s,l) return globals[s] and globals[s]..comment(s,l) or not fatal
    and safestr(select(2, pcall(tostring, s))) or error("Can't serialize "..tostring(s)) end
  local function safename(path, name) -- generates foo.bar, foo[3], or foo['b a r']
    local n = name == nil and '' or name
    local plain = type(n) == "string" and n:match("^[%l%u_][%w_]*$") and not keyword[n]
    local safe = plain and n or '['..safestr(n)..']'
    return (path or '')..(plain and path and '.' or '')..safe, safe end
  local alphanumsort = type(opts.sortkeys) == 'function' and opts.sortkeys or function(k, o, n) -- k=keys, o=originaltable, n=padding
    local maxn, to = tonumber(n) or 12, {number = 'a', string = 'b'}
    local function padnum(d) return ("%0"..tostring(maxn).."d"):format(tonumber(d)) end
    table.sort(k, function(a,b)
      -- sort numeric keys first: k[key] is not nil for numerical keys
      return (k[a] ~= nil and 0 or to[type(a)] or 'z')..(tostring(a):gsub("%d+",padnum))
           < (k[b] ~= nil and 0 or to[type(b)] or 'z')..(tostring(b):gsub("%d+",padnum)) end) end
  local function val2str(t, name, indent, insref, path, plainindex, level)
    local ttype, level, mt = type(t), (level or 0), getmetatable(t)
    local spath, sname = safename(path, name)
    local tag = plainindex and
      ((type(name) == "number") and '' or name..space..'='..space) or
      (name ~= nil and sname..space..'='..space or '')
    if seen[t] then -- already seen this element
      sref[#sref+1] = spath..space..'='..space..seen[t]
      return tag..'nil'..comment('ref', level) end
    -- protect from those cases where __tostring may fail
    if type(mt) == 'table' and metatostring ~= false then
      local to, tr = pcall(function() return mt.__tostring(t) end)
      local so, sr = pcall(function() return mt.__serialize(t) end)
      if (to or so) then -- knows how to serialize itself
        seen[t] = insref or spath
        t = so and sr or tr
        ttype = type(t)
      end -- new value falls through to be serialized
    end
    if ttype == "table" then
      if level >= maxl then return tag..'{}'..comment('maxlvl', level) end
      seen[t] = insref or spath
      if next(t) == nil then return tag..'{}'..comment(t, level) end -- table empty
      if maxlen and maxlen < 0 then return tag..'{}'..comment('maxlen', level) end
      local maxn, o, out = math.min(#t, maxnum or #t), {}, {}
      for key = 1, maxn do o[key] = key end
      if not maxnum or #o < maxnum then
        local n = #o -- n = n + 1; o[n] is much faster than o[#o+1] on large tables
        for key in pairs(t) do if o[key] ~= key then n = n + 1; o[n] = key end end end
      if maxnum and #o > maxnum then o[maxnum+1] = nil end
      if opts.sortkeys and #o > maxn then alphanumsort(o, t, opts.sortkeys) end
      local sparse = sparse and #o > maxn -- disable sparsness if only numeric keys (shorter output)
      for n, key in ipairs(o) do
        local value, ktype, plainindex = t[key], type(key), n <= maxn and not sparse
        if opts.valignore and opts.valignore[value] -- skip ignored values; do nothing
        or opts.keyallow and not opts.keyallow[key]
        or opts.keyignore and opts.keyignore[key]
        or opts.valtypeignore and opts.valtypeignore[type(value)] -- skipping ignored value types
        or sparse and value == nil then -- skipping nils; do nothing
        elseif ktype == 'table' or ktype == 'function' or badtype[ktype] then
          if not seen[key] and not globals[key] then
            sref[#sref+1] = 'placeholder'
            local sname = safename(iname, gensym(key)) -- iname is table for local variables
            sref[#sref] = val2str(key,sname,indent,sname,iname,true) end
          sref[#sref+1] = 'placeholder'
          local path = seen[t]..'['..tostring(seen[key] or globals[key] or gensym(key))..']'
          sref[#sref] = path..space..'='..space..tostring(seen[value] or val2str(value,nil,indent,path))
        else
          out[#out+1] = val2str(value,key,indent,nil,seen[t],plainindex,level+1)
          if maxlen then
            maxlen = maxlen - #out[#out]
            if maxlen < 0 then break end
          end
        end
      end
      local prefix = string.rep(indent or '', level)
      local head = indent and '{\n'..prefix..indent or '{'
      local body = table.concat(out, ','..(indent and '\n'..prefix..indent or space))
      local tail = indent and "\n"..prefix..'}' or '}'
      return (custom and custom(tag,head,body,tail,level) or tag..head..body..tail)..comment(t, level)
    elseif badtype[ttype] then
      seen[t] = insref or spath
      return tag..globerr(t, level)
    elseif ttype == 'function' then
      seen[t] = insref or spath
      if opts.nocode then return tag.."function() --[[..skipped..]] end"..comment(t, level) end
      local ok, res = pcall(string.dump, t)
      local func = ok and "((loadstring or load)("..safestr(res)..",'@serialized'))"..comment(t, level)
      return tag..(func or globerr(t, level))
    else return tag..safestr(t) end -- handle all other types
  end
  local sepr = indent and "\n" or ";"..space
  local body = val2str(t, name, indent) -- this call also populates sref
  local tail = #sref>1 and table.concat(sref, sepr)..sepr or ''
  local warn = opts.comment and #sref>1 and space.."--[[incomplete output with shared/self-references skipped]]" or ''
  return not name and body..warn or "do local "..body..sepr..tail.."return "..name..sepr.."end"
end

local function deserialize(data, opts)
  local env = (opts and opts.safe == false) and G
    or setmetatable({}, {
        __index = function(t,k) return t end,
        __call = function(t,...) error("cannot call functions") end
      })
  local f, res = (loadstring or load)('return '..data, nil, nil, env)
  if not f then f, res = (loadstring or load)(data, nil, nil, env) end
  if not f then return f, res end
  if setfenv then setfenv(f, env) end
  return pcall(f)
end

local function merge(a, b) if b then for k,v in pairs(b) do a[k] = v end end; return a; end
return { _NAME = n, _COPYRIGHT = c, _DESCRIPTION = d, _VERSION = v, serialize = s,
  load = deserialize,
  dump = function(a, opts) return s(a, merge({name = '_', compact = true, sparse = true}, opts)) end,
  line = function(a, opts) return s(a, merge({sortkeys = true, comment = true}, opts)) end,
  block = function(a, opts) return s(a, merge({indent = '  ', sortkeys = true, comment = true}, opts)) end } end)
package.preload['component'] = (function (...)
local utils = require("utils")
local bz_handle = require("bz_handle")
local net = require("net")
local rx = require("rx")
local Module = require("module")
local Observable, Subject, ReplaySubject, AsyncSubject
Observable, Subject, ReplaySubject, AsyncSubject = rx.Observable, rx.Subject, rx.ReplaySubject, rx.AsyncSubject
local applyMeta, getMeta, proxyCall, protectedCall, namespace, instanceof, isIn, assignObject, getFullName, Store
applyMeta, getMeta, proxyCall, protectedCall, namespace, instanceof, isIn, assignObject, getFullName, Store = utils.applyMeta, utils.getMeta, utils.proxyCall, utils.protectedCall, utils.namespace, utils.instanceof, utils.isIn, utils.assignObject, utils.getFullName, utils.Store
local Handle
Handle = bz_handle.Handle
local SharedStore, BroadcastSocket
SharedStore, BroadcastSocket = net.SharedStore, net.BroadcastSocket
local ComponentConfig
ComponentConfig = function(cls, cfg)
  applyMeta(cls, {
    Component = assignObject({
      mp_all = false,
      odfs = { },
      classLabels = { },
      componentName = "",
      remoteCls = false,
      customTest = function()
        return false
      end
    }, cfg)
  })
  return cls
end
local ObjCfg
ObjCfg = function(cls)
  return getMeta(cls).Component
end
local UnitComponent
do
  local _class_0
  local _base_0 = {
    getHandle = function(self)
      return self.handle
    end,
    setState = function(self, state)
      return self.store:assign(state)
    end,
    getStore = function(self)
      return self.store
    end,
    state = function(self)
      return self.store:getState()
    end,
    save = function(self)
      return self:state()
    end,
    load = function(self, state)
      self.store = Store(state)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, handle, props)
      self.store = Store()
      self.handle = Handle(handle)
    end,
    __base = _base_0,
    __name = "UnitComponent"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  UnitComponent = _class_0
end
local SyncedUnitComponent
do
  local _class_0
  local _parent_0 = UnitComponent
  local _base_0 = {
    postInit = function(self)
      if self.props.requestSocket then
        return self.props.requestSocket(nil):subscribe(function(socket)
          self.socket = socket
          self.remoteStore = SharedStore(self.localStore:getState(), socket)
          return self.storeSub:onNext(self.remoteStore)
        end)
      else
        return self.storeSub:onNext(self.localStore)
      end
    end,
    setState = function(self, state)
      if self.remoteStore then
        return self.remoteStore:assign(state)
      else
        return self.localStore:assign(state)
      end
    end,
    getStore = function(self)
      return self.storeSub
    end,
    state = function(self)
      return self.remoteStore:getState()
    end,
    componentWillUnmount = function(self)
      self.storeSub:onCompleted()
      if self.socket then
        return self.socket:close()
      end
    end,
    save = function(self)
      return self:state()
    end,
    load = function(self, state)
      self.localStore = Store(state)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, handle, props)
      _class_0.__parent.__init(self, handle, props)
      self.props = props
      self.localStore = Store()
      self.remote = props.remote
      self.storeSub = ReplaySubject.create(1)
    end,
    __base = _base_0,
    __name = "SyncedUnitComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  SyncedUnitComponent = _class_0
end
local ComponentManager
do
  local _class_0
  local _parent_0 = Module
  local _base_0 = {
    start = function(self, ...)
      _class_0.__parent.start(self, ...)
      for v in AllObjects() do
        proxyCall(self:addHandle(v), "postInit")
      end
    end,
    _regHandle = function(self, handle)
      self.waitToAdd[handle] = nil
      local objs = self:addHandle(handle)
      proxyCall(objs, "postInit")
      return proxyCall(objs, "unitDidSpawn")
    end,
    update = function(self, ...)
      _class_0.__parent.update(self, ...)
      for i, v in pairs(self.waitToAdd) do
        self:_regHandle(i)
      end
      for i, v in pairs(self.objbyhandle) do
        if IsValid(i) and IsNetGame() then
          if (not self.remoteHandles[i]) ~= (not IsRemote(i)) then
            self.remoteHandles[i] = IsRemote(i) or nil
            proxyCall(v, "unitWillTransfere")
            self.objbyhandle[i] = { }
            for _index_0 = 1, #v do
              local obj = v[_index_0]
              local m = getMeta(obj)
              local cname = getFullName(m.parent)
              if ObjCfg(m.parent).remoteCls then
                local cls = self.classes[cname]
                local inst = self:createInstance(i, cls)
                protectedCall(inst, "load", protectedCall(obj, "save"))
                protectedCall(obj, "componentWillUnmount")
                protectedCall(inst, "postInit")
                protectedCall(inst, "unitDidTransfere")
              else
                table.insert(self.objbyhandle, obj)
              end
            end
          end
        end
        v = self.objbyhandle[i]
        proxyCall(v, "update", ...)
      end
    end,
    addObject = function(self, handle, ...)
      _class_0.__parent.addObject(self, handle)
      return self:_regHandle(handle)
    end,
    createObject = function(self, handle, ...)
      print("create object")
      _class_0.__parent.createObject(self, handle, ...)
      self.waitToAdd[handle] = true
    end,
    deleteObject = function(self, ...)
      _class_0.__parent.deleteObject(self, ...)
      return self:removeHandle(...)
    end,
    getComponents = function(self, handle)
      return self.objbyhandle[handle] or { }
    end,
    getComponent = function(self, handle, cls)
      for i, v in pairs(self:getComponents(handle)) do
        if (instanceof(v, cls)) then
          return v
        end
      end
    end,
    useClass = function(self, cls)
      self.classes[getFullName(cls)] = cls
    end,
    addHandle = function(self, handle)
      if self.objbyhandle[handle] then
        return { }
      end
      local ret = { }
      local h = Handle(handle)
      local odf = h:getOdf()
      local classLabel = h:getClassLabel()
      local componentNames = h:getTable("GameObjectClass", "componentName")
      for i, v in pairs(self.classes) do
        local c = ObjCfg(v)
        local use = isIn(classLabel, c.classLabels) or isIn(c.componentName, componentNames) or isIn(odf, c.odfs) or c.customTest(handle)
        if use then
          table.insert(ret, self:createInstance(handle, v))
        end
      end
      return ret
    end,
    createInstance = function(self, handle, cls)
      local c = ObjCfg(cls)
      local instance = nil
      local socketSub = nil
      local props = {
        serviceManager = self.serviceManager,
        remote = IsNetGame() and IsRemote(handle)
      }
      local socketCount = 0
      if (IsNetGame() and IsRemote(handle)) then
        self.remoteHandles[handle] = true
        if (c.remoteCls) then
          props.requestSocket = function(name)
            socketCount = socketCount + 1
            return self.net:onNetworkReady():flatMap(function()
              return self.net:getRemoteSocket("OBJ", handle, getFullName(cls), name ~= nil and name or socketCount)
            end)
          end
          instance = c.remoteCls(handle, props)
        else
          instance = { }
        end
      else
        if (IsNetGame() and c.remoteCls) then
          props.requestSocket = function(type, name)
            socketCount = socketCount + 1
            return self.net:onNetworkReady():map(function()
              return self.net:openSocket(0, type, "OBJ", handle, getFullName(cls), name ~= nil and name or socketCount)
            end)
          end
        end
        instance = cls(handle, props)
      end
      applyMeta(instance, {
        parent = cls
      })
      self.objbyhandle[handle] = self.objbyhandle[handle] or { }
      table.insert(self.objbyhandle[handle], instance)
      return instance
    end,
    removeHandle = function(self, handle)
      local objs = self.objbyhandle[handle]
      self.objbyhandle[handle] = nil
      if objs then
        proxyCall(objs, "unitWasRemoved")
        return proxyCall(objs, "componentWillUnmount")
      end
    end,
    save = function(self, ...)
      local componentData = { }
      for i, v in pairs(self.objbyhandle) do
        do
          local _tbl_0 = { }
          for _index_0 = 1, #v do
            local obj = v[_index_0]
            _tbl_0[getFullName(obj.__class)] = table.pack(protectedCall(obj, "save"))
          end
          componentData[i] = _tbl_0
        end
      end
      return {
        mdata = _class_0.__parent.save(self, ...),
        componentData = componentData
      }
    end,
    load = function(self, ...)
      local data = ...
      _class_0.__parent.load(self, data.mdata)
      print(...)
      for i, v in pairs(data.componentData) do
        for clsName, data in pairs(v) do
          local cls = self.classes[clsName]
          local inst = self:createInstance(i, cls)
          protectedCall(inst, "load", unpack(data))
          protectedCall(inst, "postInit")
        end
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, parent, serviceManager)
      _class_0.__parent.__init(self, parent, serviceManager)
      self.classes = { }
      self.objbyhandle = { }
      self.remoteHandles = { }
      self.waitToAdd = { }
      self.serviceManager = serviceManager
      return serviceManager:getService("bzutils.net"):subscribe(function(net)
        self.net = net
      end)
    end,
    __base = _base_0,
    __name = "ComponentManager",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ComponentManager = _class_0
end
namespace("component", ComponentManager, UnitComponent)
return {
  ComponentManager = ComponentManager,
  UnitComponent = UnitComponent,
  ComponentConfig = ComponentConfig,
  SyncedUnitComponent = SyncedUnitComponent
}
 end)
package.preload['net'] = (function (...)
local rx = require("rx")
local utils = require("utils")
local runtime = require("runtime")
local assignObject, namespace, Store, sizeof, sizeTable, simpleIdGeneratorFactory
assignObject, namespace, Store, sizeof, sizeTable, simpleIdGeneratorFactory = utils.assignObject, utils.namespace, utils.Store, utils.sizeof, utils.sizeTable, utils.simpleIdGeneratorFactory
local Subject, AsyncSubject, ReplaySubject
Subject, AsyncSubject, ReplaySubject = rx.Subject, rx.AsyncSubject, rx.ReplaySubject
local Timer
Timer = runtime.Timer
local MAX_INTERFACE = 5000
local MAX_SENDSIZE = IsBz15() and 200 or 2000
local netSerializeTable
netSerializeTable = function(tbl, idgen, keymap)
  if idgen == nil then
    idgen = simpleIdGeneratorFactory()
  end
  if keymap == nil then
    keymap = { }
  end
  local id = idgen()
  keymap[id] = { }
  local size = 0
  local children = { }
  local parts = { }
  local cpart = 0
  for i, v in pairs(tbl) do
    if size == 0 then
      size = 2
      cpart = cpart + 1
      parts[cpart] = { }
    end
    size = size + sizeof(i) + 1
    if type(v) == "table" then
      local _children = netSerializeTable(v, idgen, keymap)
      local _child = _children[#_children]
      local _cid = _child[1]
      keymap[id][i] = _cid
      for i2, v2 in ipairs(_children) do
        table.insert(children, v2)
      end
    else
      size = size + sizeof(v)
      parts[cpart][i] = v
    end
    if size >= MAX_SENDSIZE then
      size = 0
    end
  end
  table.insert(children, table.pack(id, cpart, unpack(parts, 1, cpart)))
  return children, keymap
end
local addedPlayers = 0
local txRate = 0
local totalTx = 0
local _Send = Send
Send = function(...)
  if addedPlayers > 0 then
    _Send(...)
    totalTx = totalTx + 1
    txRate = txRate + 1
  end
end
local NetworkInterface
do
  local _class_0
  local _base_0 = {
    send = function(self, ...)
      if self.alive then
        for i, v in pairs(self.to) do
          Send(v, "N", self.id, ...)
        end
      else
        return error("Trying to send something via a closed network interface")
      end
    end,
    getMessages = function(self)
      return self.subject
    end,
    receive = function(self, ...)
      if self.alive then
        return self.subject:onNext(...)
      end
    end,
    close = function(self)
      if self.alive then
        self.subject:onCompleted()
        self.alive = false
      else
        return error("Interface has already closed")
      end
    end,
    isOpen = function(self)
      return self.alive
    end,
    getId = function(self)
      return self.id
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, interface_id, to)
      self.id = interface_id
      self.to = type(to) == "number" and {
        to
      } or assignObject({ }, to)
      self.subject = ReplaySubject.create()
      self.alive = true
    end,
    __base = _base_0,
    __name = "NetworkInterface"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  NetworkInterface = _class_0
end
local NetPlayer
do
  local _class_0
  local _base_0 = {
    getHandle = function(self)
      return self.handle
    end,
    getName = function(self)
      return self.name
    end,
    getId = function(self)
      return self.id
    end,
    getTeam = function(self)
      return self.team
    end,
    setHandle = function(self, h)
      self.handle = h
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, id, name, team)
      self.id = id
      self.name = name
      self.team = team
      self.handle = GetPlayerHandle(team)
      self.handleSubject = Subject.create()
    end,
    __base = _base_0,
    __name = "NetPlayer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  NetPlayer = _class_0
end
local Socket
do
  local _class_0
  local _base_0 = {
    _getNextId = function(self)
      self._currentId = self._currentId + 1
      return self._currentId
    end,
    send = function(self, ...)
      local package = table.pack(...)
      if (#package < 1) then
        error("Can not send empty packages")
      end
      package._head = 0
      package._id = self:_getNextId()
      package._sub = AsyncSubject.create()
      table.insert(self.queue, package)
      return package._sub
    end,
    sendNext = function(self)
      if self.alive then
        local p = self.queue[1]
        if p then
          local d = #p
          local tsize = 0
          local sendLen = 1
          if p._head > 0 then
            for _ = 1, d do
              local s = sizeof(p[_])
              if s + tsize < MAX_SENDSIZE then
                tsize = tsize + s
                sendLen = sendLen + 1
              else
                break
              end
            end
            d = table.pack(unpack(p, p._head, p._head + sendLen))
          end
          if type(d) == "table" then
            self.interface:send("P", p._head, p._id, unpack(d))
          else
            self.interface:send("P", p._head, p._id, d)
          end
          p._head = p._head + sendLen
          if (p._head > #p) then
            p._sub:onNext(p._id)
            p._sub:onCompleted()
            return table.remove(self.queue, 1)
          end
        elseif self.closeWhenEmpty and self.incomingQueueSize <= 0 then
          return self:close()
        end
      end
    end,
    onConnect = function(self)
      return self.connectSubject
    end,
    receive = function(self, f, tpe, t, id, ...)
      if self.alive then
        self.incomingBuffer[f] = self.incomingBuffer[f] or { }
        local buffer = self.incomingBuffer[f]
        if tpe == "P" then
          if t == 0 then
            local size = ...
            do
              local _accum_0 = { }
              local _len_0 = 1
              for i = 1, size do
                _accum_0[_len_0] = 0
                _len_0 = _len_0 + 1
              end
              buffer[id] = _accum_0
            end
            self.incomingQueueSize = self.incomingQueueSize + 1
          elseif buffer[id] ~= nil then
            local data = table.pack(...)
            for _ = 1, #data do
              buffer[id][t] = data[_]
              t = t + 1
              if t > #buffer[id] then
                break
              end
            end
            if t >= #buffer[id] then
              self.receiveSubject:onNext(unpack(buffer[id], 1, #buffer[id]))
              buffer[id] = nil
              self.incomingQueueSize = self.incomingQueueSize - 1
            end
          end
        elseif tpe == "C" then
          return self.connectSubject:onNext(f)
        end
      end
    end,
    onReceive = function(self)
      return self.receiveSubject
    end,
    getInterface = function(self)
      return self.interface
    end,
    isOpen = function(self)
      return self.alive
    end,
    closeOnEmpty = function(self)
      self.closeWhenEmpty = true
    end,
    close = function(self)
      self.alive = false
      self.receiveSubject:onCompleted()
      self.connectSubject:onCompleted()
      self.incomingBuffer = { }
      if self.interface:isOpen() then
        return self.interface:close()
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, interface, notify)
      self.interface = interface
      self.connectSubject = Subject.create()
      self.receiveSubject = Subject.create()
      self.incomingBuffer = { }
      self.incomingQueueSize = 0
      self.queue = { }
      self._currentId = 1
      self.alive = true
      self.closeWhenEmpty = false
      self.interface:getMessages():subscribe((function()
        local _base_1 = self
        local _fn_0 = _base_1.receive
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)(), nil, (function()
        local _base_1 = self
        local _fn_0 = _base_1.close
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
      if notify then
        return self.interface:send("C")
      end
    end,
    __base = _base_0,
    __name = "Socket"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Socket = _class_0
end
local ServerSocket
do
  local _class_0
  local _parent_0 = Socket
  local _base_0 = {
    _onConnect = function(self, to)
      self.subSockets[to] = Socket(NetworkInterface(self.interface:getId(), to))
    end,
    receive = function(self, f, tpe, t, id, ...)
      if self.alive then
        self.incomingBuffer[f] = self.incomingBuffer[f] or { }
        local buffer = self.incomingBuffer[f]
        if tpe == "P" then
          if t == 0 then
            local size = ...
            do
              local _accum_0 = { }
              local _len_0 = 1
              for i = 1, size do
                _accum_0[_len_0] = 0
                _len_0 = _len_0 + 1
              end
              buffer[id] = _accum_0
            end
            self.incomingQueueSize = self.incomingQueueSize + 1
          elseif buffer[id] ~= nil then
            local data = table.pack(...)
            for _ = 1, #data do
              buffer[id][t] = data[_]
              t = t + 1
              if t > #buffer[id] then
                break
              end
            end
            if t >= #buffer[id] then
              self.receiveSubject:onNext(self.subSockets[f], unpack(buffer[id], 1, #buffer[id]))
              buffer[id] = nil
              self.incomingQueueSize = self.incomingQueueSize - 1
            end
          end
        elseif tpe == "C" then
          return self.connectSubject:onNext(f)
        end
      end
    end,
    sendNext = function(self, ...)
      _class_0.__parent.__base.sendNext(self, ...)
      for i, v in pairs(self.subSockets) do
        v:sendNext(...)
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      _class_0.__parent.__init(self, ...)
      self:onConnect():subscribe((function()
        local _base_1 = self
        local _fn_0 = _base_1._onConnect
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
      self.subSockets = { }
    end,
    __base = _base_0,
    __name = "ServerSocket",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ServerSocket = _class_0
end
local BroadcastSocket
do
  local _class_0
  local _parent_0 = Socket
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      _class_0.__parent.__init(self, ...)
      return self:onReceive():subscribe((function()
        local _base_1 = _class_0.__parent
        local _fn_0 = _base_1.send
        return function(...)
          return _fn_0(self, ...)
        end
      end)())
    end,
    __base = _base_0,
    __name = "BroadcastSocket",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BroadcastSocket = _class_0
end
local NetworkInterfaceManager
do
  local _class_0
  local _base_0 = {
    getTotalTx = function(self)
      return totalTx
    end,
    getTotalRx = function(self)
      return self.totalRx
    end,
    getRxRate = function(self)
      return self.rxRate
    end,
    getTxRate = function(self)
      return txRate
    end,
    getLocalPlayer = function(self)
      if not self.isNetworkReady then
        error("Unknown! Network is not ready")
      end
      return self.localPlayer
    end,
    getPlayer = function(self, id)
      if not self.isNetworkReady then
        error("Unknown! Network is not ready")
      end
      return self.players[id]
    end,
    getPlayerHandle = function(self, team)
      return IsValid(GetPlayerHandle(team)) and GetPlayerHandle(team) or self.playerHandles[team or 0]
    end,
    getTarget = function(self, handle)
      return IsValid(GetTarget(handle)) and GetTarget(handle) or self.playerTargets[handle]
    end,
    isNetworkReady = function(self)
      return self.network_ready
    end,
    onNetworkReady = function(self)
      return self.networkReadySubject
    end,
    onHostMigration = function(self)
      return self.hostMigrationSubject
    end,
    getInterfaceById = function(self, id)
      return self.networkInterfaces[id]
    end,
    _getOrCreateInterface = function(self, id, to)
      local i = self:getInterfaceById(id)
      if i == nil then
        i = NetworkInterface(id, to)
        if self.playerInterfaceMap[to] == nil then
          self.playerInterfaceMap[to] = { }
        end
        self.playerInterfaceMap[to][id] = true
        self.networkInterfaces[id] = i
        i:getMessages():subscribe(nil, nil, function()
          self.playerInterfaceMap[to][id] = nil
          self.networkInterfaces[id] = nil
          self.allSockets[id] = nil
        end)
      end
      return i
    end,
    _terminateInterface = function(self, interface_id)
      Send(0, "X", interface_id)
      self.allSockets[interface_id] = nil
      self.networkInterfaces[interface_id] = nil
      return table.insert(self.availableIDs, id)
    end,
    _cleanUpInterfaces = function(self, player) end,
    createNewInterface = function(self, to)
      local id = nil
      if #self.availableIDs <= 0 then
        self.nextInterface_id = self.nextInterface_id % (MAX_INTERFACE + 1) + 1
        id = self.nextInterface_id + self.machine_id * MAX_INTERFACE
        local i = self:getInterfaceById(id)
        if (i and i:isOpen()) then
          id = nil
          for i, v in pairs(self.networkInterfaces) do
            if not v:isOpen() then
              table.insert(self.availableIDs, i)
            end
          end
        end
      end
      if id == nil and #self.availableIDs > 0 then
        id = table.remove(self.availableIDs)
      end
      if id ~= nil then
        self.networkInterfaces[id] = NetworkInterface(id, to)
        self.networkInterfaces[id]:getMessages():subscribe(nil, nil, function()
          return self:_terminateInterface(id)
        end)
        return self.networkInterfaces[id]
      else
        return error("All network interfaces used up!")
      end
    end,
    _getLeaf = function(self, tbl, ...)
      local t = {
        ...
      }
      local leaf = nil
      local curr = tbl
      for _index_0 = 1, #t do
        local v = t[_index_0]
        if curr[v] == nil then
          curr[v] = { }
        end
        leaf = curr[v]
        curr = leaf
      end
      return leaf
    end,
    openSocket = function(self, to, socket_type, ...)
      if socket_type == nil then
        socket_type = Socket
      end
      if self.network_ready then
        local leaf = self:_getLeaf(self.serverSockets, ...)
        local i = self:createNewInterface(to)
        local socket = socket_type(i)
        self.allSockets[i:getId()] = socket
        if leaf then
          if leaf.__socket then
            error("Can not have multiple sockets on one channel")
          end
          leaf.__socket = socket
          leaf.__socket:onReceive():subscribe(nil, nil, function()
            print("Leaf: socket closed")
            leaf.__socket = nil
          end)
          return leaf.__socket
        else
          return socket
        end
      else
        return error("Network is not ready")
      end
    end,
    getHeadlessSocket = function(self, to, interface_id, socket_type)
      if socket_type == nil then
        socket_type = Socket
      end
      local s = socket_type(self:_getOrCreateInterface(interface_id, to), true)
      self.allSockets[interface_id] = s
      return s
    end,
    getRemoteSocket = function(self, ...)
      local leaf = self:_getLeaf(self.requestSockets, ...)
      if leaf then
        if leaf.__socketSubject == nil then
          self.nextRequestId = self.nextRequestId + 1
          local requestId = self.nextRequestId
          leaf.__socketSubject = AsyncSubject.create()
          local t = Timer(5, math.huge, self.serviceManager)
          local args = {
            ...
          }
          self.requestSocketsIds[requestId] = {
            sub = leaf.__socketSubject,
            leaf = leaf,
            timer = t,
            subscription = t:onAlarm():subscribe(function(t, life)
              if life == 0 then
                leaf.__socketSubject:onNext(nil)
                leaf.__socketSubject:onCompleted()
                leaf.__socketSubject = nil
                self.requestSocketsIds[requestId] = nil
              end
              return Send(0, "R", requestId, unpack(args))
            end)
          }
          t:start()
          Send(0, "R", self.nextRequestId, ...)
        end
        return leaf.__socketSubject
      else
        return error("No channels provided")
      end
    end,
    receive = function(self, f, t, a, ...)
      if self.localPlayer and self.localPlayer.id == f then
        return 
      end
      self.totalRx = self.totalRx + 1
      self.rxRate = self.rxRate + 1
      if t == "N" then
        local i = self:_getOrCreateInterface(a, f)
        i:receive(f, ...)
      elseif t == "X" then
        local i = self:getInterfaceById(a)
        if i then
          i:close()
        end
      elseif t == "R" then
        local leaf = self:_getLeaf(self.serverSockets, ...)
        if leaf and leaf.__socket then
          Send(f, "C", a, leaf.__socket:getInterface():getId())
        end
      elseif t == "C" then
        if self.requestSocketsIds[a] then
          local interface_id = ...
          local r = self.requestSocketsIds[a]
          r.subscription:unsubscribe()
          r.timer:stop()
          local s = Socket(self:_getOrCreateInterface(interface_id, f), true)
          s:onReceive():subscribe(nil, nil, function()
            r.leaf.__socketSubject = nil
          end)
          self.allSockets[interface_id] = s
          r.sub:onNext(s)
          r.sub:onCompleted()
          self.requestSocketsIds[a] = nil
        end
      elseif t == "I" then
        if self.machine_id == -1 then
          self.machine_id = a
          self.localPlayer = self.players[self.machine_id]
          if IsHosting() then
            self.hostPlayer = self.localPlayer
          end
        end
      elseif t == "H" then
        self.hostPlayer = self.players[f] or {
          id = f,
          name = "Unknown",
          team = 0
        }
        if self.isHostMigrating then
          self.hostMigrationSubject:onNext(self.hostPlayer)
          self.isHostMigrating = false
        end
      elseif t == "Q" then
        local p = self:getPlayer(f)
        local target = ...
        if p then
          self.playerHandles[p.team] = a or GetPlayerHandle(p.team)
          local ph = self:getPlayerHandle(p.team)
          if IsValid(ph) then
            self.playerTargets[ph] = target
          end
        end
      end
      if self.hostPlayer ~= nil and self.machine_id ~= -1 and not self.network_ready then
        print("Network is now ready")
        self.network_ready = true
        return self.networkReadySubject:onNext()
      end
    end,
    start = function(self)
      if IsNetGame() and not self.network_ready and self.playerCount <= 1 then
        self.machine_id = self.lastPlayer.id
        self.localPlayer = self.lastPlayer
        self.network_ready = true
        self.hostPlayer = self.localPlayer
        return self.networkReadySubject:onNext()
      elseif not IsNetGame() then
        self.machine_id = 0
        self.localPlayer = {
          name = "Player",
          team = 1,
          id = 0
        }
        self.hostPlayer = self.localPlayer
        self.network_ready = true
        return self.networkReadySubject:onNext()
      end
    end,
    update = function(self, dtime)
      self.rxRate = self.rxRate - dtime
      txRate = txRate - dtime
      self.rxRate = math.max(self.rxRate, 0)
      txRate = math.max(txRate, 0)
      for i, v in pairs(self.allSockets) do
        v:sendNext()
      end
      if self.isHostMigrating and IsHosting() then
        self.hostPlayer = self.localPlayer
        self.isHostMigrating = false
        self.hostMigrationSubject:onNext(self.hostPlayer)
        Send(0, "H")
      end
      local ph = GetPlayerHandle()
      local pt = GetUserTarget()
      if ph ~= self.phandle or pt ~= self.ptarget then
        Send(0, "Q", ph, pt)
      end
      self.phandle = ph
      self.ptarget = pt
    end,
    addPlayer = function(self, id, name, team)
      print("Player added!", id, name, team)
      addedPlayers = addedPlayers + 1
      self.playerInterfaceMap[id] = { }
      if IsHosting() then
        Send(id, "H")
      end
      Send(id, "I", id)
      return Send(id, "Q", self.phandle, self.ptarget)
    end,
    createPlayer = function(self, id, name, team)
      self.playerCount = self.playerCount + 1
      self.players[id] = {
        id = id,
        name = name,
        team = team
      }
      self.lastPlayer = self.players[id]
    end,
    deletePlayer = function(self, id, name, team)
      addedPlayers = addedPlayers - 1
      for i, v in pairs(self.playerInterfaceMap[id] or { }) do
        self:_getOrCreateInterface(i):close()
      end
      if id == (self.hostPlayer or {
        id = -1
      }).id then
        self.isHostMigrating = true
      end
      self.players[id] = nil
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, parent, serviceManager)
      self.serviceManager = serviceManager
      self.networkInterfaces = { }
      self.machine_id = -1
      self.nextInterface_id = 0
      self.networkReadySubject = ReplaySubject.create(1)
      self.hostMigrationSubject = Subject.create()
      self.isHostMigrating = false
      self.network_ready = false
      self.serverSockets = { }
      self.availableIDs = { }
      self.requestSockets = { }
      self.requestSocketsIds = { }
      self.playerInterfaceMap = { }
      self.nextRequestId = 0
      self.hostPlayer = nil
      self.playerHandles = { }
      self.playerTargets = { }
      self.allSockets = { }
      self.playerCount = 0
      self.players = { }
      self.lastPlayer = { }
      self.phandle = GetPlayerHandle()
      self.ptarget = GetUserTarget()
      self.totalRx = 0
      self.rxRate = 0
    end,
    __base = _base_0,
    __name = "NetworkInterfaceManager"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  NetworkInterfaceManager = _class_0
end
local SharedStore
do
  local _class_0
  local _parent_0 = Store
  local _base_0 = {
    onStateUpdate = function(self)
      return self.internal_store:onStateUpdate()
    end,
    onKeyUpdate = function(self)
      return self.internal_store:onKeyUpdate()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, initial_state, socket)
      _class_0.__parent.__init(self, initial_state)
      self.socket = socket
      self.internal_store = Store(initial_state)
      self.active = true
      _class_0.__parent.onKeyUpdate(self):subscribe(function(k, v)
        if not self.active then
          return 
        end
        print("Sending", k, v)
        if v == nil then
          self.socket:send("DELETE", k)
          return self.internal_store:delete(k)
        else
          self.socket:send("SET", k, v)
          return self.internal_store:set(k, v)
        end
      end)
      self.socket:onReceive():subscribe(function(what, ...)
        if not self.active then
          return 
        end
        if what == "SET" then
          self:silentSet(...)
          return self.internal_store:set(...)
        elseif what == "DELETE" then
          self:silentDelete(...)
          return self.internal_store:delete(...)
        end
      end)
      return self.socket:onConnect():subscribe(function()
        if not self.active then
          return 
        end
        local s = self:getState()
        for i, v in pairs(s) do
          self.socket:send("SET", i, v)
        end
      end, nil, function()
        self.active = false
      end)
    end,
    __base = _base_0,
    __name = "SharedStore",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  SharedStore = _class_0
end
namespace("net", Socket, NetworkInterface, NetworkInterfaceManager)
return {
  Socket = Socket,
  BroadcastSocket = BroadcastSocket,
  ServerSocket = ServerSocket,
  NetworkInterface = NetworkInterface,
  NetworkInterfaceManager = NetworkInterfaceManager,
  SharedStore = SharedStore,
  netSerializeTable = netSerializeTable
}
 end)
package.preload['runtime'] = (function (...)
local utils = require("utils")
local rx = require("rx")
local Module = require("module")
local proxyCall, protectedCall, getFullName, applyMeta, getMeta
proxyCall, protectedCall, getFullName, applyMeta, getMeta = utils.proxyCall, utils.protectedCall, utils.getFullName, utils.applyMeta, utils.getMeta
local Subject
Subject = rx.Subject
local setRuntimeState
setRuntimeState = function(inst, state)
  return applyMeta(inst, {
    runtime = {
      state = state
    }
  })
end
local getRuntimeState
getRuntimeState = function(inst, state)
  return getMeta(inst).runtime.state
end
local RuntimeController
do
  local _class_0
  local _parent_0 = Module
  local _base_0 = {
    setInterval = function(self, func, delay, count)
      if count == nil then
        count = -1
      end
      local id = self.nextIntervalId
      self.nextIntervalId = self.nextIntervalId + 1
      self.intervals[id] = {
        func = func,
        delay = delay,
        count = count,
        time = 0
      }
      setRuntimeState(self.intervals[id], 1)
      return id
    end,
    setTimeout = function(self, func, delay)
      return self:setInterval(func, delay, 1)
    end,
    clearInterval = function(self, id)
      if getRuntimeState(self.intervals[id]) ~= 0 then
        setRuntimeState(self.intervals[id], 0)
        return table.insert(self.garbage, {
          t = self.intervals,
          k = id
        })
      end
    end,
    createRoutine = function(self, cls, ...)
      print("Creating routine", getFullName(cls))
      if type(cls) == "string" then
        cls = self.classes[cls]
      end
      if cls == nil or self.classes[getFullName(cls)] == nil then
        error(("%s has not been registered via 'useClass'"):format(getFullName(cls)))
      end
      local id = self.nextRoutineId
      self.nextRoutineId = self.nextRoutineId + 1
      local props = {
        terminate = function(...)
          return self:clearRoutine(id, ...)
        end,
        serviceManager = self.serviceManager
      }
      local inst = cls(props)
      setRuntimeState(inst, 1)
      self.routines[id] = inst
      protectedCall(inst, "routineWasCreated", ...)
      protectedCall(inst, "postInit")
      return id, inst
    end,
    useClass = function(self, cls)
      self.classes[getFullName(cls)] = cls
    end,
    getRoutine = function(self, id)
      return self.routines[id]
    end,
    clearRoutine = function(self, id, ...)
      local inst = self.routines[id]
      if inst and getRuntimeState(inst) ~= 0 then
        setRuntimeState(inst, 0)
        protectedCall(inst, "routineWasDestroyed", ...)
        return table.insert(self.garbage, {
          t = self.routines,
          k = id
        })
      end
    end,
    update = function(self, dtime)
      for i, v in ipairs(self.garbage) do
        v.t[v.k] = nil
      end
      self.garbage = { }
      for i, v in pairs(self.intervals) do
        v.time = v.time + dtime
        if v.time >= v.delay then
          v.func(v.time)
          v.time = v.time - v.delay
          v.count = v.count - 1
          if v.count == 0 then
            self:clearInterval(i)
          end
        end
      end
      for i, v in pairs(self.routines) do
        if getRuntimeState(v) ~= 0 then
          protectedCall(v, "update", dtime)
        end
      end
    end,
    save = function(self, ...)
      local routineData = { }
      for i, v in pairs(self.routines) do
        routineData[i] = {
          rdata = table.pack(protectedCall(v, "save")),
          clsName = getFullName(v.__class)
        }
      end
      return {
        mdata = _class_0.__parent.save(self, ...),
        nextId = self.nextRoutineId,
        routineData = routineData
      }
    end,
    load = function(self, ...)
      local data = ...
      _class_0.__parent.load(self, data.mdata)
      self.nextRoutineId = data.nextId
      for rid, routine in pairs(data.routineData) do
        local cls = self.classes[routine.clsName]
        local props = {
          terminate = function(...)
            return self:clearRoutine(rid, ...)
          end,
          serviceManager = self.serviceManager
        }
        local inst = cls(props)
        protectedCall(inst, "load", unpack(routine.rdata))
        protectedCall(inst, "postInit")
        self.routines[rid] = inst
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, parent, serviceManager)
      _class_0.__parent.__init(self, parent, serviceManager)
      self.serviceManager = serviceManager
      self.intervals = { }
      self.nextIntervalId = 1
      self.nextRoutineId = 1
      self.routines = { }
      self.classes = { }
      self.garbage = { }
    end,
    __base = _base_0,
    __name = "RuntimeController",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  RuntimeController = _class_0
end
local Timer
do
  local _class_0
  local _base_0 = {
    _round = function(self)
      self:reset()
      self.life = self.life - 1
      if (self.life <= 0) then
        self.running = false
      end
      return self.alarmSubject:onNext(self, math.abs(self.life), self.acc)
    end,
    update = function(self, dtime)
      if (self.running) then
        self.acc = self.acc + dtime
        self.tleft = self.tleft - dtime
        if (self.tleft <= 0) then
          return self:_round()
        end
      end
    end,
    start = function(self)
      if self.r_id < 0 then
        if (self.life > 0) then
          self.running = true
          self.r_id = self.runtimeController:setInterval((function()
            local _base_1 = self
            local _fn_0 = _base_1.update
            return function(...)
              return _fn_0(_base_1, ...)
            end
          end)(), self.time / 4)
        end
      end
    end,
    setLife = function(self, life)
      self.life = life
    end,
    reset = function(self)
      self.tleft = self.time
    end,
    stop = function(self)
      if self.running then
        self.runtimeController:clearInterval(self.r_id)
        self.r_id = -1
      end
      self:pause()
      return self:reset()
    end,
    pause = function(self)
      self.running = false
    end,
    onAlarm = function(self)
      return self.alarmSubject
    end,
    save = function(self)
      return self.tleft, self.acc, self.running, self.life, self.r_id
    end,
    load = function(self, ...)
      self.tleft, self.acc, self.running, self.life = ...
      if self.running then
        return self:start()
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, time, loop, serviceManager)
      if loop == nil then
        loop = 0
      end
      self.life = loop + 1
      self.time = time
      self.acc = 0
      self.tleft = time
      self.running = false
      self.alarmSubject = Subject.create()
      self.r_id = -1
      return serviceManager:getService("bzutils.runtime"):subscribe(function(runtimeController)
        self.runtimeController = runtimeController
      end)
    end,
    __base = _base_0,
    __name = "Timer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Timer = _class_0
end
return {
  RuntimeController = RuntimeController,
  getRuntimeState = getRuntimeState,
  Timer = Timer
}
 end)
package.preload['ecs_module'] = (function (...)
local utils = require("utils")
local bz_handle = require("bz_handle")
local net = require("net")
local rx = require("rx")
local tiny = require("tiny")
local bztiny = require("bztiny")
local bzcomponents = require("bzcomp")
local bzsystems = require("bzsystems")
local Module = require("module")
local event = require("event")
local Subject
Subject = rx.Subject
local namespace, OdfFile, getMeta, getFullName
namespace, OdfFile, getMeta, getFullName = utils.namespace, utils.OdfFile, utils.getMeta, utils.getFullName
local EcsWorld, requireAny, requireAll, Component, getComponentOdfs
EcsWorld, requireAny, requireAll, Component, getComponentOdfs = bztiny.EcsWorld, bztiny.requireAny, bztiny.requireAll, bztiny.Component, bztiny.getComponentOdfs
local BzNetworkSystem, BzPlayerSystem, BzPositionSystem
BzNetworkSystem, BzPlayerSystem, BzPositionSystem = bzsystems.BzNetworkSystem, bzsystems.BzPlayerSystem, bzsystems.BzPositionSystem
local BzHandleComponent, BzBuildingComponent, BzVehicleComponent, BzPlayerComponent, BzPersonComponent, BzRecyclerComponent, BzFactoryComponent, BzConstructorComponent, BzArmoryComponent, BzHowitzerComponent, BzWalkerComponent, BzWingmanComponent, BzGuntowerComponent, BzScavengerComponent, BzTugComponent, BzMinelayerComponent, BzTurretComponent, BzHangarComponent, BzSupplydepotComponent, BzSiloComponent, BzCommtowerComponent, BzPortalComponent, BzPowerplantComponent, BzSignComponent, BzArtifactComponent, BzStructureComponent, BzAnimstructureComponent, BzBarracksComponent, PositionComponent, BzLocalComponent, BzRemoteComponent
BzHandleComponent, BzBuildingComponent, BzVehicleComponent, BzPlayerComponent, BzPersonComponent, BzRecyclerComponent, BzFactoryComponent, BzConstructorComponent, BzArmoryComponent, BzHowitzerComponent, BzWalkerComponent, BzConstructorComponent, BzWingmanComponent, BzGuntowerComponent, BzScavengerComponent, BzTugComponent, BzMinelayerComponent, BzTurretComponent, BzHangarComponent, BzSupplydepotComponent, BzSiloComponent, BzCommtowerComponent, BzPortalComponent, BzPowerplantComponent, BzSignComponent, BzArtifactComponent, BzStructureComponent, BzAnimstructureComponent, BzBarracksComponent, PositionComponent, BzLocalComponent, BzRemoteComponent = bzcomponents.BzHandleComponent, bzcomponents.BzBuildingComponent, bzcomponents.BzVehicleComponent, bzcomponents.BzPlayerComponent, bzcomponents.BzPersonComponent, bzcomponents.BzRecyclerComponent, bzcomponents.BzFactoryComponent, bzcomponents.BzConstructorComponent, bzcomponents.BzArmoryComponent, bzcomponents.BzHowitzerComponent, bzcomponents.BzWalkerComponent, bzcomponents.BzConstructorComponent, bzcomponents.BzWingmanComponent, bzcomponents.BzGuntowerComponent, bzcomponents.BzScavengerComponent, bzcomponents.BzTugComponent, bzcomponents.BzMinelayerComponent, bzcomponents.BzTurretComponent, bzcomponents.BzHangarComponent, bzcomponents.BzSupplydepotComponent, bzcomponents.BzSiloComponent, bzcomponents.BzCommtowerComponent, bzcomponents.BzPortalComponent, bzcomponents.BzPowerplantComponent, bzcomponents.BzSignComponent, bzcomponents.BzArtifactComponent, bzcomponents.BzStructureComponent, bzcomponents.BzAnimstructureComponent, bzcomponents.BzBarracksComponent, bzcomponents.PositionComponent, bzcomponents.BzLocalComponent, bzcomponents.BzRemoteComponent
local EventDispatcher, Event
EventDispatcher, Event = event.EventDispatcher, event.Event
local USE_HANDLE_COMPONENT = true
local USE_PLAYER_COMPONENT = true
local USE_VEHICLE_COMPONENT = true
local classname_components = {
  ["recycler"] = BzRecyclerComponent,
  ["factory"] = BzFactoryComponent,
  ["armory"] = BzArmoryComponent,
  ["wingman"] = BzWingmanComponent,
  ["constructionrig"] = BzConstructorComponent,
  ["howitzer"] = BzHowitzerComponent,
  ["scavenger"] = BzScavengerComponent,
  ["tug"] = BzTugComponent,
  ["turret"] = BzGuntowerComponent,
  ["walker"] = BzWalkerComponent,
  ["turrettank"] = BzTurretComponent,
  ["minelayer"] = BzMinelayerComponent,
  ["repairdepot"] = BzHangarComponent,
  ["supplydepot"] = BzSupplydepotComponent,
  ["silo"] = BzSiloComponent,
  ["commtower"] = BzCommtowerComponent,
  ["portal"] = BzPortalComponent,
  ["powerplant"] = BzPowerplantComponent,
  ["sign"] = BzSignComponent,
  ["artifact"] = BzArtifactComponent,
  ["i76building"] = BzStructureComponent,
  ["i76building2"] = BzStructureComponent,
  ["animbuilding"] = BzAnimstructureComponent
}
local misc_components = {
  [BzBuildingComponent] = IsBuilding,
  [BzVehicleComponent] = IsCraft,
  [BzPersonComponent] = IsPerson
}
local EcsModule
do
  local _class_0
  local _parent_0 = Module
  local _base_0 = {
    getDispatcher = function(self)
      return self.dispatcher
    end,
    start = function(self)
      _class_0.__parent.start(self)
      for i in AllObjects() do
        self:_regHandle(i)
      end
    end,
    _setMiscComponents = function(self, entity, handle)
      local className = GetClassLabel(handle)
      local classComponent = classname_components[className]
      if classComponent then
        classComponent:addEntity(entity)
      end
      for miscComponent, filter in pairs(misc_components) do
        if filter(handle) then
          miscComponent:addEntity(entity)
        end
      end
    end,
    _loadComponentsFromOdf = function(self, entity, handle)
      local odf = GetOdf(handle)
      local file = OdfFile(odf)
      for component, _ in pairs(getComponentOdfs()) do
        local cMeta = getMeta(component, "ecs.fromfile")
        local header = cMeta.header
        local use = file:getBool(header, header, false)
        if use then
          local comp = component:addEntity(entity)
          file:getFields(header, cMeta.fields, comp)
        end
      end
    end,
    addSystem = function(self, system)
      self.world:addSystem(system)
      do
        local _base_1 = self
        local _fn_0 = _base_1.getEntityByHandle
        system.getEntityByHandle = function(...)
          return _fn_0(_base_1, ...)
        end
      end
      do
        local _base_1 = self
        local _fn_0 = _base_1._regHandle
        system.registerHandle = function(...)
          return _fn_0(_base_1, ...)
        end
      end
      return self.dispatcher:dispatch(Event("ECS_ADD_SYSTEM", self, nil, system))
    end,
    replaceHandle = function(self, old, new)
      self.handlesToProcess[new] = nil
      local eid = self:getEntityId(old)
      local entity = self:getEntity(eid)
      local handleComponent = BzHandleComponent:getComponent(entity)
      handleComponent.handle = new
      if self:getEntityId(new) ~= nil then
        local neid = self:getEntityId(new)
        self.world:removeEntity(neid)
      end
      self.hmap[old] = nil
      self.hmap[new] = eid
      return RemoveObject(old)
    end,
    _regHandle = function(self, handle)
      self.handlesToProcess[handle] = nil
      if not self.hmap[handle] then
        local eid, e = self.world:createEntity()
        local c1 = BzHandleComponent:addEntity(e)
        c1.handle = handle
        local c2 = PositionComponent:addEntity(e)
        c2.position = GetPosition(handle)
        if IsNetGame() then
          if IsLocal(handle) then
            BzLocalComponent:addEntity(e)
          end
          if IsRemote(handle) then
            BzRemoteComponent:addEntity(e)
          end
        else
          BzLocalComponent:addEntity(e)
        end
        self.hmap[handle] = eid
        self:_loadComponentsFromOdf(e, handle)
        self:_setMiscComponents(e, handle)
        return self.dispatcher:dispatch(Event("ECS_REG_HANDLE", self, nil, handle, eid, e))
      end
    end,
    _unregHandle = function(self, handle)
      local eid = self.hmap[handle]
      if eid then
        local entity = self.world:getTinyEntity(eid)
        if entity then
          local handleComponent = BzHandleComponent:getComponent(entity)
          if handleComponent and handleComponent.removeOnDeath then
            self.world:removeEntity(eid)
          end
          self.dispatcher:dispatch(Event("ECS_UNREG_HANDLE", self, nil, handle, eid, entity))
        end
        self.hmap[handle] = nil
      end
    end,
    getWorld = function(self)
      return self.world
    end,
    update = function(self, dtime)
      _class_0.__parent.update(self, dtime)
      for i, v in pairs(self.handlesToProcess) do
        self:_regHandle(i)
        self.handlesToProcess[i] = nil
      end
      self.world:update(dtime)
      return self.world:refresh()
    end,
    createObject = function(self, handle)
      self.handlesToProcess[handle] = true
    end,
    addObject = function(self, handle)
      _class_0.__parent.addObject(self, handle)
      self.handlesToProcess[handle] = true
    end,
    deleteObject = function(self, handle)
      _class_0.__parent.deleteObject(self, handle)
      return self:_unregHandle(handle)
    end,
    getEntityByHandle = function(self, handle)
      local id = self:getEntityId(handle)
      if id ~= nil then
        return self:getEntity(id)
      end
    end,
    getEntityId = function(self, handle)
      return self.hmap[handle]
    end,
    getEntity = function(self, id)
      return self.world:getTinyEntity(id)
    end,
    save = function(self)
      local data = {
        ecs = self.world:save(),
        handles = self.hmap
      }
      return data
    end,
    load = function(self, data)
      self.world:load(data.ecs)
      self.hmap = data.handles
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      _class_0.__parent.__init(self, ...)
      self.hmap = { }
      self.world = EcsWorld()
      self.handlesToProcess = { }
      self.dispatcher = EventDispatcher()
      self:addSystem(BzPositionSystem():createSystem())
      return self:addSystem(BzPlayerSystem():createSystem())
    end,
    __base = _base_0,
    __name = "EcsModule",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  EcsModule = _class_0
end
namespace("core.ecs", EcsModule)
return {
  EntityComponentSystemModule = EcsModule
}
 end)
package.preload['sock_m'] = (function (...)
local Module = require("module")
local rx = require("rx")
local NetSocketModule
do
  local _class_0
  local _parent_0 = Module
  local _base_0 = {
    update = function(self)
      for i, v in pairs(self.sockets) do
        if not v:isClosed() then
          v:_update()
        else
          self:unregSocket(i)
        end
      end
    end,
    unregSocket = function(self, id)
      if self.subscriptions[id] then
        self.subscriptions[id]:unsubscribe()
      end
      self.sockets[id] = nil
    end,
    handleSocket = function(self, socket)
      local id = self.nextId
      self.nextId = self.nextId + 1
      self.sockets[id] = socket
      if socket.mode == "ACCEPT" then
        local sub = socket:accept():subscribe((function()
          local _base_1 = self
          local _fn_0 = _base_1.handleSocket
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(), nil, nil)
        self.subscriptions[id] = sub
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, parent, serviceManager)
      _class_0.__parent.__init(self, parent, serviceManager)
      self.serviceManager = serviceManager
      self.sockets = { }
      self.nextId = 1
      self.subscriptions = { }
    end,
    __base = _base_0,
    __name = "NetSocketModule",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  NetSocketModule = _class_0
end
return {
  NetSocketModule = NetSocketModule,
  getUserId = getUserId,
  getAppInfo = getAppInfo,
  readString = readString,
  writeString = writeString
}
 end)
package.preload['event'] = (function (...)
local utils = require("utils")
local Rx = require("rx")
local Module = require("module")
local Subject
Subject = Rx.Subject
local Event
do
  local _class_0
  local _base_0 = {
    getArgs = function(self)
      return unpack(self.args)
    end,
    getName = function(self)
      return self.name
    end,
    getSource = function(self)
      return self.source
    end,
    getTarget = function(self)
      return self.target
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, name, source, target, ...)
      self.name = name
      self.source = source
      self.target = target
      self.args = table.pack(...)
    end,
    __base = _base_0,
    __name = "Event"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Event = _class_0
end
local EventDispatcher
do
  local _class_0
  local _base_0 = {
    on = function(self, event)
      if (not self.subjects[event]) then
        self.subjects[event] = Subject.create()
      end
      return self.subjects[event]
    end,
    dispatch = function(self, event)
      if (self.subjects[event.name]) then
        return self.subjects[event.name]:onNext(event)
      end
    end,
    queueEvent = function(self, event)
      return table.insert(self.eventQueue, event)
    end,
    dispatchQueue = function(self)
      for i, event in ipairs(self.eventQueue) do
        self:dispatch(event)
      end
      self.eventQueue = { }
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.subjects = { }
      self.eventQueue = { }
    end,
    __base = _base_0,
    __name = "EventDispatcher"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  EventDispatcher = _class_0
end
local EventDispatcherModule
do
  local _class_0
  local _parent_0 = Module
  local _base_0 = {
    getDispatcher = function(self)
      return self.dispatcher
    end,
    start = function(self)
      _class_0.__parent.start(self)
      return self.dispatcher:dispatch(Event("START", nil, nil))
    end,
    addObject = function(self, ...)
      _class_0.__parent.addObject(self, ...)
      return self.dispatcher:dispatch(Event("ADD_OBJECT", nil, nil, ...))
    end,
    createObject = function(self, ...)
      _class_0.__parent.createObject(self, ...)
      return self.dispatcher:dispatch(Event("CREATE_OBJECT", nil, nil, ...))
    end,
    deleteObject = function(self, ...)
      _class_0.__parent.deleteObject(self, ...)
      return self.dispatcher:dispatch(Event("DELETE_OBJECT", nil, nil, ...))
    end,
    addPlayer = function(self, ...)
      _class_0.__parent.addPlayer(self, ...)
      return self.dispatcher:dispatch(Event("ADD_PLAYER", nil, nil, ...))
    end,
    createPlayer = function(self, ...)
      _class_0.__parent.createPlayer(self, ...)
      return self.dispatcher:dispatch(Event("CREATE_PLAYER", nil, nil, ...))
    end,
    deletePlayer = function(self, ...)
      _class_0.__parent.deletePlayer(self, ...)
      return self.dispatcher:dispatch(Event("DELETE_PLAYER", nil, nil, ...))
    end,
    gameKey = function(self, ...)
      _class_0.__parent.gameKey(self, ...)
      return self.dispatcher:dispatch(Event("GAME_KEY", nil, nil, ...))
    end,
    update = function(self, ...)
      _class_0.__parent.update(self, ...)
      return self.dispatcher:dispatch(Event("UPDATE", nil, nil, ...))
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      _class_0.__parent.__init(self, ...)
      self.dispatcher = EventDispatcher()
    end,
    __base = _base_0,
    __name = "EventDispatcherModule",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  EventDispatcherModule = _class_0
end
return {
  EventDispatcherModule = EventDispatcherModule,
  EventDispatcher = EventDispatcher,
  Event = Event
}
 end)
package.preload['bzcomp'] = (function (...)
local bztiny = require("bztiny")
local utils = require("utils")
local Component
Component = bztiny.Component
local namespace
namespace = utils.namespace
local BzHandleComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.removeOnDeath = true
    end,
    __base = _base_0,
    __name = "BzHandleComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzHandleComponent = _class_0
end
local BzBuildingComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzBuildingComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzBuildingComponent = _class_0
end
local BzVehicleComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzVehicleComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzVehicleComponent = _class_0
end
local BzPersonComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzPersonComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzPersonComponent = _class_0
end
local BzPlayerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzPlayerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzPlayerComponent = _class_0
end
local BzLocalComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzLocalComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzLocalComponent = _class_0
end
local BzRemoteComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzRemoteComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzRemoteComponent = _class_0
end
local BzRecyclerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzRecyclerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzRecyclerComponent = _class_0
end
local BzFactoryComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzFactoryComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzFactoryComponent = _class_0
end
local BzArmoryComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzArmoryComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzArmoryComponent = _class_0
end
local BzHowitzerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzHowitzerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzHowitzerComponent = _class_0
end
local BzWalkerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzWalkerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzWalkerComponent = _class_0
end
local BzConstructorComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzConstructorComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzConstructorComponent = _class_0
end
local BzWingmanComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzWingmanComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzWingmanComponent = _class_0
end
local BzGuntowerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzGuntowerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzGuntowerComponent = _class_0
end
local BzTurretComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzTurretComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzTurretComponent = _class_0
end
local BzScavengerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzScavengerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzScavengerComponent = _class_0
end
local BzTugComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzTugComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzTugComponent = _class_0
end
local BzMinelayerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzMinelayerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzMinelayerComponent = _class_0
end
local BzHangarComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzHangarComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzHangarComponent = _class_0
end
local BzSupplydepotComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzSupplydepotComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzSupplydepotComponent = _class_0
end
local BzSiloComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzSiloComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzSiloComponent = _class_0
end
local BzCommtowerComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzCommtowerComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzCommtowerComponent = _class_0
end
local BzPortalComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzPortalComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzPortalComponent = _class_0
end
local BzPowerplantComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzPowerplantComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzPowerplantComponent = _class_0
end
local BzSignComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzSignComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzSignComponent = _class_0
end
local BzArtifactComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzArtifactComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzArtifactComponent = _class_0
end
local BzStructureComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzStructureComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzStructureComponent = _class_0
end
local BzAnimstructureComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzAnimstructureComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzAnimstructureComponent = _class_0
end
local BzBarracksComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzBarracksComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzBarracksComponent = _class_0
end
local BzCamerapodComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzCamerapodComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzCamerapodComponent = _class_0
end
local PositionComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.position = SetVector(0, 0, 0)
    end,
    __base = _base_0,
    __name = "PositionComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PositionComponent = _class_0
end
local ParticleEmitterComponent
do
  local _class_0
  local _parent_0 = Component
  local _base_0 = {
    init = function(self, min, max)
      if max == nil then
        max = min
      end
      self.minInterval = min
      self.maxInterval = max
      self._init = true
      return self:nextInterval()
    end,
    nextInterval = function(self)
      local diff = self.maxInterval - self.minInterval
      self.nextExpl = self.minInterval + diff * math.random()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.explodf = nil
      self.nextExpl = 0
      self.minInterval = 0
      self.maxInterval = 0
      self._init = false
    end,
    __base = _base_0,
    __name = "ParticleEmitterComponent",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ParticleEmitterComponent = _class_0
end
local components = {
  BzHandleComponent = BzHandleComponent,
  BzBuildingComponent = BzBuildingComponent,
  BzVehicleComponent = BzVehicleComponent,
  BzPlayerComponent = BzPlayerComponent,
  BzPersonComponent = BzPersonComponent,
  BzRecyclerComponent = BzRecyclerComponent,
  BzFactoryComponent = BzFactoryComponent,
  BzArmoryComponent = BzArmoryComponent,
  BzHowitzerComponent = BzHowitzerComponent,
  BzWalkerComponent = BzWalkerComponent,
  BzConstructorComponent = BzConstructorComponent,
  BzWingmanComponent = BzWingmanComponent,
  BzGuntowerComponent = BzGuntowerComponent,
  BzTurretComponent = BzTurretComponent,
  BzScavengerComponent = BzScavengerComponent,
  BzTugComponent = BzTugComponent,
  BzMinelayerComponent = BzMinelayerComponent,
  BzHangarComponent = BzHangarComponent,
  BzSupplydepotComponent = BzSupplydepotComponent,
  BzSiloComponent = BzSiloComponent,
  BzCommtowerComponent = BzCommtowerComponent,
  BzPortalComponent = BzPortalComponent,
  BzPowerplantComponent = BzPowerplantComponent,
  BzSignComponent = BzSignComponent,
  BzArtifactComponent = BzArtifactComponent,
  BzStructureComponent = BzStructureComponent,
  BzAnimstructureComponent = BzAnimstructureComponent,
  BzBarracksComponent = BzBarracksComponent,
  ParticleEmitterComponent = ParticleEmitterComponent,
  BzLocalComponent = BzLocalComponent,
  BzRemoteComponent = BzRemoteComponent,
  PositionComponent = PositionComponent
}
for i, v in pairs(components) do
  namespace("ecs.component", v)
end
return components
 end)
package.preload['bzserial'] = (function (...)
local utils = require("utils")
local getFullName, getClass, getMeta, setMeta, applyMeta
getFullName, getClass, getMeta, setMeta, applyMeta = utils.getFullName, utils.getClass, utils.getMeta, utils.setMeta, utils.applyMeta
local useSerializer
useSerializer = function(cls, serializer, include, exclude)
  return setMeta(cls, "component_serializer", {
    serializer = serializer,
    include = include,
    exclude = exclude
  })
end
local defaultKeyFunction
defaultKeyFunction = function(object)
  local ret = { }
  for key, value in pairs(object) do
    local startWithUnderscore = type(key) == "string" and key:find("_")
    if startWithUnderscore == nil or startWithUnderscore > 1 then
      ret[key] = value
    end
  end
  return ret
end
local Serializer
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Serializer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.serialize = function(self, component) end
  self.deserialize = function(self, data, cls) end
  self.use = function(self, cls, ...)
    return useSerializer(cls, self.__class, ...)
  end
  Serializer = _class_0
end
local TinySerializer
do
  local _class_0
  local _parent_0 = Serializer
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "TinySerializer",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.serialize = function(self, component)
    return defaultKeyFunction(component)
  end
  self.deserialize = function(self, data, cls)
    return data
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TinySerializer = _class_0
end
local BzTinyComponentSerializer
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "BzTinyComponentSerializer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.serialize = function(self, component)
    local className = getFullName(component)
    return defaultKeyFunction(component)
  end
  self.deserialize = function(self, data, cls)
    local component = cls()
    for k, v in pairs(data) do
      component[k] = v
    end
    return component
  end
  BzTinyComponentSerializer = _class_0
end
local serializeEntity
serializeEntity = function(entity)
  local ret = { }
  for name, component in pairs(entity) do
    local cls = component.__class
    local serializer = TinySerializer
    local clsName = nil
    if cls then
      clsName = getFullName(cls)
      local component_serializer = getMeta(cls).component_serializer
      if component_serializer then
        serializer = getMeta(cls).component_serializer.serializer
      else
        serializer = BzTinyComponentSerializer
      end
    end
    local componentData = serializer:serialize(component)
    ret[name] = {
      clsName = clsName,
      componentData = componentData
    }
  end
  return ret
end
local deserializeEntity
deserializeEntity = function(entityData, entity)
  for componentName, data in pairs(entityData) do
    local serializer = TinySerializer
    entity[componentName] = { }
    local cls = nil
    if data.clsName then
      cls = getClass(data.clsName)
      local component_serializer = getMeta(cls).component_serializer
      if component_serializer then
        serializer = getMeta(cls).component_serializer.serializer
      else
        serializer = BzTinyComponentSerializer
      end
    end
    entity[componentName] = serializer:deserialize(data.componentData, cls)
  end
end
return {
  serializeEntity = serializeEntity,
  deserializeEntity = deserializeEntity,
  Serializer = Serializer,
  TinySerializer = TinySerializer,
  BzTinyComponentSerializer = BzTinyComponentSerializer,
  defaultKeyFunction = defaultKeyFunction,
  useSerializer = useSerializer
}
 end)
package.preload['bztiny'] = (function (...)
local utils = require("utils")
local rx = require("rx")
local tiny = require("tiny")
local event = require("event")
local bzserializers = require("bzserial")
local Subject
Subject = rx.Subject
local namespace, getFullName, setMeta, getMeta
namespace, getFullName, setMeta, getMeta = utils.namespace, utils.getFullName, utils.setMeta, utils.getMeta
local Event, EventDispatcher
Event, EventDispatcher = event.Event, event.EventDispatcher
local serializeEntity, deserializeEntity
serializeEntity, deserializeEntity = bzserializers.serializeEntity, bzserializers.deserializeEntity
local convertArgsToNames
convertArgsToNames = function(...)
  local t = {
    ...
  }
  for i = 1, #t do
    t[i] = (type(t[i]) == "string" or type(t[i]) == "function") and t[i] or getFullName(t[i])
  end
  return unpack(t)
end
local requireAll
requireAll = function(...)
  local args = table.pack(...)
  return function(system, entity)
    return tiny.requireAll(convertArgsToNames(unpack(args)))(system, entity)
  end
end
local requireAny
requireAny = function(...)
  local args = table.pack(...)
  return function(system, entity)
    return tiny.requireAny(convertArgsToNames(unpack(args)))(system, entity)
  end
end
local rejectAny
rejectAny = function(...)
  local args = table.pack(...)
  return function(system, entity)
    return tiny.rejectAny(convertArgsToNames(unpack(args)))(system, entity)
  end
end
local rejectAll
rejectAll = function(...)
  local args = table.pack(...)
  return function(system, entity)
    return tiny.rejectAll(convertArgsToNames(unpack(args)))(system, entity)
  end
end
local _component_odfs = setmetatable({ }, { })
local loadFromFile
loadFromFile = function(component, header, fields)
  if fields == nil then
    fields = { }
  end
  setMeta(component, "ecs.fromfile", {
    header = header,
    fields = fields
  })
  _component_odfs[component] = true
end
local getComponentOdfs
getComponentOdfs = function()
  return _component_odfs
end
local Component
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Component"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.entities = { }
  self.dispatcher = EventDispatcher()
  self.addEntity = function(self, entity)
    local id = getMeta(entity, "ecs").id
    if id then
      self.entities[id] = entity
    end
    local cm = self:getName()
    if not entity[cm] then
      entity[cm] = self()
    end
    self.dispatcher:dispatch(Event("ECS_COMPONENT_ADDED", self, nil, entity))
    return entity[cm]
  end
  self.removeEntity = function(self, entity)
    print("removing component from entity", entity, self:getName())
    self.dispatcher:dispatch(Event("ECS_COMPONENT_REMOVED", self, nil, entity))
    entity[self:getName()] = nil
  end
  self.getComponent = function(self, entity)
    return entity[self:getName()]
  end
  self.getName = function(self)
    return getFullName(self)
  end
  self.getEntities = function(self)
    return self.entities
  end
  self.getDispatcher = function(self)
    return self.dispatcher
  end
  Component = _class_0
end
local EcsWorld
do
  local _class_0
  local _base_0 = {
    update = function(self, dtime)
      self.acc = self.acc + dtime
      for i = 1, math.floor(self.acc * self.TPS) do
        tiny.update(self.world, 1 / self.TPS)
        tiny.refresh(self.world)
        self.acc = self.acc - (1 / self.TPS)
      end
    end,
    createEntity = function(self, eid)
      if not eid then
        eid = self.nextId
        self.nextId = self.nextId + 1
      end
      local entity = { }
      setMeta(entity, "ecs", {
        id = eid
      })
      tiny.addEntity(self.world, entity)
      self.entities[eid] = entity
      self.dispatcher:dispatch(Event("ECS_CREATE_ENTITY", self, nil, entity))
      return eid, entity
    end,
    updateTinyEntity = function(self, entity)
      return tiny.addEntity(self.world, entity)
    end,
    updateEntity = function(self, eid)
      return self:updateTinyEntity(self:getTinyEntity(eid))
    end,
    removeEntity = function(self, eid)
      if (self.entities[eid]) then
        tiny.removeEntity(self.world, self.entities[eid])
        self.dispatcher:dispatch(Event("ECS_REMOVE_ENTITY", self, nil, self.entities[eid]))
        self.entities[eid] = nil
      end
    end,
    removeTinyEntity = function(self, entity)
      local id = self:getEntityId(entity)
      return self:removeEntity(id)
    end,
    addSystem = function(self, system)
      tiny.addSystem(self.world, system)
      system.bzworld = self
      return self.dispatcher:dispatch(Event("ECS_ADD_SYSTEM", self, nil, system))
    end,
    getTinyWorld = function(self)
      return self.world
    end,
    getDispatcher = function(self)
      return self.dispatcher
    end,
    remove = function(self, ...)
      return tiny.remove(self.world, ...)
    end,
    getTinyEntity = function(self, eid)
      return self.entities[eid]
    end,
    getEntityId = function(self, entity)
      return getMeta(entity, "ecs").id
    end,
    getEntities = function(self)
      return self.entities
    end,
    refresh = function(self)
      return tiny.refresh(self.world)
    end,
    removeSystem = function(self, system)
      tiny.removeSystem(self.world, system)
      system.bzworld = nil
      return self.dispatcher:dispatch(Event("ECS_ADD_SYSTEM", self, nil, system))
    end,
    clearSystems = function(self, ...)
      for i = #self.world.systems, 1, -1 do
        self:removeSystem(self.world.systems[i])
      end
      tiny.clearSystems(self.world, ...)
      return self.dispatcher:dispatch(Event("ECS_CLEAR_SYSTEMS", self, nil, ...))
    end,
    clearEntities = function(self, ...)
      for i, v in ipairs(self.world.entities) do
        self:removeTinyEntity(v)
      end
      tiny.clearEntities(self.world, ...)
      return self.dispatcher:dispatch(Event("ECS_CLEAR_ENTITIES", self, nil, ...))
    end,
    getEntityCount = function(self, ...)
      return tiny.getEntityCount(self.world, ...)
    end,
    getSystemCount = function(self, ...)
      return tiny.getSystemCount(self.world, ...)
    end,
    setSystemIndex = function(self, ...)
      return tiny.setSystemIndex(self.world, ...)
    end,
    save = function(self)
      local data = {
        entities = { },
        _entity_count = self:getEntityCount(),
        _next_id = self.nextId
      }
      local entities = self:getEntities()
      for id, entity in pairs(entities) do
        data.entities[id] = serializeEntity(entity)
      end
      return data
    end,
    load = function(self, data)
      self.nextId = data._next_id
      for id, entityData in pairs(data.entities) do
        local eid, entity = self:createEntity(id)
        deserializeEntity(entityData, entity)
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, ...)
      self.world = tiny.world(...)
      self.world.bzworld = self
      self.entities = { }
      self.nextId = 1
      self.TPS = 60
      self.acc = 0
      self.dispatcher = EventDispatcher()
    end,
    __base = _base_0,
    __name = "EcsWorld"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  EcsWorld = _class_0
end
namespace("ecs", EcsWorld, Component)
return {
  EcsWorld = EcsWorld,
  requireAll = requireAll,
  requireAny = requireAny,
  rejectAll = rejectAll,
  rejectAny = rejectAny,
  Component = Component,
  loadFromFile = loadFromFile,
  getComponentOdfs = getComponentOdfs
}
 end)
package.preload['bzsystems'] = (function (...)
local tiny = require("tiny")
local bztiny = require("bztiny")
local bzcomponents = require("bzcomp")
local BzPlayerComponent, BzHandleComponent, PositionComponent, BzBuildingComponent, ParticleEmitterComponent, BzLocalComponent, BzRemoteComponent
BzPlayerComponent, BzHandleComponent, PositionComponent, BzBuildingComponent, ParticleEmitterComponent, BzLocalComponent, BzRemoteComponent = bzcomponents.BzPlayerComponent, bzcomponents.BzHandleComponent, bzcomponents.PositionComponent, bzcomponents.BzBuildingComponent, bzcomponents.ParticleEmitterComponent, bzcomponents.BzLocalComponent, bzcomponents.BzRemoteComponent
local System
do
  local _class_0
  local _base_0 = {
    createSystem = function(self, f)
      return f(self)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "System"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.processingSystem = function(self, ...)
    local inst = self(...)
    inst.__type = "processingSystem"
    return tiny.processingSystem(inst)
  end
  self.sortedSystem = function(self, ...)
    local inst = self(...)
    inst.__type = "sortedSystem"
    return tiny.sortedSystem(inst)
  end
  self.sortedProcessingSystem = function(self, ...)
    local inst = self(...)
    inst.__type = "sortedProcessingSystem"
    return tiny.sortedProcessingSystem(inst)
  end
  self.system = function(self, ...)
    local inst = self(...)
    inst.__type = "system"
    return tiny.system(inst)
  end
  System = _class_0
end
local BzPlayerSystem
do
  local _class_0
  local _parent_0 = System
  local _base_0 = {
    filter = bztiny.requireAll(BzHandleComponent),
    process = function(self, entity)
      local handle = BzHandleComponent:getComponent(entity).handle
      local playerComponent = BzPlayerComponent:getComponent(entity)
      local isPlayer = GetPlayerHandle() == handle
      if isPlayer and not playerComponent then
        print("update")
        BzPlayerComponent:addEntity(entity)
        return self.bzworld:updateTinyEntity(entity)
      elseif not isPlayer and playerComponent then
        print("update")
        BzPlayerComponent:removeEntity(entity)
        return self.bzworld:updateTinyEntity(entity)
      end
    end,
    createSystem = function(self)
      return _class_0.__parent.__base.createSystem(self, tiny.processingSystem)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzPlayerSystem",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzPlayerSystem = _class_0
end
local BzPositionSystem
do
  local _class_0
  local _parent_0 = System
  local _base_0 = {
    filter = bztiny.requireAll(BzHandleComponent, PositionComponent, bztiny.rejectAny(BzBuildingComponent)),
    process = function(self, entity)
      local positionComponent = PositionComponent:getComponent(entity)
      local handleComponent = BzHandleComponent:getComponent(entity)
      local pos = GetPosition(handleComponent.handle)
      positionComponent.position = pos
    end,
    createSystem = function(self)
      return _class_0.__parent.__base.createSystem(self, tiny.processingSystem)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzPositionSystem",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzPositionSystem = _class_0
end
local BzNetworkSystem
do
  local _class_0
  local _parent_0 = System
  local _base_0 = {
    filter = bztiny.requireAll(BzHandleComponent),
    interval = 2,
    preProcess = function(self)
      self.entitiesToUpdate = { }
    end,
    process = function(self, entity)
      local handleComponent = BzHandleComponent:getComponent(entity)
      local handle = handleComponent.handle
      if IsLocal(handle) and BzLocalComponent:getComponent(entity) == nil then
        BzLocalComponent:addEntity(entity)
        self.entitiesToUpdate[entity] = true
      elseif BzLocalComponent:getComponent(entity) ~= nil then
        BzLocalComponent:removeEntity(entity)
        self.entitiesToUpdate[entity] = true
      end
      if IsRemote(handle) and BzRemoteComponent:getComponent(entity) == nil then
        BzRemoteComponent:addEntity(entity)
        self.entitiesToUpdate[entity] = true
      elseif BzRemoteComponent:getComponent(entity) ~= nil then
        BzRemoteComponent:removeEntity(entity)
        self.entitiesToUpdate[entity] = true
      end
    end,
    postProcess = function(self)
      for i, v in ipairs(self.entitiesToUpdate) do
        self.bzworld:updateTinyEntity(i)
      end
    end,
    createSystem = function(self)
      return _class_0.__parent.__base.createSystem(self, tiny.processingSystem)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BzNetworkSystem",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BzNetworkSystem = _class_0
end
local ParticleSystem
do
  local _class_0
  local _parent_0 = System
  local _base_0 = {
    filter = bztiny.requireAll(ParticleEmitterComponent, PositionComponent),
    process = function(self, entity, dtime)
      local particleComponent = ParticleEmitterComponent:getComponent(entity)
      particleComponent.nextExpl = particleComponent.nextExpl - dtime
      if particleComponent.nextExpl <= 0 then
        particleComponent:nextInterval()
        local odf = particleComponent.nextExpl
        local positionComponent = PositionComponent:getComponent(entity)
        if IsBzr() then
          return MakeExplosion(odf, positionComponent.position)
        end
      end
    end,
    createSystem = function(self)
      return _class_0.__parent.__base.createSystem(self, tiny.processingSystem)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ParticleSystem",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ParticleSystem = _class_0
end
return {
  BzPlayerSystem = BzPlayerSystem,
  BzPositionSystem = BzPositionSystem,
  BzNetworkSystem = BzNetworkSystem,
  System = System
}
 end)
package.preload['exmath'] = (function (...)
local max = math.max
local min = math.min
local pointOnLine
pointOnLine = function(p, q, r)
  return (q.x <= max(p.x, r.x)) and (q.x >= min(p.x, r.x)) and (q.z <= max(p.z, r.z)) and (q.z >= min(p.z, r.z))
end
local vectorOrinetation
vectorOrinetation = function(p, q, r)
  local val = ((q.z - p.z) * (r.x - q.x)) - ((q.x - p.x) * (r.z - q.z))
  if (val == 0) then
    return 0
  end
  if (val > 0) then
    return 1
  end
  return 2
end
local doVectorsIntersect
doVectorsIntersect = function(p1, q1, p2, q2)
  local o1 = vectorOrinetation(p1, q1, p2)
  local o2 = vectorOrinetation(p1, q1, q2)
  local o3 = vectorOrinetation(p2, q2, p1)
  local o4 = vectorOrinetation(p2, q2, q1)
  if (o1 ~= o2 and o3 ~= o4) then
    return true
  end
  if (o1 == 0 and pointOnLine(p1, p2, q1)) then
    return true
  end
  if (o2 == 0 and pointOnLine(p1, q2, q1)) then
    return true
  end
  if (o3 == 0 and pointOnLine(p2, p1, q2)) then
    return true
  end
  if (o4 == 0 and pointOnLine(p2, p1, q2)) then
    return true
  end
  return false
end
local pointOfIntersection
pointOfIntersection = function(p1, p2, q1, q2)
  if doVectorsIntersect(p1, p2, q1, q2) then
    local v1 = p2 - p1
    local v2 = q2 - q1
    local a1 = (v1.z / v1.x)
    local c1 = p1.z - a1 * p1.x
    local a2 = (v2.z / v2.x)
    local c2 = q1.z - a2 * q1.x
    if a1 >= math.huge and a2 >= math.huge then
      return (p1 + q1 + p2 + q2) / 4
    end
    if a1 >= math.huge then
      return SetVector(p1.x, 0, a2 * p1.x + c2)
    end
    if a2 >= math.huge then
      return SetVector(q1.x, 0, a1 * q1.x + c1)
    end
    local x = (c2 - c1) / (a1 - a2)
    return SetVector(x, 0, a1 * x + c1)
  end
end
local doVectorPathsIntersect
doVectorPathsIntersect = function(p1, p2)
  if #p1 <= 0 or #p2 <= 0 then
    return false
  end
  for i = 2, #p1 do
    local v1 = p1[i - 1]
    local v2 = p1[i]
    for j = 2, #p2 do
      local v3 = p2[j - 1]
      local v4 = p2[j]
      if doVectorsIntersect(v1, v2, v3, v4) then
        return true
      end
    end
  end
  return false
end
local pointsOfPathIntersection
pointsOfPathIntersection = function(p1, p2)
  if doVectorPathsIntersect(p1, p2) then
    local ret = { }
    for i = 2, #p1 do
      local v1 = p1[i - 1]
      local v2 = p1[i]
      for j = 2, #p2 do
        local v3 = p2[j - 1]
        local v4 = p2[j]
        local intersection = pointOfIntersection(v1, v2, v3, v4)
        if intersection then
          table.insert(ret, intersection)
        end
      end
    end
    return ret
  end
end
local getWindingNumber
getWindingNumber = function(path, v1)
  local intersections = pointsOfPathIntersection(path, {
    v1,
    SetVector(math.huge, 0, v1.z)
  })
  if intersections then
    return #intersections
  end
  return 0
end
local isInisdeVectorPath
isInisdeVectorPath = function(path, v1)
  return getWindingNumber(path, v1) % 2 ~= 0
end
local local2Global
local2Global = function(v, t)
  local up = SetVector(t.up_x, t.up_y, t.up_z)
  local front = SetVector(t.front_x, t.front_y, t.front_z)
  local right = SetVector(t.right_x, t.right_y, t.right_z)
  return v.x * front + v.y * up + v.z * right
end
local safeDiv
safeDiv = function(a, b)
  if a == 0 then
    return 0
  end
  if b == 0 then
    return math.hugh
  end
  return a / b
end
local safeDivV
safeDivV = function(v1, v2)
  return SetVector(safeDiv(v1.x, v2.x), safeDiv(v1.y, v2.y), safeDiv(v1.z, v2.z))
end
local global2Local
global2Local = function(v, t)
  local up = SetVector(t.up_x, t.up_y, t.up_z)
  local front = SetVector(t.front_x, t.front_y, t.front_z)
  local right = SetVector(t.right_x, t.right_y, t.right_z)
  return SetVector(DotProduct(v, front), DotProduct(v, up), DotProduct(v, right))
end
local Area
do
  local _class_0
  local _base_0 = {
    enable = function(self)
      if self._enabled then
        return 
      end
      self._enabled = true
      for v in ObjectsInRange(self.radius + 50, self.center) do
        if IsInsideArea(self.path, v) then
          self.handles[v] = true
        end
      end
      if self.routineFactory then
        self.subscription = routineFactory():subscribe((function()
          local _base_1 = self
          local _fn_0 = _base_1.update
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)())
      end
    end,
    disable = function(self)
      self._enabled = false
      if self.subscription then
        return self.subscription:unsubscribe()
      end
    end,
    getPath = function(self)
      return self.path
    end,
    getCenter = function(self)
      return self.center
    end,
    getObjects = function(self)
      local _accum_0 = { }
      local _len_0 = 1
      for i, v in pairs(self.handles) do
        _accum_0[_len_0] = i
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end,
    getRadius = function(self)
      return self.radius
    end,
    _bounding = function(self)
      return error("Not implemented")
    end,
    update = function(self)
      local all
      do
        local _tbl_0 = { }
        for i, v in pairs(self.handles) do
          _tbl_0[i] = 1
        end
        all = _tbl_0
      end
      for v in ObjectsInRange(self.radius + 50, self.center) do
        all[v] = 1
      end
      for v, _ in pairs(all) do
        if IsInsideArea(self.path, v) then
          if self.handles[v] == nil then
            self:nextObject(v, true)
          end
          self.handles[v] = true
        else
          if self.handles[v] then
            self:nextObject(v, false)
          end
          self.handles[v] = nil
        end
      end
    end,
    nextObject = function(self, handle, inside)
      self.areaSubjects.all:onNext(self, handle, inside)
      if (self.areaSubjects[handle]) then
        return self.areaSubjects[handle]:onNext(self, handle, inside)
      end
    end,
    onChange = function(self, handle)
      if (handle) then
        self.areaSubjects[handle] = self.areaSubjects[handle] or Subject.create()
        return self.areaSubjects[handle]
      end
      return self.areaSubjects.all
    end,
    save = function(self)
      return self.handles
    end,
    load = function(self, ...)
      self.handles = ...
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, routineFactory)
      self.areaSubjects = {
        all = Subject.create()
      }
      self.type = t
      self.path = path
      self.handles = { }
      self.enabled = false
      self:_bounding()
      if routineFactory then
        self.routineFactory = routineFactory
        return self:enable()
      end
    end,
    __base = _base_0,
    __name = "Area"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Area = _class_0
end
local PolyArea
do
  local _class_0
  local _parent_0 = Area
  local _base_0 = {
    _bounding = function(self)
      local center = GetCenterOfPath(self.path)
      local radius = 0
      for i, v in ipairs(GetPathPoints(self.path)) do
        radius = math.max(radius, Length(v - center))
      end
      self.center = center
      self.radius = radius
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "PolyArea",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PolyArea = _class_0
end
return {
  pointOfIntersection = pointOfIntersection,
  doVectorsIntersect = doVectorsIntersect,
  doVectorPathsIntersect = doVectorPathsIntersect,
  pointsOfPathIntersection = pointsOfPathIntersection,
  local2Global = local2Global,
  global2Local = global2Local,
  Area = Area,
  PolyArea = PolyArea
}
 end)
package.preload['graph'] = (function (...)
local utils = require("utils")
print(utils)
local simpleIdGeneratorFactory, applyMeta, getMeta
simpleIdGeneratorFactory, applyMeta, getMeta = utils.simpleIdGeneratorFactory, utils.applyMeta, utils.getMeta
local idGenerator = simpleIdGeneratorFactory()
local DijkstraSearch = nil
local AstarSearch = nil
local Path
do
  local _class_0
  local _base_0 = {
    getCost = function(self)
      return self.cost
    end,
    getNodes = function(self)
      return self.nodes
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, nodes, cost)
      self.nodes = nodes
      self.cost = cost
    end,
    __base = _base_0,
    __name = "Path"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Path = _class_0
end
local Node, Edge = nil, nil
local AddPositionMeta
AddPositionMeta = function(node, vec)
  return applyMeta(node, {
    position = vec
  })
end
local GetPositionMeta
GetPositionMeta = function(node)
  return getMeta(node, "position")
end
local Graph
do
  local _class_0
  local _base_0 = {
    findPath = function(self, start, goal, algo, cache)
      if algo == nil then
        algo = DijkstraSearch
      end
      if cache == nil then
        cache = true
      end
      if cache and self.paths[start:getId()] and self.paths[start:getId()][goal:getId()] then
        return self.paths[start:getId()][goal:getId()]
      end
      local path = algo(start, goal, self.nodes, self.heurisitcsFunc)
      if not self.paths[start:getId()] then
        self.paths[start:getId()] = { }
      end
      if not self.paths[goal:getId()] then
        self.paths[goal:getId()] = { }
      end
      self.paths[start:getId()][goal:getId()] = path
      self.paths[goal:getId()][start:getId()] = Path(table.reverse(path:getNodes()), path:getCost())
      return path
    end,
    addNodes = function(self, nodes)
      for i, v in ipairs(nodes) do
        table.insert(self.nodes, v)
      end
    end,
    setHeuristicsFunction = function(self, func)
      self.heurisitcsFunc = func
    end,
    getAllNodes = function(self)
      return self.nodes
    end,
    clone = function(self)
      local nodes = { }
      local edges = { }
      for i, v in ipairs(self.nodes) do
        local node = v:clone()
        nodes[v:getId()] = node
        for j, edge in ipairs(v:getEdges()) do
          local nedge = edge:clone()
          if not edges[nedge] then
            edges[nedge] = { }
          end
          local connections = edge:getNodes()
          table.insert(edges[nedge], (function()
            local _accum_0 = { }
            local _len_0 = 1
            for _, n in ipairs(connections) do
              _accum_0[_len_0] = n
              _len_0 = _len_0 + 1
            end
            return _accum_0
          end)())
        end
      end
      for i, v in ipairs(edges) do
        local n1 = nodes[v[1]]
        local n2 = nodes[v[2]]
        i:connect(n1, n2)
      end
      return Graph(nodes)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, nodes)
      if nodes == nil then
        nodes = { }
      end
      self.nodes = nodes
      self.paths = { }
      self.heurisitcsFunc = function()
        return 0
      end
    end,
    __base = _base_0,
    __name = "Graph"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Graph = _class_0
end
do
  local _class_0
  local _base_0 = {
    connect = function(self, n1, n2)
      if not self.connected then
        n1:addEdge(self)
        n2:addEdge(self)
        table.insert(self.nodes, n1)
        table.insert(self.nodes, n2)
        self.connected = true
      end
    end,
    getWeight = function(self)
      return self.weight
    end,
    getNodes = function(self)
      return self.nodes
    end,
    getId = function(self)
      return self.id
    end,
    clone = function(self)
      return Edge(self.weight)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, weight)
      self.weight = weight
      self.connected = false
      self.nodes = { }
      self.id = idGenerator()
    end,
    __base = _base_0,
    __name = "Edge"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Edge = _class_0
end
do
  local _class_0
  local _base_0 = {
    getWeight = function(self)
      return self.weight
    end,
    addEdge = function(self, edge)
      return table.insert(self.edges, edge)
    end,
    getEdges = function(self)
      return self.edges
    end,
    setWeight = function(self, weight)
      self.weight = weight
    end,
    addWeight = function(self, weight)
      self.weight = self.weight + weight
    end,
    getNeighbors = function(self)
      local nodes = { }
      local _list_0 = self.edges
      for _index_0 = 1, #_list_0 do
        local edge = _list_0[_index_0]
        local enodes = edge:getNodes()
        for _index_1 = 1, #enodes do
          local node = enodes[_index_1]
          if node:getId() ~= self:getId() then
            nodes[node] = edge:getWeight() + node:getWeight()
          end
        end
      end
      return nodes
    end,
    getId = function(self)
      return self.id
    end,
    clone = function(self)
      return Node(self.weight)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, weight)
      self.weight = weight
      self.edges = { }
      self.id = idGenerator()
    end,
    __base = _base_0,
    __name = "Node"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Node = _class_0
end
DijkstraSearch = function(start, goal, nodes)
  if start:getId() == goal:getId() then
    return Path({
      start
    }, 0)
  end
  local visitedNodes = { }
  local distances
  do
    local _tbl_0 = { }
    for _index_0 = 1, #nodes do
      local node = nodes[_index_0]
      _tbl_0[node] = math.huge
    end
    distances = _tbl_0
  end
  distances[start] = 0
  local path = { }
  local queue = {
    start
  }
  while #queue > 0 do
    local mdist = math.huge
    local currentNode = nil
    local currentIndex = 1
    for i, node in ipairs(queue) do
      if distances[node] < mdist then
        mdist = distances[node]
        currentIndex = i
      end
    end
    currentNode = table.remove(queue, currentIndex)
    if currentNode == goal then
      break
    end
    for neighbor, cost in pairs(currentNode:getNeighbors()) do
      if not visitedNodes[neighbor] then
        local tcost = distances[currentNode] + cost
        if tcost < distances[neighbor] then
          distances[neighbor] = tcost
          path[neighbor] = currentNode
        end
        table.insert(queue, neighbor)
      end
    end
    visitedNodes[currentNode] = true
  end
  local finalPath = { }
  local u = goal
  if path[u] then
    while u do
      table.insert(finalPath, u)
      u = path[u]
    end
  end
  return Path(table.reverse(finalPath), distances[goal])
end
AstarSearch = function(start, goal, nodes, heurisitcsFunc)
  local closedSet = { }
  local openMap = {
    [start] = true
  }
  local openSet = {
    start
  }
  local path = { }
  local gScore
  do
    local _tbl_0 = { }
    for _index_0 = 1, #nodes do
      local node = nodes[_index_0]
      _tbl_0[node] = math.huge
    end
    gScore = _tbl_0
  end
  gScore[start] = 0
  local fScore
  do
    local _tbl_0 = { }
    for _index_0 = 1, #nodes do
      local node = nodes[_index_0]
      _tbl_0[node] = math.huge
    end
    fScore = _tbl_0
  end
  fScore[start] = heurisitcsFunc(start, goal)
  while #openSet > 0 do
    local currentIndex = 1
    local minf = math.huge
    for i, node in ipairs(openSet) do
      if fScore[node] <= minf then
        minf = fScore[node]
        currentIndex = i
      end
    end
    local currentNode = table.remove(openSet, currentIndex)
    closedSet[currentNode] = true
    openMap[currentNode] = nil
    for neighbor, cost in pairs(currentNode:getNeighbors()) do
      local _continue_0 = false
      repeat
        if not closedSet[neighbor] then
          local tgScore = gScore[currentNode] + cost
          if not openMap[neighbor] then
            openMap[neighbor] = true
            table.insert(openSet, neighbor)
          else
            if tgScore >= gScore[neighbor] then
              _continue_0 = true
              break
            end
          end
          path[neighbor] = currentNode
          gScore[neighbor] = tgScore
          fScore[neighbor] = gScore[neighbor] + heurisitcsFunc(neighbor, goal)
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  local finalPath = { }
  local u = goal
  if path[u] then
    while u do
      table.insert(finalPath, u)
      u = path[u]
    end
  end
  return Path(table.reverse(finalPath), gScore[goal])
end
local createDistanceHeuristics
createDistanceHeuristics = function(nodeMap)
  local distanceMap = { }
  for node, pos in pairs(nodeMap) do
    distanceMap[node] = { }
    for node2, pos2 in pairs(nodeMap) do
      local dist = Distance2D(pos, pos2)
      distanceMap[node][node2] = dist
    end
  end
  return function(a, b)
    return distanceMap[a][b]
  end
end
return {
  Graph = Graph,
  Node = Node,
  Edge = Edge,
  DijkstraSearch = DijkstraSearch,
  AstarSearch = AstarSearch,
  createDistanceHeuristics = createDistanceHeuristics,
  AddPositionMeta = AddPositionMeta,
  GetPositionMeta = GetPositionMeta
}
 end)
package.preload['bz_handle'] = (function (...)
local utils = require("utils")
local rx = require("rx")
local OdfFile, getWepDps
OdfFile, getWepDps = utils.OdfFile, utils.getWepDps
local Subject, ReplaySubject, AsyncSubject
Subject, ReplaySubject, AsyncSubject = rx.Subject, rx.ReplaySubject, rx.AsyncSubject
local copyObject
copyObject = function(handle, odf, team, location, keepWeapons, kill, fraction)
  if keepWeapons == nil then
    keepWeapons = false
  end
  if kill == nil then
    kill = false
  end
  if fraction == nil then
    fraction = true
  end
  local loc = location ~= nil and location or GetTransform(handle)
  odf = odf ~= nil and odf or GetOdf(handle)
  team = team ~= nil and team or GetTeamNum(handle)
  local nObject = BuildObject(odf, team, loc)
  if (location == nil) then
    SetTransform(nObject, loc)
  end
  if (IsAliveAndPilot(handle)) then
    SetPilotClass(nObject, GetPilotClass(handle))
  elseif ((not IsAlive(handle)) and kill) then
    RemovePilot(nObject, handle)
  end
  SetCurHealth(nObject, fraction and GetCurHealth(handle) or GetHealth(handle) * GetMaxHealth(nObject))
  SetCurAmmo(nObject, fraction and GetCurAmmo(handle) or GetAmmo(handle) * GetMaxAmmo(nObject))
  SetVelocity(nObject, GetVelocity(handle))
  SetOmega(nObject, GetOmega(handle))
  if IsDeployed(handle) then
    Deploy(nObject)
  end
  SetIndependence(nObject, GetIndependence(handle))
  if keepWeapons then
    for i, v in ipairs({
      GetWeaponClass(handle, 0),
      GetWeaponClass(handle, 1),
      GetWeaponClass(handle, 2),
      GetWeaponClass(handle, 3),
      GetWeaponClass(handle, 4)
    }) do
      GiveWeapon(nObject, v, i - 1)
    end
  end
  SetOwner(nObject, GetOwner(handle))
  return nObject
end
local Handle
do
  local _class_0
  local _base_0 = {
    getHandle = function(self)
      return self.handle
    end,
    removeObject = function(self)
      return RemoveObject(self:getHandle())
    end,
    getDps = function(self)
      return self.dps
    end,
    cloak = function(self)
      return Cloak(self:getHandle())
    end,
    decloak = function(self)
      return Decloak(self:getHandle())
    end,
    setCloaked = function(self)
      return SetCloaked(self:getHandle())
    end,
    setDecloaked = function(self)
      return SetDecloaked(self:getHandle())
    end,
    isCloaked = function(self)
      return IsCloaked(self:getHandle())
    end,
    enableCloaking = function(self, enable)
      return EnableCloaking(self:getHandle(), enable)
    end,
    getOdf = function(self)
      return GetOdf(self:getHandle())
    end,
    hide = function(self)
      return Hide(self:getHandle())
    end,
    unHide = function(self)
      return UnHide(self:getHandle())
    end,
    getCargo = function(self)
      return GetCargo(self:getHandle())
    end,
    formation = function(self, other)
      return Formation(self:getHandle(), other)
    end,
    isOdf = function(self, ...)
      return IsOdf(self:getHandle(), ...)
    end,
    getBase = function(self)
      return GetBase(self:getHandle())
    end,
    getLabel = function(self)
      return GetLabel(self:getHandle())
    end,
    setLabel = function(self, label)
      return SetLabel(self:getHandle(), label)
    end,
    getClassSig = function(self)
      return GetClassSig(self:getHandle())
    end,
    getClassLabel = function(self)
      return GetClassLabel(self:getHandle())
    end,
    getClassId = function(self)
      return GetClassId(self:getHandle())
    end,
    getNation = function(self)
      return GetNation(self:getHandle())
    end,
    isValid = function(self)
      return IsValid(self:getHandle())
    end,
    isAlive = function(self)
      return IsAlive(self:getHandle())
    end,
    isAliveAndPilot = function(self)
      return IsAliveAndPilot(self:getHandle())
    end,
    isCraf = function(self)
      return IsCraft(self:getHandle())
    end,
    isBuilding = function(self)
      return IsBuilding(self:getHandle())
    end,
    isPlayer = function(self, team)
      return self.handle == GetPlayerHandle(team)
    end,
    isPerson = function(self)
      return IsPerson(self:getHandle())
    end,
    isDamaged = function(self, threshold)
      return IsDamaged(self:getHandle(), threshold)
    end,
    getTeamNum = function(self)
      return GetTeamNum(self:getHandle())
    end,
    getTeam = function(self)
      return self:getTeamNum()
    end,
    setTeamNum = function(self, ...)
      return SetTeamNum(self:getHandle(), ...)
    end,
    setTeam = function(self, ...)
      return self:setTeamNum(...)
    end,
    getPerceivedTeam = function(self)
      return GetPerceivedTeam(self:getHandle())
    end,
    setPerceivedTeam = function(self, ...)
      return SetPerceivedTeam(self:getHandle(), ...)
    end,
    setTarget = function(self, ...)
      return SetTarget(self:getHandle(), ...)
    end,
    getTarget = function(self)
      return GetTarget(self:getHandle())
    end,
    setOwner = function(self, ...)
      return SetOwner(self:getHandle(), ...)
    end,
    getOwner = function(self)
      return GetOwner(self:getHandle())
    end,
    setPilotClass = function(self, ...)
      return SetPilotClass(self:getHandle(), ...)
    end,
    getPilotClass = function(self)
      return GetPilotClass(self:getHandle())
    end,
    setPosition = function(self, ...)
      return SetPosition(self:getHandle(), ...)
    end,
    getPosition = function(self)
      return GetPosition(self:getHandle())
    end,
    getFront = function(self)
      return GetFront(self:getHandle())
    end,
    setTransform = function(self, ...)
      return SetTransform(self:getHandle(), ...)
    end,
    getTransform = function(self)
      return GetTransform(self:getHandle())
    end,
    getVelocity = function(self)
      return GetVelocity(self:getHandle())
    end,
    setVelocity = function(self, ...)
      return SetVelocity(self:getHandle(), ...)
    end,
    getOmega = function(self)
      return GetOmega(self:getHandle())
    end,
    setOmega = function(self, ...)
      return SetOmega(self:getHandle(), ...)
    end,
    getWhoShotMe = function(self, ...)
      return GetWhoShotMe(self:getHandle(), ...)
    end,
    getLastEnemyShot = function(self)
      return GetLastEnemyShot(self:getHandle())
    end,
    getLastFriendShot = function(self)
      return GetLastFriendShot(self:getHandle())
    end,
    isAlly = function(self, ...)
      return IsAlly(self:getHandle(), ...)
    end,
    isEnemy = function(self, other)
      return not (self:isAlly(other) or (self:getTeamNum() == GetTeamNum(other)) or (GetTeamNum(other) == 0))
    end,
    setObjectiveOn = function(self)
      return SetObjectiveOn(self:getHandle())
    end,
    setObjectiveOff = function(self)
      return SetObjectiveOff(self:getHandle())
    end,
    setObjectiveName = function(self, ...)
      return SetObjectiveName(self:getHandle(), ...)
    end,
    getObjectiveName = function(self)
      return GetObjectiveName(self:getHandle())
    end,
    copyObject = function(self, odf)
      odf = odf or self:getOdf()
      return copyObject(self:getHandle(), odf)
    end,
    getDistance = function(self, ...)
      return GetDistance(self:getHandle(), ...)
    end,
    isWithin = function(self, ...)
      return IsWithin(self:getHandle(), ...)
    end,
    getNearestObject = function(self)
      return GetNearestObject(self:getHandle())
    end,
    getNearestVehicle = function(self)
      return GetNearestVehicle(self:getHandle())
    end,
    getNearestBuilding = function(self)
      return GetNearestBuilding(self:getHandle())
    end,
    getNearestEnemy = function(self)
      return GetNearestEnemy(self:getHandle())
    end,
    getNearestFriend = function(self)
      return GetNearestFriend(self:getHandle())
    end,
    countUnitsNearObject = function(self, ...)
      return CountUnitsNearObject(self:getHandle(), ...)
    end,
    isDeployed = function(self)
      return IsDeployed(self:getHandle())
    end,
    deploy = function(self)
      return Deploy(self:getHandle())
    end,
    isSelected = function(self)
      return IsSelected(self:getHandle())
    end,
    isCritical = function(self)
      return IsCritical(self:getHandle())
    end,
    setCritical = function(self, ...)
      return SetCritical(self:getHandle(), ...)
    end,
    setWeaponMask = function(self, ...)
      return SetWeaponMask(self:getHandle(), ...)
    end,
    giveWeapon = function(self, ...)
      return GiveWeapon(self:getHandle(), ...)
    end,
    getWeaponClass = function(self, ...)
      return GetWeaponClass(self:getHandle(), ...)
    end,
    fireAt = function(self, ...)
      return FireAt(self:getHandle(), ...)
    end,
    damage = function(self, ...)
      return Damage(self:getHandle(), ...)
    end,
    canCommand = function(self)
      return CanCommand(self:getHandle())
    end,
    canBuild = function(self)
      return CanBuild(self:getHandle())
    end,
    isBusy = function(self)
      return IsBusy(self:getHandle())
    end,
    getCurrentCommand = function(self)
      return GetCurrentCommand(self:getHandle())
    end,
    getCurrentWho = function(self)
      return GetCurrentWho(self:getHandle())
    end,
    getIndependence = function(self)
      return GetIndependence(self:getHandle())
    end,
    setIndependence = function(self, ...)
      return SetIndependence(self:getHandle(), ...)
    end,
    setCommand = function(self, ...)
      return SetCommand(self:getHandle(), ...)
    end,
    attack = function(self, ...)
      return Attack(self:getHandle(), ...)
    end,
    goto = function(self, ...)
      return Goto(self:getHandle(), ...)
    end,
    mine = function(self, ...)
      return Mine(self:getHandle(), ...)
    end,
    follow = function(self, ...)
      return Follow(self:getHandle(), ...)
    end,
    defend = function(self, ...)
      return Defend(self:getHandle(), ...)
    end,
    defend2 = function(self, ...)
      return Defend2(self:getHandle(), ...)
    end,
    stop = function(self, ...)
      return Stop(self:getHandle(), ...)
    end,
    patrol = function(self, ...)
      return Patrol(self:getHandle(), ...)
    end,
    retreat = function(self, ...)
      return Retreat(self:getHandle(), ...)
    end,
    getIn = function(self, ...)
      return GetIn(self:getHandle(), ...)
    end,
    pickup = function(self, ...)
      return Pickup(self:getHandle(), ...)
    end,
    dropoff = function(self, ...)
      return Dropoff(self:getHandle(), ...)
    end,
    build = function(self, ...)
      return Build(self:getHandle(), ...)
    end,
    buildAt = function(self, ...)
      return BuildAt(self:getHandle(), ...)
    end,
    hasCargo = function(self)
      return HasCargo(self:getHandle())
    end,
    getTug = function(self)
      return GetTug(self:getHandle())
    end,
    ejectPilot = function(self)
      return EjectPilot(self:getHandle())
    end,
    hopOut = function(self)
      return HopOut(self:getHandle())
    end,
    killPilot = function(self)
      return KillPilot(self:getHandle())
    end,
    removePilot = function(self)
      return RemovePilot(self:getHandle())
    end,
    hoppedOutOf = function(self)
      return HoppedOutOf(self:getHandle())
    end,
    getHealth = function(self)
      return GetHealth(self:getHandle())
    end,
    getCurHealth = function(self)
      return GetCurHealth(self:getHandle())
    end,
    getMaxHealth = function(self)
      return GetMaxHealth(self:getHandle())
    end,
    setCurHealth = function(self, ...)
      return SetCurHealth(self:getHandle(), ...)
    end,
    setMaxHealth = function(self, ...)
      return SetMaxHealth(self:getHandle(), ...)
    end,
    addHealth = function(self, ...)
      return AddHealth(self:getHandle(), ...)
    end,
    getAmmo = function(self)
      return GetAmmo(self:getHandle())
    end,
    getCurAmmo = function(self)
      return GetCurAmmo(self:getHandle())
    end,
    getMaxAmmo = function(self)
      return GetMaxAmmo(self:getHandle())
    end,
    setCurAmmo = function(self, ...)
      return SetCurAmmo(self:getHandle(), ...)
    end,
    setMaxAmmo = function(self, ...)
      return SetMaxAmmo(self:getHandle(), ...)
    end,
    addAmmo = function(self, ...)
      return AddAmmo(self:getHandle())
    end,
    _setLocal = function(self, ...)
      return SetLocal(self:getHandle(), ...)
    end,
    isLocal = function(self)
      return IsLocal(self:getHandle())
    end,
    isRemote = function(self)
      return IsRemote(self:getHandle())
    end,
    isUnique = function(self)
      return self:isLocal() and (self:isRemote())
    end,
    setHealth = function(self, fraction)
      return self:setCurHealth(self:getMaxHealth() * fraction)
    end,
    setAmmo = function(self, fraction)
      return self:setCurAmmo(self:getMaxAmmo() * fraction)
    end,
    getCommand = function(self)
      return AiCommand[self:getCurrentCommand()]
    end,
    getOdfFile = function(self)
      local file = self.odfFile
      if (not file) then
        file = OdfFile(self:getOdf())
        self.odfFile = file
      end
      return file
    end,
    getProperty = function(self, section, var, ...)
      return self:getOdfFile():getProperty(section, var, ...)
    end,
    getFloat = function(self, section, var, ...)
      return self:getOdfFile():getFloat(section, var, ...)
    end,
    getBool = function(self, section, var, ...)
      return self:getOdfFile():getBool(section, var, ...)
    end,
    getInt = function(self, section, var, ...)
      return self:getOdfFile():getInt(section, var, ...)
    end,
    getTable = function(self, ...)
      return self:getOdfFile():getTable(...)
    end,
    getVector = function(self, ...)
      return self:getOdfFile():getVector(...)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, handle)
      self.handle = handle
      self.dps = 0
      for i = 0, 4 do
        local wpc = self:getWeaponClass(i)
        if wpc ~= nil and #wpc > 0 then
          self.dps = self.dps + getWepDps(wpc)
        end
      end
    end,
    __base = _base_0,
    __name = "Handle"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Handle = _class_0
end
local ObjectTracker
do
  local _class_0
  local _base_0 = {
    update = function(self)
      for i, v in pairs(self.track) do
        local c = self.lvars[i]
        self.lvars[i] = self:handle()[v](self:handle())
        if (self.lvars[i] ~= c) then
          self.subjects[i]:onNext(self.lvars[i], c)
        end
      end
    end,
    _checkHp = function(self, new, old)
      if not self.dead and (new <= 0 and old > 0) then
        self.dead = true
        self.destroySubject:onNext()
        return self.destroySubject:onCompleted()
      end
    end,
    handle = function(self)
      return self.h
    end,
    onChange = function(self, name)
      return self.subjects[name]
    end,
    onDestroy = function(self)
      return self.destroySubject
    end,
    doTrack = function(self, name, func)
      self.track[name] = self.track[name] or func
      self.lvars[name] = self:handle()[func](self:handle())
      self.subjects[name] = self.subjects[name] or Subject.create()
      return self.subjects[name]
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, handle)
      self.h = Handle(handle)
      self.track = {
        command = "getCurrentCommand",
        who = "getCurrentWho",
        ammo = "getAmmo",
        health = "getHealth",
        position = "getPosition"
      }
      self.destroySubject = AsyncSubject.create()
      do
        local _tbl_0 = { }
        for i, v in pairs(self.track) do
          _tbl_0[i] = self:handle()[v](self:handle())
        end
        self.lvars = _tbl_0
      end
      do
        local _tbl_0 = { }
        for i, v in pairs(self.track) do
          _tbl_0[i] = Subject.create()
        end
        self.subjects = _tbl_0
      end
      self:onChange("health"):subscribe((function()
        local _base_1 = self
        local _fn_0 = _base_1._checkHp
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
      self.dead = false
    end,
    __base = _base_0,
    __name = "ObjectTracker"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  ObjectTracker = _class_0
end
return {
  Handle = Handle,
  ObjectTracker = ObjectTracker,
  copyObject = copyObject
}
 end)
package.preload['module'] = (function (...)
local utils = require("utils")
local proxyCall, protectedCall, namespace, getFullName
proxyCall, protectedCall, namespace, getFullName = utils.proxyCall, utils.protectedCall, utils.namespace, utils.getFullName
local Module
do
  local _class_0
  local _base_0 = {
    start = function(self, ...)
      return proxyCall(self.submodules, "start", ...)
    end,
    update = function(self, ...)
      return proxyCall(self.submodules, "update", ...)
    end,
    addObject = function(self, ...)
      return proxyCall(self.submodules, "addObject", ...)
    end,
    createObject = function(self, ...)
      return proxyCall(self.submodules, "createObject", ...)
    end,
    deleteObject = function(self, ...)
      return proxyCall(self.submodules, "deleteObject", ...)
    end,
    addPlayer = function(self, ...)
      return proxyCall(self.submodules, "addPlayer", ...)
    end,
    createPlayer = function(self, ...)
      return proxyCall(self.submodules, "createPlayer", ...)
    end,
    deletePlayer = function(self, ...)
      return proxyCall(self.submodules, "deletePlayer", ...)
    end,
    save = function(self, ...)
      return proxyCall(self.submodules, "save", ...)
    end,
    load = function(self, ...)
      local data = ...
      for i, v in pairs(self.submodules) do
        protectedCall(v, "load", unpack(data[i]))
      end
    end,
    gameKey = function(self, ...)
      return proxyCall(self.submodules, "gameKey", ...)
    end,
    receive = function(self, ...)
      return proxyCall(self.submodules, "receive", ...)
    end,
    command = function(self, ...)
      return proxyCall(self.submodules, "command", ...)
    end,
    useModule = function(self, cls, ...)
      local inst = cls(self, ...)
      self.submodules[getFullName(cls)] = inst
      return inst
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, parent)
      self.submodules = { }
      self.parent = parent
    end,
    __base = _base_0,
    __name = "Module"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Module = _class_0
end
namespace("core", Module)
return Module
 end)
package.preload['msetup'] = (function (...)
local fullSetup
fullSetup = function(bzutils)
  local _Start = _G["Start"]
  local _Update = _G["Update"]
  local _AddObject = _G["AddObject"]
  local _CreateObject = _G["CreateObject"]
  local _DeleteObject = _G["DeleteObject"]
  local _Receive = _G["Receive"]
  local _Save = _G["Save"]
  local _Load = _G["Load"]
  local _Command = _G["Command"]
  local _GameKey = _G["GameKey"]
  Start = function()
    bzutils:start()
    if _Start then
      return _Start()
    end
  end
  Update = function(dtime)
    bzutils:update(dtime)
    if _Update then
      return _Update(dtime)
    end
  end
  AddObject = function(handle)
    bzutils:addObject(handle)
    if _AddObject then
      return _AddObject(handle)
    end
  end
  DeleteObject = function(handle)
    bzutils:deleteObject(handle)
    if _DeleteObject then
      return _DeleteObject(handle)
    end
  end
  CreateObject = function(handle)
    bzutils:createObject(handle)
    if _CreateObject then
      return _CreateObject(handle)
    end
  end
  Receive = function(...)
    bzutils:recieve(...)
    if _Receive then
      return _Receive(...)
    end
  end
  Save = function(...)
    if _Save then
      return bzutils:save(), _Save()
    end
    return bzutils:save()
  end
  Load = function(bzutils_d, ...)
    bzutils:load(bzutils_d)
    if _Load then
      return _Load(...)
    end
  end
  Receive = function(...)
    bzutils:receive(...)
    if _Receive then
      return _Receive(...)
    end
  end
  Command = function(...)
    bzutils:command(...)
    local _h = false
    if _Command then
      _h = _Command(...)
    end
  end
  GameKey = function(...)
    bzutils:gameKey(...)
    if _GameKey then
      return _GameKey(...)
    end
  end
end
return {
  fullSetup = fullSetup
}
 end)
package.preload['service'] = (function (...)
local rx = require("rx")
local AsyncSubject, Observable
AsyncSubject, Observable = rx.AsyncSubject, rx.Observable
local ServiceManager
do
  local _class_0
  local _base_0 = {
    createService = function(self, name, service)
      if self.services[name] ~= nil then
        error("Service already registered")
      end
      self.services[name] = service
      if self.serviceRequests[name] == nil then
        self.serviceRequests[name] = AsyncSubject.create()
      end
      local req = self.serviceRequests[name]
      req:onNext(service)
      return req:onCompleted()
    end,
    hasService = function(self, name)
      return self.services[name] ~= nil
    end,
    getServiceSync = function(self, name)
      return self.services[name]
    end,
    getService = function(self, name)
      if self.serviceRequests[name] == nil then
        self.serviceRequests[name] = AsyncSubject.create()
      end
      return self.serviceRequests[name]
    end,
    getServices = function(self, ...)
      return Observable.zip(unpack((function(...)
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = {
          ...
        }
        for _index_0 = 1, #_list_0 do
          local name = _list_0[_index_0]
          _accum_0[_len_0] = self:getService(name)
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(...)))
    end,
    getServicesSync = function(self, ...)
      return unpack((function(...)
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = {
          ...
        }
        for _index_0 = 1, #_list_0 do
          local name = _list_0[_index_0]
          _accum_0[_len_0] = self:getServiceSync(name)
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(...))
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.services = { }
      self.serviceRequests = { }
    end,
    __base = _base_0,
    __name = "ServiceManager"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  ServiceManager = _class_0
end
return {
  ServiceManager = ServiceManager
}
 end)
package.preload['terrain'] = (function (...)
local utils = require("utils")
local OdfFile
OdfFile = utils.OdfFile
local HEIGHT_TOLERANCE = 5
local NORMAL_TOLERANCE = 0.1
local Terrain
do
  local _class_0
  local _base_0 = {
    getSize = function(self)
      return self.maxVec - self.minVec
    end,
    getBoundary = function(self)
      return self.minVec, self.maxVec
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, filename)
      self.file = OdfFile(filename)
      self.minVec = SetVector(self.file:getInt("Size", "MinX"), self.file:getInt("Size", "Height"), self.file:getInt("Size", "MinZ"))
      self.maxVec = self.minVec + SetVector(self.file:getInt("Size", "Width"), 0, self.file:getInt("Size", "Depth"))
    end,
    __base = _base_0,
    __name = "Terrain"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Terrain = _class_0
end
return {
  Terrain = Terrain
}
 end)
package.preload['utils'] = (function (...)
local Rx = require("rx")
local Subject, ReplaySubject, AsyncSubject
Subject, ReplaySubject, AsyncSubject = Rx.Subject, Rx.ReplaySubject, Rx.AsyncSubject
local metadata = setmetatable({ }, {
  __mode = "k"
})
local namespaceData = setmetatable({ }, {
  __mode = "v"
})
local _unpack = unpack
local _GetOdf = GetOdf
local _GetPilotClass = GetPilotClass
local _GetWeaponClass = GetWeaponClass
local _OpenODF = OpenODF
local _BuildObject = BuildObject
local _odf_cache = setmetatable({ }, {
  __mode = "v"
})
OpenODF = function(odf)
  _odf_cache[odf] = _odf_cache[odf] ~= nil and _odf_cache[odf] or _OpenODF(odf)
  return _odf_cache[odf]
end
if IsNetGame() then
  BuildObject = function(...)
    local h = _BuildObject(...)
    SetLocal(h)
    return h
  end
end
BuildLocal = function(...)
  return _BuildObject(...)
end
GetOdf = function(...)
  return (_GetOdf(...) or ""):gmatch("[^%c]*")()
end
GetPilotClass = function(...)
  return (_GetPilotClass(...) or ""):gmatch("[^%c]*")()
end
GetWeaponClass = function(...)
  return (_GetWeaponClass(...) or ""):gmatch("[^%c]*")()
end
SetLabel = SetLabel or SettLabel
IsFriend = function(a, b)
  return IsTeamAllied(a, b) or a == b or a == 0 or b == 0
end
IsBzr = function()
  return GameVersion:match("^2") ~= nil
end
IsBz15 = function()
  return GameVersion:match("^1.5") ~= nil
end
IsBz2 = function()
  return not (IsBzr or IsBz15)
end
local simulatedTime = 0
GetSimTime = function()
  return simulatedTime
end
SimulateTime = function(dtime)
  simulatedTime = simulatedTime + dtime
end
Hide = Hide or function() end
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
  for i = 0, GetPathPointCount(path) - 1 do
    _accum_0[_len_0] = GetPosition(path, i)
    _len_0 = _len_0 + 1
  end
  return _accum_0
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
GetCenterOfPath = function(path)
  return GetCenterOfPolygon(GetPathPoints(path))
end
table.pack = function(...)
  local l = select("#", ...)
  return setmetatable({
    __n = l,
    ...
  }, {
    __len = function()
      return l
    end
  })
end
table.reverse = function(tbl)
  local ret = { }
  for i = #tbl, 1, -1 do
    table.insert(ret, tbl[i])
  end
  return ret
end
unpack = function(t, ...)
  if (t.__n ~= nil) then
    local numArgs = select('#', ...)
    if numArgs == 0 then
      return _unpack(t, 1, t.__n)
    elseif numArgs == 1 then
      return _unpack(t, ({
        ...
      })[1], t.__n)
    end
  end
  return _unpack(t, ...)
end
local simpleIdGeneratorFactory
simpleIdGeneratorFactory = function(_id)
  if _id == nil then
    _id = 0
  end
  return function()
    _id = _id + 1
    return _id
  end
end
local userdataType
userdataType = function(userdata)
  local meta = getmetatable(userdata)
  return meta.__type
end
local sizeTable = {
  Handle = function(handle)
    return IsValid(handle) and 5 or 1
  end,
  ["nil"] = function()
    return 1
  end,
  boolean = function()
    return 1
  end,
  number = function(num)
    if num == 0 then
      return 1
    end
    if num / math.ceil(num) ~= 1 then
      return 9
    end
    if num >= -128 and num <= 127 then
      return 2
    end
    if num >= -32768 and num <= 32767 then
      return 3
    end
    return 5
  end,
  string = function(string)
    local len = string:len()
    if len >= 31 then
      return 2 + len
    end
    return 1 + len
  end,
  table = function(tbl)
    local count = 0
    for i, v in pairs(tbl) do
      count = count + 1
    end
    if count >= 31 then
      return 2 + 31
    end
    return 1 + 31
  end,
  VECTOR_3D = function(vec)
    return 13
  end,
  MAT_3D = function(mat)
    return 12
  end,
  userdata = function(data)
    return 13
  end
}
local sizeof
sizeof = function(a)
  local t = type(a)
  if t == "userdata" then
    t = userdataType(a)
  end
  local size = sizeTable[t](a)
  if t == "table" then
    for key, value in pairs(a) do
      size = size + sizeof(key) + sizeof(value)
    end
  end
  return size
end
local isIn
isIn = function(element, list)
  for _index_0 = 1, #list do
    local e = list[_index_0]
    if e == element then
      return true
    end
  end
  return false
end
local assignObject
assignObject = function(...)
  local _tbl_0 = { }
  local _list_0 = {
    ...
  }
  for _index_0 = 1, #_list_0 do
    local obj = _list_0[_index_0]
    for k, v in pairs(obj) do
      _tbl_0[k] = v
    end
  end
  return _tbl_0
end
local copyList
copyList = function(t, filter)
  if filter == nil then
    filter = function()
      return true
    end
  end
  local _accum_0 = { }
  local _len_0 = 1
  for i, v in ipairs(t) do
    if filter(i, v) then
      _accum_0[_len_0] = v
      _len_0 = _len_0 + 1
    end
  end
  return _accum_0
end
local ommit
ommit = function(table, fields)
  local _tbl_0 = { }
  for k, v in pairs(table) do
    if not isIn(k, fields) then
      _tbl_0[k] = v
    end
  end
  return _tbl_0
end
local compareTables
compareTables = function(a, b)
  local _tbl_0 = { }
  for k, v in pairs(assignObject(a, b)) do
    if a[k] ~= b[k] then
      _tbl_0[k] = v
    end
  end
  return _tbl_0
end
local isNullPos
isNullPos = function(pos)
  return pos.x == pos.y and pos.y == pos.z and pos.z == 0
end
local getMeta
getMeta = function(obj, key)
  if key then
    local _tbl_0 = { }
    for k, v in pairs((metadata[obj] or { })[key] or { }) do
      _tbl_0[k] = v
    end
    return _tbl_0
  end
  local _tbl_0 = { }
  for k, v in pairs(metadata[obj] or { }) do
    _tbl_0[k] = v
  end
  return _tbl_0
end
local dropMeta
dropMeta = function(obj, key)
  if key and metadata[obj] then
    metadata[obj][key] = nil
  else
    metadata[obj] = nil
  end
end
local applyMeta
applyMeta = function(obj, ...)
  metadata[obj] = assignObject(getMeta(obj), ...)
end
local setMeta
setMeta = function(obj, key, value)
  local m = getMeta(obj)
  m[key] = value
  return applyMeta(obj, m)
end
local getFullName
getFullName = function(cls)
  if cls.__name then
    return tostring(getMeta(cls).namespace or '') .. "." .. tostring(cls.__name)
  end
end
local namespace
namespace = function(name, ...)
  for i, v in pairs({
    ...
  }) do
    applyMeta(v, {
      namespace = name
    })
    local _name = getFullName(v)
    if name then
      namespaceData[_name] = v
    end
  end
  return ...
end
local getClass
getClass = function(name)
  return namespaceData[name]
end
local instanceof
instanceof = function(inst, cls)
  local current = cls
  while current do
    if (inst.__class == current) then
      return true
    end
    current = current.__parent
  end
  return false
end
local protectedCall
protectedCall = function(obj, method, ...)
  if (obj[method]) then
    return obj[method](obj, ...)
  end
end
local proxyCall
proxyCall = function(objs, method, ...)
  local _tbl_0 = { }
  for i, v in pairs(objs) do
    _tbl_0[i] = table.pack(protectedCall(v, method, ...))
  end
  return _tbl_0
end
local stringlist
stringlist = function(str)
  local m = str:match("%s*([%.%w]+)%s*,?")
  return unpack((function()
    local _accum_0 = { }
    local _len_0 = 1
    for v in m do
      _accum_0[_len_0] = v
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)())
end
local str2vec
str2vec = function(str)
  local m = str:gmatch("%s*(%-?%d*%.?%d*)%a*%s*,?")
  local x, y, z = m(), m(), m()
  return SetVector(tonumber(x), tonumber(y), tonumber(z))
end
local getHash
getHash = function(any)
  return tonumber({
    tostring(any):gsub("%a+: ", "")
  }, 16)
end
local Store
do
  local _class_0
  local _base_0 = {
    set = function(self, key, value)
      return self:assign({
        [key] = value
      })
    end,
    delete = function(self, ...)
      local p_state = self.state
      self.state = assignObject({ }, self.state)
      for i, v in ipairs({
        ...
      }) do
        self.state[v] = nil
        self.keyUpdateSubject:onNext(v, nil)
      end
      return self.updateSubject:onNext(self.state, p_state)
    end,
    assign = function(self, kv_pairs)
      local p_state = self.state
      self.state = assignObject(self.state, kv_pairs)
      for k, v in pairs(compareTables(p_state, self.state)) do
        self.keyUpdateSubject:onNext(k, v)
      end
      return self.updateSubject:onNext(self.state, p_state)
    end,
    silentSet = function(self, key, value)
      return self:silentAssign({
        [key] = value
      })
    end,
    silentAssign = function(self, kv_pairs)
      local p_state = self.state
      self.state = assignObject(self.state, kv_pairs)
    end,
    silentDelete = function(self, ...)
      self.state = assignObject({ }, self.state)
      for i, v in ipairs({
        ...
      }) do
        self.state[v] = nil
      end
    end,
    getState = function(self)
      return self.state
    end,
    onStateUpdate = function(self)
      return self.updateSubject
    end,
    onKeyUpdate = function(self)
      return self.keyUpdateSubject
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, initial_state)
      self.state = initial_state or { }
      self.updateSubject = Subject.create()
      self.keyUpdateSubject = Subject.create()
    end,
    __base = _base_0,
    __name = "Store"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Store = _class_0
end
local OdfHeader
do
  local _class_0
  local _base_0 = {
    getProperty = function(self, ...)
      return GetODFString(self.file, self.header, ...)
    end,
    getInt = function(self, ...)
      return GetODFInt(self.file, self.header, ...)
    end,
    getBool = function(self, ...)
      return GetODFBool(self.file, self.header, ...)
    end,
    getFloat = function(self, ...)
      return GetODFFloat(self.file, self.header, ...)
    end,
    getVector = function(self, ...)
      return str2vec(self:getProperty(...) or "")
    end,
    getValueAs = function(self, parser, ...)
      return parser(self:getProperty(...) or "")
    end,
    getTable = function(self, var, ...)
      local c = 1
      local ret = { }
      local max = self:getInt(tostring(var) .. "Count", 100)
      local n = self:getProperty(tostring(var) .. tostring(c), ...)
      while n and c < max do
        table.insert(ret, n)
        c = c + 1
        n = self:getProperty(tostring(var) .. tostring(c), ...)
      end
      return ret
    end,
    getTableOf = function(self, parser, var, ...)
      local t = self:getTable(var, ...)
      local _accum_0 = { }
      local _len_0 = 1
      for i, v in ipairs(t) do
        _accum_0[_len_0] = parser(v)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end,
    getFields = function(self, fields, tbl)
      for field, t in pairs(fields) do
        local v = nil
        if t == "bool" then
          v = self:getBool(field, false)
        elseif t == "string" then
          v = self:getProperty(field)
        elseif t == "float" then
          v = self:getFloat(field, 0)
        elseif t == "int" then
          v = self:getInt(field, 0)
        elseif t == "vector" then
          v = self:getVector(field)
        elseif t == "table" then
          v = self:getTable(field)
        elseif type(t) == "function" then
          v = self:getValueAs(t, field)
        else
          v = self:getProperty(field)
        end
        tbl[field] = v
      end
      return tbl
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, file, name)
      self.file = file
      self.header = name
    end,
    __base = _base_0,
    __name = "OdfHeader"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  OdfHeader = _class_0
end
local OdfFile
do
  local _class_0
  local _base_0 = {
    getHeader = function(self, name)
      self.headers[name] = self.headers[name] or OdfHeader(self.file, name)
      return self.headers[name]
    end,
    getInt = function(self, header, ...)
      return self:getHeader(header):getInt(...)
    end,
    getFloat = function(self, header, ...)
      return self:getHeader(header):getFloat(...)
    end,
    getProperty = function(self, header, ...)
      return self:getHeader(header):getProperty(...)
    end,
    getBool = function(self, header, ...)
      return self:getHeader(header):getBool(...)
    end,
    getTable = function(self, header, ...)
      return self:getHeader(header):getTable(...)
    end,
    getVector = function(self, header, ...)
      return self:getHeader(header):getVector(...)
    end,
    getValueAs = function(self, parser, header, ...)
      return self:getHeader(header):getValueAs(parser, ...)
    end,
    getTableOf = function(self, parser, header, ...)
      return self:getHeader(header):getTableOf(parser, ...)
    end,
    getFields = function(self, header, fields, tbl)
      if tbl == nil then
        tbl = { }
      end
      return self:getHeader(header):getFields(fields, tbl)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, filename)
      self.name = filename
      self.file = OpenODF(filename)
      self.headers = { }
    end,
    __base = _base_0,
    __name = "OdfFile"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  OdfFile = _class_0
end
local CBuildObject
do
  local _class_0
  local _base_0 = {
    getClassLabel = function(self)
      return self.classLabel
    end,
    getCost = function(self)
      return self.cost
    end,
    getOdf = function(self)
      return self.odf
    end,
    getAmmo = function(self)
      return self.ammo
    end,
    getHealth = function(self)
      return self.health
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, odf)
      local file = OdfFile(odf)
      self.cost = file:getInt("GameObjectClass", "scrapCost")
      self.classLabel = file:getInt("GameObjectClass", "classLabel")
      self.odf = odf
      self.health = file:getInt("GameObjectClass", "maxHealth")
      self.ammo = file:getInt("GameObjectClass", "maxAmmo")
    end,
    __base = _base_0,
    __name = "CBuildObject"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  CBuildObject = _class_0
end
local BuildTree
do
  local _class_0
  local _base_0 = {
    _addOdf = function(self, odf)
      local boject = CBuildObject(odf)
      self.allOdfs[odf] = bobject
      local classLabel = boject:getClassLabel()
      if not self.odfByClass[classLabel] then
        self.odfByClass[classLabel] = { }
      end
      return table.insert(self.odfByClass[classLabel], bobject)
    end,
    _buildTree = function(self, file)
      local list = {
        default = { }
      }
      local isEmpty = true
      for i = 1, 20 do
        list.default[i] = file:getString("ProducerClass", ("buildItem%d"):format(i))
        isEmpty = isEmpty and list.default[i] == nil
        if list.default[i] ~= nil then
          self:_addOdf(list.default[i])
        end
      end
      if file:getString("GameObjectClass", "classLabel") == "armory" then
        local extraList = {
          "cannon",
          "rocket",
          "mortar",
          "special"
        }
        for _, l in ipairs(extraList) do
          list[l] = { }
          for i = 1, 20 do
            list[l][i] = file:getString("ArmoryClass", ("%sItem%d"):format(l, i))
            isEmpty = isEmpty and list[l][i] == nil
          end
        end
      end
      return list, isEmpty
    end,
    _buildRecursiveTree = function(self, file)
      local ret = { }
      local bTree, empty = self:_buildTree(file)
      if not empty then
        for i, v in pairs(bTree.default) do
          self.subtrees[v] = BuildTree(v)
        end
      end
      return ret, empty
    end,
    getOdfs = function(self, classname)
      return self.odfByClass[classname] or { }
    end,
    getOdfsRecursive = function(self, classname)
      local odfs = self:getOdfs(classname)
      for i, v in pairs(self.subtrees) do
        for _, odf in pairs(v:getOdfsRecursive(classname)) do
          table.insert(odfs, odf)
        end
      end
      return odfs
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, odf)
      self.allOdfs = { }
      self.odfByClass = { }
      self.subtrees = { }
      return self:_buildRecursiveTree(OdfFile(odf))
    end,
    __base = _base_0,
    __name = "BuildTree"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  BuildTree = _class_0
end
local normalWeapons = {
  "cannon",
  "machinegun",
  "thermallauncher",
  "imagelauncher",
  "snipergun"
}
local dispenserWeps = {
  radarlauncher = {
    "RadarLauncherClass",
    "objectClass"
  },
  dispenser = {
    "DispenserClass",
    "objectClass"
  }
}
local getWepOrdnance
getWepOrdnance = function(odf)
  local ofile = OdfFile(odf)
  local classLabel = ofile:getProperty("WeaponClass", "classLabel")
  if (isIn(classLabel, normalWeapons)) or classLabel == "beamgun" then
    local ord = ofile:getProperty("WeaponClass", "ordName")
    return ord
  end
end
local getWepAmmoCost
getWepAmmoCost = function(odf)
  local ord = getWepOrdnance(odf)
  if ord then
    local ordFile = OdfFile(ord)
    return ordFile:getInt("OrdnanceClass", "ammoCost")
  end
  return 0
end
local getWepDamage
getWepDamage = function(odf)
  local ord = getWepOrdnance(odf)
  if ord then
    local ordFile = OdfFile(ord)
    return ordFile:getInt("OrdnanceClass", "damageBallistic") + ordFile:getInt("OrdnanceClass", "damageConcussion") + ordFile:getInt("OrdnanceClass", "damageFlame") + ordFile:getInt("OrdnanceClass", "damageImpact")
  end
  return 0
end
local getWepDelay
getWepDelay = function(odf)
  local f = OdfFile(odf)
  local wepc = f:getProperty("WeaponClass", "classLabel")
  if isIn(wepc, normalWeapons) then
    local d1 = f:getFloat("LauncherClass", "shotDelay", 0)
    return d1 > 0 and d1 or f:getFloat("CannonClass", "shotDelay", 0)
  elseif wepc == "beamgun" then
    return 1
  end
  return 0
end
local dps_cache = { }
local getWepDps
getWepDps = function(odf)
  if dps_cache[odf] then
    return dps_cache[odf]
  end
  local damage = getWepDamage(odf)
  local delay = getWepDelay(odf)
  local dps = 0
  if delay > 0 then
    dps = damage / delay
  end
  dps_cache[odf] = dps
  return dps
end
local spawnInFormation
spawnInFormation = function(formation, location, direction, unitlist, team, seperation)
  if seperation == nil then
    seperation = 10
  end
  local ret = { }
  local formationAlign = Normalize(SetVector(-direction.z, 0, direction.x))
  local directionVec = Normalize(SetVector(direction.x, 0, direction.z))
  for i, v in ipairs(formation) do
    local length = v:len()
    local i2 = 1
    for c in v:gmatch(".") do
      local n = tonumber(c)
      if n then
        local x = (i2 - length / 2) * seperation
        local z = i * seperation * 2
        local position = x * formationAlign - z * directionVec + location
        local transform = BuildDirectionalMatrix(position, directionVec)
        table.insert(ret, BuildObject(unitlist[n], team, transform))
      end
    end
  end
  return ret
end
local spawnInFormation2
spawnInFormation2 = function(formation, location, ...)
  return spawnInFormation(formation, GetPosition(location, 0), GetPosition(location, 1) - GetPosition(location, 0), ...)
end
local createClass
createClass = function(name, methods, parent)
  local _class = nil
  local _base = ommit(methods, {
    "new",
    "super"
  }) or { }
  _base.__index = _base
  if parent then
    setmetatable(_base, parent.__base)
  end
  _class = {
    __init = function(self, ...)
      if methods.new then
        return methods.new(self, ...)
      elseif _class.__parent then
        return _class.__parent.__init(self, ...)
      end
    end,
    __base = _base,
    __name = name,
    __parent = parent,
    __inherited = methods.__inherited
  }
  _base.super = function(self, name, ...)
    return _class.__parent[name](self, ...)
  end
  _class = setmetatable(_class, {
    __index = function(self, name)
      local val = rawget(_base, name)
      if val == nil then
        local _parent = rawget(self, "__parent")
        if _parent then
          return _parent[name]
        end
      else
        return val
      end
    end,
    __call = function(self, ...)
      local _self = setmetatable({ }, _base)
      self.__init(_self, ...)
      return _self
    end
  })
  _base.__class = _class
  if parent and parent.__inherited then
    parent.__inherited(parent, _class)
  end
  return _class
end
local _switchMap
_switchMap = function(obs, func)
  return Observable.create(function(observer)
    return obs:subscribe(function(...)
      local n = func(...)
      return n:subscribe(function(...)
        return observer:onNext(...)
      end)
    end)
  end)
end
return {
  proxyCall = proxyCall,
  protectedCall = protectedCall,
  str2vec = str2vec,
  stringlist = stringlist,
  getHash = getHash,
  assignObject = assignObject,
  isIn = isIn,
  getMeta = getMeta,
  applyMeta = applyMeta,
  OdfFile = OdfFile,
  spawnInFormation = spawnInFormation,
  spawnInFormation2 = spawnInFormation2,
  namespace = namespace,
  getClass = getClass,
  getFullName = getFullName,
  dropMeta = dropMeta,
  createClass = createClass,
  superCall = superCall,
  superClass = superClass,
  instanceof = instanceof,
  isNullPos = isNullPos,
  Store = Store,
  getWepDps = getWepDps,
  compareTables = compareTables,
  copyList = copyList,
  setMeta = setMeta,
  userdataType = userdataType,
  sizeof = sizeof,
  sizeTable = sizeTable,
  simpleIdGeneratorFactory = simpleIdGeneratorFactory,
  CBuildObject = CBuildObject,
  BuildTree = BuildTree
}
 end)
package.preload['lvdf'] = (function (...)
local json = require("json")
local default_file = "bundle.pvdf"
local VdfPart
do
  local _class_0
  local _base_0 = {
    setParent = function(self, parent)
      self.parent = parent
    end,
    getName = function(self)
      return self.name
    end,
    getPosition = function(self)
      return self.pos
    end,
    getRelativePos = function(self)
      return self.relpos
    end,
    getParent = function(self)
      return self.parent
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, name, pos, relpos)
      self.name = name
      self.pos = pos
      self.relpos = relpos
    end,
    __base = _base_0,
    __name = "VdfPart"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  VdfPart = _class_0
end
local VehicleDefinition
do
  local _class_0
  local _base_0 = {
    getName = function(self)
      return self.name
    end,
    addPart = function(self, shortname, part)
      self.parts[shortname] = part
    end,
    hasPart = function(self, name)
      return self.parts[name] ~= nil
    end,
    getPart = function(self, name)
      if self:hasPart(name) then
        return self.parts[name]
      end
    end,
    getPartList = function(self)
      return self.parts
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, name)
      self.name = name
      self.parts = { }
    end,
    __base = _base_0,
    __name = "VehicleDefinition"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  VehicleDefinition = _class_0
end
local bundleCache = { }
local loadBundle
loadBundle = function(file)
  if file == nil then
    file = default_file
  end
  if bundleCache[file] then
    return bundleCache[file]
  end
  local bundle = { }
  local vdfs = json.decode(UseItem(file))
  for vdfName, struct in pairs(vdfs) do
    local vdf = VehicleDefinition(vdfName)
    for shortname, p in pairs(struct) do
      local part = VdfPart(p["fullname"], SetVector(unpack(p["pos"])), SetVector(unpack(p["relpos"])))
      part:setParent(p["parent"])
      vdf:addPart(shortname, part)
    end
    for shortname, part in pairs(vdf:getPartList()) do
      local parent = vdf:getPart(part:getParent())
      part:setParent(parent)
    end
    bundle[vdfName] = vdf
  end
  bundleCache[file] = bundle
  return bundle
end
return {
  VdfPart = VdfPart,
  VehicleDefinition = VehicleDefinition,
  loadBundle = loadBundle
}
 end)
package.preload['os'] = (function (...)
return {
  time = GetTimeNow
}
 end)
package.preload['dloader'] = (function (...)
local Observable, AsyncSubject
do
  local _obj_0 = require("rx")
  Observable, AsyncSubject = _obj_0.Observable, _obj_0.AsyncSubject
end
local initSuccess = false
local protectedRequire
protectedRequire = function(mod)
  local status, val = pcall(require, mod)
  if not status then
    return false
  end
  return val
end
local asyncRequires = { }
local initLoader
initLoader = function(mod_id, dll, dev_id)
  if mod_id == nil then
    mod_id = 0
  end
  if dll == nil then
    dll = false
  end
  if dev_id == nil then
    dev_id = nil
  end
  if initSuccess then
    return true
  end
  package.cpath = package.cpath .. (";.\\..\\..\\workshop\\content\\301650\\%s\\?.dll;.\\mods\\%s\\?.dll"):format(mod_id, mod_id)
  if dll then
    package.cpath = package.cpath .. ";./dll/?.dll"
    package.cpath = package.cpath .. ";./testdll/?.dll"
  end
  if dev_id then
    package.cpath = package.cpath .. ";./addon/" .. tostring(dev_id) .. "/?.dll"
  end
  local bzpre = protectedRequire("bzpre")
  if bzpre then
    local dllp1 = bzpre.fullpath(".\\..\\..\\workshop\\content\\301650\\" .. tostring(mod_id))
    local dllp2 = bzpre.fullpath(".\\mods\\" .. tostring(mod_id))
    package.cpath = package.cpath .. ";" .. tostring(dllp1) .. "\\?.dll;" .. tostring(dllp2) .. "\\?.dll"
    if dev_id then
      local dllp3 = bzpre.fullpath(".\\addon\\" .. tostring(dev_id))
      package.cpath = package.cpath .. ";" .. tostring(dllp3) .. "\\?.dll"
      bzpre.addPath(dllp3)
    end
    bzpre.addPath(dllp1)
    bzpre.addPath(dllp2)
    if dll then
      bzpre.addPath("./dll")
      bzpre.addPath("./testdll")
    end
    initSuccess = true
    for i, v in pairs(asyncRequires) do
      v:onNext(require(i))
      v:onCompleted()
    end
    asyncRequires = { }
    return true
  end
  return false
end
local requireDll
requireDll = function(name)
  if initSuccess then
    return Observable.of(require(name))
  end
  if not asyncRequires[name] then
    asyncRequires[name] = AsyncSubject.create()
  end
  return asyncRequires[name]
end
local requireDlls
requireDlls = function(...)
  return Observable.zip(unpack((function(...)
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local name = _list_0[_index_0]
      _accum_0[_len_0] = requireDll(name)
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(...)))
end
return {
  initLoader = initLoader,
  requireDll = requireDll,
  requireDlls = requireDlls
}
 end)
package.preload['bzext'] = (function (...)
local requireDlls
requireDlls = require("dloader").requireDlls
local isIn
isIn = require("utils").isIn
local bzpre = nil
requireDlls("bzpre"):subscribe(function(a)
  bzpre = a
end)
local producers = {
  "recycler",
  "factory",
  "armory",
  "constructionrig"
}
local IsProducer
IsProducer = function(h)
  return (IsCraft(h) and isIn(GetClassLabel(h), producers))
end
local HCheck
HCheck = function(check)
  return function(f)
    return function(h, ...)
      if (check(h)) then
        return f(h, ...)
      end
    end
  end
end
local ValidCheck = HCheck(IsValid)
local CraftCheck = HCheck(IsCraft)
local ProducerCheck = HCheck(IsProducer)
local _appinfo = nil
local craftStates = {
  [0] = "UNDEPLOYED",
  [1] = "DEPLOYING",
  [2] = "DEPLOYED",
  [3] = "UNDEPLOYING",
  DEPLOYED = 2,
  DEPLOYING = 1,
  UNDEPLOYED = 0,
  UNDEPLOYING = 3
}
local getAppInfo
getAppInfo = function(id)
  if id == nil then
    id = "301650"
  end
  if not _appinfo then
    _appinfo = bzpre.getAppInfo(id)
  end
  return _appinfo
end
local getUserId
getUserId = function(id)
  return getAppInfo(id):gmatch('"LastOwner"%s*"(%d+)"')()
end
local setBuildDoneTime = ValidCheck(ProducerCheck(function(...)
  return bzpre.setBuildDoneTime(...)
end))
local getBuildDoneTime = ValidCheck(ProducerCheck(function(...)
  return bzpre.getBuildDoneTime(...)
end))
local setBuildProgress = ValidCheck(ProducerCheck(function(...)
  return bzpre.setBuildProgress(...)
end))
local getBuildProgress = ValidCheck(ProducerCheck(function(...)
  return bzpre.getBuildProgress(...)
end))
local getBuildTime = ValidCheck(ProducerCheck(function(...)
  return bzpre.getBuildTime(...)
end))
local getBuildOdf = ValidCheck(ProducerCheck(function(...)
  return bzpre.getBuildOdf(...)
end))
local findPlan
findPlan = function(...)
  return bzpre.findPlan(...)
end
local getCurrentParam = ValidCheck(CraftCheck(function(...)
  return bzpre.getCurrentParam(...)
end))
local getCurrentWhere = ValidCheck(CraftCheck(function(...)
  local ptr, x, z = bzpre.getCurrentWhere(...)
  print(ptr, x, z)
  local vec = SetVector(x, 0, z)
  local y = GetTerrainHeightAndNormal(vec)
  vec.y = y
  return vec
end))
local getCraftState = ValidCheck(CraftCheck(function(...)
  return bzpre.getCraftState(...)
end))
local setCraftState = ValidCheck(CraftCheck(function(...)
  return bzpre.setCraftState(...)
end))
local setAsUser = ValidCheck(CraftCheck(function(...)
  return bzpre.setAsUser(...)
end))
local getPitchAngle = ValidCheck(CraftCheck(function(...)
  return bzpre.getPitchAngle(...)
end))
local getScorePlayer
getScorePlayer = function(...)
  return bzpre.getScorePlayer(...)
end
local writeString
writeString = function(...)
  return bzpre.writeString(...)
end
local readString
readString = function(...)
  return bzpre.readString(...)
end
return {
  readString = readString,
  writeString = writeString,
  getUserId = getUserId,
  getAppInfo = getAppInfo,
  setAsUser = setAsUser,
  getPitchAngle = getPitchAngle,
  getBuildDoneTime = getBuildDoneTime,
  setBuildDoneTime = setBuildDoneTime,
  getCurrentParam = getCurrentParam,
  getCurrentWhere = getCurrentWhere,
  setBuildProgress = setBuildProgress,
  getBuildProgress = getBuildProgress,
  getBuildOdf = getBuildOdf,
  getBuildTime = getBuildTime,
  getCraftState = getCraftState,
  setCraftState = setCraftState,
  craftStates = craftStates,
  getScorePlayer = getScorePlayer,
  findPlan = findPlan
}
 end)
package.preload['bztt'] = (function (...)
local rx = require("rx")
local utils = require("utils")
local json = require("json")
local Subject, AsyncSubject
Subject, AsyncSubject = rx.Subject, rx.AsyncSubject
local simpleIdGeneratorFactory
simpleIdGeneratorFactory = utils.simpleIdGeneratorFactory
local requireDlls = require("dloader").requireDlls
local socket = nil
requireDlls("socket"):subscribe(function(sock)
  socket = sock
end)
local T_CONNECT = 1
local T_CONNECT_ACK = 2
local T_DISCONNECT = 3
local T_DISCONNECT_ACK = 4
local T_SUBSCRIBE = 5
local T_SUBSCRIBE_ACK = 6
local T_UNSUBSCRIBE = 7
local T_UNSUBSCRIBE_ACK = 8
local T_PUBLISH = 9
local T_PUBLISH_ACK = 10
local T_PUSH = 11
local WriteBuffer
do
  local _class_0
  local _base_0 = {
    putNumber = function(self, number, bytes)
      if bytes == nil then
        bytes = math.ceil(math.max(math.log(number) / math.log(255), 1))
      end
      local ibuff = { }
      for i = 1, bytes do
        local part = bit.band(bit.rshift(number, (bytes - i) * 8), 0xFF)
        table.insert(ibuff, string.char(part))
      end
      return table.insert(self.buffer, table.concat(ibuff))
    end,
    putString = function(self, str)
      self:putNumber(str:len(), 4)
      return table.insert(self.buffer, str)
    end,
    putFloat = function(self, number)
      return self:putString(tostring(number))
    end,
    putBuffer = function(self, buf)
      return self:putString(buf:bytes())
    end,
    putStringArray = function(self, arr)
      local len = 0
      local size = 8
      for i, v in ipairs(arr) do
        size = size + (v:len() + 4)
        len = len + 1
      end
      self:putNumber(size, 4)
      self:putNumber(len, 4)
      for i, v in ipairs(arr) do
        self:putString(v)
      end
    end,
    putNumberArray = function(self, arr, bytes)
      local len = #arr
      local size = 8 + arr * bytes
      self:putNumber(size, 4)
      self:putNumber(len, 4)
      for i, v in ipairs(arr) do
        self:putNumber(v, bytes)
      end
    end,
    bytes = function(self)
      return table.concat(self.buffer, "")
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, buffer)
      if buffer == nil then
        buffer = { }
      end
      self.buffer = buffer
    end,
    __base = _base_0,
    __name = "WriteBuffer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  WriteBuffer = _class_0
end
local ReadBuffer
do
  local _class_0
  local _base_0 = {
    available = function(self)
      return self.buffer:len() - (self.cursor - 1)
    end,
    canRead = function(self, len)
      return self:available() >= len
    end,
    backtrack = function(self, len)
      self.cursor = self.cursor - len
    end,
    append = function(self, buffer)
      self.buffer = self.buffer .. buffer
    end,
    readByte = function(self)
      local byte = string.byte(self.buffer, self.cursor)
      self.cursor = self.cursor + 1
      return byte
    end,
    readChar = function(self)
      local char = string.sub(self.buffer, self.cursor, self.cursor)
      self.cursor = self.cursor + 1
      return char
    end,
    readChars = function(self, len)
      if len == nil then
        len = 1
      end
      local chars = string.sub(self.buffer, self.cursor, self.cursor + len - 1)
      self.cursor = self.cursor + len
      return chars
    end,
    readNumber = function(self, bytes)
      local ret = 0
      for i = 1, bytes do
        local b = self:readByte()
        ret = ret + bit.lshift(b, (bytes - i) * 8)
      end
      return ret
    end,
    readString = function(self)
      local len = self:readNumber(4)
      return self:readChars(len)
    end,
    canReadString = function(self)
      local len = self:readNumber(4)
      self:backtrack(4)
      return self:canRead(len)
    end,
    canReadFloat = function(self)
      return self:canReadString()
    end,
    readFloat = function(self)
      return tonumber(self:readString())
    end,
    readBuffer = function(self)
      local data = self:readString()
      return ReadBuffer(data)
    end,
    slice = function(self)
      return ReadBuffer(self:readChars(self:available()))
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, buffer)
      if buffer == nil then
        buffer = ""
      end
      self.buffer = buffer
      self.cursor = 1
    end,
    __base = _base_0,
    __name = "ReadBuffer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  ReadBuffer = _class_0
end
local TcpSocket
do
  local _class_0
  local _base_0 = {
    settimeout = function(self, v)
      self.sock:settimeout(v)
      self.timeoutValue = v
    end,
    gettimeout = function(self)
      return self.timeoutValue
    end,
    getstats = function(self)
      return self.sock:getstats()
    end,
    getsockname = function(self)
      return self.sock:getsockname()
    end,
    getpeername = function(self)
      return self.sock:getpeername()
    end,
    connect = function(self, ...)
      return self.sock:connect(...)
    end,
    bind = function(self, ...)
      return self.sock:bind(...)
    end,
    listen = function(self, ...)
      return self.sock:listen(...)
    end,
    send = function(self, ...)
      return self.sock:send(...)
    end,
    accept = function(self)
      self.mode = "ACCEPT"
      return self.socketSubject
    end,
    receive = function(self)
      self.mode = "RECEIVE"
      return self.socketSubject
    end,
    close = function(self)
      self.closed = true
      return self.socketSubject:onCompleted()
    end,
    isClosed = function(self)
      return self.closed
    end,
    _update = function(self)
      if self.closed then
        return 
      end
      if self.mode == "ACCEPT" then
        local err
        socket, err = self.sock:accept()
        if socket then
          return self.socketSubject:onNext(TcpSocket(socket))
        end
      elseif self.mode == "RECEIVE" then
        local data, err, partial = self.sock:receive(2048)
        if data then
          self.socketSubject:onNext(data)
        end
        if err == "timeout" and partial:len() > 0 then
          self.socketSubject:onNext(partial)
        end
        if err == "closed" then
          self.closed = true
          return self.socketSubject:onCompleted()
        end
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, sock, timeout)
      if sock == nil then
        sock = socket.tcp()
      end
      if timeout == nil then
        timeout = 0.005
      end
      self.sock = sock
      self.timeoutValue = 0
      self:settimeout(timeout)
      self.mode = "NONE"
      self.socketSubject = Subject.create()
      self.closed = false
      return self.sock:setoption("keepalive", true)
    end,
    __base = _base_0,
    __name = "TcpSocket"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.connect = function(self, ...)
    local sock = socket.tcp()
    local res, err = sock:connect(...)
    print(res, err)
    return TcpSocket(sock)
  end
  self.getTime = function(self)
    return socket.gettime()
  end
  self.bind = function(self, ...)
    local sock = socket.tcp()
    local res, err = sock:bind(...)
    if err then
      return nil
    end
    return TcpSocket(sock)
  end
  TcpSocket = _class_0
end
local BZTTClient
do
  local _class_0
  local _base_0 = {
    _handleCompleteMessage = function(self, msg)
      local _exp_0 = (msg.type)
      if T_CONNECT_ACK == _exp_0 or T_DISCONNECT_ACK == _exp_0 or T_PUBLISH_ACK == _exp_0 or T_SUBSCRIBE_ACK == _exp_0 or T_UNSUBSCRIBE_ACK == _exp_0 then
        msg.payload = msg.payload:readNumber(4)
        if self.ackSubjects[msg.id] then
          self.ackSubjects[msg.id]:onNext(msg)
          self.ackSubjects[msg.id]:onCompleted()
        end
      elseif T_PUSH == _exp_0 then
        msg.payload = {
          topic = msg.payload:readString(),
          message = msg.payload:readString()
        }
        if self.pushTopicSubjects[msg.payload.topic] then
          self.pushTopicSubjects[msg.payload.topic]:onNext(msg.payload.message)
        end
        self.pushSubject:onNext(msg.payload.topic, msg.payload.message)
      else
        error(("Unknown message type %s"):format(tostring(msg.type)))
      end
      return self.receiveSubject:onNext(msg)
    end,
    _receive = function(self, data)
      self.readBuffer:append(data)
      while (true) do
        local _continue_0 = false
        repeat
          do
            if (self.readState == 0) and (self.readBuffer:available() >= 9) then
              self.readState = 1
              self.nextPack = {
                type = self.readBuffer:readNumber(1),
                id = self.readBuffer:readNumber(4)
              }
            end
            if (self.readState == 1 and (self.readBuffer:canReadString())) then
              self.nextPack.payload = self.readBuffer:readBuffer()
              self.readBuffer = self.readBuffer:slice()
              self:_handleCompleteMessage(self.nextPack)
              self.readState = 0
              _continue_0 = true
              break
            end
            break
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end,
    sendMessage = function(self, type, payload, id)
      if id == nil then
        id = self:idGenerator()
      end
      local writeBuffer = WriteBuffer()
      writeBuffer:putNumber(type, 1)
      writeBuffer:putNumber(id, 4)
      writeBuffer:putBuffer(payload)
      local subject = AsyncSubject.create()
      self.ackSubjects[id] = subject
      self.socket:send(writeBuffer:bytes())
      return subject
    end,
    onReceive = function(self, id)
      if id ~= nil then
        return self.ackSubjects[id]
      end
      return self.receiveSubject
    end,
    onPush = function(self, topic)
      if topic == nil then
        topic = nil
      end
      if (topic ~= nil) then
        return self.pushTopicSubjects[topic]
      end
      return self.pushSubject
    end,
    connect = function(self, user)
      assert(not self.connecting, "Already trying to connect...")
      assert(not self.connected, "Already connected")
      local buffer = WriteBuffer()
      buffer:putString(user.clientId)
      buffer:putString(user.username)
      buffer:putNumber(user.userId, 1)
      buffer:putNumber(user.team, 1)
      return self:sendMessage(T_CONNECT, buffer):map(function()
        self.connected = true
        self.connecting = false
        self.connectedUser = user
        return user
      end)
    end,
    joinTopic = function(self, ...)
      local topics = {
        ...
      }
      local buffer = WriteBuffer()
      buffer:putStringArray(topics)
      for i, v in ipairs(topics) do
        self.pushTopicSubjects[v] = Subject.create()
      end
      return self:sendMessage(T_SUBSCRIBE, buffer):map(function()
        return unpack(topics)
      end)
    end,
    publishTbl = function(self, topic, data)
      return self:publish(topic, json.encode(data))
    end,
    publish = function(self, topic, data)
      local buffer = WriteBuffer()
      buffer:putString(tostring(topic))
      buffer:putString(tostring(data))
      return self:sendMessage(T_PUBLISH, buffer):map(function()
        return topic
      end)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, socket)
      self.socket = socket
      self.readBuffer = ReadBuffer()
      self.readState = 0
      self.nextPack = nil
      self.inflightMessages = { }
      self.idGenerator = simpleIdGeneratorFactory()
      self.connected = false
      self.connectedUser = nil
      self.connecting = false
      self.ackSubjects = { }
      self.receiveSubject = Subject.create()
      self.pushTopicSubjects = { }
      self.pushSubject = Subject.create()
      return self.socket:receive():subscribe((function()
        local _base_1 = self
        local _fn_0 = _base_1._receive
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
    end,
    __base = _base_0,
    __name = "BZTTClient"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.create = function(self, hostname, port)
    if port == nil then
      port = 8889
    end
    socket = TcpSocket:connect(hostname, port)
    return BZTTClient(socket)
  end
  BZTTClient = _class_0
end
return {
  BZTTClient = BZTTClient,
  TcpSocket = TcpSocket,
  WriteBuffer = WriteBuffer,
  ReadBuffer = ReadBuffer
}
 end)
package.preload['bzutils'] = (function (...)
local service = require("service")
local utils = require("utils")
local event = require("event")
local net = require("net")
local component = require("component")
local bz_handle = require("bz_handle")
local runtime = require("runtime")
local ecs = require("ecs_module")
local Module = require("module")
local ComponentManager
ComponentManager = component.ComponentManager
local NetworkInterfaceManager
NetworkInterfaceManager = net.NetworkInterfaceManager
local RuntimeController
RuntimeController = runtime.RuntimeController
local EventDispatcherModule
EventDispatcherModule = event.EventDispatcherModule
local EntityComponentSystemModule
EntityComponentSystemModule = ecs.EntityComponentSystemModule
local bz1Setup
bz1Setup = function(use_bzext, modid, devid)
  if use_bzext == nil then
    use_bzext = true
  end
  local serviceManager = service.ServiceManager()
  local core = Module()
  event = core:useModule(EventDispatcherModule, serviceManager)
  net = core:useModule(NetworkInterfaceManager, serviceManager)
  local componentManager = core:useModule(ComponentManager, serviceManager)
  local runtimeManager = core:useModule(RuntimeController, serviceManager)
  ecs = core:useModule(EntityComponentSystemModule, serviceManager)
  serviceManager:createService("bzutils.bzapi", event)
  serviceManager:createService("bzutils.net", net)
  serviceManager:createService("bzutils.component", componentManager)
  serviceManager:createService("bzutils.runtime", runtimeManager)
  serviceManager:createService("bzutils.ecs", ecs)
  if use_bzext then
    local dloader = require("dloader")
    assert(dloader.initLoader(modid, true, devid), "Failed to init dll loader")
    local sock = require("sock_m")
    local sockModule = core:useModule(sock.NetSocketModule, serviceManager)
    serviceManager:createService("bzutils.socket", sockModule)
  end
  return {
    core = core,
    serviceManager = serviceManager
  }
end
local bz2Setup
bz2Setup = function() end
local defaultSetup
defaultSetup = function(use_bzext, modid, devid)
  if use_bzext == nil then
    use_bzext = true
  end
  if IsBzr() or IsBz15() then
    return bz1Setup(use_bzext, modid, devid)
  elseif IsBz2 then
    return bz2Setup(use_bzext, modid, devid)
  end
end
return {
  defaultSetup = defaultSetup,
  bz1Setup = bz1Setup,
  bz2Setup = bz2Setup,
  bz_handle = bz_handle,
  utils = utils,
  component = component,
  runtime = runtime,
  event = event,
  service = service,
  net = net,
  ecs = ecs
}
 end)
package.preload['socket'] = (function (...)
-----------------------------------------------------------------------------
-- LuaSocket helper module
-- Author: Diego Nehab
-- RCS ID: $Id: socket.lua,v 1.22 2005/11/22 08:33:29 diego Exp $
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Declare module and import dependencies
-----------------------------------------------------------------------------
local base = _G
local string = require("string")
local math = require("math")
local socket = require("sockdl")
module("socket")

-----------------------------------------------------------------------------
-- Exported auxiliar functions
-----------------------------------------------------------------------------
function connect(address, port, laddress, lport)
    local sock, err = socket.tcp()
    if not sock then return nil, err end
    if laddress then
        local res, err = sock:bind(laddress, lport, -1)
        if not res then return nil, err end
    end
    local res, err = sock:connect(address, port)
    if not res then return nil, err end
    return sock
end

function bind(host, port, backlog)
    local sock, err = socket.tcp()
    if not sock then return nil, err end
    sock:setoption("reuseaddr", true)
    local res, err = sock:bind(host, port)
    if not res then return nil, err end
    res, err = sock:listen(backlog)
    if not res then return nil, err end
    return sock
end

try = newtry()

function choose(table)
    return function(name, opt1, opt2)
        if base.type(name) ~= "string" then
            name, opt1, opt2 = "default", name, opt1
        end
        local f = table[name or "nil"]
        if not f then base.error("unknown key (".. base.tostring(name) ..")", 3)
        else return f(opt1, opt2) end
    end
end

-----------------------------------------------------------------------------
-- Socket sources and sinks, conforming to LTN12
-----------------------------------------------------------------------------
-- create namespaces inside LuaSocket namespace
sourcet = {}
sinkt = {}

BLOCKSIZE = 2048

sinkt["close-when-done"] = function(sock)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function(self, chunk, err)
            if not chunk then
                sock:close()
                return 1
            else return sock:send(chunk) end
        end
    })
end

sinkt["keep-open"] = function(sock)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function(self, chunk, err)
            if chunk then return sock:send(chunk)
            else return 1 end
        end
    })
end

sinkt["default"] = sinkt["keep-open"]

sink = choose(sinkt)

sourcet["by-length"] = function(sock, length)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            if length <= 0 then return nil end
            local size = math.min(socket.BLOCKSIZE, length)
            local chunk, err = sock:receive(size)
            if err then return nil, err end
            length = length - string.len(chunk)
            return chunk
        end
    })
end

sourcet["until-closed"] = function(sock)
    local done
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            if done then return nil end
            local chunk, err, partial = sock:receive(socket.BLOCKSIZE)
            if not err then return chunk
            elseif err == "closed" then
                sock:close()
                done = 1
                return partial
            else return nil, err end
        end
    })
end


sourcet["default"] = sourcet["until-closed"]

source = choose(sourcet)

 end)
local _ = require("rx")
_ = require("tiny")
_ = require("json")
_ = require("base64")
_ = require("uuid")
_ = require("json")
_ = require("serpent")
_ = require("component")
_ = require("net")
_ = require("runtime")
_ = require("ecs_module")
_ = require("sock_m")
_ = require("event")
_ = require("bzcomp")
_ = require("bzserial")
_ = require("bztiny")
_ = require("tiny")
_ = require("bzsystems")
_ = require("exmath")
_ = require("graph")
_ = require("bz_handle")
_ = require("module")
_ = require("msetup")
_ = require("service")
_ = require("terrain")
_ = require("utils")
_ = require("lvdf")
_ = require("os")
_ = require("dloader")
_ = require("bzext")
_ = require("bztt")
_ = require("bzutils")
