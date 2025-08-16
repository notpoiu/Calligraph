# Calligraph

Calligraph is a library used for performing dynamic analysis on obfuscated Luau scripts in the Roblox engine.
It is still in very early development, expect many breaking changes and bugs, open to PRs.

# Usage

```lua
local CalligraphModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/centerepic/Calligraph/refs/heads/main/compiled/Calligraph.luau"))()
local Target = `Players.{game.Players.LocalPlayer.Name}.PlayerScripts.RbxCharacterSounds`
local LogFile = "Calligraph_Demo.txt"

-- Configure and initialize a new Calligraph session.
print("Initializing Calligraph session...")
local Session = CalligraphModule:NewSession(
	{ Target }, -- List of targets, value is obtained from calling debug.info(..., 's') on a target script function.
	{
		LogEnvironment = false,  -- Log calls to global functions
		LogMetamethods = true,  -- Log calls like :GetChildren(), .Name
		LogAsCode = true,       -- Generate Luau code instead of JSON
		LuraphCompatability = true, -- Filters out junk calls from Luraph
		FilterInstanceIndex = true -- Filters out indexes that return instances as they are usually redundant
	}
)

print(`Session active. Target: "{Target}". Logging to "{LogFile}".`)

-- Let the test run for a while to capture events.
task.wait(20)

-- Close the session to finalize the log file and unhook everything.
print("Closing Calligraph session.")
Session:Close()
Session:SaveToFile(LogFile)
```

# Compilation with DarkLua

- Run compile.bat and check compiled folder