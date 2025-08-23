-- Calligraph | sashaa169 / centerepic
-- This is a module designed to provide a simple way to log all high-level interactions with instances in Roblox from a specific script.
-- Usually used for aiding in dissassembly and debugging of obfuscated scripts.
-- It is highly reccomended to run this in auto-exec as it cannot capture calls made before it is loaded.

--!strict

shared.DirectCall = {}
shared.ProxyLookup = {}

--#region Definitions

local MAX_BUFFER_SIZE = 1024 * 1024 * 1024 -- 1 GiB

--#endregion

--#region Types

type SessionConfiguration = {
	LogEnvironment         : boolean,  -- Hook all functions in standard script Environment?
	LogMetamethods         : boolean,  -- Hook metamethods?
	LogRBXScriptSignals  : boolean?, -- Hook RBXScriptSignal methods? (Defaults to true)
	LuraphCompatibility    : boolean?, -- Enable Luraph compatibility mode? (Defaults to false)
	FilterInstanceIndex    : boolean?, -- Filter out instance index calls? (Defaults to false)
	PrettyPrint            : boolean?, -- Enable pretty printing of logs? (Defaults to true)
	ShowDebugIdForNilInstancesInsteadOfName : boolean?, -- Show DebugId for nil instances instead of their name? (Defaults to true)
	LogMetamethodFunctionFetches : boolean?, -- Log metamethod function fetches? (Defaults to true)
	SafetyNet : boolean?, -- Filter out improper method calls? (Defaults to true) (TURNING THIS OFF WILL LEAD TO DETECTIONS)
	EmbedFunctionsAsCode : boolean?, -- Embed functions as code? (Defaults to false)
}

local DefaultSessionConfiguration: SessionConfiguration = {
	LogEnvironment = true,
	LogMetamethods = true,
	LogRBXScriptSignals = true,
	LuraphCompatibility = false,
	FilterInstanceIndex = false,
	PrettyPrint = true,
	ShowDebugIdForNilInstancesInsteadOfName = true,
	LogMetamethodFunctionFetches = true,
	EmbedFunctionsAsCode = false,
	SafetyNet = true
}

