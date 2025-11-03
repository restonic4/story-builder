local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)

UnitTest.describe("Math Library", function()
    UnitTest.beforeEach(function()
        print("Setting up for math tests...")
    end)

    UnitTest.afterEach(function()
        print("Cleaning up after test...")
    end)

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

UnitTest.run()