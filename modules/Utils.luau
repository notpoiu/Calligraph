-- Utility library for Calligraph

local Utils = {}

--[[ 
    GetReturnData: Safely executes a function and returns its data.
    This function wraps the execution of a given function in a pcall to handle errors gracefully.
    @param Function: The function to execute.
    @param ...: The arguments to pass to the function.
    @return: The return data from the function or an error message.
]]
function Utils.GetReturnData(Function : (...any?) -> (...any?), ...)
    local Results = table.pack(pcall(Function, ...))
    local ArgsN = Results.n - 1
    
    -- Remove Args.n now
    if Results.n then
        Results.n = nil
    end

    return table.remove(Results, 1), Results, ArgsN
end

return Utils