type LogConstructorSet = {
	FunctionCall           : (Function: (...any?) -> ...any?, Args: { any? }, Return: { any? }, FunctionPath: string?) -> string,
	Namecall               : (Instance: Instance | {Instance: Instance, RBXScriptSignal: RBXScriptSignal}, Method: string, Args: { any? }, Return: { any? }) -> string,
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

-- this is so bad but wtv i just need it to work
local HookMgr = require("./modules/HookMgr.luau")
local Utils = require("./modules/Utils.luau")
local DataToCode = require("./modules/DataToCode.luau")
local EvaluateInstancePath = require("./modules/EvaluateInstancePath.luau")
local SafetyNet = require("./modules/SafetyNet.luau")

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
	local Result = DataToCode.Convert(
		x,
		#x > 1 and shared.Prettify
	)
	setthreadcontext(OldThreadContext)
	return Result
end

--#endregion

--#region Module

local Calligraph = {
	Version = "1.5.5",
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

		if typeof(Instance) == 'table' then
			-- The Instance is a custom call for RBXScriptSignals
			if typeof(Instance.RBXScriptSignal) == "RBXScriptSignal" then
				return string.format(
					-- game.RunService.RenderStepped:Connect(function() end)
					"%s.%s:%s(%s)",
					FormatInstancePath(Instance.Instance),
					tostring(Instance.RBXScriptSignal):gsub("Signal ", ""),
					Method,
					FormatCodeArgs(Args)
				)
			end
		end

		assert(typeof(Instance) == 'Instance') -- Make linter happy

		return string.format(
			"%s:%s(%s) --> %s",
			FormatInstancePath(Instance),
			Method,
			FormatCodeArgs(Args),
			LuaEncode(Return)
		)
	end,
	Index = function(Instance, Key, Return)
		-- Check if Return is a RBXScriptSignal
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
	Instance: Instance | {Instance: Instance, RBXScriptSignal: RBXScriptSignal},
	OldMethod: (...any?) -> ...any?
)

	if shared.ProxyLookup[OldMethod] then
		return shared.ProxyLookup[OldMethod]
	end

	shared.ProxyLookup[OldMethod] = newcclosure(function(...)
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
			return OldMethod(...)
		end
	end)

	return shared.ProxyLookup[OldMethod]
end

-- i hate this
function Calligraph.NewFunctionProxy(
	Session: Session,
	Formatter: LogConstructorSet,
	Function: (...any?) -> ...any?,
	FunctionPath: string?
)

	if shared.ProxyLookup[Function] then
		return shared.ProxyLookup[Function]
	end

	shared.ProxyLookup[Function] = function(Old, ...)
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

	return shared.ProxyLookup[Function]
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
	shared.EmbedFunctionsAsCode = (Configuration.EmbedFunctionsAsCode == true)

	local Session: Session
	local LogFormatter: LogConstructorSet = CodeLogConstructors
	local LastLogContent: string = ""
	local RepeatCount: number = 0

	local GameMetamethods = {
		[HookMgr.GameMT.__index] = {Name = "__index", ExpectedArguments = 2},
		[HookMgr.GameMT.__newindex] = {Name = "__newindex", ExpectedArguments = 3},
		[HookMgr.GameMT.__namecall] = {Name = "__namecall", ExpectedArguments = math.huge}
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
			
			local OldThreadContext = getthreadcontext()
			setthreadcontext(8)

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

			setthreadcontext(OldThreadContext)

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
	Session.Log(`Log format: Luau Code`)
	Session.Log("[SYSTEM] Calligraph is now active. All logs will be recorded.")

	if Session.Configuration.LogMetamethods then
		shared.DirectCall.__index = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__index`,
			HookMgr.GameMT.__index,
			function(Old, ...)
				if checkcaller() then
					return Old(...)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(...)
				end

				local IsValid, Message = SafetyNet.ValidateMetamethodCall("__index", "Instance", ...)

				if not IsValid then
					task.spawn(Session.Log, string.format("[!!!] SafetyNet triggered! [__index] %s", Message))
					return Old(...)
				end

				-- Now that we have validated the call, we can trust the arguments.
				local Self, Index = ...

				local Return = Old(Self, Index)

				if not (Session.Configuration.LuraphCompatibility == true and type(Return) == "function") then
					if not (Session.Configuration.FilterInstanceIndex == true and typeof(Return) == "Instance") then
						task.spawn(function()
							Session.Log(LogFormatter.Index(Self, Index, { Return }))
						end)
					end
				end

				if typeof(Return) == "function" then
					return Calligraph.NewMethodProxy(Session, LogFormatter, Index, Self, Return)
				elseif typeof(Return) == "RBXScriptSignal" then
					print('dbg, hit rbxscriptsignal idx ret, logging to lookup')
					shared.RBXScriptSignalLookupTable[Return] = Self
					print('dbg, ckpt2')
				end

				return Return
			end
		)

		shared.DirectCall.__newindex = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__newindex`,
			HookMgr.GameMT.__newindex,
			function(Old, ...)
				if checkcaller() then
					return Old(...)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(...)
				end

				local IsValid, Message = SafetyNet.ValidateMetamethodCall("__newindex", "Instance", ...)

				if not IsValid then
					task.spawn(Session.Log, string.format("[!!!] SafetyNet triggered! [__newindex] %s", Message))
					return Old(...)
				end

				-- Now that we have validated the call, we can trust the arguments.
				local Self, Index, Value = ...

				task.spawn(function()
					Session.Log(LogFormatter.NewIndex(Self, Index, Value))
				end)

				return Old(Self, Index, Value)
			end
		)

		shared.DirectCall.__namecall = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__namecall`,
			HookMgr.GameMT.__namecall,
			function(Old, ...)
				if checkcaller() then
					return Old(...)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(...)
				end

				local IsValid, Message = SafetyNet.ValidateMetamethodCall("__namecall", "Instance", ...)

				if not IsValid then
					task.spawn(Session.Log, string.format("[!!!] SafetyNet triggered! [__namecall] %s", Message))
					return Old(...)
				end

				local Args = {...}
				local Self = table.remove(Args, 1) :: Instance
				local Method = getnamecallmethod()
				local Return = { Old(...) }

				task.spawn(function()
					Session.Log(LogFormatter.Namecall(Self, Method, Args, Return))
				end)

				return table.unpack(Return)
			end
		)
	end

	if Session.Configuration.LogRBXScriptSignals then

		local RBXScriptSignalMetatable = getrawmetatable(workspace.ChildAdded)

		local ConnectionKeys = {
			["Connect"] = true,
			["connect"] = true,
			["ConnectParallel"] = true,
			["Once"] = true,
		}

		shared.DirectCall['RBXScriptSignal.__index'] = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:RBXScriptSignal.__index`,
			RBXScriptSignalMetatable.__index,
			function(Old, ...)
				if checkcaller() then
					return Old(...)
				end

				local CallSource = DebugInfo(4, "s")

				if not table.find(Session.Targets, CallSource) then
					return Old(...)
				end

				print('dbg, scriptsignal idx', ...)

				local IsValid, Message = SafetyNet.ValidateMetamethodCall("__index", "RBXScriptSignal", ...)

				if not IsValid then
					task.spawn(Session.Log, string.format("[!!!] SafetyNet triggered! [__index] %s", Message))
					return Old(...)
				end

				local Self, Index = ...

				if ConnectionKeys[Index] then
					
					print('dbg, hit connectionkey idx, returning methodproxy')

					local ConnectionFunction = Old(...)

					return Calligraph.NewMethodProxy(Session, LogFormatter, Index, {Instance = shared.RBXScriptSignalLookupTable[Self], RBXScriptSignal = Self}, ConnectionFunction)
				end

				-- If we reach here, it's not a connection function.
				-- We can safely return the original function.
				return Old(...)
			end
		)
	end

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
				
				for i = 1, ReturnN do
					local Value = Return[i]

					-- print('[dbg] Checking if debug.info return value is a metamethod', Value)

					-- doesnt do anything in this context
					if 
						typeof(Value) == "function" and
						iscclosure(Value) and
						GameMetamethods[Value]
					then
						-- print('[dbg] Found metamethod function:', Value)
						task.spawn(Session.Log, string.format("[!!!] Raw %s function fetched: %s", GameMetamethods[Value].Name, tostring(Value)))
					end
				end
				
			end
			
			return Old(...) -- doublecall but whatever i cant be assed to recreate the errors
		end)

		DebugInfo = shared.DirectCall.DebugInfo.Original
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
			-- ["type"] = true,
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
