local function LookupTable(array)
    local Out = {}
    for _, Value in next, array do
        Out[Value] = true
    end

    return Out
end

-- Used for checking direct getfield syntax; Lua keywords can't be used as keys without being a str
-- FYI; `continue` is Luau only (in Lua it's actually a global function)
local LuaKeywords = LookupTable({
    "and", "break", "do", "else",
    "elseif", "end", "false", "for",
    "function", "if", "in", "local",
    "nil", "not", "or", "repeat",
    "return", "then", "true", "until",
    "while", "continue"
})

-- This re-serializes a string back into Lua, for the interpreter AND humans to read. This fixes
-- `string_format("%q")` only outputting in system encoding, instead of explicit Lua byte escapes
local SerializeString do
    -- These are control characters to be encoded in a certain way in Lua rather than just a byte escape
    local SpecialCharacters = {
        ["\""] = "\\\"",
        ["\\"] = "\\\\",
        -- Special ASCII control char codes
        ["\a"] = "\\a",
        ["\b"] = "\\b",
        ["\t"] = "\\t",
        ["\n"] = "\\n",
        ["\v"] = "\\v",
        ["\f"] = "\\f",
        ["\r"] = "\\r",
    }

    -- We need to assign all extra normal byte escapes for runtime optimization
    for Index = 0, 255 do
        local Character = string.char(Index)

        if not SpecialCharacters[Character] and (Index < 32 or Index > 126) then
            SpecialCharacters[Character] = string.format("\\x%02X", Index)
        end
    end

    function SerializeString(inputString)
        -- FYI; We can't do "\0-\31" in Lua 5.1 (Only Luau/Lua 5.2+) due to an embedded zeros in pattern
        -- issue. See: https://stackoverflow.com/a/22962409
        return table.concat({ '"', string.gsub(inputString, "[%z\\\"\1-\31\127-\255]", SpecialCharacters), '"' })
    end
end

local EvaluateInstancePath do
    local function IsService(object)
        -- Logically, if an object is actually under a service, that service *has* to already exist, as we've
        -- presumably evaluated to said path
        local FindServiceSuccess, ServiceObject = pcall(game.FindService, game, object.ClassName)
        if FindServiceSuccess and ServiceObject then
            return true
        end

        return false
    end

    -- Evaluates an instances' accessable "path" with just it's ref, and if the root parent is nil/isn't
    -- under `game` or `workspace`, returns nil.
    function EvaluateInstancePath(object)
        local ObjectPointer = object

        if object == game then
            return "game"
        elseif object == workspace then
            return "workspace"
        end

        -- Input itself doesn't exist?
        if not ObjectPointer then
            return "nil"
        end

        local Path = ""

        while ObjectPointer do
            local ObjectName = ObjectPointer.Name
            local ObjectClassName = ObjectPointer.ClassName
            local ObjectParent = ObjectPointer.Parent

            if ObjectParent == game and IsService(ObjectPointer) then
                -- ^^ Then we'll use GetService directly, since it's actually a service under the DataModel

                Path = ":GetService(" .. SerializeString(ObjectClassName) .. ")" .. Path
            elseif not LuaKeywords[ObjectName] and string.match(ObjectName, "^[A-Za-z_][A-Za-z0-9_]*$") then
                -- ^^ Like the string data type, this means means we can index the name directly in Lua
                -- without an explicit string
                Path = "." .. ObjectName .. Path
            else
                Path = "[" .. SerializeString(ObjectName) .. "]" .. Path
            end

            if ObjectParent == game then
                Path = "game" .. Path
                return Path
            elseif ObjectParent == workspace then
                Path = "workspace" .. Path
                return Path
            end

            -- Advance ObjectPointer, whether it exists or not (JUMPBACK)
            ObjectPointer = ObjectParent
        end

        -- Fall back to no ret.. Only objects parented under game/workspace will be serialized
        local OldThreadContext = getthreadcontext()
        setthreadcontext(8)
        local NilInstanceString = `<{object.ClassName}`
		if shared.UseDebugId then
			NilInstanceString ..= ` {object:GetDebugId()}>`
		else
			NilInstanceString ..= ` {object.Name}>`
		end
        setthreadcontext(OldThreadContext)

        return NilInstanceString
    end
end

return EvaluateInstancePath