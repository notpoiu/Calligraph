-- Calligraph | sashaa169 / centerepic
-- This is a module designed to provide a simple way to log all high-level interactions with instances in Roblox from a specific script.
-- Usually used for aiding in dissassembly and debugging of obfuscated scripts.
-- It is highly reccomended to run this in auto-exec as it cannot capture calls made before it is loaded.

--!strict

shared.DirectCall = {}

--#region Definitions

local MAX_BUFFER_SIZE = 1024 * 1024 * 1024 -- 1 GiB

--#endregion

--#region Types

type SessionConfiguration = {
	LogEnvironment         : boolean,  -- Hook all functions in standard script Environment?
	LogMetamethods         : boolean,  -- Hook metamethods?
	LogAsCode              : boolean?, -- Log as executable Luau code instead of JSON? (Defaults to true)
	LuraphCompatibility    : boolean?, -- Enable Luraph compatibility mode? (Defaults to false)
	FilterInstanceIndex    : boolean?, -- Filter out instance index calls? (Defaults to false)
	PrettyPrint            : boolean?, -- Enable pretty printing of logs? (Defaults to true)
	ShowDebugIdForNilInstancesInsteadOfName : boolean?, -- Show DebugId for nil instances instead of their name? (Defaults to true)
	LogMetamethodFunctionFetches : boolean?, -- Log metamethod function fetches? (Defaults to true)
	MetaMethodFunctionFetchTrap : boolean?, -- Replace metamethod function fetches with traps? (Defaults to true)
}

local DefaultSessionConfiguration: SessionConfiguration = {
	LogEnvironment = true,
	LogMetamethods = true,
	LogAsCode = true,
	LuraphCompatibility = false,
	FilterInstanceIndex = false,
	PrettyPrint = true,
	ShowDebugIdForNilInstancesInsteadOfName = true,
	LogMetamethodFunctionFetches = true,
	MetaMethodFunctionFetchTrap = true,
}

type LogConstructorSet = {
	FunctionCall           : (Function: (...any?) -> ...any?, Args: { any? }, Return: { any? }, FunctionPath: string?) -> string,
	Namecall               : (Instance: Instance, Method: string, Args: { any? }, Return: { any? }) -> string,
	Index                  : (Instance: Instance, Key: string, Return: { any? }) -> string,
	NewIndex               : (Instance: Instance, Key: string, Value: any) -> string,
}

type Session = {
	Configuration          : SessionConfiguration,
	Targets                : { string },
	Data                   : buffer,
	Written                : number,
	Start                  : number,
	End                    : number,
	Close                  : () -> (),
	GUID                   : string,
	Log                    : (LogString: string) -> (),
	Active                 : boolean,
	SaveToFile             : (self: Session, FileName: string) -> (),
}

--#endregion

--#region Imports

local HttpService = game:GetService("HttpService")
local LuaEncodeAndEvaluateInstancePath = require("./modules/LuaEncode.luau")
local LuaEncodeCore, EvaluateInstancePath =
	LuaEncodeAndEvaluateInstancePath.LuaEncode, LuaEncodeAndEvaluateInstancePath.EvaluateInstancePath
-- this is so bad but wtv i just need it to work
local HookMgr = require("./modules/HookMgr.luau")
local Utils = require("./modules/Utils.luau")

local DebugInfo = getrenv and getrenv().debug.info or debug.info

local JSONEncode = function(...): string
	if shared.DirectCall.__namecall then
		return shared.DirectCall.__namecall(HttpService, "JSONEncode", ...)
	else
		return HttpService:JSONEncode(...)
	end
end

local LuaEncode = function(x)
	local OldThreadContext = getthreadcontext()
	setthreadcontext(8)
	local Result = LuaEncodeCore(
		x,
		{
			Prettify = #x > 1 and shared.Prettify
		}
	)
	setthreadcontext(OldThreadContext)
	return Result
end

--#endregion

--#region Module

local Calligraph = {
	Version = "1.5.4",
}

