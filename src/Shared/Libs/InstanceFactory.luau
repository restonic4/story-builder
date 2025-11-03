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

-- alias
InstanceFactory.New = InstanceFactory.new

return InstanceFactory