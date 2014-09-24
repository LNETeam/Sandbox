tArgs = {...}

acceptData = false

old_term = term

local eventCallerWhiteList = {instanceController}
local eventDataBlacklist = {"key","char","mouse_drag"}

local function create( first, ... ) --Derived from parallel API
	if first ~= nil then
		if type( first ) ~= "function" then
			error( "Expected function, got "..type( first ), 3 )
		end
		return coroutine.create(first), create( ... )
	end
	return nil
end

local function runSandbox( _routines, _limit ) --Derived from parallel API
	local count = #_routines
	local living = count

	local tFilters = {}
	local eventData = {}
	while true do
		for n=1,count do
			local r = _routines[n]
			if r then
				if tFilters[r] == nil or tFilters[r] == eventData[1] or eventData[1] == "terminate" then
					local ok, param = coroutine.resume( r, unpack(eventData) )
					if not ok then
						error( param, 0 )
					else
						tFilters[r] = param
					end
					if coroutine.status( r ) == "dead" then
						_routines[n] = nil
						living = living - 1
						if living <= _limit then
							return n
						end
					end
				end
			end
		end
		for n=1,count do
			local r = _routines[n]
			if r and coroutine.status( r ) == "dead" then
				_routines[n] = nil
				living = living - 1
				if living <= _limit then
					return n
				end
			end
		end
		eventData = { os.pullEventRaw() }
		if not acceptData then
			for k,v in next , eventDataBlacklist do
				if (v == eventData[1]) then
					eventData = {}
				end
			end
		end
	end
end

local container = {
	AddSandboxDefinition = function(self)
		local controller = {create(function() shell.run(self.prog,unpack(self.args)) end)}
		self.process = controller[1]
		self.status = coroutine.status(self.process)
	end,
	GetProcess = function(self)
		return self.process
	end,
	GetStatus = function(self)
		self.status = coroutine.status(self.process)
		return self.status
	end,
	ResumeContainer = function(self)
		coroutine.resume(self.process)
	end,
	StartContainer = function(self)
		runSandbox({self.process},0)
	end,
}

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local function createContainer( env,locked_dir,program,args )
	local temp = 
	{
		process = nil,
		environment = env,
		status = nil,
		local_dir = "",
		args = args and args or nil,
		prog = program
	}
	setmetatable(temp, {__index = container})
	return temp
end


local exArgs = {}
if #tArgs > 2 then
	for i=3,#tArgs do
		table.insert(exArgs,tArgs[i])
	end
end

local _container = createContainer(_G,tArgs[1],tArgs[2],exArgs)

_container:AddSandboxDefinition()

--_container:StartContainer()

function instanceController()

	while true do 
		local ev = {os.pullEvent()}
		if (ev[1] == "keys" and ev[2] == "rightControl") then
			os.queueEvent("yield_process")
			break
		end
	end

	term.setBackgroundColor(colors.blue)
	term.setTextColor(colors.white)
	term.clear = function()
		old_term.setCursorPos(1,1)
		term.clearLine()
		term.write("> ")
	end

	term.clear()

	while true do
		local input = read()
		local opts = input:split(" ")
		if (input[1] == "kill") then
			return
		elseif (input[1] == "deny" ) then
			if (input[2] == "-all") then
				eventDataBlacklist = {"char","key","paste","timer","alarm","redstone","terminate","disk","disk_eject","peripheral","peripheral_detach","rednet_message","modem_message","http_success","http_failure","mouse_click","mouse_scroll","mouse_drag","monitor_touch","monitor_resize","term_resize","turtle_inventory"}
			elseif (input[2] == "-e") then
				for k,v in next , eventDataBlacklist do
					if v == e[3] then
						break
					end
				end
				table.insert(eventDataBlacklist,e[3])
			end
		elseif (input[1] == "allow") then
			if (input[2] == "-all") then
				eventDataBlacklist = {}
			elseif (input[2] == "-e") then
				for k,v in next , eventDataBlacklist do
					if (v == input[3]) then
						table.remove(eventDataBlacklist,k)
					end
				end
			end
		elseif (input[1] == "restart") then

		elseif (input[1] == "settop") then

		elseif (input[1] == "throw") then --To be added

		elseif (input[1] == "exit") then
			break
		elseif (input[1] == "sh") then

		elseif (input[1] == "re") then

		elseif (input[1] == "l") then

		end
		term.clear()
	end
	_container:ResumeContainer()
end

function programController(prog,args)
	local function yieldController()
		while true do
			local ev = {os.pullEvent()}
			if (ev[1] == "yield_process") then
				coroutine.yield()			
			end
		end
	end
	local ops = {create(function() shell.run(self.prog,unpack(self.args)) end),create(yieldController))
	runSandbox(ops,#ops-1)
end

term = old_term

--instanceController()
--term.clear = old_clear
