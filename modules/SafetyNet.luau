local SafetyNet = {}

-- this is basically just synapse argguard ngl

local GameMetamethods = {
    ['__index'] = {Name = "__index", ExpectedArguments = 2},
    ['__newindex'] = {Name = "__newindex", ExpectedArguments = 3},
    ['__namecall'] = {Name = "__namecall", ExpectedArguments = math.huge}
}

function SafetyNet.ValidateMetamethodCall(Metamethod : string, SelfType : string,  ...)
    local Args = table.pack(...)

    -- Validate arguments
    -- If arguments aren't valid, we don't want our hooks to run on them as they will trigger detections, reject them.

    local ExpectedArguments = GameMetamethods[Metamethod].ExpectedArguments

    if ExpectedArguments ~= math.huge then
        -- Check if the number of arguments is correct
        if Args.n ~= ExpectedArguments then
            return false, string.format("Expected %d arguments, got %d", ExpectedArguments, Args.n)
        end

        -- Check that the key is a string
        if typeof(Args[2]) ~= "string" then
            return false, string.format("Invalid key type! Expected (string), got (%s)", typeof(Args[2]))
        end

        -- Check that the value isn't a userdata
        if typeof(Args[3]) == "userdata" then
            return false, string.format("Invalid value type! Expected (not userdata), got (%s)", typeof(Args[3]))
        end
    else
        -- This is a __namecall, so it can have any number of arguments
        -- But it must have at least one argument (Self) to be valid.
        if Args.n < 1 then
            return false, string.format("Missing self argument! Expected (%s), got (none)", SelfType)
        end
    end

    -- Argument count checks passed, now let's validate self
    if typeof(Args[1]) ~= SelfType then
        return false, string.format("Wrong self type! Expected (%s), got (%s)", SelfType, typeof(Args[1]))
    end

    return true, "Valid"
end

return SafetyNet