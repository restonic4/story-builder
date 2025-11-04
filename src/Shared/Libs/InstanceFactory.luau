local InstanceFactory = {}

-- Create an instance of className and apply props (table)
function InstanceFactory.new(className: string, props)
    assert(type(className) == "string", "className must be a string")

    local ok, inst = pcall(Instance.new, className)
    assert(ok and inst, "failed to Instance.new(" .. tostring(className) .. ")")

    props = props or {}

    -- first pass: set simple properties and Attributes/Events/Children skipped until after
    for k, v in pairs(props) do
        if k == "Parent" or k == "Children" or k == "Events" or k == "Attributes" or k == "Init" or k == "Properties" then
            -- handled in later passes
        else
            -- assign as a normal property (safe)
            pcall(function() inst[k] = v end)
        end
    end

    -- optional: explicit Properties table (useful if you want to separate special keys)
    if type(props.Properties) == "table" then
        for pname, pval in pairs(props.Properties) do
            pcall(function() inst[pname] = pval end)
        end
    end

    -- Attributes (SetAttribute is safe-guarded in pcall)
    if type(props.Attributes) == "table" then
        for aname, aval in pairs(props.Attributes) do
            pcall(function() inst:SetAttribute(aname, aval) end)
        end
    end

    -- Children (create after the parent exists so nested creation can reference parent if necessary)
    if type(props.Children) == "table" then
        for _, childSpec in ipairs(props.Children) do
            local child
            if type(childSpec) == "table" then
                -- childSpec may contain its own Class or use childSpec[1]
                child = InstanceFactory.Create(childSpec)
            elseif type(childSpec) == "string" then
                -- shorthand: just the class name
                child = Instance.new(childSpec)
            else
                child = nil
            end
            if child then
                -- ensure child parent is this instance (overwrite child.Spec.Parent)
                child.Parent = inst
            end
        end
    end

    -- Events: connect functions to signals (safe: only if the event exists)
    if type(props.Events) == "table" then
        for evName, fn in pairs(props.Events) do
            if type(fn) == "function" then
                pcall(function()
                    local maybeSignal = inst[evName]
                    if maybeSignal and typeof(maybeSignal) == "RBXScriptSignal" then
                        maybeSignal:Connect(fn)
                    end
                end)
            end
        end
    end

    -- Init callback called after children/events are wired
    if type(props.Init) == "function" then
        pcall(function() props.Init(inst) end)
    end

    -- Parent assigned last (so the object is fully configured before being put into game tree)
    if props.Parent then
        pcall(function() inst.Parent = props.Parent end)
    end

    return inst
end

-- Create(spec) convenience wrapper:
-- spec can be:
--  { "Frame", Name = "X", ... }  -> spec[1] or spec.Class is used as class name
--  { Class = "Frame", Name = "...", Children = {...}, ... }
function InstanceFactory.Create(spec)
    assert(type(spec) == "table", "spec must be a table")
    local className = spec.Class or spec[1]
    assert(type(className) == "string", "spec must contain Class or index 1 with class name")
    return InstanceFactory.new(className, spec)
end

