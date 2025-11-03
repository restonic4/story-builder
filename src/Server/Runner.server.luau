local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)

UnitTest.RunTests(script.Parent.UnitTests)