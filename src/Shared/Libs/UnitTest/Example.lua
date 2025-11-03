local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)

local Tests = {}

function Tests.RegisterUnitTests()
	-- Example 1: Basic synchronous tests
	UnitTest.describe("Math Library", function()
		UnitTest.it("adds numbers correctly", function()
			local result = 2 + 2
			UnitTest.assert.equal(result, 4)
		end)

		UnitTest.it("detects inequality", function()
			local result = 5 * 2
			UnitTest.assert.notEqual(result, 11)
		end)

		UnitTest.it("checks near equality for floats", function()
			local result = math.sqrt(2) ^ 2
			UnitTest.assert.near(result, 2, 1e-9)
		end)
	end)

	-- Example 2: Async test using a 'done' callback
	UnitTest.describe("Async Examples", function()
		UnitTest.it("waits for a delayed callback", function(done)
			task.delay(0.5, function()
				UnitTest.assert.truthy(true, "Expected true to be truthy")
				done()
			end)
		end, { async = true, timeout = 2 })
	end)

	-- Example 3: Using spies to monitor function calls
	local function greet(name)
		return "Hello, " .. name
	end

	UnitTest.describe("Spy Example", function()
		UnitTest.it("tracks calls to a function", function()
			local spy = UnitTest.spy.create(greet)
			local msg = spy.fn("Roblox")

			UnitTest.assert.equal(msg, "Hello, Roblox")
			UnitTest.assert.equal(spy.callCount(), 1)
			UnitTest.assert.truthy(spy.called())

			local callArgs = spy.getCall(1)
			UnitTest.assert.equal(callArgs[1], "Roblox")
		end)
	end)

	-- Example 4: Selective tests with 'only' and 'skip'
	UnitTest.describe("Selective Execution", function()
		UnitTest.it("runs normally", function()
			UnitTest.assert.truthy(true)
		end)

		UnitTest.it("runs exclusively", function()
			UnitTest.assert.truthy(true)
		end, { only = false })

		UnitTest.it("is skipped", function()
			error("Should not run")
		end, { skip = true })
	end)
end

return Tests