-- Export an Instance into the same "spec" table format accepted by InstanceFactory.Create/new.
-- Usage: local spec = InstanceFactory.Export(instance, opts)
-- opts (optional):
--   propsList = array of property names to attempt to read (default: a sensible whitelist)
--   includeParent = boolean (default false) -- whether to include Parent in the exported spec (careful with cycles)
--   includeAttributes = boolean (default true)
--   includeChildren = boolean (default true)
--   includeProperties = boolean (default true)
function InstanceFactory.Export(instance, opts)
    assert(typeof(instance) == "Instance" or type(instance) == "userdata", "Export expects a Roblox Instance")
    opts = opts or {}

    -- default property whitelist (common/likely useful properties across GUI, BaseParts, Values, etc).
    -- You can pass opts.propsList to override.
    local defaultProps = {
        -- Instance
        "Archivable",

        -- Part
        "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "CFrame", "Position",
        "Size", "Orientation", "Velocity", "RotVelocity", "Mass", "Material", "BrickColor",
        "Color", "MaterialVariant", "Reflectance", "Transparency", "Locked", "Origin",
        "PivotOffset", "EnableFluidForces", "CollisionGroup", "CustomPhysicalProperties",
        "Massless", "RootPriority", "Shape", "AssemblyLinearVelocity", "AssemblyAngularVelocity",
        "BackSurface", "BottomSurface", "FrontSurface", "LeftSurface", "RightSurface", "TopSurface",

        -- ScreenGui
        "ClipToDeviceSafeArea", "SafeAreaCompatibility", "ScreenInsets", "DisplayOrder",
        "Enabled", "IgnoreGuiInset", "ResetOnSpawn", "ZIndexBehaviour", "ZIndex", "LayoutOrder",
        "AutoLocalize", "RootLocalizationTable", "SelectionGroup",

        -- Frame
        "SelectionImageObject", "Active", "AnchorPoint", "AutomaticSize", "BackgroundColor3",
        "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "Interactable",
        "Rotation", "SizeConstraint", "Style", "Visible", "ClipDescendants", "NextSelectionDown",
        "NextSelectionLeft", "NextSelectionRight", "NextSelectionUp", "Selectable", "SelectionOrder",

        -- ImageLabel
        "Image", "ImageContent", "ImageRectSize", "ImageRectOffset", "ImageTransparency", "ImageColor3",
        "ScaleType", "SliceCenter", "ResampleMode",

        -- ValueObjects
        "Value", "MaxValue", "MinValue",

        -- Other
        "ClipsDescendants", "Text", "TextColor3", "TextSize", "TextScaled", "Font", "TextStrokeTransparency",
        "TextStrokeColor3", "TextWrapped", "TextXAlignment", "TextYAlignment", "TextTransparency", "Points",
        "MaxForce", "Weight", "Enabled", "Priority", ""
    }

    local propsList = opts.propsList or defaultProps
    local includeAttributes = opts.includeAttributes == nil and true or opts.includeAttributes
    local includeChildren = opts.includeChildren == nil and true or opts.includeChildren
    local includeProperties = opts.includeProperties == nil and true or opts.includeProperties
    local includeParent = opts.includeParent or true

    -- helper: determine if a value is safe/serializable into the spec (we skip Instances and functions and signals).
    local function isSerializable(v)
        local t = typeof(v)
        if t == "Instance" or t == "RBXScriptSignal" or t == "function" then
            return false
        end
        -- allow numbers, strings, booleans, Vector2/3, UDim2, Color3, CFrame, EnumItem, NumberRange, ColorSequence, NumberSequence, Rect, etc.
        -- We'll accept anything that's not an Instance / Signal / Function; pcall guard will still be used when reading.
        return true
    end

    -- helper: safe read a property, returning (ok, value)
    local function safeReadProperty(obj, propName)
        local ok, val = pcall(function() return obj[propName] end)
        if not ok then
            return false, nil
        end
        return true, val
    end

    local spec = {}

    -- set class (both shorthand index and explicit Class so Create() will accept it either way)
    spec[1] = instance.ClassName
    spec.Class = instance.ClassName

    -- top-level common properties (Name is extremely common)
    local okName, nameVal = safeReadProperty(instance, "Name")
    if okName and type(nameVal) == "string" and nameVal ~= "" then
        spec.Name = nameVal
    end

    -- optionally include Parent as a reference (careful: may create cycles). Default: false.
    if includeParent then
        local okParent, parentVal = safeReadProperty(instance, "Parent")
        if okParent and parentVal ~= nil and typeof(parentVal) == "Instance" then
            -- we don't attempt to embed the full parent tree; just include its full name for human reference
            spec.Parent = parentVal
            spec.ParentPath = parentVal:GetFullName() and parentVal:GetFullName() or parentVal.Name
        end
    end

    -- Properties: attempt to read values from propsList and include only serializable ones
    if includeProperties then
        spec.Properties = spec.Properties or {}
        for _, propName in ipairs(propsList) do
            -- skip keys that are reserved in our spec format
            if propName ~= "Parent" and propName ~= "Children" and propName ~= "Attributes"
            and propName ~= "Events" and propName ~= "Init" and propName ~= "Properties" then
                local ok, val = safeReadProperty(instance, propName)
                if ok and val ~= nil and isSerializable(val) then
                    -- for EnumItem, convert to Enum name (keeps readable/robust)
                    if typeof(val) == "EnumItem" then
                        spec.Properties[propName] = tostring(val) -- e.g. "Enum.Font.SourceSans"
                    else
                        spec.Properties[propName] = val
                    end
                end
            end
        end
    end

    -- Attributes
    if includeAttributes then
        local okAttr, attrs = pcall(function() return instance:GetAttributes() end)
        if okAttr and type(attrs) == "table" then
            -- copy attributes as-is (they are primitives or simple tables)
            if next(attrs) then
                spec.Attributes = {}
                for k, v in pairs(attrs) do
                    -- only include serializable attribute values
                    if isSerializable(v) then
                        spec.Attributes[k] = v
                    end
                end
            end
        end
    end

    -- Children
    if includeChildren then
        local okChildren, children = pcall(function() return instance:GetChildren() end)
        if okChildren and type(children) == "table" and #children > 0 then
            spec.Children = {}
            for _, child in ipairs(children) do
                -- recursively export; avoid including Parent in child spec to prevent cycles
                local success, childSpec = pcall(function()
                    return InstanceFactory.Export(child, {
                        propsList = opts.propsList,
                        includeAttributes = includeAttributes,
                        includeChildren = includeChildren,
                        includeProperties = includeProperties,
                        includeParent = false
                    })
                end)
                if success and type(childSpec) == "table" then
                    table.insert(spec.Children, childSpec)
                else
                    -- fallback: if export failed, insert a minimal entry
                    table.insert(spec.Children, { child.ClassName, Name = child.Name })
                end
            end
        end
    end

    return spec
end

-- alias
InstanceFactory.New = InstanceFactory.new
InstanceFactory.Export = InstanceFactory.Export

return InstanceFactory