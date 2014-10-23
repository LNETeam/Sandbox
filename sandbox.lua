tArgs = {...}

old_clear = term.clear
debug = true
_container = {}

local _stat,_err = pcall(function()


acceptData = false

local programThread = nil
local eventCallerWhiteList = {}
local eventDataBlacklist = {}
local _NORESTART = true

local _events = {"char","key","paste","timer","alarm","redstone","terminate","disk","disk_eject","peripheral","peripheral_detach","rednet_message","modem_message","http_success","http_failure","mouse_click","mouse_scroll","mouse_drag","monitor_touch","monitor_resize","term_resize","turtle_inventory"}



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

	local backup = {}
	local tFilters = {}
	local eventData = {}
	while true do
		for n=1,count do
			local r = _routines[n]
			if r then
				if (r ~= eventCallerWhiteList.controller or r == eventCallerWhiteList.yield) then
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
				elseif (r == eventCallerWhiteList.controller or r == eventCallerWhiteList.yield) then
					if tFilters[r] == nil or tFilters[r] == backup[1] or backup[1] == "terminate" then
						local ok, param = coroutine.resume( r, unpack(backup) )
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
		backup = eventData
		if not acceptData then
			for k,v in next , eventDataBlacklist do
				if (v == eventData[1]) then
					eventData = {}
				end
			end
		end
	end
end

function instanceController()

	while true do 
		local ev = {os.pullEvent()}
		
		if (ev[1] == "key" and ev[2] == 157) then
			os.queueEvent("yield_process")
			break
		end
	end

	term.setBackgroundColor(colors.blue)
	term.setTextColor(colors.white)
	term.clear = function()
		term.setBackgroundColor(colors.blue)
		term.setCursorPos(1,1)
		term.clearLine()
		term.write("> ")
	end

	while true do
		term.setCursorPos(2,1)
		local input = read()
		local opts = split(input," ")
		if (opts[1] == "kill") then
			term.setBackgroundColor(colors.black)
			old_clear()
			term.setCursorPos(1,1)
			_NORESTART = false
			error()
		elseif (opts[1] == "deny" ) then
			if (opts[2] == "-all") then
				eventDataBlacklist = _events
			elseif (opts[2] == "-e") then
				for k,v in next , eventDataBlacklist do
					if v == opts[3] then
						break
					end
				end
				table.insert(eventDataBlacklist,opts[3])
			end
		elseif (opts[1] == "allow") then
			if (opts[2] == "-all") then
				eventDataBlacklist = {}
			elseif (opts[2] == "-e") then
				for k,v in next , eventDataBlacklist do
					if (v == opts[3]) then
						table.remove(eventDataBlacklist,k)
					end
				end
			end
		elseif (opts[1] == "restart") then
			programThread = nil
			break
		elseif (opts[1] == "settop") then
			if (fs.exists(opts[2])) then
				_container.local_dir = opts[2]
			else
				term.write("Path does not exist!")
			end
		elseif (opts[1] == "throw") then --To be added

		elseif (opts[1] == "exit") then
			os.queueEvent("")
			break
		elseif (opts[1] == "sh") then
			term.clear()
			term.write("System going down for halt now!")
			sleep(2)
			os.shutdown()

		elseif (opts[1] == "re") then
			term.clear()
			term.write("System going down for reboot now!")
			sleep(2)
			os.reboot()
		elseif (opts[1] == "l") then
			print(textutils.serialize(eventDataBlacklist))
		elseif (debug and opts[1] == "clear") then
			term.setBackgroundColor(colors.black)
			old_clear()
		elseif (opts[1] == "vars") then			
			print("Value: "..coroutine.status(eventCallerWhiteList.yield))
			term.write("Value: "..coroutine.status(programThread))
		else
			term.clear()
			term.write("Unknown command: "..(opts and opts[1] or ""))
			os.pullEvent()
		end
		term.clear()
	end
end

function programController()
	local function yieldController()
		while true do
			local ev = {os.pullEvent()}
			if (ev[1] == "yield_process") then
				--error("Yield Expected")
				break
			end
		end
	end
	eventCallerWhiteList.yield = create(yieldController)
	--error("first")
	programThread = programThread and programThread or create(function() shell.run(_container.prog,unpack(_container.args)) end)
	local ops = {programThread,eventCallerWhiteList.yield}
	--runSandbox(ops,#ops-1)
	runSandbox(ops,1)
	--programController()
end



local container = {
	AddSandboxDefinition = function(self)
		--local controller = {create(function() shell.run(self.prog,unpack(self.args)) end)}
		local controller = {create(instanceController),create(programController)}
		self.process = controller[2]
		self.controller = controller[1]
		self.status = coroutine.status(self.process)
		eventCallerWhiteList.controller = self.controller
	end,
	AuxilaryDefine = function(self)
		self.process = nil
		self.controller = nil
		local controller = {create(instanceController),create(programController)}
		self.process = controller[2]
		self.controller = controller[1]
		eventCallerWhiteList.controller = self.controller
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
		runSandbox({self.process,self.controller},0)
		if (_NORESTART) then
			self:AuxilaryDefine()
			self:StartContainer()
		end
	end,
}

function split(s,sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        s:gsub(pattern, function(c) fields[#fields+1] = c end)
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
		prog = program,
		controller = nil,

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

_container = createContainer(_G,tArgs[1],tArgs[2],exArgs)

--error("second")
_container:AddSandboxDefinition()

_container:StartContainer()


end)

term.clear = old_clear

if (not _stat) then
	print(err)
	if (_err == "Terminated") then error() end
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.lightGray)
	term.clear()
	term.setCursorPos(1,2)
	term.setBackgroundColor(colors.gray)
	term.clearLine()
	term.setCursorPos(1,3)
	term.setBackgroundColor(colors.gray)
	term.clearLine()
	term.write(" Sandbox has encountered an error!")
	term.setCursorPos(1,4)
	term.setBackgroundColor(colors.gray)
	term.clearLine()
	term.setBackgroundColor(colors.lightGray)
	term.setCursorPos(1,6)
	print("Please try re-running sandbox. If you continue to experience crashes, please submit an issue to our Github repo for review.")
	term.setCursorPos(1,10)
	print("Exception:")
	term.setTextColor(colors.black)
	print("  ".._err)
	print()
	term.setTextColor(colors.white)
	print("Press any key to exit...")
	os.pullEvent("key")
	term.setBackgroundColor(colors.black)
	term.clear()
	term.setCursorPos(1,1)
end

--instanceController()
--term.clear = old_clear
