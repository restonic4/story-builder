local Test = {}
Test._suites = {}
Test._currentDescribe = nil

-- Internal helpers ---------------------------------------------------------
local function shallowCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
end

local function deepEqual(a, b, visited)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return false end
    visited = visited or {}
    if visited[a] and visited[a] == b then return true end
    visited[a] = b
    for k, v in pairs(a) do
        if not deepEqual(v, b[k], visited) then return false end
    end
    for k, v in pairs(b) do
        if a[k] == nil and b[k] ~= nil then return false end
    end
    return true
end

local function pretty(v)
    local t = type(v)
    if t == "string" then return ('"%s"'):format(v)
    elseif t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts+1] = tostring(k) .. "=" .. pretty(val)
            if #parts > 20 then break end
        end
        return "{" .. table.concat(parts, ", ") .. ( #parts > 20 and ",..." or "") .. "}"
    else return tostring(v) end
end

local function safeCall(fn, ...)
    local ok, res1, res2 = pcall(fn, ...)
    if ok then return true, res1, res2 end
    return false, res1
end

-- Assertion API ------------------------------------------------------------
Test.assert = {}
function Test.assert.equal(a, b, msg)
    if a ~= b then
        error(msg or ("Expected %s to equal %s"):format(pretty(a), pretty(b)), 2)
    end
end
function Test.assert.notEqual(a, b, msg)
    if a == b then
        error(msg or ("Expected %s to not equal %s"):format(pretty(a), pretty(b)), 2)
    end
end
function Test.assert.truthy(v, msg)
    if not v then error(msg or ("Expected truthy value, got %s"):format(pretty(v)), 2) end
end
function Test.assert.falsy(v, msg)
    if v then error(msg or ("Expected falsy value, got %s"):format(pretty(v)), 2) end
end
function Test.assert.deepEqual(a, b, msg)
    if not deepEqual(a, b) then
        error(msg or ("Expected deep equal; got %s vs %s"):format(pretty(a), pretty(b)), 2)
    end
end
function Test.assert.throws(fn, msg)
    local ok, err = pcall(fn)
    if ok then error(msg or ("Expected function to throw, but it did not"), 2) end
end
function Test.assert.near(a, b, eps, msg)
    eps = eps or 1e-6
    if type(a) ~= "number" or type(b) ~= "number" then
        error(msg or "near: both values must be numbers", 2)
    end
    if math.abs(a - b) > eps then
        error(msg or ("Expected %s to be near %s ±%s"):format(pretty(a), pretty(b), tostring(eps)), 2)
    end
end

-- Spy implementation -------------------------------------------------------
Test.spy = {}
function Test.spy.create(fn)
    local calls = {}
    local wrapper = function(...)
        local args = { ... }
        table.insert(calls, args)
        if type(fn) == "function" then
            return fn(...)
        end
    end
    return {
        fn = wrapper,
        calls = calls,
        callCount = function() return #calls end,
        called = function() return #calls > 0 end,
        getCall = function(i) return calls[i] end,
        reset = function() calls = {}; wrapper.calls = calls end
    }
end

-- Registration API --------------------------------------------------------
function Test.describe(name, fn)
    local suite = { name = name or "(anonymous)", tests = {}, beforeEach = {}, afterEach = {} }
    Test._suites[#Test._suites + 1] = suite
    local prev = Test._currentDescribe
    Test._currentDescribe = suite
    if type(fn) == "function" then
        fn()
    end
    Test._currentDescribe = prev
    return suite
end

function Test.beforeEach(fn)
    if not Test._currentDescribe then error("beforeEach must be called inside describe", 2) end
    table.insert(Test._currentDescribe.beforeEach, fn)
end
function Test.afterEach(fn)
    if not Test._currentDescribe then error("afterEach must be called inside describe", 2) end
    table.insert(Test._currentDescribe.afterEach, fn)
end

-- it(name, fn, opts)
-- opts = { async = boolean, timeout = seconds (default 5), only = boolean, skip = boolean }
function Test.it(name, fn, opts)
    opts = opts or {}
    if not Test._currentDescribe then
        -- auto-create a suite if called at top-level
        Test.describe("(root)")
    end
    local test = { name = name or "(unnamed)", fn = fn, opts = shallowCopy(opts) }
    table.insert(Test._currentDescribe.tests, test)
    return test
end

-- Runner -------------------------------------------------------------------
local function runTestCase(test, suite)
    local result = { name = test.name, fullName = (suite.name .. " - " .. test.name), passed = false, error = nil, duration = 0 }
    if test.opts and test.opts.skip then
        result.skipped = true
        return result
    end
    if test.opts and test.opts.only == false and test.opts.skip then
        result.skipped = true
        return result
    end

    local startTime = tick()
    -- run beforeEach hooks
    for _, h in ipairs(suite.beforeEach) do
        local ok, err = pcall(h)
        if not ok then
            result.passed = false
            result.error = ("beforeEach failed: %s"):format(tostring(err))
            result.duration = tick() - startTime
            return result
        end
    end

    -- run the test
    local ok, err
    if test.opts and test.opts.async then
        local done = false
        local doneErr = nil
        local timeout = (test.opts.timeout ~= nil) and test.opts.timeout or 5
        local finished = false

        local function doneFn(errMsg)
            if finished then return end
            finished = true
            if errMsg then doneErr = errMsg end
            done = true
        end

        -- run test in protected call so it can't error synchronously
        local status, res = pcall(function() return test.fn(doneFn) end)
        if not status then
            ok = false; err = res
        else
            -- wait for done or timeout
            local t0 = tick()
            while not done and (tick() - t0) < timeout do
                task.wait(0.01)
            end
            if not done then
                ok = false; err = ("Async test timed out after %s seconds"):format(tostring(timeout))
            else
                if doneErr then ok = false; err = doneErr else ok = true end
            end
        end
    else
        ok, err = pcall(function() return test.fn() end)
    end

    -- run afterEach hooks even if test errored
    for _, h in ipairs(suite.afterEach) do
        local hk, herr = pcall(h)
        if not hk then
            -- If the test already failed, append afterEach error info; otherwise treat as failure
            if not ok then
                err = ("%s\n(afterEach failed: %s)"):format(tostring(err), tostring(herr))
            else
                ok = false; err = ("afterEach failed: %s"):format(tostring(herr))
            end
        end
    end

    result.passed = ok
    if not ok then result.error = tostring(err) end
    result.duration = tick() - startTime
    return result
end

function Test.run(opts)
    opts = opts or {}
    local onlyMode = false
    for _, suite in ipairs(Test._suites) do
        for _, t in ipairs(suite.tests) do
            if t.opts and t.opts.only then onlyMode = true; break end
        end
        if onlyMode then break end
    end

    local results = {}
    local total, passed, failed, skipped = 0, 0, 0, 0
    for _, suite in ipairs(Test._suites) do
        print(("Suite: %s"):format(suite.name))
        for _, t in ipairs(suite.tests) do
            if onlyMode and not (t.opts and t.opts.only) then
                t.opts = t.opts or {}
                t.opts.skip = true
            end
            local res = runTestCase(t, suite)
            table.insert(results, res)
            if res.skipped then
                skipped = skipped + 1
                warn(string.format("  - SKIPPED: %s", res.fullName))
            elseif res.passed then
                passed = passed + 1
                print(string.format("  - PASS: %s (%.03fs)", res.fullName, res.duration))
            else
                failed = failed + 1
                warn(string.format("  - FAIL: %s (%.03fs)\n      %s", res.fullName, res.duration, res.error))
            end
            total = total + 1
        end
    end

    local summary = { total = total, passed = passed, failed = failed, skipped = skipped, results = results }
    print(("---\nTests finished. Total: %d, Passed: %d, Failed: %d, Skipped: %d"):format(total, passed, failed, skipped))
    return summary
end

-- Utility helpers ----------------------------------------------------------
function Test.clear()
    Test._suites = {}
    Test._currentDescribe = nil
end

function Test.reset()
    Test.clear()
end

function Test.runInnerTests()
    for i, children in script:GetChildren() do
        if children:IsA("ModuleScript") then
            local required = require(children)
            required.RegisterUnitTests()
        end
    end

    Test.run()
end

-- Return module
return Test