-- Log Constructors for the JSON format
local JSONLogConstructors: LogConstructorSet = {
	FunctionCall = function(Function, Args, Return, FunctionPath)
		return JSONEncode({
			Time = os.clock(),
			Type = "FunctionCall",
			Name = FunctionPath or DebugInfo(Function, "n") or tostring(Function),
			Args = LuaEncode(Args),
			Return = LuaEncode(Return),
		})
	end,
	Namecall = function(Instance, Method, Args, Return)
		return JSONEncode({
			Time = os.clock(),
			Type = "Namecall",
			Instance = Instance:GetFullName(),
			Method = Method,
			Args = LuaEncode(Args),
			Return = LuaEncode(Return),
		})
	end,
	Index = function(Instance, Key, Return)
		return JSONEncode({
			Time = os.clock(),
			Type = "Index",
			Instance = Instance:GetFullName(),
			Key = Key,
			Return = LuaEncode(Return),
		})
	end,
	NewIndex = function(Instance, Key, Value)
		return JSONEncode({
			Time = os.clock(),
			Type = "NewIndex",
			Instance = Instance:GetFullName(),
			Key = Key,
			Value = LuaEncode({ Value }),
		})
	end,
}

local function FormatCodeArgs(Args: { any? }): string
	local OldThreadContext = getthreadcontext and getthreadcontext() or 1
	setthreadcontext(7)

	local Encoded = LuaEncode(Args)

	setthreadcontext(OldThreadContext)

	return string.sub(Encoded, 2, -2)
end

local function FormatInstancePath(Instance: Instance): string
	if not Instance then
		return "nil"
	end

	-- local Path = Instance:GetFullName()

	-- make linter happy (httpget union makes game global not an instance)
	if Instance.Parent == nil and (Instance :: any) ~= game then
		-- idk how to rly handle nil instances yet
		-- return `nil...{Instance.Name}`
		local OldContext = getthreadcontext()
		setthreadcontext(8)
		local NilInstanceString = `<{Instance.ClassName}`
		if shared.UseDebugId then
			NilInstanceString ..= ` {Instance:GetDebugId()}>`
		else
			NilInstanceString ..= ` {Instance.Name}>`
		end
		setthreadcontext(OldContext)
		return NilInstanceString
	end

	return EvaluateInstancePath(Instance)
end

local CodeLogConstructors: LogConstructorSet = {
	FunctionCall = function(Function, Args, Return, FunctionPath)
		local FunctionName = FunctionPath or DebugInfo(Function, 'n') or `<Anonymous {tostring(Function)}>`
		return string.format("%s(%s) --> %s", FunctionName, FormatCodeArgs(Args), LuaEncode(Return))
	end,
	Namecall = function(Instance, Method, Args, Return)
		local CallArgs = {}

		for i, v in ipairs(Args) do -- ipairs to filter out the n=... value
			-- if i > 1 then -- skip self as it's already inferred to be a namecall
			table.insert(CallArgs, v)
			-- end
		end

		return string.format(
			"%s:%s(%s) --> %s",
			FormatInstancePath(Instance),
			Method,
			FormatCodeArgs(CallArgs),
			LuaEncode(Return)
		)
	end,
	Index = function(Instance, Key, Return)

		-- Check if Return is a RbxScriptSignal
		if typeof(Return[1]) == "RBXScriptSignal" then
			return string.format("%s.%s --> <RBXScriptSignal %s>", FormatInstancePath(Instance), Key, Key)
		end

		return string.format("%s.%s --> %s", FormatInstancePath(Instance), Key, LuaEncode(Return))
	end,
	NewIndex = function(Instance, Key, Value)
		return string.format("%s.%s = %s", FormatInstancePath(Instance), Key, Value and FormatCodeArgs({ Value }) or "nil")
	end,
}

