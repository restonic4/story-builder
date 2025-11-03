local ReflectionService = game:GetService("ReflectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)

UnitTest.RunTests(script.Parent.UnitTests)

local properties = ReflectionService:GetPropertiesOfClass("Part")
print(properties)