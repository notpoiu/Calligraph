local __DARKLUA_BUNDLE_MODULES

__DARKLUA_BUNDLE_MODULES = {
    cache = {},
    load = function(m)
        if not __DARKLUA_BUNDLE_MODULES.cache[m] then
            __DARKLUA_BUNDLE_MODULES.cache[m] = {
                c = __DARKLUA_BUNDLE_MODULES[m](),
            }
        end

        return __DARKLUA_BUNDLE_MODULES.cache[m].c
    end,
}

do
    function __DARKLUA_BUNDLE_MODULES.a()
        local table, string, next, pcall, game, workspace, tostring, tonumber, getmetatable = table, string, next, pcall, game, workspace, tostring, tonumber, getmetatable
        local string_format = string.format
        local string_char = string.char
        local string_gsub = string.gsub
        local string_match = string.match
        local string_rep = string.rep
        local string_sub = string.sub
        local string_gmatch = string.gmatch
        local table_concat = table.concat
        local Type = typeof or type

        local function LookupTable(array)
            local Out = {}

            for _, Value in next, array do
                Out[Value] = true
            end

            return Out
        end

        local LuaKeywords = LookupTable({
            'and',
            'break',
            'do',
            'else',
            'elseif',
            'end',
            'false',
            'for',
            'function',
            'if',
            'in',
            'local',
            'nil',
            'not',
            'or',
            'repeat',
            'return',
            'then',
            'true',
            'until',
            'while',
            'continue',
        })
        local KeyIndexTypes = LookupTable({
            'number',
            'string',
            'boolean',
            'Enum',
            'EnumItem',
            'Enums',
        })

        local function CheckType(inputData, dataName, ...)
            local ValidTypes = LookupTable({...})
            local InputType = Type(inputData)

            if not ValidTypes[InputType] then
                error(string_format('LuaEncode: Incorrect type for `%s`: `%s` expected, got `%s`', dataName, table_concat(ValidTypes, ', '), InputType), 0)
            end

            return inputData
        end

        local SerializeString

        do
            local SpecialCharacters = {
                ['"'] = '\\"',
                ['\\'] = '\\\\',
                ['\a'] = '\\a',
                ['\b'] = '\\b',
                ['\t'] = '\\t',
                ['\n'] = '\\n',
                ['\v'] = '\\v',
                ['\f'] = '\\f',
                ['\r'] = '\\r',
            }

            for Index = 0, 255 do
                local Character = string_char(Index)

                if not SpecialCharacters[Character] and (Index < 32 or Index > 126) then
                    SpecialCharacters[Character] = string_format('\\x%02X', Index)
                end
            end

            function SerializeString(inputString)
                return table_concat({
                    '"',
                    string_gsub(inputString, '[%z\\"\1-\31\127-\u{ff}]', SpecialCharacters),
                    '"',
                })
            end
        end

        local function CommentBlock(inputString)
            local Padding = ''

            for Match in string_gmatch(inputString, '%](=*)%]')do
                if #Match >= #Padding then
                    Padding = Match .. '='
                end
            end

            return '--[' .. Padding .. '[' .. inputString .. ']' .. Padding .. ']'
        end

        local EvaluateInstancePath

        do
            local function IsService(object)
                local FindServiceSuccess, ServiceObject = pcall(game.FindService, game, object.ClassName)

                if FindServiceSuccess and ServiceObject then
                    return true
                end

                return false
            end

            function EvaluateInstancePath(object)
                local ObjectPointer = object

                if not ObjectPointer then
                    return
                end

                local Path = ''

                while ObjectPointer do
                    local ObjectName = ObjectPointer.Name
                    local ObjectClassName = ObjectPointer.ClassName
                    local ObjectParent = ObjectPointer.Parent

                    if ObjectParent == game and IsService(ObjectPointer) then
                        Path = ':GetService(' .. SerializeString(ObjectClassName) .. ')' .. Path
                    elseif not LuaKeywords[ObjectName] and string_match(ObjectName, '^[A-Za-z_][A-Za-z0-9_]*$') then
                        Path = '.' .. ObjectName .. Path
                    else
                        Path = '[' .. SerializeString(ObjectName) .. ']' .. Path
                    end
                    if ObjectParent == game then
                        Path = 'game' .. Path

                        return Path
                    elseif ObjectParent == workspace then
                        Path = 'workspace' .. Path

                        return Path
                    end

                    ObjectPointer = ObjectParent
                end

                return
            end
        end

        local function LuaEncode(inputTable, options)
            options = options or {}

            CheckType(inputTable, 'inputTable', 'table')
            CheckType(options, 'options', 'table')
            CheckType(options.Prettify, 'options.Prettify', 'boolean', 'nil')
            CheckType(options.PrettyPrinting, 'options.PrettyPrinting', 'boolean', 'nil')
            CheckType(options.IndentCount, 'options.IndentCount', 'number', 'nil')
            CheckType(options.InsertCycles, 'options.InsertCycles', 'boolean', 'nil')
            CheckType(options.OutputWarnings, 'options.OutputWarnings', 'boolean', 'nil')
            CheckType(options.FunctionsReturnRaw, 'options.FunctionsReturnRaw', 'boolean', 'nil')
            CheckType(options.UseInstancePaths, 'options.UseInstancePaths', 'boolean', 'nil')
            CheckType(options.SerializeMathHuge, 'options.SerializeMathHuge', 'boolean', 'nil')
            CheckType(options._StackLevel, 'options._StackLevel', 'number', 'nil')
            CheckType(options._VisitedTables, 'options._VisitedTables', 'table', 'nil')

            local Prettify = (options.Prettify == nil and options.PrettyPrinting == nil and false) or (options.Prettify ~= nil and options.Prettify) or (options.PrettyPrinting and options.PrettyPrinting)
            local IndentCount = options.IndentCount or (Prettify and 4) or 0
            local InsertCycles = (options.InsertCycles == nil and false) or options.InsertCycles
            local OutputWarnings = (options.OutputWarnings == nil and true) or options.OutputWarnings
            local FunctionsReturnRaw = (options.FunctionsReturnRaw == nil and true) or options.FunctionsReturnRaw
            local UseInstancePaths = (options.UseInstancePaths == nil and true) or options.UseInstancePaths
            local SerializeMathHuge = (options.SerializeMathHuge == nil and true) or options.SerializeMathHuge
            local StackLevel = options._StackLevel or 1
            local VisitedTables = options._VisitedTables or {}
            local PositiveInf = (SerializeMathHuge and 'math.huge') or '1/0'
            local NegativeInf = (SerializeMathHuge and '-math.huge') or '-1/0'
            local NewEntryString = (Prettify and '\n') or ''
            local CodegenNewline = (Prettify and '\n') or ' '
            local ValueSeperator = (Prettify and ', ') or ','
            local BlankSeperator = (Prettify and ' ') or ''
            local EqualsSeperator = (Prettify and ' = ') or '='
            local IndentStringBase = string_rep(' ', IndentCount)
            local IndentString = nil
            local EndingIndentString = nil
            local KeyNumIndex = 1
            local TypeCases = {}

            do
                local function TypeCase(typeName, value)
                    local EncodedValue = TypeCases[typeName](value, false)

                    return EncodedValue
                end
                local function Args(...)
                    local EncodedValues = {}

                    for _, Arg in next, {...}do
                        EncodedValues[#EncodedValues + 1] = TypeCase(Type(Arg), Arg)
                    end

                    return table_concat(EncodedValues, ValueSeperator)
                end
                local function Params(newData, params)
                    return 
[[(function(v, p) for pn, pv in next, p do v[pn] = pv end return v end)(]] .. table_concat({
                        newData,
                        TypeCase('table', params),
                    }, ValueSeperator) .. ')'
                end

                TypeCases['number'] = function(value, isKey)
                    if isKey and value == KeyNumIndex then
                        KeyNumIndex = KeyNumIndex + 1

                        return nil, true
                    end
                    if value == 1 / 0 then
                        return PositiveInf
                    elseif value == -1 / 0 then
                        return NegativeInf
                    end

                    return string_format('%.14g', value)
                end
                TypeCases['string'] = function(value, isKey)
                    if isKey and not LuaKeywords[value] and string_match(value, '^[A-Za-z_][A-Za-z0-9_]*$') then
                        return value, true
                    end

                    return SerializeString(value)
                end
                TypeCases['table'] = function(value, isKey)
                    if VisitedTables[value] and OutputWarnings then
                        return '{--[[LuaEncode: Duplicate reference]]}'
                    end

                    local NewOptions = setmetatable({}, {__index = options})

                    do
                        NewOptions.Prettify = (isKey and false) or Prettify
                        NewOptions.IndentCount = (isKey and ((not Prettify and IndentCount) or 1)) or IndentCount
                        NewOptions._StackLevel = (isKey and 1) or StackLevel + 1
                        NewOptions._VisitedTables = VisitedTables
                    end

                    return LuaEncode(value, NewOptions)
                end
                TypeCases['boolean'] = function(value)
                    return value and 'true' or 'false'
                end
                TypeCases['nil'] = function(value)
                    return 'nil'
                end
                TypeCases['function'] = function(value)
                    if FunctionsReturnRaw then
                        return string_format('%s Name: %s', tostring(value), (debug.info(value, 'n') ~= '' and debug.info(value, 'n') or '<Anonymous Function>'))
                    end

                    return string_format('function()%sreturn end', (OutputWarnings and 
[=[ --[[LuaEncode: `options.FunctionsReturnRaw` false; can't serialize functions]] ]=]) or '')
                end
                TypeCases['Axes'] = function(value)
                    local EncodedArgs = {}
                    local EnumValues = {
                        ['Enum.Axis.X'] = value.X,
                        ['Enum.Axis.Y'] = value.Y,
                        ['Enum.Axis.Z'] = value.Z,
                    }

                    for EnumValue, IsEnabled in next, EnumValues do
                        if IsEnabled then
                            EncodedArgs[#EncodedArgs + 1] = EnumValue
                        end
                    end

                    return 'Axes.new(' .. table_concat(EncodedArgs, ValueSeperator) .. ')'
                end
                TypeCases['BrickColor'] = function(value)
                    return 'BrickColor.new(' .. (Prettify and TypeCase('string', value.Name)) or value.Number .. ')'
                end
                TypeCases['CFrame'] = function(value)
                    return 'CFrame.new(' .. Args(value:components()) .. ')'
                end
                TypeCases['CatalogSearchParams'] = function(value)
                    return Params('CatalogSearchParams.new()', {
                        SearchKeyword = value.SearchKeyword,
                        MinPrice = value.MinPrice,
                        MaxPrice = value.MaxPrice,
                        SortType = value.SortType,
                        CategoryFilter = value.CategoryFilter,
                        BundleTypes = value.BundleTypes,
                        AssetTypes = value.AssetTypes,
                    })
                end
                TypeCases['Color3'] = function(value)
                    return 'Color3.new(' .. Args(value.R, value.G, value.B) .. ')'
                end
                TypeCases['ColorSequence'] = function(value)
                    return 'ColorSequence.new(' .. TypeCase('table', value.Keypoints) .. ')'
                end
                TypeCases['ColorSequenceKeypoint'] = function(value)
                    return 'ColorSequenceKeypoint.new(' .. Args(value.Time, value.Value) .. ')'
                end
                TypeCases['DateTime'] = function(value)
                    return 'DateTime.fromUnixTimestamp(' .. value.UnixTimestamp .. ')'
                end
                TypeCases['DockWidgetPluginGuiInfo'] = function(value)
                    local ValueString = tostring(value)

                    return 'DockWidgetPluginGuiInfo.new(' .. Args(Enum.InitialDockState[string_match(ValueString, 'InitialDockState:(%w+)')], string_match(ValueString, 'InitialEnabled:(%w+)') == '1', string_match(ValueString, 'InitialEnabledShouldOverrideRestore:(%w+)') == '1', tonumber(string_match(ValueString, 'FloatingXSize:(%w+)')), tonumber(string_match(ValueString, 'FloatingYSize:(%w+)')), tonumber(string_match(ValueString, 'MinWidth:(%w+)')), tonumber(string_match(ValueString, 'MinHeight:(%w+)'))) .. ')'
                end
                TypeCases['Enum'] = function(value)
                    return 'Enum.' .. tostring(value)
                end
                TypeCases['EnumItem'] = function(value)
                    return tostring(value)
                end
                TypeCases['Enums'] = function(value)
                    return 'Enum'
                end
                TypeCases['Faces'] = function(value)
                    local EncodedArgs = {}
                    local EnumValues = {
                        ['Enum.NormalId.Top'] = value.Top,
                        ['Enum.NormalId.Bottom'] = value.Bottom,
                        ['Enum.NormalId.Left'] = value.Left,
                        ['Enum.NormalId.Right'] = value.Right,
                        ['Enum.NormalId.Back'] = value.Back,
                        ['Enum.NormalId.Front'] = value.Front,
                    }

                    for EnumValue, IsEnabled in next, EnumValues do
                        if IsEnabled then
                            EncodedArgs[#EncodedArgs + 1] = EnumValue
                        end
                    end

                    return 'Faces.new(' .. table_concat(EncodedArgs, ValueSeperator) .. ')'
                end
                TypeCases['FloatCurveKey'] = function(value)
                    return 'FloatCurveKey.new(' .. Args(value.Time, value.Value, value.Interpolation) .. ')'
                end
                TypeCases['Font'] = function(value)
                    return 'Font.new(' .. Args(value.Family, value.Weight, value.Style) .. ')'
                end
                TypeCases['Instance'] = function(value)
                    if UseInstancePaths then
                        local InstancePath = EvaluateInstancePath(value)

                        if InstancePath then
                            return InstancePath
                        end
                    end

                    return 'nil' .. BlankSeperator .. CommentBlock('Instance.new(' .. TypeCase('string', value.ClassName) .. ')')
                end
                TypeCases['NumberRange'] = function(value)
                    return 'NumberRange.new(' .. Args(value.Min, value.Max) .. ')'
                end
                TypeCases['NumberSequence'] = function(value)
                    return 'NumberSequence.new(' .. TypeCase('table', value.Keypoints) .. ')'
                end
                TypeCases['NumberSequenceKeypoint'] = function(value)
                    return 'NumberSequenceKeypoint.new(' .. Args(value.Time, value.Value, value.Envelope) .. ')'
                end
                TypeCases['OverlapParams'] = function(value)
                    return Params('OverlapParams.new()', {
                        FilterDescendantsInstances = value.FilterDescendantsInstances,
                        FilterType = value.FilterType,
                        MaxParts = value.MaxParts,
                        CollisionGroup = value.CollisionGroup,
                        RespectCanCollide = value.RespectCanCollide,
                    })
                end
                TypeCases['PathWaypoint'] = function(value)
                    return 'PathWaypoint.new(' .. Args(value.Position, value.Action, value.Label) .. ')'
                end
                TypeCases['PhysicalProperties'] = function(value)
                    return 'PhysicalProperties.new(' .. Args(value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight) .. ')'
                end
                TypeCases['Random'] = function()
                    return 'Random.new()'
                end
                TypeCases['Ray'] = function(value)
                    return 'Ray.new(' .. Args(value.Origin, value.Direction) .. ')'
                end
                TypeCases['RaycastParams'] = function(value)
                    return Params('RaycastParams.new()', {
                        FilterDescendantsInstances = value.FilterDescendantsInstances,
                        FilterType = value.FilterType,
                        IgnoreWater = value.IgnoreWater,
                        CollisionGroup = value.CollisionGroup,
                        RespectCanCollide = value.RespectCanCollide,
                    })
                end
                TypeCases['Rect'] = function(value)
                    return 'Rect.new(' .. Args(value.Min, value.Max) .. ')'
                end
                TypeCases['Region3'] = function(value)
                    local ValueCFrame = value.CFrame
                    local ValueSize = value.Size

                    return 'Region3.new(' .. Args(ValueCFrame * CFrame.new(-ValueSize / 2), ValueCFrame * CFrame.new(ValueSize / 2)) .. ')'
                end
                TypeCases['Region3int16'] = function(value)
                    return 'Region3int16.new(' .. Args(value.Min, value.Max) .. ')'
                end
                TypeCases['TweenInfo'] = function(value)
                    return 'TweenInfo.new(' .. Args(value.Time, value.EasingStyle, value.EasingDirection, value.RepeatCount, value.Reverses, value.DelayTime) .. ')'
                end
                TypeCases['RotationCurveKey'] = function(value)
                    return 'RotationCurveKey.new(' .. Args(value.Time, value.Value, value.Interpolation) .. ')'
                end
                TypeCases['UDim'] = function(value)
                    return 'UDim.new(' .. Args(value.Scale, value.Offset) .. ')'
                end
                TypeCases['UDim2'] = function(value)
                    return 'UDim2.new(' .. Args(value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset) .. ')'
                end
                TypeCases['Vector2'] = function(value)
                    return 'Vector2.new(' .. Args(value.X, value.Y) .. ')'
                end
                TypeCases['Vector2int16'] = function(value)
                    return 'Vector2int16.new(' .. Args(value.X, value.Y) .. ')'
                end
                TypeCases['Vector3'] = function(value)
                    return 'Vector3.new(' .. Args(value.X, value.Y, value.Z) .. ')'
                end
                TypeCases['Vector3int16'] = function(value)
                    return 'Vector3int16.new(' .. Args(value.X, value.Y, value.Z) .. ')'
                end
                TypeCases['userdata'] = function(value)
                    if getmetatable(value) ~= nil then
                        return 'newproxy(true)'
                    else
                        return 'newproxy()'
                    end
                end
            end

            local Output = {}
            local TablePointer = inputTable
            local NextKey = nil
            local IsNewTable = true
            local TableStack = {}
            local RefMaps = {
                [TablePointer] = '',
            }
            local CycleMaps = {}

            while TablePointer do
                StackLevel = #TableStack + 1
                IndentString = (Prettify and string_rep(IndentStringBase, StackLevel)) or IndentStringBase
                EndingIndentString = (#IndentString > 0 and string_sub(IndentString, 1, 
-IndentCount - 1)) or ''

                if IsNewTable then
                    Output[#Output + 1] = '{'
                elseif next(TablePointer, NextKey) == nil then
                    Output[#Output + 1] = NewEntryString .. EndingIndentString
                else
                    Output[#Output + 1] = ','
                end

                VisitedTables[TablePointer] = true

                local SkipStackPop = false

                for Key, Value in next, TablePointer, NextKey do
                    local KeyType = Type(Key)
                    local ValueType = Type(Value)
                    local ValueIsTable = ValueType == 'table'

                    if TypeCases[KeyType] and TypeCases[ValueType] then
                        if Prettify then
                            Output[#Output + 1] = NewEntryString .. IndentString
                        end

                        local ValueWasEncoded = false
                        local KeyEncodedSuccess, EncodedKeyOrError, DontEncloseKeyInBrackets = pcall(TypeCases[KeyType], Key, true)
                        local ValueEncodedSuccess, EncodedValueOrError

                        if not ValueIsTable then
                            ValueEncodedSuccess, EncodedValueOrError = pcall(TypeCases[ValueType], Value, false)
                        end
                        if KeyEncodedSuccess and (ValueIsTable or (ValueEncodedSuccess and EncodedValueOrError)) then
                            if EncodedKeyOrError then
                                if DontEncloseKeyInBrackets then
                                    Output[#Output + 1] = EncodedKeyOrError
                                else
                                    Output[#Output + 1] = table_concat({
                                        '[',
                                        EncodedKeyOrError,
                                        ']',
                                    })
                                end

                                Output[#Output + 1] = EqualsSeperator
                            end
                            if ValueIsTable then
                                local IndexPath

                                if InsertCycles and KeyIndexTypes[KeyType] and RefMaps[TablePointer] then
                                    if KeyType == 'string' and not LuaKeywords[Key] and string_match(Key, '^[A-Za-z_][A-Za-z0-9_]*$') then
                                        IndexPath = '.' .. Key
                                    else
                                        local EncodedKeyAsValue = TypeCases[KeyType](Key)

                                        IndexPath = table_concat({
                                            '[',
                                            EncodedKeyAsValue,
                                            ']',
                                        })
                                    end
                                end
                                if not VisitedTables[Value] then
                                    if IndexPath then
                                        RefMaps[Value] = RefMaps[TablePointer] .. IndexPath
                                    end

                                    TableStack[#TableStack + 1] = {TablePointer, Key, KeyNumIndex}
                                    TablePointer = Value
                                    NextKey = nil
                                    KeyNumIndex = 1
                                    IsNewTable = true
                                    SkipStackPop = true

                                    break
                                else
                                    EncodedValueOrError = string_format('{%s}', (OutputWarnings and '--[[LuaEncode: Duplicate reference]]') or '')

                                    if IndexPath then
                                        CycleMaps[IndexPath] = RefMaps[Value]
                                    end
                                end
                            end

                            Output[#Output + 1] = EncodedValueOrError
                            ValueWasEncoded = true
                        elseif OutputWarnings then
                            local ErrorMessage = string_format('LuaEncode: Failed to encode %s of data type %s: %s', (not KeyEncodedSuccess and 'key') or (not ValueEncodedSuccess and 'value') or 'key/value', ValueType, (not KeyEncodedSuccess and SerializeString(EncodedKeyOrError)) or (not ValueEncodedSuccess and SerializeString(EncodedValueOrError)) or '(Failed to get error message)')

                            Output[#Output + 1] = CommentBlock(ErrorMessage)
                        end
                        if next(TablePointer, Key) == nil then
                            Output[#Output + 1] = NewEntryString .. EndingIndentString
                        elseif ValueWasEncoded then
                            Output[#Output + 1] = ','
                        end
                    end
                end

                if not SkipStackPop then
                    Output[#Output + 1] = '}'

                    if #TableStack > 0 then
                        local TableUp = TableStack[#TableStack]

                        TableStack[#TableStack] = nil
                        TablePointer, NextKey, KeyNumIndex = TableUp[1], TableUp[2], TableUp[3]
                        IsNewTable = false
                    else
                        break
                    end
                end
            end

            if InsertCycles then
                local CycleMapsOut = {}

                for CycleIndex, CycleMap in next, CycleMaps do
                    CycleMapsOut[#CycleMapsOut + 1] = IndentString .. 't' .. CycleIndex .. EqualsSeperator .. 't' .. CycleMap .. CodegenNewline
                end

                if #CycleMapsOut > 0 then
                    return table_concat({
                        '(function(t)',
                        NewEntryString,
                        table_concat(CycleMapsOut),
                        NewEntryString,
                        IndentString,
                        'return t',
                        CodegenNewline,
                        'end)(',
                        table_concat(Output),
                        ')',
                    })
                end
            end

            return table_concat(Output)
        end

        return {
            LuaEncode = LuaEncode,
            EvaluateInstancePath = EvaluateInstancePath,
        }
    end
    function __DARKLUA_BUNDLE_MODULES.b()
        local HookMgr = {
            Registry = {},
            GameMT = {
                __namecall = function(self, ...) end,
                __index = function(self, Index: string) end,
                __newindex = function(self, Index: string, Value: any) end,
            },
        }

        if getrawmetatable then
            HookMgr.GameMT = getrawmetatable(game)
        end

        HookMgr.RegisterHook = function(
            HookName: string,
            FunctionReference: (...any) -> ...any,
            Hook: (Original:(...any) -> ...any, ...any) -> ...any
        ): {Original: (...any) -> ...any, Reference: (...any) -> ...any}
            local OriginalFunction: (...any) -> ...any
            local HookKey = 'HookMgr_Hook_' .. HookName
            local OriginalKey = 'HookMgr_Original_' .. HookName

            shared.HookRegistry = shared.HookRegistry or {}
            shared.HookRegistry[HookKey] = Hook

            local Success, Error = pcall(function()
                OriginalFunction = hookfunction(FunctionReference, loadstring(`return function(...) return shared.HookRegistry["{HookKey}"]( shared.HookRegistry["{OriginalKey}"], ... ) end`)())
            end)

            if not Success then
                warn('Failed to hook function:', HookName, 'Error:', Error)
            end

            local RegistryEntry = HookMgr.Registry[HookName]

            if RegistryEntry then
                restorefunction(RegistryEntry.Reference)
                warn('Hook for function', HookName, 'already exists. Overriding.')
            end

            shared.HookRegistry[OriginalKey] = OriginalFunction
            HookMgr.Registry[HookName] = {
                Original = OriginalFunction or FunctionReference,
                Reference = FunctionReference,
            }

            return HookMgr.Registry[HookName]
        end
        HookMgr.UnregisterHook = function(HookName: string)
            local RegistryEntry = HookMgr.Registry[HookName]

            if RegistryEntry then
                local Success, Error = pcall(function()
                    restorefunction(RegistryEntry.Reference)
                end)

                if not Success then
                    warn('Failed to unhook function:', HookName, 'Error:', Error)
                end
            else
                warn('Hook for function', HookName, 'does not exist.')
            end

            HookMgr.Registry[HookName] = nil
        end
        HookMgr.ClearHooks = function()
            for HookName, RegistryEntry in next, HookMgr.Registry do
                local Success, Error = pcall(function()
                    restorefunction(RegistryEntry.Reference)
                end)

                if not Success then
                    warn('Failed to unhook function:', HookName, 'Error:', Error)
                end
            end

            HookMgr.Registry = {}
        end

        return HookMgr
    end
    function __DARKLUA_BUNDLE_MODULES.c()
        local Utils = {}

        function Utils.GetReturnData(Function: (...any?) -> (...any?), ...)
            local Results = table.pack(pcall(Function, ...))
            local ArgsN = Results.n - 1

            if Results.n then
                Results.n = nil
            end

            return table.remove(Results, 1), Results, ArgsN
        end

        return Utils
    end
end

shared.DirectCall = {}

local MAX_BUFFER_SIZE = 1024 * 1024 * 1024

type SessionConfiguration = {LogEnvironment: boolean, LogMetamethods: boolean, LogAsCode: boolean?, LuraphCompatibility: boolean?, FilterInstanceIndex: boolean?, PrettyPrint: boolean?}

local DefaultSessionConfiguration: SessionConfiguration = {
    LogEnvironment = true,
    LogMetamethods = true,
    LogAsCode = true,
    LuraphCompatibility = false,
    FilterInstanceIndex = false,
    PrettyPrint = true,
}

type LogConstructorSet = {FunctionCall: (Function:(...any?) -> ...any?, Args:{any?}, Return:{any?}, FunctionPath:string?) -> string, Namecall: (Instance:Instance, Method:string, Args:{any?}, Return:{any?}) -> string, Index: (Instance:Instance, Key:string, Return:{any?}) -> string, NewIndex: (Instance:Instance, Key:string, Value:any) -> string}
type Session = {Configuration: SessionConfiguration, Targets: {string}, Data: buffer, Written: number, Start: number, End: number, Close: () -> (), GUID: string, Log: (LogString:string) -> (), Active: boolean, SaveToFile: (self:Session, FileName:string) -> ()}

local HttpService = game:GetService('HttpService')
local LuaEncodeAndEvaluateInstancePath = __DARKLUA_BUNDLE_MODULES.load('a')
local LuaEncodeCore, EvaluateInstancePath = LuaEncodeAndEvaluateInstancePath.LuaEncode, LuaEncodeAndEvaluateInstancePath.EvaluateInstancePath
local HookMgr = __DARKLUA_BUNDLE_MODULES.load('b')
local Utils = __DARKLUA_BUNDLE_MODULES.load('c')
local JSONEncode = function(...): string
    if shared.DirectCall.__namecall then
        return shared.DirectCall.__namecall(HttpService, 'JSONEncode', ...)
    else
        return HttpService:JSONEncode(...)
    end
end
local LuaEncode = function(x)
    return LuaEncodeCore(x, {
        Prettify = shared.Prettify,
    })
end
local Calligraph = {
    Version = '1.3.7',
}
local JSONLogConstructors: LogConstructorSet = {
    FunctionCall = function(Function, Args, Return, FunctionPath)
        return JSONEncode({
            Time = os.clock(),
            Type = 'FunctionCall',
            Name = FunctionPath or debug.info(Function, 'n') or tostring(Function),
            Args = LuaEncode(Args),
            Return = LuaEncode(Return),
        })
    end,
    Namecall = function(Instance, Method, Args, Return)
        return JSONEncode({
            Time = os.clock(),
            Type = 'Namecall',
            Instance = Instance:GetFullName(),
            Method = Method,
            Args = LuaEncode(Args),
            Return = LuaEncode(Return),
        })
    end,
    Index = function(Instance, Key, Return)
        return JSONEncode({
            Time = os.clock(),
            Type = 'Index',
            Instance = Instance:GetFullName(),
            Key = Key,
            Return = LuaEncode(Return),
        })
    end,
    NewIndex = function(Instance, Key, Value)
        return JSONEncode({
            Time = os.clock(),
            Type = 'NewIndex',
            Instance = Instance:GetFullName(),
            Key = Key,
            Value = LuaEncode({Value}),
        })
    end,
}

local function FormatCodeArgs(Args: {any?}): string
    local OldThreadContext = getthreadcontext and getthreadcontext() or 1

    setthreadcontext(7)

    local Encoded = LuaEncode(Args)

    setthreadcontext(OldThreadContext)

    return string.sub(Encoded, 2, -2)
end
local function FormatInstancePath(Instance: Instance): string
    if not Instance then
        return 'nil'
    end

    local Path = Instance:GetFullName()

    if Path == '' then
        local OldContext = getthreadcontext()

        setthreadcontext(8)

        local NilInstanceString = `<Nil Instance | Name: {Instance.Name} | UniqueId: {Instance.UniqueId}>`

        setthreadcontext(OldContext)

        return NilInstanceString
    end

    return EvaluateInstancePath(Instance)
end

local CodeLogConstructors: LogConstructorSet = {
    FunctionCall = function(Function, Args, Return, FunctionPath)
        local FunctionName = FunctionPath or debug.info(Function, 'n') or 'anonymous_function'

        return string.format('%s(%s) --> %s', FunctionName, FormatCodeArgs(Args), LuaEncode(Return))
    end,
    Namecall = function(Instance, Method, Args, Return)
        local CallArgs = {}

        for i, v in ipairs(Args)do
            table.insert(CallArgs, v)
        end

        return string.format('%s:%s(%s) --> %s', FormatInstancePath(Instance), Method, FormatCodeArgs(CallArgs), LuaEncode(Return))
    end,
    Index = function(Instance, Key, Return)
        return string.format('%s.%s --> %s', FormatInstancePath(Instance), Key, LuaEncode(Return))
    end,
    NewIndex = function(Instance, Key, Value)
        return string.format('%s.%s = %s', FormatInstancePath(Instance), Key, LuaEncode({Value}))
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

        local Args = {...}
        local Success, Return, ArgsN = Utils.GetReturnData(OldMethod, ...)
        local ReturnFormatted = Success and Return or {
            ['error'] = Return[1],
        }

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

        local CallSource = debug.info(4, 's')

        if not table.find(Session.Targets, CallSource) then
            return Old(...)
        end

        local Args = {...}
        local Success, Return, ArgsN = Utils.GetReturnData(Old, ...)
        local ReturnFormatted = Success and Return or {
            ['error'] = Return[1],
        }

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
function Calligraph:NewSession(Targets: {string}, Configuration: SessionConfiguration)
    for Key, Value in next, DefaultSessionConfiguration do
        if Configuration[Key] == nil then
            Configuration[Key] = Value
        end
    end

    shared.Prettify = (Configuration.PrettyPrint == true)

    local Session: Session
    local LogFormatter: LogConstructorSet = (Configuration.LogAsCode == true) and CodeLogConstructors or JSONLogConstructors
    local LastLogContent: string = ''
    local RepeatCount: number = 0

    local function WriteToBuffer(FormattedLog: string)
        if Session.Written + #FormattedLog > MAX_BUFFER_SIZE then
            local FinalMsg = '[SYSTEM] Buffer full. Further logs will be ignored.\n'

            if Session.Written + #FinalMsg <= MAX_BUFFER_SIZE then
                buffer.writestring(Session.Data, Session.Written, FinalMsg)

                Session.Written += #FinalMsg
            end

            Session.Active = false

            warn('Calligraph: Log buffer is full. Logging has been stopped.')

            return
        end

        buffer.writestring(Session.Data, Session.Written, FormattedLog)

        Session.Written += #FormattedLog
    end
    local function FlushRepeatedLog()
        if RepeatCount > 1 then
            local Timestamp = os.date('%Y-%m-%d %H:%M:%S')
            local RepeatLog = string.format(`[%s] (Repeated x%d) %s\n`, Timestamp, RepeatCount, LastLogContent)

            WriteToBuffer(RepeatLog)
        elseif RepeatCount == 1 then
            local Timestamp = os.date('%Y-%m-%d %H:%M:%S')
            local SingleLog = string.format(`[%s] %s\n`, Timestamp, LastLogContent)

            WriteToBuffer(SingleLog)
        end

        RepeatCount = 0
        LastLogContent = ''
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

            Session.Log('Session ended at ' .. Session.End .. ' seconds.')

            Session.Active = false

            HookMgr.ClearHooks()
            FlushRepeatedLog()
        end,
        Log = function(LogString: string)
            if not Session.Active then
                return
            end

            local IsSystemMessage = string.match(LogString, '^%[SYSTEM%]') or string.match(LogString, '^Calligraph v') or string.match(LogString, '^Session') or string.match(LogString, '^Configuration:') or string.match(LogString, '^Targets:') or string.match(LogString, '^Log format:')

            if IsSystemMessage then
                FlushRepeatedLog()

                local FormattedLog = string.format(`[%s] %s\n`, os.date('%Y-%m-%d %H:%M:%S'), LogString)

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
                warn(
[[Calligraph: 'writefile/appendfile' is not available. Cannot save to file.]])

                return
            end

            local Success, Error: any = pcall(function()
                writefile(FileName, '')

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
                warn('Calligraph: Failed to save log to file. Error:', tostring(Error))
            else
                print('Calligraph: Successfully saved', self.Written, 'bytes to', FileName)
            end
        end,
    }

    Session.Log(`Calligraph v{Calligraph.Version}`)
    Session.Log('Session started at ' .. Session.Start .. ' seconds.')
    Session.Log('Session GUID: ' .. Session.GUID)
    Session.Log('Configuration: ' .. JSONEncode(Session.Configuration))
    Session.Log('Targets: ' .. table.concat(Session.Targets, ', '))
    Session.Log(`Log format: {Session.Configuration.LogAsCode and 'Luau Code' or 'JSON'}`)
    Session.Log(
[[[SYSTEM] Calligraph is now active. All logs will be recorded.]])

    if Session.Configuration.LogMetamethods then
        shared.DirectCall.__index = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:__index`, HookMgr.GameMT.__index, function(
            Old,
            Self,
            Index
        )
            if checkcaller() then
                return Old(Self, Index)
            end

            local CallSource = debug.info(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(Self, Index)
            end

            local Return = Old(Self, Index)

            if not (Session.Configuration.LuraphCompatibility == true and type(Return) == 'function') then
                if not (Session.Configuration.FilterInstanceIndex == true and typeof(Return) == 'Instance') then
                    task.spawn(function()
                        Session.Log(LogFormatter.Index(Self, Index, {Return}))
                    end)
                end
            end
            if type(Return) == 'function' and not checkcaller() then
                return Calligraph.NewMethodProxy(Session, LogFormatter, Index, Self, Return)
            end

            return Return
        end)
        shared.DirectCall.__newindex = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:__newindex`, HookMgr.GameMT.__newindex, function(
            Old,
            Self,
            Index,
            Value
        )
            if checkcaller() then
                return Old(Self, Index, Value)
            end

            local CallSource = debug.info(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(Self, Index, Value)
            end

            task.spawn(function()
                Session.Log(LogFormatter.NewIndex(Self, Index, Value))
            end)

            return Old(Self, Index, Value)
        end)
        shared.DirectCall.__namecall = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:__namecall`, HookMgr.GameMT.__namecall, function(
            Old,
            Self,
            ...
        )
            if checkcaller() then
                return Old(Self, ...)
            end

            local CallSource = debug.info(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(Self, ...)
            end

            local Args = {...}
            local Method = getnamecallmethod()
            local Return = {
                Old(Self, ...),
            }

            task.spawn(function()
                Session.Log(LogFormatter.Namecall(Self, Method, Args, Return))
            end)

            return table.unpack(Return)
        end)
    end
    if Session.Configuration.LogEnvironment and getrenv then
        local Whitelist = {
            ['require'] = true,
            ['tostring'] = true,
            ['tonumber'] = true,
            ['typeof'] = true,
            ['tick'] = true,
            ['t_Random'] = true,
            ['t_os'] = true,
            ['t_math'] = true,
            ['t_task'] = true,
        }
        local Blacklist = {
            ['t_task.wait'] = true,
        }

        local function HookTableFunctions(
            TargetTable: {[string]: any},
            PathPrefix: string
        )
            for Name, Value in pairs(TargetTable)do
                if type(Value) == 'function' then
                    local FullPath = if PathPrefix ~= ''then PathPrefix .. '.' .. Name else Name

                    if Blacklist['t_' .. FullPath] then
                        continue
                    end

                    HookMgr.RegisterHook(`Calligraph:{Session.GUID}:FunctionCall:` .. FullPath, Value, Calligraph.NewFunctionProxy(Session, LogFormatter, Value, FullPath))
                end
            end
        end
        local function ScanAndHookWhitelisted(TargetTable: {[string]: any})
            for Name, Value in pairs(TargetTable)do
                if type(Name) ~= 'string' then
                    continue
                end
                if Whitelist[Name] and type(Value) == 'function' then
                    if Blacklist[Name] then
                        continue
                    end

                    HookMgr.RegisterHook(`Calligraph:{Session.GUID}:FunctionCall:` .. Name, Value, Calligraph.NewFunctionProxy(Session, LogFormatter, Value, Name))
                elseif Whitelist['t_' .. Name] and type(Value) == 'table' then
                    HookTableFunctions(Value, Name)
                end
            end
        end

        ScanAndHookWhitelisted(getrenv())
    end

    return Session
end

return Calligraph