function Calligraph.NewMethodProxy(
	Session: Session,
	Formatter: LogConstructorSet,
	Method: string,
	Instance: Instance,
	OldMethod: (...any?) -> ...any?
)
	return newcclosure(function(...)
		if checkcaller() then
			return OldMethod(...)
		end
		local Args = { ... }
		local Success, Return, ArgsN = Utils.GetReturnData(OldMethod, ...)
		local ReturnFormatted = Success and Return or { ["error"] = Return[1] }

		-- Remove the first argument since it's self and we're already logging it as a __namecall
		table.remove(Args, 1)

		task.spawn(function()
			Session.Log(Formatter.Namecall(Instance, Method, Args, ReturnFormatted))
		end)
		if Success then
			return table.unpack(Return, 1, ArgsN)
		else
			return error(Return[1])
		end
	end)
end

function Calligraph.NewRBXScriptSignalProxy(
	Session: Session,
	Formatter: LogConstructorSet,
	Instance: Instance,
	Signal: RBXScriptSignal
)
	local Proxy = {
		Connect = newcclosure(function(self, Callback: (...any?) -> ...any?)
			if checkcaller() then
				return Signal:Connect(Callback)
			end
			task.spawn(function()
				local SignalPath = FormatInstancePath(Instance) .. "." .. tostring(Signal):gsub("Signal ", "")
				Session.Log(
					string.format("%s:Connect(%s)", SignalPath, FormatCodeArgs({ Callback }))
				)
			end)
			return Signal:Connect(Callback)
		end),
		ConnectParallel = newcclosure(function(self, Callback: (...any?) -> ...any?)
			if checkcaller() then
				return Signal:Connect(Callback)
			end
			task.spawn(function()
				local SignalPath = FormatInstancePath(Instance) .. "." .. tostring(Signal):gsub("Signal ", "")
				Session.Log(
					string.format("%s:Connect(%s)", SignalPath, FormatCodeArgs({ Callback }))
				)
			end)
			return Signal:Connect(Callback)
		end),
		Once = newcclosure(function(self, Callback: (...any?) -> ...any?)
			if checkcaller() then
				return Signal:Once(Callback)
			end
			task.spawn(function()
				local SignalPath = FormatInstancePath(Instance) .. "." .. tostring(Signal):gsub("Signal ", "")
				Session.Log(
					string.format("%s:Once(%s)", SignalPath, FormatCodeArgs({ Callback }))
				)
			end)
			return Signal:Once(Callback)
		end),
		Wait = newcclosure(function(self)
			if checkcaller() then
				return Signal:Wait()
			end
			task.spawn(function()
				local SignalPath = FormatInstancePath(Instance) .. "." .. tostring(Signal):gsub("Signal ", "")
				Session.Log(
					string.format("%s:Wait()", SignalPath)
				)
			end)
			return Signal:Wait()
		end)
	}

	local SignalMetatable = {
		__index = function(self, key)
			return rawget(Signal, key)
		end,
		__tostring = function()
			return tostring(Signal)
		end,
		__type = function()
			return "RBXScriptSignal"
		end,
		__eq = function(self, other)
			if other == Signal then
				return true
			end
			return false
		end
	}

	setmetatable(Proxy, SignalMetatable)

	return Proxy
end

-- i hate this
function Calligraph.NewFunctionProxy(
	Session: Session,
	Formatter: LogConstructorSet,
	Function: (...any?) -> ...any?,
	FunctionPath: string?
)
	return function(Old, ...)
		if checkcaller() then
			return Old(...)
		end

		local CallSource = DebugInfo(4, "s")
		-- print('log', Old, ...)

		if not table.find(Session.Targets, CallSource) then
			return Old(...)
		end

		local Args = { ... }
		local Success, Return, ArgsN = Utils.GetReturnData(Old, ...)
		local ReturnFormatted = Success and Return or { ["error"] = Return[1] }

		task.spawn(function()
			Session.Log(Formatter.FunctionCall(Old, Args, ReturnFormatted, FunctionPath))
		end)

		if Success then
			return table.unpack(Return, 1, ArgsN)
		else
			return error(Return[1])
		end
	end
end

