-- Calligraph | sashaa169 / centerepic
-- This is a module designed to provide a simple way to log all high-level interactions with instances in Roblox from a specific script.
-- Usually used for aiding in dissassembly and debugging of obfuscated scripts.
-- It is highly reccomended to run this in auto-exec as it cannot capture calls made before it is loaded.

--!strict

shared.DirectCall = {}

--#region Types

type SessionConfiguration = {
	LogEnvironment: boolean, -- Hook all functions in standard script Environment?
	LogMetamethods: boolean, -- Hook metamethods?
	LogAsCode: boolean?, -- Log as executable Luau code instead of JSON? (Defaults to false)
	LuraphCompatibility: boolean?, -- Enable Luraph compatibility mode? (Defaults to false)
	FilterInstanceIndex: boolean?, -- Filter out instance index calls? (Defaults to false)
}

-- This new type defines the required shape for any log constructor table.
type LogConstructorSet = {
	FunctionCall: (Function: (...any?) -> ...any?, Args: { any? }, Return: { any? }) -> string,
	Namecall: (Instance: Instance, Method: string, Args: { any? }, Return: { any? }) -> string,
	Index: (Instance: Instance, Key: string, Return: { any? }) -> string,
	NewIndex: (Instance: Instance, Key: string, Value: any) -> string,
}

type Session = {
	Configuration: SessionConfiguration,
	Targets: { string },
	Data: buffer,
	Written: number,
	Start: number,
	End: number,
	Close: () -> (),
	GUID: string,
	Log: (LogString: string) -> (),
	Active: boolean,
	SaveToFile: (self: Session, FileName: string) -> (),
}

--#endregion

--#region Imports

local HttpService = game:GetService("HttpService")
local LuaEncodeAndEvaluateInstancePath = require("./modules/LuaEncode.luau")
local LuaEncode, EvaluateInstancePath =
	LuaEncodeAndEvaluateInstancePath.LuaEncode, LuaEncodeAndEvaluateInstancePath.EvaluateInstancePath
-- this is so bad but wtv i just need it to work
local HookMgr = require("./modules/HookMgr.luau")
local Utils = require("./modules/Utils.luau")
local JSONEncode = function(...): string
	if shared.DirectCall.__namecall then
		return shared.DirectCall.__namecall(HttpService, "JSONEncode", ...)
	else
		return HttpService:JSONEncode(...)
	end
end

--#endregion

--#region Definitions
local MAX_BUFFER_SIZE = 1024 * 1024 * 1024 -- 1 GiB
--#endregion

--#region Module

local Calligraph = {
	Version = "1.3.1",
}

-- Log Constructors for the JSON format
local JSONLogConstructors: LogConstructorSet = {
	FunctionCall = function(Function, Args, Return)
		return JSONEncode({
			Time = os.clock(),
			Type = "FunctionCall",
			Name = debug.info(Function, "n") or tostring(Function),
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

	if #Args > 0 and type(Args[#Args]) == "number" then
		table.remove(Args, #Args)
	end

	local Encoded = LuaEncode(Args)

	setthreadcontext(OldThreadContext)

	return string.sub(Encoded, 2, -2)
end

local function FormatInstancePath(Instance: Instance): string
	if not Instance then
		return "nil"
	end

	local Path = Instance:GetFullName()

	if Path == "" then
		-- idk how to rly handle nil instances yet
		return `nil...{Instance.Name}`
	end

	return EvaluateInstancePath(Instance)
end

local CodeLogConstructors: LogConstructorSet = {
	FunctionCall = function(Function, Args, Return)
		local FunctionName = debug.info(Function, "n") or "anonymous_function"
		return string.format("%s(%s) --> %s", FunctionName, FormatCodeArgs(Args), LuaEncode(Return))
	end,
	Namecall = function(Instance, Method, Args, Return)
		local CallArgs = {}

		for i, v in ipairs(Args) do -- ipairs to filter out the n=... value
			if i > 1 then -- skip self as it's already inferred to be a namecall
				table.insert(CallArgs, v)
			end
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
		return string.format("%s.%s --> %s", FormatInstancePath(Instance), Key, LuaEncode(Return))
	end,
	NewIndex = function(Instance, Key, Value)
		return string.format("%s.%s = %s", FormatInstancePath(Instance), Key, LuaEncode({ Value }))
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

-- i hate this
function Calligraph.NewFunctionProxy(Session: Session, Formatter: LogConstructorSet, Function: (...any?) -> ...any?)
	local Wrapped = iscclosure(Function)
	return Wrapped
			and newcclosure(function(...)
				if checkcaller() then
					return Function(...)
				end
				local CallSource = debug.info(4, "s")
				if not table.find(Session.Targets, CallSource) then
					return Function(...)
				end
				local Args = { ... }
				local Success, Return, ArgsN = Utils.GetReturnData(Function, ...)
				local ReturnFormatted = Success and Return or { ["error"] = Return[1] }
				task.spawn(function()
					Session.Log(Formatter.FunctionCall(Function, Args, ReturnFormatted))
				end)
				if Success then
					return table.unpack(Return, 1, ArgsN)
				else
					return error(Return[1])
				end
			end)
		or function(...)
			if checkcaller() then
				return Function(...)
			end
			local CallSource = debug.info(4, "s")
			if not table.find(Session.Targets, CallSource) then
				return Function(...)
			end
			local Args = { ... }
			local Success, Return, ArgsN = Utils.GetReturnData(Function, ...)
			local ReturnFormatted = Success and Return or { ["error"] = Return[1] }
			task.spawn(function()
				Session.Log(Formatter.FunctionCall(Function, Args, ReturnFormatted))
			end)
			if Success then
				return table.unpack(Return, 1, ArgsN)
			else
				return error(Return[1])
			end
		end
end

function Calligraph:NewSession(Targets: { string }, Configuration: SessionConfiguration)
	local Session: Session
	local LogFormatter: LogConstructorSet = (Configuration.LogAsCode == true) and CodeLogConstructors
		or JSONLogConstructors

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
		end,
		Log = function(LogString: string)
			if not Session.Active then
				return
			end
			local FormattedLog = string.format(`[%s] %s\n`, os.date("%Y-%m-%d %H:%M:%S"), LogString)
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
		end,
		SaveToFile = function(self: Session, FileName: string)
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

	if Session.Configuration.LogMetamethods then
		shared.DirectCall.__index = HookMgr.RegisterHook(
			`Calligraph:{Session.GUID}:__index`,
			HookMgr.GameMT.__index,
			function(Old, Self, Index)
				if checkcaller() then
					return Old(Self, Index)
				end

				local CallSource = debug.info(4, "s")

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

				local CallSource = debug.info(4, "s")

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

				local CallSource = debug.info(4, "s")

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

	local Blacklist = {
		["rawget"] = true,
		["rawset"] = true,
	}

	if Session.Configuration.LogEnvironment and getrenv then
		for FunctionName, Function in pairs(getrenv()) do
			if type(Function) == "function" and type(FunctionName) == "string" and FunctionName ~= "" then
				if not Blacklist[FunctionName] then
					HookMgr.RegisterHook(
						`Calligraph:{Session.GUID}:FunctionCall:` .. FunctionName,
						Function,
						Calligraph.NewFunctionProxy(Session, LogFormatter, Function)
					)
				end
			end
		end
	end

	return Session
end

return Calligraph

--#endregion
