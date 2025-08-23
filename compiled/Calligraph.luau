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
    function __DARKLUA_BUNDLE_MODULES.b()
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
    function __DARKLUA_BUNDLE_MODULES.c()
        local assert, type, typeof, rawset, getmetatable, tostring = assert, type, typeof, rawset, getmetatable, tostring
        local print, warn, pack, unpack, next = print, warn, table.pack, unpack, next
        local IsSharedFrozen, SharedSize = SharedTable.isFrozen, SharedTable.size
        local bufftostring, fromstring, readu8 = buffer.tostring, buffer.fromstring, buffer.readu8
        local isfrozen, concat = table.isfrozen, table.concat
        local info = debug.info
        local DefaultMethods = {}
        local Methods = setmetatable({}, {__index = DefaultMethods})
        local Class = {
            Methods = Methods,
            _tostringUnsupported = false,
            _Serializeinf = false,
            __VERSION = '1.0',
        }
        local Keywords = {
            ['local'] = '"local"',
            ['function'] = '"function"',
            ['and'] = '"and"',
            ['break'] = '"break"',
            ['not'] = '"not"',
            ['or'] = '"or"',
            ['else'] = '"else"',
            ['elseif'] = '"elseif"',
            ['if'] = '"if"',
            ['then'] = '"then"',
            ['until'] = '"until"',
            ['repeat'] = '"repeat"',
            ['while'] = '"while"',
            ['do'] = '"do"',
            ['for'] = '"for"',
            ['in'] = '"in"',
            ['end'] = '"end"',
            ['return'] = '"return"',
            ['true'] = '"true"',
            ['false'] = '"false"',
            ['nil'] = '"nil"',
        }
        local weakkeys = {
            __mode = 'k',
        }
        local islclosure = islclosure or function<func>(Function: func)
            return info(Function, 'l') ~= -1
        end
        local DefaultVectors, DefaultCFrames = {}, {}

        do
            local function ExtractTypes<Library>(
                DataTypeLibrary: Library,
                Path: string,
                DataType: string,
                Storage: {[any]: string}
            )
                for i, v in next, DataTypeLibrary do
                    if typeof(v) == DataType and not Storage[v] and type(i) == 'string' and not Keywords[i] or not i:match('[a-Z_][a-Z_0-9]') then
                        Storage[v] = Path .. '.' .. i
                    end
                end
            end

            ExtractTypes(vector, 'vector', 'Vector3', DefaultVectors)
            ExtractTypes(Vector3, 'Vector3', 'Vector3', DefaultVectors)
            ExtractTypes(CFrame, 'CFrame', 'CFrame', DefaultCFrames)

            Class.DefaultTypes = {
                Vector3 = DefaultVectors,
                CFrame = DefaultCFrames,
            }
        end

        local function Serialize<Type>(
            DataStructure: Type,
            format: boolean?,
            indents: string,
            CyclicList: {[{[any]: any?}]: boolean | nil}?,
            InComment: boolean?
        )
            local DataHandler = Methods[typeof(DataStructure)]

            return if DataHandler then DataHandler(DataStructure, format, indents, CyclicList, InComment)else'nil --[' .. (if InComment then''else'=') .. '[ Unsupported Data Type | ' .. typeof(DataStructure) .. (if not Class._tostringUnsupported then''else' | ' .. tostring(DataStructure)) .. ' ]' .. (if not InComment then''else'=') .. ']'
        end
        local function ValidateSharedTableIndex(Index: string)
            local IsKeyword = if type(Index) == 'number'then Index else Keywords[Index]

            if not IsKeyword then
                if Index ~= '' then
                    local IndexBuffer = fromstring(Index)
                    local FirstByte = readu8(IndexBuffer, 0)

                    if FirstByte >= 97 and FirstByte <= 122 or FirstByte >= 65 and FirstByte <= 90 or FirstByte == 95 then
                        for i = 1, #Index - 1 do
                            local Byte = readu8(IndexBuffer, i)

                            if not ((Byte >= 97 and Byte <= 122) or (Byte >= 65 and Byte <= 90) or Byte == 95 or (Byte >= 48 and Byte <= 57)) then
                                return '[' .. Methods.string(Index) .. '] = '
                            end
                        end

                        return Index .. ' = '
                    end

                    return '[' .. Methods.string(Index) .. '] = '
                end

                return '[""] = '
            end

            return '[' .. IsKeyword .. '] = '
        end
        local function ValidateIndex(Index: any)
            local IndexType = type(Index)
            local IsNumber = IndexType == 'number'

            if IsNumber or IndexType == 'string' then
                local IsKeyword = if IsNumber then Index else Keywords[Index]

                if not IsKeyword then
                    if Index ~= '' then
                        local IndexBuffer = fromstring(Index)
                        local FirstByte = readu8(IndexBuffer, 0)

                        if FirstByte >= 97 and FirstByte <= 122 or FirstByte >= 65 and FirstByte <= 90 or FirstByte == 95 then
                            for i = 1, #Index - 1 do
                                local Byte = readu8(IndexBuffer, i)

                                if not ((Byte >= 97 and Byte <= 122) or (Byte >= 65 and Byte <= 90) or Byte == 95 or (Byte >= 48 and Byte <= 57)) then
                                    return '[' .. Methods.string(Index) .. '] = '
                                end
                            end

                            return Index .. ' = '
                        end

                        return '[' .. Methods.string(Index) .. '] = '
                    end

                    return '[""] = '
                end

                return '[' .. IsKeyword .. '] = '
            end

            return '[' .. (if IndexType ~= 'table'then Serialize(Index, false, '')else'"<Table> (table: ' .. (if getmetatable(Index) == nil then tostring(Index):sub(8)else'@metatable') .. ')"') .. '] = '
        end

        function DefaultMethods.Axes(Axes: Axes)
            return 'Axes.new(' .. concat({
                if Axes.X then'Enum.Axis.X'else nil,
                if Axes.Y then'Enum.Axis.Y'else nil,
                if Axes.Z then'Enum.Axis.Z'else nil,
            }, ', ') .. ')'
        end
        function DefaultMethods.BrickColor(Color: BrickColor)
            return 'BrickColor.new(' .. Color.Number .. ')'
        end
        function DefaultMethods.CFrame(CFrame: CFrame)
            local Generation = DefaultCFrames[CFrame]

            if not Generation then
                local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = CFrame:GetComponents()
                local SerializeNumber = Methods.number

                return 'CFrame.new(' .. SerializeNumber(x) .. ', ' .. SerializeNumber(y) .. ', ' .. SerializeNumber(z) .. ', ' .. SerializeNumber(R00) .. ', ' .. SerializeNumber(R01) .. ', ' .. SerializeNumber(R02) .. ', ' .. SerializeNumber(R10) .. ', ' .. SerializeNumber(R11) .. ', ' .. SerializeNumber(R12) .. ', ' .. SerializeNumber(R20) .. ', ' .. SerializeNumber(R21) .. ', ' .. SerializeNumber(R22) .. ')'
            end

            return Generation
        end

        do
            local DefaultCatalogSearchParams = CatalogSearchParams.new()

            function DefaultMethods.CatalogSearchParams(
                Params: CatalogSearchParams,
                format: boolean?,
                indents: string
            )
                if DefaultCatalogSearchParams ~= Params then
                    local formatspace = if format then'\n' .. indents else' '
                    local SerializeString = Methods.string
                    local SearchKeyword = Params.SearchKeyword
                    local MinPrice = Params.MinPrice
                    local MaxPrice = Params.MaxPrice
                    local SortType = Params.SortType
                    local SortAggregation = Params.SortAggregation
                    local CategoryFilter = Params.CategoryFilter
                    local SalesTypeFilter = Params.SalesTypeFilter
                    local BundleTypes = Params.BundleTypes
                    local AssetTypes = Params.AssetTypes
                    local CreatorName = Params.CreatorName
                    local CreatorType = Params.CreatorType
                    local CreatorId = Params.CreatorId
                    local Limit = Params.Limit

                    return '(function(Param : CatalogSearchParams)' .. formatspace .. (if SearchKeyword ~= ''then'\tParam.SearchKeyword = ' .. SerializeString(SearchKeyword) .. formatspace else'') .. (if MinPrice ~= 0 then'\tParam.MinPrice = ' .. MinPrice .. formatspace else'') .. (if MaxPrice ~= 2147483647 then'\tParam.MaxPrice = ' .. MaxPrice .. formatspace else'') .. (if SortType ~= Enum.CatalogSortType.Relevance then'\tParam.SortType = Enum.CatalogSortType.' .. SortType.Name .. formatspace else'') .. (if SortAggregation ~= Enum.CatalogSortAggregation.AllTime then'\tParam.SortAggregation = Enum.CatalogSortAggregation.' .. SortAggregation.Name .. formatspace else'') .. (if CategoryFilter ~= Enum.CatalogCategoryFilter.None then'\tParam.CategoryFilter = Enum.CatalogCategoryFilter.' .. CategoryFilter.Name .. formatspace else'') .. (if SalesTypeFilter ~= Enum.SalesTypeFilter.All then'\tParam.SalesTypeFilter = Enum.SalesTypeFilter.' .. SalesTypeFilter.Name .. formatspace else'') .. (if#BundleTypes > 0 then'\tParam.BundleTypes = ' .. Methods.table(BundleTypes, false, '') .. formatspace else'') .. (if#AssetTypes > 0 then'\tParam.AssetTypes = ' .. Methods.table(AssetTypes, false, '') .. formatspace else'') .. (if Params.IncludeOffSale then'\tParams.IncludeOffSale = true' .. formatspace else'') .. (if CreatorName ~= ''then'\tParams.CreatorName = ' .. SerializeString(CreatorName) .. formatspace else'') .. (if CreatorType ~= Enum.CreatorTypeFilter.All then'\tParam.CreatorType = Enum.CreatorTypeFilter.' .. CreatorType.Name .. formatspace else'') .. (if CreatorId ~= 0 then'\tParams.CreatorId = ' .. CreatorId .. formatspace else'') .. (if Limit ~= 30 then'\tParams.Limit = ' .. Limit .. formatspace else'') .. '\treturn Params' .. formatspace .. 'end)(CatalogSearchParams.new())'
                end

                return 'CatalogSearchParams.new()'
            end
        end

        function DefaultMethods.Color3(Color: Color3)
            local SerializeNumber = Methods.number

            return 'Color3.new(' .. SerializeNumber(Color.R) .. ', ' .. SerializeNumber(Color.G) .. ', ' .. SerializeNumber(Color.B) .. ')'
        end
        function DefaultMethods.ColorSequence(Sequence: ColorSequence)
            local SerializeColorSequenceKeypoint = Methods.ColorSequenceKeypoint
            local Keypoints = Sequence.Keypoints
            local Size = #Keypoints
            local Serialized = ''

            for i = 1, Size - 1 do
                Serialized ..= SerializeColorSequenceKeypoint(Keypoints[i]) .. ', '
            end

            return 'ColorSequence.new({' .. Serialized .. SerializeColorSequenceKeypoint(Keypoints[Size]) .. '})'
        end
        function DefaultMethods.ColorSequenceKeypoint(KeyPoint: ColorSequenceKeypoint)
            return 'ColorSequenceKeypoint.new(' .. Methods.number(KeyPoint.Time) .. ', ' .. Methods.Color3(KeyPoint.Value) .. ')'
        end
        function DefaultMethods.Content(content: Content)
            local Uri = content.Uri

            return if Uri then'Content.fromUri(' .. Uri .. ')'else'Content.none'
        end
        function DefaultMethods.DateTime(Date: DateTime)
            return 'DateTime.fromUnixTimestampMillis(' .. Date.UnixTimestampMillis .. ')'
        end
        function DefaultMethods.DockWidgetPluginGuiInfo(Dock: DockWidgetPluginGuiInfo)
            local ArgumentFunction = tostring(Dock):gmatch(':([%w%-]+)')

            return 'DockWidgetPluginGuiInfo.new(Enum.InitialDockState.' .. ArgumentFunction() .. ', ' .. (if ArgumentFunction() == '1'then'true'else'false') .. ', ' .. (if ArgumentFunction() == '1'then'true'else'false') .. ', ' .. ArgumentFunction() .. ', ' .. ArgumentFunction() .. ', ' .. ArgumentFunction() .. ', ' .. ArgumentFunction() .. ')'
        end
        function DefaultMethods.Enum(Enum: Enum)
            return 'Enums.' .. tostring(Enum)
        end

        do
            local Enums = {}

            for i, v in Enum:GetEnums()do
                Enums[v] = 'Enum.' .. tostring(v)
            end

            function DefaultMethods.EnumItem(Item: EnumItem)
                return Enums[Item.EnumType] .. '.' .. Item.Name
            end
        end

        function DefaultMethods.Enums()
            return 'Enums'
        end
        function DefaultMethods.Faces(Faces: Faces)
            return 'Faces.new(' .. concat({
                if Faces.Top then'Enum.NormalId.Top'else nil,
                if Faces.Bottom then'Enum.NormalId.Bottom'else nil,
                if Faces.Left then'Enum.NormalId.Left'else nil,
                if Faces.Right then'Enum.NormalId.Right'else nil,
                if Faces.Back then'Enum.NormalId.Back'else nil,
                if Faces.Front then'Enum.NormalId.Front'else nil,
            }, ', ') .. ')'
        end
        function DefaultMethods.FloatCurveKey(CurveKey: FloatCurveKey)
            local SerializeNumber = Methods.number

            return 'FloatCurveKey.new(' .. SerializeNumber(CurveKey.Time) .. ', ' .. SerializeNumber(CurveKey.Value) .. ', Enum.KeyInterpolationMode.' .. CurveKey.Interpolation.Name .. ')'
        end
        function DefaultMethods.Font(Font: Font)
            return 'Font.new(' .. Methods.string(Font.Family) .. ', Enum.FontWeight.' .. Font.Weight.Name .. ', Enum.FontStyle.' .. Font.Style.Name .. ')'
        end

        do
            local Players = game:GetService('Players')
            local FindService = game.FindService
            local Services = {
                Workspace = 'workspace',
                Lighting = 'game.lighting',
                GlobalSettings = 'settings()',
                Stats = 'stats()',
                UserSettings = 'UserSettings()',
                PluginManagerInterface = 'PluginManager()',
                DebuggerManager = 'DebuggerManager()',
            }

            if game:GetService('RunService'):IsClient() then
                local LocalPlayer = Players.LocalPlayer

                if not LocalPlayer then
                    Players:GetPropertyChangedSignal('LocalPlayer'):Once(function(
                    )
                        LocalPlayer = Players.LocalPlayer
                    end)
                end

                function DefaultMethods.Instance(obj: Instance)
                    local ObjectParent = obj.Parent
                    local ObjectClassName = obj.ClassName

                    if ObjectParent then
                        local ObjectName = Methods.string(obj.Name)

                        if ObjectClassName ~= 'Model' and ObjectClassName ~= 'Player' then
                            local IsService, Output = pcall(FindService, game, ObjectClassName)

                            return if not (IsService and Output)then Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')'else Services[ObjectClassName] or 'game:GetService("' .. ObjectClassName .. '")'
                        elseif ObjectClassName == 'Model' then
                            local Player = Players:GetPlayerFromCharacter(obj)

                            return if not Player then Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')'else'game:GetService("Players")' .. (if Player == LocalPlayer then'.LocalPlayer.Character'else':WaitForChild(' .. ObjectName .. ').Character')
                        end

                        return 'game:GetService("Players")' .. (if obj == LocalPlayer then'.LocalPlayer'else':WaitForChild(' .. ObjectName .. ')')
                    end

                    return if ObjectClassName == 'DataModel'then'game'else'Instance.new("' .. ObjectClassName .. '", nil)'
                end
            else
                function DefaultMethods.Instance(obj: Instance)
                    local ObjectParent = obj.Parent
                    local ObjectClassName = obj.ClassName

                    if ObjectParent then
                        local ObjectName = Methods.string(obj.Name)

                        if ObjectClassName ~= 'Model' and ObjectClassName ~= 'Player' then
                            local IsService, Output = pcall(FindService, game, ObjectClassName)

                            return if not (IsService and Output)then Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')'else Services[ObjectClassName] or 'game:GetService("' .. ObjectClassName .. '")'
                        elseif ObjectClassName == 'Model' then
                            local Player = Players:GetPlayerFromCharacter(obj)

                            return if not Player then Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')'else'game:GetService("Players"):WaitForChild(' .. ObjectName .. ').Character'
                        end

                        return 'game:GetService("Players"):WaitForChild(' .. ObjectName .. ')'
                    end

                    return if ObjectClassName == 'DataModel'then'game'else'Instance.new("' .. ObjectClassName .. '", nil)'
                end
            end

            Class.Services = Services
        end

        function DefaultMethods.NumberRange(Range: NumberRange)
            local SerializeNumber = Methods.number

            return 'NumberRange.new(' .. SerializeNumber(Range.Min) .. ', ' .. SerializeNumber(Range.Max) .. ')'
        end
        function DefaultMethods.NumberSequence(Sequence: NumberSequence)
            local SerializeNumberSequenceKeypoint = Methods.NumberSequenceKeypoint
            local Keypoints = Sequence.Keypoints
            local Size = #Keypoints
            local Serialized = ''

            for i = 1, Size - 1 do
                Serialized ..= SerializeNumberSequenceKeypoint(Keypoints[i]) .. ', '
            end

            return 'NumberSequence.new({' .. Serialized .. SerializeNumberSequenceKeypoint(Keypoints[Size]) .. '})'
        end

        do
            local DefaultOverlapParams = OverlapParams.new()

            function DefaultMethods.OverlapParams(
                Params: OverlapParams,
                format: boolean?,
                indents: string
            )
                if DefaultOverlapParams ~= Params then
                    local formatspace = format and '\n' .. indents or ' '
                    local FilterDescendantsInstances = Params.FilterDescendantsInstances
                    local FilterType = Params.FilterType
                    local CollisionGroup = Params.CollisionGroup

                    return '(function(Param : OverlapParams)' .. formatspace .. (if#FilterDescendantsInstances > 0 then'\tParam.FilterDescendantsInstances = ' .. Methods.table(FilterDescendantsInstances, false, '') .. formatspace else'') .. (if FilterType ~= Enum.RaycastFilterType.Exclude then'\tParam.FilterType = Enum.RaycastFilterType.' .. FilterType.Name .. formatspace else'') .. (if CollisionGroup ~= 'Default'then'\tParam.CollisionGroup = ' .. Methods.string(CollisionGroup) .. formatspace else'') .. (if Params.RespectCanCollide then'\tParam.RespectCanCollide = true' .. formatspace else'') .. (if Params.BruteForceAllSlow then'\tParam.BruteForceAllSlow = true' .. formatspace else'') .. '\treturn Params' .. formatspace .. 'end)(OverlapParams.new())'
                end

                return 'OverlapParams.new()'
            end
        end

        function DefaultMethods.NumberSequenceKeypoint(Keypoint: NumberSequenceKeypoint)
            local SerializeNumber = Methods.number

            return 'NumberSequenceKeypoint.new(' .. SerializeNumber(Keypoint.Time) .. ', ' .. SerializeNumber(Keypoint.Value) .. ', ' .. SerializeNumber(Keypoint.Envelope) .. ')'
        end
        function DefaultMethods.PathWaypoint(Waypoint: PathWaypoint)
            return 'PathWaypoint.new(' .. Methods.Vector3(Waypoint.Position) .. ', Enum.PathWaypointAction.' .. Waypoint.Action.Name .. ', ' .. Methods.string(Waypoint.Label) .. ')'
        end

        do
            local function nanToString(num: number)
                return if num == num then num else'0/0'
            end

            function DefaultMethods.PhysicalProperties(Properties: PhysicalProperties)
                return 'PhysicalProperties.new(' .. (nanToString(Properties.Density)) .. ', ' .. nanToString(Properties.Friction) .. ', ' .. nanToString(Properties.Elasticity) .. ', ' .. nanToString(Properties.FrictionWeight) .. ', ' .. nanToString(Properties.ElasticityWeight) .. ')'
            end
        end

        function DefaultMethods.RBXScriptConnection(
            Connection: RBXScriptConnection,
            _,
            _,
            _,
            InComment: boolean?
        )
            local CommentSeperator = if not InComment then''else'='

            return '(nil --[' .. CommentSeperator .. '[ RBXScriptConnection | IsConnected: ' .. (if Connection.Connected then'true'else'false') .. ' ]' .. CommentSeperator .. '])'
        end

        do
            local Signals = {
                GraphicsQualityChangeRequest = 'game.GraphicsQualityChangeRequest',
                AllowedGearTypeChanged = 'game.AllowedGearTypeChanged',
                ScreenshotSavedToAlbum = 'game.ScreenshotSavedToAlbum',
                UniverseMetadataLoaded = 'game.UniverseMetadataLoaded',
                ScreenshotReady = 'game.ScreenshotReady',
                ServiceRemoving = 'game.ServiceRemoving',
                ServiceAdded = 'game.ServiceAdded',
                ItemChanged = 'game.ItemChanged',
                CloseLate = 'game.CloseLate',
                Loaded = 'game.Loaded',
                Close = 'game.Close',
                RobloxGuiFocusedChanged = 'game:GetService("RunService").RobloxGuiFocusedChanged',
                PostSimulation = 'game:GetService("RunService").PostSimulation',
                RenderStepped = 'game:GetService("RunService").RenderStepped',
                PreSimulation = 'game:GetService("RunService").PreSimulation',
                PreAnimation = 'game:GetService("RunService").PreAnimation',
                PreRender = 'game:GetService("RunService").PreRender',
                Heartbeat = 'game:GetService("RunService").Heartbeat',
                Stepped = 'game:GetService("RunService").Stepped',
            }

            function DefaultMethods.RBXScriptSignal(
                Signal: RBXScriptSignal,
                _,
                _,
                _,
                InComment: boolean?
            )
                local CommentSeperator = if not InComment then''else'='
                local SignalName = tostring(Signal):match('Signal ([A-z]+)')

                return Signals[SignalName] or '(nil --[' .. CommentSeperator .. '[ RBXScriptSignal | ' .. SignalName .. ' is not supported ]' .. CommentSeperator .. '])'
            end

            Class.Signals = Signals
        end

        function DefaultMethods.Random(_, _, _, _, InComment: boolean?)
            local CommentSeperator = if not InComment then''else'='

            return 'Random.new(--[' .. CommentSeperator .. '[ <Seed> ]' .. CommentSeperator .. '])'
        end
        function DefaultMethods.Ray(Ray: Ray)
            local SerializeVector3 = Methods.Vector3

            return 'Ray.new(' .. SerializeVector3(Ray.Origin) .. ', ' .. SerializeVector3(Ray.Direction) .. ')'
        end

        do
            local DefaultRaycastParams = RaycastParams.new()

            function DefaultMethods.RaycastParams(
                Params: RaycastParams,
                format: boolean?,
                indents: string
            )
                if DefaultRaycastParams ~= Params then
                    local formatspace = format and '\n' .. indents or ' '
                    local FilterDescendantsInstances = Params.FilterDescendantsInstances
                    local FilterType = Params.FilterType
                    local CollisionGroup = Params.CollisionGroup

                    return '(function(Param : RaycastParams)' .. formatspace .. (if#FilterDescendantsInstances > 0 then'\tParam.FilterDescendantsInstances = ' .. Methods.table(FilterDescendantsInstances, false, '') .. formatspace else'') .. (if FilterType ~= Enum.RaycastFilterType.Exclude then'\tParam.FilterType = Enum.RaycastFilterType.' .. FilterType.Name .. formatspace else'') .. (if Params.IgnoreWater then'\tParam.IgnoreWater = true' .. formatspace else'') .. (if CollisionGroup ~= 'Default'then'\tParam.CollisionGroup = ' .. Methods.string(CollisionGroup) .. formatspace else'') .. (if Params.RespectCanCollide then'\tParam.RespectCanCollide = true' .. formatspace else'') .. (if Params.BruteForceAllSlow then'\tParam.BruteForceAllSlow = true' .. formatspace else'') .. '\treturn Params' .. formatspace .. 'end)(RaycastParams.new())'
                end

                return 'RaycastParams.new()'
            end
        end

        function DefaultMethods.Rect(Rect: Rect)
            local SerializeVector2 = Methods.Vector2

            return 'Rect.new(' .. SerializeVector2(Rect.Min) .. ', ' .. SerializeVector2(Rect.Max) .. ')'
        end
        function DefaultMethods.Region3(Region: Region3)
            local SerializeVector3 = Methods.Vector3
            local Center = Region.CFrame.Position
            local Size = Region.Size / 2

            return 'Region3.new(' .. SerializeVector3(Center - Size) .. ', ' .. SerializeVector3(Center + Size) .. ')'
        end
        function DefaultMethods.Region3int16(Region: Region3int16)
            local SerializeVector3int16 = Methods.Vector3int16

            return 'Region3int16.new(' .. SerializeVector3int16(Region.Min) .. ', ' .. SerializeVector3int16(Region.Max) .. ')'
        end
        function DefaultMethods.RotationCurveKey(Curve: RotationCurveKey)
            return 'RotationCurveKey.new(' .. Methods.number(Curve.Time) .. ', ' .. Methods.CFrame(Curve.Value) .. ', Enum.KeyInterpolationMode.' .. Curve.Interpolation.Name .. ')'
        end
        function DefaultMethods.SharedTable(
            Shared: SharedTable,
            format: boolean?,
            indents: string,
            _,
            InComment: boolean?
        )
            local isreadonly = IsSharedFrozen(Shared)

            if SharedSize(Shared) ~= 0 then
                local stackindent = indents .. (if format then'\t'else'')
                local CurrentIndex = 1
                local Serialized = {}

                for i, v in Shared do
                    Serialized[CurrentIndex] = (if CurrentIndex ~= i then ValidateSharedTableIndex(i)else'') .. Serialize(v, format, stackindent, nil, InComment)

                    CurrentIndex += 1
                end

                local formatspace = if format then'\n'else''
                local Contents = formatspace .. stackindent .. concat(Serialized, (if format then',\n'else', ') .. stackindent) .. formatspace .. indents

                return if not isreadonly then'SharedTable.new({' .. Contents .. '})'else'SharedTable.cloneAndFreeze(SharedTable.new({' .. Contents .. '}))'
            end

            return if not isreadonly then'SharedTable.new()'else'SharedTable.cloneAndFreeze(SharedTable.new())'
        end
        function DefaultMethods.TweenInfo(Info: TweenInfo)
            return 'TweenInfo.new(' .. Methods.number(Info.Time) .. ', Enum.EasingStyle.' .. Info.EasingStyle.Name .. ', Enum.EasingDirection.' .. Info.EasingDirection.Name .. ', ' .. Info.RepeatCount .. ', ' .. (if Info.Reverses then'true'else'false') .. ', ' .. Methods.number(Info.DelayTime) .. ')'
        end
        function DefaultMethods.UDim(UDim: UDim)
            return 'UDim.new(' .. Methods.number(UDim.Scale) .. ', ' .. UDim.Offset .. ')'
        end
        function DefaultMethods.UDim2(UDim2: UDim2)
            local SerializeNumber = Methods.number
            local Width = UDim2.X
            local Height = UDim2.Y

            return 'UDim2.new(' .. SerializeNumber(Width.Scale) .. ', ' .. Width.Offset .. ', ' .. SerializeNumber(Height.Scale) .. ', ' .. Height.Offset .. ')'
        end
        function DefaultMethods.Vector2(Vector: Vector2)
            local SerializeNumber = Methods.number

            return 'Vector2.new(' .. SerializeNumber(Vector.X) .. ', ' .. SerializeNumber(Vector.Y) .. ')'
        end
        function DefaultMethods.Vector2int16(Vector: Vector2int16)
            return 'Vector2int16.new(' .. Vector.X .. ', ' .. Vector.Y .. ')'
        end
        function DefaultMethods.Vector3(Vector: Vector3)
            local SerializeNumber = Methods.number

            return DefaultVectors[Vector] or 'vector.create(' .. SerializeNumber(Vector.X) .. ', ' .. SerializeNumber(Vector.Y) .. ', ' .. SerializeNumber(Vector.Z) .. ')'
        end
        function DefaultMethods.Vector3int16(Vector: Vector3int16)
            return 'Vector3int16.new(' .. Vector.X .. ', ' .. Vector.Y .. ', ' .. Vector.Z .. ')'
        end
        function DefaultMethods.boolean(bool: boolean)
            return if bool then'true'else'false'
        end
        function DefaultMethods.buffer(buff: buffer)
            return 'buffer.fromstring(' .. Methods.string(bufftostring(buff)) .. ')'
        end

        do
            local GlobalFunctions = {}

            do
                local getrenv = getrenv or (function()
                    local env = {
                        bit32 = bit32,
                        buffer = buffer,
                        coroutine = coroutine,
                        debug = debug,
                        math = math,
                        os = os,
                        string = string,
                        table = table,
                        utf8 = utf8,
                        Content = Content,
                        Axes = Axes,
                        AdReward = AdReward,
                        BrickColor = BrickColor,
                        CatalogSearchParams = CatalogSearchParams,
                        CFrame = CFrame,
                        Color3 = Color3,
                        ColorSequence = ColorSequence,
                        ColorSequenceKeypoint = ColorSequenceKeypoint,
                        DateTime = DateTime,
                        DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo,
                        Faces = Faces,
                        FloatCurveKey = FloatCurveKey,
                        Font = Font,
                        Instance = Instance,
                        NumberRange = NumberRange,
                        NumberSequence = NumberSequence,
                        NumberSequenceKeypoint = NumberSequenceKeypoint,
                        OverlapParams = OverlapParams,
                        PathWaypoint = PathWaypoint,
                        PhysicalProperties = PhysicalProperties,
                        Random = Random,
                        Ray = Ray,
                        RaycastParams = RaycastParams,
                        Rect = Rect,
                        Region3 = Region3,
                        Region3int16 = Region3int16,
                        RotationCurveKey = RotationCurveKey,
                        SharedTable = SharedTable,
                        task = task,
                        TweenInfo = TweenInfo,
                        UDim = UDim,
                        UDim2 = UDim2,
                        Vector2 = Vector2,
                        Vector2int16 = Vector2int16,
                        Vector3 = Vector3,
                        vector = vector,
                        Vector3int16 = Vector3int16,
                        CellId = CellId,
                        PluginDrag = PluginDrag,
                        SecurityCapabilities = SecurityCapabilities,
                        assert = assert,
                        error = error,
                        getfenv = getfenv,
                        getmetatable = getmetatable,
                        ipairs = ipairs,
                        loadstring = loadstring,
                        newproxy = newproxy,
                        next = next,
                        pairs = pairs,
                        pcall = pcall,
                        print = print,
                        rawequal = rawequal,
                        rawget = rawget,
                        rawlen = rawlen,
                        rawset = rawset,
                        select = select,
                        setfenv = setfenv,
                        setmetatable = setmetatable,
                        tonumber = tonumber,
                        tostring = tostring,
                        unpack = unpack,
                        xpcall = xpcall,
                        collectgarbage = collectgarbage,
                        delay = delay,
                        gcinfo = gcinfo,
                        PluginManager = PluginManager,
                        DebuggerManager = DebuggerManager,
                        require = require,
                        settings = settings,
                        spawn = spawn,
                        tick = tick,
                        time = time,
                        UserSettings = UserSettings,
                        wait = wait,
                        warn = warn,
                        Delay = Delay,
                        ElapsedTime = ElapsedTime,
                        elapsedTime = elapsedTime,
                        printidentity = printidentity,
                        Spawn = Spawn,
                        Stats = Stats,
                        stats = stats,
                        Version = Version,
                        version = version,
                        Wait = Wait,
                    }

                    return function()
                        return env
                    end
                end)()
                local Visited = setmetatable({}, weakkeys)

                for i, v in getrenv()do
                    local ElementType = type(i) == 'string' and type(v)

                    if ElementType then
                        if ElementType == 'table' then
                            local function LoadLibrary(
                                Path: string,
                                tbl: {[string]: any}
                            )
                                if not Visited[tbl] then
                                    Visited[tbl] = true

                                    for i, v in next, tbl do
                                        local Type = type(i) == 'string' and not Keywords[i] and i:match('[A-z_][A-z_0-9]') and type(v)
                                        local NewPath = Type and (Type == 'function' or Type == 'table') and Path .. '.' .. i

                                        if NewPath then
                                            if Type == 'function' then
                                                GlobalFunctions[v] = NewPath
                                            else
                                                LoadLibrary(NewPath, v)
                                            end
                                        end
                                    end

                                    Visited[tbl] = nil
                                end
                            end

                            LoadLibrary(i, v)
                            table.clear(Visited)
                        elseif ElementType == 'function' then
                            GlobalFunctions[v] = i
                        end
                    end
                end

                Class.GlobalFunctions = GlobalFunctions
            end

            DefaultMethods['function'] = function(
                Function: (...any?) -> ...any?,
                format: boolean?,
                indents: string,
                _,
                InComment: boolean?
            )
                local IsGlobal = GlobalFunctions[Function]

                if not IsGlobal then
                    if shared.EmbedFunctionsAsCode then
                        if format then
                            local SerializeString = Methods.string
                            local CommentSeperator = if not InComment then''else'='
                            local tempindents = indents .. '\t\t\t'
                            local newlineindent = ',\n' .. tempindents
                            local source, line, name, numparams, vargs = info(Function, 'slna')
                            local lclosure = line ~= -1

                            return (if lclosure then''else'coroutine.wrap(') .. 'function()\n\t' .. indents .. '--[' .. CommentSeperator .. '[\n\t\t' .. indents .. 'info = {\n' .. tempindents .. 'source = ' .. SerializeString(source) .. newlineindent .. 'line = ' .. line .. newlineindent .. 'what = ' .. (if lclosure then'"Lua"'else'"C"') .. newlineindent .. 'name = ' .. SerializeString(name) .. newlineindent .. 'numparams = ' .. numparams .. newlineindent .. 'vargs = ' .. (if vargs then'true'else'false') .. newlineindent .. 'function = ' .. tostring(Function) .. '\n\t\t' .. indents .. '}\n\t' .. indents .. ']' .. CommentSeperator .. ']\n' .. indents .. 'end' .. (if lclosure then''else')')
                        end
                    else
                        if info(Function, 'n') ~= '' then
                            return string.format('<%s Name: %s>', tostring(Function), debug.info(Function, 'n'))
                        end

                        return string.format('<Anonymous %s>', tostring(Function))
                    end

                    return if islclosure(Function)then'function() end'else'coroutine.wrap(function() end)'
                end

                return IsGlobal
            end
        end

        function DefaultMethods.table(
            tbl: {[any]: any},
            format: boolean?,
            indents: string,
            CyclicList: {[{[any]: any?}]: boolean | nil}?,
            InComment: boolean?
        )
            if not CyclicList then
                CyclicList = setmetatable({}, weakkeys)
            end
            if not CyclicList[tbl] then
                local isreadonly = isfrozen(tbl)
                local Index, Value = next(tbl)

                if Index ~= nil then
                    local Indents = indents .. (if format then'\t'else'')
                    local Ending = (if format then',\n'else', ')
                    local formatspace = if format then'\n'else''
                    local Generation = '{' .. formatspace
                    local CurrentIndex = 1

                    CyclicList[tbl] = true

                    repeat
                        Generation ..= Indents .. (if CurrentIndex ~= Index then ValidateIndex(Index)else'') .. Serialize(Value, format, Indents, CyclicList, InComment)

                        Index, Value = next(tbl, Index)

                        Generation ..= if Index ~= nil then Ending else formatspace .. indents .. '}'
                        CurrentIndex += 1
                    until Index == nil

                    CyclicList[tbl] = nil

                    return if not isreadonly then Generation else'table.freeze(' .. Generation .. ')'
                end

                return if not isreadonly then'{}'else'table.freeze({})'
            else
                return '*** cycle table reference detected ***'
            end
        end

        DefaultMethods['nil'] = function()
            return 'nil'
        end

        function DefaultMethods.number(num: number)
            return if num < 1 / 0 and num > -1 / 0
                then tostring(num)
                elseif num == 1 / 0
                then(if Class._Serializeinf then'math.huge'else'1/0')
                elseif num == num
                then(if Class._Serializeinf then'-math.huge'else'-1/0')
                else'0/0'
        end

        do
            local ByteList = {
                ['\a'] = '\\a',
                ['\b'] = '\\b',
                ['\t'] = '\\t',
                ['\n'] = '\\n',
                ['\v'] = '\\v',
                ['\f'] = '\\f',
                ['\r'] = '\\r',
                ['"'] = '\\"',
                ['\\'] = '\\\\',
            }

            for i = 0, 255 do
                local Character = (i < 32 or i > 126) and string.char(i)

                if Character and not ByteList[Character] then
                    ByteList[Character] = ('\\%03d'):format(i)
                end
            end

            function DefaultMethods.string(RawString: string)
                return '"' .. RawString:gsub('[\0-\31"\\\127-\u{ff}]', ByteList) .. '"'
            end
        end

        function DefaultMethods.thread(thread: thread)
            return string.format('<%s>', tostring(thread))
        end
        function DefaultMethods.userdata(userdata: any)
            return getmetatable(userdata) ~= nil and 'newproxy(true)' or 'newproxy(false)'
        end

        do
            local SecurityCapabilityEnums = Enum.SecurityCapability:GetEnumItems()

            function DefaultMethods.SecurityCapabilities(
                Capabilities: SecurityCapabilities,
                format: boolean?,
                _,
                _,
                InComment: boolean?
            )
                local ContainedCapabilities = {}
                local CurrentIndex = 1

                for i, v in SecurityCapabilityEnums do
                    if Capabilities:Contains(v) then
                        ContainedCapabilities[CurrentIndex] = 'Enum.SecurityCapability.' .. v.Name

                        CurrentIndex += 1
                    end
                end

                return 'SecurityCapabilities.new(' .. concat(ContainedCapabilities, ', ') .. ')'
            end
        end

        function DefaultMethods.PluginDrag(Drag: PluginDrag)
            local SerializeString = Methods.string

            return 'PluginDrag.new(' .. SerializeString(Drag.Sender) .. ', ' .. SerializeString(Drag.MimeType) .. ', ' .. SerializeString(Drag.Data) .. ', ' .. SerializeString(Drag.MouseIcon) .. ', ' .. SerializeString(Drag.DragIcon) .. ', ' .. Methods.Vector2(Drag.HotSpot) .. ')'
        end
        function DefaultMethods.CellId(Cell: CellId)
            local ArgumentFunction = tostring(Cell):gmatch('%w+')
            local SerializeNumber = Methods.number

            local function SerializeStringToNumber(number: string)
                return SerializeNumber(tonumber(number))
            end

            return 'CellId.new(' .. ArgumentFunction() .. ', ' .. SerializeStringToNumber(ArgumentFunction()) .. ', ' .. SerializeStringToNumber(ArgumentFunction()) .. ', ' .. SerializeStringToNumber(ArgumentFunction()) .. ')'
        end

        local function Serializevargs(...: any)
            local tbl = pack(...)
            local GenerationSize = 0

            for i = 1, #tbl do
                local Generation = Serialize(tbl[i], true, '')

                tbl[i] = Generation

                GenerationSize += #Generation

                if GenerationSize > 100000 then
                    break
                end
            end

            return unpack(tbl, 1, tbl.n)
        end

        function Class.Convert<Type>(DataStructure: Type, format: boolean?)
            return Serialize(DataStructure, format, '')
        end
        function Class.ConvertKnown<Type>(
            DataType: string,
            DataStructure: Type,
            format: boolean?
        )
            return Methods[DataType](DataStructure, format, '')
        end
        function Class.print(...: any?)
            print(Serializevargs(...))
        end
        function Class.warn(...: any?)
            warn(Serializevargs(...))
        end

        if type(setclipboard) == 'function' then
            local setclipboard = setclipboard

            function Class.setclipboard<Type>(
                DataStructure: Type,
                format: boolean?
            )
                setclipboard(Serialize(DataStructure, format, ''))
            end
        end

        Class.Internals = table.freeze({Serialize = Serialize})

        return setmetatable(Class, {
            __tostring = function(self)
                return 'DataToCode ' .. self.__VERSION
            end,
        })
    end
    function __DARKLUA_BUNDLE_MODULES.d()
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
                local Character = string.char(Index)

                if not SpecialCharacters[Character] and (Index < 32 or Index > 126) then
                    SpecialCharacters[Character] = string.format('\\x%02X', Index)
                end
            end

            function SerializeString(inputString)
                return table.concat({
                    '"',
                    string.gsub(inputString, '[%z\\"\1-\31\127-\u{ff}]', SpecialCharacters),
                    '"',
                })
            end
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

                if object == game then
                    return 'game'
                elseif object == workspace then
                    return 'workspace'
                end
                if not ObjectPointer then
                    return 'nil'
                end

                local Path = ''

                while ObjectPointer do
                    local ObjectName = ObjectPointer.Name
                    local ObjectClassName = ObjectPointer.ClassName
                    local ObjectParent = ObjectPointer.Parent

                    if ObjectParent == game and IsService(ObjectPointer) then
                        Path = ':GetService(' .. SerializeString(ObjectClassName) .. ')' .. Path
                    elseif not LuaKeywords[ObjectName] and string.match(ObjectName, '^[A-Za-z_][A-Za-z0-9_]*$') then
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
    end
    function __DARKLUA_BUNDLE_MODULES.e()
        local SafetyNet = {}
        local GameMetamethods = {
            ['__index'] = {
                Name = '__index',
                ExpectedArguments = 2,
            },
            ['__newindex'] = {
                Name = '__newindex',
                ExpectedArguments = 3,
            },
            ['__namecall'] = {
                Name = '__namecall',
                ExpectedArguments = math.huge,
            },
        }

        function SafetyNet.ValidateMetamethodCall(
            Metamethod: string,
            SelfType: string,
            ...
        )
            local Args = table.pack(...)
            local ExpectedArguments = GameMetamethods[Metamethod].ExpectedArguments

            if ExpectedArguments ~= math.huge then
                if Args.n ~= ExpectedArguments then
                    return false, string.format('Expected %d arguments, got %d', ExpectedArguments, Args.n)
                end
                if typeof(Args[2]) ~= 'string' then
                    return false, string.format('Invalid key type! Expected (string), got (%s)', typeof(Args[2]))
                end
                if typeof(Args[3]) == 'userdata' then
                    return false, string.format('Invalid value type! Expected (not userdata), got (%s)', typeof(Args[3]))
                end
            else
                if Args.n < 1 then
                    return false, string.format('Missing self argument! Expected (%s), got (none)', SelfType)
                end
            end
            if typeof(Args[1]) ~= SelfType then
                return false, string.format('Wrong self type! Expected (%s), got (%s)', SelfType, typeof(Args[1]))
            end

            return true, 'Valid'
        end

        return SafetyNet
    end
end

shared.DirectCall = {}
shared.ProxyLookup = {}

local MAX_BUFFER_SIZE = 1024 * 1024 * 1024

type SessionConfiguration = {LogEnvironment: boolean, LogMetamethods: boolean, LogRBXScriptSignals: boolean?, LuraphCompatibility: boolean?, FilterInstanceIndex: boolean?, PrettyPrint: boolean?, ShowDebugIdForNilInstancesInsteadOfName: boolean?, LogMetamethodFunctionFetches: boolean?, SafetyNet: boolean?, EmbedFunctionsAsCode: boolean?}

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
    SafetyNet = true,
}

type LogConstructorSet = {FunctionCall: (Function:(...any?) -> ...any?, Args:{any?}, Return:{any?}, FunctionPath:string?) -> string, Namecall: (Instance:Instance | {Instance: Instance, RBXScriptSignal: RBXScriptSignal}, Method:string, Args:{any?}, Return:{any?}) -> string, Index: (Instance:Instance, Key:string, Return:{any?}) -> string, NewIndex: (Instance:Instance, Key:string, Value:any) -> string}
type Session = {Configuration: SessionConfiguration, Targets: {string}, Data: buffer, Written: number, Start: number, End: number, Close: () -> (), GUID: string, Log: (LogString:string) -> (), Active: boolean, SaveToFile: (self:Session, FileName:string) -> ()}

local HttpService = game:GetService('HttpService')
local HookMgr = __DARKLUA_BUNDLE_MODULES.load('a')
local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
local DataToCode = __DARKLUA_BUNDLE_MODULES.load('c')
local EvaluateInstancePath = __DARKLUA_BUNDLE_MODULES.load('d')
local SafetyNet = __DARKLUA_BUNDLE_MODULES.load('e')
local DebugInfo = getrenv and getrenv().debug.info or debug.info
local JSONEncode = function(...): string
    if shared.DirectCall.__namecall then
        return shared.DirectCall.__namecall(HttpService, 'JSONEncode', ...)
    else
        return HttpService:JSONEncode(...)
    end
end
local LuaEncode = function(x)
    local OldThreadContext = getthreadcontext()

    setthreadcontext(8)

    local Result = DataToCode.Convert(x, #x > 1 and shared.Prettify)

    setthreadcontext(OldThreadContext)

    return Result
end
local Calligraph = {
    Version = '1.5.5',
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
    if Instance.Parent == nil and (Instance::any) ~= game then
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

        return string.format('%s(%s) --> %s', FunctionName, FormatCodeArgs(Args), LuaEncode(Return))
    end,
    Namecall = function(Instance, Method, Args, Return)
        if typeof(Instance) == 'table' then
            if typeof(Instance.RBXScriptSignal) == 'RBXScriptSignal' then
                return string.format('%s.%s:%s(%s)', FormatInstancePath(Instance.Instance), tostring(Instance.RBXScriptSignal):gsub('Signal ', ''), Method, FormatCodeArgs(Args))
            end
        end

        assert(typeof(Instance) == 'Instance')

        return string.format('%s:%s(%s) --> %s', FormatInstancePath(Instance), Method, FormatCodeArgs(Args), LuaEncode(Return))
    end,
    Index = function(Instance, Key, Return)
        if typeof(Return[1]) == 'RBXScriptSignal' then
            return string.format('%s.%s --> <RBXScriptSignal %s>', FormatInstancePath(Instance), Key, Key)
        end

        return string.format('%s.%s --> %s', FormatInstancePath(Instance), Key, LuaEncode(Return))
    end,
    NewIndex = function(Instance, Key, Value)
        return string.format('%s.%s = %s', FormatInstancePath(Instance), Key, Value and FormatCodeArgs({Value}) or 'nil')
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

        local Args = {...}
        local Success, Return, ArgsN = Utils.GetReturnData(OldMethod, ...)
        local ReturnFormatted = Success and Return or {
            ['error'] = Return[1],
        }

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

        local CallSource = DebugInfo(4, 's')

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

    return shared.ProxyLookup[Function]
end
function Calligraph:NewSession(Targets: {string}, Configuration: SessionConfiguration)
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
    local LastLogContent: string = ''
    local RepeatCount: number = 0
    local GameMetamethods = {
        [HookMgr.GameMT.__index] = {
            Name = '__index',
            ExpectedArguments = 2,
        },
        [HookMgr.GameMT.__newindex] = {
            Name = '__newindex',
            ExpectedArguments = 3,
        },
        [HookMgr.GameMT.__namecall] = {
            Name = '__namecall',
            ExpectedArguments = math.huge,
        },
    }

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

            local OldThreadContext = getthreadcontext()

            setthreadcontext(8)

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

            setthreadcontext(OldThreadContext)
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
    Session.Log(`Log format: Luau Code`)
    Session.Log(
[[[SYSTEM] Calligraph is now active. All logs will be recorded.]])

    if Session.Configuration.LogMetamethods then
        shared.DirectCall.__index = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:__index`, HookMgr.GameMT.__index, function(
            Old,
            ...
        )
            if checkcaller() then
                return Old(...)
            end

            local CallSource = DebugInfo(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(...)
            end

            local IsValid, Message = SafetyNet.ValidateMetamethodCall('__index', 'Instance', 
...)

            if not IsValid then
                task.spawn(Session.Log, string.format('[!!!] SafetyNet triggered! [__index] %s', Message))

                return Old(...)
            end

            local Self, Index = ...
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
            elseif typeof(Return) == 'RBXScriptSignal' then
                shared.RBXScriptSignalLookupTable[Return] = Self
            end

            return Return
        end)
        shared.DirectCall.__newindex = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:__newindex`, HookMgr.GameMT.__newindex, function(
            Old,
            ...
        )
            if checkcaller() then
                return Old(...)
            end

            local CallSource = DebugInfo(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(...)
            end

            local IsValid, Message = SafetyNet.ValidateMetamethodCall('__newindex', 'Instance', 
...)

            if not IsValid then
                task.spawn(Session.Log, string.format('[!!!] SafetyNet triggered! [__newindex] %s', Message))

                return Old(...)
            end

            local Self, Index, Value = ...

            task.spawn(function()
                Session.Log(LogFormatter.NewIndex(Self, Index, Value))
            end)

            return Old(Self, Index, Value)
        end)
        shared.DirectCall.__namecall = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:__namecall`, HookMgr.GameMT.__namecall, function(
            Old,
            ...
        )
            if checkcaller() then
                return Old(...)
            end

            local CallSource = DebugInfo(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(...)
            end

            local IsValid, Message = SafetyNet.ValidateMetamethodCall('__namecall', 'Instance', 
...)

            if not IsValid then
                task.spawn(Session.Log, string.format('[!!!] SafetyNet triggered! [__namecall] %s', Message))

                return Old(...)
            end

            local Args = {...}
            local Self = table.remove(Args, 1)::Instance
            local Method = getnamecallmethod()
            local Return = {
                Old(...),
            }

            task.spawn(function()
                Session.Log(LogFormatter.Namecall(Self, Method, Args, Return))
            end)

            return table.unpack(Return)
        end)
    end
    if Session.Configuration.LogRBXScriptSignals then
        local RBXScriptSignalMetatable = getrawmetatable(workspace.ChildAdded)
        local ConnectionKeys = {
            ['Connect'] = true,
            ['connect'] = true,
            ['ConnectParallel'] = true,
            ['Once'] = true,
        }

        shared.DirectCall['RBXScriptSignal.__index'] = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:RBXScriptSignal.__index`, RBXScriptSignalMetatable.__index, function(
            Old,
            ...
        )
            if checkcaller() then
                return Old(...)
            end

            local CallSource = DebugInfo(4, 's')

            if not table.find(Session.Targets, CallSource) then
                return Old(...)
            end

            local IsValid, Message = SafetyNet.ValidateMetamethodCall('__index', 'RBXScriptSignal', 
...)

            if not IsValid then
                task.spawn(Session.Log, string.format('[!!!] SafetyNet triggered! [__index] %s', Message))

                return Old(...)
            end

            local Self, Index = ...

            if ConnectionKeys[Index] then
                local ConnectionFunction = Old(...)

                if shared.ProxyLookup[ConnectionFunction] then
                    return shared.ProxyLookup[ConnectionFunction]
                end

                return Calligraph.NewMethodProxy(Session, LogFormatter, Index, {
                    Instance = shared.RBXScriptSignalLookupTable[Self],
                    RBXScriptSignal = Self,
                }, ConnectionFunction)
            end
        end)
    end
    if Session.Configuration.LogMetamethodFunctionFetches then
        shared.DirectCall.DebugInfo = HookMgr.RegisterHook(`Calligraph:{Session.GUID}:MetamethodFunctionFetch`, getrenv().debug.info, function(
            Old,
            ...
        )
            if checkcaller() then
                return Old(...)
            end

            local Args = table.pack(...)

            if Args.n ~= 2 then
                return Old(...)
            end
            if typeof(Args[1]) == 'number' and typeof(Args[2]) == 'string' and Args[2]:match('f') then
                local Success, Return, ReturnN = Utils.GetReturnData(Old, Args[1] + 4, Args[2])

                if not Success then
                    return Old(...)
                end

                for i = 1, ReturnN do
                    local Value = Return[i]

                    if typeof(Value) == 'function' and iscclosure(Value) and GameMetamethods[Value] then
                        task.spawn(Session.Log, string.format('[!!!] Raw %s function fetched: %s', GameMetamethods[Value].Name, tostring(Value)))
                    end
                end
            end

            return Old(...)
        end)
        DebugInfo = shared.DirectCall.DebugInfo.Original
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