function Calligraph:NewSession(Targets: { string }, Configuration: SessionConfiguration)

	-- Load default session configuration for unset keys
	for Key, Value in next, DefaultSessionConfiguration do
		if Configuration[Key] == nil then
			Configuration[Key] = Value
		end
	end

	shared.Prettify = (Configuration.PrettyPrint == true)
	shared.UseDebugId = (Configuration.ShowDebugIdForNilInstancesInsteadOfName == true)

	local Session: Session
	local LogFormatter: LogConstructorSet = (Configuration.LogAsCode == true) and CodeLogConstructors
		or JSONLogConstructors
	local LastLogContent: string = ""
	local RepeatCount: number = 0

	local GameMetamethods = {
		[HookMgr.GameMT.__index] = "__index",
		[HookMgr.GameMT.__newindex] = "__newindex",
		[HookMgr.GameMT.__namecall] = "__namecall"
	}

	local function WriteToBuffer(FormattedLog: string)
		if Session.Written + #FormattedLog > MAX_BUFFER_SIZE then
			local FinalMsg = "[SYSTEM] Buffer full. Further logs will be ignored.\n"
			if Session.Written + #FinalMsg <= MAX_BUFFER_SIZE then
				buffer.writestring(Session.Data, Session.Written, FinalMsg)
				Session.Written += #FinalMsg
			end
			Session.Active = false
			warn("Calligraph: Log buffer is full. Logging has been stopped.")
			return
		end
		buffer.writestring(Session.Data, Session.Written, FormattedLog)
		Session.Written += #FormattedLog
	end

	local function FlushRepeatedLog()
		if RepeatCount > 1 then
			local Timestamp = os.date("%Y-%m-%d %H:%M:%S")
			local RepeatLog = string.format(`[%s] (Repeated x%d) %s\n`, Timestamp, RepeatCount, LastLogContent)
			WriteToBuffer(RepeatLog)
		elseif RepeatCount == 1 then
			local Timestamp = os.date("%Y-%m-%d %H:%M:%S")
			local SingleLog = string.format(`[%s] %s\n`, Timestamp, LastLogContent)
			WriteToBuffer(SingleLog)
		end
		RepeatCount = 0
		LastLogContent = ""
	end

	Session = {
		Configuration = Configuration,
		Targets = Targets,
		Data = buffer.create(MAX_BUFFER_SIZE),
		Written = 0,
		Start = os.clock(),
		End = 0,
		GUID = HttpService:GenerateGUID(false),
		Active = true,
		Close = function()
			if not Session.Active then
				return
			end
			Session.End = os.clock()
			Session.Log("Session ended at " .. Session.End .. " seconds.")
			Session.Active = false
			HookMgr.ClearHooks()
			FlushRepeatedLog()
		end,
		Log = function(LogString: string)
			if not Session.Active then
				return
			end
			
			local IsSystemMessage = string.match(LogString, "^%[SYSTEM%]") or 
									string.match(LogString, "^Calligraph v") or
									string.match(LogString, "^Session") or
									string.match(LogString, "^Configuration:") or
									string.match(LogString, "^Targets:") or
									string.match(LogString, "^Log format:")
			
			if IsSystemMessage then
				FlushRepeatedLog()
				local FormattedLog = string.format(`[%s] %s\n`, os.date("%Y-%m-%d %H:%M:%S"), LogString)
				WriteToBuffer(FormattedLog)
				return
			end
			
			if LogString == LastLogContent then
				RepeatCount += 1
			else
				FlushRepeatedLog()
				LastLogContent = LogString
				RepeatCount = 1
			end
		end,
		SaveToFile = function(self: Session, FileName: string)
			FlushRepeatedLog()
			
			if not writefile or not appendfile then
				warn("Calligraph: 'writefile/appendfile' is not available. Cannot save to file.")
				return
			end
			local Success, Error: any = pcall(function()
				writefile(FileName, "")
				local TotalSize = self.Written
				if TotalSize == 0 then
					return
				end
				local ChunkSize = math.max(1, math.floor(TotalSize / 10))
				for Offset = 0, TotalSize - 1, ChunkSize do
					local CurrentChunkSize = math.min(ChunkSize, TotalSize - Offset)
					appendfile(FileName, buffer.readstring(self.Data, Offset, CurrentChunkSize))
				end
			end)
			if not Success then
				warn("Calligraph: Failed to save log to file. Error:", tostring(Error))
			else
				print("Calligraph: Successfully saved", self.Written, "bytes to", FileName)
			end
		end,
	}

	Session.Log(`Calligraph v{Calligraph.Version}`)
	Session.Log("Session started at " .. Session.Start .. " seconds.")
	Session.Log("Session GUID: " .. Session.GUID)
	Session.Log("Configuration: " .. JSONEncode(Session.Configuration))
	Session.Log("Targets: " .. table.concat(Session.Targets, ", "))
	Session.Log(`Log format: {Session.Configuration.LogAsCode and "Luau Code" or "JSON"}`)
	Session.Log("[SYSTEM] Calligraph is now active. All logs will be recorded.")

	if Session.Configuration.LogMetamethodFunctionFetches then
		shared.DirectCall.DebugInfo = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:MetamethodFunctionFetch`, getrenv().debug.info, function(Old, ...)
			if checkcaller() then
				return Old(...)
			end

			local Args = table.pack(...)
			if Args.n ~= 2 then
				return Old(...)
			end

			if typeof(Args[1]) == 'number' and typeof(Args[2]) == 'string' and Args[2]:match("f") then

				-- stack visualization of debug.info call:
				-- 1. current level
				-- 2. hook wrapper [Added by hook]
				-- 3. pcall inside GetReturnData [Added by hook]
				-- 4. function call to GetReturnData [Added by hook]
				-- 5. cclosure wrapper [Added by hook]
				-- 6. original function call

				-- our hook adds 4 stack levels, so we need to offset the number.

				-- function Utils.GetReturnData(Function : (...any?) -> (...any?), ...)
				-- 	local Results = table.pack(pcall(Function, ...))
				-- 	local ArgsN = Results.n - 1
					
				-- 	-- Remove Args.n now
				-- 	if Results.n then
				-- 		Results.n = nil
				-- 	end
				--
				-- 	return table.remove(Results, 1), Results, ArgsN
				-- end

				local Success, Return, ReturnN = Utils.GetReturnData(Old, Args[1] + 4, Args[2])

				if not Success then
					return Old(...)
				end

				local ModifiedArgs = {}
				
				for i = 1, ReturnN do
					local Value = Return[i]
					ModifiedArgs[i] = Value

					-- print('[dbg] Checking if debug.info return value is a metamethod', Value)

					if 
						typeof(Value) == "function" and
						iscclosure(Value) and
						GameMetamethods[Value]
					then
						-- print('[dbg] Found metamethod function:', Value)
						task.spawn(Session.Log, string.format("[!!!] Raw %s function fetched: %s", GameMetamethods[Value], tostring(Value)))
						if Session.Configuration.MetaMethodFunctionFetchTrap then
							-- print('[dbg] Returning trap instead of metamethod function')
							ModifiedArgs[i] = newcclosure(function()
								print(string.format('[Calligraph] Metamethod trap triggered! Method: %s, Traceback: %s', GameMetamethods[Value], debug.traceback()))
								task.spawn(Session.Log, string.format("[!!!] Metamethod trap triggered! Method: %s, Traceback: %s", GameMetamethods[Value], debug.traceback()))
								return coroutine.yield()
							end)
						end
					end
				end

				return table.unpack(ModifiedArgs, 1, ReturnN)
			end
			
			return Old(...) -- doublecall but whatever i cant be assed to recreate the errors
		end)

		DebugInfo = shared.DirectCall.DebugInfo.Original
	end

	if Session.Configuration.LogMetamethods then
		shared.DirectCall.__index = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__index`,
			HookMgr.GameMT.__index,
			function(Old, Self, Index)
				if checkcaller() then
					return Old(Self, Index)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(Self, Index)
				end

				local Return = Old(Self, Index)

				if not (Session.Configuration.LuraphCompatibility == true and type(Return) == "function") then
					if not (Session.Configuration.FilterInstanceIndex == true and typeof(Return) == "Instance") then
						task.spawn(function()
							Session.Log(LogFormatter.Index(Self, Index, { Return }))
						end)
					end
				end

				if type(Return) == "function" and not checkcaller() then
					return Calligraph.NewMethodProxy(Session, LogFormatter, Index, Self, Return)
				elseif typeof(Return) == "RBXScriptSignal" then
					return Calligraph.NewRBXScriptSignalProxy(Session, LogFormatter, Self, Return)
				end

				return Return
			end
		)

		shared.DirectCall.__newindex = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__newindex`,
			HookMgr.GameMT.__newindex,
			function(Old, Self, Index, Value)
				if checkcaller() then
					return Old(Self, Index, Value)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(Self, Index, Value)
				end

				task.spawn(function()
					Session.Log(LogFormatter.NewIndex(Self, Index, Value))
				end)

				return Old(Self, Index, Value)
			end
		)

		shared.DirectCall.__namecall = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__namecall`,
			HookMgr.GameMT.__namecall,
			function(Old, Self, ...)
				if checkcaller() then
					return Old(Self, ...)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(Self, ...)
				end

				local Args = { ... }
				local Method = getnamecallmethod()
				local Return = { Old(Self, ...) }

				task.spawn(function()
					Session.Log(LogFormatter.Namecall(Self, Method, Args, Return))
				end)

				return table.unpack(Return)
			end
		)
	end

	if Session.Configuration.LogEnvironment and getrenv then
		local Whitelist = {
			["require"] = true,
			-- ["print"] = true,
			-- ["warn"] = true,
			-- ["error"] = true,
			["tostring"] = true, -- Luraph spams this but is useful sometimes
			["tonumber"] = true,
			["typeof"] = true,
			["tick"] = true,
			-- Tables prefixed with t_ will have all their functions hooked
			-- ["t_CFrame"] = true,
			-- ["t_Vector3"] = true,
			-- ["t_Vector2"] = true,
			["t_Random"] = true,
			["t_os"] = true,
			["t_math"] = true,
			-- ["t_bit32"] = true, -- Luraph spams this with garbage
			-- ["t_table"] = true,
			-- ["t_coroutine"] = true,
			["t_task"] = true,
		}

		local Blacklist = {
			["t_task.wait"] = true, -- spammy and useless
		}

		local function HookTableFunctions(TargetTable: { [string]: any }, PathPrefix: string)
			for Name, Value in pairs(TargetTable) do
				if type(Value) == "function" then
					local FullPath = if PathPrefix ~= "" then PathPrefix .. "." .. Name else Name
					if Blacklist["t_" .. FullPath] then
						continue
					end
					HookMgr.RegisterHook(
						`Calligraph:{Session.GUID}:FunctionCall:` .. FullPath,
						Value,
						Calligraph.NewFunctionProxy(Session, LogFormatter, Value, FullPath)
					)
				end
			end
		end

		local function ScanAndHookWhitelisted(TargetTable: { [string]: any })
			for Name, Value in pairs(TargetTable) do
				if type(Name) ~= "string" then
					continue -- Skip non-string keys
				end

				if Whitelist[Name] and type(Value) == "function" then
					if Blacklist[Name] then
						continue
					end
					-- Direct function in whitelist (e.g., print)
					HookMgr.RegisterHook(
						`Calligraph:{Session.GUID}:FunctionCall:` .. Name,
						Value,
						Calligraph.NewFunctionProxy(Session, LogFormatter, Value, Name)
					)
				elseif Whitelist["t_" .. Name] and type(Value) == "table" then
					-- Table in whitelist (e.g., t_math for math table)
					HookTableFunctions(Value, Name)
				end
			end
		end

		ScanAndHookWhitelisted(getrenv())
	end

	return Session
end

return Calligraph

--#endregion
