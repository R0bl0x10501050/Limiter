local HTTP = game:GetService("HttpService")

local Limiter = {}
Limiter.__index = Limiter

Limiter.Queue = {}
Limiter.MaxPerMinute = 5
Limiter.Active = false

Limiter.__events = {}

--// Internal Functions

function Limiter.__newEvent(name)
	local event = {}
	event.name = name
	
	function event:Fire(...)
		local func = Limiter.__events[self.name]
		if func then func(...) end
	end
	
	function event:Connect(callback)
		Limiter.__events[self.name] = callback
	end
	
	return event
end

Limiter.Activated = Limiter.__newEvent('activated')
Limiter.Deactivated = Limiter.__newEvent('deactivated')
Limiter.Added = Limiter.__newEvent('added')

--// Public Functions

function Limiter:SetRatelimit(rt: number)
	self.MaxPerMinute = rt
	if rt then self.MaxPerMinute = rt end
end

function Limiter:Add(misc, ...)
	self.Added:Fire()
	local args = {...}
	if typeof(misc) == "function" then
		table.insert(self.Queue, #self.Queue+1, misc)
	elseif typeof(misc) == "string" then
		if misc == "d_webhook" then
			local url = args[1]
			local data = {
				['content'] = args[2]
			}
			data = HTTP:JSONEncode(data)
			table.insert(self.Queue, #self.Queue+1, {url, data})
		end
	end
end

function Limiter:Activate()
	self.Activated:Fire()
	self.Active = true
	coroutine.resume(coroutine.create(function()
		local function handle()
			pcall(function()
				if self.Active == false then
					coroutine.yield()
				end
				
				local nextInQueue = self.Queue[1]
				if typeof(nextInQueue) == "function" then
					nextInQueue()
				elseif typeof(nextInQueue) == "table" then
					HTTP:PostAsync(nextInQueue[1], nextInQueue[2])
				end
				
				table.remove(self.Queue, 1)
			end)
		end
		
		handle()
		
		while wait(60/self.MaxPerMinute) do
			handle()
		end
	end))
end

function Limiter:Deactivate()
	self.Deactivated:Fire()
	self.Active = false
end

return Limiter
